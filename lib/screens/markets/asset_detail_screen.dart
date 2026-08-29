// Asset detail (pushed) — price header (BalancePanel + KLineChart with range
// pills), your-position card (only when held), stat grid via KStatCard,
// an About / Order book tab pair, and a sticky Buy / Sell footer calling
// showBuyFlow / showSellFlow. Save toggle in the header writes
// AppState.watchlistTickers. Ported from app-screens.jsx `AssetDetail`.
// Pushed screen — custom top bar (back + ticker + save).
//
// Artboards, taken from RULINGS.md (never from a comment — R-5): `s26`
// ("26 · Asset detail, About and Order book", light, About tab active) and
// `s27` ("27 · Order book", light, Order book tab active), both in `03 Home
// and Markets.dc.html`. Dark reference is `s26d` — the canvas only drew one
// dark twin, and it renders the Order book tab active (`s27` has no `s27d`
// counterpart); the About tab's dark styling below is the same token
// mapping applied to the inactive-tab look `s26d` already draws.
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
// R-41 (docs/redesign/DECISIONS.md): also wired to `market:quote` and
// `market:orderBook` (RealtimeClient.quotes/orderBooks) — this screen
// `market:subscribe`s to its one ticker on entry and `market:unsubscribe`s
// on exit ([_AssetDetailScreenState.initState]/[dispose]). A decoded quote
// is merged onto the already-loaded [Asset] via
// AssetRepository.applyLiveQuote (price/change only — no network call); a
// decoded order book replaces [_OrderBookTabState]'s displayed one
// directly. Neither tab refetches on an event; each refetches ONCE on
// RealtimeClient.reconnected, since events missed while disconnected can't
// be replayed.
//
// Save/watch toggle: optimistic local flip via AppState.toggleWatch for
// instant UI feedback, then the real POST/DELETE /watchlist-items via
// WatchlistRepository — reverting the optimistic flip and surfacing a
// SnackBar on ApiException. Mirrors the dedicated watchlist screen's
// remove-control pattern (lib/screens/markets/watchlist_screen.dart). Kept
// per R-16: the dedicated Watchlist screen is dropped but this toggle stays.
//
// 2026-08-24 rebuild: the canvas's About tab has NO Open/High/Low/Prev-close
// /Mkt-cap/P-E stat grid at all — that six-cell block was never in the
// design; removed. It also has NO "OPEN"/"HIGH" cells. ProductCard's
// risk/liquidity/minimum ARE real, product-wide constants (`risk: high`
// applies uniformly to every NGX ordinary share here — this app carries no
// fixed income, see AssetClass's own doc comment — `liquidity="Daily · T+3"`
// and `minimum="₦5,000"` are used identically elsewhere in this app:
// wallet_flows.dart/onboarding's ₦5,000 minimum, faq_screen.dart's T+3
// glossary term). The ProductCard/dividend-yield/"You own" row is real app
// content the artboard doesn't draw (it draws a plainer From/Paid-out/
// Dividend three-cell row instead) — kept rather than silently dropped, per
// the screen-agent brief's rule 2; reported in this pass's summary.
//
// GENUINE GAP (kept, not silently dropped): canvas's "Dividend yield 6.20%"
// cell needs a real per-asset yield figure (trailing dividends ÷ price) that
// no backend endpoint computes yet, even though Dividend records now exist
// (see DividendsModule) — still renders "—". Flagged in
// docs/redesign/BACKEND_GAPS.md.
//
// 2026-08-29 repair: `fee: "1.35% all-in"` was a client-side literal with no
// writer, and it was also flatly wrong. FACT-CONFLICTS.md C-1 tracked two
// competing figures — the backend rate card's effective 1.4512% of
// consideration vs. the new canvas's ~0.37% — as unconfirmed. The product
// owner has since ruled (2026-08-29) in favour of the BACKEND rate card;
// the canvas's ~0.361–0.375% figures are now a recorded design error, not a
// competing truth. `fee` below reads `kTradingFeeDisplay`
// (lib/data/fees.dart) — the single place that confirmed rate lives on the
// mobile side — rather than a literal repeated per call site. This is a
// product-wide informational rate, not a per-order computation: a real
// order's own commission/VAT/total in ₦ is calculated and charged
// server-side, but `POST /orders`'s response type has no field carrying it
// back to a client (see BACKEND_GAPS.md's "buy/sell fees are unreachable"
// entry for the exact missing fields) — that's the exact defect class
// fees.ts's own header warns about (the app previously showed "Fees ·
// 1.35%" while the backend charged nothing at all), and it's why
// trade_flows.dart still carries no fee constant of its own.
//
// 2026-08-27: Order book tab built (R-18). At the time, no depth/order-book
// feed existed anywhere in this app's data layer — filed as a gap in
// docs/redesign/BACKEND_GAPS.md under s27.
//
// 2026-08-27 (later same day): the backend gained a real simulated order
// book (BR-5, SimulatedNgxBroker#getOrderBook, GET
// /assets/:ticker/order-book) — the BACKEND_GAPS.md entry above is now
// stale on the backend half and updated to say so. This tab's bid/ask rows
// and best-price cells still render nothing, because the mobile data layer
// (lib/data/**) has no OrderBook model or AssetRepository method, and a
// screen agent may not add one (screen-agent brief rule 5: lib/data/** is
// off-limits to a screen agent). Filed as SHARED-CHANGES.md request S-7,
// which names the exact model/method shape needed — S-7 landing plus a
// re-dispatch of this screen is what turns the tab's rows on. The tab
// still ships its real, data-free structure (tab bar, explainer copy,
// table header, Buy/Sell footer) plus the honest "depth unavailable" empty
// state where the rows would go, entered unconditionally: the mobile side
// has no path to fetch order-book data today. The liquidity call-out
// banner ("Easy"/"Hard to sell") stays omitted even after S-7 lands —
// SimulatedNgxBroker computes no liquidity tier, and the book is always
// exactly 5 levels a side, so no real signal exists to threshold on
// without inventing one.
//
// Also removed this pass: a hardcoded `MockData.mtnnSeries` fixture chart
// that only MTNN got, while every other ticker rendered its real
// `asset.sparkline` — a live-mock-data defect the `fake_data` gate now
// catches. MTNN gets the same real series as everything else.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/app/feature_flags.dart';
import 'dart:async';

