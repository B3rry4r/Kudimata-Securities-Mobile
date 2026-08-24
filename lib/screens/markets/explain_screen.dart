// "Explain this investment" (pushed) — the AI/comprehension layer's
// centerpiece (2026-08-22 "Soft Landing" redesign, screen-specs.md screen
// 34). 2026-08-24: wired to the real Gemini-backed POST
// /ai/explain-asset/:ticker (Kudimata-Securities-Backend's
// AiComprehensionService) — direct product instruction ("that entry point
// is good... let's implement please we would use gemini api"). No more
// canned per-ticker strings; KGeneratingText's "writing" animation now
// plays while the real network call is in flight, not as a fixed 500ms
// timer.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/ai_repository.dart';
import 'package:kudimata_invest/data/repositories/asset_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/trade/trade_flows.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);

/// Free-trial grant — mirrors the backend's User.aiCreditsRemaining
/// `@default(3)` (Kudimata-Securities-Backend prisma/schema.prisma) — used
/// only to size the KCreditMeter's "total" when the investor has no active
/// plan (the backend tracks a plain balance + ledger, not a fixed
/// per-period total, so this screen derives one for display).
const _freeTrialCredits = 3;

class ExplainScreen extends StatefulWidget {
  const ExplainScreen({super.key, required this.topic});

  final String topic;

  @override
  State<ExplainScreen> createState() => _ExplainScreenState();
}

class _ExplainScreenState extends State<ExplainScreen> {
  static const _followUps = ['What is a dividend?', 'Why T+3?', 'Explain in Pidgin'];

  late final _aiRepo = AiRepository(AppScope.read(context).apiClient);

  String _answer = '';
  KGeneratingState _state = KGeneratingState.thinking;
  bool _launchingBuy = false;
  int? _creditsRemaining;
  String? _plan;
  String? _error;
  bool _insufficientCredits = false;

  @override
  void initState() {
    super.initState();
    _explain();
  }

  Future<void> _explain() async {
    setState(() {
      _state = KGeneratingState.thinking;
      _error = null;
      _insufficientCredits = false;
    });
    try {
      // Plan is fetched alongside the explain call (not returned by it) —
      // only used to size the KCreditMeter's "total" (trial vs plan
      // grant); reads current state at call time, not after the spend
      // below, so a boundary case (e.g. exactly out of credits) never
      // shows a mismatched plan/count pairing.
      final statusFuture = _aiRepo.credits();
      final result = await _aiRepo.explainAsset(widget.topic);
      final status = await statusFuture;
      if (!mounted) return;
      setState(() {
        _answer = result.text;
        _creditsRemaining = result.creditsRemaining;
        _plan = status.plan;
        _state = KGeneratingState.writing;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _insufficientCredits = e.code == 'INSUFFICIENT_CREDITS';
        _error = e.message;
        _state = KGeneratingState.done;
      });
    }
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
    final total = _plan == null ? _freeTrialCredits : null;
    final used = _creditsRemaining != null && total != null ? (total - _creditsRemaining!).clamp(0, total) : 0;

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
                  if (_creditsRemaining != null)
                    KCreditMeter(
                      compact: true,
                      used: used,
                      total: total ?? (used + _creditsRemaining!),
                      kind: _plan == null ? 'trial' : 'plan',
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 10, bottom: 24),
                children: [
                  Padding(
                    padding: _gut,
                    child: _error != null
                        ? KExplainPanel(
                            title: 'What am I buying?',
                            body: _error,
                            actions: _insufficientCredits
                                ? [
                                    KButton(
                                      label: 'See plans and credits',
                                      variant: KButtonVariant.secondary,
                                      onPressed: () => context.push(Routes.acctPlans),
                                    ),
                                  ]
                                : [
                                    KButton(
                                      label: 'Try again',
                                      variant: KButtonVariant.secondary,
                                      onPressed: _explain,
                                    ),
                                  ],
                          )
                        : KExplainPanel(
                            title: 'What am I buying?',
                            bodyWidget: KGeneratingText(key: ValueKey(_answer), text: _answer, state: _state),
                          ),
                  ),
                  const SizedBox(height: 10),
                  if (_error == null) ...[
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
                  ],
                  if (_creditsRemaining != null)
                    Padding(
                      padding: _gut,
                      child: KCreditMeter(
                        used: used,
                        total: total ?? (used + _creditsRemaining!),
                        kind: _plan == null ? 'trial' : 'plan',
                      ),
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
