//
//  HostStatistics.h
//  Embrace
//
//  Created by Ricci Adams on 2016-05-24.
//  (c) 2016-2017 Ricci Adams.  All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HostStatistics : NSObject


@property (nonatomic, readonly) NSUInteger usedMemory;
@property (nonatomic, readonly) NSUInteger freeMemory;
@property (nonatomic, readonly) NSUInteger totalMemory;
//
//
//
//    usage.usedRam = (vm_stat.active_count + vm_stat.inactive_count + vm_stat.wire_count) * pageSize;
//    usage.activeRam = vm_stat.active_count * pageSize;
//    usage.inactiveRam = vm_stat.inactive_count * pageSize;
//
//
//- (NSUInteger) usedMemory;
//- (NSUInteger) freeMemory;
//- (NSUInteger) totalMemory;
//
//
//- (NSString *) usedMemoryString;
//


@end
