// (c) 2012-2017 musictheory.net, LLC


#import "MTSEscapePod.h"

#import "MTSTelemetry.h"

#include <dlfcn.h>
#include <fcntl.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <signal.h>
#include <sys/sysctl.h>
#include <sys/stat.h>

#include <stdatomic.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIDevice.h>
#endif

static NSString *sTelemetryName = @"MTSEscapePod";
static mach_port_t sIgnoredThread = 0;
static MTSEscapePodSignalCallback sSignalCallback = NULL;

#define MAX_FILE_SIZE (1024 * 256)
#define MAX_NUMBER_OF_FRAMES 128
#define CUSTOM_STRING_COUNT 4
#define CUSTOM_STRING_MAX_LEN 128

static int sSignalsToCatch[] = {
    SIGABRT,
    SIGBUS,
    SIGFPE,
    SIGILL,
    SIGSEGV,
    SIGTRAP
};

static NSUncaughtExceptionHandler *sExistingUncaughtExceptionHandler = NULL;

static size_t  sSignalsToCatchCount = (sizeof(sSignalsToCatch) / sizeof(sSignalsToCatch[0]));
static stack_t sSignalStack;

static char *sActivePath = NULL;

typedef struct EscapePodBinaryImage {
    struct EscapePodBinaryImage *next;

    const void *addr;
    uint64_t vmaddr;
    char *path;
    char uuid[16];
    size_t size;
    uint32_t version;
    cpu_type_t cputype;
    cpu_subtype_t cpusubtype;
    boolean_t active;
} EscapePodBinaryImage;


static dispatch_queue_t sDispatchQueue = NULL;

typedef struct {
    char *headerString;
    _Atomic(char *) exceptionString;

    CFMutableDictionaryRef headerToBinaryImageMap;
    CFMutableDictionaryRef uuidToBinaryImageMap;
    _Atomic(EscapePodBinaryImage *) binaryImageHead;

    char customString[CUSTOM_STRING_COUNT][CUSTOM_STRING_MAX_LEN];
} EscapePodStorage;

static EscapePodStorage sStorage;


#pragma mark - Utility Functions

static BOOL read_memory_safe(void *destination, const void *source, size_t n)
{
    vm_size_t read_size = n;
    kern_return_t result = vm_read_overwrite(mach_task_self(), (vm_address_t)source, n, (pointer_t)destination, &read_size);
    return (result == KERN_SUCCESS);
}


static void memcpy_safe(void * restrict destination, const void * restrict source, size_t n)
{
    uint8_t *s = (uint8_t *)source;
    uint8_t *d = (uint8_t *)destination;

    for (size_t count = 0; count < n; count++) {
        *d++ = *s++;
    }
}


static size_t strlen_safe(const char *s1)
{
    const char *s2 = s1;
    while (*s2++);
    return (s2 - s1) - 1;
}


static void to_hex_string_safe(char *destination, const uint8_t *source, size_t n)
{
    char *d = destination;
    BOOL didWrite = NO;

    for (int i = 0; i < n; i++) {
        uint8_t s   = source[i];
        uint8_t hi  = (s & 0xF0) >> 4;
        uint8_t low = (s & 0x0F);

        if (hi || didWrite) {
            *d++ = (hi < 10)  ? (hi  + '0') : (hi  - 10 + 'a');
            didWrite = YES;
        }
        
        if (low || didWrite) {
            *d++ = (low < 10) ? (low + '0') : (low - 10 + 'a');
            didWrite = YES;
        }
    }

    // Always write at least one '0' to output
    if (!didWrite) {
        *d++ = '0';
    }
    
    *d = 0;
}


#pragma mark - File Functions

typedef struct {
    int    fd;
    size_t total;
    size_t max;
    char   buffer[256];
    size_t length;
} File;


