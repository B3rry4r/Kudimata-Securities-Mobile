// Artboard `s09` (+ dark `s09d`) in `01 Getting In.dc.html` — Reset your
// password. Ported from screens.jsx ResetPasscode (originally mislabeled
// "reset your passcode" — both the screen copy and the buttons linking to
// it, on both the login form and the local-unlock screen, called this
// "Forgot passcode"; relabeled to "Forgot/reset password" since that's what
// it actually does). Mid-flow gated screen pushed off Log in, no tab bar.
//
// R-20 (docs/redesign/DECISIONS.md): "Account password reset and local
// passcode reset stay SEPARATE flows. The canvas's combined flow (email code
// → straight into setting a passcode) is not adopted: it would mean anyone
// with email access can reset a device credential." This screen ends by
// signing the investor out and handing them to the real email+password
// login form (log_in_screen.dart) — never to create_passcode_screen.dart —
// so a successful reset here can never itself mint a new local passcode.
//
// Reconciliation note: the backend concept behind this screen is a real
// account PASSWORD reset, not the app-local PIN —
// Kudimata-Securities-Backend/.pipeline/conventions.md is explicit that the
// passcode is client-only and never sent to the server, and registry.json's
// AuthSession/EmailOtp resources have no passcode-reset endpoint at all,
// only a password one:
//   POST /auth/request-password-reset {email} -> EmailOtp
//   POST /auth/reset-password {email, code, newPassword} -> 204 No Content
//     (not on the frozen registry.json list; the necessary completion of
//     request-password-reset — see lib/data/repositories/auth_repository.dart
//     and Kudimata-Securities-Backend src/auth/auth.controller.ts /
//     dto/reset-password.dto.ts for confirmation of the exact body shape).
//
// `s09` itself draws one screen — illustration, "Reset your password", "We
// email a link to adebayo@email.com so you can set a new password.", one
// "Email me a reset link" button — and its own flow note says the next step
// is a `s04`-style code entry, then straight into a NEW passcode (`s05`).
// That chained ending is exactly R-20's rejected "combined flow", so it is
// not built. What ships instead: `s09`'s look for the request step (below),
// then a second, real step this app adds — a code field plus a new-password
// field, POSTed to /auth/reset-password — reusing this screen's existing
// KInput/KButton/KScreenHead/KOnboardTopBar/KOnboardBody shapes, no new
// shared widgets. `s09` also claims the email is sent as a clickable "link";
// the real endpoint returns an `EmailOtp` (a code), not a link, so the
// on-screen copy says "code" — R-34: a claim about system behaviour with no
// mechanism behind it (a link, when the backend hands back a one-time code)
// is not shipped as designed, only the accurate version. The back arrow
// steps from the code/password step back to the email step before falling
// back to Log in.
//
// 2026-08-27 (SCREEN-AGENT-BRIEF.md R-5 audit): this file used to cite
// "Canvas #s12" — an id from the retired 97-screen canvas, and one that
// described a different shape entirely (arriving pre-warmed on "step 2 of
// 2"). Renumbered/corrected throughout below to `s09`.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/auth_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/data/password_policy.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'onboarding_scaffold.dart';

class ResetPasscodeScreen extends StatefulWidget {
  const ResetPasscodeScreen({super.key});

  @override
  State<ResetPasscodeScreen> createState() => _ResetPasscodeScreenState();
}

class _ResetPasscodeScreenState extends State<ResetPasscodeScreen> {
  late final _repo = AuthRepository(AppScope.read(context).apiClient);

  // Distinct controllers per field (and per step) are required here: the
  // email-step and code-step KInputs occupy the same slot in the Column
  // returned by build(), and with no controller (and no key) Flutter's
  // element diffing reuses the same KInput State — and with it the
  // underlying TextField's own internal editing buffer — across steps,
  // which was making the Code field render whatever text was left over
  // from the Email field. Owning separate controllers (each explicitly
  // passed to its KInput) forces TextField to bind to a fresh, genuinely
  // empty text source when step 2 first appears, regardless of any
  // widget/element reuse between the two steps.
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _email = '';
  String _code = '';
  String _newPassword = '';
  String _confirmPassword = '';

  // Step 2 only reachable once request-password-reset has actually
  // succeeded — no client-side skip to the code/new-password step.
  bool _codeSent = false;
  bool _busy = false;

