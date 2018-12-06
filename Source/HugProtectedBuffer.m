// (c) 2015-2018 Ricci Adams.  All rights reserved.

#import "HugProtectedBuffer.h"
#import "HugUtils.h"


@implementation HugProtectedBuffer {
    void        *_totalBytes;
    vm_size_t    _totalLength;
    size_t       _pageSize;

    UInt8       *_bytes;
    
    BOOL _locked;
    BOOL _protected;
}



- (id) initWithCapacity:(NSUInteger)capacity
{
    if ((self = [super init])) {
        _pageSize    = sysconf(_SC_PAGESIZE);
        _totalLength = capacity + (2 * _pageSize);
                
        if (vm_allocate(mach_task_self(), (vm_address_t *)&_totalBytes, _totalLength, VM_FLAGS_ANYWHERE) != 0) {
            self = nil;
            return nil;
        }
        
        memset(_totalBytes,                              0, _pageSize);
        memset(_totalBytes + (_totalLength - _pageSize), 0, _pageSize);
        
        _bytes = _totalBytes + _pageSize;

        return self;
    }
    
    return self;
}


- (void) dealloc
{
    if (_protected) {
        mprotect((void *)_totalBytes, _totalLength, PROT_READ|PROT_WRITE);
    }

    if (_locked) {
        munlock((void *)_totalBytes, _totalLength);
    }

    if (_totalBytes) {
        vm_deallocate(mach_task_self(), (vm_address_t)_totalBytes, _totalLength);
    }

    _totalBytes   = NULL;
    _bytes        = NULL;
    _totalLength = 0;
}


- (void) lock
{
    if (!_locked) {
        _locked = (mlock(_totalBytes, _totalLength) == noErr);
    }

    if (!_protected) {
        _protected = (mprotect(_totalBytes, _totalLength, PROT_READ) == noErr);
    }

    HugLog(@"Buffer %p - locked: %ld, protected: %ld", _bytes, (long)_locked, (long)_protected);
}


- (void *) bytes
{
    return _bytes;
}


@end