static void file_open_safe(File *file, const char *path)
{
    file->fd     = open(path, O_RDWR|O_CREAT|O_TRUNC, 0644);
    file->length = 0;
    file->total  = 0;
    file->max    = MAX_FILE_SIZE;
}


static BOOL file_fd_write_safe(File *file, const void *data, size_t length)
{
    const void *d = data;
    size_t bytesRemaining = length;
    ssize_t bytesWritten = 0;

    while (bytesRemaining > 0) {
        if ((bytesWritten = write(file->fd, d, bytesRemaining)) <= 0) {
            if (errno == EINTR) {
                bytesWritten = 0;
            } else {
                return NO;
            }
        }
        
        bytesRemaining -= bytesWritten;
        d += bytesWritten;
    }
    
    return YES;
}


static BOOL file_write_safe(File *file, const void *data, size_t length)
{
    if ((length + file->total) > file->max) {
        return NO;
    }

    file->total += length;

    if ((file->length + length) > sizeof(file->buffer)) {
        if (!file_fd_write_safe(file, file->buffer, file->length)) {
            return NO;
        }
        
        file->length = 0;
    }
    
    if ((file->length + length) <= sizeof(file->buffer)) {
        memcpy_safe(file->buffer + file->length, data, length);
        file->length += length;
        
    } else {
        if (!file_fd_write_safe(file, data, length)) {
            return NO;
        }
    } 

    return YES;
}


static void file_writef_safe(File *file, const char *format, ...)
{
    va_list v;
    va_start(v, format);

    char c;
    while ((c = *format++)) {
        if (c == '%') {
            c = *format++;

            if (c == 'x') {
                uintptr_t p = va_arg(v, uintptr_t);

#if defined(__LP64__) && __LP64__
                p = OSSwapHostToBigInt64(p);
#else
                p = OSSwapHostToBigInt32(p);
#endif

                char buffer[(sizeof(void *) * 2) + 1];
                to_hex_string_safe(buffer, (const uint8_t *)&p, sizeof(uintptr_t));

                size_t length = strlen_safe(buffer);
                file_write_safe(file, buffer, length);

            } else if (c == 's') {
                const char *string = va_arg(v, const char *);
                size_t length = strlen_safe(string);
                file_write_safe(file, string, length);
            
            } else if (c == 0) {
                break;
            }

        } else {
            file_write_safe(file, &c, 1);
        }
    }
    
    va_end(v);
}


static BOOL file_flush_safe(File *file)
{
    if (file->length != 0) {
        if (!file_fd_write_safe(file, file->buffer, file->length)) {
            return NO;
        }
        
        file->length = 0;
    }
    
    return YES;
}


static void file_close_safe(File *file)
{
    file_flush_safe(file);
    close(file->fd);
    file->fd = 0;
}


#pragma mark - Cursor Functions

typedef struct {
    ucontext_t *uap;
    void *fp[2];
    ucontext_t _uap_data;
    _STRUCT_MCONTEXT _mcontext_data;
} Cursor;


static BOOL get_thread_state_safe(thread_t thread, _STRUCT_MCONTEXT *context)
{
    kern_return_t kr = KERN_FAILURE;

#if defined(__arm64__)
    mach_msg_type_number_t stateCount = ARM_THREAD_STATE64_COUNT;
    kr = thread_get_state(thread, ARM_THREAD_STATE64, (thread_state_t)&context->__ss, &stateCount);

#elif defined(__arm__)
    mach_msg_type_number_t stateCount = ARM_THREAD_STATE_COUNT;
    kr = thread_get_state(thread, ARM_THREAD_STATE, (thread_state_t)&context->__ss, &stateCount);

#elif defined(__x86_64__)
    mach_msg_type_number_t stateCount = x86_THREAD_STATE64_COUNT;
    kr = thread_get_state(thread, x86_THREAD_STATE64, (thread_state_t) &context->__ss, &stateCount);

#elif defined(__i386__)
    mach_msg_type_number_t stateCount = x86_THREAD_STATE32_COUNT;
    kr = thread_get_state(thread, x86_THREAD_STATE32, (thread_state_t) &context->__ss, &stateCount);
#else
    #warning MTSEscapePod - get_thread_state_safe() not implemented for architecture
#endif

    return (kr == KERN_SUCCESS);
}


