#import "Models.h"

@implementation TmuxWindow

- (instancetype)initWithIndex:(NSInteger)index
                         name:(NSString *)name
                       active:(BOOL)active {
  self = [super init];
  if (self) {
    _index = index;
    _name = [name copy];
    _active = active;
  }
  return self;
}

@end
