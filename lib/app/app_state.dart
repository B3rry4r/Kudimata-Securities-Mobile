// Kudimata Securities — minimal app session state. Drives the gated-flow router
// (passcode → biometric → KYC → suitability → tabs) and the live watchlist set.
// SEAM: real auth/KYC/suitability outcomes flip these flags; here they are flipped
// by the demo flows.
// Persistence: `signedIn` is now backed by AuthTokenStore (flutter_secure_storage)
// — the secure store this comment used to say "plugs in later". See
// _hydrateSignedIn() and forceSignOut() below. Every other flag here is still
// in-memory only.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/api/api_client.dart';
import '../data/api/auth_token_store.dart';
import '../data/api/passcode_store.dart';
import '../data/repositories/market_status_repository.dart';
import '../data/repositories/watchlist_repository.dart';
import '../router/routes.dart';
import '../screens/kyc/kyc_form_state.dart';
// isNgxOpenNow() is the local-clock fallback for [marketOpen] below — kept
// in the markets screen's own file (its original home, still imported
// directly by several screens) rather than duplicated here.
import '../screens/markets/market_hours.dart';

class AppState extends ChangeNotifier {
  AppState({
    Set<String>? watchlistTickers,
    AuthTokenStore? tokenStore,
    PasscodeStore? passcodeStore,
    // `?? {}` — this used to default to a hardcoded {'MTNN', 'GTCO',
    // 'ZENITHBANK', 'DANGCEM'} mock set, never hydrated from the real
    // watchlist. That made asset_detail_screen.dart's save toggle (which
    // reads AppState.isWatched()) show those 4 tickers as permanently
    // "saved" regardless of what the investor's account actually had saved
    // server-side — found live 2026-08-10 ("a particular opened market
    // screen is always showing toggled"). Starts empty now; see
    // hydrateWatchlist() below for how it gets populated with real data.
  })  : _watchlist = watchlistTickers ?? {},
        _tokenStore = tokenStore ?? AuthTokenStore(),
        _passcodeStore = passcodeStore ?? PasscodeStore() {
    ready = _hydrate();
  }

  /// Resolves once startup hydration ([_hydrateSignedIn] +
  /// [_hydratePasscodeSet]) has completed. [signedIn] and [passcodeSet]
  /// both start `false` synchronously (before the secure-storage reads that
  /// back them return) — callers that need a startup-correct read of either
  /// flag, rather than just reacting to a later [notifyListeners] call, must
  /// await this first. See splash_screen.dart's routing decision.
  late final Future<void> ready;

  Future<void> _hydrate() async {
    await Future.wait([_hydrateSignedIn(), _hydratePasscodeSet()]);
  }

  final AuthTokenStore _tokenStore;
  final PasscodeStore _passcodeStore;

  /// The single shared [ApiClient] — assigned exactly once, at app startup,
  /// by `main.dart`'s `_KudimataAppState.initState` (which wires this same
  /// AppState's [forceSignOut] as the client's `onSessionExpired` callback).
  /// `late final`: unset reads before that assignment throw a clear
  /// LateInitializationError rather than silently returning null.
  ///
  /// Every screen/repository reaches it via the SAME `AppScope` this app
  /// already threads `AppState` through — no second InheritedWidget:
  ///   `AppScope.read(context).apiClient`  (event handlers, initState, repo construction)
  ///   `AppScope.of(context).apiClient`    (only if the widget already listens to AppState)
  /// See lib/data/api/README.md.
  late final ApiClient apiClient;

  /// The single shared [KycFormState] — assigned exactly once, at app
  /// startup, by `main.dart`'s `_KudimataAppState.initState`, alongside
  /// [apiClient]. Holds every field the KYC screens (bvn → id-upload →
  /// liveness → next-of-kin) collect, since only the last of those screens
  /// makes the real `POST /kyc-submissions` call — see
  /// lib/screens/kyc/kyc_form_state.dart for the field list and usage.
  /// Reached the same way as [apiClient]:
  ///   `AppScope.read(context).kycForm`  (event handlers, initState)
  ///   `AppScope.of(context).kycForm`    (only if already listening to AppState)
  late final KycFormState kycForm;