static void *cursor_get_frame_pointer_safe(Cursor *cursor)
{
#if defined(__arm64__)
    return (void *)cursor->uap->uc_mcontext->__ss.__fp;
#elif defined(__arm__)
    return (void *)cursor->uap->uc_mcontext->__ss.__r[7];
#elif defined(__x86_64__)
    return (void *)cursor->uap->uc_mcontext->__ss.__rbp;
#elif defined(__i386__)
    return (void *)cursor->uap->uc_mcontext->__ss.__ebp;
#else
    #warning MTSEscapePod - cursor_get_frame_pointer_safe() not implemented for architecture
    return NULL;
#endif
}


static void *cursor_get_program_counter_safe(Cursor *cursor)
{
#if defined(__arm64__)
    return (void *)cursor->uap->uc_mcontext->__ss.__pc;
#elif defined(__arm__)
    return (void *)cursor->uap->uc_mcontext->__ss.__pc;
#elif defined(__x86_64__)
    return (void *)cursor->uap->uc_mcontext->__ss.__rbp;
#elif defined(__i386__)
    return (void *)cursor->uap->uc_mcontext->__ss.__eip;
#else
    #warning MTSEscapePod - cursor_get_program_counter_safe() not implemented for architecture
    return NULL;
#endif

}


static void cursor_ucontext_init_safe(Cursor *cursor, ucontext_t *uap)
{
    cursor->uap = uap;
    cursor->fp[0] = NULL;
}


static BOOL cursor_thread_init_safe(Cursor *cursor, thread_t thread)
{
    ucontext_t *uap;

    uap = &cursor->_uap_data;
    uap->uc_mcontext = (void *) &cursor->_mcontext_data;

    sigemptyset(&uap->uc_sigmask);
    if (!get_thread_state_safe(thread, &cursor->_mcontext_data)) {
        return NO;
    }
    
    cursor_ucontext_init_safe(cursor, uap);

    return YES;
}


static BOOL cursor_next_safe(Cursor *cursor)
{
    BOOL result = YES;

    void *from = cursor->fp[0] ? cursor->fp[0] : cursor_get_frame_pointer_safe(cursor);
    if (!from) return NO;
    result = read_memory_safe(cursor->fp, from, sizeof(cursor->fp));

    if (!result) return result;
    if (!cursor->fp[0]) result = NO;
    
    return result;
}


#pragma mark - Callbacks

