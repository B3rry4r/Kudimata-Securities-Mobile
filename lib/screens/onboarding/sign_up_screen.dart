// 01 · Sign up — wordmark, email input, Continue.
// Ported from screens.jsx SignUp. Root gated screen: own Scaffold, no tab bar.
//
// Wired to POST /auth/signup (AuthRepository). Product truth: sign-up is
// email+password only — there is no backend counterpart for a phone
// sign-up (see Kudimata-Securities-Backend registry.json's AuthSession
// resource: POST /auth/signup takes {email, password} and nothing else).
// The original design mockup had an email/phone segmented control here;
// the phone tab was removed since it never did anything (see git history).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/auth_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'onboarding_scaffold.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _showErrors = false;
  bool _busy = false;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _fullNameValid => _fullName.text.trim().isNotEmpty;
  bool get _emailValid => _emailPattern.hasMatch(_email.text.trim());
  bool get _passwordValid => _password.text.trim().length >= 8;
  bool get _confirmPasswordValid =>
      _confirmPassword.text.trim().isNotEmpty &&
      _confirmPassword.text.trim() == _password.text.trim();

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: KOnboardBody(
          paddingTop: 32,
          children: [
            const KWordmark(),
            const SizedBox(height: 28),
            const KScreenHead(title: 'Create your account'),
            const SizedBox(height: 28),
            KInput(
              label: 'Full name',
              icon: 'profile',
              placeholder: 'Ada Obi',
              controller: _fullName,
              onChanged: _showErrors ? (_) => setState(() {}) : null,
              error: _showErrors && !_fullNameValid ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 16),
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
              placeholder: 'At least 8 characters',
              obscure: true,
              controller: _password,
              onChanged: _showErrors ? (_) => setState(() {}) : null,
              error: _showErrors && !_passwordValid ? 'Use at least 8 characters' : null,
            ),
            const SizedBox(height: 16),
            KInput(
              label: 'Confirm password',
              placeholder: 'Re-enter your password',
              obscure: true,
              controller: _confirmPassword,
              onChanged: _showErrors ? (_) => setState(() {}) : null,
              error: _showErrors && !_confirmPasswordValid ? 'Passwords do not match' : null,
            ),
            const Spacer(),
            Column(
              children: [
                KButton(
                  label: 'Continue',
                  iconRight: 'arrowUpRight',
                  loading: _busy,
                  onPressed: _busy ? null : _continue,
                ),
                const SizedBox(height: 10),
                KButton(
                  label: 'Log in',
                  variant: KButtonVariant.ghost,
                  onPressed: () => context.go(Routes.login),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'By continuing you agree to our Terms and Risk Disclosure.',
                textAlign: TextAlign.center,
                style: KType.micro(color: KColor.ink3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _continue() async {
    if (!_fullNameValid || !_emailValid || !_passwordValid || !_confirmPasswordValid) {
      setState(() => _showErrors = true);
      return;
    }
    final fullName = _fullName.text.trim();
    final email = _email.text.trim();
    final password = _password.text.trim();
    setState(() => _busy = true);
    final repo = AuthRepository(AppScope.read(context).apiClient);
    try {
      await repo.signUp(email: email, password: password, fullName: fullName);
      if (!mounted) return;
      context.go(Routes.otp, extra: email);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}