import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/fees.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/realtime/realtime_client.dart';
import 'package:kudimata_invest/data/repositories/asset_repository.dart';
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/data/repositories/watchlist_repository.dart';
import 'market_hours.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/glossary_sheet.dart';
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
  late final RealtimeClient _realtime = AppScope.read(context).realtimeClient;
  late Future<(Asset asset, String? about, Holding? holding)> _future =
      _load(widget.ticker);

  /// The freshest known [Asset] — starts as whatever [_load] fetched, then
  /// kept live in place by `market:quote` (see file header's R-41
  /// paragraph). Preferred over the FutureBuilder's own snapshot, same
  /// override pattern every other R-41-wired screen uses.
  Asset? _liveAsset;

  StreamSubscription<RealtimeQuote>? _quoteSub;
  StreamSubscription<void>? _reconnectSub;

  @override
  void initState() {
    super.initState();
    _realtime.subscribeMarket([widget.ticker]);
    _quoteSub = _realtime.quotes.listen(_onQuote);
    // Refetches ONCE on reconnect — a quote missed while disconnected
    // can't be replayed. Deliberately does NOT reassign `_future`: that
    // would flip the FutureBuilder back to ConnectionState.waiting and
    // flash the whole screen to KLoadingView, same reason
    // home_screen.dart/wallet_screens.dart's own silent polls avoid it.
    // [_load] already updates [_liveAsset] as a side effect, which is all
    // this surface (market:quote) needs kept current.
    _reconnectSub = _realtime.reconnected.listen((_) => _load(widget.ticker));
  }

  /// Applies a decoded `market:quote` directly onto [_liveAsset] via
  /// AssetRepository.applyLiveQuote — no network call. Dropped if nothing
  /// has loaded yet ([_liveAsset] null); the in-flight initial [_future]
  /// covers that case moments later.
  void _onQuote(RealtimeQuote quote) {
    if (quote.ticker != widget.ticker) return;
    final base = _liveAsset;
    if (base == null || !mounted) return;
    setState(() {
      _liveAsset = AssetRepository.applyLiveQuote(
        base,
        priceKobo: quote.priceKobo,
        changeAbsKobo: quote.changeAbsKobo,
        changePct: quote.changePct,
      );
    });
  }

  @override
  void dispose() {
    _quoteSub?.cancel();
    _reconnectSub?.cancel();
    _realtime.unsubscribeMarket([widget.ticker]);
    super.dispose();
  }

  /// Combines the asset/about fetch with an optional holding lookup — see
  /// file header for why a 404 on the holding fetch is swallowed as "no
  /// position" while other failures propagate.
  Future<(Asset asset, String? about, Holding? holding)> _load(String ticker) async {
    final assetFuture = _repo.byTickerWithAbout(ticker);
    final holdingFuture = _fetchHolding(ticker);
    final (asset, about) = await assetFuture;
    final holding = await holdingFuture;
    if (mounted) setState(() => _liveAsset = asset);
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
            // s26/s27: name over an uppercase "TICKER · EXCHANGE" line,
            // left-aligned next to the back button, not a centred bare
            // ticker — and the trailing action is a plus/check toggle (adds
            // to the watchlist, kept per R-16), not an eye.
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
                  // s49's own caption: "From the asset page, or 'Set a price
                  // alert' on 39 Market closed" (X-7, SHARED-CHANGES.md
                  // 2026-08-27) — this is that entry point.
                  KIconButton(
                    icon: 'bell',
                    semanticLabel: 'Set a price alert',
                    onPressed: () => context.push(Routes.setPriceAlert(widget.ticker)),
                  ),
                  const SizedBox(width: 8),
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
                  // _liveAsset carries any market:quote update applied
                  // since [asset] was fetched (see file header) — same
                  // field, just current.
                  return _AssetDetailBody(asset: _liveAsset ?? asset, about: about, holding: holding);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two tabs s26/s27 draw on this screen. Local UI state only — nothing
/// backend-wired depends on which one is selected.
enum _AssetTab { about, orderBook }

/// The fetched-data half of the screen: tab bar (About / Order book), the
/// tab's own content, and the sticky Buy/Sell footer shared by both tabs (s26
/// and s27 both draw it identically). Stateful only to hold which tab is
/// selected — fed by [FutureBuilder]'s snapshot data instead of
/// `MockData.assetByTicker`.
class _AssetDetailBody extends StatefulWidget {
  const _AssetDetailBody({required this.asset, required this.about, required this.holding});

  final Asset asset;
  final String? about;

  /// Real position data via HoldingsRepository.byTicker (GET
  /// /holdings/:ticker), null when this investor doesn't hold this asset —
  /// see file header. The "your position" card below only renders when
  /// non-null.
  final Holding? holding;

  @override
  State<_AssetDetailBody> createState() => _AssetDetailBodyState();
}

class _AssetDetailBodyState extends State<_AssetDetailBody> {
  _AssetTab _tab = _AssetTab.about;

  @override
  Widget build(BuildContext context) {
    final holding = widget.holding;
    final asset = widget.asset;

    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              _TabBar(
                selected: _tab,
                onChanged: (t) => setState(() => _tab = t),
              ),
              Expanded(
                child: switch (_tab) {
                  _AssetTab.about => _AboutTab(asset: asset, about: widget.about, holding: holding),
                  _AssetTab.orderBook => _OrderBookTab(ticker: asset.ticker),
                },
              ),
            ],
          ),
        ),

        // sticky Buy / Sell footer — shared by both tabs (s26 and s27 both
        // draw it identically directly under the tab content). Order is
        // Buy (primary, left) then Sell (secondary outline, right), matching
        // s26/s27's markup in `03 Home and Markets.dc.html` exactly — no
        // ruling in DECISIONS.md authorises the reverse order this footer
        // shipped with (2026-08-29 repair pass).
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
                  label: 'Buy',
                  onPressed: () => showBuyFlow(context, asset),
                ),
              ),
              const SizedBox(width: 10),
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
            ],
          ),
        ),
      ],
    );
  }
}

