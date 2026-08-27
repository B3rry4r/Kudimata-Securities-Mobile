// KYC 2 of 7 — CHN · optional (canvas screen 15). NEW screen (2026-08-24,
// re-sequencing the 5-step phased flow to the canvas's real steps; renumbered
// 8->7 steps 2026-08-27 per X-2/bvn_nin.dart's derivation — see there). Sits
// right after BVN/NIN (step 1), before Documents (step 3).
//
// The CHN itself is a real backend field (KycSubmission.chn — added
// 2026-08-24 alongside this screen), updated via
// PATCH /kyc-submissions/draft {chn} (KycRepository.updateDraftFields) —
// deliberately NOT sent at step 1 (draftStep1 also accepts it, but the
// canvas collects it here, later in the real UX sequence; see
// kyc-submissions.service.ts's draftStep1 doc comment).
//
// "No, or I'm not sure" needs no network call at all — chn already defaults
// to null on a fresh draft; nothing to PATCH. "Skip — create one for me"
// (ghost button) is the same no-op-and-move-on, always available regardless
// of the radio/input state, per the canvas's own two-CTA design.
//
// Step-complete navigation goes to Routes.kycChecklist, not straight to the
// next collection screen (X-5, SHARED-CHANGES.md 2026-08-27) — the
// checklist hub is the flow's spine now, re-entered after every step.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import '_kyc_chrome.dart';

class ChnScreen extends StatefulWidget {
  const ChnScreen({super.key});

  @override
  State<ChnScreen> createState() => _ChnScreenState();
}

class _ChnScreenState extends State<ChnScreen> {
  final _chn = TextEditingController();
  bool _hasChn = false; // "most first-time investors don't have one yet" (KycSubmission.chn doc comment)
  bool _busy = false;
  bool _showErrors = false;
  String? _error;
  bool _prefilled = false;

  late final _repo = KycRepository(AppScope.read(context).apiClient);

  @override
  void dispose() {
    _chn.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resume-aware (Review & submit's "Edit" jumps back here) — prefill
    // from whatever's already on the draft, fetched once.
    if (_prefilled) return;
    _prefilled = true;
    _repo.getDraft().then((draft) {
      if (!mounted || draft?.chn == null) return;
      setState(() {
        _hasChn = true;
        _chn.text = draft!.chn!;
      });
    }).catchError((_) {});
  }

  Future<void> _continue() async {
    if (_hasChn && _chn.text.trim().isEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    if (!_hasChn) {
      // Nothing to persist — chn already defaults to null on the draft.
      context.go(Routes.kycChecklist);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.updateDraftFields(chn: _chn.text.trim());
      if (!mounted) return;
      context.go(Routes.kycChecklist);
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

  void _skip() => context.go(Routes.kycChecklist);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KycTopBar(
              onBack: () => context.go(Routes.kycBvn),
              stepLabel: 'Verification · 2 of 7 · optional',
            ),
            const KycStepProgress(total: 7, current: 2),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(
                      title: 'Do you have a CHN?',
                      body:
                          "Only if you've invested before. If not, we'll get one for you — nothing to do here.",
                    ),
                    const SizedBox(height: 20),
                    _ChoiceRow(
                      label: 'Yes, I have a CHN',
                      selected: _hasChn,
                      onTap: () => setState(() => _hasChn = true),
                    ),
                    const SizedBox(height: 10),
                    _ChoiceRow(
                      label: "No, or I'm not sure — request one for me",
                      selected: !_hasChn,
                      onTap: () => setState(() => _hasChn = false),
                    ),
                    if (_hasChn) ...[
                      const SizedBox(height: 20),
                      KInput(
                        label: 'CHN',
                        numeric: true,
                        placeholder: 'e.g. 1234567890',
                        helper: 'On any old contract note, or ask your previous broker',
                        error: _showErrors && _chn.text.trim().isEmpty ? 'Enter your CHN' : null,
                        controller: _chn,
                        onChanged: (_) {
                          if (_showErrors) setState(() {});
                        },
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: KType.body(color: KColor.loss)),
                    ],
                    const SizedBox(height: 20),
                    const KExplainPanel(
                      title: 'What is a CHN?',
                      body:
                          'Your permanent ID at the CSCS, the register of who owns which Nigerian shares. One person, one CHN, for life.',
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
              child: Column(
                children: [
                  KButton(label: 'Continue', loading: _busy, onPressed: _busy ? null : _continue),
                  const SizedBox(height: 10),
                  KButton(
                    label: 'Skip — create one for me',
                    variant: KButtonVariant.ghost,
                    onPressed: _busy ? null : _skip,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A selectable radio-row card — same visual shape as the canvas's Yes/No
/// rows (indicator-tinted + bordered when selected, plain paper otherwise).
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? KColor.indicatorTint : KColor.paper,
          borderRadius: BorderRadius.circular(KRadii.card),
          border: Border.all(color: selected ? KColor.indicator : KColor.hairline, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            KRadio(checked: selected, onChanged: (_) => onTap()),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: KType.body(color: KColor.ink))),
          ],
        ),
      ),
    );
  }
}
