#import "AboutWindowController.h"

#ifndef TMUX_BAR_VERSION
#define TMUX_BAR_VERSION "0.0.0"
#endif

#ifndef TMUX_BAR_BUILD
#define TMUX_BAR_BUILD "0"
#endif

#ifndef TMUX_BAR_COMMIT
#define TMUX_BAR_COMMIT "unknown"
#endif

static NSString *const kTmuxBarRepoURL = @"https://github.com/daxliar/tmux-bar";

@interface AboutWindowController ()

@property(nonatomic, copy) NSString *commitString;

@end

@implementation AboutWindowController

+ (instancetype)sharedController {
  static AboutWindowController *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[AboutWindowController alloc] init];
  });
  return instance;
}

- (instancetype)init {
  const CGFloat windowWidth = 360.0;
  const CGFloat windowHeight = 460.0;
  NSRect frame = NSMakeRect(0, 0, windowWidth, windowHeight);
  NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable;
  NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                 styleMask:style
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO];
  window.title = @"About tmux-bar";
  window.releasedWhenClosed = NO;
  window.titlebarAppearsTransparent = YES;
  window.titleVisibility = NSWindowTitleHidden;
  window.movableByWindowBackground = YES;

  self = [super initWithWindow:window];
  if (self) {
    [self buildContent];
  }
  return self;
}

