//
//  TrackData.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-14.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TrackData;
typedef void (^TrackDataReadyCallback)(TrackData *trackData);


@interface TrackData : NSObject

@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) AudioStreamBasicDescription streamDescription;

- (void) addReadyCallback:(TrackDataReadyCallback)callback;
@property (nonatomic, readonly, getter=isReady) BOOL ready;

@end
