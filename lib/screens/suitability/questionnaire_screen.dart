// Suitability — risk-profile questionnaire. Multi-question, KRadio options, slim
// step-progress (mirrors the KYC flow). Linear, no tab bar.
// Ported from risk-screens.jsx (Questionnaire + StepProgress).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/suitability_repository.dart';
import 'package:kudimata_invest/screens/shared/glossary_sheet.dart';

/// One suitability question with its answer options.
class _Question {
  const _Question(this.prompt, this.options, {this.glossaryTerm});
  final String prompt;
  final List<String> options;

  /// A term in [prompt] the investor may not know. Renders a tappable
  /// "What does this mean?" affordance under the question, opening the
  /// HAND-WRITTEN definition from lib/data/glossary.dart — never an AI
  /// call (2026-08-24: "do that as a hand written glossary not an ai
  /// call"). This is a mandatory regulatory question nobody can skip, so
  /// understanding it must not cost a credit or need a network round-trip.
  final String? glossaryTerm;
}

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  // 2026-08-24 rewrite — the previous 7-question set (invented, no canvas
  // ground truth beyond one frame) is replaced with the exact 4-question
  // Client Suitability Assessment from the firm's real SEC-facing
  // compliance intake ("My observations on KSL papers.docx"): Investment
  // Experience, Investment Objective, Investment Horizon, Risk Tolerance —
  // each a single-select radio with exactly 3 options, wording verbatim
  // from that document. Every question orders index 0 = LEAST risk-oriented
  // option -> index 2 = MOST risk-oriented option (ascending) — matching
  // the backend's real scoring.ts, which no longer needs an inversion step
  // (see that file's own header comment for the bug history this avoids
  // repeating). The Risk Tolerance question's own options are the
  // document's literal (Conservative)/(Moderate)/(Aggressive) labels — the
  // same 3 values the computed profile can come out as.
  static const List<_Question> _questions = [
    _Question('Investment Experience', [
      'No experience (Beginner)',
      'Limited experience (Have bought basic stocks/mutual funds)',
      'Extensive experience (Active trader, familiar with derivatives/leverage)',
    ]),
    _Question('Investment Objective', [
      'Capital Preservation (Low risk, safety of principal)',
      'Balanced Growth (Medium risk, capital growth + income)',
      'Aggressive Growth (High risk, maximum capital appreciation)',
    ]),
    _Question(
      'Investment Horizon',
      [
        'Short-term (Less than 1 year)',
        'Medium-term (1 to 3 years)',
        'Long-term (More than 3 years)',
      ],
      // Reported 2026-08-24 ("what is this question for"): the term is
      // jargon and the question's purpose isn't self-evident.
      glossaryTerm: 'Investment Horizon',
    ),
    _Question(
      'If my investment portfolio drops by 20% in a month, I will:',
      [
        'Panic and liquidate all assets immediately (Conservative)',
        'Do nothing and wait for recovery (Moderate)',
        'View it as a buying opportunity and invest more (Aggressive)',
      ],
    ),
  ];

  int _index = 0;
  // Selected option index per question — no pre-checked default; every
  // question starts unanswered so an investor can't submit a real
  // regulatory intake on values they never actually chose. -1 = unanswered.
  final List<int> _answers = List<int>.filled(4, -1);

  late final _repo = SuitabilityRepository(AppScope.read(context).apiClient);
  bool _submitting = false;

  void _back() {
    if (_index == 0) {
      // Two entry paths: AppState.tradingEligibilityGap's fallback prompt
      // (home_screen.dart) `push`es this route, leaving a real screen
      // beneath it to pop back to. R-8a's primary onboarding path instead
      // reaches here via otp_screen.dart's `context.go(Routes.questionnaire)`
      // — a replace, not a push, so there's nothing on the stack to pop and
      // `context.pop()` alone would silently do nothing. Fall back to OTP
      // in that case rather than leaving the back control dead.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.otp);
      }
      return;
    }
    setState(() => _index--);
  }

  void _next() {
    if (_index < _questions.length - 1) {
      setState(() => _index++);
    } else {
      _submit();
    }
  }

  // POST /suitability-result with all 7 collected answers, then navigate to
  // the result screen (which re-fetches the real computed profile via
  // GET /suitability-result/me — see suitability_repository.dart). Question
  // ids: this screen's questions are a hardcoded local list with no
  // backend-defined id, so the list index is used, stringified as
  // "q0".."q6" — the backend's scoring only requires a non-empty string id
  // (see submit-suitability-answers.dto.ts), it does not interpret it.
  Future<void> _submit() async {
    setState(() => _submitting = true);
    final answers = [
      for (var i = 0; i < _questions.length; i++)
        SuitabilityAnswer(questionId: 'q$i', selectedOptionIndex: _answers[i]),
    ];
    try {
      await _repo.submit(answers);
      if (!mounted) return;
      context.go(Routes.suitabilityResult);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.displayMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_index];
    final total = _questions.length;
    final current = _index + 1;

    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: back icon-button + step label, THEN the progress bar
            // below it — ported 1:1 from the canvas mockup's #s27 block,
            // which has these as two separate rows in that order. The
            // previous version had no back affordance in the header at all
            // (only the step label sat here, below a taller/differently
            // radiused progress bar) and put the step label under the bar
            // instead of beside the back button.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  KIconButton(
                    icon: 'back',
                    variant: KIconButtonVariant.float,
                    onPressed: _back,
                    semanticLabel: 'back',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Question $current of $total'.upper,
                        style: KType.micro(color: KColor.ink3).tnum),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: List.generate(total, (i) {
                  return Expanded(
                    child: Container(
                      height: 5,
                      margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: i < current ? KColor.indicator : KColor.track,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),

            // Body: question card + nav buttons.
            Expanded(
              child: Padding(
                // Canvas: title/options/ExplainTrigger column padding
                // "24px 20px 0" (top 24 already applied above via the
                // SizedBox(height: 24)); footer row padding "20px 20px
                // 30px" — so this Padding's bottom is 30, matching the
                // footer's own bottom inset, not the content column's
                // (which has none).
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: Column(
                  children: [
                    Text(q.prompt, style: KType.title()),
                    if (q.glossaryTerm != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => showGlossaryExplainSheet(
                          context,
                          q.glossaryTerm!,
                          allowAiFollowUp: false,
                        ),
                        child: Text(
                          'What does this mean?',
                          style: KType.data(color: KColor.indicator)
                              .copyWith(decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                    // Canvas: the title/options-list/ExplainTrigger column
                    // uses a uniform gap:18px between all three children —
                    // was 16 then 14, matching neither.
                    const SizedBox(height: 18),
                    for (int i = 0; i < q.options.length; i++) ...[
                      if (i != 0) const SizedBox(height: 10),
                      _OptionRow(
                        label: q.options[i],
                        selected: _answers[_index] == i,
                        onTap: () => setState(() => _answers[_index] = i),
                      ),
                    ],
                    // 2026-08-24: a KExplainTrigger reading "What is this
                    // question for?" used to sit here on EVERY question,
                    // opening a hardcoded "Why we ask this" sheet. Removed
                    // on direct instruction ("What is this question for is
                    // not needed"). It also wore the AI-comprehension
                    // styling (sparkle + dashed underline) despite calling
                    // no AI at all, which is the same mislabelling that was
                    // just taken off the legal documents. Only question 3
                    // genuinely needed explaining, and it now carries a
                    // hand-written glossary link under its title instead.
                    const Spacer(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          // 100 (the original "editorial mono" figure) is 1.4px
                          // too narrow for "Back" in Nunito Sans semibold — the
                          // "Soft Landing" redesign's font swap renders very
                          // slightly wider at the same nominal size. Found live
                          // via route_walk_test.dart's overflow check.
                          width: 112,
                          child: KButton(
                            label: 'Back',
                            variant: KButtonVariant.secondary,
                            fullWidth: true,
                            onPressed: _submitting ? null : _back,
                          ),
                        ),
                        // Canvas footer row: gap:12px between the two buttons.
                        const SizedBox(width: 12),
                        Expanded(
                          child: KButton(
                            label: 'Next question',
                            loading: _submitting,
                            // A mandatory regulatory intake must reflect an
                            // answer the investor actually chose — disabled
                            // until this question has one (see _answers'
                            // doc comment: -1 = unanswered, no more
                            // pre-selected defaults).
                            onPressed: _submitting || _answers[_index] == -1 ? null : _next,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selectable option card — 2026-08-22 "Soft Landing" (screen-specs.md
/// screen 27): the selected option is a full indicator-tinted card with an
/// indicator border, not just tinted text — the same "selected choice card"
/// treatment used throughout KYC's radio groups (screens 15, 20).
///
/// Per the canvas (#s27): a leading `Radio` component (22×22, gap 12) draws
/// the checked/unchecked state — NOT a trailing checkmark icon appended
/// after the label, which is what this used to render (with no radio glyph
/// at all). The label's colour/weight also never changes on selection in
/// the canvas — it's always plain `--ink` body text; only the card's own
/// background/border communicate selection. Mirrors trade_flows.dart's
/// `_RadioOptionCard`, which draws the same shape for a different flow.
class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? KColor.indicatorTint : KColor.paper,
          borderRadius: KRadii.cardR,
          border: Border.all(
            color: selected ? KColor.indicator : KColor.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KRadio(checked: selected, onChanged: (_) => onTap()),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: KType.body(color: KColor.ink)),
            ),
          ],
        ),
      ),
    );
  }
}
