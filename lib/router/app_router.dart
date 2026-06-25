// Kudimata Securities — GoRouter (Stage 10 wiring). One StatefulShellRoute with
// 5 indexed-stack branches (Home · Portfolio · Markets · Wallet · Account), each
// keeping its own stack, under a shell scaffold that floats KBottomNav above the
// content. Every gated / KYC / suitability / pushed-detail / account-sub route is
// TOP-LEVEL so it covers the tab bar (no nav, KDetailHeader chrome).
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
import '../screens/onboarding/log_in_screen.dart';
import '../screens/onboarding/reset_passcode_screen.dart';

// KYC.
import '../screens/kyc/kyc_intro.dart';
import '../screens/kyc/personal_details.dart';
import '../screens/kyc/bvn.dart';
import '../screens/kyc/id_upload.dart';
import '../screens/kyc/liveness.dart';
import '../screens/kyc/checking.dart';
import '../screens/kyc/next_of_kin.dart';
import '../screens/kyc/submitted.dart';
import '../screens/kyc/approved.dart';

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
import '../screens/account/security_screen.dart';
import '../screens/account/notifications_settings_screen.dart';
import '../screens/account/legal_screen.dart';
import '../screens/account/statements_screen.dart';

// Shared states (used for missing-data placeholders).
import '../screens/shared/state_views.dart';

