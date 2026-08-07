// Stage 9 — Personal info (pushed). Read-only KInput-style rows: tracked
// UPPERCASE label + tabular value. Mirrors `PersonalInfo` in extra-screens.jsx.
//
// Wired to GET /users/me (UserRepository.personalInfo — fullName/email/
// phone/dob/residentialAddress) and GET /kyc-submissions/me
// (KycRepository.me — masked bvn) per lib/data/api/README.md's
// FutureBuilder convention. Both are fetched together with Future.wait so
// the screen shows one loading state instead of two staggered ones; see
// Kudimata-Securities-Backend/.pipeline/fragments/account-personal.json's
// STUB-account-personal-1 for why dob/residentialAddress/bvn used to be
// hardcoded literals interleaved with the two real MockData.user fields.
//
// "Edit details" opens a showKSheet form (full name / phone / residential
// address, the three fields PATCH /users/me accepts — see
// UserRepository.updateProfile) pre-filled with the values already shown
// above. Saving re-fetches so the screen reflects the new values.
import 'package:flutter/material.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/api/api_exception.dart';
import 'package:kudimata_securities/data/repositories/kyc_repository.dart';
import 'package:kudimata_securities/data/repositories/user_repository.dart';
import 'package:kudimata_securities/screens/shared/state_views.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
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
      ('Full name', info.fullName),
      ('Date of birth', info.dob),
      ('Email', info.email),
      ('Phone', info.phone),
      ('Residential address', info.residentialAddress),
      ('BVN', bvn),
    ];

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
  late final _name = TextEditingController(text: widget.info.fullName);
  late final _phone = TextEditingController(text: widget.info.phone);
  // The repository renders a missing address as '—' for display; don't
  // prefill that placeholder into an editable field.
  late final _addr = TextEditingController(
    text: widget.info.residentialAddress == '—' ? '' : widget.info.residentialAddress,
  );

  bool _showErrors = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _addr.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final normalizedPhone = _normalizePhoneToE164(_phone.text);
    final valid = _name.text.trim().isNotEmpty && normalizedPhone != null;
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
        fullName: _name.text.trim(),
        phone: normalizedPhone,
        residentialAddress: _addr.text.trim().isEmpty ? null : _addr.text.trim(),
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
          label: 'Full name',
          placeholder: 'Chidi Okafor',
          controller: _name,
          onChanged: _showErrors ? (_) => setState(() {}) : null,
          error:
              _showErrors && _name.text.trim().isEmpty ? 'Enter your full name' : null,
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
