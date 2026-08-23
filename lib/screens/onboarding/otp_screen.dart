// 02 · OTP verify — 6 single-digit cells (fed by a hidden numeric TextField, since
// KOtpCells itself is display-only), a live resend countdown, Verify.
// Ported from screens.jsx Otp. Mid-flow gated screen: top bar with back, no tab bar.
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
      context.go(Routes.termsOfService, extra: email);
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

  String get _resendLabel {
    if (_secondsLeft <= 0) return 'Resend code';
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return 'Resend code in $m:$s';
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
              stepLabel: 'Step 1 of 4',
              onBack: () => context.go(Routes.signup),
            ),
            Expanded(
              child: KOnboardBody(
                paddingTop: 8,
                children: [
                  const KIllustration('email-sent', role: KIlloRole.banner),
                  const SizedBox(height: 20),
                  KScreenHead(
                    title: 'Check your email',
                    body: 'We sent a 6-digit code to ${email ?? 'your email'}.',
                  ),
                  const SizedBox(height: 36),
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
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: KType.body(color: KColor.loss, w: KWeight.medium)),
                  ],
                  const Spacer(),
                  Column(
                    children: [
                      KButton(
                        label: _resendLabel,
                        variant: KButtonVariant.ghost,
                        loading: _resending,
                        onPressed: (_secondsLeft > 0 || _resending || _verifying) ? null : _resend,
                      ),
                      const SizedBox(height: 10),
                      KButton(
                        label: 'Verify email',
                        loading: _verifying,
                        onPressed: (_complete && !_verifying && !_resending) ? _verify : null,
                      ),
                    ],
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
