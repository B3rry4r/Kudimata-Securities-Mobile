// Stage 7 · Holding detail (pushed). Ported from portfolio-screens.jsx
// `HoldingDetail`, made data-driven by ticker. Position BalancePanel, a KLineChart,
// position stats via KStatCard, and the Sell / Buy more footer wired to the
// trade flow launchers. KDetailHeader (back chevron, no tab bar).
import 'package:flutter/material.dart';

import 'package:kudimata_securities/data/mock.dart';
import 'package:kudimata_securities/data/models.dart';
import 'package:kudimata_securities/screens/trade/trade_flows.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';

class HoldingDetailScreen extends StatelessWidget {
  const HoldingDetailScreen({super.key, required this.ticker});

  /// The held instrument's ticker (e.g. 'MTNN').
  final String ticker;

  @override
  Widget build(BuildContext context) {
    final holding = MockData.holdingByTicker(ticker) ?? MockData.portfolioHoldings.first;
    final asset = holding.asset;
    final trend = holding.returnTrend == Trend.loss ? KTrend.loss : KTrend.gain;
    final subTone =
        holding.returnTrend == Trend.loss ? KSubTone.loss : KSubTone.gain;

    // Feature series: MTNN has a ported series; others reuse the asset sparkline.
    final series = asset.ticker == 'MTNN' ? MockData.mtnnSeries : asset.sparkline;

    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: KDetailHeader(title: asset.name),
      body: SafeArea(
        top: false,
        child: Column(
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
                  const SizedBox(height: 20),

                  // Price history.
                  KCard(
                    child: KLineChart(data: series, trend: asset.trend == Trend.loss ? KTrend.loss : KTrend.gain),
                  ),
                  const SizedBox(height: 16),

                  // Position stats — 2×2 grid of KStatCard.
                  _StatGrid(
                    children: [
                      KStatCard(
                        icon: const KIcon('transfer', size: 18, color: KColor.ink2),
                        label: 'Avg cost',
                        value: holding.avgPrice,
                      ),
                      KStatCard(
                        icon: const KIcon('portfolio', size: 18, color: KColor.ink2),
                        label: 'Quantity',
                        value: holding.units,
                      ),
                      KStatCard(
                        icon: const KIcon('markets', size: 18, color: KColor.ink2),
                        label: 'Market value',
                        value: holding.marketValue,
                      ),
                      KStatCard(
                        icon: const KIcon('arrowUpRight', size: 18, color: KColor.ink2),
                        label: 'Total return',
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
            _ActionFooter(asset: asset),
          ],
        ),
      ),
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
      decoration: const BoxDecoration(
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
