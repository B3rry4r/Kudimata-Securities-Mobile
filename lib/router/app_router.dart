// Kudimata Securities — GoRouter (Stage 10 wiring). One StatefulShellRoute with
// 5 indexed-stack branches (Home · Portfolio · Markets · Wallet · Account), each
// keeping its own stack, under a shell scaffold that floats KBottomNav above the
// content. Every gated / KYC / suitability / pushed-detail / account-sub route is
// TOP-LEVEL so it covers the tab bar (no nav, KDetailHeader chrome).
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_state.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../widgets/widgets.dart';

import 'routes.dart';

// Onboarding / security.
import '../screens/onboarding/splash_screen.dart';
import '../screens/onboarding/sign_up_screen.dart';
import '../screens/onboarding/otp_screen.dart';
import '../screens/onboarding/create_passcode_screen.dart';
import '../screens/onboarding/confirm_passcode_screen.dart';
import '../screens/onboarding/biometric_screen.dart';
import '../screens/onboarding/personal_details_screen.dart';
import '../screens/onboarding/log_in_screen.dart';
import '../screens/onboarding/reset_passcode_screen.dart';

// KYC.
import '../screens/kyc/kyc_intro.dart';
import '../screens/kyc/bvn.dart';
import '../screens/kyc/id_upload.dart';
import '../screens/kyc/liveness.dart';
import '../screens/kyc/checking.dart';
import '../screens/kyc/next_of_kin.dart';
import '../screens/kyc/submitted.dart';
import '../screens/kyc/approved.dart';
import '../screens/kyc/outcome_not_approved.dart';

// Suitability & agreements.
import '../screens/suitability/questionnaire_screen.dart';
import '../screens/suitability/suitability_result_screen.dart';
import '../screens/suitability/risk_disclosure_screen.dart';
import '../screens/suitability/client_agreement_screen.dart';

// Tab roots.
import '../screens/home/home_screen.dart';
import '../screens/portfolio/portfolio_screen.dart';
import '../screens/markets/markets_screen.dart';
import '../screens/wallet/wallet_screens.dart';
import '../screens/account/account_screen.dart';

// Home pushed.
import '../screens/home/notifications_screen.dart';
import '../screens/home/search_screen.dart';

// Markets pushed.
import '../screens/markets/asset_list_screen.dart';
import '../screens/markets/asset_detail_screen.dart';
import '../screens/markets/watchlist_screen.dart';

// Portfolio pushed.
import '../screens/portfolio/holding_detail_screen.dart';
import '../screens/portfolio/order_status_screen.dart';

// Account subs.
import '../screens/account/personal_info_screen.dart';
import '../screens/account/bank_accounts_screen.dart';
import '../screens/account/refer_earn_screen.dart';
import '../screens/account/help_support_screen.dart';
import '../screens/account/faq_screen.dart';
import '../screens/account/security_screen.dart';
import '../screens/account/notifications_settings_screen.dart';
import '../screens/account/legal_screen.dart';
import '../screens/account/statements_screen.dart';

// Shared states (used for missing-data placeholders).
import '../screens/shared/state_views.dart';

