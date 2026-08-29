// s08 (trusted device) / s08p (untrusted device) — the returning-user unlock,
// per the reverse-sweep's "device-trust login fork" (reverse-sweep.json):
// s08 is a centered avatar + personalized greeting, 6-digit passcode dots,
// a "Forgot password?" link, then the keypad (biometric shortcut
// bottom-left); s08p is the email+password fallback for a device with no
// local passcode, its own "Forgot password?" link under the fields, and a
// helper line ("We text a code after this, then you set a passcode for
// this phone.") above its Sign in button. "Forgot password?" leads to a
// real account password reset, not a local-passcode reset — see
// reset_passcode_screen.dart's header comment.
// On a full passcode we sign in and go home. R-11: 6 digits with a
// create+confirm pair everywhere including login — the canvas's 4-digit
// single-entry look is what's adopted, not its length; the 6-dot count
// here is unchanged, already correct.
// Root gated screen: own Scaffold, no tab bar.
//
// WIRING NOTE (real-login pass): the original version of this screen was
// LOCAL-PASSCODE-ONLY — whenever `!AppState.signedIn` (no valid local
// session: explicit sign-out, forced sign-out on a stale token, or a fresh
// device that has never signed in here) it unconditionally called
// `forceSignOut()` and bounced to Sign Up. That's a dead end for a
// signed-out investor with an existing, already-approved account: Sign Up
// fails immediately with EMAIL_ALREADY_REGISTERED, and there was no email
// +password form anywhere in the app to get back in. Even the "Forgot
// passcode" flow (reset_passcode_screen.dart), which genuinely resets the
// account's PASSWORD server-side via POST /auth/reset-password, looped back
// to this exact same dead end afterward.
//
// This screen now has two real, chosen-at-runtime modes:
//   1. LOCAL UNLOCK — unchanged from before. Shown when `AppState.signedIn`
//      (a valid local session exists) AND `PasscodeStore.hasPasscode()` (a
//      local passcode was created on this device). See [_unlock] below.
//   2. EMAIL LOGIN — new. Shown whenever either of those is false: a real
//      email+password form, wired to `AuthRepository.login()` ->
//      POST /auth/login. Handles both real backend responses: a normal
//      session (tokens) immediately, or — when the account's step-up-auth
//      preference is on — an EmailOtp step-up challenge first (reusing
//      KOtpCells, the same digit-cell widget otp_screen.dart's sign-up
//      verification uses, and redeemed via the SAME
//      `AuthRepository.verifyEmailOtp` that screen already calls — see
//      AuthRepository.login's doc comment for why no separate "verify
//      step-up" method is needed). Once a session exists, tokens are saved
//      and the investor is routed into LOCAL passcode creation
//      (Routes.createPasscode) since this device has none yet.
//
// Real gating-state hydration (kycSubmitted/kycApproved/suitabilityComplete
// — all in-memory-only AppState flags that default false and would
// otherwise wrongly re-run KYC/suitability for an already-approved
// investor on a fresh device) happens right after that new local passcode
// is confirmed — see [hydrateGatingStateAndRoute] below, called from
// confirm_passcode_screen.dart once AppState.loginPasscodeSetup (set by
// [_completeLogin]) tells it this was a fresh login rather than first-time
// signup onboarding or Security's change-passcode reentry.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/api/auth_token_store.dart';
import 'package:kudimata_invest/data/api/passcode_store.dart';
import 'package:kudimata_invest/data/biometric_auth.dart';
import 'package:kudimata_invest/data/repositories/auth_repository.dart';
import 'package:kudimata_invest/data/repositories/compliance_repository.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/data/repositories/suitability_repository.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'onboarding_scaffold.dart';

class LogInScreen extends StatefulWidget {
  const LogInScreen({super.key, this.resumeLock = false});

  /// True when main.dart's `didChangeAppLifecycleState` PUSHED this screen
  /// as a foreground-resume re-auth challenge over an already-signed-in
  /// session (A-6, 2026-08-29 audit), rather than reaching it the ordinary
  /// way (splash_screen.dart's ROUTING to it — a `go()` that owns the
  /// screen's exit itself). Reuses this same unlock UI/logic rather than a
  /// second lock screen, per the audit's own instruction, with two
  /// deliberate differences from the default behaviour:
  ///   - a successful unlock pops back to whatever was underneath instead
  ///     of re-hydrating gating state and routing to Home — the investor's
  ///     place in the app must survive a resume challenge, not be lost to
  ///     it.
  ///   - biometric unlock is offered proactively (attempted once, on
  ///     entry, when available/enabled) rather than waiting for a tap on
  ///     the keypad's Face ID key — a resume challenge is a security
  ///     re-check the app is imposing, not a fresh sign-in the investor is
  ///     initiating, so it should cost as little friction as the passcode
  ///     alternative it's standing in for. A failed/cancelled/unavailable
  ///     attempt falls straight through to the ordinary passcode keypad
  ///     (already-built fallback — see [_unlock]'s `viaBiometric` branch).
  /// Also wrapped in a [PopScope] that refuses to be dismissed by a back
  /// gesture/button without authenticating — the whole point is that it
  /// cannot be swiped away.
  final bool resumeLock;

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  // ── Mode decision ─────────────────────────────────────────────────────
  // null while deciding; true = email+password form; false = local unlock.
  bool? _showEmailLogin;
  final _passcodeStore = PasscodeStore();
  bool _prefilledEmail = false;
  bool _autoBiometricAttempted = false;