  // Onboarding / gate flags.
  bool passcodeSet = false;
  bool biometricEnabled = false;
  bool kycSubmitted = false;
  bool kycApproved = false;
  bool suitabilityComplete = false;

  /// Which of the 5 phased-KYC steps (2026-08-20) an in-progress draft is
  /// resuming at, and the fixed total — both null when there's no known
  /// in-progress draft (never started, or already finalized/decided).
  /// Populated by hydrateGatingStateAndRoute (log_in_screen.dart) alongside
  /// kycSubmitted/kycApproved; read by tradingEligibilityGap below to show
  /// Home's "Complete your KYC — N/5 done" prompt and resume at the right
  /// step instead of always restarting at step 1.
  int? kycDraftStep;
  int? kycDraftTotal;

  /// One of 'rejected' | 'flagged' | 'expired', or null while there's no
  /// known terminal-non-approved outcome (never submitted, still
  /// pending/review, or approved). 2026-08-20 fix — reported: "a rejected
  /// account is showing needs manual review [on Home]... thats a hard
  /// wall." Before this existed, tradingEligibilityGap() below only ever
  /// checked the boolean kycApproved, so a genuine hard REJECTION looked
  /// identical to a submission still quietly awaiting a decision — Home's
  /// prompt always said "Your KYC is under review" and routed to the
  /// pending-polling screen, regardless of how final the real outcome
  /// actually was. Populated by refreshKycGatingState (log_in_screen.dart)
  /// alongside kycSubmitted/kycApproved.
  String? kycOutcomeStatus;
  bool signedIn = false;

  /// True while a fresh email+password login (log_in_screen.dart) is
  /// walking its device through first-time LOCAL passcode creation, so
  /// confirm_passcode_screen.dart can tell that case apart from both
  /// first-time signup onboarding (reentry=false, continues to Biometric)
  /// and Security's change-passcode reentry (reentry=true, pops back to
  /// Security) — neither of which the existing `reentry` bool alone can
  /// distinguish. Threaded via AppState rather than GoRouter `extra` because
  /// app_router.dart's CreatePasscode/ConfirmPasscode route builders only
  /// ever forward `reentry`/`created` out of `extra`, not a third value.
  /// Consumed (set back to false) by confirm_passcode_screen.dart the
  /// instant it acts on it, so it never leaks into a later, unrelated
  /// security-reentry passcode change.
  bool loginPasscodeSetup = false;

  // Live watchlist (tickers).
  final Set<String> _watchlist;
  Set<String> get watchlistTickers => Set.unmodifiable(_watchlist);
  bool isWatched(String ticker) => _watchlist.contains(ticker);

  /// Bumped on every real mutation ([toggleWatch]/[addWatch]/[removeWatch])
  /// — a lightweight "the watchlist changed" signal for screens (home_screen.dart)
  /// that fetch their OWN server-truth watchlist list rather than reading
  /// [watchlistTickers] directly, so they know to re-fetch instead of
  /// showing stale data until the next unrelated rebuild. Not bumped by
  /// [hydrateWatchlist] itself — that's the initial sync, not a "changed
  /// elsewhere" event.
  int watchlistVersion = 0;

  /// Best-effort sync of [watchlistTickers] with the investor's real saved
  /// list (GET /watchlist-items) — call once after sign-in. Fixes
  /// [isWatched] (asset_detail_screen.dart's save-toggle icon) showing the
  /// wrong state for any ticker until this ran at least once — before this
  /// existed, [_watchlist] started pre-populated with 4 hardcoded demo
  /// tickers that never matched a real account's actual saved list. Swallows
  /// failures (network hiccup, not signed in yet) since every screen that
  /// actually needs the true list already fetches it directly — this is
  /// only priming [isWatched] for a snappier first paint, not load-bearing.
  Future<void> hydrateWatchlist(WatchlistRepository repo) async {
    try {
      final items = await repo.items();
      _watchlist
        ..clear()
        ..addAll(items.map((a) => a.ticker));
      notifyListeners();
    } catch (_) {
      // best-effort — see doc comment above.
    }
  }