/// Builds the app router. [state] drives the deep-link gate redirect.
GoRouter buildRouter(AppState state) {
  final homeKey = GlobalKey<NavigatorState>();
  final portfolioKey = GlobalKey<NavigatorState>();
  final marketsKey = GlobalKey<NavigatorState>();
  final walletKey = GlobalKey<NavigatorState>();
  final accountKey = GlobalKey<NavigatorState>();

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: state,
    redirect: (context, st) => _gateRedirect(state, st),
    routes: [
      // ── Gated onboarding ──────────────────────────────────────────────--
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.signup, builder: (_, _) => const SignUpScreen()),
      GoRoute(path: Routes.otp, builder: (_, _) => const OtpScreen()),
      GoRoute(
        path: Routes.createPasscode,
        builder: (_, _) => const CreatePasscodeScreen(),
      ),
      GoRoute(
        path: Routes.confirmPasscode,
        // Create-step passes the chosen code through GoRouter `extra`.
        builder: (_, st) => ConfirmPasscodeScreen(created: st.extra as String?),
      ),
      GoRoute(path: Routes.biometric, builder: (_, _) => const BiometricScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LogInScreen()),
      GoRoute(path: Routes.reset, builder: (_, _) => const ResetPasscodeScreen()),

      // ── KYC ───────────────────────────────────────────────────────────--
      GoRoute(path: Routes.kycIntro, builder: (_, _) => const KycIntroScreen()),
      GoRoute(path: Routes.kycPersonal, builder: (_, _) => const PersonalDetailsScreen()),
      GoRoute(path: Routes.kycBvn, builder: (_, _) => const BvnScreen()),
      GoRoute(path: Routes.kycId, builder: (_, _) => const IdUploadScreen()),
      GoRoute(path: Routes.kycLiveness, builder: (_, _) => const LivenessScreen()),
      GoRoute(path: Routes.kycChecking, builder: (_, _) => const CheckingScreen()),
      GoRoute(path: Routes.kycNextOfKin, builder: (_, _) => const NextOfKinScreen()),
      GoRoute(path: Routes.kycSubmitted, builder: (_, _) => const SubmittedScreen()),
      GoRoute(path: Routes.kycApproved, builder: (_, _) => const ApprovedScreen()),

      // ── Suitability & agreements ───────────────────────────────────────--
      GoRoute(path: Routes.questionnaire, builder: (_, _) => const QuestionnaireScreen()),
      GoRoute(path: Routes.suitabilityResult, builder: (_, _) => const SuitabilityResultScreen()),
      GoRoute(path: Routes.riskDisclosure, builder: (_, _) => const RiskDisclosureScreen()),
      GoRoute(path: Routes.clientAgreement, builder: (_, _) => const ClientAgreementScreen()),

      // ── Pushed detail (top-level — cover the shell, no tab bar) ─────────--
      GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: Routes.search, builder: (_, _) => const SearchScreen()),
      GoRoute(path: Routes.orderStatus, builder: (_, _) => const OrderStatusScreen()),
      GoRoute(path: Routes.assetList, builder: (_, st) {
        // Optional AssetClass passed via `extra` (defaults to NGX when absent).
        final cls = st.extra is AssetClass ? st.extra as AssetClass : null;
        return AssetListScreen(assetClass: cls);
      }),
      GoRoute(path: Routes.watchlist, builder: (_, _) => const WatchlistScreen()),
      GoRoute(
        path: Routes.assetDetailPath,
        builder: (_, st) => AssetDetailScreen(ticker: st.pathParameters['ticker']!),
      ),
      GoRoute(
        path: Routes.holdingDetailPath,
        builder: (_, st) => HoldingDetailScreen(ticker: st.pathParameters['ticker']!),
      ),
      GoRoute(
        path: Routes.transactionDetailPath,
        builder: (_, st) => TransactionDetailScreen(id: st.pathParameters['id']!),
      ),

      // ── Account sub-pages (pushed) ─────────────────────────────────────--
      GoRoute(path: Routes.acctPersonal, builder: (_, _) => const PersonalInfoScreen()),
      GoRoute(path: Routes.acctBanks, builder: (_, _) => const BankAccountsScreen()),
      GoRoute(path: Routes.acctRefer, builder: (_, _) => const ReferEarnScreen()),
      GoRoute(path: Routes.acctHelp, builder: (_, _) => const HelpSupportScreen()),
      GoRoute(path: Routes.acctSecurity, builder: (_, _) => const SecurityScreen()),
      GoRoute(path: Routes.acctNotifications, builder: (_, _) => const NotificationsSettingsScreen()),
      GoRoute(path: Routes.acctLegal, builder: (_, _) => const LegalScreen()),
      GoRoute(path: Routes.acctStatements, builder: (_, _) => const StatementsScreen()),

      // ── Tab shell (StatefulShellRoute / indexedStack) ──────────────────--
      StatefulShellRoute.indexedStack(
        builder: (context, st, navShell) => _TabShell(navShell: navShell),
        branches: [
          StatefulShellBranch(navigatorKey: homeKey, routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(navigatorKey: portfolioKey, routes: [
            GoRoute(path: Routes.portfolio, builder: (_, _) => const PortfolioScreen()),
          ]),
          StatefulShellBranch(navigatorKey: marketsKey, routes: [
            GoRoute(path: Routes.markets, builder: (_, _) => const MarketsScreen()),
          ]),
          StatefulShellBranch(navigatorKey: walletKey, routes: [
            GoRoute(path: Routes.wallet, builder: (_, _) => const WalletScreen()),
          ]),
          StatefulShellBranch(navigatorKey: accountKey, routes: [
            GoRoute(path: Routes.account, builder: (_, _) => const AccountScreen()),
          ]),
        ],
      ),
    ],
    errorBuilder: (_, st) => RouteNotFoundScreen(location: st.uri.toString()),
  );
}

// ── Redirect: deep-link gate ────────────────────────────────────────────────
// Pragmatic, not draconian: the whole gated flow (onboarding → KYC → suitability)
// is always allowed so the demo can walk it end-to-end. Only DEEP LINKS into the
// tab section / pushed detail screens are bounced to /splash when not signed in.
String? _gateRedirect(AppState state, GoRouterState st) {
  final loc = st.matchedLocation;

  // Locations that belong to the gated flow (reachable while signed out).
  const gated = <String>{
    Routes.splash, Routes.signup, Routes.otp,
    Routes.createPasscode, Routes.confirmPasscode,
    Routes.biometric, Routes.login, Routes.reset,
    Routes.kycIntro, Routes.kycPersonal, Routes.kycBvn, Routes.kycId,
    Routes.kycLiveness, Routes.kycChecking, Routes.kycNextOfKin,
    Routes.kycSubmitted, Routes.kycApproved,
    Routes.questionnaire, Routes.suitabilityResult,
    Routes.riskDisclosure, Routes.clientAgreement,
  };

  if (state.signedIn) return null;          // signed in → free roam
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
                padding: const EdgeInsets.only(bottom: 12),
                child: Center(
                  child: KBottomNav(active: active, onChange: _onNav),
                ),
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
