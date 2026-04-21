#import "TouchBarController.h"
#import <objc/message.h>

static NSTouchBarItemIdentifier const kWindowsGroupIdentifier =
    @"com.daxliar.tmuxbar.windowsGroup";
static NSTouchBarItemIdentifier const kSeparatorIdentifier =
    @"com.daxliar.tmuxbar.separator";
static NSTouchBarItemIdentifier const kCreateIdentifier =
    @"com.daxliar.tmuxbar.create";
static NSTouchBarItemIdentifier const kBinIdentifier =
    @"com.daxliar.tmuxbar.bin";

// Cap the scrollable area so the create/bin buttons always remain visible
// on the right-hand side of the Touch Bar. 720pt fits comfortably within the
// usable Touch Bar area after the system control strip and our fixed buttons.
static CGFloat const kWindowsMaxWidth = 720.0;
static CGFloat const kTouchBarRowHeight = 30.0;

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
@property(nonatomic, assign) BOOL deleteMode;

@property(nonatomic, weak) NSStackView *windowsStack;
@property(nonatomic, strong) NSLayoutConstraint *windowsWidthConstraint;
@property(nonatomic, weak) NSButton *binButton;

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
    // The flexible space absorbs any empty area between the scrollable window
    // buttons on the left and our fixed controls on the right, so the
    // separator/+/trash trio sits flush against the system control strip.
    _internalTouchBar.defaultItemIdentifiers = @[
      kWindowsGroupIdentifier,
      NSTouchBarItemIdentifierFlexibleSpace,
      kSeparatorIdentifier,
      kCreateIdentifier,
      kBinIdentifier,
    ];
  }
  return self;
}

- (NSTouchBar *)touchBar {
  return self.internalTouchBar;
}

- (void)updateWindows:(NSArray<TmuxWindow *> *)windows {
  self.windows = windows ?: @[];
  // If the active windows disappear there's nothing to delete anymore, so
  // make sure we leave delete mode to avoid a stale red bin.
  if (self.windows.count == 0 && self.deleteMode) {
    self.deleteMode = NO;
    [self refreshBinButtonAppearance];
  }
  [self rebuildWindowsStack];
  if (self.windows.count > 0) {
    [self presentIfNeeded];
  } else {
    [self hideIfNeeded];
  }
}

- (void)clearWindows {
  [self updateWindows:@[]];
}

#pragma mark - NSTouchBarDelegate

- (nullable NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar
                makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier {
  if ([identifier isEqualToString:kWindowsGroupIdentifier]) {
    return [self makeWindowsGroupItem:identifier];
  }
  if ([identifier isEqualToString:kSeparatorIdentifier]) {
    return [self makeSeparatorItem:identifier];
  }
  if ([identifier isEqualToString:kCreateIdentifier]) {
    return [self makeCreateItem:identifier];
  }
  if ([identifier isEqualToString:kBinIdentifier]) {
    return [self makeBinItem:identifier];
  }
  return nil;
}

#pragma mark - Windows group (scrollable)

- (NSTouchBarItem *)makeWindowsGroupItem:(NSTouchBarItemIdentifier)identifier {
  NSCustomTouchBarItem *item =
      [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];

  NSStackView *stack = [[NSStackView alloc] init];
  stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  stack.spacing = 8.0;
  stack.alignment = NSLayoutAttributeCenterY;
  stack.edgeInsets = NSEdgeInsetsMake(0, 2, 0, 2);
  stack.translatesAutoresizingMaskIntoConstraints = NO;

  NSScrollView *scroll = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(0, 0, 1.0, kTouchBarRowHeight)];
  scroll.translatesAutoresizingMaskIntoConstraints = NO;
  scroll.hasHorizontalScroller = NO;
  scroll.hasVerticalScroller = NO;
  scroll.drawsBackground = NO;
  scroll.borderType = NSNoBorder;
  scroll.horizontalScrollElasticity = NSScrollElasticityAllowed;
  scroll.verticalScrollElasticity = NSScrollElasticityNone;
  scroll.automaticallyAdjustsContentInsets = NO;
  scroll.documentView = stack;

  // Pin the stack to the content view so horizontal scrolling works naturally
  // and the buttons stay vertically centered in the Touch Bar row.
  NSClipView *clip = scroll.contentView;
  [NSLayoutConstraint activateConstraints:@[
    [stack.leadingAnchor constraintEqualToAnchor:clip.leadingAnchor],
    [stack.topAnchor constraintEqualToAnchor:clip.topAnchor],
    [stack.bottomAnchor constraintEqualToAnchor:clip.bottomAnchor],
    [stack.heightAnchor constraintEqualToConstant:kTouchBarRowHeight],
  ]];

  self.windowsWidthConstraint =
      [scroll.widthAnchor constraintEqualToConstant:1.0];
  self.windowsWidthConstraint.active = YES;
  [scroll.heightAnchor constraintEqualToConstant:kTouchBarRowHeight].active = YES;

  self.windowsStack = stack;
  item.view = scroll;

  [self populateWindowsStack];
  return item;
}

