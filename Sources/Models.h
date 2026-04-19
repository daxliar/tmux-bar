#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TmuxWindow : NSObject

@property(nonatomic, assign) NSInteger index;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, assign, getter=isActive) BOOL active;

- (instancetype)initWithIndex:(NSInteger)index
                         name:(NSString *)name
                       active:(BOOL)active;

@end

NS_ASSUME_NONNULL_END
