#import "AppDelegate.h"

#import "FocusWatcher.h"
#import "TouchBarController.h"
#import "TmuxClient.h"

@interface AppDelegate ()

@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSTimer *refreshTimer;
@property(nonatomic, strong) TmuxClient *tmuxClient;
@property(nonatomic, strong) FocusWatcher *focusWatcher;
@property(nonatomic, strong) TouchBarController *touchBarController;
@property(nonatomic, assign) BOOL debugMode;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  self.tmuxClient = [[TmuxClient alloc] init];
  self.focusWatcher = [[FocusWatcher alloc] init];
  [self.focusWatcher start];

  self.touchBarController =
      [[TouchBarController alloc] initWithTmuxClient:self.tmuxClient];
  self.debugMode = (getenv("TMUX_BAR_DEBUG") != NULL);

  self.statusItem =
      [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
  self.statusItem.button.title = @"tmux-bar";
  self.statusItem.button.toolTip = @"tmux Touch Bar helper";

  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"tmux-bar"];
  [menu addItemWithTitle:@"Refresh Now"
                  action:@selector(refreshState)
           keyEquivalent:@"r"];
  if (self.debugMode) {
    [menu addItemWithTitle:@"Log Debug Snapshot"
                    action:@selector(logDebugSnapshot)
             keyEquivalent:@"d"];
  }
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Quit"
                  action:@selector(quitApp)
           keyEquivalent:@"q"];
  self.statusItem.menu = menu;

  // Keep refresh cadence responsive but lightweight for a menu bar utility.
  self.refreshTimer =
      [NSTimer scheduledTimerWithTimeInterval:0.8
                                       target:self
                                     selector:@selector(refreshState)
                                     userInfo:nil
                                      repeats:YES];

  [self refreshState];
}

- (void)quitApp {
  [NSApp terminate:nil];
}

- (void)refreshState {
  NSString *frontmost = self.focusWatcher.frontmostBundleIdentifier ?: @"";
  if (![self.focusWatcher isTerminalFocused]) {
    // Avoid showing stale Touch Bar content while the user is in non-terminal apps.
    [self.touchBarController clearWindows];
    [self.touchBarController hideIfNeeded];
    if (self.debugMode) {
      self.statusItem.button.title =
          [NSString stringWithFormat:@"tmux-bar [idle %@]", frontmost];
    } else {
      self.statusItem.button.title = @"tmux-bar";
    }
    return;
  }

  NSArray<TmuxWindow *> *windows = [self.tmuxClient listWindows];
  if (windows.count == 0) {
    // No visible tmux session: hide controls until tmux becomes available again.
    [self.touchBarController clearWindows];
    [self.touchBarController hideIfNeeded];
    if (self.debugMode) {
      self.statusItem.button.title =
          [NSString stringWithFormat:@"tmux-bar [no-session %@]", frontmost];
    } else {
      self.statusItem.button.title = @"tmux-bar (no session)";
    }
    return;
  }

  [self.touchBarController updateWindows:windows];
  [self.touchBarController presentIfNeeded];
  NSString *session = [self.tmuxClient activeSessionName] ?: @"?";
  if (self.debugMode) {
    self.statusItem.button.title =
        [NSString stringWithFormat:@"tmux-bar [%@:%lu %@]", session,
                                   (unsigned long)windows.count, frontmost];
  } else {
    self.statusItem.button.title =
        [NSString stringWithFormat:@"tmux-bar [%@:%lu]", session,
                                   (unsigned long)windows.count];
  }
}

- (void)logDebugSnapshot {
  NSArray<TmuxWindow *> *windows = [self.tmuxClient listWindows];
  NSMutableArray<NSString *> *labels = [NSMutableArray array];
  for (TmuxWindow *w in windows) {
    [labels addObject:[NSString stringWithFormat:@"%ld:%@%@", (long)w.index, w.name,
                                                 w.isActive ? @"*" : @""]];
  }
  NSLog(@"[tmux-bar] focused=%@ terminalFocused=%@ windows=%@",
        self.focusWatcher.frontmostBundleIdentifier,
        [self.focusWatcher isTerminalFocused] ? @"YES" : @"NO", labels);
}

@end
