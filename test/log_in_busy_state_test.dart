// Regression test for the 2026-08-30 fix: "the login passcode screen has no
// loading state" — log_in_screen.dart's local-unlock keypad (artboard
// `s08`, the screen the cold-start lock routes to) verifies the passcode,
// re-hydrates gating state, and routes, showing the investor nothing while
// it does — a full row of filled dots that just sits there reads as
// frozen. Fixed by reusing confirm_passcode_screen.dart's busy/spinner
// treatment via the shared [PasscodeBusyState] mixin (onboarding_scaffold
// .dart) rather than a second hand-copied version — see log_in_screen.dart
// `_unlock`'s own doc comment for what the delay here actually consists
// of (local passcode check, THEN two real network round trips this screen
// didn't use to have: GET /users/me + KYC/suitability gating hydration).
//
// Two things asserted here, both driving the REAL keypad (same discipline
// confirm_passcode_busy_state_test.dart uses, which this file's structure
// mirrors):
//
//   1. Busy engages synchronously (dims the keypad the instant the 6th
//      digit lands) and the spinner only appears once the network call
//      genuinely outlasts the threshold — using MockNetwork.slow (a
//      request that never resolves) to hold `_unlock` inside its network
//      phase indefinitely so both moments are directly observable.
//   2. A stray tap right after the 6th digit does not double-submit —
//      exactly one local passcode check reaches secure storage, same
//      "count a marker that's written/read exactly once per real attempt"
//      discipline confirm_passcode_busy_state_test.dart's own double-submit
//      test uses (there: hash writes; here: the salt read inside
//      PasscodeStore.verifyPasscode).
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/data/api/passcode_store.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/home/home_screen.dart';
import 'package:kudimata_invest/screens/kyc/kyc_form_state.dart';
import 'package:kudimata_invest/screens/onboarding/onboarding_scaffold.dart';
import 'package:kudimata_invest/theme/app_theme.dart';

import 'fixtures/mock_api_adapter.dart';

const _kTestPasscode = '135790';
const _kTestSalt = 'log-in-busy-state-fixed-salt';
String _testPasscodeHash() =>
    sha256.convert(utf8.encode('$_kTestSalt:$_kTestPasscode')).toString();

/// A real in-memory backing for `flutter_secure_storage`'s method channel —
/// same pattern security_persistence_test.dart uses — plus a counter on
/// reads of the salt key, which [PasscodeStore.verifyPasscode] reads
/// exactly once per call, and nothing else reads at all — an exact proxy
/// for "how many times did `_unlock`'s local passcode check actually run".
int _saltReads = 0;

void _mockSecureStorage({required Map<String, String> seed}) {
  _saltReads = 0;
  final store = <String, String>{...seed};
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      final args = call.arguments is Map ? call.arguments as Map : const {};
      switch (call.method) {
        case 'read':
          final key = args['key'] as String?;
          if (key == 'kudimata.passcode.salt') _saltReads++;
          return store[key];
        case 'write':
          final key = args['key'] as String?;
          final value = args['value'] as String?;
          if (key != null && value != null) store[key] = value;
          return null;
        case 'readAll':
          return Map<String, String>.from(store);
        case 'containsKey':
          return store.containsKey(args['key'] as String?);
        case 'delete':
          store.remove(args['key'] as String?);
          return null;
        case 'deleteAll':
          store.clear();
          return null;
        default:
          return null;
      }
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (call) async => call.method == 'getAll' ? <String, dynamic>{} : null,
  );
}

Future<GoRouter> _mount(WidgetTester tester, {required MockNetwork network}) async {
  _mockSecureStorage(seed: {
    'kudimata.passcode.hash': _testPasscodeHash(),
    'kudimata.passcode.salt': _kTestSalt,
    'kudimata.passcode.owner': 'login-busy@example.com',
  });
  final apiClient = ApiClient()..dio.httpClientAdapter = MockApiAdapter(network: network);
  final state = AppState(passcodeStore: PasscodeStore())
    ..signedIn = true
    ..passcodeSet = true
    ..biometricEnabled = false
    ..apiClient = apiClient
    ..kycForm = KycFormState();
  await state.ready;
  final router = buildRouter(state);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: KTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  router.go(Routes.login);
  await tester.pump();
  // Clears GoRouter's page-transition animation — see
  // sign_up_middle_name_test.dart's identical fix for why 50ms wasn't
  // enough (found live: the keypad's hit-test targets were still
  // hundreds of logical pixels off their final position mid-transition).
  await tester.pump(const Duration(milliseconds: 700));
  expect(find.text('Enter your passcode'), findsOneWidget,
      reason: 'expected the local-unlock keypad, not the email+password form');
  return router;
}

Future<void> _tapDigit(WidgetTester tester, String digit) async {
  await tester.tap(find.text(digit).first);
}

/// Bounded polling — same shape confirm_passcode_busy_state_test.dart's
/// helper of the same name uses.
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

void main() {
  testWidgets(
    'shows a busy state: the keypad dims the instant the passcode is '
    'complete, and a spinner appears once the network call outlasts the '
    'threshold',
    (tester) async {
      // MockNetwork.slow never resolves — holds `_unlock` inside its
      // GET /users/me network phase indefinitely, so both moments below
      // are directly observable instead of racing a fast mock response.
      await _mount(tester, network: MockNetwork.slow);

      for (final digit in _kTestPasscode.split('')) {
        await _tapDigit(tester, digit);
      }
      await tester.pump(); // let _onKey's setState + _unlock's sync startBusy land

      expect(
        tester.widget<KKeypad>(find.byType(KKeypad)).busy,
        isTrue,
        reason: 'busy must be set synchronously once the 6th digit lands, '
            'before the local passcode check (let alone the network call) '
            'has even run',
      );
      expect(
        find.text('Signing you in…'),
        findsNothing,
        reason: 'the spinner must not flash on immediately — only once the '
            'call outlasts PasscodeBusyState.spinnerThreshold',
      );

      // Past the 150ms threshold.
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Signing you in…'), findsOneWidget,
          reason: 'the work has now genuinely outlasted the threshold '
              '(MockNetwork.slow never resolves)');
      expect(tester.widget<KKeypad>(find.byType(KKeypad)).busy, isTrue,
          reason: 'still busy — the request is still pending');
    },
  );

  testWidgets(
    'a stray tap right after the 6th digit does not double-submit — '
    'exactly one local passcode check runs',
    (tester) async {
      await _mount(tester, network: MockNetwork.ok);

      for (final digit in _kTestPasscode.split('')) {
        await _tapDigit(tester, digit);
      }
      // One more tap immediately after the 6th digit, before any pump —
      // the exact window a missing busy guard would have let a second
      // `_unlock()` slip through in (mirrors confirm_passcode_busy_state
      // _test.dart's identical stray-tap regression).
      await _tapDigit(tester, '1');

      await pumpUntil(
        tester,
        () => find.byType(HomeScreen).evaluate().isNotEmpty,
        'the (single) correct submission to reach Home',
      );

      expect(
        _saltReads,
        1,
        reason: 'a stray tap once the code is complete must be ignored, not '
            're-run the whole local-check/network/route sequence a second '
            'time',
      );
    },
  );
}
