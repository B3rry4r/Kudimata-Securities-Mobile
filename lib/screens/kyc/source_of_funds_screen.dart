// Occupation + source of funds — KYC step 6 of 8. NEW screen, 2026-09-04;
// gained occupation 2026-09-05.
//
// STILL STEP 6 OF 8. Occupation was added to THIS screen, not to a new step.
// The count went 7 -> 8 for source of funds and stays 8 — see
// test/kyc_step_count_single_truth_test.dart, which exists because this app
// reported a wrong "N of M" three separate times.
//
// TWO REGULATORY SOURCES, ONE SCREEN:
//
//   * Source of funds — Nigerian SEC No Objection condition 2, verbatim: "The
//     Company's client onboarding process is required to include a dedicated
//     'Source of Funds' field within the onboarding questionnaire to support
//     appropriate investor profiling and the required AML/CFT due diligence."
//
//   * Occupation — SEC (Capital Market Operators) AML/CFT/CPF Regulations
//     2022, reg 50(3)(e), which lists "verification of employment or public
//     position held" among the measures that strengthen identification.
//
// "Onboarding questionnaire" is the KYC flow the investor actually walks —
// NOT the suitability questionnaire, which was removed from onboarding
// entirely by ruling R-51 and is not being resurrected. This is a step of the
// verification flow, sitting between Bank & DCS (5) and Declarations (7),
// where the other regulator-required declarations already live.
//
// WHY THE TWO FIELDS HAVE DIFFERENT SHAPES — one closed list, one free text.
// This is not an inconsistency; it follows from what each answer is for.
//
//   Source of funds is a PROFILING answer. It only supports AML/CFT screening
//   if it can be aggregated and compared across investors, so it is a closed
//   list: [kSourceOfFundsOptions] (lib/data/repositories/kyc_repository.dart),
//   mirroring the backend's SourceOfFunds enum exactly — a screen never
//   invents a wire value. 'Something else' is the escape hatch and REQUIRES a
//   written description, enforced here as a field error and again server-side
//   (400 SOURCE_OF_FUNDS_OTHER_REQUIRED) so the requirement does not depend on
//   this screen behaving.
//
//   Occupation is an IDENTIFICATION answer. Reg 50(3)(e) is about pinning down
//   what position this person holds; it is genuinely open-ended, and any list
//   short enough to show in a sheet would be wrong for someone. A wrong list
//   plus an "Other" box is strictly worse than the free text it imitates — it
//   pushes real answers into an unlabelled bucket. So: free text, but BOUNDED
//   — trimmed, non-empty, and capped at [kOccupationMaxLength] (the backend's
//   own OCCUPATION_MAX_LENGTH, mirrored in lib/data/ because it is part of the
//   wire contract).
//
// A DROPDOWN, NOT NINE RADIO ROWS (2026-09-05, owner instruction). The nine
// options used to render inline as radios; nine visible options is too tall a
// list to sit on a form that now also carries a text field. It uses the app's
// existing select idiom and nothing new: [KSelectField] for the collapsed
// state and [showSourceOfFundsPicker] for the sheet, both in
// ../onboarding/_pickers.dart, both built on showKSheet/_PickerRow — the same
// machinery behind the state, country-code and avatar pickers.
//
// BOTH FIELDS GATE. Continue is disabled until both are answered, and — the
// part that actually matters — the backend refuses to finalize a draft missing
// either, exactly the way it already refuses one with no ID document or no
// liveness check. An investor cannot walk past this step and still submit.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import '../onboarding/_pickers.dart';
import '_kyc_chrome.dart';
import 'kyc_checklist_screen.dart' show nextKycStepRoute;

class SourceOfFundsScreen extends StatefulWidget {
  const SourceOfFundsScreen({super.key});

  @override
  State<SourceOfFundsScreen> createState() => _SourceOfFundsScreenState();
}

class _SourceOfFundsScreenState extends State<SourceOfFundsScreen> {
  final _other = TextEditingController();
  final _occupation = TextEditingController();
  String? _selected;
  bool _busy = false;
  bool _showErrors = false;
  String? _error;
  bool _prefilled = false;

  late final _repo = KycRepository(AppScope.read(context).apiClient);