  /// null until the first successful [refreshMarketStatus] — [marketOpen]
  /// falls back to the local WAT-clock calc (isNgxOpenNow()) until then, or
  /// forever if the backend is unreachable.
  bool? _marketOpenFromBackend;
  Timer? _marketStatusTimer;

  /// Whether the app should show the NGX market as open right now. Backed
  /// by GET /market-status (2026-08-24) so a staff override set from the
  /// admin dashboard's Settings screen — "force open"/"force closed", for
  /// testing document/statement/receipt flows without waiting for the real
  /// 10:00-14:30 WAT window — is reflected everywhere in the app that used
  /// to call isNgxOpenNow() directly. Falls back to that same local clock
  /// calc if the backend hasn't answered yet (or is unreachable), so the
  /// app still shows a sensible open/closed state offline.
  bool get marketOpen => _marketOpenFromBackend ?? isNgxOpenNow();

  Future<void> refreshMarketStatus(MarketStatusRepository repo) async {
    try {
      final status = await repo.fetch();
      _marketOpenFromBackend = status.open;
      notifyListeners();
    } catch (_) {
      // best-effort — marketOpen falls back to the local clock calc above.
    }
  }

  /// Starts polling GET /market-status every 30s so a mid-session staff
  /// override is picked up without an app restart. Call once after sign-in
  /// (see main.dart); [dispose] cancels the timer.
  void startMarketStatusPolling(MarketStatusRepository repo) {
    _marketStatusTimer?.cancel();
    unawaited(refreshMarketStatus(repo));
    _marketStatusTimer = Timer.periodic(const Duration(seconds: 30), (_) => refreshMarketStatus(repo));
  }

  @override
  void dispose() {
    _marketStatusTimer?.cancel();
    super.dispose();
  }

  void setPasscode(bool v) {
    passcodeSet = v;
    notifyListeners();
  }

  void setBiometric(bool v) {
    biometricEnabled = v;
    notifyListeners();
  }

  void setKycSubmitted(bool v) {
    kycSubmitted = v;
    notifyListeners();
  }

  void setKycApproved(bool v) {
    kycApproved = v;
    notifyListeners();
  }

  void setSuitabilityComplete(bool v) {
    suitabilityComplete = v;
    notifyListeners();
  }

  /// Sets both together — a draft's step/total are only ever meaningful as
  /// a pair (see [kycDraftStep]'s doc comment). Pass `null` for both to
  /// clear (no known in-progress draft).
  void setKycDraftProgress(int? step, int? total) {
    kycDraftStep = step;
    kycDraftTotal = total;
    notifyListeners();
  }

  void setKycOutcomeStatus(String? v) {
    kycOutcomeStatus = v;
    notifyListeners();
  }

  void setSignedIn(bool v) {
    signedIn = v;
    notifyListeners();
  }

  void setLoginPasscodeSetup(bool v) {
    loginPasscodeSetup = v;
    notifyListeners();
  }

  /// On construction, read the secure token store to decide the initial
  /// [signedIn] value — a LOCAL presence check only (an access token was
  /// persisted from a prior session), not a server-side validation. If that
  /// token has since expired, the first real API call still 401s and
  /// ApiClient's refresh-then-force-sign-out path (see lib/data/api/api_client.dart)
  /// takes over from there.
  Future<void> _hydrateSignedIn() async {
    try {
      final token = await _tokenStore.getAccessToken();
      if (token != null && token.isNotEmpty) {
        signedIn = true;
        notifyListeners();
      }
    } catch (_) {
      // Best-effort, like hydrateWatchlist() below — a secure-storage read
      // failing (corrupted keystore, a first-run platform quirk, no
      // secure-storage plugin registered at all as in a plain widget test)
      // should fall back to the safe default (treat as signed out), not
      // leave [ready] — and therefore splash_screen.dart's unguarded
      // `await app.ready` — rejected and uncaught.
    }
  }