/// Builds the app router. [state] drives the deep-link gate redirect AND the
/// theme reactivity: every screen is wrapped in a [ListenableBuilder] on [state]
/// so a theme-mode / system-brightness change rebuilds it (the global KColor
/// palette alone doesn't push rebuilds through go_router's cached routes or the
/// shell's preserved branch navigators). Screens are built WITHOUT `const` so a
/// fresh instance is created on each rebuild (a const instance would be skipped).
GoRouter buildRouter(AppState state) {
  final homeKey = GlobalKey<NavigatorState>();
  final portfolioKey = GlobalKey<NavigatorState>();
  final marketsKey = GlobalKey<NavigatorState>();
  final walletKey = GlobalKey<NavigatorState>();
  final accountKey = GlobalKey<NavigatorState>();

  // Re-theme on every AppState notify (theme toggle / system brightness bump).
  Widget themed(Widget Function() build) =>
      ListenableBuilder(listenable: state, builder: (_, _) => build());

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: state,
    redirect: (context, st) => _gateRedirect(state, st),
    routes: [
      // ── Gated onboarding ──────────────────────────────────────────────--
      GoRoute(path: Routes.splash, builder: (_, _) => themed(() => SplashScreen())),
      GoRoute(path: Routes.signup, builder: (_, _) => themed(() => SignUpScreen())),
      GoRoute(path: Routes.otp, builder: (_, _) => themed(() => OtpScreen())),
      GoRoute(
        path: Routes.createPasscode,
        // `extra: true` marks re-entry from Security's "Change passcode"
        // (security_screen.dart) rather than first-time onboarding. A
        // String `extra` instead (otp_screen.dart's post-signup handoff,
        // log_in_screen.dart's post-login handoff) is the account's email —
        // known with certainty at both those call sites, so it's threaded
        // straight through rather than re-derived later via an API call
        // that could fail (BUG-03 follow-up, 2026-08-15: PasscodeStore's
        // owner scoping used to resolve the email via GET /users/me right
        // when the passcode was set — a single transient failure there
        // permanently mis-scoped the passcode, forcing re-onboarding on
        // every future login for that account).
        builder: (_, st) => themed(() => CreatePasscodeScreen(
              reentry: st.extra == true,
              email: st.extra is String ? st.extra as String : null,
            )),
      ),
      GoRoute(
        path: Routes.confirmPasscode,
        // Create-step passes the chosen code (and re-entry flag) via
        // GoRouter `extra` as a ConfirmPasscodeArgs.
        builder: (_, st) {
          final args = st.extra;
          return themed(() => ConfirmPasscodeScreen(
                created: args is ConfirmPasscodeArgs ? args.code : null,
                reentry: args is ConfirmPasscodeArgs ? args.reentry : false,
              ));
        },
      ),
      GoRoute(
        path: Routes.biometric,
        // Biometric enrolment can't function on web (no local_auth backing
        // store) — bounce straight past it to the next onboarding step, same
        // as BiometricScreen's own "Maybe later" path, rather than showing a
        // screen offering a capability that will never work.
        redirect: (_, _) => kIsWeb ? Routes.onboardingPersonal : null,
        builder: (_, _) => themed(() => BiometricScreen()),
      ),
      GoRoute(
        path: Routes.onboardingPersonal,
        builder: (_, _) => themed(() => OnboardingPersonalDetailsScreen()),
      ),
      GoRoute(path: Routes.login, builder: (_, _) => themed(() => LogInScreen())),
      GoRoute(path: Routes.reset, builder: (_, _) => themed(() => ResetPasscodeScreen())),

      // ── KYC ───────────────────────────────────────────────────────────--
      GoRoute(path: Routes.kycIntro, builder: (_, _) => themed(() => KycIntroScreen())),
      GoRoute(path: Routes.kycBvn, builder: (_, _) => themed(() => BvnScreen())),
      GoRoute(path: Routes.kycId, builder: (_, _) => themed(() => IdUploadScreen())),
      GoRoute(path: Routes.kycLiveness, builder: (_, _) => themed(() => LivenessScreen())),
      GoRoute(path: Routes.kycChecking, builder: (_, _) => themed(() => CheckingScreen())),
      GoRoute(path: Routes.kycNextOfKin, builder: (_, _) => themed(() => NextOfKinScreen())),
      GoRoute(path: Routes.kycSubmitted, builder: (_, _) => themed(() => SubmittedScreen())),
      GoRoute(path: Routes.kycApproved, builder: (_, _) => themed(() => ApprovedScreen())),
      GoRoute(path: Routes.kycOutcome, builder: (_, _) => themed(() => KycOutcomeScreen())),

      // ── Suitability & agreements ───────────────────────────────────────--
      GoRoute(path: Routes.questionnaire, builder: (_, _) => themed(() => QuestionnaireScreen())),
      GoRoute(path: Routes.suitabilityResult, builder: (_, _) => themed(() => SuitabilityResultScreen())),
      GoRoute(path: Routes.riskDisclosure, builder: (_, _) => themed(() => RiskDisclosureScreen())),
      GoRoute(path: Routes.clientAgreement, builder: (_, _) => themed(() => ClientAgreementScreen())),

      // ── Pushed detail (top-level — cover the shell, no tab bar) ─────────--
      GoRoute(path: Routes.notifications, builder: (_, _) => themed(() => NotificationsScreen())),
      GoRoute(path: Routes.search, builder: (_, _) => themed(() => SearchScreen())),
      GoRoute(path: Routes.orderStatus, builder: (_, _) => themed(() => OrderStatusScreen())),
      GoRoute(path: Routes.assetList, builder: (_, st) {
        // Optional AssetClass passed via `extra` (defaults to NGX when absent).
        final cls = st.extra is AssetClass ? st.extra as AssetClass : null;
        return themed(() => AssetListScreen(assetClass: cls));
      }),
      GoRoute(path: Routes.watchlist, builder: (_, _) => themed(() => WatchlistScreen())),
      GoRoute(
        path: Routes.assetDetailPath,
        builder: (_, st) => themed(() => AssetDetailScreen(ticker: st.pathParameters['ticker']!)),
      ),
      GoRoute(
        path: Routes.holdingDetailPath,
        builder: (_, st) => themed(() => HoldingDetailScreen(ticker: st.pathParameters['ticker']!)),
      ),
      GoRoute(
        path: Routes.transactionDetailPath,
        builder: (_, st) => themed(() => TransactionDetailScreen(id: st.pathParameters['id']!)),
      ),

      // ── Account sub-pages (pushed) ─────────────────────────────────────--
      GoRoute(path: Routes.acctPersonal, builder: (_, _) => themed(() => PersonalInfoScreen())),
      GoRoute(path: Routes.acctBanks, builder: (_, _) => themed(() => BankAccountsScreen())),
      GoRoute(path: Routes.acctRefer, builder: (_, _) => themed(() => ReferEarnScreen())),
      GoRoute(path: Routes.acctHelp, builder: (_, _) => themed(() => HelpSupportScreen())),
      GoRoute(path: Routes.acctFaq, builder: (_, _) => themed(() => FaqScreen())),
      GoRoute(path: Routes.acctSecurity, builder: (_, _) => themed(() => SecurityScreen())),
      GoRoute(path: Routes.acctNotifications, builder: (_, _) => themed(() => NotificationsSettingsScreen())),
      GoRoute(path: Routes.acctLegal, builder: (_, _) => themed(() => LegalScreen())),
      GoRoute(path: Routes.acctStatements, builder: (_, _) => themed(() => StatementsScreen())),

      // ── Tab shell (StatefulShellRoute / indexedStack) ──────────────────--
      StatefulShellRoute.indexedStack(
        builder: (context, st, navShell) => themed(() => _TabShell(navShell: navShell)),
        branches: [
          StatefulShellBranch(navigatorKey: homeKey, routes: [
            GoRoute(path: Routes.home, builder: (_, _) => themed(() => HomeScreen())),
          ]),
          StatefulShellBranch(navigatorKey: portfolioKey, routes: [
            GoRoute(path: Routes.portfolio, builder: (_, _) => themed(() => PortfolioScreen())),
          ]),
          StatefulShellBranch(navigatorKey: marketsKey, routes: [
            GoRoute(path: Routes.markets, builder: (_, _) => themed(() => MarketsScreen())),
          ]),
          StatefulShellBranch(navigatorKey: walletKey, routes: [
            GoRoute(path: Routes.wallet, builder: (_, _) => themed(() => WalletScreen())),
          ]),
          StatefulShellBranch(navigatorKey: accountKey, routes: [
            GoRoute(path: Routes.account, builder: (_, _) => themed(() => AccountScreen())),
          ]),
        ],
      ),
    ],
    errorBuilder: (_, st) => themed(() => RouteNotFoundScreen(location: st.uri.toString())),
  );
}