static void HandleSignal(int signal, siginfo_t *siginfo, void *uapAsVoid)
{
    ucontext_t *uap = (ucontext_t *)uapAsVoid;

    // Remove all of our installed sigactions.  The raise() at the bottom
    // of this method will cause the default signal handler to fire
    //
    for (size_t i = 0; i < sSignalsToCatchCount; i++) {
        struct sigaction action;
        
        memset(&action, 0, sizeof(action));
        action.sa_handler = SIG_DFL;
        sigemptyset(&action.sa_mask);
        
        sigaction(sSignalsToCatch[i], &action, NULL);
    }
   
    File f;
    File *file = &f;

    file_open_safe(file, sActivePath);

    if (sStorage.headerString) {
        size_t length = strlen_safe(sStorage.headerString);
        file_write_safe(file, sStorage.headerString, length);
    }

    // Suspend each thread and write out its state
    {
        task_t   taskSelf   = mach_task_self();
        thread_t threadSelf = mach_thread_self();

        thread_act_array_t threads;
        mach_msg_type_number_t threadCount;

        if (task_threads(taskSelf, &threads, &threadCount) != KERN_SUCCESS) {
            threadCount = 0;
        }

        for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
            thread_t thread = threads[i];
            BOOL isSelf = (MACH_PORT_INDEX(thread) == MACH_PORT_INDEX(threadSelf));

            if (!isSelf && (threads[i] != sIgnoredThread)) {
                if (thread_suspend(threads[i]) != KERN_SUCCESS) {
                    continue;
                }
            }

            file_writef_safe(file, "%s: ", isSelf ? "THRC" : "THRD");
            
            Cursor c = {0};
            Cursor *cursor = &c;
            
            if (isSelf) {
                cursor_ucontext_init_safe(cursor, uap);
            } else {
                cursor_thread_init_safe(cursor, thread);
            }
            
            file_writef_safe(file, "%x", cursor_get_program_counter_safe(cursor));

            int frameCount = MAX_NUMBER_OF_FRAMES;
            while (cursor_next_safe(cursor) && (--frameCount >= 0)) {
                file_writef_safe(file, ",%x", cursor->fp[1]);
            }
            file_writef_safe(file, "\n");
        }

        // Technically, we should free the memory allocated by task_threads()
        // In practice, we are dying anyway.
        //
        //    for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
        //        mach_port_deallocate(mach_task_self(), threads[i]);
        //    }

        //    vm_deallocate(mach_task_self(), (vm_address_t)threads, sizeof(thread_t) * threadCount);
    }

    char *exceptionString = atomic_load(&sStorage.exceptionString);
    if (exceptionString) {
        size_t length = strlen_safe(exceptionString);
        file_write_safe(file, exceptionString, length);
    }

    // Report timestamp
    {
        time_t timestamp;

        if (time(&timestamp) == (time_t)-1) {
            timestamp = 0;
        }

        file_writef_safe(file, "time: %x\n", (void *)timestamp);
    }

    // Report siginfo
    {
        file_writef_safe(file,
            "sign: %x\n"
            "sigc: %x\n"
            "siga: %x\n",
            siginfo ? siginfo->si_signo : 0,
            siginfo ? siginfo->si_code  : 0,
            siginfo ? siginfo->si_addr  : 0
        );
    }
    
    // Report custom strings
    {
        char *sTagStrings[CUSTOM_STRING_COUNT] = { "STR0", "STR1", "STR2", "STR3" };
        
        for (int i = 0; i < CUSTOM_STRING_COUNT; i++) {
            if (strlen_safe(sStorage.customString[i]) > 0) {
                file_writef_safe(file, "%s: %s\n", sTagStrings[i], sStorage.customString[i]);
            }
        }
    }
   
    // Report registers
    {
        size_t count = sizeof(uap->uc_mcontext->__ss) / sizeof(void *);
        void **registers = (void **)&uap->uc_mcontext->__ss;

        for (int i = 0; i < count; i++) {
            file_writef_safe(file, "REGI: %x\n", registers[i]);
        }
    }

    // Report binary images
    {
        char uuidString[40];

        EscapePodBinaryImage *image = atomic_load(&sStorage.binaryImageHead);

        while (image) {
           if (image->active) {
                uint32_t version = image->version;
                to_hex_string_safe(uuidString, (const uint8_t *)image->uuid, sizeof(image->uuid));

                file_writef_safe(file, "BINI: %x,%x,%x,%x,%x,%x,%x,%x,%s,%s\n",
                    image->addr,
                    (void *)image->size,
                    image->vmaddr,
                    (void *)(NSInteger)( version >> 16),
                    (void *)(NSInteger)((version >> 8 ) & 0xff),
                    (void *)(NSInteger)( version        & 0xff),
                    (void *)(NSInteger)image->cputype,
                    (void *)(NSInteger)image->cpusubtype,
                    uuidString,
                    image->path
                );
            }
            
            image = image->next;
        }
    }

    file_close_safe(file);
    
    if (sSignalCallback) {
        sSignalCallback(signal, siginfo, uap);
    }

    raise(signal);
}


