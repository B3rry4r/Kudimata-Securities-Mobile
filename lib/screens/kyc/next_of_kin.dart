// KYC 7 — next of kin (step 5 of 5, final). Name / relationship / phone.
// Continue finalizes the draft: POST /kyc-submissions/draft/finalize
// (2026-08-20, phased-KYC directive — was POST /kyc-submissions, the
// all-at-once call, before this) — requires steps 2-4 (id document,
// liveness, utility bill) already done, computes the real vendorDecision
// from everything accumulated across the earlier steps, and leaves
// 'draft' for good. Then sets kycSubmitted, clears the held draft id
// (KycFormState.reset), and advances to the Submitted (pending review)
// screen. See lib/data/repositories/kyc_repository.dart.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
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
  bool _busy = false;
  String? _relationship;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    final app = AppScope.read(context);
    setState(() => _busy = true);
    final repo = KycRepository(app.apiClient);
    try {
      await repo.finalizeDraft(
        nextOfKinName: _name.text,
        nextOfKinRelationship: _relationship ?? '',
        nextOfKinPhone: _phone.text,
      );
      if (!mounted) return;
      app.kycForm.reset();
      app.setKycSubmitted(true);
      context.go(Routes.kycSubmitted);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showErrorSheet(context, message: e.message);
    } catch (_) {
      // Widened from `on ApiException` only (2026-08-20) — any OTHER
      // exception type used to leave `_busy` stuck true forever (a
      // permanent loading spinner on the final submit button).
      if (!mounted) return;
      setState(() => _busy = false);
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
              onBack: () => context.go(Routes.kycUtilityBill),
              stepLabel: 'Verification · 5 of 5',
            ),
            const KycStepProgress(total: 5, current: 5),
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
                              controller: _name),
                          const SizedBox(height: 16),
                          _RelationshipField(
                            value: _relationship,
                            onTap: _pickRelationship,
                          ),
                          const SizedBox(height: 16),
                          KInput(
                              label: 'Phone number',
                              prefix: '+234',
                              placeholder: '802 987 6543',
                              keyboardType: TextInputType.phone,
                              controller: _phone),
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
                // This app's flow has no separate review screen (spec 22) —
                // this button IS the final submit (calls finalizeDraft
                // directly), so it gets that screen's real button label
                // rather than a generic "Continue" on the last step.
                label: 'Submit for verification',
                loading: _busy,
                onPressed: _busy ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the POST /kyc-submissions (or a document registration) call
/// fails with an [ApiException] — [message] is that exception's
/// human-readable summary (safe to show directly, per
/// lib/data/api/api_exception.dart). The form's entered values stay intact
/// so the user can retry without re-typing anything.
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