  /// On construction, read the secure passcode store to decide the initial
  /// [passcodeSet] value — mirrors [_hydrateSignedIn] but checks local
  /// passcode-hash presence via [PasscodeStore.hasPasscode] instead of a
  /// stored access token. Without this, [passcodeSet] stays at its `false`
  /// default for the whole process, and splash_screen.dart would route every
  /// cold launch to sign-up — even a returning investor with a valid stored
  /// session and a stored passcode.
  Future<void> _hydratePasscodeSet() async {
    try {
      final has = await _passcodeStore.hasPasscode();
      if (has) {
        passcodeSet = true;
        notifyListeners();
      }
    } catch (_) {
      // Best-effort — see _hydrateSignedIn()'s identical catch above.
    }
  }

  /// Called by ApiClient when a 401 could not be silently resolved (refresh
  /// attempt failed or no refresh token was stored) — a genuine
  /// security-relevant sign-out: the session itself is no longer valid, or
  /// (reset_passcode_screen.dart) the account password was just reset
  /// server-side. Also clears the locally stored passcode hash
  /// (PasscodeStore) — this device's passcode is only ever trustworthy as a
  /// stand-in for a real, still-valid session; once that's gone for a
  /// security reason, so should the shortcut past it.
  ///
  /// Also called by splash_screen.dart's invalid-session bounce. NOT called
  /// by a plain voluntary "Sign out" in Account — see [signOut] for that
  /// (2026-08-14, BUG-03): the two used to be the same method, which meant
  /// signing out and back in as the SAME person always forced recreating
  /// the passcode from scratch, defeating its purpose as a fast re-entry
  /// shortcut. Splits are keyed to "was this sign-out because something's
  /// actually wrong" vs "the investor just chose to sign out."
  Future<void> forceSignOut() async {
    await _passcodeStore.clearPasscode();
    await _resetSessionState();
  }

  /// Plain voluntary sign-out (Account's "Sign out" button) — ends the
  /// session same as [forceSignOut], but does NOT wipe the on-device
  /// passcode. log_in_screen.dart's post-login flow re-checks
  /// PasscodeStore.belongsTo() against whichever account signs in next: the
  /// same person gets to skip straight past passcode creation and reuse
  /// it, a different account on this device still gets a fresh
  /// create/confirm flow (same protection [forceSignOut] used to apply
  /// unconditionally, just decided at the point it's actually knowable).
  Future<void> signOut() async {
    await _resetSessionState();
  }

  /// Shared by [forceSignOut]/[signOut] — everything about ending a session
  /// EXCEPT the passcode decision, which differs between the two (see their
  /// doc comments). Resets kycSubmitted/kycApproved/suitabilityComplete/
  /// biometricEnabled/the watchlist too (2026-08-10) — these used to survive
  /// a sign-out, so signing into/creating a DIFFERENT account in the same
  /// browser tab (web has no natural process restart between accounts)
  /// inherited the previous account's eligibility state: a fresh signup
  /// could land on Home already "kycApproved", skipping the KYC gate
  /// entirely on Add money/Withdraw/Buy/Sell. hydrateGatingStateAndRoute
  /// (log_in_screen.dart) still re-syncs these from the server on the next
  /// real login, so this only removes the stale carry-over, not any real
  /// hydration path.
  Future<void> _resetSessionState() async {
    await _tokenStore.clearTokens();
    signedIn = false;
    loginPasscodeSetup = false;
    kycSubmitted = false;
    kycApproved = false;
    suitabilityComplete = false;
    kycDraftStep = null;
    kycDraftTotal = null;
    kycOutcomeStatus = null;
    biometricEnabled = false;
    _watchlist.clear();
    watchlistVersion = 0;
    notifyListeners();
  }

  void toggleWatch(String ticker) {
    if (!_watchlist.remove(ticker)) _watchlist.add(ticker);
    watchlistVersion++;
    notifyListeners();
  }

  void addWatch(String ticker) {
    if (_watchlist.add(ticker)) {
      watchlistVersion++;
      notifyListeners();
    }
  }

  void removeWatch(String ticker) {
    if (_watchlist.remove(ticker)) {
      watchlistVersion++;
      notifyListeners();
    }
  }
}

