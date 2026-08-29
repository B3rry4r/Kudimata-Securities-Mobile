// Regression test for the 2026-08-29 UI-feedback fix ("confirming of pin
// should be showing a proper loader it just hangs and shows nothing until
// it goes through ... confirm pin shows all the pin entered but users dont
// know something is happening").
//
// Two things confirm_passcode_screen.dart's `_evaluate()` got wrong before
// this pass, both exercised here by driving the REAL keypad (same
// discipline as biometric_reachability_test.dart, which this file's mount
// helper is adapted from):
//
//   1. A wrong passcode left `_error` set but nothing else — that part
//      already worked — but a genuinely FAILED evaluation (any exception,
//      not just a mismatch) had no catch at all, so it would have left the
//      keypad permanently disabled had a busy flag existed. This asserts
//      the keypad is fully interactive again after a mismatch, not just
//      that an error message appeared.
//   2. `_onKey` re-ran `_evaluate()` on every keypress once `_code` was
//      already 6 digits, even while the first call was still in flight —
//      a real double-submit bug. A stray tap landing in that window used
//      to re-drive the whole hash/store/route sequence a second time. This
//      asserts a stray tap right after the 6th digit results in exactly
//      ONE write to the passcode hash in secure storage, not two.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/onboarding/biometric_screen.dart';
import 'package:kudimata_invest/screens/onboarding/confirm_passcode_screen.dart';
import 'package:kudimata_invest/theme/app_theme.dart';

import 'fixtures/mock_api_adapter.dart';

/// Bounded polling — same reasoning/shape as interrupted_signup_gate_test
/// .dart's helper of the same name: this app has periodic timers elsewhere
/// that never let `pumpAndSettle` return.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition,
  String what, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  do {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
  } while (DateTime.now().isBefore(deadline));
  fail('Timed out after ${timeout.inSeconds}s waiting for $what');
}

/// Counts writes to the passcode hash key so a double-submit shows up as a
/// second write, not just a second (possibly-swallowed) navigation.
int _hashWrites = 0;

void _mockSecureStorage() {
  _hashWrites = 0;
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      final args = call.arguments is Map ? call.arguments as Map : const {};
      switch (call.method) {
        case 'read':
          return null;
        case 'readAll':
          return <String, String>{};
        case 'containsKey':
          return false;
        case 'write':
          if (args['key'] == 'kudimata.passcode.hash') _hashWrites++;
          return null;
        case 'delete':
        case 'deleteAll':
          return null;
        default:
          return null;
      }
    },
  );
}

Future<GoRouter> _mount(WidgetTester tester) async {
  _mockSecureStorage();
  final apiClient = ApiClient()..dio.httpClientAdapter = MockApiAdapter();
  final state = AppState()
    ..apiClient = apiClient
    ..loginPasscodeSetup = false;
  final router = buildRouter(state);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp.router(theme: KTheme.light(), routerConfig: router),
    ),
  );
  // Land directly on Confirm, same as create_passcode_screen.dart's
  // context.go(Routes.confirmPasscode, extra: args).
  router.go(
    Routes.confirmPasscode,
    extra: const ConfirmPasscodeArgs(code: '135790', reentry: false),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  return router;
}

Future<void> _tapDigit(WidgetTester tester, String digit) async {
  await tester.tap(find.text(digit).first);
}

void main() {
  testWidgets(
    'a mismatched passcode shows an error and leaves the keypad fully '
    'interactive — not stuck busy',
    (tester) async {
      await _mount(tester);

      // '135790' is the created code; type a different one.
      for (final digit in '111111'.split('')) {
        await _tapDigit(tester, digit);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await pumpUntil(
        tester,
        () => find.text("That didn't match. Try the six digits again.").evaluate().isNotEmpty,
        'the mismatch error to appear',
      );

      // The keypad must still respond: delete the wrong code (a mismatch
      // doesn't clear `_code` for you — same as before this fix) then type
      // the RIGHT one, and expect it to actually go through, proving
      // _busy/_error were both cleared rather than the screen being left
      // permanently disabled.
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.bySemanticsLabel('Delete'));
        await tester.pump(const Duration(milliseconds: 20));
      }
      for (final digit in '135790'.split('')) {
        await _tapDigit(tester, digit);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await pumpUntil(
        tester,
        () => find.byType(BiometricScreen).evaluate().isNotEmpty,
        'a correct retry after a mismatch to reach Biometric',
      );
    },
  );

  testWidgets(
    'a stray tap right after the 6th digit does not double-submit — '
    'exactly one passcode write reaches secure storage',
    (tester) async {
      await _mount(tester);

      for (final digit in '135790'.split('')) {
        await _tapDigit(tester, digit);
      }
      // One more tap immediately after the 6th digit, before any pump — the
      // exact window the old code re-ran _evaluate() in, since `_code` was
      // already 6 digits and nothing yet marked a submission "in flight".
      await _tapDigit(tester, '1');

      await pumpUntil(
        tester,
        () => find.byType(BiometricScreen).evaluate().isNotEmpty,
        'the (single) submission to reach Biometric',
      );

      expect(
        _hashWrites,
        1,
        reason: 'a stray tap once the code is complete must be ignored, not '
            're-run the whole hash/store/route sequence a second time',
      );
    },
  );
}