// ── Redirect: deep-link gate ────────────────────────────────────────────────
// Pragmatic, not draconian: the whole gated flow (onboarding → KYC → suitability)
// is always allowed so the demo can walk it end-to-end. Only DEEP LINKS into the
// tab section / pushed detail screens are bounced to /splash when not signed in.
//
// 2026-08-14 (BUG-04): also closes the reverse gap — an already-signed-in
// investor landing back on a pre-auth-only screen via browser back/history
// (web) or a stray stack entry (native). go_router's `.go()` calls
// consistently used throughout the auth/onboarding flow keep the app's OWN
// Navigator flat, but each still reports a distinct browser history entry
// on web (a go_router/Flutter Router characteristic, not something this
// app's navigation calls control) — so repeated back-navigation could
// still walk through /splash, /signup, /otp, /reset even once fully
// authenticated. Routes.login is deliberately NOT in this block list: it's
// dual-purpose (LogInScreen._decideMode) — the pre-auth email+password form
// AND the legitimate returning-user passcode-unlock screen splash_screen.dart
// itself routes an already-signed-in investor to on every cold start, so
// bouncing it away here would break that intended flow.
String? _gateRedirect(AppState state, GoRouterState st) {
  final loc = st.matchedLocation;

  // Locations that belong to the gated flow (reachable while signed out).
  const gated = <String>{
    Routes.splash, Routes.signup, Routes.otp,
    Routes.createPasscode, Routes.confirmPasscode,
    Routes.biometric, Routes.login, Routes.reset,
    Routes.kycIntro, Routes.kycBvn, Routes.kycId,
    Routes.kycLiveness, Routes.kycChecking, Routes.kycNextOfKin,
    Routes.kycSubmitted, Routes.kycApproved, Routes.kycOutcome,
    Routes.questionnaire, Routes.suitabilityResult,
    Routes.riskDisclosure, Routes.clientAgreement,
  };

  // Pre-auth-only screens — never legitimately reachable once fully signed
  // in, regardless of how the app landed there (fresh navigation, stale
  // history, deep link).
  const preAuthOnly = <String>{
    Routes.splash, Routes.signup, Routes.otp, Routes.reset,
  };

  if (state.signedIn) {
    if (preAuthOnly.contains(loc)) return Routes.home;
    return null;                            // otherwise free roam
  }
  if (gated.contains(loc)) return null;     // gated flow always allowed
  return Routes.splash;                      // any deep link into the app → splash
}

