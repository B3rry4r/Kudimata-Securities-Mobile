// Stage 9 — Personal info (pushed). Read-only label:value rows (Full name /
// Date of birth / BVN · NIN / CHN / Account status), then real editable
// Phone number / Residential address fields inline on the page (matching
// the canvas's #s49 body exactly — 2026-08-23 exactness pass), then the
// Investor profile card, then a "Save changes" button. Mirrors `PersonalInfo`
// in extra-screens.jsx.
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
// Full name is deliberately NOT editable anywhere on this screen — the
// canvas's read-only card has no edit affordance on that row, and its own
// footer note says "a legal-name change opens support at 56" (Help &
// support). A prior version of this screen let a name change ride along
// inside a generic "Edit details" sheet; that's now gone (2026-08-23
// exactness pass) — legal-name changes belong to support, not self-serve.
//
// City/state editing (added 2026-08-07, supersedes.json S-9) stays as a
// secondary "Add city & state" link, shown only while either is missing:
// they're normally collected once by the post-signup onboarding step
// (onboarding/personal_details_screen.dart), but that step can fail or be
// skipped (e.g. a phone-number conflict, or the investor just closing the
// app mid-flow) with no way back to it — this screen is the only other
// place in the app that can complete them. Kept out of the canvas's own two
// inline fields (Phone number / Residential address) so this screen still
// reads as the design intends when both are already set. dob stays
// deliberately non-editable here ("contact support") — an existing,
// unrelated product decision this change doesn't touch.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/data/repositories/suitability_repository.dart';
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

/// Strips a leading country code so the field shows just the local number
/// next to the KInput `prefix: '+234'` — matching the canvas's
/// `prefix="+234" value="801 234 5678"` split (2026-08-23 exactness pass;
/// the prior version showed the full E.164 string in one plain field).
String _localPhone(String raw) {
  final trimmed = raw.trim();
  if (trimmed.startsWith('+234')) return trimmed.substring(4).trim();
  if (trimmed.startsWith('234')) return trimmed.substring(3).trim();
  return trimmed;
}

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);
  late final _kycRepo = KycRepository(AppScope.read(context).apiClient);
  late final _suitabilityRepo = SuitabilityRepository(AppScope.read(context).apiClient);
  late Future<(PersonalInfo, String, String?)> _future = _load();

  Future<(PersonalInfo, String, String?)> _load() async {
    final infoFuture = _userRepo.personalInfo();
    final bvnFuture = _fetchBvn();
    final profileFuture = _fetchSuitabilityProfile();
    final info = await infoFuture;
    final bvn = await bvnFuture;
    final profile = await profileFuture;
    return (info, bvn, profile);
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

  /// Null means "hasn't taken the questionnaire yet" (also a normal state —
  /// suitability is optional, see app_state.dart's tradingEligibilityGap),
  /// same 404-is-not-an-error pattern as [_fetchBvn].
  Future<String?> _fetchSuitabilityProfile() async {
    try {
      final result = await _suitabilityRepo.me();
      return result.profile.isEmpty ? null : result.profile;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Personal info',
      child: FutureBuilder<(PersonalInfo, String, String?)>(
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
          final (info, bvn, profile) = snapshot.data!;
          return _PersonalInfoBody(
            key: ValueKey(info.phone + info.residentialAddress + info.city + (info.state)),
            info: info,
            bvn: bvn,
            profile: profile,
            repo: _userRepo,
            onSaved: _reload,
          );
        },
      ),
    );
  }
}

class _PersonalInfoBody extends StatefulWidget {
  const _PersonalInfoBody({
    super.key,
    required this.info,
    required this.bvn,
    required this.profile,
    required this.repo,
    required this.onSaved,
  });

  final PersonalInfo info;
  final String bvn;
  final String? profile;
  final UserRepository repo;
  final VoidCallback onSaved;

  @override
  State<_PersonalInfoBody> createState() => _PersonalInfoBodyState();
}

class _PersonalInfoBodyState extends State<_PersonalInfoBody> {
  late final _phone = TextEditingController(text: _localPhone(widget.info.phone));
  late final _addr = TextEditingController(
    text: widget.info.residentialAddress == '—' ? '' : widget.info.residentialAddress,
  );

