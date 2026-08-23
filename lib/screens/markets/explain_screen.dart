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
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/asset_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/trade/trade_flows.dart';
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
  bool _launchingBuy = false;

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

  /// Screen 34's primary CTA opens the Buy sheet directly (`nav.s35`), not a
  /// bare pop — this screen only receives a `topic` string, so it fetches
  /// the real Asset by ticker (today's only caller, asset_detail_screen.dart,
  /// always passes a ticker) before handing it to the shared buy flow.
  Future<void> _readyToBuy() async {
    setState(() => _launchingBuy = true);
    try {
      final repo = AssetRepository(AppScope.read(context).apiClient);
      final asset = await repo.byTicker(widget.topic);
      if (!mounted) return;
      await showBuyFlow(context, asset);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _launchingBuy = false);
    }
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
                  // Spec: "CreditMeter (compact, in header; full below)",
                  // both reading "7 of 10 left".
                  const KCreditMeter(compact: true, used: 7, total: 10, kind: 'trial'),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 10, bottom: 24),
                children: [
                  Padding(
                    padding: _gut,
                    child: KExplainPanel(
                      title: 'What am I buying?',
                      bodyWidget: KGeneratingText(key: ValueKey(_answer), text: _answer, state: _state),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Screen 34: a standing "what thinking looks like" example
                  // — a 2-line shimmer, labelled so it reads as a preview of
                  // the state before any answer text exists, not as a second
                  // live answer.
                  Padding(
                    padding: _gut,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: KColor.indicatorTint, borderRadius: KRadii.cardR),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('While it thinks · before any text exists'.upper,
                              style: KType.micro(color: KColor.ink3)),
                          const SizedBox(height: 8),
                          const KGeneratingText(text: '', state: KGeneratingState.thinking, lines: 2),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 10),
                  // Full (non-compact) card, per spec's "full below" — the
                  // header above carries the compact one.
                  const Padding(
                    padding: _gut,
                    child: KCreditMeter(used: 7, total: 10, kind: 'trial'),
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
              // Screen 34: the two CTAs stack full-width, not a side-by-side
              // row, and the second is ghost, not secondary.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KButton(
                    label: "I'm ready to buy",
                    loading: _launchingBuy,
                    onPressed: _launchingBuy ? null : _readyToBuy,
                  ),
                  const SizedBox(height: 10),
                  KButton(
                    label: 'See plans and credits',
                    variant: KButtonVariant.ghost,
                    onPressed: () => context.push(Routes.acctPlans),
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