// ── Tab shell scaffold: content + floating KBottomNav ───────────────────────
class _TabShell extends StatelessWidget {
  const _TabShell({required this.navShell});
  final StatefulNavigationShell navShell;

  // KBottomNav item id → branch index (Account's nav id is `profile`).
  static const _branchForNav = {
    'home': 0,
    'portfolio': 1,
    'markets': 2,
    'wallet': 3,
    'profile': 4,
  };
  static const _navForBranch = ['home', 'portfolio', 'markets', 'wallet', 'profile'];

  void _onNav(String id) {
    final idx = _branchForNav[id] ?? 0;
    // goBranch with initialLocation:true taps the active tab back to its root.
    navShell.goBranch(idx, initialLocation: idx == navShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final active = _navForBranch[navShell.currentIndex];
    return Scaffold(
      backgroundColor: KColor.bg,
      // The branch builds its own Scaffold/SafeArea body; the nav floats above it.
      body: Stack(
        children: [
          Positioned.fill(child: navShell),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: KBottomNav(active: active, onChange: _onNav),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fallbacks ───────────────────────────────────────────────────────────────
/// Minimal faithful not-found screen (router never ships a dead end).
class RouteNotFoundScreen extends StatelessWidget {
  const RouteNotFoundScreen({super.key, required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          children: [
            KDetailHeader(title: 'Not found', onBack: () => context.go(Routes.home)),
            Expanded(
              child: KErrorView(
                title: 'Page not found',
                message: "We couldn't find $location.",
                primary: 'Go home',
                onPrimary: () => context.go(Routes.home),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