- (void)buildContent {
  NSView *content = self.window.contentView;
  content.wantsLayer = YES;

  NSImageView *icon = [[NSImageView alloc] init];
  icon.image = [NSApp applicationIconImage];
  icon.imageScaling = NSImageScaleProportionallyUpOrDown;
  icon.translatesAutoresizingMaskIntoConstraints = NO;
  [content addSubview:icon];

  NSTextField *title = [NSTextField labelWithString:@"tmux-bar"];
  title.font = [NSFont systemFontOfSize:28 weight:NSFontWeightBold];
  title.alignment = NSTextAlignmentCenter;
  title.translatesAutoresizingMaskIntoConstraints = NO;
  [content addSubview:title];

  NSTextField *tagline = [NSTextField wrappingLabelWithString:
      @"Native macOS menu bar helper that puts your\ntmux windows on the Touch Bar."];
  tagline.font = [NSFont systemFontOfSize:12];
  tagline.textColor = [NSColor secondaryLabelColor];
  tagline.alignment = NSTextAlignmentCenter;
  tagline.translatesAutoresizingMaskIntoConstraints = NO;
  [content addSubview:tagline];

  NSGridView *grid = [NSGridView gridViewWithNumberOfColumns:2 rows:3];
  grid.rowSpacing = 4;
  grid.columnSpacing = 10;
  grid.translatesAutoresizingMaskIntoConstraints = NO;

  NSString *versionString = @TMUX_BAR_VERSION;
  NSString *buildString = @TMUX_BAR_BUILD;
  self.commitString = @TMUX_BAR_COMMIT;

  [grid cellAtColumnIndex:0 rowIndex:0].contentView = [self rowLabel:@"Version"];
  [grid cellAtColumnIndex:1 rowIndex:0].contentView = [self rowValue:versionString];
  [grid cellAtColumnIndex:0 rowIndex:1].contentView = [self rowLabel:@"Build"];
  [grid cellAtColumnIndex:1 rowIndex:1].contentView = [self rowValue:buildString];
  [grid cellAtColumnIndex:0 rowIndex:2].contentView = [self rowLabel:@"Commit"];
  [grid cellAtColumnIndex:1 rowIndex:2].contentView = [self rowCommit:self.commitString];

  NSGridColumn *labelsColumn = [grid columnAtIndex:0];
  labelsColumn.xPlacement = NSGridCellPlacementTrailing;
  NSGridColumn *valuesColumn = [grid columnAtIndex:1];
  valuesColumn.xPlacement = NSGridCellPlacementLeading;

  [content addSubview:grid];

  NSButton *readmeButton = [NSButton buttonWithTitle:@"README"
                                              target:self
                                              action:@selector(openReadme:)];
  readmeButton.bezelStyle = NSBezelStyleRounded;
  readmeButton.translatesAutoresizingMaskIntoConstraints = NO;

  NSButton *githubButton = [NSButton buttonWithTitle:@"GitHub"
                                              target:self
                                              action:@selector(openGitHub:)];
  githubButton.bezelStyle = NSBezelStyleRounded;
  githubButton.translatesAutoresizingMaskIntoConstraints = NO;

  NSStackView *buttons = [NSStackView stackViewWithViews:@[ readmeButton, githubButton ]];
  buttons.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  buttons.spacing = 12;
  buttons.distribution = NSStackViewDistributionEqualSpacing;
  buttons.translatesAutoresizingMaskIntoConstraints = NO;
  [content addSubview:buttons];

  [NSLayoutConstraint activateConstraints:@[
    [icon.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
    [icon.topAnchor constraintEqualToAnchor:content.topAnchor constant:48],
    [icon.widthAnchor constraintEqualToConstant:128],
    [icon.heightAnchor constraintEqualToConstant:128],

    [title.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
    [title.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:16],

    [tagline.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
    [tagline.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
    [tagline.widthAnchor constraintLessThanOrEqualToAnchor:content.widthAnchor constant:-40],

    [grid.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
    [grid.topAnchor constraintEqualToAnchor:tagline.bottomAnchor constant:28],

    [buttons.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
    [buttons.topAnchor constraintEqualToAnchor:grid.bottomAnchor constant:18],
    [buttons.bottomAnchor constraintLessThanOrEqualToAnchor:content.bottomAnchor constant:-20],
  ]];
}

- (NSTextField *)rowLabel:(NSString *)text {
  NSTextField *label = [NSTextField labelWithString:text];
  label.font = [NSFont systemFontOfSize:12];
  label.textColor = [NSColor secondaryLabelColor];
  return label;
}

- (NSTextField *)rowValue:(NSString *)text {
  NSTextField *value = [NSTextField labelWithString:text];
  value.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
  value.textColor = [NSColor labelColor];
  value.selectable = YES;
  return value;
}

- (NSView *)rowCommit:(NSString *)commit {
  NSButton *link = [NSButton buttonWithTitle:commit
                                      target:self
                                      action:@selector(openCommit:)];
  link.bezelStyle = NSBezelStyleInline;
  link.bordered = NO;
  link.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
  link.contentTintColor = [NSColor linkColor];
  NSMutableAttributedString *attr = [[NSMutableAttributedString alloc]
      initWithString:commit
          attributes:@{
            NSForegroundColorAttributeName : [NSColor linkColor],
            NSFontAttributeName : [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular],
          }];
  link.attributedTitle = attr;
  link.focusRingType = NSFocusRingTypeNone;
  NSTrackingArea *area = [[NSTrackingArea alloc]
      initWithRect:NSZeroRect
           options:(NSTrackingCursorUpdate | NSTrackingActiveAlways | NSTrackingInVisibleRect)
             owner:self
          userInfo:nil];
  [link addTrackingArea:area];
  return link;
}

- (void)cursorUpdate:(NSEvent *)event {
  [[NSCursor pointingHandCursor] set];
}

- (void)showAboutPanel {
  [NSApp activateIgnoringOtherApps:YES];
  if (!self.window.isVisible) {
    [self.window center];
  }
  [self showWindow:nil];
  [self.window makeKeyAndOrderFront:nil];
}

- (void)openReadme:(id)sender {
  NSURL *url = [NSURL URLWithString:[kTmuxBarRepoURL stringByAppendingString:@"#readme"]];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)openGitHub:(id)sender {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kTmuxBarRepoURL]];
}

- (void)openCommit:(id)sender {
  if (self.commitString.length == 0 || [self.commitString isEqualToString:@"unknown"]) {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kTmuxBarRepoURL]];
    return;
  }
  NSString *urlString =
      [NSString stringWithFormat:@"%@/commit/%@", kTmuxBarRepoURL, self.commitString];
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

@end