  // Canvas #s08 personalizes the unlock greeting ("Welcome back, Adebayo")
  // and shows the investor's own chosen avatar — see [_loadProfileForGreeting].
  String? _firstName;
  String? _avatarKey;

  // ── Local unlock (existing passcode-dots flow — unchanged) ────────────
  String _code = '';
  bool _verifying = false;
  bool _error = false;

  // ── Email+password login (new) ─────────────────────────────────────────
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showErrors = false;
  bool _busy = false;
  String? _serverError;
  final _tokenStore = AuthTokenStore();

  // DECISIONS.md B-5 (2026-08-27 ruling): canvas #s08p draws no "Create an
  // account" link, and this screen previously dropped it entirely to match.
  // But `_showEmailLogin` covers TWO real paths, and the artboard only
  // depicts one of them:
  //   - the device-trust login fork (splash_screen.dart routes here
  //     directly whenever `AppState.passcodeSet` is true — this device
  //     recognizes an account was set up on it before, it's just
  //     signed-out/session-expired now). THIS is what #s08p depicts, and it
  //     correctly has no signup affordance — the investor already has an
  //     account.
  //   - a genuinely account-less fresh install: splash_screen.dart only
  //     sends an unrecognized device to Welcome, whose "Sign in" CTA
  //     (welcome_slider_screen.dart) is the other way to land here, with no
  //     passcode ever set on this device. That user may have no account at
  //     all and, without this link, had no way off this screen.
  // `AppState.passcodeSet` is exactly the signal that tells the two apart,
  // so the link is gated on it below rather than always shown.
  final _createAccountTap = TapGestureRecognizer();

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  bool get _emailValid => _emailPattern.hasMatch(_email.text.trim());

  // ── Step-up OTP challenge (new — shown mid email-login when the account
  // has two-factor/step-up auth enabled) ──────────────────────────────────
  String? _stepUpEmail; // non-null while this challenge is showing.
  final List<String> _stepUpDigits = List.filled(6, '');
  final _stepUpController = TextEditingController();
  final _stepUpFocus = FocusNode();
  bool _stepUpVerifying = false;
  String? _stepUpError;

  @override
  void initState() {
    super.initState();
    _decideMode();
    _checkBiometricAvailability();
    _createAccountTap.onTap = () => context.go(Routes.signup);
  }

  /// Whether this device can actually run a biometric check. The keypad's
  /// fingerprint key is gated on this AS WELL AS AppState.biometricEnabled
  /// (2026-08-24): the stored flag only records that the investor once
  /// chose biometrics, and it survives wiping every fingerprint from the
  /// phone, reinstalling on a device without a sensor, or running as the
  /// web build. Showing a key that cannot possibly succeed is how the
  /// original hole hid in plain sight — it looked like it worked.
  bool _biometricAvailable = false;

