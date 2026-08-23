// "Explain this investment" (pushed) — the AI/comprehension layer's
// centerpiece (2026-08-22 "Soft Landing" redesign, screen-specs.md screen
// 34). UI-COMPLETE, CONTENT-STATIC: there is no real generative-AI backend
// yet (see docs/redesign/PLAN.md) — the answer shown here is a canned,
// per-topic plain-English explanation, not an LLM call. KGeneratingText's
// "writing" animation still runs for real (it's a local character-reveal
// effect, not a network-streaming one), so the interaction itself is
// faithful to the design even though the content behind it is a stub.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);

/// Canned explanations keyed by topic (an asset ticker today; any string the
/// caller wants to explain more generally tomorrow). Falls back to a generic
/// explainer when the topic isn't one of the specific cases below.
String _canned(String topic) {
  const known = <String, String>{
    'MTNN':
        'An MTN Nigeria share is a small piece of the company. You make money two ways: the price goes up, or MTN shares its profit with you as a dividend.',
    'GTCO':
        'A GTCO share is a small piece of Guaranty Trust Holding Company. You make money two ways: the price goes up, or GTCO pays part of its profit to shareholders as a dividend.',
    'DANGCEM':
        'A Dangote Cement share is a small piece of the company. You make money two ways: the price goes up, or Dangote Cement shares its profit with you as a dividend.',
  };
  return known[topic.toUpperCase()] ??
      'A share in $topic is a small piece of that company. You make money two ways: the price goes up, or the company shares its profit with you as a dividend.';
}

class ExplainScreen extends StatefulWidget {
  const ExplainScreen({super.key, required this.topic});

  final String topic;

  @override
  State<ExplainScreen> createState() => _ExplainScreenState();
}

class _ExplainScreenState extends State<ExplainScreen> {
  static const _followUps = ['What is a dividend?', 'Why T+3?', 'Explain in Pidgin'];

  late String _answer = _canned(widget.topic);
  KGeneratingState _state = KGeneratingState.thinking;

  @override
  void initState() {
    super.initState();
    // A brief "thinking" beat before the canned answer starts writing —
    // matches the spec's "thinking -> writing -> done" loop even though
    // there's no real network round-trip behind it.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _state = KGeneratingState.writing);
    });
  }

  void _ask(String followUp) {
    setState(() {
      _answer = "That's the plain-English version — a deeper answer to \"$followUp\" isn't available yet.";
      _state = KGeneratingState.writing;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, KSpace.gutter, 8),
              child: Row(
                children: [
                  KIconButton(icon: 'close', semanticLabel: 'Close', onPressed: () => context.pop()),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Explain ${widget.topic}', style: KType.section())),
                  // Spec: "CreditMeter (compact, in header; full below)" —
                  // was missing entirely up here before this exactness pass.
                  const KCreditMeter(compact: true, used: 3, total: 10, kind: 'trial'),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: _gut,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: KColor.indicatorTint, borderRadius: KRadii.featureR),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(children: [
                            const KAvatar.guide(size: KIllo.avatarSm),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Kudimata Invest',
                                    style: KType.cardTitle(color: KColor.indicatorPress).copyWith(fontSize: 13, height: 1.2)),
                                Text('EXPLAINING', style: KType.micro()),
                              ],
                            ),
                          ]),
                          const SizedBox(height: 16),
                          Text('What am I actually buying?',
                              style: TextStyle(
                                fontFamily: KType.fontDisplay,
                                fontWeight: KWeight.bold,
                                fontSize: 20,
                                height: 26 / 20,
                                letterSpacing: -0.02 * 20,
                                color: KColor.indicatorPress,
                              )),
                          const SizedBox(height: 8),
                          KGeneratingText(key: ValueKey(_answer), text: _answer, state: _state),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: _gut,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in _followUps) KPillChip(label: f, onTap: () => _ask(f)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Full (non-compact) card, per spec's "full below" — the
                  // header above carries the compact one.
                  const Padding(
                    padding: _gut,
                    child: KCreditMeter(used: 3, total: 10, kind: 'trial'),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: KColor.paper,
                border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
              ),
              padding: EdgeInsets.fromLTRB(
                KSpace.gutter,
                14,
                KSpace.gutter,
                14 + MediaQuery.of(context).padding.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: KButton(
                      label: "I'm ready to buy",
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Was missing entirely — spec's second button.
                  Expanded(
                    child: KButton(
                      label: 'See plans and credits',
                      variant: KButtonVariant.secondary,
                      onPressed: () => context.push(Routes.acctPlans),
                    ),
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
