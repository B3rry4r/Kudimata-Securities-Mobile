// "A few more details" — DOB / residential address / city / state / phone.
// 2026-08-24: this used to run right after biometric.dart, gating Home for
// every fresh sign-up — direct product feedback: "a few more details should
// be part of the KYC and not a separate step after login". Now reached ONLY
// from kyc_intro.dart's `_start()`, the moment an investor actually begins
// verification (checked there, not on the Home path at all) — Continue
// below routes back into kyc_intro, which re-runs its own resume-or-fresh-
// start logic now that this prerequisite is satisfied. Still PATCH
// /users/me, still not a numbered KYC step itself (KYC's own 8 steps still
// start from BVN — see kyc/kyc_intro.dart) — just reached from within that
// flow instead of blocking Home beforehand.
//
// Full name is no longer collected here — sign_up_screen.dart now asks for
// it directly at signup, which is also what fixed Home's "Hi {email}"
// greeting (it now uses the real name).
//
// Reuses the exact DOB date-picker / state-of-residence picker / phone
// country-code picker originally built for the old kyc/personal_details.dart
// screen (_pickers.dart, moved here alongside its only remaining consumer
// now that that screen is deleted) rather than duplicating that picker UI.
//
// A single PATCH /users/me call (UserRepository.updateProfile) persists
// dob/residentialAddress/city/state/phone — no separate submission step,
// unlike the old KYC screen which staged values into KycFormState first.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import '_pickers.dart';

/// Loose E.164 check mirroring the backend's UpdateMeDto validator, same
/// pattern as kyc/personal_details.dart's identical constant (duplicated
/// rather than shared — that file is out of scope to touch, per this
/// codebase's convention of small per-screen helpers over cross-file
/// sharing for things this size).
final RegExp _e164Pattern = RegExp(r'^\+[1-9]\d{7,14}$');

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
    e164 = '+$digits';
  } else if (digits.startsWith('0')) {
    e164 = '+$dialCode${digits.substring(1)}';
  } else {
    e164 = '+$dialCode$digits';
  }
  return _e164Pattern.hasMatch(e164) ? e164 : null;
}

const _kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _formatDobDisplay(DateTime d) => '${d.day} ${_kMonths[d.month - 1]} ${d.year}';

String _formatDobIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class OnboardingPersonalDetailsScreen extends StatefulWidget {
  const OnboardingPersonalDetailsScreen({super.key});

  @override
  State<OnboardingPersonalDetailsScreen> createState() => _OnboardingPersonalDetailsScreenState();
}

class _OnboardingPersonalDetailsScreenState extends State<OnboardingPersonalDetailsScreen> {
  final _addr = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();

  DateTime? _dob;
  String? _residenceState;
  KPhoneCountry _phoneCountry = kDefaultPhoneCountry;

  bool _showErrors = false;
  bool _busy = false;

  @override
  void dispose() {
    _addr.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
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

  Future<void> _continue() async {
    final normalizedPhone = _normalizePhoneToE164(_phone.text, _phoneCountry.dial);
    final valid = _dob != null &&
        _addr.text.trim().isNotEmpty &&
        _city.text.trim().isNotEmpty &&
        _residenceState != null &&
        normalizedPhone != null;
    if (!valid) {
      setState(() => _showErrors = true);
      return;
    }

    setState(() => _busy = true);
    final app = AppScope.read(context);
    final userRepo = UserRepository(app.apiClient);
    try {
      await userRepo.updateProfile(
        dob: _formatDobIso(_dob!),
        residentialAddress: _addr.text.trim(),
        city: _city.text.trim(),
        state: _residenceState!,
        phone: normalizedPhone,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showErrorSheet(context, message: e.message);
      return;
    }
    if (!mounted) return;
    // Onward to the (optional) avatar choice, not straight back into
    // kyc_intro — see avatar_screen.dart's header comment for why that
    // screen is chained here rather than forced right after login.
    context.go(Routes.onboardingAvatar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Canvas #s10 has no top bar at all — no back arrow, no step
            // label; content starts directly under the status bar (found in
            // the 2026-08-23 exactness audit; KOnboardTopBar was an
            // unrequested addition).
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 18, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(
                      title: 'A few more details',
                      body: 'This keeps your account secure and compliant.',
                    ),
                    const SizedBox(height: 20),
                    // Canvas #s10: fields sit directly on --bg with a plain
                    // gap:16px flex column — no card background/border/
                    // padding around the group. The KCard wrapper here was
                    // an unrequested addition (found in the 2026-08-23
                    // exactness audit); removed to match.
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
                    _TappableField(
                        label: 'State',
                        value: _residenceState,
                        placeholder: 'Select your state',
                        onTap: _pickState,
                        error: _showErrors && _residenceState == null
                            ? 'Select your state'
                            : null),
                    const SizedBox(height: 16),
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

void _showErrorSheet(BuildContext context, {required String message}) {
  showKSheet<void>(
    context,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KStatusView(
        tone: KStatusTone.error,
        title: "Couldn't save your details",
        message: message,
        primary: 'Try again',
        onPrimary: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

/// Same styling as kyc/personal_details.dart's file-local `_TappableField` —
/// duplicated rather than shared (lib/widgets/ is frozen; that file's copy
/// is private to its own library).
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

/// Same styling as kyc/personal_details.dart's file-local `_PhoneField` —
/// duplicated for the same reason as `_TappableField` above.
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
