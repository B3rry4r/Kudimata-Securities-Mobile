// Stage 9 — Personal info (pushed). Read-only KInput-style rows: tracked
// UPPERCASE label + tabular value. Mirrors `PersonalInfo` in extra-screens.jsx.
//
// Wired to GET /users/me (UserRepository.personalInfo — firstName/middleName/lastName/email/
// phone/dob/residentialAddress) and GET /kyc-submissions/me
// (KycRepository.me — masked bvn) per lib/data/api/README.md's
// FutureBuilder convention. Both are fetched together with Future.wait so
// the screen shows one loading state instead of two staggered ones; see
// Kudimata-Securities-Backend/.pipeline/fragments/account-personal.json's
// STUB-account-personal-1 for why dob/residentialAddress/bvn used to be
// hardcoded literals interleaved with the two real MockData.user fields.
//
// "Edit details" opens a showKSheet form (full name / phone / residential
// address / city / state — see UserRepository.updateProfile) pre-filled
// with the values already shown above. Saving re-fetches so the screen
// reflects the new values. City/state editing added 2026-08-07
// (supersedes.json S-9): they're normally collected once by the post-signup
// onboarding step (onboarding/personal_details_screen.dart), but that step
// can fail or be skipped (e.g. a phone-number conflict, or the investor
// just closing the app mid-flow) with no way back to it — this screen is
// the only other place in the app that can complete them. dob stays
// deliberately non-editable here ("contact support") — an existing,
// unrelated product decision this change doesn't touch.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import '../onboarding/_pickers.dart';
import 'account_widgets.dart';

/// Loose E.164 check mirroring the backend's UpdateMeDto validator
/// (Kudimata-Securities-Backend src/users/dto/update-me.dto.ts) — same
/// pattern as onboarding/personal_details_screen.dart's
/// `_normalizePhoneToE164`, duplicated here rather than shared since neither
/// file is allowed to grow a shared-utility dependency for this change.
final RegExp _e164Pattern = RegExp(r'^\+[1-9]\d{7,14}$');

/// Normalizes free-typed input to E.164, tolerating a local Nigerian
/// `0803...` format rather than rejecting it. Returns null if the result
/// still isn't a plausible phone number.
String? _normalizePhoneToE164(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final hasPlus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  String e164;
  if (hasPlus) {
    e164 = '+$digits';
  } else if (digits.startsWith('234')) {
    e164 = '+$digits';
  } else if (digits.startsWith('0')) {
    e164 = '+234${digits.substring(1)}';
  } else {
    e164 = '+234$digits';
  }
  return _e164Pattern.hasMatch(e164) ? e164 : null;
}

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);
  late final _kycRepo = KycRepository(AppScope.read(context).apiClient);
  late Future<(PersonalInfo, String)> _future = _load();

  Future<(PersonalInfo, String)> _load() async {
    final infoFuture = _userRepo.personalInfo();
    final bvnFuture = _fetchBvn();
    final info = await infoFuture;
    final bvn = await bvnFuture;
    return (info, bvn);
  }

  /// A 404 here just means this investor hasn't submitted KYC yet — a
  /// perfectly normal state (browsing no longer requires KYC first, see
  /// home_screen.dart's prompt card), not a reason to fail this whole
  /// screen. Mirrors asset_detail_screen.dart's `_fetchHolding` — same
  /// "404 on an optional secondary fetch means 'nothing yet', not an
  /// error" pattern.
  Future<String> _fetchBvn() async {
    try {
      final kyc = await _kycRepo.me();
      return kyc.bvn ?? '—';
    } on ApiException catch (e) {
      if (e.statusCode == 404) return '—';
      rethrow;
    }
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _openEdit(PersonalInfo info) async {
    final saved = await showKSheet<bool>(
      context,
      title: 'Edit details',
      child: _EditPersonalInfoSheet(repo: _userRepo, info: info),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Personal info',
      child: FutureBuilder<(PersonalInfo, String)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const KLoadingView();
          }
          if (snapshot.hasError) {
            return KErrorView(
              onPrimary: _reload,
            );
          }
          final (info, bvn) = snapshot.data!;
          return _PersonalInfoBody(info: info, bvn: bvn, onEdit: () => _openEdit(info));
        },
      ),
    );
  }
}

class _PersonalInfoBody extends StatelessWidget {
  const _PersonalInfoBody({required this.info, required this.bvn, required this.onEdit});

