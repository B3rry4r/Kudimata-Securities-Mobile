// Kudimata Securities — minimal app session state. Drives the gated-flow router
// (passcode → biometric → KYC → suitability → tabs) and the live watchlist set.
// SEAM: real auth/KYC/suitability outcomes flip these flags; here they are flipped
// by the demo flows.
// Persistence: `signedIn` is now backed by AuthTokenStore (flutter_secure_storage)
// — the secure store this comment used to say "plugs in later". See
// _hydrateSignedIn() and forceSignOut() below. `biometricEnabled` is backed by
// PasscodeStore the same way (2026-08-29, A-6/A-7 fix — see
// _hydrateBiometricEnabled()'s doc comment: it used to be in-memory only,
// which meant a real enrolment was forgotten on the very next cold start).
// Every other flag here is still in-memory only.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/api/api_client.dart';
import '../data/api/auth_token_store.dart';
import '../data/api/passcode_store.dart';
import '../data/realtime/realtime_client.dart';
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
    RealtimeClient? realtimeClient,
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
        _passcodeStore = passcodeStore ?? PasscodeStore(),
        // Shares the SAME (possibly caller-supplied) `tokenStore` param
        // ApiClient is built with in main.dart, not [_tokenStore] above —
        // Dart's initializer list can't reference an already-initialized
        // sibling field, so this passes the raw param straight through;
        // [RealtimeClient]'s own constructor applies the identical
        // `?? AuthTokenStore()` default when it's null. Two default
        // instances both just wrap the same underlying secure storage, so
        // this is harmless when no [tokenStore] is supplied at all (tests).
        realtimeClient = realtimeClient ?? RealtimeClient(tokenStore: tokenStore) {
    ready = _hydrate();
  }

  /// Resolves once startup hydration ([_hydrateSignedIn] +
  /// [_hydratePasscodeSet] + [_hydrateBiometricEnabled]) has completed.
  /// [signedIn], [passcodeSet] and [biometricEnabled] all start `false`
  /// synchronously (before the secure-storage reads that back them return)
  /// — callers that need a startup-correct read of any of them, rather than
  /// just reacting to a later [notifyListeners] call, must await this
  /// first. See splash_screen.dart's routing decision.
  late final Future<void> ready;

  /// True exactly when [_hydrateSignedIn] is the reason [signedIn] is
  /// `true` — a token was found in secure storage at COLD START — and
  /// nothing has confirmed since that whoever just opened the app is really
  /// that token's owner. Deliberately NOT set by [setSignedIn] (every
  /// interactive path: fresh signup, a fresh login, this exact challenge
  /// succeeding): those already involve the investor doing something —
  /// typing a passcode, completing OTP — that only its intended flag
  /// ([passcodeSet]/[loginPasscodeSetup] etc.) needs to track, and a
  /// synthetic `AppState()..signedIn = true` in tests (there are many)
  /// represents exactly that "already mid-session" case too, not a cold
  /// start — this flag correctly stays `false` for every one of them with
  /// no per-test-file change needed, because none of them go through
  /// [_hydrateSignedIn]'s actual code path.
  ///
  /// `_gateRedirect` (app_router.dart) forces a restored session with a
  /// passcode set through `Routes.login` for real while this is true (A-6
  /// follow-up, 2026-08-29: "if i close the app and reopen, passcode never
  /// comes up"). [clearColdStartLock] clears it once that challenge (or an
  /// interactive login/signup reaching Home the ordinary way) succeeds —
  /// see `hydrateGatingStateAndRoute`, log_in_screen.dart, which every one
  /// of those paths eventually calls.
  bool coldStartPendingUnlock = false;

  void clearColdStartLock() {
    coldStartPendingUnlock = false;
    notifyListeners();
  }

  /// [signedIn]/[passcodeSet]/[biometricEnabled] each hydrate from their OWN
  /// secure-storage read and, before this, called [notifyListeners]
  /// individually the instant THEIR read finished — which meant a redirect
  /// evaluated in the gap between them (`refreshListenable: state` re-runs
  /// on every notify) could see [signedIn] already `true` and [passcodeSet]
  /// still its synchronous `false` default, read that as "no passcode to
  /// challenge", and send a cold start straight to Home with no unlock at
  /// all. None of the three hydrate methods below notify on their own any
  /// more — only this wrapper does, once, after all three have actually
  /// settled together, and only if one of them actually found something
  /// (each returns whether it changed anything) — a plain fresh-install
  /// hydration that found nothing at all stays exactly as silent as it was
  /// before this existed, which matters for tests that dispose an AppState
  /// before this Future resolves: an unconditional notify here would fire
  /// on an already-disposed ChangeNotifier and throw.
  Future<void> _hydrate() async {
    final changed = await Future.wait(
      [_hydrateSignedIn(), _hydratePasscodeSet(), _hydrateBiometricEnabled()],
    );
    // Defect fix (2026-08-29, two-auditor report): [coldStartPendingUnlock]
    // exists to force a re-auth CHALLENGE against an EXISTING local
    // passcode — see its own doc comment, "prove whoever just opened the
    // app is really that token's owner". It presumes a passcode exists to
    // challenge with. A restored session with a token but NO passcode at
    // all is not a returning owner to verify — it's an interrupted signup
    // (otp_screen.dart persists the token the instant OTP verifies, before
    // passcode creation ever runs; kill the app in between and the next
    // cold start hydrates exactly this: signedIn=true, passcodeSet=false).
    // `_gateRedirect` (app_router.dart) handles that case on its own by
    // forcing a resume at the passcode step directly — this flag must not
    // survive to hijack THAT screen's own onward navigation the moment
    // passcode creation actually completes a few seconds later (it would
    // otherwise still be sitting here `true`, and `_gateRedirect` would
    // force a redundant, flow-breaking re-challenge with the code the
    // investor just typed).
    if (coldStartPendingUnlock && !passcodeSet) coldStartPendingUnlock = false;
    if (changed.any((v) => v)) notifyListeners();
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

  /// The single shared [RealtimeClient] (R-41, docs/redesign/DECISIONS.md)
  /// — unlike [apiClient]/[kycForm], built right here in the constructor
  /// (below) rather than assigned externally by main.dart: it needs no
  /// back-reference to this AppState, only the SAME [AuthTokenStore]
  /// [_tokenStore] already wraps, so there's no chicken-and-egg to solve.
  /// Connected after authentication ([setSignedIn]/main.dart's cold-start
  /// hydration), disconnected on sign-out ([_resetSessionState]) and on
  /// [dispose], reconnected on app foreground resume (main.dart's
  /// `didChangeAppLifecycleState`). Reached the same way as [apiClient]:
  ///   `AppScope.read(context).realtimeClient`
  ///   `AppScope.of(context).realtimeClient`
  final RealtimeClient realtimeClient;

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

  /// Whether this investor has accepted the Statutory Risk Disclaimer
  /// (Rule 76 compliance), added 2026-08-24 per the firm's real SEC-facing
  /// compliance intake. Set by legal_acceptance_screen.dart's own
  /// `_accept()` when its `kinds` include 'risk_disclosure' — since
  /// 2026-08-29 that's every run of the onboarding legal-documents screen
  /// (terms_and_privacy_screen.dart; risk disclosure was its own
  /// standalone screen before that, see risk_disclaimer_screen.dart's
  /// header and DECISIONS.md's R-8a superseded note). In-memory only, same
  /// as every other gate flag here — hydrated for a RETURNING investor by
  /// refreshKycGatingState (log_in_screen.dart) via GET
  /// /compliance-acknowledgements/me, same "don't re-block someone who
  /// already cleared this in a past session" reasoning kycApproved/
  /// suitabilityComplete already handle.
  bool riskDisclosureAccepted = false;

  /// Which of the 5 phased-KYC steps (2026-08-20) an in-progress draft is
  /// resuming at, and the fixed total — both null when there's no known
  /// in-progress draft (never started, or already finalized/decided).
  /// Populated by hydrateGatingStateAndRoute (log_in_screen.dart) alongside
  /// kycSubmitted/kycApproved; read by tradingEligibilityGap below to show
  /// Home's "Complete your KYC — N/5 done" prompt and resume at the right
  /// step instead of always restarting at step 1.
  int? kycDraftStep;

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

  /// 'active' | 'suspended' | 'dormant' — this investor's server-side
  /// account lifecycle state, or null before it's ever been told. Applied
  /// LIVE from the `kyc:status` socket payload's own `accountStatus` field
  /// (see [applyRealtimeKycStatus] — RealtimeKycStatus carries this
  /// already; it was decoded off the wire and then never read anywhere,
  /// which is the bug this field fixes: a staff-pushed suspension/dormancy
  /// flag was silently dropped, so a suspended account kept trading until
  /// whatever screen was open next happened to run a full REST refresh).
  /// [tradingEligibilityGap] below gates on 'dormant'; 'suspended' is
  /// handled more severely, in [applyRealtimeKycStatus] itself (see there).
  String? accountStatus;
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

  /// The email being onboarded, set by otp_screen.dart right after a
  /// successful verify. R-8a (DECISIONS.md, 2026-08-27) put suitability +
  /// its result + the risk disclosure BETWEEN OTP and the other three legal
  /// documents, so the email otp_screen.dart used to hand straight to
  /// terms_and_privacy_screen.dart via a single GoRouter `extra` now has to
  /// survive several hops it isn't otherwise involved in (questionnaire →
  /// result → risk disclaimer → terms). Threaded via AppState rather than
  /// re-plumbing `extra` through every one of those screens, same reasoning
  /// as [loginPasscodeSetup] above. terms_and_privacy_screen.dart reads it
  /// (via `AppScope.read`) when it hands off to Routes.createPasscode,
  /// which is the one screen downstream that actually needs it.
  String? pendingSignupEmail;

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
    realtimeClient.dispose();
    super.dispose();
  }

  void setPasscode(bool v) {
    passcodeSet = v;
    notifyListeners();
  }

  /// Flips [biometricEnabled] AND persists it (2026-08-29, A-6/A-7 fix —
  /// see [_hydrateBiometricEnabled]'s doc comment for what broke before
  /// this). Fire-and-forget on the write: every existing call site
  /// (biometric_screen.dart's enrolment, security_screen.dart's toggle)
  /// treats this as a synchronous setter already, and the in-memory flag —
  /// which every screen actually reads — is updated immediately either way.
  void setBiometric(bool v) {
    biometricEnabled = v;
    unawaited(_passcodeStore.setBiometricEnabled(v));
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

  void setRiskDisclosureAccepted(bool v) {
    riskDisclosureAccepted = v;
    notifyListeners();
  }

  /// Sets both together — a draft's step/total are only ever meaningful as
  /// a pair (see [kycDraftStep]'s doc comment). Pass `null` for both to
  /// clear (no known in-progress draft).
  void setKycDraftProgress(int? step) {
    kycDraftStep = step;
    notifyListeners();
  }

  void setKycOutcomeStatus(String? v) {
    kycOutcomeStatus = v;
    notifyListeners();
  }

  /// Applies a `kyc:status` socket payload (R-41) directly to the gate
  /// flags it can determine on its own — [kycApproved]/[kycSubmitted]/
  /// [kycOutcomeStatus] — with NO network call. Wired from main.dart via
  /// `realtimeClient.kycStatus.listen(applyRealtimeKycStatus)`, so it
  /// reaches every screen that reads these flags (not just whichever one
  /// happens to be open), same as any other AppState mutation.
  ///
  /// Deliberately narrower than [refreshKycGatingState]
  /// (log_in_screen.dart), the REST check this does NOT replace or
  /// trigger: the backend's `User` payload carries only the coarse
  /// `kycStatus` enum, not the KycSubmission's own `flagReason`
  /// (needed for [kycOutcomeStatus]'s "still has a retry" nuance —
  /// KycSubmissionStatus.isRejectedWithRoomToRetry, kyc_repository.dart),
  /// nor suitability/risk-disclosure completion. Those three
  /// ([suitabilityComplete], [riskDisclosureAccepted], [kycDraftStep]/
  /// [kycDraftTotal]) are left untouched here — home_screen.dart's own 8s
  /// `_kycPollTimer` used to also keep them current but was removed as
  /// redundant (this method already covers everything that poll was
  /// actually for — see home_screen.dart's doc comment on the removal);
  /// these three now stay owned by [refreshKycGatingState] itself, run
  /// once at Home's initial load and once more on each realtime
  /// reconnect (home_screen.dart's `_reconnectSub`) — the one legitimate
  /// fetch a reconnect earns, since events missed while disconnected
  /// can't be replayed.
  void applyRealtimeKycStatus(RealtimeKycStatus status) {
    kycApproved = status.kycStatus == 'approved';
    kycSubmitted = status.kycStatus != 'draft';
    kycOutcomeStatus = const {'rejected', 'flagged', 'expired'}.contains(status.kycStatus)
        ? status.kycStatus
        : null;
    // Defect fix (2026-08-29, two-auditor report): [accountStatus] used to
    // be decoded off this exact payload (RealtimeKycStatus.accountStatus)
    // and never applied here at all — see that field's own doc comment.
    // Applied directly, same as every flag above: no network call.
    accountStatus = status.accountStatus;
    if (accountStatus == 'suspended') {
      // The backend already treats 'suspended' as a hard block on using the
      // app at all — login itself refuses a suspended account outright
      // (hydrateGatingStateAndRoute's dormancy-gate doc comment,
      // log_in_screen.dart: "only 'suspended' is blocked server-side"). A
      // suspension pushed mid-session must end that session with the same
      // finality — not leave it running, silently flagged, still able to
      // place trades until the next unrelated refresh happens to notice.
      // forceSignOut() itself makes no network call (only local
      // storage/state teardown + disconnecting this very socket) — this
      // stays a direct application of the pushed payload, per this file's
      // "no refetch" rule, not a trigger to go ask the server anything.
      unawaited(forceSignOut());
    }
    notifyListeners();
  }

  void setSignedIn(bool v) {
    signedIn = v;
    // R-41: connect the realtime socket the moment a session becomes
    // valid — covers the interactive sign-in path (hydrateGatingStateAndRoute,
    // log_in_screen.dart); the cold-start "already signed in" path is
    // covered separately by main.dart's `ready.then` block, since this
    // setter isn't the one that flips [signedIn] there (see
    // [_hydrateSignedIn]). Fire-and-forget: [RealtimeClient.connect] is
    // safe to call repeatedly and no-ops with nothing stored to auth with.
    if (v) unawaited(realtimeClient.connect());
    notifyListeners();
  }

  void setLoginPasscodeSetup(bool v) {
    loginPasscodeSetup = v;
    notifyListeners();
  }

  void setPendingSignupEmail(String? v) {
    pendingSignupEmail = v;
    notifyListeners();
  }

  /// On construction, read the secure token store to decide the initial
  /// [signedIn] value — a LOCAL presence check only (an access token was
  /// persisted from a prior session), not a server-side validation. If that
  /// token has since expired, the first real API call still 401s and
  /// ApiClient's refresh-then-force-sign-out path (see lib/data/api/api_client.dart)
  /// takes over from there.
  Future<bool> _hydrateSignedIn() async {
    try {
      final token = await _tokenStore.getAccessToken();
      if (token != null && token.isNotEmpty) {
        signedIn = true;
        // See [coldStartPendingUnlock]'s doc comment — this is the one
        // real code path that means it.
        coldStartPendingUnlock = true;
        return true;
      }
    } catch (_) {
      // Best-effort, like hydrateWatchlist() below — a secure-storage read
      // failing (corrupted keystore, a first-run platform quirk, no
      // secure-storage plugin registered at all as in a plain widget test)
      // should fall back to the safe default (treat as signed out), not
      // leave [ready] — and therefore splash_screen.dart's unguarded
      // `await app.ready` — rejected and uncaught.
    }
    return false;
  }

  /// On construction, read the secure passcode store to decide the initial
  /// [passcodeSet] value — mirrors [_hydrateSignedIn] but checks local
  /// passcode-hash presence via [PasscodeStore.hasPasscode] instead of a
  /// stored access token. Without this, [passcodeSet] stays at its `false`
  /// default for the whole process, and splash_screen.dart would route every
  /// cold launch to sign-up — even a returning investor with a valid stored
  /// session and a stored passcode.
  Future<bool> _hydratePasscodeSet() async {
    try {
      final has = await _passcodeStore.hasPasscode();
      if (has) {
        passcodeSet = true;
        return true;
      }
    } catch (_) {
      // Best-effort — see _hydrateSignedIn()'s identical catch above.
    }
    return false;
  }

  /// On construction, read the secure store to decide the initial
  /// [biometricEnabled] value — mirrors [_hydratePasscodeSet] exactly, just
  /// reading [PasscodeStore.getBiometricEnabled] instead. Added 2026-08-29
  /// (product-owner audit A-6/A-7). Before this fix, [biometricEnabled] was
  /// flipped true by biometric_screen.dart's enrolment but never persisted
  /// anywhere — every cold start silently reset it to `false`, so:
  ///   - log_in_screen.dart's unlock keypad (`app.biometricEnabled &&
  ///     _biometricAvailable`) never showed the Face ID key again after the
  ///     very first app launch, even for an investor who genuinely turned it
  ///     on — i.e. biometrics were "collected" once and then forgotten (A-7).
  ///   - a resume-lock built on this flag (main.dart's
  ///     `didChangeAppLifecycleState`, A-6) would have had nothing reliable
  ///     to offer biometric-first either.
  /// Without this hydration, [biometricEnabled] stays at its `false` default
  /// until the investor happens to notice and re-enrol from Security.
  Future<bool> _hydrateBiometricEnabled() async {
    try {
      final enabled = await _passcodeStore.getBiometricEnabled();
      if (enabled) {
        biometricEnabled = true;
        return true;
      }
    } catch (_) {
      // Best-effort — see _hydrateSignedIn()'s identical catch above.
    }
    return false;
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
    // R-41: tear down the socket on every sign-out path (voluntary or
    // forced) — a socket authenticated as this investor must not survive
    // into a different investor's session on the same device.
    realtimeClient.disconnect();
    signedIn = false;
    coldStartPendingUnlock = false;
    loginPasscodeSetup = false;
    pendingSignupEmail = null;
    kycSubmitted = false;
    kycApproved = false;
    suitabilityComplete = false;
    kycDraftStep = null;
    kycOutcomeStatus = null;
    accountStatus = null;
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
  // Checked BEFORE every KYC/suitability check below — account-lifecycle
  // state is orthogonal to KYC outcome (an already-approved, fully
  // onboarded investor can still go dormant), so it must not be masked by
  // whichever KYC-shaped gap would otherwise be returned first. dormant_
  // account_screen.dart is the same screen hydrateGatingStateAndRoute
  // (log_in_screen.dart) already routes a returning dormant investor to
  // after a REST check; this is the live-push route to the identical
  // screen for a dormancy flag that arrives mid-session (AppState.
  // accountStatus's own doc comment). 'suspended' isn't handled here at
  // all — applyRealtimeKycStatus ends that session outright the instant
  // the flag arrives, so a suspended investor never reaches this check
  // still signed in.
  if (app.accountStatus == 'dormant') {
    return const TradingEligibilityGap(
      title: 'Your account is dormant',
      message: 'Reactivate your account to keep investing',
      route: Routes.acctDormant,
    );
  }
  if (!app.kycSubmitted) {
    // Only "is there a draft in progress", never "how far along" -- see the
    // title below for why no total is kept.
    if (app.kycDraftStep != null) {
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
      // NO step count in this title. It used to read
      // 'Complete your KYC — $step/$total done' off the backend's
      // KYC_TOTAL_STEPS = 5, which has never matched the real 7-step flow
      // since the 2026-08-24 re-sequencing added CHN, Bank & DCS and
      // Declarations. It was reported wrong three times, and each earlier
      // fix corrected a DIFFERENT renderer of the same fact -- the step
      // screens, then the checklist, then Home's progress bar -- while this
      // title kept saying "4/5" above a correct 7-step bar.
      //
      // The count now has exactly one writer: kycProgressSummary(), derived
      // per-item from the real checklist, rendered by _VerifyBanner's own
      // FutureBuilder directly under this title. A second copy of a number
      // is a second truth, and this one drifted for three passes.
      return const TradingEligibilityGap(
        title: 'Complete your KYC',
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
        // No in-app notification mechanism backs a "we'll tell you" promise
        // here (unbacked_promises gate) — states what's actually happening
        // instead, same shape as the 'expired' case below.
        message: 'Manual review is under way',
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
      // No in-app notification mechanism backs a "we'll tell you" promise
      // (unbacked_promises gate) — states what's actually happening
      // instead, same shape as the 'expired' case below.
      message: 'Review is under way',
      route: Routes.kycSubmitted,
    );
  }
  // RESTORED 2026-08-24 (direct product instruction, after the firm's real
  // SEC-facing compliance intake made it mandatory: "please make the
  // suitability mandatory"). This block had been off since 2026-08-20
  // ("make the assessment optional or hide it for now") — that directive
  // is superseded, not this one silently reversing it. A returning
  // investor who was already fully onboarded under the old optional regime
  // (kycApproved=true, but never took the questionnaire) is exactly who
  // this now correctly re-gates.
  if (!app.suitabilityComplete) {
    return const TradingEligibilityGap(
      title: 'Complete your suitability assessment',
      message: 'A quick suitability assessment is required before you can invest',
      route: Routes.questionnaire,
    );
  }
  if (!app.riskDisclosureAccepted) {
    // Routes to the legal-documents screen, not a standalone risk-
    // disclosure screen — 2026-08-29, DECISIONS.md's R-8a superseded note:
    // risk disclosure is one of the documents in terms_and_privacy_screen
    // .dart's list now, not its own step ahead of it.
    return const TradingEligibilityGap(
      title: 'Accept the risk disclosure',
      message: 'Please review and accept the statutory risk notice',
      route: Routes.termsOfService,
    );
  }
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
