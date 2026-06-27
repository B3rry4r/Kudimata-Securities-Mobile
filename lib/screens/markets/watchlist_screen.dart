// Watchlist (pushed) — saved assets (AppState.watchlistTickers) as KAssetRows
// with a remove control; empty state when nothing is saved. Ported from
// app-screens.jsx `Watchlist` / `WatchlistEmpty`. Pushed screen: Scaffold +
// KDetailHeader. Toggle writes AppState (live across the app).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/mock.dart';
import 'package:kudimata_securities/data/models.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  KTrend _k(Trend t) => t == Trend.gain ? KTrend.gain : KTrend.loss;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tickers = app.watchlistTickers;
    // Resolve to assets (across all classes), preserving the canonical order.
    final items = MockData.allAssets.where((a) => tickers.contains(a.ticker)).toList();

    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: const KDetailHeader(title: 'Watchlist'),
      body: items.isEmpty ? _empty(context) : _list(context, items),
    );
  }

  Widget _list(BuildContext context, List<Asset> items) {
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        Padding(
          padding: _gut,
          child: KCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: i == 0
                            ? BorderSide.none
                            : BorderSide(color: KColor.hairline, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: KAssetRow(
                            name: items[i].name,
                            ticker: items[i].ticker,
                            price: items[i].price,
                            change: items[i].change,
                            trend: _k(items[i].trend),
                            logoColor: items[i].logoColor ?? KColor.ink,
                            onTap: () =>
                                context.push(Routes.assetDetail(items[i].ticker)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              AppScope.read(context).removeWatch(items[i].ticker),
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: Center(
                              child: KIcon('close', size: 18, color: KColor.ink3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 0),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KColor.paper,
              shape: BoxShape.circle,
              border: Border.all(color: KColor.hairline, width: 1),
            ),
            child: KIcon('eye', size: 30, color: KColor.ink),
          ),
          const SizedBox(height: 22),
          Text('Nothing saved yet', style: KType.title()),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text('Save a stock or ETF to follow its price and changes here.',
                textAlign: TextAlign.center,
                style: KType.body(color: KColor.ink2)),
          ),
          const SizedBox(height: 28),
          KButton(
            label: 'Browse markets',
            onPressed: () => context.go(Routes.markets),
          ),
        ],
      ),
    );
  }
}
