//
//  HugError.h
//  Embrace
//
//  Created by Ricci Adams on 2018-12-08.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSErrorDomain const HugErrorDomain;

NS_ERROR_ENUM(HugErrorDomain) {
    HugErrorOpenFailed        = 1000,
    HugErrorProtectedContent  = 1001,
    HugErrorConversionFailed  = 1002,
    HugErrorReadFailed        = 1003,
    HugErrorReadTooSlow       = 1004,
    HugErrorInvalidFrameCount = 1005
};
