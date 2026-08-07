// KYC 2 — personal details (step 1 of 5). Name / DOB / address / city /
// state / phone. Mirrors PersonalDetails. Continue advances the linear flow
// to BVN.
//
// State-of-residence is a fixed 36-state+FCT picker (see _pickers.dart —
// KycSubmission.state's documented contract requires this, not free text),
// styled like a KInput but read-only/tappable (_TappableField below), same
// showKSheet pattern as bank_accounts_screen.dart's bank picker.
//
// Phone is the investor's OWN number — collected nowhere else in the app
// (sign-up only takes email+password; next_of_kin.dart's "Phone number"
// field is for a different person). User.phone is required, non-nullable
// backend-side and defaults to an auto-generated placeholder at signup, so
// this screen also fires a direct PATCH /users/me the moment Continue is
// pressed (UserRepository.updateProfile) — independent of the eventual
// POST /kyc-submissions call on next_of_kin.dart, since phone lives on the
// User record, not KycSubmission, and that endpoint's body has no phone
// field. The phone field now has a real country-code picker (_PhoneField
// below, backed by _pickers.dart's kPhoneCountries) rather than a hardcoded
// +234 prefix — defaults to Nigeria, same as before, but the investor can
// change it.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/api/api_exception.dart';
import 'package:kudimata_securities/data/repositories/user_repository.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import '_kyc_chrome.dart';
import '_pickers.dart';

/// Loose E.164 check mirroring the backend's UpdateMeDto validator (
/// Kudimata-Securities-Backend src/users/dto/update-me.dto.ts):
/// `+` then 8-15 digits, no leading zero after the `+`.
final RegExp _e164Pattern = RegExp(r'^\+[1-9]\d{7,14}$');

/// Normalizes free-typed input to E.164 using the SELECTED country's dial
/// code ([dialCode], without the leading '+'), tolerating the local
/// (`0803...`) format rather than rejecting it outright — better UX than a
/// hard reject, and the backend is documented to tolerate local-format
/// input elsewhere in this system. Returns null if the result still isn't a
/// plausible phone number.
String? _normalizePhoneToE164(String raw, String dialCode) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final hasPlus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  String e164;
  if (hasPlus) {
    e164 = '+$digits';
  } else if (digits.startsWith(dialCode)) {
    // Already carries the selected country's dial code, just missing the '+'.
    e164 = '+$digits';
  } else if (digits.startsWith('0')) {
    // Local format (0803...) — drop the trunk 0, prepend the selected
    // country's dial code.
    e164 = '+$dialCode${digits.substring(1)}';
  } else {
    // Bare local digits.
    e164 = '+$dialCode$digits';
  }
  return _e164Pattern.hasMatch(e164) ? e164 : null;
}

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

/// Month-name formatter for the DOB field's display text ("12 May 1990") —
/// avoided intl just for this since the app has no other date-formatting
/// dependency yet.
const _kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _formatDobDisplay(DateTime d) => '${d.day} ${_kMonths[d.month - 1]} ${d.year}';