  bool _showErrors = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _addr.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final normalizedPhone = _normalizePhoneToE164(_phone.text);
    if (normalizedPhone == null) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.updateProfile(
        phone: normalizedPhone,
        residentialAddress: _addr.text.trim().isEmpty ? null : _addr.text.trim(),
      );
      widget.onSaved();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  Future<void> _addCityState() async {
    final saved = await showKSheet<bool>(
      context,
      title: 'City & state',
      child: _CityStateSheet(repo: widget.repo, info: widget.info),
    );
    if (saved == true) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final bvn = widget.bvn;
    final profile = widget.profile;

    // Re-verified against the canvas's real s49.html (2026-08-23 exactness
    // pass): the read-only card's rows are Full name / Date of birth /
    // BVN · NIN / CHN / Account status — a coarser, more privacy-conscious
    // set than the raw field-by-field dump this screen used to show
    // (separate first/middle/last/city/state rows, and the literal BVN
    // value rather than a verified/not-verified status).
    final verified = bvn != '—';
    final rows = <(String, String, bool tabular)>[
      ('Full name', info.fullName, false),
      ('Date of birth', info.dob, false),
      ('BVN · NIN', verified ? 'Verified' : 'Not verified', true),
      ('CHN', info.cscsNumber, true),
      (
        'Account status',
        info.accountStatus.isEmpty
            ? '—'
            : info.accountStatus[0].toUpperCase() + info.accountStatus.substring(1),
        false,
      ),
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
    final missingCityState = info.city == '—' || info.state == '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Read-only rows — a plain label:value line per row (`text-data`
        // both sides, ink-2 label / ink value), not the label-above-value
        // stacked/uppercase-caption layout this screen used to render
        // (2026-08-23 exactness pass — that stacked treatment belongs to a
        // different part of the design system, not this card).
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
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(rows[i].$1, style: KType.data(color: KColor.ink2)),
                    ),
                    Text(
                      rows[i].$2,
                      style: rows[i].$3 ? KType.data().tnum : KType.data(),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (missingKyc)
          KAccountCard(
            children: [
              KAccountRow(
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
        const SizedBox(height: 14),
        Text('You can change these'.upper, style: KType.label()),
        const SizedBox(height: 14),
        // Editable fields per the canvas: Phone number, Residential
        // address. "Employment status" (canvas's third field, a Select) is
        // skipped — no such field exists anywhere in the backend's User
        // model (checked UpdateMeDto and the User type interface), so there
        // is nothing real to collect or display for it yet.
        KInput(
          label: 'Phone number',
          prefix: '+234',
          numeric: true,
          controller: _phone,
          onChanged: _showErrors ? (_) => setState(() {}) : null,
          error: _showErrors && _normalizePhoneToE164(_phone.text) == null
              ? 'Enter a valid phone number'
              : null,
        ),
        const SizedBox(height: 14),
        KInput(
          label: 'Residential address',
          controller: _addr,
        ),
        if (missingCityState) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _addCityState,
            behavior: HitTestBehavior.opaque,
            child: Text('Add city & state', style: KType.data(color: KColor.indicator)),
          ),
        ],
        const SizedBox(height: 14),
        // "Investor profile · {profile}" flat card with a "Retake" link
        // (canvas nav note: "Retake -> 27", the suitability questionnaire).
        // The canvas's "Answered 14 Mar 2026" subtitle isn't shown: the real
        // SuitabilityResult model (suitability_repository.dart) doesn't
        // carry a computedAt/answered-date field to this client yet, and
        // that repository is out of this screen's file scope this pass —
        // fabricating a date would be worse than omitting it.
        KCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  profile == null ? 'Investor profile' : 'Investor profile · $profile',
                  style: KType.cardTitle(),
                ),
              ),
              GestureDetector(
                onTap: () => context.push(Routes.questionnaire),
                behavior: HitTestBehavior.opaque,
                child: Text('Retake', style: KType.data(color: KColor.indicator)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(_error!, style: KType.micro(color: KColor.loss)),
          const SizedBox(height: 10),
        ],
        KButton(
          label: 'Save changes',
          loading: _busy,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }
}

/// Secondary sheet for the city/state completion gap (see this file's
/// header comment) — kept out of the main inline form so the screen still
/// matches the canvas exactly once both are already set.
class _CityStateSheet extends StatefulWidget {
  const _CityStateSheet({required this.repo, required this.info});

  final UserRepository repo;
  final PersonalInfo info;

  @override
  State<_CityStateSheet> createState() => _CityStateSheetState();
}

class _CityStateSheetState extends State<_CityStateSheet> {
  late final _city = TextEditingController(
    text: widget.info.city == '—' ? '' : widget.info.city,
  );
  late String? _state = widget.info.state == '—' ? null : widget.info.state;

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _pickState() async {
    final picked = await showStatePicker(context, selected: _state);
    if (picked != null) setState(() => _state = picked);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.updateProfile(
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
          label: 'Save',
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
