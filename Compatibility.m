//
//  Compatibility.m
//  Embrace
//
//  Created by Ricci Adams on 2014-09-20.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Compatibility.h"

#import <objc/runtime.h>
#include <dlfcn.h>


#define class_getInstanceMethod        _s0
#define class_addMethod                _s1
#define method_exchangeImplementations _s2
#define class_getMethodImplementation  _s3
#define method_getTypeEncoding         _s4
#define NSSelectorFromString           _s5

static Method (*class_getInstanceMethod)(Class cls, SEL name);
static BOOL   (*class_addMethod)(Class cls, SEL name, IMP imp, const char *types);
static void   (*method_exchangeImplementations)(Method m1, Method m2);
SEL (*NSSelectorFromString)(NSString *aSelectorName);
IMP (*class_getMethodImplementation)(Class cls, SEL name);
const char *(*method_getTypeEncoding)(Method m);




BOOL IsLegacyOS()
{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];

    if ([processInfo respondsToSelector:@selector(operatingSystemVersion)]) {
        NSOperatingSystemVersion version = [processInfo operatingSystemVersion];
        
        if (version.majorVersion > 10) {
            return NO;
        } else if (version.minorVersion >= 10) {
            return NO;
        }
    }

    return YES;
}


static inline void *sCompatibilityLookup(const UInt8 *inName)
{
    const UInt8 *i = inName;

    UInt8 buffer[1024];
    UInt8 *o = buffer;

    while (*i) { *o = (*i - 128); i++; o++; }
    *o = 0;

    return dlsym(RTLD_NEXT, (char *)buffer);
}


static void sInit()
{
    if (class_getInstanceMethod) return;

    UInt8 a[] = { 227,236,225,243,243,223,231,229,244,201,238,243,244,225,238,227,229,205,229,244,232,239,228,0 };
    UInt8 b[] = { 227,236,225,243,243,223,225,228,228,205,229,244,232,239,228,0 };
    UInt8 c[] = { 237,229,244,232,239,228,223,229,248,227,232,225,238,231,229,201,237,240,236,229,237,229,238,244,225,244,233,239,238,243,0 };
    UInt8 d[] = { 206,211,211,229,236,229,227,244,239,242,198,242,239,237,211,244,242,233,238,231,0 };
    UInt8 e[] = { 227,236,225,243,243,223,231,229,244,205,229,244,232,239,228,201,237,240,236,229,237,229,238,244,225,244,233,239,238,0 };
    UInt8 f[] = { 237,229,244,232,239,228,223,231,229,244,212,249,240,229,197,238,227,239,228,233,238,231,0 };

    class_getInstanceMethod = sCompatibilityLookup(a);
    class_addMethod = sCompatibilityLookup(b);
    method_exchangeImplementations = sCompatibilityLookup(c);
    NSSelectorFromString = sCompatibilityLookup(d);
    class_getMethodImplementation = sCompatibilityLookup(e);
    method_getTypeEncoding = sCompatibilityLookup(f);
}


extern NSString *EmbraceCompatibilityLookup(UInt32 unused, ...)
{
    sInit();

    va_list v;
    va_start(v, unused);
        
    char *name = va_arg(v, char *);
    
    UInt8 *inName = (UInt8 *)name;
    UInt8 *i      = inName;

    UInt8 buffer[1024];
    UInt8 *o = buffer;

    while (*i) { *o = (*i - 128); i++; o++; }
    *o = 0;

    return [[NSString alloc] initWithBytes:buffer length:(o - buffer) encoding:NSASCIIStringEncoding];
}


void EmbraceCompatibilityLookup_(UInt32 unused, ...)
{
    sInit();

    va_list v;
    va_start(v, unused);

    Class cls = NSClassFromString(va_arg(v, NSString *));
    if (!cls) return;

    SEL   originalSel = NSSelectorFromString(va_arg(v, NSString *));
    SEL   altSel      = NSSelectorFromString(va_arg(v, NSString *));

	Method originalMethod = class_getInstanceMethod(cls, originalSel);
	Method altMethod      = class_getInstanceMethod(cls, altSel);

    BOOL yn;

    if (originalMethod && altMethod) {

        yn = class_addMethod(cls,
					originalSel,
					class_getMethodImplementation(cls, originalSel),
					method_getTypeEncoding(originalMethod));

        yn = class_addMethod(cls,
					altSel,
					class_getMethodImplementation(cls, altSel),
					method_getTypeEncoding(altMethod));

        method_exchangeImplementations(class_getInstanceMethod(cls, originalSel), class_getInstanceMethod(cls, altSel));
    }

    va_end(v);
}


void EmbraceCheckCompatibility()
{
    if (IsLegacyOS()) return;

    // Check for DebugUseDarkerTrackWindow
    {
        // Pref name = DebugUseDarkerTrackWindow
        UInt8 n[] = { 196,229,226,245,231,213,243,229,196,225,242,235,229,242,212,242,225,227,235,215,233,238,228,239,247,0 };

        // class = NSVisualEffectView
        UInt8 c[] = { 206,211,214,233,243,245,225,236,197,230,230,229,227,244,214,233,229,247,0 };

        // original selector = _internalMaterialFromMaterial:
        UInt8 o[] = { 223,233,238,244,229,242,238,225,236,205,225,244,229,242,233,225,236,198,242,239,237,205,225,244,229,242,233,225,236,186,0 };

        // alt selector = embrace_compatibility0:
        UInt8 a[] = { 229,237,226,242,225,227,229,223,227,239,237,240,225,244,233,226,233,236,233,244,249,176,186,0 };
    
        if ([[NSUserDefaults standardUserDefaults] boolForKey:EmbraceGetPrivateName(n)]) {
            EmbraceSizzle(EmbraceGetPrivateName(c), EmbraceGetPrivateName(o), EmbraceGetPrivateName(a));
        }
    }
    
    // Check for DebugForceTranslucency
    {
        // Pref name = DebugForceTranslucency
        UInt8 n[] = { 196,229,226,245,231,198,239,242,227,229,212,242,225,238,243,236,245,227,229,238,227,249,0 };

        // class = NSVisualEffectView
        UInt8 c[] = { 206,211,214,233,243,245,225,236,197,230,230,229,227,244,214,233,229,247,0 };

        // original selector = _useAccessibilityColors
        UInt8 o[] = { 223,245,243,229,193,227,227,229,243,243,233,226,233,236,233,244,249,195,239,236,239,242,243,0 };

        // alt selector = embrace_compatibility1
        static UInt8 a[] = { 229,237,226,242,225,227,229,223,227,239,237,240,225,244,233,226,233,236,233,244,249,177,0 };

        if ([[NSUserDefaults standardUserDefaults] boolForKey:EmbraceGetPrivateName(n)]) {
            EmbraceSizzle(EmbraceGetPrivateName(c), EmbraceGetPrivateName(o), EmbraceGetPrivateName(a));
        }
    }
}

