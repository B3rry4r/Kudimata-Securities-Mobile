// 01 · Sign up — wordmark, email input, Continue.
// Ported from screens.jsx SignUp. Root gated screen: own Scaffold, no tab bar.
//
// Wired to POST /auth/signup (AuthRepository). Product truth: sign-up is
// email+password only — there is no backend counterpart for a phone
// sign-up (see Kudimata-Securities-Backend registry.json's AuthSession
// resource: POST /auth/signup takes {email, password} and nothing else).
// The original design mockup had an email/phone segmented control here;
// the phone tab was removed since it never did anything (see git history).
import 'package:flutter/gestures.dart';
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
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _showErrors = false;
  bool _busy = false;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  // firstName/lastName required, middleName optional — split from one
  // "Full name" field 2026-08-19 so BVN/NIN verification has a real
  // first/last to compare against the registry's own name fields.
  bool get _firstNameValid => _firstName.text.trim().isNotEmpty;
  bool get _lastNameValid => _lastName.text.trim().isNotEmpty;
  bool get _emailValid => _emailPattern.hasMatch(_email.text.trim());
  bool get _passwordValid => _password.text.trim().length >= 8;
  bool get _confirmPasswordValid =>
      _confirmPassword.text.trim().isNotEmpty &&
      _confirmPassword.text.trim() == _password.text.trim();

  // Tap targets for the "By continuing..." line below — pushes a read-only
  // preview (legal_preview_screen.dart) via GET /public/legal-documents/
  // content/:kind, the one legal-documents route with no auth requirement,
  // since there's no account/token yet on this screen.
  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => context.push(Routes.legalPreview('terms_of_service'));
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => context.push(Routes.legalPreview('privacy_policy'));
  late final _riskTap = TapGestureRecognizer()
    ..onTap = () => context.push(Routes.legalPreview('risk_disclosure'));
  // 2026-08-24: the line used to name only 3 of the 4 real documents an
  // investor must actually agree to (Client Agreement was missing) —
  // direct product feedback: "by continuing you agree to our... should
  // agree to terms and disclosures meaning all our legal". Added for real,
  // not just in copy — legal_preview_screen.dart's kind-keyed maps needed
  // a client_agreement entry too (a genuine, separately-confirmed small
  // gap: it only covered terms_of_service/privacy_policy/risk_disclosure).
  late final _agreementTap = TapGestureRecognizer()
    ..onTap = () => context.push(Routes.legalPreview('client_agreement'));

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    _riskTap.dispose();
    _agreementTap.dispose();
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
            const SizedBox(height: 6),
            Text('Two minutes now. Verification comes after.',
                style: KType.body(color: KColor.ink2)),
            const SizedBox(height: 22),
            KInput(
              label: 'First name',
              icon: 'profile',
              placeholder: 'Ada',
              controller: _firstName,
              onChanged: _showErrors ? (_) => setState(() {}) : null,
              error: _showErrors && !_firstNameValid ? 'Enter your first name' : null,
            ),
            const SizedBox(height: 16),
            KInput(
              label: 'Middle name (optional)',
              icon: 'profile',
              placeholder: 'Chioma',
              controller: _middleName,
            ),
            const SizedBox(height: 16),
            KInput(
              label: 'Last name',
              icon: 'profile',
              placeholder: 'Obi',
              controller: _lastName,
              onChanged: _showErrors ? (_) => setState(() {}) : null,
              error: _showErrors && !_lastNameValid ? 'Enter your last name' : null,
            ),
            const SizedBox(height: 14),
            // 2026-08-20 directive: "a note or something that tells users
            // beautifully please and not hard to miss, that name must
            // match what is on their bvn and nin" — a real reason for
            // this, not just a suggestion: kyc-submissions.service.ts's
            // name cross-check (namesMatch) compares whatever the
            // investor typed HERE against the registry's own name on the
            // BVN/NIN record, and a mismatch is a genuine reject reason.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: KColor.indicatorTint,
                borderRadius: KRadii.cardR,
                border: Border.all(color: KColor.indicator.withValues(alpha: 0.24), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Use your legal name',
                      style: KType.cardTitle(color: KColor.indicator, w: KWeight.semibold)),
                  const SizedBox(height: 4),
                  Text(
                    'Enter your name exactly as it appears on your BVN and NIN — a mismatch here will fail identity verification later.',
                    style: KType.micro(color: KColor.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            KInput(
              label: 'Email',
              icon: 'mail',
              placeholder: 'you@email.com',
              helper: 'We send your verification code here',
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
            // Fixed gap, not `Spacer()` (2026-08-20 fix — reported:
            // "confirm password and the continue button are joined
            // together"). KOnboardBody wraps this Column in an
            // IntrinsicHeight sized to at least the viewport height, so
            // Spacer() only has room to expand while total content is
            // SHORTER than the viewport — adding the name-match notice
            // card above pushed this form's content past that point, so
            // Spacer collapsed to zero and the button landed flush
            // against the field above it. A fixed gap is correct
            // regardless of how tall the content above it gets.
            const SizedBox(height: 28),
            // Mockup #s03: legal line sits ABOVE Continue, reads "By
            // continuing you agree to our [Terms], [Privacy] and [Risk]."
            // — not "You'll review and accept... next." below the button.
            // The mockup's fixed bottom block is legal-line + Continue
            // only; the extra "Log in" ghost button below isn't in #s03 —
            // kept here (not removed) since no code comment explains
            // either way and cutting a working nav affordance felt riskier
            // than flagging it. See docs/redesign/PLAN.md open questions.
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: KType.data(color: KColor.ink2),
                children: [
                  const TextSpan(text: 'By continuing you agree to our '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: KType.data(color: KColor.ink2)
                        .copyWith(decoration: TextDecoration.underline),
                    recognizer: _termsTap,
                  ),
                  const TextSpan(text: ', '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: KType.data(color: KColor.ink2)
                        .copyWith(decoration: TextDecoration.underline),
                    recognizer: _privacyTap,
                  ),
                  const TextSpan(text: ', '),
                  TextSpan(
                    text: 'Risk Disclosure',
                    style: KType.data(color: KColor.ink2)
                        .copyWith(decoration: TextDecoration.underline),
                    recognizer: _riskTap,
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Client Agreement',
                    style: KType.data(color: KColor.ink2)
                        .copyWith(decoration: TextDecoration.underline),
                    recognizer: _agreementTap,
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Mockup #s03's fixed bottom block is legal-line + Continue
            // only, no icon on the button — the arrowUpRight icon and the
            // extra "Log in" ghost button below it were both additions with
            // no grounding in the canvas (removed 2026-08-23 exactness
            // audit; "I already have an account" on the welcome slider
            // already covers this nav path — welcome_slider_screen.dart).
            KButton(
              label: 'Continue',
              loading: _busy,
              onPressed: _busy ? null : _continue,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _continue() async {
    if (!_firstNameValid || !_lastNameValid || !_emailValid || !_passwordValid || !_confirmPasswordValid) {
      setState(() => _showErrors = true);
      return;
    }
    final firstName = _firstName.text.trim();
    final middleName = _middleName.text.trim();
    final lastName = _lastName.text.trim();
    final email = _email.text.trim();
    final password = _password.text.trim();
    setState(() => _busy = true);
    final repo = AuthRepository(AppScope.read(context).apiClient);
    try {
      await repo.signUp(
        email: email,
        password: password,
        firstName: firstName,
        middleName: middleName.isEmpty ? null : middleName,
        lastName: lastName,
      );
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
