// KYC 7 of 7 — next of kin (2026-08-24 re-sequencing: was step 5 of 5/final;
// renumbered 8->7 (was 8 of 8) 2026-08-27 per X-2/bvn_nin.dart's derivation).
// Name / relationship / phone.
//
// D-1 (SHARED-CHANGES.md, 2026-08-27 removals pass, R-9): this is now the
// LAST collection step — the standalone Review & submit screen
// (review_submit_screen.dart) was dropped, and submission moves here.
// Continue stashes these three fields on KycFormState (same as before), then
// calls POST /kyc-submissions/draft/finalize directly
// (KycRepository.finalizeDraft — 2026-08-20 phased-KYC directive; was POST
// /kyc-submissions, the all-at-once call, before that) — requires steps 2-5
// (id document, liveness, utility bill, ready-to-finalize) already done,
// computes the real vendorDecision from everything accumulated across the
// earlier steps, and leaves 'draft' for good.
//
// X-3 (SHARED-CHANGES.md): a compliance officer reviewing a submission must
// see the residential address AS IT WAS WHEN SUBMITTED, not whatever the
// profile says later. utility_bill.dart (s17) already collects
// street address/city/state and PATCHes them onto the investor's own
// profile (UserRepository.updateProfile) rather than staging them into the
// shared KycFormState. So — same as review_submit_screen.dart used to do —
// this screen re-fetches that profile (UserRepository.personalInfo(), the
// exact resource utility_bill.dart just wrote to) right before Submit
// fires, and sends its residentialAddress/city/state straight into
// finalizeDraft. That captures the value AT SUBMISSION TIME. This wiring
// MOVED here with the submission call; it must not be lost.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import '../onboarding/_pickers.dart';
import '_kyc_chrome.dart';

class NextOfKinScreen extends StatefulWidget {
  const NextOfKinScreen({super.key});

  @override
  State<NextOfKinScreen> createState() => _NextOfKinScreenState();
}

// Canvas screen 21's "Relationship" field is a Select (design system has no
// Flutter Select widget — see id_upload.dart's own _pickType comment); this
// mirrors that same screen's already-established compact-field + KSheet
// picker convention rather than leaving it a free-text KInput.
const List<String> _relationships = [
  'Spouse',
  'Parent',
  'Sibling',
  'Child',
  'Guardian',
  'Other relative',
  'Other',
];

