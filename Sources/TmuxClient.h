#import <Foundation/Foundation.h>

#import "Models.h"

NS_ASSUME_NONNULL_BEGIN

@interface TmuxClient : NSObject

- (NSArray<TmuxWindow *> *)listWindows;
- (nullable NSString *)activeSessionName;
- (BOOL)selectWindowAtIndex:(NSInteger)windowIndex;
- (BOOL)createWindowInActiveSession;
- (BOOL)killWindowAtIndex:(NSInteger)windowIndex;

@end

NS_ASSUME_NONNULL_END