static void HandleBinaryImageAdd(const struct mach_header *header, intptr_t vmaddr_slide)
{
    Dl_info info;
    if (dladdr(header, &info) == 0) {
        return;
    }

    const void   *addr       = header;
    uint64_t      vmaddr     = 0;
    const char   *path       = info.dli_fname;
    size_t        size       = 0;
    uint32_t      version    = 0;
    cpu_type_t    cputype    = header->cputype;
    cpu_subtype_t cpusubtype = header->cpusubtype;

    char uuid[16] = {0};
    
    // Find the UUID and __TEXT size for this binary image
    {
        struct load_command *command = (struct load_command *) (header + 1);

#if defined(__LP64__) && __LP64__
        if (header->magic == MH_MAGIC_64 || header->magic == MH_CIGAM_64) {
            const struct mach_header_64 *header64 = (const struct mach_header_64 *)header;
            command = (struct load_command *) (header64 + 1);
        }
#endif
        
        for (uint32_t i = 0; i < header->ncmds; i++){
            if (command->cmd == LC_UUID) {
                struct uuid_command *uuidCommand = (struct uuid_command *)command;
                memcpy(uuid, uuidCommand->uuid, sizeof(uuidCommand->uuid));
                
            } else if (command->cmd == LC_ID_DYLIB) {
                struct dylib_command *dylibCommand = (struct dylib_command *)command;
                version = dylibCommand->dylib.current_version;

#if defined(__LP64__) && __LP64__
           } else if (command->cmd == LC_SEGMENT_64) {
                struct segment_command_64 *segmentCommand = (struct segment_command_64 *)command;

                if (strncmp(segmentCommand->segname, SEG_TEXT, 16) == 0) {
                    size   = segmentCommand->vmsize;
                    vmaddr = segmentCommand->vmaddr;
                }
#else
            } else if (command->cmd == LC_SEGMENT) {
                struct segment_command *segmentCommand = (struct segment_command *)command;

                if (strncmp(segmentCommand->segname, SEG_TEXT, 16) == 0) {
                    size = segmentCommand->vmsize;
                    vmaddr = segmentCommand->vmaddr;
                }
#endif
            }

            command = (struct load_command *)((uintptr_t)command + command->cmdsize);
        }
    }
    
    CFDataRef uuidData = CFDataCreate(NULL, (const UInt8 *)uuid, sizeof(uuid));
    
    dispatch_sync(sDispatchQueue, ^{
        EscapePodBinaryImage *image = (EscapePodBinaryImage *)CFDictionaryGetValue(sStorage.uuidToBinaryImageMap, uuidData);
        BOOL needsPush = NO;
        
        if (!image) {
            image = calloc(1, sizeof(EscapePodBinaryImage));

            image->path = strdup(path);
            memcpy(image->uuid, CFDataGetBytePtr(uuidData), CFDataGetLength(uuidData));

            needsPush = YES;
        }

        image->addr       = addr;
        image->vmaddr     = vmaddr;
        image->size       = size;
        image->version    = version;
        image->cputype    = cputype;
        image->cpusubtype = cpusubtype;
        image->active     = 1;

        if (needsPush) {
            image->next = atomic_load(&sStorage.binaryImageHead);
            atomic_store(&sStorage.binaryImageHead, image);

            CFDictionarySetValue(sStorage.uuidToBinaryImageMap, uuidData, image);
        } 

        CFDictionarySetValue(sStorage.headerToBinaryImageMap, header, image);
    });
    
    CFRelease(uuidData);
}


static void HandleBinaryImageRemove(const struct mach_header *header, intptr_t vmaddr_slide)
{
    dispatch_sync(sDispatchQueue, ^{
        EscapePodBinaryImage *image = (EscapePodBinaryImage *)CFDictionaryGetValue(sStorage.headerToBinaryImageMap, header);
        CFDictionarySetValue(sStorage.headerToBinaryImageMap, header, 0);
        if (image) image->active = NO;
    });
}


