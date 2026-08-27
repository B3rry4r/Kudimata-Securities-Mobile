// Live-backend gate — see docs/redesign/... task brief. Runs the ACTUAL app
// (lib/main.dart's `KudimataApp`, unmodified) inside a real Chrome tab via
// `flutter drive` + chromedriver, driven with real widget finders (never DOM
// selectors — the app renders with CanvasKit, so DOM selectors can't see
// into it at all). It proves the app can reach the real deployed backend
// (--dart-define=API_BASE_URL, see lib/data/api/api_client.dart) through the
// real login UI, with no minted token / injected session / test backdoor.
//
// Run via scripts/live_gate.sh — see that file for the exact command and for
// why chromedriver has to be started before this can run at all.
//
// ── Why these particular assertions ─────────────────────────────────────
// Every value asserted below was picked by first reading
// test/fixtures/mock_api_adapter.dart and choosing something IT PHYSICALLY
// CANNOT PRODUCE, so a pass here is only possible against a real backend:
//
//   - Home's greeting reads `Hi Ngozi` — the seed account's real first name
//     (confirmed via GET /users/me against the live API). The mock's
//     UserRepository fixture hardcodes 'Adebayo' (mock_api_adapter.dart
//     line 206) for every scenario; it has no code path that can ever
//     produce 'Ngozi'.
//   - Portfolio shows a DANGCEM row reading "40 shares · avg ₦520.00" — the
//     seed account's real DANGCEM holding (units=40, avgPriceKobo=52000,
//     confirmed via GET /holdings against the live API). The mock's
//     `_holdingsList()` (mock_api_adapter.dart line 126) hardcodes exactly
//     two holdings, MTNN and GTCO — DANGCEM never appears as a holding in
//     the mock under any scenario, so this row cannot exist without a real
//     backend.
//   - The fresh-signup account's Home shows the 'Complete your KYC' gap
//     banner — driven by that account's REAL kycStatus:'pending' from
//     GET /users/me. The mock's default scenario (MockKyc.none, what an
//     unparameterised MockApiAdapter() — what this whole app was built and
//     tested against — uses) never renders this screen for a signed-in
//     session at all; reaching it here requires an actual pending KYC
//     record the live backend returned for this real account.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:kudimata_invest/data/api/auth_token_store.dart';
import 'package:kudimata_invest/data/api/passcode_store.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart' show KErrorView;
import 'package:kudimata_invest/widgets/finance.dart' show KAssetRow;
import 'package:kudimata_invest/widgets/scaffold.dart' show KDetailHeader;

import 'package:kudimata_invest/main.dart' as app;

const _fullEmail = String.fromEnvironment(
  'LIVE_GATE_EMAIL',
  defaultValue: 'demo.full-investor-seed@kudimatasecurities.com',
);
const _fullPassword = String.fromEnvironment(
  'LIVE_GATE_PASSWORD',
  defaultValue: 'DemoInvestor#2026',
);
const _fullFirstName = 'Ngozi';

const _freshEmail = String.fromEnvironment(
  'LIVE_GATE_FRESH_EMAIL',
  defaultValue: 'demo.fresh-signup-seed@kudimatasecurities.com',
);
const _freshPassword = String.fromEnvironment(
  'LIVE_GATE_FRESH_PASSWORD',
  defaultValue: 'FreshSignup#2026',
);

