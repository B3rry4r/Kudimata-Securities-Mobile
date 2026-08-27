// Driver for integration_test/live_gate_test.dart on Chrome (web target) —
// required by `flutter drive` for ANY web integration test, whether or not
// it takes screenshots itself: without a driver file `flutter drive` has no
// process to hand the browser-side WebDriver session to. See
// scripts/live_gate.sh for the actual invocation.
//
// onScreenshot below is what makes `binding.takeScreenshot(name)` calls
// inside the app-side test produce real PNG files: on web, the app side has
// no pixel access at all (integration_test's _callback_web.dart: "Flutter
// Web doesn't provide the bytes") — it just asks the DRIVER side to invoke
// chromedriver's WebDriver screenshot command (driver.screenshot()) and
// hand the bytes back here.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outDir = Directory('build/live_gate_screenshots');
  await outDir.create(recursive: true);

  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('${outDir.path}/$name.png');
      await file.writeAsBytes(bytes, flush: true);
      // ignore: avoid_print
      print('Saved screenshot: ${file.path} (${bytes.length} bytes)');
      return true;
    },
  );
}