- (void)populateWindowsStack {
  NSStackView *stack = self.windowsStack;
  if (stack == nil) {
    return;
  }

  for (NSView *subview in [stack.arrangedSubviews copy]) {
    [stack removeArrangedSubview:subview];
    [subview removeFromSuperview];
  }

  for (TmuxWindow *window in self.windows) {
    NSButton *button = [self makeWindowButton:window];
    [stack addArrangedSubview:button];
  }

  [self updateWindowsScrollWidth];
}

- (void)rebuildWindowsStack {
  // The Touch Bar lazily caches items, so if the group item hasn't been
  // materialised yet we just wait until -touchBar:makeItemForIdentifier:
  // builds it; it will call -populateWindowsStack itself.
  if (self.windowsStack == nil) {
    return;
  }
  [self populateWindowsStack];
}

- (void)updateWindowsScrollWidth {
  NSStackView *stack = self.windowsStack;
  if (stack == nil || self.windowsWidthConstraint == nil) {
    return;
  }
  [stack layoutSubtreeIfNeeded];
  CGFloat content = stack.fittingSize.width;
  // Keep a minimum width so the layout engine doesn't collapse the scroll
  // area to zero while we momentarily have no buttons.
  CGFloat width = MIN(MAX(content, 1.0), kWindowsMaxWidth);
  self.windowsWidthConstraint.constant = width;
}

- (NSButton *)makeWindowButton:(TmuxWindow *)window {
  NSString *title = [self titleForWindow:window];
  NSButton *button = [NSButton buttonWithTitle:title
                                        target:self
                                        action:@selector(windowButtonTapped:)];
  button.tag = window.index;
  button.bezelColor =
      TmuxBarBezelColorForWindow(window.index, window.isActive);
  return button;
}

- (NSString *)titleForWindow:(TmuxWindow *)window {
  NSString *base =
      [NSString stringWithFormat:@"%ld:%@", (long)window.index, window.name];
  if (self.deleteMode) {
    // Prepend an "X" mark so the user can see which button will delete.
    return [@"\u2715 " stringByAppendingString:base];
  }
  return base;
}

#pragma mark - Separator

