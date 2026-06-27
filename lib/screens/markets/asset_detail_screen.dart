// Asset detail (pushed) — price header (BalancePanel + KLineChart with range
// pills), your-position card (only when held), stat grid via KStatCard, About,
// and a sticky Buy / Sell footer calling showBuyFlow / showSellFlow. Save toggle
// in the header writes AppState.watchlistTickers. Ported from app-screens.jsx
// `AssetDetail`. Pushed screen — custom top bar (back + ticker + save), no tab bar.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/mock.dart';
import 'package:kudimata_securities/data/models.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'package:kudimata_securities/screens/trade/trade_flows.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);

class AssetDetailScreen extends StatelessWidget {
  const AssetDetailScreen({super.key, required this.ticker});

  final String ticker;

  KTrend _k(Trend t) => t == Trend.gain ? KTrend.gain : KTrend.loss;

  @override
  Widget build(BuildContext context) {
    final asset = MockData.assetByTicker(ticker);
    if (asset == null) {
      return Scaffold(
        backgroundColor: KColor.bg,
        appBar: KDetailHeader(title: ticker),
        body: Center(
          child: Text('Asset not found', style: KType.body(color: KColor.ink2)),
        ),
      );
    }

    final app = AppScope.of(context);
    final watched = app.isWatched(asset.ticker);
    final holding = MockData.holdingByTicker(asset.ticker);
    final series = asset.ticker == 'MTNN' ? MockData.mtnnSeries : asset.sparkline;

    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // top bar: back · ticker · save
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  KIconButton(
                    icon: 'back',
                    semanticLabel: 'Back',
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(asset.ticker,
                          style: KType.section().copyWith(letterSpacing: 0.04 * 17)),
                    ),
                  ),
                  // save toggle — purple when watched (interactive layer)
                  GestureDetector(
                    onTap: () => AppScope.read(context).toggleWatch(asset.ticker),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: watched ? KColor.indicator : KColor.paper,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: watched ? KColor.indicator : KColor.hairline,
                          width: 1,
                        ),
                      ),
                      child: KIcon('eye',
                          size: 20, color: watched ? KColor.featureInk : KColor.ink),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                children: [
                  // price feature panel
                  Padding(
                    padding: _gut,
                    child: KBalancePanel(
                      label: asset.name,
                      balance: asset.price,
                      change: '${asset.change} today',
                      changeTone: _k(asset.trend),
                      chart: KLineChart(
                        data: series,
                        trend: _k(asset.trend),
                        onDark: true,
                        height: 150,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // your position (only when held)
                  if (holding != null) ...[
                    Padding(
                      padding: _gut,
                      child: KCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const KEyebrow('Your position'),
                                const Spacer(),
                                KBadge(
                                  label: 'P/L ${holding.returnPct}',
                                  tone: holding.returnTrend == Trend.gain
                                      ? KBadgeTone.gain
                                      : KBadgeTone.loss,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: _PosCell(
                                        label: 'Quantity', value: holding.units)),
                                Expanded(
                                    child: _PosCell(
                                        label: 'Average cost', value: holding.avgPrice)),
                                Expanded(
                                    child: _PosCell(
                                        label: 'Market value',
                                        value: holding.marketValue)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // stat grid
                  Padding(
                    padding: _gut,
                    child: _StatGrid(asset: asset),
                  ),
                  const SizedBox(height: 28),

                  // about
                  const Padding(padding: _gut, child: KEyebrow('About')),
                  const SizedBox(height: 10),
                  Padding(
                    padding: _gut,
                    child: Text(_about(asset),
                        style: KType.body(color: KColor.ink2)),
                  ),
                ],
              ),
            ),

            // sticky Buy / Sell footer
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
                      label: 'Sell',
                      variant: KButtonVariant.secondary,
                      onPressed: () => showSellFlow(context, asset),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KButton(
                      label: 'Buy',
                      onPressed: () => showBuyFlow(context, asset),
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

  String _about(Asset a) {
    switch (a.assetClass) {
      case AssetClass.ngx:
        return '${a.name} is listed on the Nigerian Exchange (NGX). Prices are '
            'quoted in naira and the market closes at 2:30 pm WAT. This is mock '
            'reference copy for the 1:1 design rebuild.';
      case AssetClass.us:
        return '${a.name} is a US-listed equity quoted in US dollars. Trading '
            'follows regular US market hours. This is mock reference copy for the '
            '1:1 design rebuild.';
      case AssetClass.etf:
        return '${a.name} is an exchange-traded fund offering diversified, '
            'low-cost exposure to a basket of equities. This is mock reference '
            'copy for the 1:1 design rebuild.';
    }
  }
}

class _PosCell extends StatelessWidget {
  const _PosCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.upper, style: KType.micro(color: KColor.ink3)),
        const SizedBox(height: 5),
        Text(value, style: KType.cardTitle(w: KWeight.semibold).tnum),
      ],
    );
  }
}

/// Stat grid — 2-column KStatCard tiles. Values are mock reference figures.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.asset});
  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final cur = asset.price.isNotEmpty ? asset.price[0] : '₦';
    final stats = <(String, String, String)>[
      ('Open', '${cur}263.30', 'markets'),
      ('High', '${cur}270.00', 'arrowUp'),
      ('Low', '${cur}262.10', 'arrowDown'),
      ('Prev close', '${cur}263.30', 'transfer'),
      ('Mkt cap', '${cur}5.46T', 'portfolio'),
      ('P/E', '12.4', 'filter'),
    ];
    return Column(
      children: [
        for (var i = 0; i < stats.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _stat(stats[i])),
                const SizedBox(width: 10),
                Expanded(
                  child: i + 1 < stats.length
                      ? _stat(stats[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stat((String, String, String) s) => KStatCard(
        icon: KIcon(s.$3, size: 18, color: KColor.ink2),
        label: s.$1,
        value: s.$2,
      );
}
