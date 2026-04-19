#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FocusWatcher : NSObject

@property(nonatomic, copy, readonly) NSString *frontmostBundleIdentifier;

- (void)start;
- (BOOL)isTerminalFocused;

@end

NS_ASSUME_NONNULL_END
