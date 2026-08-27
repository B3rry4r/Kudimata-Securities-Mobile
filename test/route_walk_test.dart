// Route-walk verification: drives the GoRouter through every screen (signed-in)
// and asserts no build/layout/paint exception fires. Stronger than the splash
// smoke test — it actually renders all 50+ screens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/screens/kyc/kyc_form_state.dart';
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/screens/home/home_screen.dart';
import 'package:kudimata_invest/screens/portfolio/portfolio_screen.dart';
import 'package:kudimata_invest/screens/markets/markets_screen.dart';
import 'package:kudimata_invest/screens/wallet/wallet_screens.dart';
import 'package:kudimata_invest/screens/account/account_screen.dart';

void main() {
  testWidgets('every route renders without exceptions', (tester) async {
    final state = AppState()
      ..passcodeSet = true
      ..biometricEnabled = true
      ..kycSubmitted = true
      ..kycApproved = true
      ..suitabilityComplete = true
      ..riskDisclosureAccepted = true
      ..signedIn = true
      // Several tab screens (Home, Markets, Wallet, Account, ...) read
      // AppScope.read(context).apiClient in repo field initializers — unset
      // (the `late final` default) throws LateInitializationError the
      // instant they build, which is exactly the "exception" this test was
      // catching and failing on for every apiClient-touching route. Real
      // requests fail against this bogus/unreachable client, surfacing as a
      // handled KErrorView (per each screen's FutureBuilder), not an
      // uncaught exception — which is all this test actually asserts on.
      ..apiClient = ApiClient()
      // Added 2026-08-24: declarations_screen.dart/next_of_kin.dart read
      // AppScope.read(context).kycForm at BUILD time (not just from an
      // event handler, like the pre-existing KYC screens did), so an unset
      // `late final` here throws the same LateInitializationError apiClient
      // above already guards against — main.dart's real bootstrap always
      // sets this too.
      ..kycForm = KycFormState();
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
      '/notifications', '/search', '/orders',
      // pushed dynamic
      '/asset/MTNN',
      '/asset/AAPL',
      '/asset/MTNN/alert',
      '/portfolio/holding/MTNN',
      '/wallet/txn/TX1042',
      // account subs
      '/account/personal', '/account/banks', '/account/refer', '/account/help',
      '/account/security',
      '/account/notifications',
      '/account/legal',
      '/account/statements',
      // gated
      '/signup', '/otp', '/passcode/create', '/passcode/confirm', '/biometric',
      '/onboarding/personal', '/onboarding/next-steps', '/login', '/reset',
      // kyc (2026-08-24: re-sequenced to 8 real steps — chn, bank-dcs,
      // declarations, review were new; D-1, 2026-08-27 removals pass, R-9:
      // review dropped, next-of-kin is now the last step and submits
      // directly)
      '/kyc',
      '/kyc/checklist',
      '/kyc/bvn',
      '/kyc/chn',
      '/kyc/id',
      '/kyc/liveness',
      '/kyc/utility-bill',
      '/kyc/bank-dcs', '/kyc/declarations', '/kyc/next-of-kin',
      '/kyc/submitted', '/kyc/approved',
      // suitability
      '/suitability', '/suitability/result', '/suitability/risk-disclaimer',
      '/suitability/terms',
      // 2026-08-22 "Soft Landing" redesign additions — added after this
      // exact test's original list missed a real overflow bug on
      // /security-alert (found only via test/shots.dart's visual check).
      '/welcome', '/account/security/freeze', '/security-alert',
      '/account/plans', '/explain/MTNN',
      // 2026-08-23 canvas-expansion additions (screens 76-97). Routes needing
      // an `extra` (acctStatementDetail, acctComplaintTracked) are skipped
      // here, same as the pre-existing acctWithdrawMandate/contractNote.
      '/account/tax', '/watchlist/alerts',
      '/corporate-actions', '/corporate-actions/rights-issue',
      '/corporate-actions/agm', '/corporate-actions/dividends',
      '/account/help/complaint',
      '/account/dormant',
      '/account/close',
      '/account/data-privacy',
      '/locked-out',
      '/account/legal/partner-disclosures', '/account/legal/referral-terms',
      '/account/legal/data-notice', '/account/legal/closure-terms',
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
