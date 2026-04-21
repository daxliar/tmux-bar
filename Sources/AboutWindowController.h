#import <AppKit/AppKit.h>

@interface AboutWindowController : NSWindowController

+ (instancetype)sharedController;

- (void)showAboutPanel;

@end
