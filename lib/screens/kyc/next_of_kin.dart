// KYC 8 of 8 — next of kin (2026-08-24 re-sequencing: was step 5 of 5/final;
// there's now a Review & submit screen after this one). Name / relationship
// / phone.
//
// Continue no longer finalizes the draft directly — it stashes these three
// fields on KycFormState (the draft itself has nowhere to hold them until
// finalize is actually called) and hands off to Review & submit
// (review_submit_screen.dart), which is the one screen that now calls
// POST /kyc-submissions/draft/finalize (2026-08-20, phased-KYC directive —
// was POST /kyc-submissions, the all-at-once call, before that) — requires
// steps 2-5 (id document, liveness, utility bill, ready-to-finalize)
// already done, computes the real vendorDecision from everything
// accumulated across the earlier steps, and leaves 'draft' for good.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
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
  String? _relationship;
  bool _showErrors = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
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
    _phone.text = form.nextOfKinPhone ?? '';
    _relationship = form.nextOfKinRelationship;
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

  void _continue() {
    if (!_valid) {
      setState(() => _showErrors = true);
      return;
    }
    AppScope.read(context).kycForm.setNextOfKin(
          name: _name.text.trim(),
          relationship: _relationship!,
          phone: _phone.text.trim(),
        );
    context.go(Routes.kycReview);
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
              onBack: () => context.go(Routes.kycDeclarations),
              stepLabel: 'Verification · 8 of 8',
            ),
            const KycStepProgress(total: 8, current: 8),
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
                          KInput(
                              label: 'Phone number',
                              prefix: '+234',
                              placeholder: '802 987 6543',
                              keyboardType: TextInputType.phone,
                              controller: _phone,
                              error: _showErrors && _phone.text.trim().isEmpty ? 'Enter a phone number' : null,
                              onChanged: (_) {
                                if (_showErrors) setState(() {});
                              }),
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
                // Review & submit (screen 22) is the new final step — this
                // one hands off to it rather than submitting directly.
                label: 'Review and submit',
                onPressed: _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
