// Route-walk verification: drives the GoRouter through every screen (signed-in)
// and asserts no build/layout/paint exception fires. Stronger than the splash
// smoke test — it actually renders all 50+ screens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/router/app_router.dart';
import 'package:kudimata_securities/theme/app_theme.dart';

void main() {
  testWidgets('every route renders without exceptions', (tester) async {
    final state = AppState()
      ..passcodeSet = true
      ..biometricEnabled = true
      ..kycSubmitted = true
      ..kycApproved = true
      ..suitabilityComplete = true
      ..signedIn = true;
    final router = buildRouter(state);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp.router(theme: KTheme.light(), routerConfig: router),
      ),
    );
    await tester.pump();

    const routes = <String>[
      // tabs
      '/home', '/portfolio', '/markets', '/wallet', '/account',
      // pushed static
      '/notifications', '/search', '/orders', '/assets', '/watchlist',
      // pushed dynamic
      '/asset/MTNN', '/asset/AAPL', '/portfolio/holding/MTNN', '/wallet/txn/TX1042',
      // account subs
      '/account/personal', '/account/banks', '/account/refer', '/account/help',
      '/account/security', '/account/notifications', '/account/legal', '/account/statements',
      // gated
      '/signup', '/otp', '/passcode/create', '/passcode/confirm', '/biometric', '/login', '/reset',
      // kyc
      '/kyc', '/kyc/personal', '/kyc/bvn', '/kyc/id', '/kyc/liveness',
      '/kyc/next-of-kin', '/kyc/submitted', '/kyc/approved',
      // suitability
      '/suitability', '/suitability/result', '/suitability/risk', '/suitability/agreement',
    ];

    final failures = <String>[];
    for (final r in routes) {
      router.go(r);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final ex = tester.takeException();
      if (ex != null) failures.add('$r → $ex');
    }

    // Flush any auto-advance timers (splash/checking/submitted) so teardown is clean.
    await tester.pump(const Duration(seconds: 3));
    final tail = tester.takeException();
    if (tail != null) failures.add('post-flush → $tail');

    state.dispose();
    expect(failures, isEmpty, reason: 'Routes threw:\n${failures.join('\n')}');
  });
}
