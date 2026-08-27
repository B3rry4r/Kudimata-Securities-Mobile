// 03 · Sign up — three-step wizard (Step 1 of 4..3 of 4; step 4 is email OTP,
// otp_screen.dart): name → email+phone → password. Root gated screen: own
// Scaffold, no tab bar.
//
// Re-sequenced 2026-08-27 per docs/redesign/DECISIONS.md R-11 and artboards
// #s03 (name) / #s03b (contact) / #s03p (password) in
// "01 Getting In.dc.html". All three steps live in this one screen/route
// (`Routes.signup`) with internal step state — the canvas's step count
// governs copy/UI, not the route table, so no new routes were needed.
//
// R-11 rulings applied here:
//  - Phone number IS collected (canvas re-introduces it) but there is still
//    no backend field for it (`AuthRepository.signUp` takes
//    {email, password, firstName, middleName?, lastName} only — see
//    Kudimata-Securities-Backend registry.json's AuthSession resource). Per
//    R-11 the field must never silently discard what's typed into it, so
//    it's rendered fully DISABLED (can't be typed into at all) with an
//    explanatory helper, not a live control whose value is thrown away.
//    Gap filed in docs/redesign/BACKEND_GAPS.md; SHARED-CHANGE REQUEST
//    filed in this build's report for `AuthRepository.signUp` to accept an
//    optional `phone` once the backend has somewhere to put it.
//  - Terms acceptance is NOT collected here. The canvas's #s03p draws a
//    pre-OTP "I have read and agree..." checkbox; R-11 says do not adopt
//    it — acceptance stays the dedicated post-OTP screen
//    (terms_and_privacy_screen.dart, reached via Routes.termsOfService
//    right after OTP verification).
//  - Middle name: the canvas's #s03 draws only First/Last name fields (no
//    middle name field anywhere in the name step). Matching the artboard
//    exactly here drops the middle-name box the previous single-step
//    version of this screen had; `AuthRepository.signUp`'s `middleName` stays
//    optional and is simply never sent from this screen now.
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
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  // 0 · name (#s03) · 1 · contact (#s03b) · 2 · password (#s03p). Step 4 of
  // 4 is the separate OTP screen this flow hands off to.
  int _step = 0;

  bool _showErrors = false;
  bool _busy = false;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _upperPattern = RegExp(r'[A-Z]');
  static final _digitPattern = RegExp(r'[0-9]');

  bool get _firstNameValid => _firstName.text.trim().isNotEmpty;
  bool get _lastNameValid => _lastName.text.trim().isNotEmpty;
  bool get _emailValid => _emailPattern.hasMatch(_email.text.trim());

  // Canvas #s03p's live checklist: length + capital/number are real,
  // programmatically-checkable requirements. The third item ("not a
  // password you use elsewhere") is advisory only — nothing in this app can
  // verify that — and the canvas itself renders it permanently unfilled
  // even in its all-green demo screenshot, so it's shown but never ticked
  // (see _PasswordRequirement's `met: null`).
  bool get _passwordLengthOk => _password.text.length >= 10;
  bool get _passwordComplexOk =>
      _upperPattern.hasMatch(_password.text) && _digitPattern.hasMatch(_password.text);
  bool get _passwordValid => _passwordLengthOk && _passwordComplexOk;
  bool get _confirmPasswordValid =>
      _confirmPassword.text.isNotEmpty && _confirmPassword.text == _password.text;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (_step == 0) {
      // Sign-up is reached via context.go (replace, no back stack — see
      // routes.dart's navigation convention note), so there's nothing for
      // KOnboardTopBar's default maybePop() to pop back to.
      context.go(Routes.welcome);
    } else {
      setState(() {
        _showErrors = false;
        _step -= 1;
      });
    }
  }

  void _continueFromName() {
    if (!_firstNameValid || !_lastNameValid) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _showErrors = false;
      _step = 1;
    });
  }

  void _continueFromContact() {
    if (!_emailValid) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _showErrors = false;
      _step = 2;
    });
  }

  Future<void> _createAccount() async {
    if (!_passwordValid || !_confirmPasswordValid) {
      setState(() => _showErrors = true);
      return;
    }
    final firstName = _firstName.text.trim();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KOnboardTopBar(
              stepLabel: 'Step ${_step + 1} of 4',
              onBack: _handleBack,
            ),
            Expanded(
              // Keyed on _step so switching steps fully unmounts the old
              // field subtree instead of Flutter reusing TextField elements
              // by list position across differently-shaped step content —
              // without this, an uncontrolled field (the disabled phone
              // input) inherited the outgoing step's last controlled
              // field's typed text (its TextField's internal fallback
              // controller is seeded from whatever controller/value
              // previously occupied that element slot), found while
              // verifying step 2's screenshot.
              child: KOnboardBody(
                key: ValueKey(_step),
                paddingTop: 18,
                children: switch (_step) {
                  0 => _nameStep(),
                  1 => _contactStep(),
                  _ => _passwordStep(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1 of 4 — #s03 "What's your name?" ────────────────────────────
  List<Widget> _nameStep() {
    return [
      const KScreenHead(
        title: "What's your name?",
        body: 'Use your official names, exactly as they appear on your BVN.',
      ),
      const SizedBox(height: 24),
      KInput(
        label: 'First name (official)',
        placeholder: 'Adebayo',
        helper: 'As it appears on your BVN',
        controller: _firstName,
        onChanged: _showErrors ? (_) => setState(() {}) : null,
        error: _showErrors && !_firstNameValid ? 'Enter your first name' : null,
      ),
      const SizedBox(height: 16),
      KInput(
        label: 'Last name (official)',
        placeholder: 'Okonkwo',
        controller: _lastName,
        onChanged: _showErrors ? (_) => setState(() {}) : null,
        error: _showErrors && !_lastNameValid ? 'Enter your last name' : null,
      ),
      _stepFooter([
        KButton(label: 'Continue', onPressed: _continueFromName),
      ]),
    ];
  }

  // ── Step 2 of 4 — #s03b "How do we reach you?" ────────────────────────
  List<Widget> _contactStep() {
    return [
      const KScreenHead(
        title: 'How do we reach you?',
        body: 'We email your receipts and statements here.',
      ),
      const SizedBox(height: 24),
      KInput(
        label: 'Email',
        placeholder: 'you@email.com',
        keyboardType: TextInputType.emailAddress,
        controller: _email,
        onChanged: _showErrors ? (_) => setState(() {}) : null,
        error: _showErrors && !_emailValid ? 'Enter a valid email address' : null,
      ),
      const SizedBox(height: 16),
      // R-11 / BACKEND_GAPS.md: no backend field exists yet for a sign-up
      // phone number. Rendered fully disabled — not merely styled to look
      // inactive — so nothing typed here can be silently thrown away; there
      // is nothing to type. See file header and the SHARED-CHANGE REQUEST
      // in this build's report.
      const KInput(
        label: 'Phone number',
        prefix: '+234',
        placeholder: '801 234 5678',
        disabled: true,
        helper: "Not collected at sign-up yet — you'll be asked for this during verification",
      ),
      _stepFooter([
        KButton(label: 'Continue', onPressed: _continueFromContact),
      ]),
    ];
  }

  // ── Step 3 of 4 — #s03p "Create a password" ────────────────────────────
  List<Widget> _passwordStep() {
    return [
      const KScreenHead(
        title: 'Create a password',
        body: 'This is what signs you in on any device. The 4-digit passcode '
            'comes later, for quick opening on this phone.',
      ),
      const SizedBox(height: 24),
      KInput(
        label: 'Password',
        obscure: true,
        controller: _password,
        // Live checklist below needs every keystroke, independent of
        // whether a Create-account attempt has surfaced errors yet.
        onChanged: (_) => setState(() {}),
        error: _showErrors && !_passwordValid
            ? 'Use at least 10 characters with a capital letter and a number'
            : null,
      ),
      const SizedBox(height: 16),
      KInput(
        label: 'Repeat password',
        obscure: true,
        controller: _confirmPassword,
        onChanged: (_) => setState(() {}),
        error: _showErrors && !_confirmPasswordValid ? 'Passwords do not match' : null,
      ),
      const SizedBox(height: 16),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PasswordRequirement(label: 'At least 10 characters', met: _passwordLengthOk),
          const SizedBox(height: 9),
          _PasswordRequirement(
              label: 'One capital letter and one number', met: _passwordComplexOk),
          const SizedBox(height: 9),
          const _PasswordRequirement(label: 'Not a password you use elsewhere', met: null),
        ],
      ),
      _stepFooter([
        KButton(
          label: 'Create account',
          loading: _busy,
          onPressed: _busy ? null : _createAccount,
        ),
      ]),
    ];
  }

  // Fixed bottom action block — canvas's `border-top:1px solid hairline`
  // separator between the scrollable fields and the CTA. A fixed gap above
  // it, not Spacer(): KOnboardBody wraps its column in an IntrinsicHeight
  // sized to at least the viewport height, so Spacer() only has room to
  // expand while content is SHORTER than the viewport — on a short phone
  // (or once error/helper lines push content past that point) Spacer
  // collapses to zero and the button lands flush against the field above
  // it (the exact bug this screen shipped with once before).
  Widget _stepFooter(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: KColor.hairline)),
      ),
      child: Column(children: children),
    );
  }
}

/// One row of canvas #s03p's password checklist: a filled/tinted check
/// medallion + label. [met] is null for the one advisory-only requirement
/// ("not a password you use elsewhere") that nothing here can verify — it
/// renders permanently in its neutral/unfilled state, matching the canvas.
class _PasswordRequirement extends StatelessWidget {
  const _PasswordRequirement({required this.label, required this.met});
  final String label;
  final bool? met;

  @override
  Widget build(BuildContext context) {
    final on = met == true;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? KColor.gain.withValues(alpha: 0.12) : KColor.track,
          ),
          child: KIcon('check', size: 11, color: on ? KColor.gain : KColor.ink3),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(label, style: KType.data(color: on ? KColor.ink2 : KColor.ink3)),
        ),
      ],
    );
  }
}