  final PersonalInfo info;
  final String bvn;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('First name', info.firstName),
      if (info.middleName != null && info.middleName!.trim().isNotEmpty)
        ('Middle name', info.middleName!),
      ('Last name', info.lastName),
      ('Date of birth', info.dob),
      ('Email', info.email),
      ('Phone', info.phone),
      ('Residential address', info.residentialAddress),
      ('City', info.city),
      ('State', info.state),
      ('BVN', bvn),
    ];

    // BVN and date of birth are blank for exactly one reason: this investor
    // hasn't submitted KYC yet (BVN comes from the KYC flow itself; DOB from
    // the post-signup onboarding step that leads into it) — never a data
    // bug. Found live 2026-08-19: the screen just showed blank "—" rows with
    // no explanation, which reads as broken. Route straight to the KYC
    // intro instead of the dead-end "contact support" copy, which only
    // makes sense for an investor who HAS already verified and wants to
    // correct one of these otherwise-locked fields.
    final missingKyc = bvn == '—' || info.dob == '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KAccountCard(
          children: [
            for (var i = 0; i < rows.length; i++)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border(
                    top: i == 0
                        ? BorderSide.none
                        : BorderSide(color: KColor.hairline, width: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(rows[i].$1.upper, style: KType.label()),
                    const SizedBox(height: 5),
                    Text(rows[i].$2,
                        style: KType.cardTitle(w: KWeight.medium).tnum),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (missingKyc)
          KAccountCard(
            children: [
              KAccountRow(
                icon: 'profile',
                title: 'Complete your KYC',
                sub: 'Verify your BVN and identity to fill in these details',
                right: const KRowChevron(),
                first: true,
                onTap: () => context.push(Routes.kycIntro),
              ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'To change your date of birth or BVN, contact support.',
              style: KType.body(color: KColor.ink3),
            ),
          ),
        const SizedBox(height: 16),
        // Opens a showKSheet form (full name / phone / residential address)
        // pre-filled with the values above, backed by PATCH /users/me — see
        // _EditPersonalInfoSheet below.
        KButton(label: 'Edit details', onPressed: onEdit),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit-details sheet — full name / phone / residential address, pre-filled
// with the current values. Backed by PATCH /users/me
// (UserRepository.updateProfile). Mirrors bank_accounts_screen.dart's
// _AddBankAccountSheet: FutureBuilder-free simple form, busy/error state,
// pop(true) on success so the caller knows to re-fetch.
// ─────────────────────────────────────────────────────────────────────────────

class _EditPersonalInfoSheet extends StatefulWidget {
  const _EditPersonalInfoSheet({required this.repo, required this.info});

  final UserRepository repo;
  final PersonalInfo info;

  @override
  State<_EditPersonalInfoSheet> createState() => _EditPersonalInfoSheetState();
}

class _EditPersonalInfoSheetState extends State<_EditPersonalInfoSheet> {
  late final _firstName = TextEditingController(text: widget.info.firstName);
  late final _middleName = TextEditingController(text: widget.info.middleName ?? '');
  late final _lastName = TextEditingController(text: widget.info.lastName);
  late final _phone = TextEditingController(text: widget.info.phone);
  // The repository renders a missing value as '—' for display; don't
  // prefill that placeholder into an editable field.
  late final _addr = TextEditingController(
    text: widget.info.residentialAddress == '—' ? '' : widget.info.residentialAddress,
  );
  late final _city = TextEditingController(
    text: widget.info.city == '—' ? '' : widget.info.city,
  );
  late String? _state = widget.info.state == '—' ? null : widget.info.state;

  bool _showErrors = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _addr.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _pickState() async {
    final picked = await showStatePicker(context, selected: _state);
    if (picked != null) setState(() => _state = picked);
  }

  Future<void> _save() async {
    final normalizedPhone = _normalizePhoneToE164(_phone.text);
    final valid = _firstName.text.trim().isNotEmpty &&
        _lastName.text.trim().isNotEmpty &&
        normalizedPhone != null;
    if (!valid) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.updateProfile(
        firstName: _firstName.text.trim(),
        middleName: _middleName.text.trim().isEmpty ? null : _middleName.text.trim(),
        lastName: _lastName.text.trim(),
        phone: normalizedPhone,
        residentialAddress: _addr.text.trim().isEmpty ? null : _addr.text.trim(),
        city: _city.text.trim().isEmpty ? null : _city.text.trim(),
        state: _state,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KInput(
          label: 'First name',
          placeholder: 'Chidi',
          controller: _firstName,
          onChanged: _showErrors ? (_) => setState(() {}) : null,
          error: _showErrors && _firstName.text.trim().isEmpty
              ? 'Enter your first name'
              : null,
        ),
        const SizedBox(height: 16),
        KInput(
          label: 'Middle name (optional)',
          placeholder: 'Emeka',
          controller: _middleName,
        ),
        const SizedBox(height: 16),
        KInput(
          label: 'Last name',
          placeholder: 'Okafor',
          controller: _lastName,
          onChanged: _showErrors ? (_) => setState(() {}) : null,
          error: _showErrors && _lastName.text.trim().isEmpty
              ? 'Enter your last name'
              : null,
        ),
        const SizedBox(height: 16),
        KInput(
          label: 'Phone number',
          placeholder: '+234 801 234 5678',
          keyboardType: TextInputType.phone,
          controller: _phone,
          onChanged: _showErrors ? (_) => setState(() {}) : null,
          error: _showErrors && _normalizePhoneToE164(_phone.text) == null
              ? 'Enter a valid phone number'
              : null,
        ),
        const SizedBox(height: 16),
        KInput(
          label: 'Residential address',
          placeholder: '12 Bourdillon Road',
          controller: _addr,
        ),
        const SizedBox(height: 16),
        KInput(
          label: 'City',
          placeholder: 'Ikeja',
          controller: _city,
        ),
        const SizedBox(height: 16),
        _TappableField(
          label: 'State',
          value: _state,
          placeholder: 'Select your state',
          onTap: _pickState,
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: KType.micro(color: KColor.loss)),
        ],
        const SizedBox(height: 22),
        KButton(
          label: 'Save changes',
          loading: _busy,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }
}

/// Same styling as onboarding/personal_details_screen.dart's file-local
/// `_TappableField` (KInput-styled but read-only/tappable, opens a picker
/// sheet) — duplicated rather than shared per this codebase's convention;
/// lib/widgets/ is frozen so this can't live there.
class _TappableField extends StatelessWidget {
  const _TappableField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              border: Border.all(color: KColor.hairline, width: 1),
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
      ],
    );
  }
}
