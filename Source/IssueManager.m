// (c) 2016-2020 Ricci Adams.  All rights reserved.


#import "IssueManager.h"


@implementation IssueManager {
    NSMutableArray *_issues;
}

+ (instancetype) sharedInstance
{
    static IssueManager *sSharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sSharedInstance = [[IssueManager alloc] init];
    });
    
    return sSharedInstance;
}


- (id) init
{
    if ((self = [super init])) {
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(_performPeriodicChecks) userInfo:nil repeats:YES];
        [timer setTolerance:1.0];
        
        _issues = [NSMutableArray array];
    }
    
    return self;
}


#pragma mark - Private Methods

- (void) _addIssue:(Issue *)issue
{
    if (!issue) return;
    [_issues addObject:issue];
}


- (void) _removeIssuesWithType:(IssueType)type
{
    NSMutableArray *issues = [NSMutableArray array];
    
    for (Issue *issue in _issues) {
        if ([issue type] != type) {
            [issues addObject:issue];
        }
    }
    
    _issues = issues;
}


- (Issue *) _issueWithType:(IssueType)type
{
    for (Issue *issue in _issues) {
        if ([issue type] == type) {
            return issue;
        }
    }

    return nil;
}


- (void) _performPeriodicChecks
{
    [self _checkDiskSpace];
}


- (void) _checkDiskSpace
{
    void (^checkPath)(NSString *) = ^(NSString *path) {
        NSError *error = nil;
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error:&error];
   

        NSString *volumeName;
        [[NSURL fileURLWithPath:path] getResourceValue:&volumeName forKey:NSURLVolumeNameKey error:&error];

        NSInteger freeNodes = [[attributes objectForKey:NSFileSystemFreeNodes] integerValue];
        NSInteger freeSize  = [[attributes objectForKey:NSFileSystemFreeSize]  integerValue];

        if ((freeNodes < 512) || (freeSize < ((SInt64)1024 * 1024 * 1024 * 2))) {
            Issue *issue = [[Issue alloc] init];

            NSString *problemFormat  = NSLocalizedString(@"The disk '%@' is running low on space.",     nil);

            [issue setType:IssueTypeLowDiskSpace];
            [issue setDate:[NSDate date]];
            [issue setTitle:NSLocalizedString(@"Low Disk Space", nil)];
            [issue setProblemText:[NSString stringWithFormat:problemFormat, volumeName]];
            [issue setSolutionText:NSLocalizedString(@"Try removing files and emptying the Trash.", nil)];
            
            [self _removeIssuesWithType:IssueTypeLowDiskSpace];
            [self _addIssue:issue];
        }
    };

    checkPath(@"/");
    checkPath(GetApplicationSupportDirectory());
}


#pragma mark - Public Methods

- (void) addOverloadIssueWithTrack:(Track *)track timeElapsed:(NSTimeInterval)timeElapsed
{
    Issue *existingIssue = [self _issueWithType:IssueTypeOverload];
    Issue *issue = [[Issue alloc] init];

    [issue setType:IssueTypeOverload];
    [issue setTitle:NSLocalizedString(@"Audio Overload", nil)];
    [issue setProblemText:NSLocalizedString(@"An audio overload occurred. This may have caused an audible glitch or distortion.", nil)];
    [issue setCount:[existingIssue count] + 1];

    [issue setSolutionText:NSLocalizedString(@"Audio overloads are usually caused when another program uses too many resources and prevents Embrace from delivering sound data on time. Quit other programs or increase the number of Frames in Preferences.", nil)];
    
    [self _removeIssuesWithType:IssueTypeOverload];
    [self _addIssue:issue];

}



@end



@implementation Issue
@end
