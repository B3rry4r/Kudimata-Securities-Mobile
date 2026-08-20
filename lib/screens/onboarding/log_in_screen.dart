// 06 · Log in — the returning-user unlock. Centered wordmark, passcode dots, the
// keypad (with a biometric shortcut bottom-left), and a Forgot password link
// (relabeled from "Forgot passcode" — the screen it leads to is a real
// account password reset, not a local-passcode reset; see
// reset_passcode_screen.dart's header comment).
// On a full passcode we sign in and go home. Ported from screens.jsx LogIn.
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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/api/auth_token_store.dart';
import 'package:kudimata_invest/data/api/passcode_store.dart';
import 'package:kudimata_invest/data/repositories/auth_repository.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/data/repositories/suitability_repository.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'onboarding_scaffold.dart';

class LogInScreen extends StatefulWidget {
  const LogInScreen({super.key});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  // ── Mode decision ─────────────────────────────────────────────────────
  // null while deciding; true = email+password form; false = local unlock.
  bool? _showEmailLogin;
  final _passcodeStore = PasscodeStore();
  bool _prefilledEmail = false;

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
    setState(() {
      _showEmailLogin = !app.signedIn || !hasPasscode;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _stepUpController.dispose();
    _stepUpFocus.dispose();
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

    if (!viaBiometric) {
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
  /// client_agreement_screen.dart setting it only once suitability is
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
    if (_showEmailLogin == null) {
      // Brief beat while [_decideMode] reads PasscodeStore.
      return Scaffold(
        backgroundColor: KColor.bg,
        body: Center(child: KSpinner(size: 22, color: KColor.ink3)),
      );
    }
    if (_showEmailLogin == true) {
      return _stepUpEmail != null ? _buildStepUp() : _buildLoginForm();
    }
    return _buildUnlock(context);
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
                const KWordmark(center: true),
                const SizedBox(height: 28),
                Text('Enter your passcode', style: KType.body(color: KColor.ink2)),
                const SizedBox(height: 24),
                KPasscodeDots(filled: _code.length, error: _error),
                const SizedBox(height: 18),
                if (_error)
                  Text(
                    'Incorrect passcode',
                    style: KType.body(color: KColor.loss, w: KWeight.medium),
                  ),
                const SizedBox(height: 26),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: KKeypad(
                    onKey: _onKey,
                    leftAction: app.biometricEnabled
                        ? KFingerprint(size: 26, stroke: 1.6, color: KColor.ink)
                        : null,
                    onLeftAction:
                        app.biometricEnabled ? () => _unlock(viaBiometric: true) : null,
                  ),
                ),
                const SizedBox(height: 8),
                KButton(
                  label: 'Forgot password',
                  variant: KButtonVariant.ghost,
                  size: KButtonSize.sm,
                  fullWidth: false,
                  onPressed: () => context.go(Routes.reset),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Email+password login UI (new) ───────────────────────────────────────
  Widget _buildLoginForm() {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: KOnboardBody(
          paddingTop: 32,
          children: [
            const KWordmark(),
            const SizedBox(height: 28),
            const KScreenHead(title: 'Log in'),
            const SizedBox(height: 28),
            KInput(
              label: 'Email',
              icon: 'profile',
              placeholder: 'you@email.com',
              keyboardType: TextInputType.emailAddress,
              controller: _email,
              onChanged: _showErrors ? (_) => setState(() {}) : null,
              error: _showErrors && !_emailValid ? 'Enter a valid email address' : null,
            ),
            const SizedBox(height: 16),
            KInput(
              label: 'Password',
              placeholder: 'Your password',
              obscure: true,
              controller: _password,
              onChanged: _showErrors ? (_) => setState(() {}) : null,
              error: _showErrors && _password.text.isEmpty ? 'Enter your password' : null,
            ),
            if (_serverError != null) ...[
              const SizedBox(height: 16),
              Text(_serverError!, style: KType.body(color: KColor.loss, w: KWeight.medium)),
            ],
            const Spacer(),
            Column(
              children: [
                KButton(
                  label: 'Log in',
                  iconRight: 'arrowUpRight',
                  loading: _busy,
                  onPressed: _busy ? null : _login,
                ),
                const SizedBox(height: 10),
                KButton(
                  label: 'Create an account',
                  variant: KButtonVariant.ghost,
                  onPressed: _busy ? null : () => context.go(Routes.signup),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: KButton(
                label: 'Forgot password',
                variant: KButtonVariant.ghost,
                size: KButtonSize.sm,
                fullWidth: false,
                onPressed: _busy ? null : () => context.go(Routes.reset),
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

    app.setKycSubmitted(kycSubmitted);
    app.setKycApproved(kycApproved);
    app.setSuitabilityComplete(suitabilityComplete);
    app.setKycDraftProgress(kyc?.isDraft == true ? kyc!.currentStep : null, kyc?.isDraft == true ? kyc!.totalSteps : null);
  }
  app.setSignedIn(true);

  if (!context.mounted) return;
  context.go(Routes.home);
}
