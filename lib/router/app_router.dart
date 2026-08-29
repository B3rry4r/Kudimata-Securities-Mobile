// Kudimata Securities — GoRouter (Stage 10 wiring, R-28 2026-08-26: 4 tabs).
// One StatefulShellRoute with 4 indexed-stack branches (Home · Markets ·
// Portfolio · Wallet), each keeping its own stack, under a shell scaffold
// that floats KBottomNav above the content. Every gated / KYC / suitability /
// pushed-detail / account-sub route is TOP-LEVEL so it covers the tab bar (no
// nav, KDetailHeader chrome) — Account itself is now one of these too (it was
// the 5th tab, "You"; R-28 removed it in favour of the header avatar).
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/widgets.dart';

import 'routes.dart';

// Onboarding / security.
import '../screens/onboarding/splash_screen.dart';
import '../screens/onboarding/welcome_slider_screen.dart';
import '../screens/onboarding/sign_up_screen.dart';
import '../screens/onboarding/otp_screen.dart';
import '../screens/onboarding/create_passcode_screen.dart';
import '../screens/onboarding/confirm_passcode_screen.dart';
import '../screens/onboarding/biometric_screen.dart';
import '../screens/onboarding/avatar_screen.dart';
import '../screens/onboarding/whats_next_screen.dart';
import '../screens/onboarding/personal_details_screen.dart';
import '../screens/onboarding/log_in_screen.dart';
import '../screens/onboarding/reset_passcode_screen.dart';
import '../screens/onboarding/legal_preview_screen.dart';

// KYC.
import '../screens/kyc/kyc_intro.dart';
import '../screens/kyc/kyc_checklist_screen.dart';
import '../screens/kyc/bvn_nin.dart';
import '../screens/kyc/chn_screen.dart';
import '../screens/kyc/id_upload.dart';
import '../screens/kyc/liveness.dart';
import '../screens/kyc/checking.dart';
import '../screens/kyc/utility_bill.dart';
import '../screens/kyc/bank_dcs_screen.dart';
import '../screens/kyc/declarations_screen.dart';
import '../screens/kyc/next_of_kin.dart';
import '../screens/kyc/submitted.dart';
import '../screens/kyc/approved.dart';
import '../screens/kyc/outcome_not_approved.dart';

// Suitability & agreements.
import '../screens/suitability/questionnaire_screen.dart';
import '../screens/suitability/risk_disclaimer_screen.dart';
import '../screens/suitability/suitability_result_screen.dart';
import '../screens/suitability/terms_and_privacy_screen.dart';

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
import '../screens/markets/asset_detail_screen.dart';
import '../screens/markets/explain_screen.dart';

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
import '../screens/account/freeze_account_screen.dart';
import '../screens/account/security_alert_screen.dart';
import '../screens/account/plans_screen.dart';
import '../screens/account/withdraw_mandate_screen.dart';
import '../screens/account/contract_note_screen.dart';
import '../data/repositories/bank_accounts_repository.dart' show BankAccountSummary;
import '../data/repositories/statements_repository.dart' show Statement;

