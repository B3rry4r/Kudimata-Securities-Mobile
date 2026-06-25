// 01 · Sign up — wordmark, email/phone segmented control, single input, Continue.
// Ported from screens.jsx SignUp. Root gated screen: own Scaffold, no tab bar.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  String _value = '';

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
                    value: _value,
                    onChanged: (v) => setState(() => _value = v),
                  )
                : KInput(
                    label: 'Phone',
                    icon: 'profile',
                    prefix: '+234',
                    placeholder: '801 234 5678',
                    keyboardType: TextInputType.phone,
                    value: _value,
                    onChanged: (v) => setState(() => _value = v),
                  ),
            const Spacer(),
            Column(
              children: [
                KButton(
                  label: 'Continue',
                  iconRight: 'arrowUpRight',
                  // SEAM: real sign-up (broker account create + OTP dispatch) plugs
                  // in here; the demo advances to OTP verify unconditionally.
                  onPressed: () => context.go(Routes.otp),
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
}