static void HandleUncaughtException(NSException *exception)
{
    NSString *exceptionName       = [exception name];
    NSString *exceptionReason     = [exception reason];
    NSArray  *returnAddresses     = [exception callStackReturnAddresses];
    NSString *userInfoDescription = [[exception userInfo] description];
    
    NSCharacterSet *newlines = [NSCharacterSet newlineCharacterSet];
    
    NSMutableArray *lines = [NSMutableArray array];
    
    if ([exceptionName length]) {
        [lines addObject:[NSString stringWithFormat:@"excn: %@", exceptionName]];
    }

    if ([returnAddresses count]) {
        NSMutableArray *addressStrings = [NSMutableArray array];
        for (NSNumber *returnAddress in returnAddresses) {
            [addressStrings addObject:[NSString stringWithFormat:@"%lx", [returnAddress longValue]]];
        }
    
        NSString *joinedString = [addressStrings componentsJoinedByString:@","];
        [lines addObject:[NSString stringWithFormat:@"excs: %@", joinedString]];
    }

    if ([exceptionReason length]) {
        for (NSString *reasonLine in [exceptionReason componentsSeparatedByCharactersInSet:newlines]) {
            [lines addObject:[NSString stringWithFormat:@"excl: %@", reasonLine]];
        }
    }

    if ([userInfoDescription length]) {
        for (NSString *descriptionLine in [userInfoDescription componentsSeparatedByCharactersInSet:newlines]) {
            [lines addObject:[NSString stringWithFormat:@"excl: %@", descriptionLine]];
        }
    }
    
    [lines addObject:@""];
    
    NSString *joinedString = [lines componentsJoinedByString:@"\n"];
   
    dispatch_sync(sDispatchQueue, ^{
        if (atomic_load(&sStorage.exceptionString) == NULL) {
            char *newString = strdup([joinedString cStringUsingEncoding:NSASCIIStringEncoding]);
            atomic_store(&sStorage.exceptionString, newString);
        }
    });

    if (sExistingUncaughtExceptionHandler) {
        sExistingUncaughtExceptionHandler(exception);
    } else {
        abort();
    }
}


#pragma mark - Header

static void sSetupHeader()
{
    NSString *header = [NSString stringWithFormat:
        @"arch: %@\n"
        @"uuid: %@\n"
        @"name: %@\n"
        @"path: %@\n"
        @"bund: %@\n"
        @"vers: %@ (%@)\n"
        @"soft: %@ (%@)\n"
        @"hard: %@\n"
        @"hwmd: %@\n",
        MTSTelemetryGetString(MTSTelemetryStringArchitectureKey),
        MTSTelemetryGetUUIDString(),
        MTSTelemetryGetString(MTSTelemetryStringApplicationNameKey),
        MTSTelemetryGetString(MTSTelemetryStringApplicationPathKey),
        MTSTelemetryGetString(MTSTelemetryStringBundleIdentifierKey),
        MTSTelemetryGetString(MTSTelemetryStringApplicationVersionKey), MTSTelemetryGetString(MTSTelemetryStringApplicationBuildKey),
        MTSTelemetryGetString(MTSTelemetryStringOSVersionKey), MTSTelemetryGetString(MTSTelemetryStringOSBuildKey),
        MTSTelemetryGetString(MTSTelemetryStringHardwareMachineKey),
        MTSTelemetryGetString(MTSTelemetryStringHardwareModelKey)
    ];

    sStorage.headerString = strdup([header cStringUsingEncoding:NSASCIIStringEncoding]);
}


#pragma mark - Public Functions

