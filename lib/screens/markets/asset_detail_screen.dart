// Asset detail (pushed) — price header (BalancePanel + KLineChart with range
// pills), your-position card (only when held), stat grid via KStatCard, About,
// and a sticky Buy / Sell footer calling showBuyFlow / showSellFlow. Save toggle
// in the header writes AppState.watchlistTickers. Ported from app-screens.jsx
// `AssetDetail`. Pushed screen — custom top bar (back + ticker + save), no tab bar.
//
// Wired per lib/data/api/README.md's FutureBuilder convention: the Asset (+
// live Quote, merged per registry.json) and its real `about` field come from
// AssetRepository.byTickerWithAbout (GET /assets/:ticker) — replacing both
// MockData.assetByTicker and the old hardcoded per-assetClass `_about()`
// copy. The top bar's back/ticker segments don't depend on the fetch (they
// only need the route ticker) but the save toggle does need the real
// watchlist API, so it stays in this StatefulWidget's State alongside the
// fetch machinery.
//
// Your-position card: GET /holdings/:ticker via HoldingsRepository.byTicker
// — folded into the same combined future as the asset/about fetch (see
// `_load`) rather than a second FutureBuilder, since it's small and this
// screen already has exactly one loading/error surface. A 404 (this
// investor doesn't hold this ticker) is treated as "no position" (the card
// simply doesn't render, same as the old `MockData.holdingByTicker(...) ==
// null` case) — any other ApiException propagates and fails the whole
// fetch, same as every other combined fetch in this app (e.g. the portfolio
// screen's holdings+summary).
//
// Save/watch toggle: optimistic local flip via AppState.toggleWatch for
// instant UI feedback, then the real POST/DELETE /watchlist-items via
// WatchlistRepository — reverting the optimistic flip and surfacing a
// SnackBar on ApiException. Mirrors the dedicated watchlist screen's
// remove-control pattern (lib/screens/markets/watchlist_screen.dart).
//
// _StatGrid's Open/High/Low/Prev-close/Mkt-cap/P-E figures stay mocked: per
// the backend brief, registry.json's Asset/Quote resources have NO
// corresponding fields for any of them — there is nothing real to wire them
// to yet, so inventing plausible-looking numbers would be worse than the
// existing labeled-mock placeholders. This is a genuine backend/product gap,
// not a wiring omission.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/mock.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/asset_repository.dart';
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/data/repositories/watchlist_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/screens/trade/trade_flows.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);

class AssetDetailScreen extends StatefulWidget {
  const AssetDetailScreen({super.key, required this.ticker});

  final String ticker;

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  late final _repo = AssetRepository(AppScope.read(context).apiClient);
  late final _holdingsRepo = HoldingsRepository(AppScope.read(context).apiClient);
  late final _watchlistRepo = WatchlistRepository(AppScope.read(context).apiClient);
  late Future<(Asset asset, String? about, Holding? holding)> _future =
      _load(widget.ticker);

  /// Combines the asset/about fetch with an optional holding lookup — see
  /// file header for why a 404 on the holding fetch is swallowed as "no
  /// position" while other failures propagate.
  Future<(Asset asset, String? about, Holding? holding)> _load(String ticker) async {
    final assetFuture = _repo.byTickerWithAbout(ticker);
    final holdingFuture = _fetchHolding(ticker);
    final (asset, about) = await assetFuture;
    final holding = await holdingFuture;
    return (asset, about, holding);
  }

  Future<Holding?> _fetchHolding(String ticker) async {
    try {
      return await _holdingsRepo.byTicker(ticker);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Optimistic toggle: flips local AppState immediately for instant UI
  /// feedback, then fires the real add/remove call. On failure, reverts the
  /// optimistic flip and surfaces the error. Mirrors watchlist_screen.dart's
  /// `_removeTicker`.
  Future<void> _toggleWatch() async {
    final app = AppScope.read(context);
    final wasWatched = app.isWatched(widget.ticker);
    app.toggleWatch(widget.ticker);
    try {
      if (wasWatched) {
        await _watchlistRepo.remove(widget.ticker);
      } else {
        await _watchlistRepo.add(widget.ticker);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      app.toggleWatch(widget.ticker); // revert the optimistic local flip
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final watched = app.isWatched(widget.ticker);

    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // top bar: back · ticker · save — independent of the fetch below.
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
                      child: Text(widget.ticker,
                          style: KType.section().copyWith(letterSpacing: 0.04 * 17)),
                    ),
                  ),
                  // save toggle — purple when watched (interactive layer)
                  GestureDetector(
                    onTap: () => _toggleWatch(),
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
              child: FutureBuilder<(Asset asset, String? about, Holding? holding)>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const KLoadingView();
                  }
                  if (snapshot.hasError) {
                    return KErrorView(
                      onPrimary: () => setState(
                        () => _future = _load(widget.ticker),
                      ),
                    );
                  }
                  final (asset, about, holding) = snapshot.data!;
                  return _AssetDetailBody(asset: asset, about: about, holding: holding);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The fetched-data half of the screen: price panel, position card, stat
/// grid, about copy, and the sticky Buy/Sell footer. Identical to the old
/// mock-fed `build()` body, just extracted so it can be fed by
/// [FutureBuilder]'s snapshot data instead of `MockData.assetByTicker`.
class _AssetDetailBody extends StatelessWidget {
  const _AssetDetailBody({required this.asset, required this.about, required this.holding});

  final Asset asset;
  final String? about;

  /// Real position data via HoldingsRepository.byTicker (GET
  /// /holdings/:ticker), null when this investor doesn't hold this asset —
  /// see file header. The "your position" card below only renders when
  /// non-null.
  final Holding? holding;

  KTrend _k(Trend t) => t == Trend.gain ? KTrend.gain : KTrend.loss;

  @override
  Widget build(BuildContext context) {
    // Local binding: `holding` is a public field, so Dart won't flow-promote
    // it from `Holding?` to `Holding` across the `holding != null` check
    // below (promotion only applies to private fields) — binding it to a
    // local first restores that promotion.
    final holding = this.holding;
    final series = asset.ticker == 'MTNN' ? MockData.mtnnSeries : asset.sparkline;

    return Column(
      children: [
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

              // stat grid — still mocked; see file header / product-gap note.
              Padding(
                padding: _gut,
                child: _StatGrid(asset: asset),
              ),
              const SizedBox(height: 28),

              // about — real backend field (Asset.about), falls back to a
              // plain notice (not fabricated copy) when the backend has none
              // for this instrument.
              const Padding(padding: _gut, child: KEyebrow('About')),
              const SizedBox(height: 10),
              Padding(
                padding: _gut,
                child: Text(
                  (about != null && about!.trim().isNotEmpty)
                      ? about!
                      : 'No description available for ${asset.name} yet.',
                  style: KType.body(color: KColor.ink2),
                ),
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
    );
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

/// Stat grid — 2-column KStatCard tiles. Values are mock reference figures:
/// registry.json's Asset/Quote resources carry no open/high/low/prev-close/
/// market-cap/P-E fields, so there is no real endpoint to wire this to yet
/// (product gap — flagged, not silently invented).
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