  @override
  void dispose() {
    _other.dispose();
    _occupation.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    // Resume support, same shape declarations_screen.dart uses: an investor
    // who answered this and came back sees their own answers, not a blank
    // form. Best-effort — a failed fetch leaves the form empty rather than
    // blocking the step.
    _repo.getDraft().then((draft) {
      if (!mounted || draft == null) return;
      if (draft.sourceOfFunds == null && draft.occupation == null) return;
      setState(() {
        _selected = draft.sourceOfFunds;
        _other.text = draft.sourceOfFundsOther ?? '';
        _occupation.text = draft.occupation ?? '';
      });
    }).catchError((_) {});
  }

  /// The human label behind [_selected]'s wire code — what the collapsed
  /// select shows. Null while nothing is picked, which is what makes
  /// [KSelectField] render its placeholder.
  String? get _selectedLabel {
    if (_selected == null) return null;
    for (final option in kSourceOfFundsOptions) {
      if (option.code == _selected) return option.label;
    }
    // A code the app does not know a label for can only mean a draft carrying
    // a value this build predates. Show the code rather than an empty select
    // that reads as unanswered.
    return _selected;
  }

  bool get _needsDescription => _selected == kSourceOfFundsOtherCode;
  bool get _descriptionMissing => _needsDescription && _other.text.trim().isEmpty;
  String get _occupationValue => _occupation.text.trim();
  bool get _occupationMissing => _occupationValue.length < kOccupationMinLength;
  bool get _canContinue => _selected != null && !_descriptionMissing && !_occupationMissing;

  Future<void> _pickSource() async {
    final picked = await showSourceOfFundsPicker(context, selected: _selected);
    if (picked == null || !mounted) return;
    setState(() {
      _selected = picked;
      _showErrors = false;
    });
  }

  Future<void> _continue() async {
    if (!_canContinue) {
      // Says WHICH answer is missing rather than leaving a dead button — an
      // "other" with no description is the absence of an AML answer wearing
      // the shape of one, and the investor is told exactly that.
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.updateDraftFields(
        sourceOfFunds: _selected,
        // Sent ONLY for 'other' — the server rejects a description alongside a
        // specific source as two answers to one question.
        sourceOfFundsOther: _needsDescription ? _other.text.trim() : null,
        // Trimmed here as well as server-side, so the value this screen shows
        // on resume is the value that was stored.
        occupation: _occupationValue,
      );
      if (!mounted) return;
      final next = await nextKycStepRoute(AppScope.read(context).apiClient);
      if (!mounted) return;
      context.go(next);
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
              onBack: () => context.go(kycBackTarget(context, Routes.kycSourceOfFunds)),
              stepLabel: kycStepLabel(6),
            ),
            const KycStepProgress(current: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(
                      title: 'Your work and your money',
                      body: 'What you do, and the main source of the money you plan '
                          'to invest. The regulator requires us to ask both.',
                    ),
                    const SizedBox(height: 18),
                    KCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          KInput(
                            label: 'Occupation',
                            placeholder: 'e.g. Secondary school teacher',
                            controller: _occupation,
                            required: true,
                            // Capped at the wire bound rather than truncated
                            // after the fact, so the investor cannot type a
                            // request the server will refuse. KInput.maxLength
                            // is a PROP added for this (2026-09-05), not a
                            // second input widget.
                            maxLength: kOccupationMaxLength,
                            error: _showErrors && _occupationMissing
                                ? 'Tell us what you do for a living.'
                                : null,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          KSelectField(
                            label: 'Source of funds',
                            value: _selectedLabel,
                            placeholder: 'Select a source',
                            required: true,
                            onTap: _pickSource,
                            error: _showErrors && _selected == null
                                ? 'Pick your source of funds to continue.'
                                : null,
                          ),
                          if (_needsDescription) ...[
                            const SizedBox(height: 16),
                            KInput(
                              label: 'Tell us where it comes from',
                              placeholder: 'e.g. Proceeds from a matured cooperative contribution',
                              controller: _other,
                              // Only ever rendered when 'Something else' is
                              // picked, and it genuinely blocks Continue when
                              // it is — so it carries the same asterisk the two
                              // fields above do, rather than looking optional.
                              required: true,
                              error: _showErrors && _descriptionMissing
                                  ? 'Describe where your money comes from.'
                                  : null,
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: KType.body(color: KColor.loss)),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      'We ask this of every investor. Your answers are held for anti-money-laundering '
                      'checks and are never shared outside Kudimata Securities Ltd and the regulator.',
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
