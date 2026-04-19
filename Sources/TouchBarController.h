#import <AppKit/AppKit.h>

#import "Models.h"
#import "TmuxClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TouchBarController : NSObject <NSTouchBarDelegate>

- (instancetype)initWithTmuxClient:(TmuxClient *)tmuxClient;
- (NSTouchBar *)touchBar;
- (void)updateWindows:(NSArray<TmuxWindow *> *)windows;
- (void)clearWindows;
- (void)presentIfNeeded;
- (void)hideIfNeeded;

@end

NS_ASSUME_NONNULL_END
