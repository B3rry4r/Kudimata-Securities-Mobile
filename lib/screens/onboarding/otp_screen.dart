// s04 · Verify email — 6 single-digit cells (fed by a hidden numeric
// TextField, since KOtpCells itself is display-only), a live resend
// countdown, one full-width Verify button. Mid-flow gated screen: top bar
// with back + "Step 4 of 4", no tab bar. R-11: the app keeps 6 digits here
// (the artboard itself already draws 6, unlike the 4-digit passcode
// screens R-11 governs) — no length change needed on this screen.
//
// Wired to POST /auth/verify-email-otp (AuthRepository) and POST
// /email-otps/resend. The email being verified arrives via GoRouter `extra`
// from the sign-up screen (`context.go(Routes.otp, extra: email)` —
// sign_up_screen.dart's `_continue()`); read here through
// `GoRouterState.of(context).extra` rather than a constructor param since
// app_router.dart's `Routes.otp` GoRoute discards its builder's `state` arg
// (`builder: (_, _) => ...`) — GoRouterState.of still resolves correctly
// from any descendant regardless of that.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/api/auth_token_store.dart';
import 'package:kudimata_invest/data/repositories/auth_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'onboarding_scaffold.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _codeLength = 6;
  static const _resendCooldown = 42; // seconds — matches the design's "0:42" seed.
  static const _purpose = 'signup_verify'; // this screen only ever follows sign-up.

  late final _repo = AuthRepository(AppScope.read(context).apiClient);
  final _tokenStore = AuthTokenStore();

  final List<String> _digits = List.filled(_codeLength, '');
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();

  Timer? _timer;
  int _secondsLeft = _resendCooldown;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  // Canvas #s04 renders "Resend in 00:42" as one small centered text line
  // under the OTP cells, and "Change" inline in the "Sent to X · Change"
  // subtitle above — tap targets for both. Neither is a dedicated screen of
  // its own in the canvas; "Change" returns to sign-up where the email was
  // entered.
  late final _resendTap = TapGestureRecognizer()
    ..onTap = () {
      if (_secondsLeft <= 0 && !_resending && !_verifying) _resend();
    };
  late final _changeEmailTap = TapGestureRecognizer()
    ..onTap = () => context.go(Routes.signup);

  int get _focusIndex => _digits.indexWhere((d) => d.isEmpty);
  bool get _complete => _focusIndex == -1;

  /// The email being verified, threaded from sign-up via GoRouter `extra`
  /// (see file header). Null if this screen was reached without it (e.g. a
  /// bare deep link) — Verify/Resend surface a clear error in that case
  /// rather than calling the backend with no address.
  String? get _email {
    final extra = GoRouterState.of(context).extra;
    return extra is String && extra.isNotEmpty ? extra : null;
  }

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _secondsLeft = _resendCooldown;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _codeFocus.dispose();
    _resendTap.dispose();
    _changeEmailTap.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    setState(() {
      for (var i = 0; i < _codeLength; i++) {
        _digits[i] = i < value.length ? value[i] : '';
      }
      _error = null;
    });
  }

  Future<void> _verify() async {
    final email = _email;
    if (email == null) {
      setState(() => _error = "We couldn't find your email. Please sign up again.");
      return;
    }
    if (!_complete || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final tokens = await _repo.verifyEmailOtp(email: email, code: _digits.join());
      await _tokenStore.saveTokens(tokens.accessToken, tokens.refreshToken ?? '');
      if (!mounted) return;
      // 2026-08-31 (R-51, DECISIONS.md): the questionnaire/suitability-result/
      // legal-documents chain this used to hand off to is gone — a verified
      // email now goes straight to passcode creation, `email` riding this
      // route's own `extra` again (no more AppState.pendingSignupEmail hop).
      //
      // [signedIn] flips true right here rather than downstream, on the
      // strength of the token just saved above — this used to happen inside
      // the deleted legal-acceptance screen's own accept handler, several
      // screens later; app_router.dart's `_gateRedirect` doc comment on the
      // 2026-08-29 "interrupted signup" fix explains why createPasscode
      // being reached with signedIn=true and passcodeSet=false is the
      // correct, expected shape, not a bug.
      AppScope.read(context).setSignedIn(true);
      context.go(Routes.createPasscode, extra: email);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = e.message;
      });
      return;
    }
    if (mounted) setState(() => _verifying = false);
  }

  Future<void> _resend() async {
    final email = _email;
    if (email == null) {
      setState(() => _error = "We couldn't find your email. Please sign up again.");
      return;
    }
    if (_secondsLeft > 0 || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await _repo.resendOtp(email: email, purpose: _purpose);
      if (!mounted) return;
      _codeController.clear();
      setState(() {
        for (var i = 0; i < _codeLength; i++) {
          _digits[i] = '';
        }
      });
      _startCountdown();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  // Artboard #s04 renders "Resend in 00:42" (zero-padded minutes, unlike the
  // countdown's un-padded seconds-tens digit). The ready-to-resend wording
  // has no artboard evidence — no variant depicts it — so "Resend code" is
  // this screen's own reasonable label for a state the design doesn't draw.
  String get _resendLabel {
    if (_secondsLeft <= 0) return 'Resend code';
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return 'Resend in $m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final email = _email;
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KOnboardTopBar(
              stepLabel: 'Step 4 of 4',
              onBack: () => context.go(Routes.signup),
            ),
            Expanded(
              child: KOnboardBody(
                paddingTop: 18,
                children: [
                  // Canvas #s04 draws no illustration on this screen — straight
                  // from the top bar into the title. The 2026-08-23 pass had
                  // added one; dropped to match.
                  const KScreenHead(title: 'Enter the code we emailed you'),
                  const SizedBox(height: 10),
                  // Artboard copy: "Sent to adebayo@email.com · Change" — one
                  // line, "Change" a same-line link back to sign-up (where the
                  // email was entered), not a separate line under the cells.
                  RichText(
                    text: TextSpan(
                      style: KType.body(color: KColor.ink2),
                      children: [
                        TextSpan(text: 'Sent to ${email ?? 'your email'} · '),
                        TextSpan(
                          text: 'Change',
                          style: KType.body(color: KColor.ink2, w: KWeight.semibold),
                          recognizer: _changeEmailTap,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Stack(
                    children: [
                      KOtpCells(digits: _digits, focusIndex: _focusIndex),
                      // Invisible numeric field driving the digit cells above —
                      // KOtpCells (onboarding_scaffold.dart) is display-only, no
                      // onChanged/TextField of its own.
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0,
                          child: TextField(
                            controller: _codeController,
                            focusNode: _codeFocus,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(_codeLength),
                            ],
                            onChanged: _onCodeChanged,
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
                  const SizedBox(height: 16),
                  // Canvas #s04: "Resend in 00:42" — centered, on its own,
                  // directly under the cells. "Change" already sits in the
                  // subtitle above (next to the email address), not
                  // repeated here.
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: KType.body(color: KColor.ink3),
                        children: [
                          TextSpan(
                            text: _resendLabel,
                            recognizer: (_secondsLeft > 0 || _resending || _verifying)
                                ? null
                                : _resendTap,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: KType.body(color: KColor.loss, w: KWeight.medium)),
                  ],
                  const Spacer(),
                  // Canvas #s04 draws exactly one button, labelled "Verify".
                  // A prior pass added a second "I can't access this email"
                  // button here citing "Canvas #s04's second button" — that
                  // comment was reading the OLD 97-screen canvas (R-5's
                  // trap: this build's #s04 is a different screen and draws
                  // no second control at all). Removed; password reset is
                  // still reachable from the login screen's own "Forgot
                  // password?" link (log_in_screen.dart), which fits better
                  // anyway — this screen is verifying a brand-new signup
                  // email, not an existing account login.
                  KButton(
                    label: 'Verify',
                    loading: _verifying,
                    onPressed: (_complete && !_verifying && !_resending) ? _verify : null,
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
