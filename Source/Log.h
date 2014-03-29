//
//  Log.h
//  Embrace
//
//  Created by Ricci Adams on 2014-03-26.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>


extern void EmbraceOpenLogFile();
extern void EmbraceLog(NSString *category, NSString *format, ...) NS_FORMAT_FUNCTION(2,3);

extern void _EmbraceLogMethod(const char *f);
#define EmbraceLogMethod() _EmbraceLogMethod(__PRETTY_FUNCTION__)