// Any 6 digits — same value used for both the create and confirm step of
// each pass through the local-passcode-creation flow this login path always
// triggers on a device with no stored passcode (see log_in_screen.dart's
// header comment: EMAIL LOGIN always routes into Routes.createPasscode
// afterward).
const _passcode = '482051';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final results = <String, bool>{}; // surface -> passed
  final failures = <String>[];

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  void checkNoErrorView(String surface) {
    final ok = find.byType(KErrorView).evaluate().isEmpty;
    results[surface] = ok;
    if (!ok) failures.add('$surface: rendered KErrorView instead of content');
  }

  /// Types [digits] into whichever passcode keypad (create or confirm) is
  /// currently on screen — both use KKeypad, whose digit cells render as
  /// plain `Text('0'..'9')` (onboarding_scaffold.dart's KKeypad.digit).
  Future<void> enterPasscode(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.text(d).first);
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  /// Full real login: splash -> welcome -> "Sign in" -> email+password form
  /// -> POST /auth/login (real) -> create-passcode -> confirm-passcode ->
  /// hydrateGatingStateAndRoute (real GET /users/me, /kyc-submissions/me,
  /// etc.) -> Home. No token is ever injected; every step is a real widget
  /// interaction against the real backend.
  Future<void> realLogin(WidgetTester tester, {required String email, required String password}) async {
    app.main();
    // Splash's own beat is 1400ms (splash_screen.dart) before it decides
    // welcome vs. login; give it real time plus settle margin.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final signIn = find.text('Sign in');
    expect(signIn, findsWidgets, reason: 'Welcome screen "Sign in" CTA not found');
    await tester.tap(signIn.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Email+password form (log_in_screen.dart's _buildLoginForm) — two bare
    // TextFields in document order, Email then Password.
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2), reason: 'expected exactly the Email + Password fields');
    await tester.enterText(fields.at(0), email);
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(1), password);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in').last); // the KButton, not the CTA above
    // Real network round trip (POST /auth/login) — give it real time.
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // A device with no stored local passcode always lands on
    // Routes.createPasscode next (see log_in_screen.dart's
    // _completeLogin) — enter the same 6 digits twice (create, then
    // confirm).
    expect(find.text('Create a passcode'), findsOneWidget,
        reason: 'expected the create-passcode screen after a successful real login');
    await enterPasscode(tester, _passcode);
    await enterPasscode(tester, _passcode);

    // hydrateGatingStateAndRoute's own real GET /users/me (+ kyc/suitability
    // calls) then context.go(Routes.home) — real network again.
    await tester.pumpAndSettle(const Duration(seconds: 4));
  }

  /// Wipes local secure storage so the NEXT realLogin() call is a genuinely
  /// fresh device (no stored passcode/session) rather than a stale one from
  /// the previous account — not a shortcut around auth, just resetting
  /// on-device state between two real, independent login passes.
  Future<void> resetLocalDeviceState() async {
    await AuthTokenStore().clearTokens();
    await PasscodeStore().clearPasscode();
  }

  testWidgets('real backend — full investor: login, server-only data, all primary surfaces', (tester) async {
    await realLogin(tester, email: _fullEmail, password: _fullPassword);

    // ── 1. Home — real auth handshake landed here; server-only greeting ──
    checkNoErrorView('Home (full investor)');
    expect(
      find.text('Hi $_fullFirstName'),
      findsOneWidget,
      reason:
          'Home greeting should read the REAL account first name ($_fullFirstName) from '
          'GET /users/me — the mock hardcodes "Adebayo" and can never produce this',
    );
    // Approved KYC on this account -> no gap banner at all.
    expect(find.textContaining('Complete your KYC'), findsNothing,
        reason: 'full investor account is KYC-approved; no gap banner should render');
    await shot(tester, 'home_full_investor');

    // ── 2. Portfolio — server-only DANGCEM position ─────────────────────
    await tester.tap(find.text('PORTFOLIO'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    checkNoErrorView('Portfolio');
    expect(
      find.text('40 shares · avg ₦520.00'),
      findsOneWidget,
      reason:
          'DANGCEM holding (40 units @ ₦520.00 avg) comes from the real GET /holdings '
          'response; the mock only ever returns MTNN and GTCO holdings, never DANGCEM',
    );
    await shot(tester, 'portfolio_full_investor');

    // ── 3. Markets + Asset detail (real navigation: tap a row) ──────────
    await tester.tap(find.text('MARKETS'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    checkNoErrorView('Markets');
    await shot(tester, 'markets_full_investor');

    final assetRows = find.byType(KAssetRow);
    expect(assetRows, findsWidgets, reason: 'Markets should list at least one asset row to tap into');
    await tester.tap(assetRows.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    checkNoErrorView('Asset detail');
    await shot(tester, 'asset_detail_full_investor');
    // Back to Markets via the shared pushed-screen header (KDetailHeader —
    // lib/widgets/scaffold.dart; its first GestureDetector is the back chip).
    final assetBack = find.descendant(of: find.byType(KDetailHeader), matching: find.byType(GestureDetector));
    await tester.tap(assetBack.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // ── 4. Wallet ─────────────────────────────────────────────────────
    await tester.tap(find.text('WALLET'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    checkNoErrorView('Wallet');
    await shot(tester, 'wallet_full_investor');

    // ── 5. Orders (pushed from Home) ─────────────────────────────────
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.text('Orders').first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    checkNoErrorView('Orders');
    await shot(tester, 'orders_full_investor');
    final ordersBack = find.descendant(of: find.byType(KDetailHeader), matching: find.byType(GestureDetector));
    if (ordersBack.evaluate().isNotEmpty) {
      await tester.tap(ordersBack.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    // ── 6. Account (pushed from Home's avatar) ────────────────────────
    await tester.tap(find.text('Hi $_fullFirstName'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    checkNoErrorView('Account');
    await shot(tester, 'account_full_investor');

    // Clean local state for the next real login pass.
    await resetLocalDeviceState();

    if (failures.isNotEmpty) {
      fail('Live-gate surface failures (full investor):\n${failures.join('\n')}');
    }
  });

  testWidgets('real backend — fresh signup: unverified account sees the KYC gate', (tester) async {
    await realLogin(tester, email: _freshEmail, password: _freshPassword);

    checkNoErrorView('Home (fresh signup)');
    expect(
      find.textContaining('Complete your KYC'),
      findsOneWidget,
      reason:
          'the fresh-signup account has real kycStatus:"pending" (GET /users/me) — Home '
          'should show the gap banner, never the fully-verified body an approved '
          'investor sees. The mock\'s default (unparameterised) scenario never renders '
          'a signed-in Home in this state at all.',
    );
    await shot(tester, 'home_fresh_signup_kyc_gate');

    await resetLocalDeviceState();

    if (results['Home (fresh signup)'] != true) {
      fail('Live-gate surface failure (fresh signup): Home rendered KErrorView');
    }
  });
}
