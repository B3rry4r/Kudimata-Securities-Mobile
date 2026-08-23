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

/// One suitability question with its answer options.
class _Question {
  const _Question(this.prompt, this.options);
  final String prompt;
  final List<String> options;
}

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  // 7 questions → the canvas mockup's #s27 block is explicitly labelled
  // "Question 3 of 7" with a 7-segment progress bar (3 filled, 4 track) —
  // this screen previously hardcoded only 5, so "of 5" never matched the
  // design at all. Question index 2 (the 3rd question) is the ONE the
  // canvas gives verbatim — exact prompt, exact 3 options (not 4), exact
  // default selection (see _answers below) — every other question's copy
  // has no canvas ground truth (the canvas only shows this one frame of
  // the flow), so it's kept close to this screen's pre-existing content.
  static const List<_Question> _questions = [
    _Question('What are you investing for?', [
      'Growth over many years',
      'A goal in 3–5 years',
      'Income now',
      "I'm just exploring",
    ]),
    _Question('How long until you need this money?', [
      'More than 10 years',
      '5 to 10 years',
      '2 to 5 years',
      'Within 2 years',
    ]),
    // Verbatim from the canvas (#s27) — prompt, option copy and count (3,
    // not 4) are all exact.
    _Question('Your shares drop 20% in a month. What do you do?', [
      "Sell everything — I can't watch that",
      'Hold and wait it out',
      'Buy more at the lower price',
    ]),
    _Question('How much investing experience do you have?', [
      'I invest regularly',
      'I’ve invested a few times',
      'A little, mostly savings',
      'None yet',
    ]),
    _Question('What matters most to you?', [
      'Highest possible growth',
      'A balance of growth and safety',
      'Protecting what I have',
      'Steady income',
    ]),
    _Question('How would you describe your income?', [
      'Steady and predictable',
      'Variable, but manageable',
      'Irregular right now',
      'No income right now',
    ]),
    _Question('How comfortable are you with financial risk in general?', [
      'Very comfortable',
      'Somewhat comfortable',
      'Not very comfortable',
      'Not at all comfortable',
    ]),
  ];

  int _index = 0;
  // Selected option index per question — defaults to the first option,
  // EXCEPT question index 2 (the 20%-drop question), which the canvas shows
  // with its second option ("Hold and wait it out") pre-checked.
  final List<int> _answers = [0, 0, 1, 0, 0, 0, 0];

  late final _repo = SuitabilityRepository(AppScope.read(context).apiClient);
  bool _submitting = false;

  void _back() {
    if (_index == 0) {
      context.pop(); // back to the gate that launched suitability
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
        SnackBar(content: Text(e.message)),
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
                    const SizedBox(height: 18),
                    KExplainTrigger(
                      label: 'What is this question for?',
                      variant: KExplainTriggerVariant.inline,
                      onTap: () => showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: KColor.paper,
                        shape: const RoundedRectangleBorder(borderRadius: KRadii.sheetR),
                        builder: (context) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Why we ask this', style: KType.section()),
                              const SizedBox(height: 8),
                              Text(
                                'Your answers decide which products suit you — the SEC requires this before you can trade. There are no wrong answers.',
                                style: KType.body(color: KColor.ink2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
                            onPressed: _submitting ? null : _next,
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