  Future<void> _checkBiometricAvailability() async {
    final available = await BiometricAuth.isAvailable();
    if (!mounted) return;
    setState(() => _biometricAvailable = available);
    // See [LogInScreen.resumeLock]'s doc comment — offer biometric
    // proactively for a resume challenge instead of waiting for a keypad
    // tap. Guarded so this only ever fires once per screen instance.
    if (widget.resumeLock &&
        !_autoBiometricAttempted &&
        available &&
        AppScope.read(context).biometricEnabled) {
      _autoBiometricAttempted = true;
      _unlock(viaBiometric: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // One-time prefill from reset_passcode_screen.dart's post-reset handoff
    // (`context.go(Routes.login, extra: email)`) — read via GoRouterState.of
    // rather than a constructor param since app_router.dart's Routes.login
    // GoRoute discards its builder's `state` arg (`builder: (_, _) => ...`),
    // same as otp_screen.dart's `_email` getter already does for its own
    // extra. Guarded by [_prefilledEmail] so a later rebuild (e.g. the
    // system theme changing) doesn't stomp on whatever the investor has
    // since typed.
    if (!_prefilledEmail) {
      _prefilledEmail = true;
      final extra = GoRouterState.of(context).extra;
      if (extra is String && extra.isNotEmpty) _email.text = extra;
    }
  }

  Future<void> _decideMode() async {
    final app = AppScope.read(context);
    final hasPasscode = await _passcodeStore.hasPasscode();
    if (!mounted) return;
    final showEmailLogin = !app.signedIn || !hasPasscode;
    setState(() {
      _showEmailLogin = showEmailLogin;
    });
    if (!showEmailLogin) _loadProfileForGreeting();
  }

  /// GET /users/me for the local-unlock greeting's first name + avatar.
  /// Neither is cached on-device — PasscodeStore only ever knows the
  /// owner's EMAIL (see its `owner` getter) — so this is a real fetch, same
  /// call [_unlock] already makes for session validity, just run once up
  /// front instead of only at unlock time. Best-effort: on failure both
  /// stay null and the screen falls back to the generic "Welcome back" +
  /// initial-letter avatar (same fallback convention home_screen.dart /
  /// account_screen.dart use for a null avatarKey) rather than blocking
  /// passcode entry on a network call.
  Future<void> _loadProfileForGreeting() async {
    final app = AppScope.read(context);
    try {
      final profile = await UserRepository(app.apiClient).me();
      if (!mounted) return;
      setState(() {
        _firstName = profile.firstName;
        _avatarKey = profile.avatarKey;
      });
    } on ApiException {
      // Fall through to the generic greeting — see doc comment above.
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _stepUpController.dispose();
    _stepUpFocus.dispose();
    _createAccountTap.dispose();
    super.dispose();
  }

  void _onKey(String k) {
    if (_verifying) return;
    setState(() {
      if (k == 'del') {
        if (_code.isNotEmpty) _code = _code.substring(0, _code.length - 1);
        _error = false;
      } else if (_code.length < 6) {
        _code += k;
        _error = false;
      }
    });
    if (_code.length == 6) _unlock();
  }

  // Two layers, in order:
  //  1. LOCAL passcode verification (PasscodeStore, salted-hash comparison —
  //     see lib/data/api/passcode_store.dart) against the value
  //     confirm_passcode_screen.dart persisted on passcode creation. This is
  //     the real "does the re-entered code match what this device's owner
  //     chose" check, and it's the primary gate now.
  //  2. Session validity: AppState.signedIn is hydrated from AuthTokenStore
  //     at launch (app_state.dart's _hydrateSignedIn — a token was found in
  //     secure storage), then confirmed still valid server-side with one GET
  //     /users/me call (the same already-adopted check splash_screen.dart
  //     makes on launch) before letting the user through. A
  //     stale/expired/revoked session forces a real sign-out instead of a
  //     false unlock.
  //
  // This method is only reachable once [_decideMode] has already confirmed
  // `app.signedIn && hasPasscode` (see build() below) — the `!app.signedIn`
  // branch is kept as a defensive fallback (e.g. a session expiring in the
  // brief window between that check and a keypad tap), not the primary path
  // anymore. On that fallback we go to the real email login form now,
  // instead of the old dead-end Sign Up bounce.
  // [viaBiometric]: the keypad's biometric shortcut bypasses typed-passcode
  // entry entirely, so it also bypasses the LOCAL passcode check below (there
  // is no typed code to check) — biometric unlock still passes through the
  // session-validity check same as always.
  Future<void> _unlock({bool viaBiometric = false}) async {
    if (_verifying) return;
    final app = AppScope.read(context);

    if (!app.signedIn) {
      // No stored session at all — nothing to unlock into. Clear any stray
      // state and fall back to the real email login form (this screen's
      // own [_showEmailLogin] mode), not the old Sign Up dead end.
      await app.forceSignOut();
      if (!mounted) return;
      setState(() {
        _showEmailLogin = true;
        _code = '';
      });
      return;
    }

    setState(() => _verifying = true);

    if (viaBiometric) {
      // CRITICAL FIX (2026-08-24). This branch used to be the `if
      // (!viaBiometric)` guard around the passcode check below — meaning
      // the biometric path verified NOTHING and unlocked the account
      // outright, with local_auth not even installed. Anyone holding an
      // unlocked-to-home-screen phone could tap the fingerprint key and be
      // inside a funded brokerage account. See lib/data/biometric_auth.dart
      // for the full write-up.
      //
      // Now a real system biometric prompt, and a failed/cancelled/
      // unavailable check falls back to the passcode keypad rather than
      // unlocking. BiometricAuth.authenticate() returns false on every
      // error path, so there is no way for a fault to read as success.
      final ok = await BiometricAuth.authenticate();
      if (!ok) {
        if (!mounted) return;
        setState(() {
          _verifying = false;
          _code = '';
        });
        return;
      }
    } else {
      final hasPasscode = await _passcodeStore.hasPasscode();
      if (hasPasscode) {
        final localMatch = await _passcodeStore.verifyPasscode(_code);
        if (!localMatch) {
          if (!mounted) return;
          setState(() {
            _verifying = false;
            _error = true;
            _code = '';
          });
          return;
        }
      }
    }

    try {
      final repo = UserRepository(app.apiClient);
      await repo.me();
    } on ApiException catch (e) {
      if (e.isSessionExpired || e.statusCode == 401) {
        await app.forceSignOut();
        if (!mounted) return;
        setState(() {
          _showEmailLogin = true;
          _code = '';
        });
        return;
      }
      // Any other failure (network/timeout/5xx) isn't a session-invalid
      // signal — don't lock a returning user out over a transient error;
      // fall through to the same unlock a healthy call would have produced.
    } finally {
      if (mounted) setState(() => _verifying = false);
    }

    if (!mounted) return;
    if (widget.resumeLock) {
      // A-6: a resume challenge unlocks back into wherever the investor
      // already was — no gating re-hydration, no route to Home. That state
      // was never lost (the app process stayed alive in the background);
      // re-fetching it here would only cost time and risk visibly resetting
      // a screen the investor is about to land back on unchanged.
      context.pop();
      return;
    }
    // Re-hydrate kyc/suitability from the server before landing on Home —
    // those AppState flags are in-memory only (not persisted), so on a cold
    // start they've reset to their `false` defaults even for an
    // already-fully-onboarded returning investor. Without this, Home's
    // "Complete your KYC" prompt would wrongly show every relaunch.
    // hydrateGatingStateAndRoute already does exactly this and lands on
    // Home unconditionally; app.signedIn is already true here (required to
    // even reach this unlock screen), so its setSignedIn(true) is a no-op.
    await hydrateGatingStateAndRoute(context);
  }

  // ── Email+password login ────────────────────────────────────────────────

  Future<void> _login() async {
    if (!_emailValid || _password.text.isEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _busy = true;
      _serverError = null;
    });
    final repo = AuthRepository(AppScope.read(context).apiClient);
    try {
      final result = await repo.login(email: _email.text.trim(), password: _password.text);
      if (!mounted) return;
      if (result.stepUpRequired) {
        setState(() {
          _busy = false;
          _stepUpEmail = _email.text.trim();
        });
        return;
      }
      await _completeLogin(result.tokens!, _email.text.trim());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _serverError = e.message;
      });
    }
  }

