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
// 2026-08-24 rebuild: canvas s33 has NO Open/High/Low/Prev-close/Mkt-cap/P-E
// stat grid at all — that six-cell block was never in the design; removed.
// It also has NO "OPEN"/"HIGH" cells and does NOT leave ProductCard's
// risk/fee/liquidity/minimum blank: `risk="high" fee="1.35% all-in"
// liquidity="Daily · T+3" minimum="₦5,000"` — real, product-wide constants
// already used identically elsewhere in this app (trade_flows.dart's sell
// fee row, wallet_flows.dart/onboarding's ₦5,000 minimum, faq_screen.dart's
// T+3 glossary term). Passing "—" for these was a wiring bug, not an honest
// backend gap — fixed by reusing the SAME constants. `risk: high` applies
// uniformly to every NGX ordinary share here (this app carries no fixed
// income — see AssetClass's own doc comment — so "equities, not bonds" is
// the real, product-wide disclosure, not a per-instrument judgement).
//
// GENUINE GAP (kept, not silently dropped): canvas's "Dividend yield 6.20%"
// cell needs a real per-asset yield figure (trailing dividends ÷ price) that
// no backend endpoint computes yet, even though Dividend records now exist
// (see DividendsModule) — still renders "—". Flagged in
// docs/redesign/BACKEND_GAPS.md.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/mock.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/asset_repository.dart';
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/data/repositories/watchlist_repository.dart';
import 'market_hours.dart';
import 'package:kudimata_invest/router/routes.dart';
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
            // top bar: back · name/ticker · save — independent of the fetch below.
            // Screen 33: name over an uppercase "TICKER · EXCHANGE" line,
            // left-aligned next to the back button, not a centred bare
            // ticker — and the trailing action is a plus/check toggle (adds
            // to the watchlist), not an eye.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  KIconButton(
                    icon: 'back',
                    semanticLabel: 'Back',
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FutureBuilder<(Asset asset, String? about, Holding? holding)>(
                      future: _future,
                      builder: (context, snapshot) {
                        final asset = snapshot.data?.$1;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(asset?.name ?? widget.ticker, style: KType.cardTitle()),
                            Text(
                              (asset?.sector == null
                                      ? '${widget.ticker} · NGX'
                                      : '${widget.ticker} · NGX · ${asset!.sector}')
                                  .upper,
                              style: KType.micro(color: KColor.ink3),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  KIconButton(
                    icon: watched ? 'check' : 'plus',
                    semanticLabel: watched ? 'Remove from watchlist' : 'Add to watchlist',
                    selected: watched,
                    onPressed: () => _toggleWatch(),
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
    final marketOpen = AppScope.of(context).marketOpen;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              // 2026-08-24: this screen never showed any closed-market
              // indication at all (reported live as "markets dont show
              // closed too") — same banner markets_screen.dart shows. The
              // chart/price below stay as-is (last close, same as any
              // broker app shows outside trading hours) — only the small
              // live-look sparkline on the Markets LIST gets hidden when
              // closed, not this screen's real historical range chart.
              if (!marketOpen) ...[
                const Padding(padding: _gut, child: KMarketClosedBanner()),
                const SizedBox(height: 16),
              ],
              // price header — screen 33 is a hero price + change line
              // directly on the page background (no purple/ink feature
              // panel here; that treatment is reserved for wallet/portfolio
              // balances), then a plain (not onDark) chart defaulted to 1M.
              Padding(
                padding: _gut,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.price, style: KType.hero().tnum),
                    const SizedBox(height: 4),
                    Text(
                      asset.changeAbs == null
                          ? '${asset.change} today'
                          : '${asset.changeAbs} · ${asset.change} today',
                      style: KType.data(
                        color: _k(asset.trend) == KTrend.loss ? KColor.loss : KColor.gain,
                        w: KWeight.semibold,
                      ).tnum,
                    ),
                    const SizedBox(height: 12),
                    KLineChart(
                      data: series,
                      trend: _k(asset.trend),
                      range: '1M',
                      height: 130,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // The redesigned product card (2026-08-22 "Soft Landing" —
              // components/finance/ProductCard.jsx). price/change are real
              // (same Asset fields as the hero above). risk/fee/liquidity/
              // minimum are real, product-wide constants — see file header.
              Padding(
                padding: _gut,
                child: KProductCard(
                  name: asset.name,
                  market: 'Ordinary shares · NGX Main Board',
                  price: asset.price,
                  change: asset.change,
                  risk: KRiskTier.high,
                  fee: '1.35% all-in',
                  liquidity: 'Daily · T+3',
                  minimum: '₦5,000',
                  onExplain: () => context.push(Routes.explainThis(asset.ticker)),
                ),
              ),
              const SizedBox(height: 16),

              // Dividend yield / You own — screen 33's two-cell row.
              // Dividend yield has no backend field yet — see file header
              // gap note — so it renders "—" rather than a fabricated
              // number; "You own" is the real holding unit count, "0
              // shares" when this investor doesn't hold the asset (the row
              // is unconditional in the design, unlike the old P/L
              // position card this replaces).
              Padding(
                padding: _gut,
                child: Row(
                  children: [
                    Expanded(child: _StatCell(label: 'Dividend yield', value: '—')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCell(
                        label: 'You own',
                        value: holding != null ? '${holding.units} shares' : '0 shares',
                      ),
                    ),
                  ],
                ),
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
                  // Disabled when this investor doesn't hold the asset
                  // (holding == null, see this file's header) — there was
                  // nothing stopping a Sell attempt on a position of zero
                  // shares before this, reported 2026-08-19.
                  onPressed: holding == null ? null : () => showSellFlow(context, asset),
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

/// The screen-33 "Dividend yield" / "You own" cell — a bordered paper tile,
/// distinct from [KStatCard] (which also carries an optional icon this cell
/// never does).
class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border.all(color: KColor.hairline, width: 1),
        borderRadius: KRadii.cardR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.upper, style: KType.micro(color: KColor.ink3)),
          const SizedBox(height: 4),
          Text(value, style: KType.cardTitle(w: KWeight.semibold).tnum),
        ],
      ),
    );
  }
}

