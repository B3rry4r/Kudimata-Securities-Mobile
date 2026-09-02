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
//  - Phone number IS collected (canvas re-introduces it). The backend gained
//    an optional `phone` on POST /auth/signup 2026-08-27 (BR-3); the field
//    below went live (SHARED-CHANGES.md S-2, applied 2026-08-28) — see
//    `AuthRepository.signUp`'s doc comment for the wire shape and error
//    codes. Made REQUIRED 2026-09-01 (product-owner ruling, both sides):
//    the field now renders with the same red-asterisk `required` marker as
//    Email (`KPhoneNumberField.required`), Continue on this step
//    (`_continueFromContact`) refuses to advance while it's empty, and the
//    backend's `SignupDto.phone` is non-optional too
//    (Kudimata-Securities-Backend src/auth/dto/signup.dto.ts). Still no
//    client-side *format* check beyond "not empty" — an unparseable value
//    still reaches the server, which is the one place that validates and
//    returns INVALID_PHONE (see `_phoneError` below), same contract as
//    before this change.
//  - Terms acceptance: R-11 originally kept this off the password step,
//    since acceptance lived on a dedicated post-OTP screen
//    (terms_and_privacy_screen.dart). That screen — and the standalone
//    legal-acceptance chain generally — is gone (R-51, DECISIONS.md,
//    2026-08-31: "remove the assessment and also remove the risk
//    disclosure too... add [a checkbox] on the last screen that creates
//    the account"). This step (`_passwordStep`, the one that actually
//    calls `_createAccount`) is now that last screen: it carries the
//    checkbox R-11 used to defer, gating account creation on it directly.
//  - Middle name: the canvas's #s03 draws only First/Last name fields (no
//    middle name field anywhere in the name step). 2026-08-30 (product
//    owner, via colleague dogfooding): re-added anyway — a deliberate
//    product addition on top of the design, not a conformance fix, since
//    the backend has always accepted it (`SignupDto.middleName?`) and
//    investors with one had no way to give it at signup. Styled to match
//    the First/Last fields around it (same KInput, same "(official)"-less
//    plain label, no helper) rather than inventing a new look. It is
//    genuinely optional: absent from `_firstNameValid`/`_lastNameValid`'s
//    gate on Continue (see below), and `AuthRepository.signUp` already
//    omits the key entirely when empty rather than sending `""` — the
//    backend's `@IsString()` with no `@MinLength` would actually accept an
//    empty string too, but omitting is the honest "wasn't given" shape and
//    matches how `phone` is already handled two lines below it.
//
// R-43 (docs/redesign/DECISIONS.md, product-owner ruling, 2026-08-29)
// OVERRIDES the canvas's password rule: #s03p/#s03pd draw "At least 10
// characters" / "One capital letter and one number" / "Not a password you
// use elsewhere", but the recorded ruling is 8+ characters, a number AND a
// special character, no capital-letter requirement, and the "not a
// password you use elsewhere" advisory line removed entirely. Implemented
// below (see `_passwordLengthOk`/`_passwordComplexOk` and `_passwordStep`)
// rather than matching the canvas, per that ruling's own instruction that
// it outranks the canvas here. The equivalent, previously-decorative,
// server-side rule is now real too — see
// Kudimata-Securities-Backend/src/common/password-policy.ts.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/password_policy.dart';
import 'package:kudimata_invest/data/repositories/auth_repository.dart';
import 'package:kudimata_invest/k_links.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import '_pickers.dart';
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
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  // 0 · name (#s03) · 1 · contact (#s03b) · 2 · password (#s03p). Step 4 of
  // 4 is the separate OTP screen this flow hands off to.
  int _step = 0;

  // Country for the phone field, picked via showCountryCodePicker
  // (_pickers.dart) — defaults to Nigeria, same default as
  // personal_details_screen.dart. 2026-08-29: replaces a hardcoded '+234'
  // prefix that offered no way to pick anything else (product feedback:
  // "phone number on the create account is meant to populate the country
  // codes not just default 234 ... just like it was done on the removed
  // few more details screen").
  KPhoneCountry _phoneCountry = kDefaultPhoneCountry;

  bool _showErrors = false;
  bool _busy = false;

  // The one consent record left after R-51 (DECISIONS.md, 2026-08-31)
  // removed the standalone legal/terms-acceptance screen, the risk-
  // disclosure step and the suitability assessment: an unticked checkbox on
  // this, the screen that actually creates the account, genuinely gates
  // account creation — see _createAccount below. No AppState flag records
  // this (there's nowhere left to read it downstream), same as any other
  // plain form-validation bool on this screen.
  bool _agreedToTerms = false;

  // Set only from a 400 INVALID_PHONE / 409 PHONE_ALREADY_REGISTERED
  // response to _createAccount (see there) — server-side errors surfaced
  // back onto the field they're actually about, on the step that field
  // lives on, rather than a generic snackbar the investor can't act on.
  String? _phoneError;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _digitPattern = RegExp(r'[0-9]');

  // Same explicit ASCII special-character class the backend's
  // @IsStrongPassword() uses (Kudimata-Securities-Backend
  // src/common/password-policy.ts) — the traditional printable
  // punctuation/symbol set plus a literal space. Deliberately not "not
  // alphanumeric": that function's own doc comment explains why a
  // non-ASCII symbol or emoji doesn't count (no confirmed guarantee every
  // hop — an SMTP reset email body, bcrypt's 72-byte truncation, a future
  // gateway — round-trips arbitrary Unicode). Keeping the two patterns
  // textually identical is deliberate; if one changes, so must the other.
  static final _specialPattern = RegExp(r'''[ !"#$%&'()*+,\-./:;<=>?@[\]^_`{|}~]''');

  bool get _firstNameValid => _firstName.text.trim().isNotEmpty;
  bool get _lastNameValid => _lastName.text.trim().isNotEmpty;
  // Deliberately no _middleNameValid: the field is optional and must never
  // enter the chain that gates Continue (product owner: "watch out
  // validation should not be blocked please!").
  bool get _emailValid => _emailPattern.hasMatch(_email.text.trim());
  // Required 2026-09-01 (product-owner ruling) — same "not empty" bar as
  // the neighbouring required fields on this step; format is still
  // validated only server-side (see file header and `_phoneError`).
  bool get _phoneValid => _phone.text.trim().isNotEmpty;

  // R-43 (docs/redesign/DECISIONS.md, product-owner ruling, 2026-08-29):
  // 8+ characters, a number AND a special character — both real,
  // programmatically-checkable requirements, matched server-side by
  // @IsStrongPassword() so this checklist is no longer decorative. The
  // capital-letter requirement is dropped, and the old third checklist
  // line ("not a password you use elsewhere") — which nothing in this app
  // could ever verify, and which the canvas itself rendered permanently
  // unfilled — is removed entirely rather than kept as dead UI.
  // Both from lib/data/password_policy.dart — the one definition R-43 lives
  // in, shared with the reset-password screen and mirrored by the backend.
  bool get _passwordLengthOk => passwordLongEnough(_password.text);
  bool get _passwordComplexOk =>
      _digitPattern.hasMatch(_password.text) && _specialPattern.hasMatch(_password.text);
  bool get _passwordValid => _passwordLengthOk && _passwordComplexOk;
  bool get _confirmPasswordValid =>
      _confirmPassword.text.isNotEmpty && _confirmPassword.text == _password.text;

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
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
    if (!_emailValid || !_phoneValid) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _showErrors = false;
      _step = 2;
    });
  }

  Future<void> _pickCountryCode() async {
    final picked = await showCountryCodePicker(context, selected: _phoneCountry);
    if (picked != null) setState(() => _phoneCountry = picked);
  }

  Future<void> _createAccount() async {
    if (!_passwordValid || !_confirmPasswordValid || !_agreedToTerms) {
      setState(() => _showErrors = true);
      return;
    }
    final firstName = _firstName.text.trim();
    // Empty stays '' here and is turned into "don't send the key at all"
    // by AuthRepository.signUp (`middleName.isNotEmpty` check) — not sent
    // as an empty string. See this file's header note on why that split
    // matters even though the backend's own validator would tolerate "".
    final middleName = _middleName.text.trim();
    final lastName = _lastName.text.trim();
    final email = _email.text.trim();
    // Contract (backend Kudimata-Securities-Backend src/common/phone.ts,
    // extended 2026-08-29): the client always sends full E.164 — '+' plus
    // the picked country's dial code plus whatever was typed — now that
    // the field isn't hardcoded to Nigeria. composePhoneE164 (_pickers.dart)
    // does the prefixing without judging the result, matching this field's
    // existing "no client-side format check" contract (see the phone
    // KPhoneNumberField's comment above): an unparseable value still
    // reaches the server, which is the one place that validates and
    // returns INVALID_PHONE. Guaranteed non-empty by the time we get here —
    // `_continueFromContact` (required 2026-09-01) already refused to leave
    // step 2 with an empty phone field.
    final phone = composePhoneE164(_phone.text, _phoneCountry.dial);
    final password = _password.text.trim();
    setState(() => _busy = true);
    final repo = AuthRepository(AppScope.read(context).apiClient);
    try {
      await repo.signUp(
        email: email,
        password: password,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        phone: phone,
      );
      if (!mounted) return;
      context.go(Routes.otp, extra: email);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'PHONE_ALREADY_REGISTERED' || e.code == 'INVALID_PHONE') {
        // The field the error is actually about lives on step 2 (#s03b),
        // not the password step (#s03p) this attempt was submitted from —
        // send the investor back to it with the error attached, rather than
        // a snackbar pointing at a field they can no longer see.
        setState(() {
          _busy = false;
          _step = 1;
          // Country-aware (2026-08-29): this used to hardcode "...Nigerian
          // phone number...", which would have been wrong the moment an
          // investor picked anything other than Nigeria from the country
          // picker below. Nigeria keeps its specific example format;
          // every other country gets a generic message naming it, since
          // this codebase has no per-country example-format table.
          _phoneError = e.code == 'PHONE_ALREADY_REGISTERED'
              ? 'That number is already registered to another account.'
              : _phoneCountry.iso2 == 'NG'
                  ? 'Enter a valid Nigerian phone number, e.g. 0803 123 4567.'
                  : 'Enter a valid phone number for ${_phoneCountry.name}.';
        });
        return;
      }
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.displayMessage)),
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
        required: true,
      ),
      const SizedBox(height: 16),
      // Optional (product addition, 2026-08-30 — see file header): not in
      // `_firstNameValid`/`_lastNameValid`'s Continue-gating chain, no
      // error prop wired at all, so `_showErrors` can never touch it.
      KInput(
        label: 'Middle name (optional)',
        placeholder: 'Chinedu',
        controller: _middleName,
      ),
      const SizedBox(height: 16),
      KInput(
        label: 'Last name (official)',
        placeholder: 'Okonkwo',
        controller: _lastName,
        onChanged: _showErrors ? (_) => setState(() {}) : null,
        error: _showErrors && !_lastNameValid ? 'Enter your last name' : null,
        required: true,
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
        required: true,
      ),
      const SizedBox(height: 16),
      // Live per SHARED-CHANGES.md S-2 — the backend gained a `phone` on
      // POST /auth/signup (BR-3), made required 2026-09-01 (see file
      // header). Required here too, via the same `required`/error wiring
      // as Email above (`_phoneValid`, `_continueFromContact`) — still no
      // client-side *format* check (see file header for why).
      //
      // 2026-08-29: this used to be a KInput with a hardcoded `prefix:
      // '+234'` — every investor who wasn't Nigerian either lied about
      // their country code or couldn't sign up with their real number.
      // Replaced with the same country-code picker + dataset
      // personal_details_screen.dart already used (KPhoneNumberField,
      // _pickers.dart's 186-country kPhoneCountries, Nigeria first/default)
      // rather than forking a second copy of that field. The server's own
      // normalizePhone() (Kudimata-Securities-Backend src/common/phone.ts)
      // now accepts full E.164 for any country when a leading '+' is
      // present (the shape composePhoneE164 below always produces), and
      // still separately accepts bare Nigerian local formats
      // ('0803…'/'803…'/'234803…') with no leading '+' for callers that
      // never send explicit country context — a 400 INVALID_PHONE / 409
      // PHONE_ALREADY_REGISTERED response is surfaced onto this field by
      // _createAccount instead of validated here.
      KPhoneNumberField(
        controller: _phone,
        country: _phoneCountry,
        onCountryTap: _pickCountryCode,
        // BVN is Nigeria-specific — this helper only makes a promise this
        // field can actually keep when Nigeria is the picked country.
        helper: _phoneError == null && _phoneCountry.iso2 == 'NG'
            ? 'Use the line registered to your BVN'
            : null,
        // Server error (400 INVALID_PHONE / 409 PHONE_ALREADY_REGISTERED,
        // set by _createAccount) takes priority when present; otherwise the
        // same required-field pattern as Email above.
        error: _phoneError ?? (_showErrors && !_phoneValid ? 'Enter your phone number' : null),
        required: true,
        onChanged: (_) {
          if (_phoneError != null || _showErrors) {
            setState(() => _phoneError = null);
          }
        },
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
        // R-43 (2026-08-29): was "Use at least 10 characters with a
        // capital letter and a number" — updated to match the ruling below
        // _passwordValid now actually checks.
        error: _showErrors && !_passwordValid
            ? 'Use at least 8 characters with a number and a special character'
            : null,
        required: true,
      ),
      const SizedBox(height: 16),
      KInput(
        label: 'Repeat password',
        obscure: true,
        controller: _confirmPassword,
        onChanged: (_) => setState(() {}),
        error: _showErrors && !_confirmPasswordValid ? 'Passwords do not match' : null,
        required: true,
      ),
      const SizedBox(height: 16),
      // R-43 (2026-08-29): exactly two lines now — the third
      // ("Not a password you use elsewhere") is removed entirely rather
      // than kept as an always-neutral, never-checkable row. See
      // _PasswordRequirement below: its `met` is a plain bool now that
      // nothing renders the old null/advisory state.
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PasswordRequirement(label: 'At least 8 characters', met: _passwordLengthOk),
          const SizedBox(height: 9),
          _PasswordRequirement(
              label: 'One number and one special character', met: _passwordComplexOk),
        ],
      ),
      const SizedBox(height: 18),
      // The one consent record left after R-51 (DECISIONS.md) removed the
      // standalone legal screen — see _agreedToTerms' own doc comment.
      // Standard pattern: unticked by default, opens the real legal page
      // (KLinks.legal) rather than an in-app screen.
      KLinkedCheckbox(
        checked: _agreedToTerms,
        onChanged: (v) => setState(() => _agreedToTerms = v),
        prefixText: 'I acknowledge that I have read and agree to',
        linkText: 'Terms and Conditions',
        url: KLinks.legal,
      ),
      if (_showErrors && !_agreedToTerms) ...[
        const SizedBox(height: 8),
        Text(
          'Agree to the Terms and Conditions to create your account',
          style: KType.data(color: KColor.loss),
        ),
      ],
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

/// One row of the password checklist: a filled/tinted check medallion +
/// label. Both rows are real, programmatically-checkable requirements as
/// of R-43 (2026-08-29) — [met] was nullable to render a third,
/// permanently-unfilled advisory row ("not a password you use elsewhere")
/// that R-43 removed outright, so there is no longer a state this can be
/// in besides met/not-met.
class _PasswordRequirement extends StatelessWidget {
  const _PasswordRequirement({required this.label, required this.met});
  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final on = met;
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
