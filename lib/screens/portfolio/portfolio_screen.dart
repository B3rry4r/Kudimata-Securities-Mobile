// Stage 7 · Portfolio overview (root tab). Ported 1:1 from portfolio-screens.jsx
// `Portfolio`. One ink BalancePanel (total value + all-time return), the purple
// allocation donut with NGX/US/ETF/Cash legend, then the holdings list.
// Tab root: builds a Scaffold body WITHOUT a bottom nav — the shell owns nav.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_securities/data/mock.dart';
import 'package:kudimata_securities/data/models.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';

/// Allocation breakdown (matches the design copy/order). Purple ramp owns colour.
const _allocation = <_Alloc>[
  _Alloc('Nigerian stocks', 52),
  _Alloc('US stocks', 33),
  _Alloc('ETFs', 9),
  _Alloc('Cash', 6),
];

class _Alloc {
  const _Alloc(this.name, this.value);
  final String name;
  final double value;
}

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final holdings = MockData.portfolioHoldings;

    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              KSpace.gutter, 14, KSpace.gutter, 24),
          children: [
            const KScreenHead(title: 'Portfolio'),
            const SizedBox(height: 16),

            // The single ink BalancePanel — total value + all-time return.
            const KBalancePanel(
              label: 'Total value',
              balance: '₦2,418,650.00',
              change: '+₦418,650 · 20.9% all-time',
              changeTone: KTrend.gain,
              chart: KLineChart(
                data: MockData.homeSeries,
                onDark: true,
                height: 140,
                ranges: ['1W', '1M', '3M', '1Y', 'ALL'],
              ),
            ),

            const SizedBox(height: 28),
            const KEyebrow('Allocation'),
            const SizedBox(height: 12),
            const _AllocationCard(),

            const SizedBox(height: 28),
            const KEyebrow('Holdings'),
            const SizedBox(height: 12),
            _HoldingsCard(holdings: holdings),
          ],
        ),
      ),
    );
  }
}

/// Donut + legend card — donut uses the brand purple ramp; legend dots match.
class _AllocationCard extends StatelessWidget {
  const _AllocationCard();

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          KAllocationDonut(
            segments: [
              for (final a in _allocation) KDonutSegment(value: a.value, label: a.name),
            ],
            size: 132,
            thickness: 18,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _allocation.length; i++) ...[
                  if (i != 0) const SizedBox(height: 12),
                  _LegendRow(
                    color: KAllocationDonut.ramp[i % KAllocationDonut.ramp.length],
                    label: _allocation[i].name,
                    value: '${_allocation[i].value.toInt()}%',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: KType.body(color: KColor.ink))),
        Text(value,
            style: KType.body(color: KColor.ink, w: KWeight.medium).tnum),
      ],
    );
  }
}

/// Holdings list inside a single hairline card (rows split by 1px rules).
class _HoldingsCard extends StatelessWidget {
  const _HoldingsCard({required this.holdings});
  final List<Holding> holdings;

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < holdings.length; i++)
            Container(
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : const Border(top: BorderSide(color: KColor.hairline, width: 1)),
              ),
              child: KAssetRow(
                name: holdings[i].asset.name,
                ticker: holdings[i].asset.ticker,
                logoColor: holdings[i].asset.logoColor ?? KColor.ink,
                price: holdings[i].asset.price,
                change: holdings[i].asset.change,
                trend: holdings[i].asset.trend == Trend.loss ? KTrend.loss : KTrend.gain,
                onTap: () =>
                    context.push(Routes.holdingDetail(holdings[i].asset.ticker)),
              ),
            ),
        ],
      ),
    );
  }
}
