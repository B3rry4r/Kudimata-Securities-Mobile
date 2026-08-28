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
// ── Why this never uses pumpAndSettle ───────────────────────────────────
// `pumpAndSettle` waits for zero pending frames AND zero pending timers.
// This app never reaches that state while it's running correctly:
//   lib/widgets/spinner.dart:26        AnimationController(...)..repeat() — infinite
//   lib/screens/home/home_screen.dart  rotating movers card Timer.periodic(4s)
//   lib/screens/home/home_screen.dart  portfolio poll Timer.periodic(8s)
// A spinner that spins is correct behaviour — the fix belongs in this test,
// not in the app's animations. [pumpUntil] below pumps in short slices
// until a specific, named condition is true, or fails with a message
// naming exactly what it was waiting for. This gate also talks to a REAL
// backend over the network, so every wait is bounded by a generous
// wall-clock timeout rather than a fixed frame/pump count — real latency,
// not simulated time.
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
import 'package:kudimata_invest/screens/shared/state_views.dart' show KErrorView, KLoadingView;
import 'package:kudimata_invest/widgets/buttons.dart' show KIconButton;
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

  /// Pumps in short real-time slices — always at least one, so a condition
  /// that only becomes true as a DIRECT RESULT of the frame just pumped
  /// (e.g. "the loading spinner for the screen I just navigated to is
  /// gone") is never checked against stale, pre-navigation state — until
  /// [condition] is true, or fails naming [what] after [timeout]. This is
  /// the one replacement for every `pumpAndSettle` call this file used to
  /// make (see file header for why pumpAndSettle can't be used here at
  /// all). [timeout] defaults generously since this drives a real backend
  /// over a real network connection, not a mock.
  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition,
    String what, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    do {
      await tester.pump(const Duration(milliseconds: 200));
      if (condition()) return;
    } while (DateTime.now().isBefore(deadline));
    fail('Timed out after ${timeout.inSeconds}s waiting for $what');
  }

  /// Pumps in short slices for a fixed, bounded [duration] — for the rare
  /// spot with no specific widget/state worth naming as a wait condition
  /// (settling a screenshot, settling a same-screen text-field edit, the
  /// client-side-only transition between the create/confirm passcode
  /// steps). Still bounded, never open-ended like `pumpAndSettle`.
  Future<void> pumpBriefly(WidgetTester tester, {Duration duration = const Duration(seconds: 1)}) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await pumpBriefly(tester, duration: const Duration(milliseconds: 500));
    await binding.takeScreenshot(name);
  }

  void checkNoErrorView(String surface) {
    final ok = find.byType(KErrorView).evaluate().isEmpty;
    results[surface] = ok;
    if (!ok) failures.add('$surface: rendered KErrorView instead of content');
  }

  /// Waits for whichever screen's own loading spinner (KLoadingView, the
  /// shared FutureBuilder-loading widget every wired screen uses — see
  /// lib/data/api/README.md) to be gone — i.e. the screen's own fetch has
  /// resolved, either into real content or into a KErrorView, which
  /// [checkNoErrorView] then reports on with a specific reason. Bounded by
  /// real network latency, not a frame count.
  Future<void> waitForLoad(WidgetTester tester, String surface) => pumpUntil(
        tester,
        () => find.byType(KLoadingView).evaluate().isEmpty,
        '$surface to finish loading',
      );

  /// Types [digits] into whichever passcode keypad (create or confirm) is
  /// currently on screen — both use KKeypad, whose digit cells render as
  /// plain `Text('0'..'9')` (onboarding_scaffold.dart's KKeypad.digit).
  Future<void> enterPasscode(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.text(d).first);
      await tester.pump(const Duration(milliseconds: 80));
    }
    await pumpBriefly(tester);
  }

  /// Full real login: splash -> welcome -> "Sign in" -> email+password form
  /// -> POST /auth/login (real) -> create-passcode -> confirm-passcode ->
  /// hydrateGatingStateAndRoute (real GET /users/me, /kyc-submissions/me,
  /// etc.) -> Home. No token is ever injected; every step is a real widget
  /// interaction against the real backend.
  Future<void> realLogin(WidgetTester tester, {required String email, required String password}) async {
    app.main();
    // Splash's own beat is 1400ms (splash_screen.dart) before it decides
    // welcome vs. login — wait for the actual welcome screen rather than a
    // fixed pump count.
    await pumpUntil(
      tester,
      () => find.text('Sign in').evaluate().isNotEmpty,
      'the welcome screen ("Sign in" CTA) to appear after splash',
    );

    final signIn = find.text('Sign in');
    expect(signIn, findsWidgets, reason: 'Welcome screen "Sign in" CTA not found');
    await tester.tap(signIn.first);
    await pumpUntil(
      tester,
      () => find.byType(TextField).evaluate().isNotEmpty,
      'the email/password login form after tapping "Sign in"',
    );

    // Email+password form (log_in_screen.dart's _buildLoginForm) — two bare
    // TextFields in document order, Email then Password.
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2), reason: 'expected exactly the Email + Password fields');
    await tester.enterText(fields.at(0), email);
    await pumpBriefly(tester, duration: const Duration(milliseconds: 300));
    await tester.enterText(fields.at(1), password);
    await pumpBriefly(tester, duration: const Duration(milliseconds: 300));

    await tester.tap(find.text('Sign in').last); // the KButton, not the CTA above
    // Real network round trip (POST /auth/login) — real latency, so this
    // waits for the actual next screen instead of a fixed pump duration.
    await pumpUntil(
      tester,
      () => find.text('Create a passcode').evaluate().isNotEmpty,
      'the create-passcode screen after a successful login (POST /auth/login)',
      timeout: const Duration(seconds: 30),
    );

    // A device with no stored local passcode always lands on
    // Routes.createPasscode next (see log_in_screen.dart's
    // _completeLogin) — enter the same 6 digits twice (create, then
    // confirm).
    expect(find.text('Create a passcode'), findsOneWidget,
        reason: 'expected the create-passcode screen after a successful real login');
    await enterPasscode(tester, _passcode);
    await enterPasscode(tester, _passcode);

    // hydrateGatingStateAndRoute's own real GET /users/me (+ kyc/suitability
    // calls) then context.go(Routes.home) — real network again. Home's
    // header always renders "Hi <first name>" regardless of KYC state
    // (_HomeBody builds it unconditionally), so it's a reliable marker for
    // both seed accounts used below.
    await pumpUntil(
      tester,
      () => find.textContaining('Hi ').evaluate().isNotEmpty,
      "Home's greeting after the real gating check (GET /users/me, /kyc-submissions/me)",
      timeout: const Duration(seconds: 30),
    );
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
    await waitForLoad(tester, 'Portfolio (GET /holdings, /portfolio-summary)');
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
    await waitForLoad(tester, 'Markets (GET /assets)');
    checkNoErrorView('Markets');
    await shot(tester, 'markets_full_investor');

    final assetRows = find.byType(KAssetRow);
    expect(assetRows, findsWidgets, reason: 'Markets should list at least one asset row to tap into');
    await tester.tap(assetRows.first);
    await waitForLoad(tester, 'Asset detail');
    checkNoErrorView('Asset detail');
    await shot(tester, 'asset_detail_full_investor');
    // Back to Markets — asset_detail_screen.dart builds its own top bar
    // (NOT the shared KDetailHeader every pushed detail-style screen below
    // uses), a plain `KIconButton(icon: 'back', ...)` as the first icon
    // button in that bar.
    final assetBack = find.byType(KIconButton);
    expect(assetBack, findsWidgets, reason: 'Asset detail should have a back icon button');
    await tester.tap(assetBack.first);
    await pumpUntil(
      tester,
      () => find.byType(KAssetRow).evaluate().isNotEmpty,
      'Markets to return after tapping back from Asset detail',
    );

    // ── 4. Wallet ─────────────────────────────────────────────────────
    await tester.tap(find.text('WALLET'));
    await waitForLoad(tester, 'Wallet (GET /wallet-balance, /transactions)');
    checkNoErrorView('Wallet');
    await shot(tester, 'wallet_full_investor');

    // ── 5. Orders (pushed from Home) ─────────────────────────────────
    await tester.tap(find.text('HOME'));
    await pumpUntil(
      tester,
      () => find.text('Orders').evaluate().isNotEmpty,
      'Home to show the Orders quick action after switching tabs',
    );
    await tester.tap(find.text('Orders').first);
    await waitForLoad(tester, 'Orders (GET /orders)');
    checkNoErrorView('Orders');
    await shot(tester, 'orders_full_investor');
    final ordersBack = find.descendant(of: find.byType(KDetailHeader), matching: find.byType(GestureDetector));
    if (ordersBack.evaluate().isNotEmpty) {
      await tester.tap(ordersBack.first);
      await pumpUntil(
        tester,
        () => find.byType(KDetailHeader).evaluate().isEmpty,
        'Home to return after tapping back from Orders',
      );
    }

    // ── 6. Account (pushed from Home's avatar) ────────────────────────
    await tester.tap(find.text('Hi $_fullFirstName'));
    await waitForLoad(tester, 'Account');
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