void MTSEscapePodSetCustomString(UInt8 zeroToThree, NSString *string)
{
    if (zeroToThree >= CUSTOM_STRING_COUNT || !sDispatchQueue) {
        return;
    }
    
    dispatch_sync(sDispatchQueue, ^{
        const char *cString = [string cStringUsingEncoding:NSASCIIStringEncoding];
        if (!cString) cString = "";

        strncpy(sStorage.customString[zeroToThree], cString, CUSTOM_STRING_MAX_LEN);
        sStorage.customString[zeroToThree][CUSTOM_STRING_MAX_LEN - 1] = 0;
    });
}


OSStatus MTSEscapePodInstall()
{
    __block OSStatus result = noErr;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sDispatchQueue = dispatch_queue_create("MTSEscapePod", DISPATCH_QUEUE_SERIAL);

        @autoreleasepool {
            NSMutableString *randomString = [NSMutableString stringWithCapacity:64];
            for (int i = 0; i < 5; i++) {
                [randomString appendFormat:@"%08x", arc4random()];
            }

            NSString *basePath   = [MTSTelemetryGetBasePath() stringByAppendingPathComponent:sTelemetryName];
            NSString *activePath = [basePath stringByAppendingPathComponent:randomString];
            NSUInteger length = [activePath length] + 1;

            [[NSFileManager defaultManager] createDirectoryAtPath:basePath withIntermediateDirectories:YES attributes:NULL error:NULL];

            sActivePath = malloc(length);
            [activePath getCString:sActivePath maxLength:length encoding:NSUTF8StringEncoding];

            sSetupHeader();
        }
        
        sSignalStack.ss_size = MAX(MINSIGSTKSZ, 64 * 1024);
        sSignalStack.ss_sp   = malloc(sSignalStack.ss_size);
        sSignalStack.ss_flags = 0;

        if (!sSignalStack.ss_sp) {
            result = errno;
            return;
        }

        if (sigaltstack(&sSignalStack, 0) < 0) {
            result = errno;
            return;
        }

        for (NSInteger i = 0; i < sSignalsToCatchCount; i++) {
            struct sigaction action;
            memset(&action, 0, sizeof(action));

            action.sa_flags = SA_SIGINFO | SA_ONSTACK;
            sigemptyset(&action.sa_mask);
            action.sa_sigaction = &HandleSignal;

            if (sigaction(sSignalsToCatch[i], &action, NULL) != 0) {
                result = errno;
                return;
            }
        }
        
        for (NSInteger i = 0; i < CUSTOM_STRING_COUNT; i++) {
            memset(sStorage.customString[i], 0, CUSTOM_STRING_MAX_LEN);
        }

        sStorage.headerToBinaryImageMap = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
        sStorage.uuidToBinaryImageMap   = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, NULL);

        for (uint32_t i = 0, imageCount = _dyld_image_count(); i < imageCount; i++) {
            HandleBinaryImageAdd(_dyld_get_image_header(i), _dyld_get_image_vmaddr_slide(i));
        }

        _dyld_register_func_for_add_image(HandleBinaryImageAdd);
        _dyld_register_func_for_remove_image(HandleBinaryImageRemove);

        sExistingUncaughtExceptionHandler = NSGetUncaughtExceptionHandler();
        NSSetUncaughtExceptionHandler(&HandleUncaughtException);
    });

    return result;
}


void MTSEscapePodSetTelemetryName(NSString *telemetryName)
{
    sTelemetryName = telemetryName;
}


NSString *MTSEscapePodGetTelemetryName()
{
    return sTelemetryName;
}


void MTSEscapePodSetSignalCallback(MTSEscapePodSignalCallback callback)
{
    sSignalCallback = callback;
}


MTSEscapePodSignalCallback MTSEscapePodGetSignalCallback(void)
{
    return sSignalCallback;
}


void MTSEscapePodSetIgnoredThread(mach_port_t thread)
{
    sIgnoredThread = thread;
}


mach_port_t MTSEscapePodGetIgnoredThread(void)
{
    return sIgnoredThread;
}

