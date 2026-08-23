// Stage 7 · Portfolio overview (root tab). Ported 1:1 from portfolio-screens.jsx
// `Portfolio`. One ink BalancePanel (total value + all-time return), the purple
// allocation donut with NGX/Cash legend, then the holdings list.
// NGX-only: US stocks/ETFs removed (Blue Marina supplies NGX equities only).
// Tab root: builds a Scaffold body WITHOUT a bottom nav — the shell owns nav.
//
// Wired to the backend per lib/data/api/README.md's FutureBuilder convention:
// HoldingsRepository.holdings() (GET /holdings) + .summary() (GET
// /portfolio-summary) replace MockData.portfolioHoldings and the formerly
// hardcoded BalancePanel/allocation-donut literals (STUB-portfolio-1/2 in
// .pipeline/fragments/portfolio.json).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  late final _repo = HoldingsRepository(AppScope.read(context).apiClient);
  late Future<(PortfolioSummary, List<Holding>)> _future = _load();

  Future<(PortfolioSummary, List<Holding>)> _load() async {
    // Record `.wait`, not fire-then-sequential-await: if summary() rejects
    // while holdings() is still in flight, sequential awaiting would throw
    // immediately and leave holdings()'s future unlistened-to — an
    // "unhandled exception" once it too resolves. `.wait` listens to both
    // up front regardless of which fails first. See home_screen.dart's
    // _load() for the same fix with the fuller writeup.
    final (summary, holdingsPage) = await (_repo.summary(), _repo.holdings()).wait;
    return (summary, holdingsPage.data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<(PortfolioSummary, List<Holding>)>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const KLoadingView();
            }
            if (snapshot.hasError) {
              return KErrorView.failedLoad(
                onPrimary: () => setState(() => _future = _load()),
              );
            }
            final (summary, holdings) = snapshot.data!;
            if (holdings.isEmpty) {
              return KEmptyView.holdings(
                onAction: () => context.go(Routes.markets),
              );
            }
            return _PortfolioBody(summary: summary, holdings: holdings);
          },
        ),
      ),
    );
  }
}

/// The loaded-state widget tree — identical to the original mock-fed
/// `build()`, just parameterized on fetched data instead of `MockData.x`.
class _PortfolioBody extends StatelessWidget {
  const _PortfolioBody({required this.summary, required this.holdings});
  final PortfolioSummary summary;
  final List<Holding> holdings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Tab-root: pad the bottom so the last holdings row clears the
      // floating KBottomNav (~70px + 12 margin + safe area).
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 14, KSpace.gutter, 100),
      children: [
        // screen-specs.md #38 / mockup-raw/s38.html: title, BalancePanel,
        // allocation card, digest, holdings card at a uniform 14px rhythm —
        // no "Allocation"/"Holdings" eyebrow labels between them (the app
        // had added those, and widened the rhythm to 16/28/12/20/28/12).
        const KScreenHead(title: 'Portfolio'),
        const SizedBox(height: 14),

        // The single ink BalancePanel — total value + all-time return.
        KBalancePanel(
          label: 'Total value',
          balance: summary.totalValue,
          change: summary.change,
          changeTone: summary.changeTrend == Trend.loss ? KTrend.loss : KTrend.gain,
          chart: KLineChart(
            data: summary.chartSeries,
            onDark: true,
            height: 140,
            ranges: const ['1W', '1M', '3M', '1Y', 'ALL'],
          ),
        ),

        const SizedBox(height: 14),
        _AllocationCard(allocation: summary.allocation, holdingCount: holdings.length),

        const SizedBox(height: 14),
        _ConcentrationDigest(allocation: summary.allocation),

        const SizedBox(height: 14),
        _HoldingsCard(holdings: holdings),
      ],
    );
  }
}

/// Donut + legend card — brand purple ramp; legend dots mirror the donut.
class _AllocationCard extends StatelessWidget {
  const _AllocationCard({required this.allocation, required this.holdingCount});
  final List<PortfolioAllocationSlice> allocation;

  /// The real number of distinct holdings — NOT `allocation.length` (that's
  /// the number of allocation SLICES, e.g. sectors, a different count).
  /// Spec 38's "4 holdings" center label refers to actual holdings.
  final int holdingCount;

  @override
  Widget build(BuildContext context) {
    // mockup-raw/s38.html line 11: 14px card padding, 16px row gap, 120px
    // donut — the app had 20px (KCard default), 20px, and 132px.
    return KCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          KAllocationDonut(
            segments: [
              for (var i = 0; i < allocation.length; i++)
                KDonutSegment(
                  value: allocation[i].value,
                  label: allocation[i].label,
                  color: KAllocationDonut.ramp[i % KAllocationDonut.ramp.length],
                ),
            ],
            // "4 holdings" (spec 38) — was missing the center label
            // entirely even though KAllocationDonut has always supported it.
            centerValue: '$holdingCount',
            centerLabel: holdingCount == 1 ? 'holding' : 'holdings',
            size: 120,
            thickness: 18,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < allocation.length; i++) ...[
                  if (i != 0) const SizedBox(height: 8),
                  _LegendRow(
                    color: KAllocationDonut.ramp[i % KAllocationDonut.ramp.length],
                    label: allocation[i].label,
                    value: '${allocation[i].value.toInt()}%',
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

/// AI portfolio-concentration narrative (2026-08-22 "Soft Landing" —
/// components/comprehension/DigestCard.jsx, design-system readme's
/// comprehension layer). Real numbers from `summary.allocation` — no
/// generation backend exists yet (see docs/redesign/PLAN.md), so this is a
/// deterministic sentence built from the two largest slices rather than
/// an actual LLM call; the copy pattern matches screen-specs.md #38
/// exactly ("Heavy on two names — X and Y are Z% of what you own...").
class _ConcentrationDigest extends StatelessWidget {
  const _ConcentrationDigest({required this.allocation});
  final List<PortfolioAllocationSlice> allocation;

  @override
  Widget build(BuildContext context) {
    if (allocation.isEmpty) return const SizedBox.shrink();
    final sorted = [...allocation]..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(2).toList();
    final combined = top.fold<double>(0, (sum, s) => sum + s.value);
    final names = top.map((s) => s.label).join(' and ');
    final body = top.length > 1
        ? '$names are ${combined.toStringAsFixed(0)}% of what you own — if either falls hard, the whole portfolio feels it.'
        : '${top.first.label} is ${top.first.value.toStringAsFixed(0)}% of what you own — a single concentrated position.';
    return KDigestCard(
      eyebrow: 'Portfolio health',
      title: top.length > 1 ? 'Heavy on two names' : 'A concentrated portfolio',
      body: body,
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
                    : Border(top: BorderSide(color: KColor.hairline, width: 1)),
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
