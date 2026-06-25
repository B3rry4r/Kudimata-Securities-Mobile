// Suitability — risk-profile questionnaire. Multi-question, KRadio options, slim
// step-progress (mirrors the KYC flow). Linear, no tab bar.
// Ported from risk-screens.jsx (Questionnaire + StepProgress).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_securities/widgets/widgets.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/router/routes.dart';

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
  // 5 questions → "QUESTION n OF 5" in the design's StepProgress.
  static const List<_Question> _questions = [
    _Question('What are you investing for?', [
      'Growth over many years',
      'A goal in 3–5 years',
      'Income now',
      "I'm just exploring",
    ]),
    _Question('How would you react to a 20% drop?', [
      'Buy more while it’s cheaper',
      'Hold and wait it out',
      'Sell some to limit losses',
      'Sell everything',
    ]),
    _Question('How long until you need this money?', [
      'More than 10 years',
      '5 to 10 years',
      '2 to 5 years',
      'Within 2 years',
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
  ];

  int _index = 0;
  // Selected option index per question (defaults to first, as in the design).
  final List<int> _answers = List<int>.filled(_questions.length, 0);

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
      context.go(Routes.suitabilityResult);
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
            // Slim step-progress indicator.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(total, (i) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                          decoration: BoxDecoration(
                            color: i < current ? KColor.ink : KColor.hairline,
                            borderRadius: BorderRadius.circular(KRadii.pill),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  Text('Question $current of $total'.upper,
                      style: KType.micro(color: KColor.ink3).tnum),
                ],
              ),
            ),

            // Body: question card + nav buttons.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    KCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                            child: Text(q.prompt, style: KType.section()),
                          ),
                          for (int i = 0; i < q.options.length; i++)
                            _OptionRow(
                              label: q.options[i],
                              selected: _answers[_index] == i,
                              onTap: () => setState(() => _answers[_index] = i),
                            ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: KButton(
                            label: 'Back',
                            variant: KButtonVariant.ghost,
                            onPressed: _back,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: KButton(
                            label: 'Next',
                            onPressed: _next,
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

/// Selectable option row — hairline top divider, KRadio dot + label; selected
/// label turns purple (mirrors the design's check-row).
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
        ),
        child: Row(
          children: [
            KRadio(checked: selected, onChanged: (_) => onTap()),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: KType.body(
                  color: selected ? KColor.indicator : KColor.ink,
                  w: selected ? KWeight.medium : KWeight.regular,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
