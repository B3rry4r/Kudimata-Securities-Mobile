// Watchlist (pushed) — saved assets fetched live from GET /watchlist-items
// (WatchlistRepository) as KAssetRows with a remove control; empty state when
// nothing is saved. Ported from app-screens.jsx `Watchlist` / `WatchlistEmpty`.
// Pushed screen: Scaffold + KDetailHeader.
//
// Source of truth: the server. AppState.watchlistTickers/toggleWatch are
// still flipped here for immediate optimistic UI feedback (they're shared
// with other screens — home, asset-detail — that read them for local toggle
// state), but the remove control now also fires DELETE /watchlist-items/:ticker
// and, on failure, reverts the optimistic local flip and re-fetches the list
// so the screen never drifts from what the server actually has saved.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/watchlist_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  late final _repo = WatchlistRepository(AppScope.read(context).apiClient);
  late Future<List<Asset>> _future = _repo.items();

  KTrend _k(Trend t) => t == Trend.gain ? KTrend.gain : KTrend.loss;

  /// Optimistic remove: flips local AppState immediately for instant UI
  /// feedback (other screens read the same AppState.watchlistTickers), then
  /// fires the real DELETE. On failure, reverts the local flip and refetches
  /// the list from the server — the server stays the source of truth.
  Future<void> _removeTicker(String ticker) async {
    final app = AppScope.read(context);
    app.removeWatch(ticker);
    setState(() {}); // reflect the optimistic removal in this screen's list immediately
    try {
      await _repo.remove(ticker);
    } on ApiException catch (e) {
      if (!mounted) return;
      app.addWatch(ticker); // revert the optimistic local toggle
      setState(() => _future = _repo.items());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: const KDetailHeader(title: 'Watchlist'),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _repo.items());
          await _future;
        },
        child: FutureBuilder<List<Asset>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const KLoadingView();
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  KErrorView(
                    onPrimary: () => setState(() => _future = _repo.items()),
                  ),
                ],
              );
            }
            final items = snapshot.data ?? const <Asset>[];
            if (items.isEmpty) {
              return ListView(
                children: [_empty(context)],
              );
            }
            return _list(context, items);
          },
        ),
      ),
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
                          // Screen 46 shows "TICKER · added 12 Mar" — the
                          // watchlist API has no "date added" field on its
                          // Asset resource, so that half of the ticker line
                          // is a genuine backend gap (like the asset-detail
                          // and product-card gaps elsewhere in this app),
                          // not fabricated here.
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
                          onTap: () => _removeTicker(items[i].ticker),
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
        const SizedBox(height: 16),
        Padding(
          padding: _gut,
          child: KNudgeCard(
            tone: KNudgeTone.sun,
            title: 'Price alerts',
            body: "We'll notify you if a name on this list moves more than 5% in a day. Nothing else — no daily noise.",
            // Screen 86 (s86.html) — per-asset alert thresholds, now wired
            // to a real PriceAlert CRUD backend (see
            // price_alerts_screen.dart's header). The threshold/on-off state
            // itself is genuinely saved server-side; that backend's own
            // notification-delivery scheduler isn't wired yet, so this
            // card's "We'll notify you..." promise is currently ahead of
            // what actually fires — flagged in price_alerts_screen.dart's
            // header rather than rewritten here, since this screen is owned
            // by concurrent work outside this change's scope.
            action: KButton(
              label: 'Manage price alerts',
              variant: KButtonVariant.secondary,
              onPressed: () => context.push(Routes.priceAlerts),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // "Find more on the NGX" (spec 46) — was only present on the empty
        // state's own "Browse markets" button; the populated list had no
        // equivalent way to jump to Markets. Primary, per the mock (no
        // `variant` attribute on that Button import — it was wrongly ghost).
        Padding(
          padding: _gut,
          child: KButton(
            label: 'Find more on the NGX',
            onPressed: () => context.go(Routes.markets),
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
          const KIllustration('empty-watchlist', role: KIlloRole.state),
          const SizedBox(height: 22),
          Text('Nothing saved yet', style: KType.title()),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text('Save a stock to follow its price and changes here.',
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
