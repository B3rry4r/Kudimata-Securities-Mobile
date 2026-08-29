// Evidence for the 2026-08-29 product-owner audit's A-6 ("passcode or
// biometrics scan for reopening the app is not enforced") and A-7
// ("biometrics is not collected from start") fixes.
//
//   flutter test test/security_persistence_test.dart
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
import 'package:kudimata_invest/screens/kyc/kyc_form_state.dart';
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/theme/tokens.dart';

import 'fixtures/mock_api_adapter.dart';

const _kTestPasscode = '135790';
const _kTestSalt = 'security-persistence-fixed-salt';
String _testPasscodeHash() =>
    sha256.convert(utf8.encode('$_kTestSalt:$_kTestPasscode')).toString();

/// A REAL in-memory backing for `flutter_secure_storage`'s method channel —
/// unlike a null-always mock, this actually persists what's written, so it
/// can stand in for the real device store across TWO separate [AppState]
/// instances in the same test (simulating a cold restart — see the A-7
/// test below, which is the exact scenario that was broken: enrolling in
/// biometric_screen.dart, then a fresh app process forgetting it).
Map<String, String> _mockSecureStorage({Map<String, String>? seed}) {
  final store = <String, String>{...?seed};
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      final args = call.arguments is Map ? call.arguments as Map : const {};
      switch (call.method) {
        case 'read':
          return store[args['key'] as String?];
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
  return store;
}

void main() {
  group('A-7 — biometric enrolment survives a cold start', () {
    test('setBiometric persists, and a FRESH AppState instance reads it back', () async {
      final backing = _mockSecureStorage();

      final first = AppState();
      await first.ready;
      expect(first.biometricEnabled, isFalse,
          reason: 'nothing enrolled yet on a fresh device');

      first.setBiometric(true);
      // setBiometric's persistence write is fire-and-forget (unawaited) —
      // give it a turn of the event loop to land in the mock store before
      // the "cold start" below reads it back.
      await Future<void>.delayed(Duration.zero);
      expect(backing['kudimata.passcode.biometricEnabled'], 'true',
          reason: 'the enrolment must actually be written to secure storage, '
              'not just held in memory (that was the whole bug)');

      // Simulate a cold app restart: a BRAND NEW AppState, same underlying
      // secure storage. Before the A-7 fix, this always came back false —
      // an investor who turned biometrics on lost the Face ID key from
      // log_in_screen.dart's unlock keypad on the very next launch.
      final second = AppState();
      await second.ready;
      expect(second.biometricEnabled, isTrue,
          reason: 'A-7: biometric enrolment must survive a cold start');
    });

    test('clearPasscode (a forced sign-out) wipes the biometric preference too', () async {
      _mockSecureStorage(seed: {
        'kudimata.passcode.hash': 'x',
        'kudimata.passcode.salt': 'y',
        'kudimata.passcode.owner': 'someone@example.com',
        'kudimata.passcode.biometricEnabled': 'true',
      });
      await PasscodeStore().clearPasscode();
      final after = AppState();
      await after.ready;
      expect(after.biometricEnabled, isFalse);
    });
  });

  group('A-6 — foreground-resume re-auth reuses log_in_screen.dart\'s unlock', () {
    Future<GoRouter> mountUnlocked(WidgetTester tester) async {
      _mockSecureStorage(seed: {
        'kudimata.passcode.hash': _testPasscodeHash(),
        'kudimata.passcode.salt': _kTestSalt,
        'kudimata.passcode.owner': 'resume-lock@example.com',
      });
      KColor.active = KPalette.light;
      final apiClient = ApiClient()..dio.httpClientAdapter = MockApiAdapter();
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
      router.go(Routes.home);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      return router;
    }

    testWidgets('cannot be dismissed by a back gesture without authenticating', (tester) async {
      final router = await mountUnlocked(tester);
      router.push(Routes.login, extra: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Enter your passcode'), findsOneWidget);

      // The Android hardware/gesture back button, routed through the
      // framework the same way a real device dispatches it.
      final dynamic rootBackDispatcher = tester.binding.platformDispatcher;
      await rootBackDispatcher.popRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Still locked — PopScope(canPop: false) must have refused it.
      expect(find.text('Enter your passcode'), findsOneWidget);
    });

    testWidgets('a correct passcode pops back to where the investor was — not Home',
        (tester) async {
      final router = await mountUnlocked(tester);
      // Somewhere that ISN'T Home, so a wrong "route to Home" fallback
      // would be visibly distinguishable from the correct "pop back here".
      router.go(Routes.markets);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      router.push(Routes.login, extra: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Enter your passcode'), findsOneWidget);

      for (final digit in _kTestPasscode.split('')) {
        await tester.tap(find.text(digit).last);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 700));

      // Popped back onto Markets, not routed to Home.
      final loc = router.routerDelegate.currentConfiguration.uri.toString();
      expect(loc, Routes.markets);
      expect(find.text('Enter your passcode'), findsNothing);
    });
  });
}