/// Where an investor should go next to become eligible to trade/fund, or
/// null if they already can ([AppState.kycApproved] &&
/// [AppState.suitabilityComplete]). Browsing itself is never gated —
/// this only matters at the specific points that need it: home_screen.dart's
/// prompt card, and the Buy/Sell/Add money/Withdraw entry points
/// (trade_flows.dart, wallet_flows.dart), which all call this so the copy
/// and routing stay consistent everywhere it's surfaced. Purely a UX
/// convenience — the real enforcement is server-side (OrdersService/
/// TransactionsService in the backend both re-check this before acting).
class TradingEligibilityGap {
  const TradingEligibilityGap({required this.title, required this.message, required this.route});
  final String title;
  final String message;
  final String route;
}

TradingEligibilityGap? tradingEligibilityGap(AppState app) {
  if (!app.kycSubmitted) {
    final step = app.kycDraftStep;
    final total = app.kycDraftTotal;
    if (step != null && total != null) {
      // ALWAYS routes to kyc-intro, never straight to the specific step
      // screen (fixed 2026-08-20 — reported: after refreshing the app
      // mid-flow, tapping this prompt jumped straight to e.g. Utility
      // Bill, which immediately failed with "something went wrong,
      // restart verification"). Every step screen after step 1 needs
      // AppState.kycForm.draftId already set — the ONLY place that gets
      // fetched and populated is kyc-intro's own "Start" handler
      // (GET /kyc-submissions/draft). A fresh page load/app relaunch
      // resets kycForm.draftId to null (it's in-memory only), so jumping
      // straight to a step screen skipped that fetch entirely and every
      // upload on that screen failed. kyc-intro's "Start" button now does
      // that fetch and resumes at the right step itself — one extra tap,
      // but the draft id is always populated correctly first.
      return TradingEligibilityGap(
        title: 'Complete your KYC — $step/$total done',
        message: 'Pick up where you left off',
        route: Routes.kycIntro,
      );
    }
    return const TradingEligibilityGap(
      title: 'Complete your KYC',
      message: 'Verify your identity to start investing',
      route: Routes.kycIntro,
    );
  }
  // Checked BEFORE the generic "still pending" fallback below — a real
  // rejected/flagged/expired outcome is a genuinely different situation
  // from "quietly awaiting a decision" and deserves accurate copy + a
  // route to kyc-outcome (which shows the real per-status message), not
  // "under review" + a route to the pending-polling screen regardless of
  // how final the actual outcome is (2026-08-20 fix — see
  // AppState.kycOutcomeStatus's doc comment).
  switch (app.kycOutcomeStatus) {
    case 'rejected':
    case 'rejected_retry': // staff reject with resubmission room left — see KycSubmissionStatus.isRejectedWithRoomToRetry
      return const TradingEligibilityGap(
        title: "Your KYC wasn't approved",
        message: 'See what to do next',
        route: Routes.kycOutcome,
      );
    case 'flagged':
      return const TradingEligibilityGap(
        title: 'Your account needs manual review',
        message: "We'll notify you once it's resolved",
        route: Routes.kycOutcome,
      );
    case 'expired':
      return const TradingEligibilityGap(
        title: 'Your KYC submission expired',
        message: 'Please verify your identity again',
        route: Routes.kycOutcome,
      );
  }
  if (!app.kycApproved) {
    return const TradingEligibilityGap(
      title: 'Your KYC is under review',
      message: "We'll notify you once it's approved",
      route: Routes.kycSubmitted,
    );
  }
  // Suitability is no longer a hard gate on trading/funding (2026-08-20
  // directive: "make the assessment optional or hide it for now — the one
  // that comes after KYC"). KYC approval alone is now enough to reach
  // Buy/Sell/Add money/Withdraw — the questionnaire itself, and
  // kyc-approved's "Start investing" entry into it, are UNCHANGED and
  // still reachable for anyone who wants to complete it voluntarily; this
  // just stops it from blocking anyone who doesn't. Not deleted, matching
  // this codebase's "supersede, don't remove" convention — restore this
  // block to re-enable the hard gate later.
  return null;
}

/// InheritedNotifier exposing the single [AppState]. Wrap the app once; read it
/// with `AppScope.of(context)` (rebuilds on change) or `AppScope.read(context)`.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  /// Listening read — rebuilds the caller when [AppState] notifies.
  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.notifier!;
  }

  /// Non-listening read — for event handlers that only mutate.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.notifier!;
  }
}
