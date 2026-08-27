// Search (pushed) — back chevron + KSearchPill, live local-filter results
// list (AssetRow), and a real "Popular this week" trending-ticker chip row.
// Artboard: s25 / s25d (docs/design/redesign-2026-08/03 Home and
// Markets.dc.html) — id per docs/redesign/RULINGS.md, never from a code
// comment (R-5).
//
// Wired to GET /assets (AssetRepository.byAssetClass(null), fetched once —
// not a server-side search endpoint) for the local string-filter list. Per
// Kudimata-Securities-Backend/.pipeline/fragments/search.json, this screen
// is local-filter-only: no debounce, no query param ever leaves the widget,
// filtering is a synchronous getter over the already-fetched list.
//
// 2026-08-27 redesign to s25: the canvas draws no "Recent" search-history
// section and no footer CTA at all — it draws exactly header, results, and
// a "Popular this week" chip row. The old locally-persisted 'Recent' chips
// (shared_preferences) and the "Browse all of the market" footer button are
// both dropped to match; recents was a local convenience with no design
// backing and no backend tie, unlike Cancel on the Orders hub (R-17), so
// nothing here needed a ruling to remove. "Popular this week" is wired to
// the real GET /assets/trending (AssetRepository.trending()) rather than
// the canvas's illustrative MTNN/GTCO/ZENITHBANK/AIRTELAFRI literals — a
// designed chip row with no data source would be exactly the R-34 defect
// (a figure with nothing writing it), so it reads from the real trending
// list instead of transcribing the mock tickers.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/asset_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  late final _repo = AssetRepository(AppScope.read(context).apiClient);
  late Future<List<Asset>> _assetsFuture = _repo.byAssetClass(null);
  late final Future<List<Asset>> _trendingFuture = _repo.trending();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  KTrend _k(Trend t) => t == Trend.gain ? KTrend.gain : KTrend.loss;

  List<Asset> _filter(List<Asset> assets) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return assets
        .where((a) =>
            a.name.toLowerCase().contains(q) || a.ticker.toLowerCase().contains(q))
        .toList();
  }

  void _open(String ticker) {
    context.push(Routes.assetDetail(ticker));
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // s25: "display:flex;align-items:center;gap:10px;padding:14px
            // 20px 0" — gap 10 (not 12), bottom 0 (not 6).
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  KIconButton(
                    icon: 'back',
                    semanticLabel: 'Back',
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KSearchPill(
                      placeholder: 'Search companies',
                      controller: _controller,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _content(hasQuery)),
          ],
        ),
      ),
    );
  }

  /// s25 stacks, top to bottom: results (only meaningfully present once
  /// there's a query — an empty query has nothing to filter) then "Popular
  /// this week". Both a query with zero matches and the trending fetch
  /// itself are non-happy states this screen owns (R-30 — the canvas
  /// designs none of them).
  Widget _content(bool hasQuery) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (hasQuery) _resultsSection(),
        _popularSection(),
      ],
    );
  }

  /// s25: "padding:18px 12px 0" straight into AssetRow results — no
  /// "Results" eyebrow, no card/border wrapper. Just-in-time top hairline
  /// dividers between rows, same convention as every other flat list here.
  Widget _resultsSection() {
    return FutureBuilder<List<Asset>>(
      future: _assetsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: KLoadingView(),
          );
        }
        if (snapshot.hasError) {
          return KErrorView(
            onPrimary: () => setState(() => _assetsFuture = _repo.byAssetClass(null)),
          );
        }
        final results = _filter(snapshot.data!);
        if (results.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              children: [
                Text('No matches', style: KType.cardTitle(w: KWeight.semibold)),
                const SizedBox(height: 8),
                Text('Try a ticker like MTNN, GTCO or DANGCEM.',
                    textAlign: TextAlign.center,
                    style: KType.body(color: KColor.ink2)),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
          child: Column(
            children: [
              for (var i = 0; i < results.length; i++)
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: i == 0
                          ? BorderSide.none
                          : BorderSide(color: KColor.hairline, width: 1),
                    ),
                  ),
                  child: KAssetRow(
                    name: results[i].name,
                    ticker: results[i].sector == null
                        ? results[i].ticker
                        : '${results[i].ticker} · ${results[i].sector}',
                    initialsSource: results[i].ticker,
                    price: results[i].price,
                    change: results[i].change,
                    trend: _k(results[i].trend),
                    logoColor: results[i].logoColor ?? KColor.ink,
                    onTap: () => _open(results[i].ticker),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// s25: "padding:24px 24px 0", eyebrow "Popular this week" + a wrapped
  /// chip row (gap 10), each chip navigating straight to asset detail.
  /// Backed by the real GET /assets/trending — see the file header for why
  /// this isn't the canvas's literal illustrative tickers.
  Widget _popularSection() {
    return FutureBuilder<List<Asset>>(
      future: _trendingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KEyebrow('Popular this week'),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < 4; i++)
                      const KSkeleton(width: 84, height: 36, radius: 999),
                  ],
                ),
              ],
            ),
          );
        }
        // Error or an empty trending list: this is a secondary, decorative
        // rail (not the screen's primary content, unlike the results list
        // above), so the whole section — eyebrow included — degrades to
        // nothing rather than a full-screen error; there is no other
        // content on this screen for a KErrorView to sit beside without
        // crowding out the search box the investor came here to use.
        if (snapshot.hasError || (snapshot.data?.isEmpty ?? true)) {
          return const SizedBox.shrink();
        }
        final trending = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const KEyebrow('Popular this week'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final asset in trending)
                    KPillChip(label: asset.ticker, onTap: () => _open(asset.ticker)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
