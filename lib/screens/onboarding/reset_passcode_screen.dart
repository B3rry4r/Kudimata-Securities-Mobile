// 07 · Reset your passcode — email entry, then code + new password. Ported
// from screens.jsx ResetPasscode, extended with a second step. Mid-flow
// gated screen pushed off Log in, no tab bar.
//
// Reconciliation note: despite this screen's name ("reset your passcode"),
// the backend concept behind it is a real account PASSWORD reset, not the
// app-local PIN — Kudimata-Securities-Backend/.pipeline/conventions.md is
// explicit that the passcode is client-only and never sent to the server,
// and registry.json's AuthSession/EmailOtp resources have no passcode-reset
// endpoint at all, only a password one:
//   POST /auth/request-password-reset {email} -> EmailOtp
//   POST /auth/reset-password {email, code, newPassword} -> 204 No Content
//     (not on the frozen registry.json list; the necessary completion of
//     request-password-reset — see lib/data/repositories/auth_repository.dart
//     and Kudimata-Securities-Backend src/auth/auth.controller.ts /
//     dto/reset-password.dto.ts for confirmation of the exact body shape).
// The original mock screen only ever collected an email with no code/new-
// password fields (its "Send code" button just navigated straight back to
// Log in), so a second step is added here to actually complete the flow:
// a numeric code field plus a new-password field, reusing this screen's
// existing KInput/KButton/KScreenHead/KOnboardTopBar/KOnboardBody shapes —
// no new shared widgets. The back arrow steps from the code/password step
// back to the email step before falling back to Log in.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/api/api_exception.dart';
import 'package:kudimata_securities/data/repositories/auth_repository.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
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

  String _email = '';
  String _code = '';
  String _newPassword = '';

  // Step 2 only reachable once request-password-reset has actually
  // succeeded — no client-side skip to the code/new-password step.
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  bool get _emailValid => _email.contains('@') && _email.contains('.');
  bool get _resetValid => _code.trim().isNotEmpty && _newPassword.length >= 8;

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset. Log in with your new password.')),
      );
      // Hand off to the real email+password login form (log_in_screen.dart),
      // not the old passcode-unlock screen — a password reset doesn't touch
      // this device's local passcode/session, so AppState.signedIn is still
      // false here and log_in_screen.dart would show its email-login mode
      // anyway; passing the email along just saves retyping it. Read via
      // GoRouterState.of(context).extra on that screen (app_router.dart's
      // Routes.login GoRoute discards its builder's `state` arg, same as
      // otp_screen.dart's own extra handoff).
      context.go(Routes.login, extra: _email.trim());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _onBack() {
    if (_codeSent) {
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
            KOnboardTopBar(onBack: _onBack),
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
      const KScreenHead(
        title: 'Reset your passcode',
        body: "We'll send a code to your email.",
      ),
      const SizedBox(height: 28),
      KInput(
        key: const ValueKey('reset-email-input'),
        label: 'Email',
        icon: 'profile',
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
        label: 'Code',
        placeholder: '123456',
        numeric: true,
        controller: _codeController,
        value: _code,
        onChanged: (v) => setState(() => _code = v),
      ),
      const SizedBox(height: 16),
      KInput(
        key: const ValueKey('reset-new-password-input'),
        label: 'New password',
        placeholder: 'At least 8 characters',
        obscure: true,
        controller: _newPasswordController,
        value: _newPassword,
        onChanged: (v) => setState(() => _newPassword = v),
      ),
      const Spacer(),
      KButton(
        label: 'Reset password',
        loading: _busy,
        onPressed: _resetValid && !_busy ? _resetPassword : null,
      ),
    ];
  }
}
