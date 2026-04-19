#import "TmuxClient.h"

@implementation TmuxClient

- (NSString *)tmuxExecutablePath {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray<NSString *> *candidates = @[
    @"/opt/homebrew/bin/tmux",  // Apple Silicon Homebrew
    @"/usr/local/bin/tmux",     // Intel Homebrew
    @"/usr/bin/tmux"            // System path fallback (usually absent)
  ];
  for (NSString *path in candidates) {
    if ([fm isExecutableFileAtPath:path]) {
      return path;
    }
  }
  return @"tmux";
}

- (nullable NSString *)resolveBestSessionName {
  int code = 0;
  NSArray<NSString *> *lines =
      [self runTmuxWithArguments:@[
        @"list-sessions", @"-F",
        @"#{session_name}|#{session_attached}|#{session_last_attached}"
      ]
                            code:&code];
  if (code != 0 || lines.count == 0) {
    return nil;
  }

  // Only consider sessions that currently have at least one client attached.
  // Detached sessions would still list windows and would misleadingly populate the
  // Touch Bar while the focused terminal is not actually inside tmux.
  NSString *best = nil;
  long long bestLastAttached = LLONG_MIN;

  for (NSString *line in lines) {
    NSArray<NSString *> *parts = [line componentsSeparatedByString:@"|"];
    if (parts.count < 3) {
      continue;
    }
    NSString *sessionName = parts[0];
    NSInteger attached = [parts[1] integerValue];
    long long lastAttached = [parts[2] longLongValue];

    if (attached <= 0) {
      continue;
    }
    if (lastAttached >= bestLastAttached) {
      bestLastAttached = lastAttached;
      best = sessionName;
    }
  }

  return best;
}

- (NSArray<NSString *> *)runTmuxWithArguments:(NSArray<NSString *> *)arguments
                                         code:(int *)exitCode {
  NSTask *task = [[NSTask alloc] init];
  NSString *tmuxPath = [self tmuxExecutablePath];
  if ([tmuxPath isEqualToString:@"tmux"]) {
    // Use /usr/bin/env when falling back to PATH lookup.
    task.launchPath = @"/usr/bin/env";
    NSMutableArray<NSString *> *fullArgs = [NSMutableArray arrayWithObject:@"tmux"];
    [fullArgs addObjectsFromArray:arguments];
    task.arguments = fullArgs;
  } else {
    task.launchPath = tmuxPath;
    task.arguments = arguments;
  }

  NSPipe *stdoutPipe = [NSPipe pipe];
  NSPipe *stderrPipe = [NSPipe pipe];
  task.standardOutput = stdoutPipe;
  task.standardError = stderrPipe;

  @try {
    [task launch];
    [task waitUntilExit];
  } @catch (NSException *exception) {
    if (exitCode != NULL) {
      *exitCode = -1;
    }
    return @[];
  }

  if (exitCode != NULL) {
    *exitCode = task.terminationStatus;
  }

  NSData *data = [[stdoutPipe fileHandleForReading] readDataToEndOfFile];
  NSData *stderrData = [[stderrPipe fileHandleForReading] readDataToEndOfFile];
  NSString *output =
      [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  NSString *stderrOutput =
      [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding];
  if (task.terminationStatus != 0) {
    NSLog(@"[tmux-bar] tmuxPath=%@ cmd=%@ failed (code=%d) stderr=%@",
          task.launchPath,
          [arguments componentsJoinedByString:@" "], task.terminationStatus,
          stderrOutput ?: @"");
  }
  if (output.length == 0) {
    return @[];
  }

  NSArray<NSString *> *lines =
      [output componentsSeparatedByCharactersInSet:
                  [NSCharacterSet newlineCharacterSet]];
  NSMutableArray<NSString *> *trimmed = [NSMutableArray array];
  for (NSString *line in lines) {
    NSString *candidate =
        [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (candidate.length > 0) {
      [trimmed addObject:candidate];
    }
  }

  return trimmed;
}

- (NSArray<TmuxWindow *> *)listWindows {
  NSString *session = [self resolveBestSessionName];
  if (session.length == 0) {
    return @[];
  }

  int code = 0;
  NSArray<NSString *> *lines = [self runTmuxWithArguments:@[
    @"list-windows", @"-t", session, @"-F",
    @"#{window_index}|#{window_name}|#{window_active}"
  ]
                                                   code:&code];
  if (code != 0 || lines.count == 0) {
    return @[];
  }

  NSMutableArray<TmuxWindow *> *windows = [NSMutableArray array];
  for (NSString *line in lines) {
    NSArray<NSString *> *parts = [line componentsSeparatedByString:@"|"];
    if (parts.count < 3) {
      continue;
    }
    NSInteger idx = [parts[0] integerValue];
    NSString *name = parts[1];
    BOOL active = [parts[2] isEqualToString:@"1"];
    [windows addObject:[[TmuxWindow alloc] initWithIndex:idx name:name active:active]];
  }

  return windows;
}

- (nullable NSString *)activeSessionName {
  return [self resolveBestSessionName];
}

- (BOOL)selectWindowAtIndex:(NSInteger)windowIndex {
  int code = 0;
  (void)[self runTmuxWithArguments:@[ @"select-window", @"-t",
                                      [NSString stringWithFormat:@"%ld", (long)windowIndex] ]
                              code:&code];
  return code == 0;
}

@end
