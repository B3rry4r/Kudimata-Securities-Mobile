// KYC 6 of 7 — Declarations (artboard s19 "Two quick questions",
// docs/design/redesign-2026-08/02 Verification.dc.html). Renumbered 8->7
// (was 7 of 8) 2026-08-27 per X-2/bvn_nin.dart's derivation.
//
// s19's actual two questions, per RULINGS.md's evidence
// (docs/redesign/evidence/kyc.json) — the previous build of this screen had
// the RIGHT first question and the WRONG second one (an undesigned
// "I trade for myself" declaration instead of s19's real second question);
// fixed here to match the artboard:
//   1. PEP question (Yes/No) — wired to the real backend field
//      KycSubmission.pepSelfDeclared via PATCH /kyc-submissions/draft
//      (KycRepository.updateDraftFields). A "Yes" reveals a "who holds the
//      position" select + a free-text "position and body" input — the
//      canvas draws only a "What's a PEP?" link on this question, no
//      who/position sub-fields, but a real "Yes" here is a genuine
//      SEC-compliance detail the screen can't leave uncollected just
//      because the artboard's one drawn scene is "No" (same reasoning as
//      the brief's Cancel/status-pill precedents — neither has a backend
//      field yet, confirmed against UpdateKycDraftFieldsRequest/
//      KycSubmission, backend common/types/kyc.types.ts: only the boolean
//      is stored). Held in KycFormState for THIS session only — a real,
//      flaggable gap, not faked.
//   2. "Do you work for a stockbroker or the NGX?" (Yes/No) — s19's real
//      second question. ALSO has no backend field (same file, same
//      confirmation) — a real gap, filed in BACKEND_GAPS.md. Held in
//      KycFormState (brokerOrNgxEmployed) for this session only, same
//      treatment as the PEP who/position detail above.
import 'package:flutter/gestures.dart';
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
  // s19's second question — "Do you work for a stockbroker or the NGX?" —
  // replaces the app's old, undesigned "I trade for myself" declaration
  // (see kyc_form_state.dart's brokerOrNgxEmployed doc comment). Defaults to
  // No, same as PEP.
  bool _brokerOrNgxEmployed = false;
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
      _brokerOrNgxEmployed = form.brokerOrNgxEmployed;
      _who = form.pepWho;
      _position.text = form.pepPosition ?? '';
    });
    _repo.getDraft().then((draft) {
      if (!mounted || draft?.pepSelfDeclared == null) return;
      setState(() => _pep = draft!.pepSelfDeclared!);
    }).catchError((_) {});
  }

  void _explainPep(BuildContext context) {
    showKSheet<void>(
      context,
      child: const KExplainPanel(
        title: "What's a PEP?",
        body: 'A politically exposed person holds — or has held — a prominent public role: elected '
            'office, a senior government or military post, or a similar position. Family members and '
            'close associates count too.',
      ),
    );
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

  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.updateDraftFields(pepSelfDeclared: _pep);
      if (!mounted) return;
      AppScope.read(context).kycForm.setDeclarations(
            brokerOrNgxEmployed: _brokerOrNgxEmployed,
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
              stepLabel: 'Verification · 6 of 7',
            ),
            const KycStepProgress(total: 7, current: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // s19's title/body, verbatim.
                    const KScreenHead(
                      title: 'Two quick questions',
                      body: 'The regulator requires these. Most people answer no.',
                    ),
                    const SizedBox(height: 18),
                    KCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Are you, a family member, or a close associate a '
                                      'politically exposed person? ',
                                  style: KType.cardTitle(),
                                ),
                                TextSpan(
                                  text: "What's a PEP?",
                                  style: KType.data(color: KColor.indicator, w: KWeight.semibold),
                                  recognizer: TapGestureRecognizer()..onTap = () => _explainPep(context),
                                ),
                              ],
                            ),
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
                          // Canvas's static PEP question draws only the
                          // Yes/No fork — but a real "Yes" here is a genuine
                          // SEC-compliance detail, not something the screen
                          // can leave uncollected just because the one
                          // situation the artboard depicts is "No". Same
                          // reasoning as the brief's Cancel/status-pill
                          // precedents: the code path this "Yes" branch
                          // serves is broader than the one scene drawn.
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
                    // s19's second question, verbatim — replaces the app's
                    // old "I trade for myself" declaration (see
                    // kyc_form_state.dart).
                    KCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Do you work for a stockbroker or the NGX?', style: KType.cardTitle()),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _YesNoTile(
                                  label: 'Yes',
                                  selected: _brokerOrNgxEmployed,
                                  onTap: () => setState(() => _brokerOrNgxEmployed = true),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _YesNoTile(
                                  label: 'No',
                                  selected: !_brokerOrNgxEmployed,
                                  onTap: () => setState(() => _brokerOrNgxEmployed = false),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                onPressed: _busy ? null : _continue,
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