- (NSTouchBarItem *)makeSeparatorItem:(NSTouchBarItemIdentifier)identifier {
  NSCustomTouchBarItem *item =
      [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];

  NSView *container = [[NSView alloc] init];
  container.translatesAutoresizingMaskIntoConstraints = NO;

  NSView *line = [[NSView alloc] init];
  line.translatesAutoresizingMaskIntoConstraints = NO;
  line.wantsLayer = YES;
  line.layer.backgroundColor =
      [NSColor colorWithWhite:0.55 alpha:1.0].CGColor;
  line.layer.cornerRadius = 1.0;
  [container addSubview:line];

  [NSLayoutConstraint activateConstraints:@[
    [container.widthAnchor constraintEqualToConstant:12.0],
    [container.heightAnchor constraintEqualToConstant:kTouchBarRowHeight],
    [line.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
    [line.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
    [line.widthAnchor constraintEqualToConstant:2.0],
    [line.heightAnchor constraintEqualToConstant:18.0],
  ]];

  item.view = container;
  return item;
}

#pragma mark - Create button

- (NSTouchBarItem *)makeCreateItem:(NSTouchBarItemIdentifier)identifier {
  NSCustomTouchBarItem *item =
      [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];

  NSImage *image =
      [NSImage imageWithSystemSymbolName:@"plus"
                accessibilityDescription:@"New tmux Window"];
  NSButton *button = [NSButton buttonWithImage:image
                                        target:self
                                        action:@selector(createButtonTapped:)];
  button.imagePosition = NSImageOnly;
  button.bezelColor =
      [NSColor colorWithSRGBRed:0.18 green:0.75 blue:0.35 alpha:1.0];
  button.toolTip = @"Create a new tmux window";
  item.view = button;
  return item;
}

#pragma mark - Bin (toggle delete) button

- (NSTouchBarItem *)makeBinItem:(NSTouchBarItemIdentifier)identifier {
  NSCustomTouchBarItem *item =
      [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];

  NSImage *image =
      [NSImage imageWithSystemSymbolName:@"trash"
                accessibilityDescription:@"Toggle delete mode"];
  NSButton *button = [NSButton buttonWithImage:image
                                        target:self
                                        action:@selector(binButtonTapped:)];
  button.imagePosition = NSImageOnly;
  button.toolTip = @"Toggle delete mode. While on, tap a window to kill it.";
  self.binButton = button;
  item.view = button;
  [self refreshBinButtonAppearance];
  return item;
}

- (void)refreshBinButtonAppearance {
  NSButton *button = self.binButton;
  if (button == nil) {
    return;
  }
  if (self.deleteMode) {
    button.bezelColor =
        [NSColor colorWithSRGBRed:0.95 green:0.25 blue:0.25 alpha:1.0];
  } else {
    button.bezelColor =
        [NSColor colorWithSRGBRed:0.55 green:0.22 blue:0.22 alpha:1.0];
  }
}

#pragma mark - Button actions

- (void)windowButtonTapped:(NSButton *)sender {
  NSInteger index = sender.tag;
  if (self.deleteMode) {
    BOOL ok = [self.tmuxClient killWindowAtIndex:index];
    // Always leave delete mode after a tap to avoid accidental repeat kills.
    self.deleteMode = NO;
    [self refreshBinButtonAppearance];
    if (!ok) {
      // Still rebuild so the X prefix is removed even if tmux failed.
      [self rebuildWindowsStack];
      return;
    }
    NSArray<TmuxWindow *> *windows = [self.tmuxClient listWindows];
    [self updateWindows:windows];
    return;
  }

  BOOL ok = [self.tmuxClient selectWindowAtIndex:index];
  if (!ok) {
    return;
  }
  NSArray<TmuxWindow *> *windows = [self.tmuxClient listWindows];
  [self updateWindows:windows];
}

- (void)createButtonTapped:(NSButton *)sender {
  BOOL ok = [self.tmuxClient createWindowInActiveSession];
  if (!ok) {
    return;
  }
  NSArray<TmuxWindow *> *windows = [self.tmuxClient listWindows];
  [self updateWindows:windows];
}

- (void)binButtonTapped:(NSButton *)sender {
  self.deleteMode = !self.deleteMode;
  [self refreshBinButtonAppearance];
  [self rebuildWindowsStack];
}

#pragma mark - System modal presentation

- (void)presentIfNeeded {
  if (self.presented) {
    return;
  }
  // Uses private class methods via objc_msgSend to present a system modal Touch Bar.
  // Passing nil as the systemTrayItemIdentifier suppresses the close ("X") button
  // that the system would otherwise add on the left side of the bar.
  Class touchBarClass = [NSTouchBar class];
  SEL presentSEL = NSSelectorFromString(@"presentSystemModalTouchBar:systemTrayItemIdentifier:");
  if ([touchBarClass respondsToSelector:presentSEL]) {
    void (*presentFn)(id, SEL, NSTouchBar *, NSTouchBarItemIdentifier) =
        (void (*)(id, SEL, NSTouchBar *, NSTouchBarItemIdentifier))objc_msgSend;
    presentFn(touchBarClass, presentSEL, self.internalTouchBar, nil);
    self.presented = YES;
  } else {
    NSLog(@"[tmux-bar] presentSystemModalTouchBar selector unavailable");
  }
}

- (void)hideIfNeeded {
  if (!self.presented) {
    return;
  }
  // Mirror the present path. With no system tray identifier, the dismiss call
  // takes no argument, so we also try the no-argument minimise selector first.
  Class touchBarClass = [NSTouchBar class];
  SEL minimizeNoArg = NSSelectorFromString(@"minimizeSystemModalTouchBar");
  SEL minimizeWithId = NSSelectorFromString(@"minimizeSystemModalTouchBar:");
  if ([touchBarClass respondsToSelector:minimizeNoArg]) {
    void (*hideFn)(id, SEL) = (void (*)(id, SEL))objc_msgSend;
    hideFn(touchBarClass, minimizeNoArg);
  } else if ([touchBarClass respondsToSelector:minimizeWithId]) {
    void (*hideFn)(id, SEL, NSTouchBarItemIdentifier) =
        (void (*)(id, SEL, NSTouchBarItemIdentifier))objc_msgSend;
    hideFn(touchBarClass, minimizeWithId, nil);
  }
  self.presented = NO;
}

@end
