// Route-walk verification: drives the GoRouter through every screen (signed-in)
// and asserts no build/layout/paint exception fires. Stronger than the splash
// smoke test — it actually renders all 50+ screens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/router/app_router.dart';
import 'package:kudimata_securities/theme/app_theme.dart';
import 'package:kudimata_securities/screens/home/home_screen.dart';
import 'package:kudimata_securities/screens/portfolio/portfolio_screen.dart';
import 'package:kudimata_securities/screens/markets/markets_screen.dart';
import 'package:kudimata_securities/screens/wallet/wallet_screens.dart';
import 'package:kudimata_securities/screens/account/account_screen.dart';

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

    // Let a page transition fully settle so we test one route at a time (the
    // Cupertino transition is ~300ms; splash/checking spinners forbid pumpAndSettle).
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
    }

    final failures = <String>[];
    for (final r in routes) {
      router.go(r);
      await settle();
      final ex = tester.takeException();
      if (ex != null) failures.add('$r → $ex');
      // A matched route must NOT land on the not-found screen.
      if (find.byType(RouteNotFoundScreen).evaluate().isNotEmpty) {
        failures.add('$r → RouteNotFoundScreen (route did not match)');
      }
    }

    // The 5 tab roots must resolve to their real screens (guards the shell route).
    for (final entry in <String, Type>{
      '/home': HomeScreen,
      '/portfolio': PortfolioScreen,
      '/markets': MarketsScreen,
      '/wallet': WalletScreen,
      '/account': AccountScreen,
    }.entries) {
      router.go(entry.key);
      await settle();
      if (find.byType(entry.value).evaluate().isEmpty) {
        failures.add('${entry.key} → expected ${entry.value} not found');
      }
    }

    state.dispose();
    expect(failures, isEmpty, reason: 'Routes threw:\n${failures.join('\n')}');
  });
}