/// ISO-8601 date only (no time component), matching KycSubmission.dob's
/// documented wire contract (kyc_form_state.dart).
String _formatDobIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _name = TextEditingController();
  final _addr = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();

  // A real date picker, not free-typed text — was previously a plain KInput
  // with a "DD / MM / YYYY" placeholder the investor had to type by hand
  // (and nothing enforced it matched that format, or was even a real date).
  DateTime? _dob;
  String? _residenceState;
  KPhoneCountry _phoneCountry = kDefaultPhoneCountry;

  bool _showErrors = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _addr.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    // Investing/KYC accounts require the investor to be an adult — the
    // picker's own range enforces that rather than a separate validator.
    final adultCutoff = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? adultCutoff,
      firstDate: DateTime(now.year - 100),
      lastDate: adultCutoff,
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickState() async {
    final picked = await showStatePicker(context, selected: _residenceState);
    if (picked != null) setState(() => _residenceState = picked);
  }

  Future<void> _pickCountryCode() async {
    final picked = await showCountryCodePicker(context, selected: _phoneCountry);
    if (picked != null) setState(() => _phoneCountry = picked);
  }

  // Basic non-empty validation (matches the flow's no-live-validation
  // pattern — errors only surface after Continue is pressed). Phone also
  // has to normalize to a plausible E.164 number, since it's sent straight
  // to PATCH /users/me below.
  Future<void> _continue() async {
    final normalizedPhone = _normalizePhoneToE164(_phone.text, _phoneCountry.dial);
    final valid = _name.text.trim().isNotEmpty &&
        _dob != null &&
        _addr.text.trim().isNotEmpty &&
        _city.text.trim().isNotEmpty &&
        _residenceState != null &&
        normalizedPhone != null;
    if (!valid) {
      setState(() => _showErrors = true);
      return;
    }
    final app = AppScope.read(context);
    final kycForm = app.kycForm;
    kycForm.setName(_name.text.trim());
    kycForm.setDob(_formatDobIso(_dob!));
    kycForm.setAddress(_addr.text.trim());
    kycForm.setCity(_city.text.trim());
    kycForm.setResidenceState(_residenceState!);

    setState(() => _busy = true);
    final userRepo = UserRepository(app.apiClient);
    try {
      await userRepo.updateProfile(phone: normalizedPhone);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showPhoneErrorSheet(context, message: e.message);
      return;
    }
    if (!mounted) return;
    context.go(Routes.kycBvn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KycTopBar(),
            const KycStepProgress(current: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(title: 'Your details'),
                    const SizedBox(height: 20),
                    KCard(
                      child: Column(
                        children: [
                          KInput(
                              label: 'Full name',
                              placeholder: 'Chidi Okafor',
                              controller: _name,
                              onChanged: _showErrors ? (_) => setState(() {}) : null,
                              error: _showErrors && _name.text.trim().isEmpty
                                  ? 'Enter your full name'
                                  : null),
                          const SizedBox(height: 16),
                          _TappableField(
                              label: 'Date of birth',
                              value: _dob != null ? _formatDobDisplay(_dob!) : null,
                              placeholder: 'Select your date of birth',
                              onTap: _pickDob,
                              error: _showErrors && _dob == null
                                  ? 'Enter your date of birth'
                                  : null),
                          const SizedBox(height: 16),
                          KInput(
                              label: 'Residential address',
                              placeholder: '12 Bourdillon Road',
                              controller: _addr,
                              onChanged: _showErrors ? (_) => setState(() {}) : null,
                              error: _showErrors && _addr.text.trim().isEmpty
                                  ? 'Enter your residential address'
                                  : null),
                          const SizedBox(height: 16),
                          KInput(
                              label: 'City',
                              placeholder: 'Ikeja',
                              controller: _city,
                              onChanged: _showErrors ? (_) => setState(() {}) : null,
                              error: _showErrors && _city.text.trim().isEmpty
                                  ? 'Enter your city'
                                  : null),
                          const SizedBox(height: 16),
                          // Fixed 36-state+FCT picker — see _pickers.dart's
                          // showStatePicker. Styled like KInput but
                          // read-only/tappable, not free text.
                          _TappableField(
                              label: 'State',
                              value: _residenceState,
                              placeholder: 'Select your state',
                              onTap: _pickState,
                              error: _showErrors && _residenceState == null
                                  ? 'Select your state'
                                  : null),
                          const SizedBox(height: 16),
                          // The investor's OWN phone number — distinct from
                          // next_of_kin.dart's "Phone number" field, which
                          // belongs to a different person entirely. Country
                          // code is a real tappable picker (_pickers.dart's
                          // showCountryCodePicker), defaulting to Nigeria.
                          _PhoneField(
                              controller: _phone,
                              country: _phoneCountry,
                              onCountryTap: _pickCountryCode,
                              onChanged: _showErrors ? (_) => setState(() {}) : null,
                              error: _showErrors &&
                                      _normalizePhoneToE164(
                                              _phone.text, _phoneCountry.dial) ==
                                          null
                                  ? 'Enter a valid phone number'
                                  : null),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
              child: KButton(
                label: 'Continue',
                loading: _busy,
                onPressed: _busy ? null : _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the PATCH /users/me phone update fails with an
/// [ApiException] — [message] is that exception's human-readable summary
/// (safe to show directly, per lib/data/api/api_exception.dart). The form's
/// entered values stay intact so the investor can retry without re-typing
/// anything. Mirrors next_of_kin.dart's `_showErrorSheet`, duplicated here
/// (rather than shared) since that file is out of scope to touch.
void _showPhoneErrorSheet(BuildContext context, {required String message}) {
  showKSheet<void>(
    context,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KStatusView(
        tone: KStatusTone.error,
        title: 'Couldn\'t save phone number',
        message: message,
        primary: 'Try again',
        onPrimary: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

/// A field styled exactly like [KInput] (same label/box/error tokens —
/// height 50, KRadii.input, hairline/loss border) but read-only and
/// tappable, opening a picker sheet instead of the keyboard. lib/widgets/
/// is frozen so this can't be added to KInput itself as a `readOnly` mode;
/// kept file-local here since only this screen's State field needs it.
class _TappableField extends StatelessWidget {
  const _TappableField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.error,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final borderColor = error != null ? KColor.loss : KColor.hairline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.upper, style: KType.label(color: KColor.ink2)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: KColor.paper,
              borderRadius: BorderRadius.circular(KRadii.input),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? placeholder,
                    style: KType.body(color: value != null ? KColor.ink : KColor.ink3),
                  ),
                ),
                const SizedBox(width: 10),
                KIcon('arrowDown', size: 16, color: KColor.ink3),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 7),
          Text(error!, style: KType.micro(color: KColor.loss).copyWith(letterSpacing: 0.02 * 10)),
        ],
      ],
    );
  }
}

/// The phone field: a tappable country-code chip (flag + dial code, opens
/// [showCountryCodePicker]) beside a plain number entry — replaces the old
/// fixed `+234` [KInput.prefix]. Composed from the same tokens KInput uses
/// (height 50, KRadii.input, hairline/ink/loss border, KType styles) rather
/// than reusing KInput itself, since KInput has no slot for a tappable
/// leading widget (only a static prefix Text) — see file header for why
/// this can't just live in lib/widgets/ (frozen).
class _PhoneField extends StatefulWidget {
  const _PhoneField({
    required this.controller,
    required this.country,
    required this.onCountryTap,
    this.onChanged,
    this.error,
  });

  final TextEditingController controller;
  final KPhoneCountry country;
  final VoidCallback onCountryTap;
  final ValueChanged<String>? onChanged;
  final String? error;

  @override
  State<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<_PhoneField> {
  late final FocusNode _focus = FocusNode()..addListener(() => setState(() {}));

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final borderColor = widget.error != null
        ? KColor.loss
        : focused
            ? KColor.ink
            : KColor.hairline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Phone number'.upper, style: KType.label(color: KColor.ink2)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: widget.onCountryTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: KColor.paper,
                  borderRadius: BorderRadius.circular(KRadii.input),
                  border: Border.all(color: KColor.hairline, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.country.flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(widget.country.dialLabel,
                        style: KType.body(color: KColor.ink2, w: KWeight.medium).tnum),
                    const SizedBox(width: 6),
                    KIcon('arrowDown', size: 14, color: KColor.ink3),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: KColor.paper,
                  borderRadius: BorderRadius.circular(KRadii.input),
                  border: Border.all(color: borderColor, width: 1),
                ),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  onChanged: widget.onChanged,
                  keyboardType: TextInputType.phone,
                  cursorColor: KColor.indicator,
                  cursorWidth: 1.5,
                  style: KType.body(color: KColor.ink, w: KWeight.medium).copyWith(
                    letterSpacing: -0.14,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '801 234 5678',
                    hintStyle: KType.body(color: KColor.ink3),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 7),
          Text(widget.error!,
              style: KType.micro(color: KColor.loss).copyWith(letterSpacing: 0.02 * 10)),
        ],
      ],
    );
  }
}
