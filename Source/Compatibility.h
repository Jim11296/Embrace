//
//  Compatibility.h
//  Embrace
//
//  Created by Ricci Adams on 2014-09-20.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *EmbraceCompatibilityLookup(UInt32 unused, ...);
extern void EmbraceCompatibilityLookup_(UInt32 unused, ...);

static inline NSString *EmbraceGetPrivateName(const UInt8 *obfuscatedSelName)
{
    return EmbraceCompatibilityLookup(0, obfuscatedSelName);
}

static inline void EmbraceSizzle(NSString *cls, NSString *originalSelName, NSString *altSelName)
{
    EmbraceCompatibilityLookup_(0, cls, originalSelName, altSelName);
}

extern void EmbraceCheckCompatibility(void);