// Screens 76-97 (2026-08-23 canvas expansion).
import '../screens/account/statement_detail_screen.dart';
import '../screens/account/tax_documents_screen.dart';
import '../screens/markets/price_alerts_screen.dart';
import '../screens/corporate_actions/corporate_actions_screen.dart';
import '../screens/corporate_actions/rights_issue_screen.dart';
import '../screens/corporate_actions/agm_vote_screen.dart';
import '../screens/corporate_actions/dividends_screen.dart';
import '../screens/account/complaint_screen.dart';
import '../screens/account/complaint_tracked_screen.dart';
import '../screens/account/dormant_account_screen.dart';
import '../screens/account/close_account_screen.dart';
import '../screens/account/data_privacy_screen.dart';
import '../screens/onboarding/locked_out_screen.dart';
import '../screens/account/legal_reference_screens.dart';

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
  final marketsKey = GlobalKey<NavigatorState>();
  final portfolioKey = GlobalKey<NavigatorState>();
  final walletKey = GlobalKey<NavigatorState>();

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
      GoRoute(path: Routes.welcome, builder: (_, _) => themed(() => WelcomeSliderScreen())),
      GoRoute(path: Routes.signup, builder: (_, _) => themed(() => SignUpScreen())),
      GoRoute(path: Routes.otp, builder: (_, _) => themed(() => OtpScreen())),
      GoRoute(
        path: Routes.legalBundlePreview,
        builder: (_, _) => themed(() => LegalBundlePreviewScreen()),
      ),
      GoRoute(
        path: Routes.legalPreviewPath,
        builder: (_, st) =>
            themed(() => LegalPreviewScreen(kind: st.pathParameters['kind']!)),
      ),
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
        // store) — bounce straight past it, same as BiometricScreen's own
        // "Maybe later" path, rather than showing a screen offering a
        // capability that will never work.
        //
        // 2026-08-29 (A-1 audit fix): used to redirect to
        // Routes.onboardingPersonal — confirm_passcode_screen.dart's OWN
        // kIsWeb branch already bypasses this route entirely and calls
        // hydrateGatingStateAndRoute() directly, so in practice nothing
        // reaches this redirect via the real signup flow any more; kept
        // only as a defensive fallback for a direct/deep-link hit on `/biometric`
        // from a web session. onboardingPersonal is no longer on the KYC
        // path at all (kyc_intro.dart's `_start()` — DOB now folds into
        // bvn_nin.dart's confirm step), so this now matches
        // hydrateGatingStateAndRoute's own destination instead of a
        // detour that no longer leads anywhere real.
        redirect: (_, _) => kIsWeb ? Routes.home : null,
        builder: (_, _) => themed(() => BiometricScreen()),
      ),
      GoRoute(
        path: Routes.onboardingPersonal,
        builder: (_, _) => themed(() => OnboardingPersonalDetailsScreen()),
      ),
      GoRoute(
        path: Routes.onboardingAvatar,
        builder: (_, _) => themed(() => OnboardingAvatarScreen()),
      ),
      GoRoute(
        path: Routes.onboardingNextSteps,
        builder: (_, _) => themed(() => WhatsNextScreen()),
      ),
      GoRoute(
        path: Routes.login,
        // `extra: true` (main.dart's resume-lock push, A-6 2026-08-29 audit)
        // marks this as a re-lock challenge over an already-signed-in
        // session rather than the ordinary pre-auth/returning-unlock entry
        // — see LogInScreen.resumeLock's doc comment for the behavior
        // difference (pop back to whatever was underneath instead of
        // routing to Home, and a PopScope that refuses to be dismissed any
        // other way).
        builder: (_, st) => themed(() => LogInScreen(resumeLock: st.extra == true)),
      ),
      GoRoute(path: Routes.reset, builder: (_, _) => themed(() => ResetPasscodeScreen())),

      // ── KYC ───────────────────────────────────────────────────────────--
      GoRoute(path: Routes.kycIntro, builder: (_, _) => themed(() => KycIntroScreen())),
      GoRoute(path: Routes.kycChecklist, builder: (_, _) => themed(() => KycChecklistScreen())),
      GoRoute(path: Routes.kycBvn, builder: (_, _) => themed(() => BvnNinScreen())),
      GoRoute(path: Routes.kycChn, builder: (_, _) => themed(() => ChnScreen())),
      GoRoute(path: Routes.kycId, builder: (_, _) => themed(() => IdUploadScreen())),
      GoRoute(path: Routes.kycLiveness, builder: (_, _) => themed(() => LivenessScreen())),
      GoRoute(path: Routes.kycChecking, builder: (_, _) => themed(() => CheckingScreen())),
      GoRoute(path: Routes.kycUtilityBill, builder: (_, _) => themed(() => UtilityBillScreen())),
      GoRoute(path: Routes.kycBankDcs, builder: (_, _) => themed(() => BankDcsScreen())),
      GoRoute(path: Routes.kycDeclarations, builder: (_, _) => themed(() => DeclarationsScreen())),
      GoRoute(path: Routes.kycNextOfKin, builder: (_, _) => themed(() => NextOfKinScreen())),
      GoRoute(path: Routes.kycSubmitted, builder: (_, _) => themed(() => SubmittedScreen())),
      GoRoute(path: Routes.kycApproved, builder: (_, _) => themed(() => ApprovedScreen())),
      GoRoute(path: Routes.kycOutcome, builder: (_, _) => themed(() => KycOutcomeScreen())),

      // ── Suitability & agreements ───────────────────────────────────────--
      GoRoute(path: Routes.questionnaire, builder: (_, _) => themed(() => QuestionnaireScreen())),
      GoRoute(path: Routes.suitabilityResult, builder: (_, _) => themed(() => SuitabilityResultScreen())),
      GoRoute(
        path: Routes.riskDisclaimer,
        // R-8a (DECISIONS.md, 2026-08-27): its own scroll-gated in-app
        // screen, run right after suitability's result — pushed from
        // suitability_result_screen.dart with a RiskDisclaimerArgs `extra`
        // (profile already known there, though R-2 means the screen never
        // displays it), or from AppState.tradingEligibilityGap's prompt
        // (home_screen.dart) with no `extra` at all for a returning
        // investor re-gated here directly.
        builder: (_, st) {
          final args = st.extra;
          return themed(() => RiskDisclaimerScreen(
                profile: args is RiskDisclaimerArgs ? args.profile : null,
              ));
        },
      ),
      GoRoute(
        path: Routes.termsOfService,
        // R-8a: the remaining THREE legal documents (risk disclosure moved
        // to its own screen above) in one screen/one tick — reached from
        // risk_disclaimer_screen.dart's own accept action, not straight off
        // OTP any more. The account email rides AppState.pendingSignupEmail
        // across the suitability/result/risk-disclaimer hops between OTP
        // and here (see that field's doc comment) rather than this route's
        // `extra`.
        builder: (_, _) => themed(() => TermsAndPrivacyScreen()),
      ),

      // ── Pushed detail (top-level — cover the shell, no tab bar) ─────────--
      GoRoute(path: Routes.notifications, builder: (_, _) => themed(() => NotificationsScreen())),
      GoRoute(path: Routes.search, builder: (_, _) => themed(() => SearchScreen())),
      GoRoute(path: Routes.orderStatus, builder: (_, _) => themed(() => OrderStatusScreen())),
      GoRoute(
        path: Routes.assetDetailPath,
        builder: (_, st) => themed(() => AssetDetailScreen(ticker: st.pathParameters['ticker']!)),
      ),
      GoRoute(
        // Set a price alert (screen s49) — S-11/X-7, SHARED-CHANGES.md.
        path: Routes.setPriceAlertPath,
        builder: (_, st) => themed(() => SetPriceAlertScreen(ticker: st.pathParameters['ticker']!)),
      ),
      GoRoute(
        path: Routes.explainThisPath,
        builder: (_, st) => themed(() => ExplainScreen(topic: st.pathParameters['topic']!)),
      ),
      GoRoute(
        path: Routes.holdingDetailPath,
        builder: (_, st) => themed(() => HoldingDetailScreen(ticker: st.pathParameters['ticker']!)),
      ),
      GoRoute(
        path: Routes.transactionDetailPath,
        builder: (_, st) => themed(() => TransactionDetailScreen(id: st.pathParameters['id']!)),
      ),

      // ── Account (pushed) ────────────────────────────────────────────────
      // R-28: no longer a shell branch/tab ("You" removed) — reached by
      // pushing from the header avatar on Home instead. Same route path
      // (Routes.account), so close_account_screen.dart's context.go(Routes.
      // account) after a cancelled closure still resolves.
      GoRoute(path: Routes.account, builder: (_, _) => themed(() => AccountScreen())),

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
      GoRoute(path: Routes.acctFreeze, builder: (_, _) => themed(() => FreezeAccountScreen())),
      GoRoute(path: Routes.securityAlert, builder: (_, _) => themed(() => SecurityAlertScreen())),
      GoRoute(path: Routes.acctPlans, builder: (_, _) => themed(() => PlansScreen())),
      GoRoute(
        // Screen 65 — pushed from bank_accounts_screen.dart's row actions
        // with a BankAccountSummary `extra`.
        path: Routes.acctWithdrawMandate,
        builder: (_, st) {
          final account = st.extra;
          if (account is! BankAccountSummary) {
            return themed(() => const KErrorView());
          }
          return themed(() => WithdrawMandateScreen(account: account));
        },
      ),
      GoRoute(
        // Screen 66 — pushed from statements_screen.dart's contract-note
        // rows with a Statement `extra`.
        path: Routes.contractNote,
        builder: (_, st) {
          final statement = st.extra;
          if (statement is! Statement) {
            return themed(() => const KErrorView());
          }
          return themed(() => ContractNoteScreen(statement: statement));
        },
      ),

      // ── Screens 76-97 (2026-08-23 canvas expansion) ──────────────────────
      GoRoute(
        // Screen 76 — pushed from statements_screen.dart with a Statement
        // `extra`.
        path: Routes.acctStatementDetail,
        builder: (_, st) {
          final statement = st.extra;
          if (statement is! Statement) {
            return themed(() => const KErrorView());
          }
          return themed(() => StatementDetailScreen(statement: statement));
        },
      ),
      GoRoute(path: Routes.acctTax, builder: (_, _) => themed(() => TaxDocumentsScreen())),
      GoRoute(path: Routes.priceAlerts, builder: (_, _) => themed(() => PriceAlertsScreen())),
      GoRoute(path: Routes.corpActions, builder: (_, _) => themed(() => CorporateActionsScreen())),
      GoRoute(
        path: Routes.corpActionsRightsIssue,
        builder: (_, _) => themed(() => RightsIssueScreen()),
      ),
      GoRoute(path: Routes.corpActionsAgm, builder: (_, _) => themed(() => AgmVoteScreen())),
      GoRoute(
        path: Routes.corpActionsDividends,
        builder: (_, _) => themed(() => DividendsScreen()),
      ),
      GoRoute(path: Routes.acctComplaint, builder: (_, _) => themed(() => ComplaintScreen())),
      GoRoute(
        // Pushed with a ComplaintSummary `extra` — no live entry point yet
        // (see routes.dart), registered so the built screen is reachable
        // once complaint submission has a real backend to return one from.
        path: Routes.acctComplaintTracked,
        builder: (_, st) {
          final complaint = st.extra;
          if (complaint is! ComplaintSummary) {
            return themed(() => const KErrorView());
          }
          return themed(() => ComplaintTrackedScreen(complaint: complaint));
        },
      ),
      GoRoute(path: Routes.acctDormant, builder: (_, _) => themed(() => DormantAccountScreen())),
      GoRoute(path: Routes.acctClose, builder: (_, _) => themed(() => CloseAccountScreen())),
      GoRoute(
        path: Routes.acctDataPrivacy,
        builder: (_, _) => themed(() => DataPrivacyScreen()),
      ),
      GoRoute(path: Routes.lockedOut, builder: (_, _) => themed(() => LockedOutScreen())),
      GoRoute(
        path: Routes.acctLegalPartnerDisclosures,
        builder: (_, _) => themed(() => PartnerDisclosuresScreen()),
      ),
      GoRoute(
        path: Routes.acctLegalReferralTerms,
        builder: (_, _) => themed(() => ReferralTermsScreen()),
      ),
      GoRoute(
        path: Routes.acctLegalDataNotice,
        builder: (_, _) => themed(() => DataNoticeScreen()),
      ),
      GoRoute(
        path: Routes.acctLegalClosureTerms,
        builder: (_, _) => themed(() => AccountClosureTermsScreen()),
      ),

      // ── Tab shell (StatefulShellRoute / indexedStack) ──────────────────--
      StatefulShellRoute.indexedStack(
        builder: (context, st, navShell) => themed(() => _TabShell(navShell: navShell)),
        branches: [
          StatefulShellBranch(navigatorKey: homeKey, routes: [
            GoRoute(path: Routes.home, builder: (_, _) => themed(() => HomeScreen())),
          ]),
          StatefulShellBranch(navigatorKey: marketsKey, routes: [
            GoRoute(path: Routes.markets, builder: (_, _) => themed(() => MarketsScreen())),
          ]),
          StatefulShellBranch(navigatorKey: portfolioKey, routes: [
            GoRoute(path: Routes.portfolio, builder: (_, _) => themed(() => PortfolioScreen())),
          ]),
          StatefulShellBranch(navigatorKey: walletKey, routes: [
            GoRoute(path: Routes.wallet, builder: (_, _) => themed(() => WalletScreen())),
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
    Routes.splash, Routes.welcome, Routes.signup, Routes.otp,
    Routes.createPasscode, Routes.confirmPasscode,
    Routes.biometric, Routes.onboardingPersonal, Routes.onboardingAvatar,
    Routes.onboardingNextSteps, Routes.login, Routes.reset,
    Routes.kycIntro, Routes.kycChecklist, Routes.kycBvn, Routes.kycChn, Routes.kycId,
    Routes.kycLiveness, Routes.kycChecking, Routes.kycUtilityBill,
    Routes.kycBankDcs, Routes.kycDeclarations, Routes.kycNextOfKin,
    Routes.kycSubmitted, Routes.kycApproved, Routes.kycOutcome,
    Routes.questionnaire, Routes.suitabilityResult, Routes.riskDisclaimer,
    Routes.termsOfService,
  };

  // Pre-auth-only screens — never legitimately reachable once fully signed
  // in, regardless of how the app landed there (fresh navigation, stale
  // history, deep link).
  const preAuthOnly = <String>{
    Routes.splash, Routes.welcome, Routes.signup, Routes.otp, Routes.reset,
  };

  if (state.signedIn) {
    if (preAuthOnly.contains(loc)) return Routes.home;
    return null;                            // otherwise free roam
  }
  if (gated.contains(loc)) return null;     // gated flow always allowed
  // Legal-document preview is reachable pre-signup (sign_up_screen.dart's
  // "By continuing..." link) — both the bundle list (exact match) and each
  // individual document (a parameterized route, so a prefix check rather
  // than the `gated` set's exact-string membership).
  if (loc == Routes.legalBundlePreview) return null;
  if (loc.startsWith('/legal-preview/')) return null;
  return Routes.splash;                      // any deep link into the app → splash
}

// ── Tab shell scaffold: content + floating KBottomNav ───────────────────────
class _TabShell extends StatelessWidget {
  const _TabShell({required this.navShell});
  final StatefulNavigationShell navShell;

  // KBottomNav item id → branch index. R-28: 4 tabs, Markets before
  // Portfolio; Account/`profile` is no longer a branch at all (pushed from
  // the header avatar instead — see home_screen.dart).
  static const _branchForNav = {
    'home': 0,
    'markets': 1,
    'portfolio': 2,
    'wallet': 3,
  };
  static const _navForBranch = ['home', 'markets', 'portfolio', 'wallet'];

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
