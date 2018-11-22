// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

extern void EmbraceCleanupLogs(NSURL *directoryURL);

extern void EmbraceLog(NSString *category, NSString *format, ...) NS_FORMAT_FUNCTION(2,3);

extern void EmbraceLogSetDirectory(NSString *logDirectory);
extern NSString *EmbraceLogGetDirectory(void);

extern void EmbraceLogReopenLogFile(void);

extern void _EmbraceLogMethod(const char *f);
#define EmbraceLogMethod() _EmbraceLogMethod(__PRETTY_FUNCTION__)


#ifdef __cplusplus
}
#endif