class _NextOfKinScreenState extends State<NextOfKinScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  // 2026-08-29: next of kin's phone gained the same country picker as
  // sign_up_screen.dart/personal_details_screen.dart — this field used to
  // draw a hardcoded `prefix: '+234'` that was purely decorative (the
  // submitted value was always just the raw digits typed, with no country
  // code at all, since finalizeDraft's nextOfKin.phone is free text with
  // no format contract). Defaults to Nigeria, same as everywhere else.
  KPhoneCountry _phoneCountry = kDefaultPhoneCountry;
  String? _relationship;
  bool _showErrors = false;
  bool _prefilled = false;
  bool _submitting = false;

  late final _kycRepo = KycRepository(AppScope.read(context).apiClient);
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resume-aware (Review & submit's "Edit" jumps back here) — prefill
    // from whatever KycFormState already holds this session.
    if (_prefilled) return;
    _prefilled = true;
    final form = AppScope.read(context).kycForm;
    _name.text = form.nextOfKinName ?? '';
    final storedPhone = form.nextOfKinPhone ?? '';
    _phoneCountry = countryForE164(storedPhone);
    _phone.text = storedPhone.isEmpty ? '' : localPartOf(storedPhone, _phoneCountry);
    _email.text = form.nextOfKinEmail ?? '';
    _relationship = form.nextOfKinRelationship;
  }

  Future<void> _pickCountryCode() async {
    final picked = await showCountryCodePicker(context, selected: _phoneCountry);
    if (picked != null) setState(() => _phoneCountry = picked);
  }

  Future<void> _pickRelationship() async {
    final picked = await showKSheet<String>(
      context,
      title: 'Relationship',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _relationships.length; i++)
            _RelationRow(
              label: _relationships[i],
              selected: _relationship == _relationships[i],
              first: i == 0,
              onTap: () => Navigator.of(context).pop(_relationships[i]),
            ),
        ],
      ),
    );
    if (picked == null) return;
    setState(() => _relationship = picked);
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && _relationship != null && _phone.text.trim().isNotEmpty;

  /// D-1: submits the draft directly — this is the last collection step.
  /// See this file's header comment (X-3) for why the profile address is
  /// re-fetched here rather than read off KycFormState.
  Future<void> _submit() async {
    if (!_valid) {
      setState(() => _showErrors = true);
      return;
    }
    final app = AppScope.read(context);
    final form = app.kycForm;
    form.setNextOfKin(
      name: _name.text.trim(),
      relationship: _relationship!,
      phone: _phone.text.trim().isEmpty
          ? ''
          : composePhoneE164(_phone.text, _phoneCountry.dial),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
    );

    setState(() => _submitting = true);
    // X-3: best-effort — a failed fetch shouldn't block submission, it just
    // leaves the address unset on finalizeDraft (same as never having
    // collected it).
    PersonalInfo? info;
    try {
      info = await _userRepo.personalInfo();
    } on ApiException {
      info = null;
    }
    String? realOrNull(String? v) => (v == null || v == '—') ? null : v;
    try {
      await _kycRepo.finalizeDraft(
        nextOfKinName: form.nextOfKinName ?? '',
        nextOfKinRelationship: form.nextOfKinRelationship ?? '',
        nextOfKinPhone: form.nextOfKinPhone ?? '',
        nextOfKinEmail: form.nextOfKinEmail,
        address: realOrNull(info?.residentialAddress),
        city: realOrNull(info?.city),
        state: realOrNull(info?.state),
      );
      if (!mounted) return;
      form.reset();
      app.setKycSubmitted(true);
      context.go(Routes.kycSubmitted);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showErrorSheet(context, message: e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showErrorSheet(context, message: 'Something went wrong. Please try again.');
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
            KycTopBar(
              // R-45 as amended: locked (pre-restart) goes to the checklist
              // hub, in-session goes to the normal predecessor — see
              // kycBackTarget's own doc comment.
              onBack: () => context.go(kycBackTarget(context, Routes.kycNextOfKin)),
              stepLabel: 'Verification · 7 of 7',
            ),
            const KycStepProgress(total: 7, current: 7),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 8, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(
                      title: 'Next of kin',
                      body:
                          "Who should we contact about your account if we can't reach you? The CSCS requires this.",
                    ),
                    const SizedBox(height: 20),
                    KCard(
                      child: Column(
                        children: [
                          KInput(
                              label: 'Full name',
                              placeholder: 'Ngozi Okonkwo',
                              controller: _name,
                              error: _showErrors && _name.text.trim().isEmpty ? 'Enter a full name' : null,
                              onChanged: (_) {
                                if (_showErrors) setState(() {});
                              }),
                          const SizedBox(height: 16),
                          _RelationshipField(
                            value: _relationship,
                            onTap: _pickRelationship,
                          ),
                          if (_showErrors && _relationship == null) ...[
                            const SizedBox(height: 6),
                            Text('Select a relationship', style: KType.data(color: KColor.loss)),
                          ],
                          const SizedBox(height: 16),
                          KPhoneNumberField(
                              controller: _phone,
                              country: _phoneCountry,
                              onCountryTap: _pickCountryCode,
                              hintText: '802 987 6543',
                              error: _showErrors && _phone.text.trim().isEmpty ? 'Enter a phone number' : null,
                              onChanged: (_) {
                                if (_showErrors) setState(() {});
                              }),
                          const SizedBox(height: 16),
                          // Canvas s21's 4th field — optional, no validation.
                          KInput(
                            label: 'Email',
                            placeholder: 'Optional',
                            icon: 'mail',
                            keyboardType: TextInputType.emailAddress,
                            controller: _email,
                          ),
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
                // D-1: this is now the final step — submits directly rather
                // than handing off to a Review & submit screen.
                label: 'Submit for verification',
                loading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the finalize call fails — moved from review_submit_screen.dart
/// (D-1, dropped per R-9) along with the submit call itself.
void _showErrorSheet(BuildContext context, {required String message}) {
  showKSheet<void>(
    context,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KStatusView(
        tone: KStatusTone.error,
        title: 'Submission failed',
        message: message,
        primary: 'Try again',
        onPrimary: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

/// "Relationship" field's closed/collapsed state — same visual chrome as
/// [KInput] (tracked uppercase label, 50px hairline box) so it sits
/// consistently among the KInput fields around it in the same KCard, but
/// opens [_RelationRow]'s picker sheet instead of a keyboard.
class _RelationshipField extends StatelessWidget {
  const _RelationshipField({required this.value, required this.onTap});
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('RELATIONSHIP', style: KType.label(color: KColor.ink2)),
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
                    value ?? 'Select',
                    style: KType.body(
                        color: value == null ? KColor.ink3 : KColor.ink,
                        w: KWeight.medium),
                  ),
                ),
                const SizedBox(width: 10),
                KIcon('chevronRight', size: 20, color: KColor.ink3),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One row in the relationship picker sheet — same shape as
/// id_upload.dart's own `_IdTypeRow` (that screen's precedent for this
/// compact-field + KSheet picker pattern), duplicated rather than shared
/// per this codebase's per-screen small-widget convention.
class _RelationRow extends StatelessWidget {
  const _RelationRow({
    required this.label,
    required this.selected,
    required this.first,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: KColor.hairline, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: KType.cardTitle())),
            if (selected) const KIcon('check', size: 18),
          ],
        ),
      ),
    );
  }
}