  void _onStepUpCodeChanged(String value) {
    setState(() {
      for (var i = 0; i < 6; i++) {
        _stepUpDigits[i] = i < value.length ? value[i] : '';
      }
      _stepUpError = null;
    });
    if (value.length == 6) _verifyStepUp();
  }

  Future<void> _verifyStepUp() async {
    final email = _stepUpEmail;
    if (email == null || _stepUpVerifying) return;
    setState(() {
      _stepUpVerifying = true;
      _stepUpError = null;
    });
    final repo = AuthRepository(AppScope.read(context).apiClient);
    try {
      final tokens = await repo.verifyEmailOtp(email: email, code: _stepUpDigits.join());
      if (!mounted) return;
      await _completeLogin(tokens, email);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _stepUpVerifying = false;
        _stepUpError = e.message;
        for (var i = 0; i < 6; i++) {
          _stepUpDigits[i] = '';
        }
      });
      _stepUpController.clear();
    }
  }

  /// Shared by both the direct-session and step-up-then-session paths.
  /// Persists the fresh tokens, then either routes into LOCAL passcode
  /// creation (this device has none yet, or its existing one belongs to a
  /// different account — reaching the email-login form at all required
  /// either `!signedIn` or `!hasPasscode`) or — BUG-03 fix, 2026-08-14 —
  /// skips straight past passcode creation when this device already has a
  /// passcode set by THIS SAME [email] (PasscodeStore.belongsTo): a plain
  /// sign-out-then-sign-back-in as the same person should re-use the
  /// existing passcode, not force recreating it every time. AppState.signedIn
  /// is deliberately NOT set true in the create-passcode branch: this app's
  /// existing convention (see otp_screen.dart's post-verify handoff, and
  /// suitability_result_screen.dart setting it only once suitability is
  /// genuinely complete) only flips it once the investor is fully through
  /// every gate, so `_gateRedirect` (app_router.dart) never free-roams
  /// someone whose real KYC/suitability state hasn't been hydrated and
  /// checked yet — see [hydrateGatingStateAndRoute], which does set it once
  /// that's confirmed complete (both branches below eventually reach it).
  Future<void> _completeLogin(AuthTokens tokens, String email) async {
    await _tokenStore.saveTokens(tokens.accessToken, tokens.refreshToken ?? '');
    if (!mounted) return;
    final app = AppScope.read(context);

    final reuseExisting = await _passcodeStore.belongsTo(email);
    if (!mounted) return;

    if (reuseExisting) {
      await hydrateGatingStateAndRoute(context);
      return;
    }

    app.setLoginPasscodeSetup(true);
    context.go(Routes.createPasscode, extra: email);
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (_showEmailLogin == null) {
      // Brief beat while [_decideMode] reads PasscodeStore.
      content = Scaffold(
        backgroundColor: KColor.bg,
        body: Center(child: KSpinner(size: 22, color: KColor.ink3)),
      );
    } else if (_showEmailLogin == true) {
      content = _stepUpEmail != null ? _buildStepUp() : _buildLoginForm();
    } else {
      content = _buildUnlock(context);
    }
    if (!widget.resumeLock) return content;
    // A-6: cannot be swiped/backed away from without authenticating — see
    // [LogInScreen.resumeLock]'s doc comment.
    return PopScope(canPop: false, child: content);
  }

  // ── Local unlock UI (unchanged) ─────────────────────────────────────────
  Widget _buildUnlock(BuildContext context) {
    final app = AppScope.of(context);
    // A returning-user lock screen: the whole block — brand, prompt, dots, keypad,
    // forgot link — is vertically centred as one cohesive unit (scrolls if it ever
    // exceeds the viewport). No spacer pushing the keypad to an extreme.
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Canvas #s08 draws no wordmark on this screen — straight
                // from the top of the frame into the avatar.
                _avatarKey != null
                    ? KAvatar(avatarKey: _avatarKey!, size: 64)
                    : _LoginAvatar(
                        initial: (_firstName?.isNotEmpty ?? false) ? _firstName![0] : 'K',
                        size: 64,
                      ),
                const SizedBox(height: 14),
                // Artboard copy: "Welcome back, Adebayo" — personalized with
                // the account's real first name (see [_loadProfileForGreeting]).
                // Falls back to the generic greeting while that fetch is in
                // flight or if it fails.
                Text(
                  (_firstName?.isNotEmpty ?? false) ? 'Welcome back, $_firstName' : 'Welcome back',
                  style: KType.title(),
                ),
                const SizedBox(height: 4),
                Text('Enter your passcode', style: KType.body(color: KColor.ink2)),
                const SizedBox(height: 24),
                KPasscodeDots(filled: _code.length, error: _error),
                const SizedBox(height: 18),
                if (_error)
                  Text(
                    'Incorrect passcode',
                    style: KType.body(color: KColor.loss, w: KWeight.medium),
                  ),
                const SizedBox(height: 12),
                // Canvas #s08: "Forgot password?" sits directly under the
                // dots, above the keypad — not below it. Plain text link
                // (var(--indicator)), not a bordered ghost button.
                GestureDetector(
                  onTap: () async {
                    final email = await _passcodeStore.owner;
                    if (!context.mounted) return;
                    // Thread the known device owner (PasscodeStore.owner) so
                    // reset_passcode_screen.dart can skip straight to "step 2
                    // of 2", matching canvas #s12 — see that getter's doc
                    // comment.
                    context.go(Routes.reset, extra: email);
                  },
                  child: Text(
                    'Forgot password?',
                    style: KType.body(color: KColor.indicator, w: KWeight.semibold),
                  ),
                ),
                const SizedBox(height: 26),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: KKeypad(
                    onKey: _onKey,
                    leftAction: app.biometricEnabled && _biometricAvailable
                        ? KFingerprint(size: 26, stroke: 1.6, color: KColor.ink)
                        : null,
                    onLeftAction: app.biometricEnabled && _biometricAvailable
                        ? () => _unlock(viaBiometric: true)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Email+password login UI (new) ───────────────────────────────────────
  // Canvas #s08p — the device-trust login fork's untrusted-device branch
  // (reverse-sweep.json: "Login branch for a NEW/untrusted device — email +
  // password entry (vs s08's passcode entry for a trusted device)").
  Widget _buildLoginForm() {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Canvas #s08p: a bare back chip, no step label, back to Welcome
            // (nav.s02) — this screen previously had no back navigation at
            // all.
            KOnboardTopBar(onBack: () => context.go(Routes.welcome)),
            Expanded(
              child: KOnboardBody(
                paddingTop: 8,
                children: [
                  // Canvas #s08p draws no wordmark — straight into the title.
                  const KScreenHead(
                    title: 'Sign in',
                    body: 'New phone, so we need your email and password.',
                  ),
                  const SizedBox(height: 28),
                  KInput(
                    label: 'Email',
                    icon: 'mail',
                    placeholder: 'you@email.com',
                    keyboardType: TextInputType.emailAddress,
                    controller: _email,
                    onChanged: _showErrors ? (_) => setState(() {}) : null,
                    error: _showErrors && !_emailValid ? 'Enter a valid email address' : null,
                  ),
                  const SizedBox(height: 16),
                  KInput(
                    label: 'Password',
                    icon: 'lock',
                    placeholder: 'Your password',
                    obscure: true,
                    controller: _password,
                    onChanged: _showErrors ? (_) => setState(() {}) : null,
                    error: _showErrors && _password.text.isEmpty ? 'Enter your password' : null,
                  ),
                  const SizedBox(height: 14),
                  // Canvas #s08p: "Forgot password?" sits directly under the
                  // fields, not near the bottom action. Plain text link
                  // (var(--indicator)), not a bordered ghost button.
                  GestureDetector(
                    onTap: _busy
                        ? null
                        : () => context.go(
                              Routes.reset,
                              // Whatever's typed here is the known email —
                              // thread it through so reset_passcode_screen.dart
                              // can skip straight to "step 2 of 2" (canvas
                              // #s12; see PasscodeStore.owner's doc comment
                              // for the local-unlock equivalent).
                              extra: _email.text.trim().isEmpty ? null : _email.text.trim(),
                            ),
                    child: Text(
                      'Forgot password?',
                      style: KType.data(color: KColor.indicator, w: KWeight.semibold),
                    ),
                  ),
                  if (_serverError != null) ...[
                    const SizedBox(height: 16),
                    Text(_serverError!, style: KType.body(color: KColor.loss, w: KWeight.medium)),
                  ],
                  const Spacer(),
                  // Canvas #s08p: a small centered helper line above the
                  // button, describing what happens next — step-up code,
                  // then set a passcode for this phone (exactly what
                  // [_login]/[_verifyStepUp]/[_completeLogin] below do).
                  Text(
                    'We text a code after this, then you set a passcode for this phone.',
                    textAlign: TextAlign.center,
                    style: KType.data(color: KColor.ink3),
                  ),
                  const SizedBox(height: 14),
                  KButton(
                    label: 'Sign in',
                    loading: _busy,
                    onPressed: _busy ? null : _login,
                  ),
                  // DECISIONS.md B-5 — only on the account-less path (see the
                  // doc comment on `_createAccountTap` above); the
                  // device-trust fork #s08p depicts leaves this hidden.
                  if (!AppScope.of(context).passcodeSet) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: KType.data(color: KColor.ink3),
                          children: [
                            const TextSpan(text: 'New here? '),
                            TextSpan(
                              text: 'Create an account',
                              style: KType.data(color: KColor.indicator, w: KWeight.semibold),
                              recognizer: _createAccountTap,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step-up OTP challenge UI (new) — mirrors otp_screen.dart's cell
  // pattern (KOtpCells fed by an invisible numeric TextField) without
  // depending on that screen's file, since it's a sign-up-specific route
  // this login flow doesn't otherwise touch. ───────────────────────────────
  Widget _buildStepUp() {
    final focusIndex = _stepUpDigits.indexWhere((d) => d.isEmpty);
    final complete = focusIndex == -1;
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KOnboardTopBar(
              onBack: () => setState(() {
                _stepUpEmail = null;
                _stepUpError = null;
                for (var i = 0; i < 6; i++) {
                  _stepUpDigits[i] = '';
                }
                _stepUpController.clear();
              }),
            ),
            Expanded(
              child: KOnboardBody(
                paddingTop: 8,
                children: [
                  KScreenHead(
                    title: "Verify it's you",
                    body: 'Enter the 6-digit code we sent to $_stepUpEmail',
                  ),
                  const SizedBox(height: 36),
                  Stack(
                    children: [
                      KOtpCells(digits: _stepUpDigits, focusIndex: focusIndex),
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0,
                          child: TextField(
                            controller: _stepUpController,
                            focusNode: _stepUpFocus,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onChanged: _onStepUpCodeChanged,
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_stepUpError != null) ...[
                    const SizedBox(height: 16),
                    Text(_stepUpError!, style: KType.body(color: KColor.loss, w: KWeight.medium)),
                  ],
                  const Spacer(),
                  KButton(
                    label: 'Verify',
                    loading: _stepUpVerifying,
                    onPressed: complete && !_stepUpVerifying ? _verifyStepUp : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fetches real KYC/suitability state from the server (purely informational
/// now — see below), signs the investor in, and always lands on Home. Called
/// once by confirm_passcode_screen.dart right after it persists a brand-new
/// LOCAL passcode for a fresh email+password login (gated on
/// AppState.loginPasscodeSetup, which [_LogInScreenState._completeLogin]
/// sets and this consumes indirectly by being invoked at all — the caller
/// resets the flag itself before calling this).
///
/// Browsing the app shell no longer requires KYC/suitability to be complete
/// — only trading/funding do (enforced both by the Buy/Sell/Add
/// money/Withdraw entry points checking these same AppState flags, and
/// server-side by OrdersService/TransactionsService, since a purely
/// frontend gate is bypassable). This function's job is just to hydrate
/// those flags accurately so Home can show the right "Complete your KYC"
/// prompt (or none, if already done) — never to redirect away from Home.
Future<void> hydrateGatingStateAndRoute(BuildContext context) async {
  final override = await hydrateGatingState(context);
  if (!context.mounted) return;
  context.go(override ?? Routes.home);
}

/// Does everything [hydrateGatingStateAndRoute] does EXCEPT the final
/// navigation — pulled apart 2026-08-29 (R-44, DECISIONS.md) so
/// biometric_screen.dart can run these same real side effects (sign-in
/// completion, cold-start-lock clearing, biometric re-hydration, the
/// dormancy check) without being forced to land on Home immediately after:
/// its own fresh-onboarding chain has an optional avatar-picker hop
/// (Routes.onboardingAvatar) first. Returns [Routes.acctDormant] when the
/// dormancy gate below fires, or `null` meaning "proceed to whatever this
/// caller's own ordinary next step is" (Home, for every caller except
/// biometric_screen.dart's onboarding chain).
Future<String?> hydrateGatingState(BuildContext context) async {
  await refreshKycGatingState(context);
  if (!context.mounted) return null;
  final app = AppScope.read(context);
  app.setSignedIn(true);
  // A-6 cold-start fix: every path that reaches this function has just had a
  // real unlock happen — fresh signup/login completing, or a cold-start
  // passcode-or-biometric challenge succeeding — so whatever gate
  // `_gateRedirect` (app_router.dart) was holding a restored session behind
  // is clear for the rest of this process. See
  // AppState.coldStartPendingUnlock's doc comment for the bug this closes.
  // A no-op when this was never set in the first place (every path here
  // except the genuine cold-start one).
  app.clearColdStartLock();

  // A-7 (2026-08-29 audit) belt-and-suspenders: AppState._hydrateBiometricEnabled
  // already restores this from PasscodeStore at app CONSTRUCTION, which
  // covers every cold start. The one gap that misses is a voluntary sign-out
  // (AppState.signOut() zeroes biometricEnabled in memory, on purpose — see
  // its own doc comment) followed by the SAME owner signing back in inside
  // the SAME still-running app process (no restart in between, so
  // hydration never re-runs). Re-checking here, on every path that lands a
  // signed-in investor on Home, closes that gap too — a no-op write when
  // it's already correct.
  if (!app.biometricEnabled) {
    final storedBiometric = await PasscodeStore().getBiometricEnabled();
    if (!context.mounted) return null;
    if (storedBiometric) app.setBiometric(true);
  }

  // Dormancy gate (2026-08-24, mobile canvas screen 89) — the backend
  // promotes an idle-12-months account to accountStatus 'dormant' at the
  // moment of a successful login (AuthService.checkAndApplyDormancy(),
  // checked BEFORE the login being handled here even happens — so this
  // fetch always sees the up-to-date status). Login itself still succeeds
  // for a dormant account (only 'suspended' is blocked server-side), so
  // this is the one place that has to decide whether to route to Home or
  // to the Dormant account screen instead. Best-effort: a failure to fetch
  // personal info here just falls through to Home as before, same
  // "never regress existing behavior over a network hiccup" posture
  // refreshKycGatingState's own header comment describes.
  try {
    final info = await UserRepository(AppScope.read(context).apiClient).personalInfo();
    if (!context.mounted) return null;
    if (info.accountStatus == 'dormant') return Routes.acctDormant;
  } on ApiException {
    // Fall through — see comment above.
  }

  return null;
}

/// The actual KYC/suitability fetch + AppState update [hydrateGatingStateAndRoute]
/// runs at login — pulled out on its own (2026-08-20, "poll the KYC endpoint
/// ... so we can see changes instantly without refreshing since no realtime
/// yet") so home_screen.dart can call it repeatedly while the investor sits
/// on Home waiting for a staff decision (or the new auto-approve), without
/// also re-running the sign-in/navigate side effects this only needs once,
/// at login.
Future<void> refreshKycGatingState(BuildContext context) async {
  final app = AppScope.read(context);
  final kycRepo = KycRepository(app.apiClient);
  final suitabilityRepo = SuitabilityRepository(app.apiClient);

  KycSubmissionStatus? kyc;
  // Only a real 404 means "never submitted" — anything else (a transient
  // network blip, a 401 racing the just-issued token, a 5xx) is NOT the
  // same signal, but used to be treated identically ("nothing confirmed
  // yet"). That silently downgraded an investor who really has a
  // KYC-under-review/approved submission to kycSubmitted=false on nothing
  // more than one failed call, which then wrongly showed Home's "Complete
  // your KYC" prompt instead of "Your KYC is under review" — reported
  // 2026-08-19 ("why is Complete KYC still showing on an account that KYC
  // is under review"). A non-404 failure now leaves kycSubmitted/kycApproved
  // exactly as AppState already had them (both still default false on a
  // genuinely fresh cold start, so a brand-new investor sees no behavior
  // change) rather than overwriting a real known state with a wrong one.
  var kycFetchFailed = false;
  try {
    kyc = await kycRepo.me();
  } on ApiException catch (e) {
    if (e.statusCode == 404) {
      kyc = null;
    } else {
      kycFetchFailed = true;
    }
  }

  if (!kycFetchFailed) {
    // A row that's still 'draft' (2026-08-20, phased KYC) is NOT a real
    // submission — findMine/GET /kyc-submissions/me returns the investor's
    // MOST RECENT row regardless of status, and a fresh draft's
    // `submittedAt` defaults to creation time, so it's often the most
    // recent row while it's in progress. Treating any non-null `kyc` as
    // "submitted" (the old logic) would wrongly flip kycSubmitted=true for
    // someone who's only, say, 2/5 steps into KYC.
    final kycSubmitted = kyc != null && !kyc.isDraft;
    final kycApproved = kyc?.isApproved ?? false;

    bool suitabilityComplete = false;
    if (kycApproved) {
      try {
        await suitabilityRepo.me();
        suitabilityComplete = true;
      } on ApiException {
        // 404 -> genuinely not submitted yet.
        suitabilityComplete = false;
      }
    }

    // Added 2026-08-24 alongside the restored mandatory suitability gate
    // (see AppState.tradingEligibilityGap) — without this, a returning
    // investor who already accepted the risk disclaimer in a past session
    // would be wrongly re-gated on every fresh app boot (AppState.
    // riskDisclosureAccepted is in-memory only). Only worth checking once
    // suitability is genuinely complete — the gate gets to that check
    // second anyway.
    var riskDisclosureAccepted = false;
    if (suitabilityComplete) {
      try {
        final kinds = await ComplianceRepository(app.apiClient).myAcknowledgedKinds();
        riskDisclosureAccepted = kinds.contains('risk_disclosure');
      } on ApiException {
        riskDisclosureAccepted = false;
      }
    }

    app.setKycSubmitted(kycSubmitted);
    app.setKycApproved(kycApproved);
    app.setSuitabilityComplete(suitabilityComplete);
    app.setRiskDisclosureAccepted(riskDisclosureAccepted);
    // Step only. The backend's `totalSteps` (KYC_TOTAL_STEPS = 5) is
    // deliberately NOT carried into AppState: it has never matched the real
    // 7-step flow, and every time it was stored something eventually
    // rendered it. The real count is derived by kycProgressSummary().
    app.setKycDraftProgress(kyc?.isDraft == true ? kyc!.currentStep : null);
    // See AppState.kycOutcomeStatus's doc comment — a genuine hard
    // rejected/flagged/expired outcome must not collapse into the same
    // "still pending" bucket a not-yet-decided submission does. A staff
    // reject with resubmission room left (kyc.isRejectedWithRoomToRetry)
    // sends `status` back to 'pending' rather than a terminal value, so it
    // needs its own sentinel here too, or Home would show "under review"
    // for a submission that was genuinely just rejected.
    const terminalOutcomes = {'rejected', 'flagged', 'expired'};
    app.setKycOutcomeStatus(
      kyc?.isRejectedWithRoomToRetry == true
          ? 'rejected_retry'
          : (terminalOutcomes.contains(kyc?.status) ? kyc!.status : null),
    );
  }
}

/// Fallback for canvas #s08's 64px avatar when the account has no chosen
/// `avatarKey` yet — same initial-letter-in-a-ring convention
/// home_screen.dart's `_Avatar` / account_screen.dart already use for that
/// case, sized up to match this screen's larger avatar.
class _LoginAvatar extends StatelessWidget {
  const _LoginAvatar({required this.initial, required this.size});
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: KColor.bg,
        shape: BoxShape.circle,
        border: Border.all(color: KColor.hairline, width: 1),
      ),
      child: Text(
        initial.toUpperCase(),
        style: KType.title(color: KColor.ink).copyWith(fontSize: size * 0.4),
      ),
    );
  }
}