/// s26/s27's tab bar — "About" / "Order book", underlined-indicator style,
/// hairline rule under the whole row. Screen-local (rule 5: no shared K*
/// tab widget exists anywhere in this app to reuse or fork).
class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onChanged});
  final _AssetTab selected;
  final ValueChanged<_AssetTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
      ),
      child: Row(
        children: [
          _TabLabel(
            label: 'About',
            selected: selected == _AssetTab.about,
            onTap: () => onChanged(_AssetTab.about),
          ),
          const SizedBox(width: 24),
          _TabLabel(
            label: 'Order book',
            selected: selected == _AssetTab.orderBook,
            onTap: () => onChanged(_AssetTab.orderBook),
          ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? KColor.indicator : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: KType.cardTitle(
            color: selected ? KColor.indicator : KColor.ink3,
            w: selected ? KWeight.bold : KWeight.semibold,
          ),
        ),
      ),
    );
  }
}

/// s26 — the About tab: hero price + range chart, the redesigned product
/// card, dividend/you-own row, and the About copy.
class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.asset, required this.about, required this.holding});

  final Asset asset;
  final String? about;
  final Holding? holding;

  KTrend _k(Trend t) => t == Trend.gain ? KTrend.gain : KTrend.loss;

  @override
  Widget build(BuildContext context) {
    final holding = this.holding;
    final marketOpen = AppScope.of(context).marketOpen;

    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        // 2026-08-24: this screen never showed any closed-market
        // indication at all (reported live as "markets dont show
        // closed too") — same banner markets_screen.dart shows. The
        // chart/price below stay as-is (last close, same as any
        // broker app shows outside trading hours) — only the small
        // live-look sparkline on the Markets LIST gets hidden when
        // closed, not this screen's real historical range chart.
        if (!marketOpen) ...[
          Padding(
            padding: _gut,
            child: KMarketClosedBanner(
              onSetAlert: () => context.push(Routes.setPriceAlert(asset.ticker)),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // price header — s26 is a hero price + change line directly on the
        // page background (no purple/ink feature panel here; that treatment
        // is reserved for wallet/portfolio balances), then a plain (not
        // onDark) chart defaulted to 1M. `asset.sparkline` for every ticker
        // — no more MTNN-only fixture (see file header, 2026-08-27).
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
                data: asset.sparkline,
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
        // (same Asset fields as the hero above). risk/liquidity/minimum
        // are real, product-wide constants — see file header. `fee` reads
        // kTradingFeeDisplay (lib/data/fees.dart) — see file header's
        // 2026-08-29 note (FACT-CONFLICTS.md C-1): the owner has ruled the
        // backend rate card is the confirmed figure.
        Padding(
          padding: _gut,
          child: KProductCard(
            name: asset.name,
            market: 'Ordinary shares · NGX Main Board',
            price: asset.price,
            change: asset.change,
            risk: KRiskTier.high,
            fee: kTradingFeeDisplay,
            liquidity: 'Daily · T+3',
            minimum: '₦5,000',
            // D-3 (SHARED-CHANGES.md, 2026-08-27 removals pass, R-6): the
            // AI-credits line is parked — null hides KProductCard's Explain
            // affordance entirely (see finance.dart's onExplain check).
            onExplain: kAiCreditsEnabled
                ? () => context.push(Routes.explainThis(asset.ticker))
                : null,
            onTapStat: (label) => showGlossaryExplainSheet(context, label),
          ),
        ),
        const SizedBox(height: 16),

        // Dividend yield / You own. s26 draws a plainer three-cell
        // From/Paid-out/Dividend row instead — this two-cell row is real
        // app content the artboard doesn't draw (see file header, kept per
        // the screen-agent brief's rule 2, reported rather than dropped).
        // Dividend yield has no backend field yet — see file header gap
        // note — so it renders "—" rather than a fabricated number; "You
        // own" is the real holding unit count, "0 shares" when this
        // investor doesn't hold the asset.
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
    );
  }
}

/// s27 — the Order book tab (R-18). S-7 (SHARED-CHANGES.md) landed the
/// mobile data layer's `OrderBook`/`OrderBookLevel` model
/// (lib/data/models.dart) and `AssetRepository.orderBook` (GET
/// /assets/:ticker/order-book), backed by BR-5's real simulated depth feed
/// (SimulatedNgxBroker#getOrderBook). This tab now fetches for real: a
/// FutureBuilder drives loading / error / populated bid-ask rows with
/// best-buy/best-sell cells, plus an empty state for the case both sides
/// come back with zero levels (never observed against the real backend,
/// which always returns 5 levels a side, but a real possible response
/// shape, not the old unconditional placeholder).
///
/// NOT included: s26/s27's "Easy to sell" / "Hard to sell quickly"
/// liquidity call-out banner (R-34/D-5) — SimulatedNgxBroker computes no
/// liquidity tier at all, and the book is always exactly 5 levels a side,
/// so no real signal exists to threshold "easy" vs "hard" on without
/// inventing one. Stays an omission pending a product ruling.
class _OrderBookTab extends StatefulWidget {
  const _OrderBookTab({required this.ticker});
  final String ticker;

  @override
  State<_OrderBookTab> createState() => _OrderBookTabState();
}

class _OrderBookTabState extends State<_OrderBookTab> {
  late final _repo = AssetRepository(AppScope.read(context).apiClient);
  late final RealtimeClient _realtime = AppScope.read(context).realtimeClient;
  late Future<OrderBook> _future = _load();

  /// The freshest known order book — kept live in place by
  /// `market:orderBook` (file header's R-41 paragraph). No `market:subscribe`
  /// call here: the parent [_AssetDetailScreenState] already subscribed to
  /// this ticker for the whole screen's lifetime, and `market:orderBook`
  /// rides that same room.
  OrderBook? _liveBook;

  StreamSubscription<OrderBook>? _bookSub;
  StreamSubscription<void>? _reconnectSub;

  Future<OrderBook> _load() async {
    final book = await _repo.orderBook(widget.ticker);
    if (mounted) setState(() => _liveBook = book);
    return book;
  }

  @override
  void initState() {
    super.initState();
    _bookSub = _realtime.orderBooks.listen(_onOrderBook);
    // See _AssetDetailScreenState's identical reconnect handling for why
    // this doesn't reassign `_future`.
    _reconnectSub = _realtime.reconnected.listen((_) => _load());
  }

  /// Applies a decoded `market:orderBook` directly — no network call.
  void _onOrderBook(OrderBook book) {
    if (book.ticker != widget.ticker || !mounted) return;
    setState(() => _liveBook = book);
  }

  @override
  void dispose() {
    _bookSub?.cancel();
    _reconnectSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 20, bottom: 24),
      children: [
        Padding(
          padding: _gut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Who's buying and selling", style: KType.cardTitle()),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  style: KType.body(color: KColor.ink2),
                  children: [
                    const TextSpan(
                      text: "Buyers name the price they'll pay. Sellers name the price they "
                          'want. A trade happens when they meet. ',
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: KGlossaryTerm(
                        text: 'Explain more',
                        style: KType.body(color: KColor.ink2),
                        onTap: () => showGlossaryExplainSheet(context, 'Order book'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: _gut,
          child: FutureBuilder<OrderBook>(
            future: _future,
            builder: (context, snapshot) {
              // Prefer the freshest known book (kept live by
              // market:orderBook, see file header) over the FutureBuilder's
              // own snapshot — same override pattern as this screen's own
              // [_liveAsset].
              final effective = _liveBook ?? snapshot.data;
              if (effective == null) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 180, child: KLoadingView());
                }
                if (snapshot.hasError) {
                  return SizedBox(
                    height: 260,
                    child: KErrorView(
                      onPrimary: () => setState(() => _future = _load()),
                    ),
                  );
                }
              }
              final book = effective!;
              // Empty when both sides come back with zero levels — a real
              // possible response shape (not observed against
              // SimulatedNgxBroker today, which always returns 5 levels a
              // side, but the model doesn't assume that — see OrderBook's
              // doc comment).
              if (book.bids.isEmpty && book.asks.isEmpty) {
                return const _OrderBookEmptyState();
              }
              return _OrderBookTable(book: book);
            },
          ),
        ),
      ],
    );
  }
}

