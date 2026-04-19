#import "FocusWatcher.h"

#import <AppKit/AppKit.h>

static NSString *const kTerminalBundleID = @"com.apple.Terminal";
static NSString *const kiTermBundleID = @"com.googlecode.iterm2";
static NSString *const kGhosttyBundleID = @"com.mitchellh.ghostty";

@interface FocusWatcher ()

@property(nonatomic, copy, readwrite) NSString *frontmostBundleIdentifier;

@end

@implementation FocusWatcher

- (instancetype)init {
  self = [super init];
  if (self) {
    _frontmostBundleIdentifier = @"";
  }
  return self;
}

- (void)start {
  [self refreshFrontmostApplication];
  [[[NSWorkspace sharedWorkspace] notificationCenter]
      addObserver:self
         selector:@selector(activeAppChanged:)
             name:NSWorkspaceDidActivateApplicationNotification
           object:nil];
}

- (void)activeAppChanged:(NSNotification *)notification {
  NSDictionary *info = notification.userInfo;
  NSRunningApplication *app = info[NSWorkspaceApplicationKey];
  self.frontmostBundleIdentifier = app.bundleIdentifier ?: @"";
}

- (void)refreshFrontmostApplication {
  NSRunningApplication *app = [[NSWorkspace sharedWorkspace] frontmostApplication];
  self.frontmostBundleIdentifier = app.bundleIdentifier ?: @"";
}

- (BOOL)isTerminalFocused {
  NSString *bundleID = self.frontmostBundleIdentifier;
  return [bundleID isEqualToString:kTerminalBundleID] ||
         [bundleID isEqualToString:kiTermBundleID] ||
         [bundleID isEqualToString:kGhosttyBundleID];
}

@end
