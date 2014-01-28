//
//  Limiter.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-27.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>


#ifdef __cplusplus
#define EXTERN extern "C"
#else
#define EXTERN extern
#endif

EXTERN void LimiterGetComponentDescription(AudioComponentDescription *outDesc);

#undef EXTERN