  // `s09` shows the investor's email as static text ("We email a link to
  // adebayo@email.com…") with no email input field anywhere on it — both of
  // its real entry points (`s08p`'s and `s08`'s "Forgot password?" links)
  // already know the investor's email from context. otp_screen.dart and
  // log_in_screen.dart now thread that known email through via GoRouter
  // `extra`; when present, skip the email step entirely and fire the reset
  // email automatically, same as the canvas implies. Falls back to the
  // manual email-entry step (this screen's pre-existing behaviour) when
  // reached with no known email (e.g. a bare deep link) — same pattern
  // otp_screen.dart's `_email` getter uses.
  bool _autoStartHandled = false;
  // True once we know the email step was skipped via a known-email `extra` —
  // there's then no real "step 1" to fall back to on a back-tap, so it goes
  // straight to Log in (canvas #s12's back target) instead of exposing a
  // synthetic email step the investor never actually saw.
  bool _skippedEmailStep = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_autoStartHandled) return;
    _autoStartHandled = true;
    final extra = GoRouterState.of(context).extra;
    if (extra is String && extra.isNotEmpty) {
      _emailController.text = extra;
      _email = extra;
      _skippedEmailStep = true;
      _sendCode();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _emailValid => _email.contains('@') && _email.contains('.');
  bool get _confirmMismatch =>
      _confirmPassword.isNotEmpty && _confirmPassword != _newPassword;
  bool get _resetValid =>
      _code.trim().isNotEmpty &&
      // R-43, via the ONE shared rule. This line checked only
      // `length >= 8`, so it accepted a password the server then
      // rejected for having no special character — and the investor
      // saw "Validation failed" with no reason, on the screen they
      // were on because they could not get in.
      passwordAcceptable(_newPassword) &&
      !_confirmMismatch &&
      _confirmPassword.isNotEmpty;

  Future<void> _sendCode() async {
    if (!_emailValid || _busy) return;
    setState(() => _busy = true);
    try {
      await _repo.requestPasswordReset(_email.trim());
      if (!mounted) return;
      setState(() {
        _busy = false;
        _codeSent = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetValid || _busy) return;
    setState(() => _busy = true);
    try {
      await _repo.resetPassword(
        email: _email.trim(),
        code: _code.trim(),
        newPassword: _newPassword,
      );
      if (!mounted) return;
      // This screen is also reachable from the local-unlock screen (a
      // signed-in device with a set passcode the investor has forgotten —
      // see log_in_screen.dart's `_buildUnlock`), where AppState.signedIn
      // and PasscodeStore.hasPasscode() are both still true going in. Without
      // clearing them here, log_in_screen.dart's `_decideMode()` would just
      // show that same locked passcode screen again after a successful
      // password reset — a dead end for exactly the person this flow exists
      // to help. forceSignOut() clears both the stale session and the
      // forgotten local passcode, so the login screen correctly falls back
      // to its email+password form.
      await AppScope.read(context).forceSignOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset. Log in with your new password.')),
      );
      // Hand off to the real email+password login form (log_in_screen.dart).
      // Passing the email along just saves retyping it. Read via
      // GoRouterState.of(context).extra on that screen (app_router.dart's
      // Routes.login GoRoute discards its builder's `state` arg, same as
      // otp_screen.dart's own extra handoff).
      context.go(Routes.login, extra: _email.trim());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    }
  }

  void _onBack() {
    if (_codeSent && !_skippedEmailStep) {
      setState(() => _codeSent = false);
    } else {
      context.go(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KOnboardTopBar(
              // `s09` itself shows no step label (just a back arrow) — but
              // it also draws only one screen, with no in-app code/password
              // step at all. Since this app must complete the reset over two
              // real steps the canvas never drew (see file header), a step
              // label here orients the investor through content the artboard
              // doesn't depict, rather than copying a "no label" chrome that
              // only made sense for a single-screen flow.
              stepLabel: _codeSent ? 'Reset · step 2 of 2' : 'Reset · step 1 of 2',
              onBack: _onBack,
            ),
            Expanded(
              child: KOnboardBody(
                paddingTop: 8,
                children: _codeSent ? _resetStep() : _emailStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _emailStep() {
    return [
      // `s09`'s illustration, on the same sun-tinted plate the artboard
      // draws it on.
      const KIllustration('email-sent', role: KIlloRole.state, tone: KIlloTone.sun),
      const SizedBox(height: 20),
      const KScreenHead(
        title: 'Reset your password',
        // `s09` says "We email a link…" — the real endpoint returns an
        // EmailOtp (a one-time code), not a link (see file header's R-34
        // note), so this says "code" to match what actually happens.
        body: "We'll send a code to your email.",
      ),
      const SizedBox(height: 28),
      // `s09` never draws this field — its real entry points already know
      // the investor's email (see the `_email` field's own doc comment).
      // This only renders on a bare deep link with no known email, a case
      // the artboard doesn't depict but this code path still has to serve.
      KInput(
        key: const ValueKey('reset-email-input'),
        label: 'Email',
        icon: 'mail',
        placeholder: 'you@email.com',
        keyboardType: TextInputType.emailAddress,
        controller: _emailController,
        value: _email,
        onChanged: (v) => setState(() => _email = v),
      ),
      const Spacer(),
      KButton(
        label: 'Send code',
        loading: _busy,
        onPressed: _emailValid && !_busy ? _sendCode : null,
      ),
    ];
  }

  List<Widget> _resetStep() {
    return [
      KScreenHead(
        title: 'Choose a new password',
        body: 'Enter the code sent to $_email and your new password.',
      ),
      const SizedBox(height: 28),
      KInput(
        key: const ValueKey('reset-code-input'),
        label: 'Reset code',
        placeholder: '6 digits',
        numeric: true,
        controller: _codeController,
        value: _code,
        onChanged: (v) => setState(() => _code = v),
      ),
      const SizedBox(height: 16),
      KInput(
        key: const ValueKey('reset-new-password-input'),
        label: 'New password',
        placeholder: kPasswordRuleLabel,
        icon: 'lock',
        helper: kPasswordRuleLabel,
        obscure: true,
        controller: _newPasswordController,
        value: _newPassword,
        onChanged: (v) => setState(() => _newPassword = v),
      ),
      const SizedBox(height: 16),
      KInput(
        key: const ValueKey('reset-confirm-password-input'),
        label: 'Confirm new password',
        placeholder: 'Re-enter your new password',
        icon: 'lock',
        obscure: true,
        controller: _confirmPasswordController,
        value: _confirmPassword,
        error: _confirmMismatch ? "Passwords don't match yet" : null,
        onChanged: (v) => setState(() => _confirmPassword = v),
      ),
      const Spacer(),
      KButton(
        label: 'Save and log in',
        loading: _busy,
        onPressed: _resetValid && !_busy ? _resetPassword : null,
      ),
      const SizedBox(height: 10),
      KButton(
        label: 'Resend the code',
        variant: KButtonVariant.ghost,
        onPressed: _busy ? null : _sendCode,
      ),
    ];
  }
}
