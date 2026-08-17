// Stage 7 · Holding detail (pushed). Ported from portfolio-screens.jsx
// `HoldingDetail`, made data-driven by ticker. Position BalancePanel, a KLineChart,
// position stats via KStatCard, and the Sell / Buy more footer wired to the
// trade flow launchers. KDetailHeader (back chevron, no tab bar).
//
// Wired to GET /holdings/:ticker via HoldingsRepository.byTicker (see
// lib/data/api/README.md's FutureBuilder convention). That endpoint's own
// JSON has no asset display fields, so the repository merges in a
// GET /assets/:ticker fetch itself — this screen just consumes the single
// resulting `Holding`. This also resolves the old silent not-found fallback
// (MockData.holdingByTicker(ticker) ?? MockData.portfolioHoldings.first): an
// unrecognized/failed ticker now surfaces KErrorView instead of silently
// showing a different holding's numbers.
import 'package:flutter/material.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/screens/trade/trade_flows.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class HoldingDetailScreen extends StatefulWidget {
  const HoldingDetailScreen({super.key, required this.ticker});

  /// The held instrument's ticker (e.g. 'MTNN').
  final String ticker;

  @override
  State<HoldingDetailScreen> createState() => _HoldingDetailScreenState();
}

class _HoldingDetailScreenState extends State<HoldingDetailScreen> {
  late final _repo = HoldingsRepository(AppScope.read(context).apiClient);
  late Future<Holding> _future = _repo.byTicker(widget.ticker);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Holding>(
      future: _future,
      builder: (context, snapshot) {
        // KDetailHeader's title can't wait on the fetch (it's outside the
        // scrollable body), so it shows the ticker — always known up front,
        // same fallback asset_detail_screen.dart uses — until the real
        // asset.name (the fragment's intended title) resolves.
        final title = snapshot.data?.asset.name ?? widget.ticker;

        return Scaffold(
          backgroundColor: KColor.bg,
          appBar: KDetailHeader(title: title),
          body: SafeArea(
            top: false,
            child: Builder(builder: (context) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const KLoadingView();
              }
              if (snapshot.hasError) {
                return KErrorView.failedLoad(
                  onPrimary: () =>
                      setState(() => _future = _repo.byTicker(widget.ticker)),
                );
              }
              return _HoldingDetailBody(holding: snapshot.data!);
            }),
          ),
        );
      },
    );
  }
}

/// The loaded-state widget tree — identical to the original mock-fed
/// `build()`, just parameterized on the fetched `Holding` instead of
/// `MockData.holdingByTicker`.
class _HoldingDetailBody extends StatelessWidget {
  const _HoldingDetailBody({required this.holding});
  final Holding holding;

  @override
  Widget build(BuildContext context) {
    final asset = holding.asset;
    final trend = holding.returnTrend == Trend.loss ? KTrend.loss : KTrend.gain;
    final subTone =
        holding.returnTrend == Trend.loss ? KSubTone.loss : KSubTone.gain;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                KSpace.gutter, 16, KSpace.gutter, 24),
            children: [
              // Position panel — your value + total return.
              KBalancePanel(
                label: '${asset.name} · your position',
                balance: holding.marketValue,
                change: '${holding.totalReturn} · ${holding.returnPct}',
                changeTone: trend,
              ),
              const SizedBox(height: 16),

              // Position stats — 2×2 grid of KStatCard.
              _StatGrid(
                children: [
                  KStatCard(
                    icon: KIcon('transfer', size: 18, color: KColor.ink2),
                    label: 'Avg cost',
                    value: holding.avgPrice,
                  ),
                  KStatCard(
                    icon: KIcon('portfolio', size: 18, color: KColor.ink2),
                    label: 'Quantity',
                    value: holding.units,
                  ),
                  KStatCard(
                    icon: KIcon('markets', size: 18, color: KColor.ink2),
                    label: 'Current',
                    value: asset.price,
                  ),
                  KStatCard(
                    icon: KIcon('arrowUpRight', size: 18, color: KColor.ink2),
                    label: 'P/L',
                    value: holding.returnPct,
                    sub: holding.totalReturn,
                    subTone: subTone,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Sticky footer: Sell (secondary) + Buy more (the one purple moment).
        // Sell launches showSellFlow(context, asset) from trade_flows.dart —
        // that flow's own contract belongs to the asset-detail screen agent;
        // this screen is only a second launch point into it.
        _ActionFooter(asset: asset),
      ],
    );
  }
}

/// 2-column grid of equal-height stat cards.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: children,
    );
  }
}

class _ActionFooter extends StatelessWidget {
  const _ActionFooter({required this.asset});
  final Asset asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 14, KSpace.gutter, 14),
      child: Row(
        children: [
          Expanded(
            child: KButton(
              label: 'Sell',
              variant: KButtonVariant.secondary,
              onPressed: () => showSellFlow(context, asset),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: KButton(
              label: 'Buy more',
              onPressed: () => showBuyFlow(context, asset),
            ),
          ),
        ],
      ),
    );
  }
}
