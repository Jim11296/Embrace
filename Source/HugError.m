// (c) 2018-2020 Ricci Adams.  All rights reserved.

#import "HugError.h"

NSErrorDomain const HugErrorDomain = @"com.iccir.Hug";


static id sUserInfoValueProvider(NSError *error, NSErrorUserInfoKey userInfoKey)
{
    NSInteger code = [error code];
    
    NSString *description;
    NSString *suggestion;

    if (code == HugErrorOpenFailed) {
        description = NSLocalizedString(@"The file cannot be opened.", nil);

    } else if (code == HugErrorProtectedContent) {
        description = NSLocalizedString(@"The file cannot be read because it is protected.", nil);
        suggestion  = NSLocalizedString(@"Protected content can only be played with Apple Music.\n\nTo play this content, you will need to first remove the download and then purchase it from the iTunes Store.", nil);

    } else if (code ==  HugErrorConversionFailed) {
        description = NSLocalizedString(@"The file cannot be read because it is in an unknown format.", nil);

    } else if (code == HugErrorReadFailed) {
        description = NSLocalizedString(@"The file cannot be read.", nil);
    
    } else if (code == HugErrorReadTooSlow) {
        description = NSLocalizedString(@"The file could not be read fast enough.", nil);
    }
    
    if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
        return description;
    } else if ([userInfoKey isEqualToString:NSLocalizedRecoverySuggestionErrorKey]) {
        return suggestion;
    }
    
    return nil;
}


void load( void ) __attribute__ ((constructor));
void load( void )
{
    [NSError setUserInfoValueProviderForDomain:HugErrorDomain provider:^(NSError *error, NSErrorUserInfoKey userInfoKey) {
        return sUserInfoValueProvider(error, userInfoKey);
    }];
}