/// The bordered bid/ask table s27 draws — column headers plus one row per
/// level, best-first on each side per the model's doc comment. Bids and
/// asks may have different counts; row count follows the longer side, empty
/// cells stay blank on the shorter one (never zero-padded, which would
/// invent a level that isn't there).
class _OrderBookTable extends StatelessWidget {
  const _OrderBookTable({required this.book});
  final OrderBook book;

  @override
  Widget build(BuildContext context) {
    final rowCount = book.bids.length > book.asks.length ? book.bids.length : book.asks.length;
    final bestBid = book.bids.isEmpty ? null : book.bids.first;
    final bestAsk = book.asks.isEmpty ? null : book.asks.first;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: KColor.hairline, width: 1),
            borderRadius: KRadii.cardR,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      color: KColor.gain.withValues(alpha: 0.12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Buyers',
                              style: KType.micro(color: KColor.gain, w: KWeight.bold)
                                  .copyWith(fontSize: 12)),
                          Text('Units',
                              style: KType.micro(color: KColor.ink3).copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: KColor.loss.withValues(alpha: 0.10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Units',
                              style: KType.micro(color: KColor.ink3).copyWith(fontSize: 12)),
                          Text('Sellers',
                              style: KType.micro(color: KColor.loss, w: KWeight.bold)
                                  .copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              for (var i = 0; i < rowCount; i++)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              i < book.bids.length ? _naira(book.bids[i].priceKobo) : '',
                              style: KType.cardTitle(color: KColor.gain, w: KWeight.bold)
                                  .copyWith(fontSize: 15)
                                  .tnum,
                            ),
                            Text(
                              i < book.bids.length ? _units(book.bids[i].units) : '',
                              style: KType.body(color: KColor.ink2).tnum,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: KColor.hairline, width: 1),
                            left: BorderSide(color: KColor.hairline, width: 1),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              i < book.asks.length ? _units(book.asks[i].units) : '',
                              style: KType.body(color: KColor.ink2).tnum,
                            ),
                            Text(
                              i < book.asks.length ? _naira(book.asks[i].priceKobo) : '',
                              style: KType.cardTitle(color: KColor.loss, w: KWeight.bold)
                                  .copyWith(fontSize: 15)
                                  .tnum,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _BestPriceCell(
                label: 'Best buy price',
                value: bestBid == null ? '—' : _naira(bestBid.priceKobo),
                color: KColor.gain,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BestPriceCell(
                label: 'Best sell price',
                value: bestAsk == null ? '—' : _naira(bestAsk.priceKobo),
                color: KColor.loss,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The "Best buy price" / "Best sell price" cells under the table.
class _BestPriceCell extends StatelessWidget {
  const _BestPriceCell({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border.all(color: KColor.hairline, width: 1),
        borderRadius: KRadii.cardR,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: KType.micro(color: KColor.ink3)),
          const SizedBox(height: 2),
          Text(value, style: KType.cardTitle(color: color, w: KWeight.bold).copyWith(fontSize: 15).tnum),
        ],
      ),
    );
  }
}

/// Empty state — reachable only if the backend ever responds with zero
/// levels on both sides (not observed against SimulatedNgxBroker today,
/// which always returns 5 a side — see class doc above).
class _OrderBookEmptyState extends StatelessWidget {
  const _OrderBookEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: KColor.hairline, width: 1),
        borderRadius: KRadii.cardR,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  color: KColor.gain.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Buyers',
                          style:
                              KType.micro(color: KColor.gain, w: KWeight.bold).copyWith(fontSize: 12)),
                      Text('Units', style: KType.micro(color: KColor.ink3).copyWith(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: KColor.loss.withValues(alpha: 0.10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Units', style: KType.micro(color: KColor.ink3).copyWith(fontSize: 12)),
                      Text('Sellers',
                          style:
                              KType.micro(color: KColor.loss, w: KWeight.bold).copyWith(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: const KEmptyView(
              icon: 'markets',
              title: 'Depth unavailable',
              message: "There's no live buy and sell order data for this stock right now.",
            ),
          ),
        ],
      ),
    );
  }
}

/// Minor-unit integer (kobo) -> "₦1,234.56" — same convention as
/// contract_note_screen.dart's `_naira` (per S-7: this model carries raw
/// ints, the screen formats them).
String _naira(int kobo) {
  final v = (kobo / 100).toStringAsFixed(2);
  final parts = v.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '₦$whole.${parts[1]}';
}

/// Thousands-separated unit count — e.g. 1200 -> "1,200".
String _units(int units) => units.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// The "Dividend yield" / "You own" cell on s26's About tab — a bordered
/// paper tile, distinct from [KStatCard] (which also carries an optional
/// icon this cell never does).
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

