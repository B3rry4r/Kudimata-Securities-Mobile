// KYC 7 of 8 — Declarations · PEP (canvas screen 20). NEW screen (2026-08-24,
// re-sequencing to the canvas's real 8-step flow).
//
// Two real declarations, per the canvas — NOT one checkbox:
//   1. PEP question (Yes/No) — wired to the real backend field
//      KycSubmission.pepSelfDeclared via PATCH /kyc-submissions/draft
//      (KycRepository.updateDraftFields). A "Yes" reveals a "who holds the
//      position" select + a free-text "position and body" input — the
//      canvas calls for both, but NEITHER has a backend field yet
//      (confirmed against UpdateKycDraftFieldsRequest/KycSubmission,
//      backend common/types/kyc.types.ts: only the boolean is stored).
//      Rendered as real UI per the canvas anyway; held in KycFormState for
//      review_submit_screen.dart to echo back THIS session only — NOT
//      persisted server-side. A real, flaggable gap, not faked.
//   2. "I trade for myself, with my own money" — ALSO has no backend field;
//      a pure client-side confirmation. JUDGMENT CALL: this app blocks
//      Continue when it's unchecked (see _canContinue below) — the
//      description text itself ("Trading for someone else needs a
//      different account type") frames it as a genuine account-type
//      mismatch, not a soft nudge, and this flow is what a real SEC/NGX
//      licence application runs on, so treating it as advisory-only risked
//      quietly onboarding someone into the wrong account type.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import '_kyc_chrome.dart';

const List<String> _pepWhoOptions = ['Myself', 'A family member', 'A close associate'];

class DeclarationsScreen extends StatefulWidget {
  const DeclarationsScreen({super.key});

  @override
  State<DeclarationsScreen> createState() => _DeclarationsScreenState();
}

class _DeclarationsScreenState extends State<DeclarationsScreen> {
  final _position = TextEditingController();
  bool _pep = false;
  String? _who;
  bool _tradeForSelf = true;
  bool _busy = false;
  String? _error;
  bool _prefilled = false;

  late final _repo = KycRepository(AppScope.read(context).apiClient);

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final form = AppScope.read(context).kycForm;
    setState(() {
      _tradeForSelf = form.tradeForSelf;
      _who = form.pepWho;
      _position.text = form.pepPosition ?? '';
    });
    _repo.getDraft().then((draft) {
      if (!mounted || draft?.pepSelfDeclared == null) return;
      setState(() => _pep = draft!.pepSelfDeclared!);
    }).catchError((_) {});
  }

  Future<void> _pickWho() async {
    final picked = await showKSheet<String>(
      context,
      title: 'Who holds the position?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _pepWhoOptions.length; i++)
            _OptionRow(
              label: _pepWhoOptions[i],
              selected: _who == _pepWhoOptions[i],
              first: i == 0,
              onTap: () => Navigator.of(context).pop(_pepWhoOptions[i]),
            ),
        ],
      ),
    );
    if (picked == null) return;
    setState(() => _who = picked);
  }

  bool get _canContinue => _tradeForSelf;

  Future<void> _continue() async {
    if (!_canContinue) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.updateDraftFields(pepSelfDeclared: _pep);
      if (!mounted) return;
      AppScope.read(context).kycForm.setDeclarations(
            tradeForSelf: _tradeForSelf,
            pepWho: _pep ? _who : null,
            pepPosition: _pep ? _position.text.trim() : null,
          );
      context.go(Routes.kycNextOfKin);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
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
              onBack: () => context.go(Routes.kycBankDcs),
              stepLabel: 'Verification · 7 of 8',
            ),
            const KycStepProgress(total: 8, current: 7),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(
                      title: 'Two declarations',
                      body: 'The SEC requires both. A yes is fine — it only means a person reviews your file.',
                    ),
                    const SizedBox(height: 18),
                    KCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Do you, a family member or a close associate hold public office?',
                            style: KType.cardTitle(),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Elected office, a government or military post, a party role.',
                            style: KType.data(color: KColor.ink2),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _YesNoTile(
                                  label: 'Yes',
                                  selected: _pep,
                                  onTap: () => setState(() => _pep = true),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _YesNoTile(
                                  label: 'No',
                                  selected: !_pep,
                                  onTap: () => setState(() => _pep = false),
                                ),
                              ),
                            ],
                          ),
                          if (_pep) ...[
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: _pickWho,
                              behavior: HitTestBehavior.opaque,
                              child: _CompactField(
                                label: 'Who holds the position?',
                                value: _who,
                              ),
                            ),
                            const SizedBox(height: 16),
                            KInput(
                              label: 'Position and body',
                              placeholder: 'e.g. Commissioner, Lagos State',
                              controller: _position,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    KCard(
                      child: KCheckbox(
                        checked: _tradeForSelf,
                        onChanged: (v) => setState(() => _tradeForSelf = v),
                        label: 'I trade for myself, with my own money',
                        description: 'Trading for someone else needs a different account type',
                      ),
                    ),
                    if (!_tradeForSelf) ...[
                      const SizedBox(height: 10),
                      Text(
                        "You'll need a different account type for that — confirm this to continue with this account.",
                        style: KType.data(color: KColor.loss),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: KType.body(color: KColor.loss)),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      'A false declaration can close your account. Nothing here is shared outside Kudimata Securities Ltd and the regulator.',
                      style: KType.data(color: KColor.ink3),
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
                onPressed: (_busy || !_canContinue) ? null : _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YesNoTile extends StatelessWidget {
  const _YesNoTile({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? KColor.indicatorTint : KColor.bg,
          borderRadius: BorderRadius.circular(KRadii.card),
          border: Border.all(color: selected ? KColor.indicator : KColor.hairline, width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KRadio(checked: selected, onChanged: (_) => onTap()),
            const SizedBox(width: 10),
            Text(label, style: KType.body(color: KColor.ink)),
          ],
        ),
      ),
    );
  }
}

/// Same closed/collapsed "Select" chrome as next_of_kin.dart's
/// _RelationshipField — this codebase's established compact-field + KSheet
/// picker convention (no Flutter Select widget exists; see id_upload.dart's
/// _pickType comment), duplicated per-screen by convention.
class _CompactField extends StatelessWidget {
  const _CompactField({required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: KType.label(color: KColor.ink2)),
        const SizedBox(height: 8),
        Container(
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
                  style: KType.body(color: value == null ? KColor.ink3 : KColor.ink, w: KWeight.medium),
                ),
              ),
              const SizedBox(width: 10),
              KIcon('chevronRight', size: 20, color: KColor.ink3),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.label, required this.selected, required this.first, required this.onTap});
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
