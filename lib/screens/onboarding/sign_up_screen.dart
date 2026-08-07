// 01 · Sign up — wordmark, email/phone segmented control, single input, Continue.
// Ported from screens.jsx SignUp. Root gated screen: own Scaffold, no tab bar.
//
// Wired to POST /auth/signup (AuthRepository). Product truth: sign-up is
// email+password only — there is no backend counterpart for a phone
// sign-up (see Kudimata-Securities-Backend registry.json's AuthSession
// resource: POST /auth/signup takes {email, password} and nothing else).
// The phone tab is left in the UI as-is (out of scope to redesign here) but
// Continue always requires the email tab's value — selecting the phone tab
// and pressing Continue surfaces a validation error rather than submitting,
// which is a known UI mismatch, not a bug fixed by this wiring pass.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/api/api_exception.dart';
import 'package:kudimata_securities/data/repositories/auth_repository.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'onboarding_scaffold.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  String _tab = 'email';
  String _value = ''; // phone tab's value — display-only, see file header.

  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _showErrors = false;
  bool _busy = false;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _emailValid => _emailPattern.hasMatch(_email.text.trim());
  bool get _passwordValid => _password.text.trim().length >= 8;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emailTab = _tab == 'email';
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
            KSegmentedControl(
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
              options: const [
                KSegmentOption(value: 'email', label: 'Email'),
                KSegmentOption(value: 'phone', label: 'Phone'),
              ],
            ),
            const SizedBox(height: 20),
            emailTab
                ? KInput(
                    label: 'Email',
                    icon: 'profile',
                    placeholder: 'you@email.com',
                    keyboardType: TextInputType.emailAddress,
                    controller: _email,
                    onChanged: _showErrors ? (_) => setState(() {}) : null,
                    error: _showErrors && !_emailValid ? 'Enter a valid email address' : null,
                  )
                : KInput(
                    label: 'Phone',
                    icon: 'profile',
                    prefix: '+234',
                    placeholder: '801 234 5678',
                    keyboardType: TextInputType.phone,
                    value: _value,
                    onChanged: (v) => setState(() => _value = v),
                    error: _showErrors ? 'Sign up with email — phone isn’t supported yet' : null,
                  ),
            if (emailTab) ...[
              const SizedBox(height: 16),
              KInput(
                label: 'Password',
                placeholder: 'At least 8 characters',
                obscure: true,
                controller: _password,
                onChanged: _showErrors ? (_) => setState(() {}) : null,
                error: _showErrors && !_passwordValid ? 'Use at least 8 characters' : null,
              ),
            ],
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
    if (_tab != 'email' || !_emailValid || !_passwordValid) {
      setState(() => _showErrors = true);
      return;
    }
    final email = _email.text.trim();
    final password = _password.text.trim();
    setState(() => _busy = true);
    final repo = AuthRepository(AppScope.read(context).apiClient);
    try {
      await repo.signUp(email: email, password: password);
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
