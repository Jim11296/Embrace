//
//  IssueManager.h
//  Embrace
//
//  Created by Ricci Adams on 2016-05-29.
//  (c) 2016-2017 Ricci Adams.  All rights reserved.
//

#import <Foundation/Foundation.h>

@class Issue, Track;


typedef NS_ENUM(NSInteger, IssueType) {
    IssueTypeOverload,
    IssueTypeThermal,
    IssueTypeLowMemory,
    IssueTypeLowDiskSpace,
};


@interface IssueManager : NSObject

+ (instancetype) sharedInstance;

- (void) addOverloadIssueWithTrack: (Track *) track
                       timeElapsed: (NSTimeInterval) timeElapsed;


@property (nonatomic, strong) NSArray<Issue *> *issues;

@end




@interface Issue : NSObject

@property (nonatomic) IssueType type;
@property (nonatomic) NSDate *date;
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *problemText;
@property (nonatomic) NSString *solutionText;

// If non-zero, issue is a repeat for this set
@property (nonatomic) NSInteger count;

@end
