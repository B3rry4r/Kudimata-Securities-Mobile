// A tab root is switched to, never pushed.
//
// Reported by the product owner: "when I click on new price alert which takes
// me to markets tab it breaks... markets tab is disabled... it doesn't work,
// not clickable."
//
// Cause: `context.push(Routes.markets)`. The four tab roots are
// StatefulShellRoute BRANCH roots. Pushing one stacks a second, detached copy
// of that screen above the shell — so the bottom nav the investor is looking at
// belongs to the shell underneath, and every tap lands on a nav that is no
// longer the visible one. It looks exactly like a disabled tab bar.
//
// There were two: price_alerts_screen.dart and plans_screen.dart. Neither was
// caught by a render test, because both screens RENDER perfectly — the defect
// is in the navigator stack, not the pixels. Only tapping the control finds it,
// which is why this is a source sweep rather than another screenshot.
//
//   flutter test test/tab_root_navigation_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The StatefulShellRoute branch roots, from lib/router/app_router.dart's
/// `_branchForNav`. Keep in step if a branch is ever added or removed.
const List<String> kTabRoots = ['home', 'markets', 'portfolio', 'wallet'];

void main() {
  test('no screen pushes a tab-root route', () {
    final offenders = <String>[];
    final push = RegExp(
      r'push\w*\(\s*Routes\.(' + kTabRoots.join('|') + r')\b',
    );

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].trimLeft();
        if (code.startsWith('//') || code.startsWith('///') || code.startsWith('*')) {
          continue; // a comment discussing the bug is not the bug
        }
        if (push.hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'A tab root is being pushed instead of switched to. Use '
          'context.go(...) — push stacks a detached copy above the shell and '
          'the bottom nav stops responding:\n${offenders.join('\n')}',
    );
  });
}
