#import "TouchBarController.h"
#import <objc/message.h>

static NSTouchBarItemIdentifier const kSystemTrayIdentifier =
    @"com.daxliar.tmuxbar.tray";

/// Active window gets a per-index vivid bezel; inactive uses nil (default grey).
static NSColor *TmuxBarBezelColorForWindow(NSInteger index, BOOL active) {
  if (!active) {
    return nil;
  }
  static NSArray<NSColor *> *vivid = nil;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    vivid = @[
        [NSColor colorWithSRGBRed:0.20 green:0.52 blue:0.98 alpha:1.0],  // dev blue
        [NSColor colorWithSRGBRed:0.98 green:0.72 blue:0.12 alpha:1.0],  // debug gold
        [NSColor colorWithSRGBRed:0.18 green:0.78 blue:0.58 alpha:1.0],  // log mint
        [NSColor colorWithSRGBRed:0.72 green:0.38 blue:0.95 alpha:1.0],  // violet
        [NSColor colorWithSRGBRed:0.98 green:0.42 blue:0.45 alpha:1.0],  // coral
        [NSColor colorWithSRGBRed:0.35 green:0.82 blue:0.95 alpha:1.0],  // sky
    ];
  });
  NSInteger n = (NSInteger)vivid.count;
  NSInteger i = ((index % n) + n) % n;
  return vivid[i];
}

@interface TouchBarController ()

@property(nonatomic, strong) TmuxClient *tmuxClient;
@property(nonatomic, strong) NSTouchBar *internalTouchBar;
@property(nonatomic, copy) NSArray<TmuxWindow *> *windows;
@property(nonatomic, assign) BOOL presented;

@end

@implementation TouchBarController

- (instancetype)initWithTmuxClient:(TmuxClient *)tmuxClient {
  self = [super init];
  if (self) {
    _tmuxClient = tmuxClient;
    _windows = @[];
    _internalTouchBar = [[NSTouchBar alloc] init];
    _internalTouchBar.delegate = self;
    _internalTouchBar.customizationIdentifier =
        @"com.daxliar.tmuxbar.touchbar";
    _internalTouchBar.defaultItemIdentifiers = @[];
  }
  return self;
}

- (NSTouchBar *)touchBar {
  return self.internalTouchBar;
}

- (void)updateWindows:(NSArray<TmuxWindow *> *)windows {
  self.windows = windows ?: @[];
  self.internalTouchBar.defaultItemIdentifiers = [self itemIdentifiers];
  [self refreshVisibleButtonState];
  if (self.windows.count > 0) {
    [self presentIfNeeded];
  } else {
    [self hideIfNeeded];
  }
}

- (void)clearWindows {
  [self updateWindows:@[]];
}

- (NSArray<NSTouchBarItemIdentifier> *)itemIdentifiers {
  NSMutableArray<NSTouchBarItemIdentifier> *ids = [NSMutableArray array];
  for (TmuxWindow *window in self.windows) {
    [ids addObject:[self identifierForWindowIndex:window.index]];
  }
  return ids;
}

- (NSTouchBarItemIdentifier)identifierForWindowIndex:(NSInteger)windowIndex {
  return [NSString stringWithFormat:@"com.daxliar.tmuxbar.window.%ld",
                                    (long)windowIndex];
}

- (nullable NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar
                makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier {
  for (TmuxWindow *window in self.windows) {
    if ([[self identifierForWindowIndex:window.index] isEqualToString:identifier]) {
      NSCustomTouchBarItem *item =
          [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];

      NSString *title = [NSString stringWithFormat:@"%ld:%@", (long)window.index,
                                                   window.name];
      NSButton *button = [NSButton buttonWithTitle:title
                                            target:self
                                            action:@selector(windowButtonTapped:)];
      button.tag = window.index;
      button.bezelColor =
          TmuxBarBezelColorForWindow(window.index, window.isActive);
      item.view = button;
      return item;
    }
  }

  return nil;
}

- (void)windowButtonTapped:(NSButton *)sender {
  BOOL ok = [self.tmuxClient selectWindowAtIndex:sender.tag];
  if (!ok) {
    return;
  }

  // Fast visual sync instead of waiting for the periodic refresh.
  NSArray<TmuxWindow *> *windows = [self.tmuxClient listWindows];
  [self updateWindows:windows];
}

- (void)refreshVisibleButtonState {
  for (TmuxWindow *window in self.windows) {
    NSTouchBarItemIdentifier identifier =
        [self identifierForWindowIndex:window.index];
    NSTouchBarItem *item = [self.internalTouchBar itemForIdentifier:identifier];
    if (![item isKindOfClass:[NSCustomTouchBarItem class]]) {
      continue;
    }

    NSCustomTouchBarItem *customItem = (NSCustomTouchBarItem *)item;
    if (![customItem.view isKindOfClass:[NSButton class]]) {
      continue;
    }

    NSButton *button = (NSButton *)customItem.view;
    button.title = [NSString stringWithFormat:@"%ld:%@", (long)window.index,
                                              window.name];
    button.tag = window.index;
    button.bezelColor =
        TmuxBarBezelColorForWindow(window.index, window.isActive);
  }
}

- (void)presentIfNeeded {
  if (self.presented) {
    return;
  }
  // Uses private class methods via objc_msgSend to present a system modal Touch Bar.
  Class touchBarClass = [NSTouchBar class];
  SEL presentSEL = NSSelectorFromString(@"presentSystemModalTouchBar:systemTrayItemIdentifier:");
  if ([touchBarClass respondsToSelector:presentSEL]) {
    void (*presentFn)(id, SEL, NSTouchBar *, NSTouchBarItemIdentifier) =
        (void (*)(id, SEL, NSTouchBar *, NSTouchBarItemIdentifier))objc_msgSend;
    presentFn(touchBarClass, presentSEL, self.internalTouchBar, kSystemTrayIdentifier);
    self.presented = YES;
  } else {
    NSLog(@"[tmux-bar] presentSystemModalTouchBar selector unavailable");
  }
}

- (void)hideIfNeeded {
  if (!self.presented) {
    return;
  }
  // Mirror present path and dismiss the same system tray identifier.
  Class touchBarClass = [NSTouchBar class];
  SEL minimizeSEL = NSSelectorFromString(@"minimizeSystemModalTouchBar:");
  if ([touchBarClass respondsToSelector:minimizeSEL]) {
    void (*hideFn)(id, SEL, NSTouchBarItemIdentifier) =
        (void (*)(id, SEL, NSTouchBarItemIdentifier))objc_msgSend;
    hideFn(touchBarClass, minimizeSEL, kSystemTrayIdentifier);
  }
  self.presented = NO;
}

@end
