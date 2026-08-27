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
// a "Popular this week" chip row. A first redesign pass dropped the old
// locally-persisted 'Recent' chips (shared_preferences) and the "Browse all
// of the market" footer button to match. "Popular this week" is wired to
// the real GET /assets/trending (AssetRepository.trending()) rather than
// the canvas's illustrative MTNN/GTCO/ZENITHBANK/AIRTELAFRI literals — a
// designed chip row with no data source would be exactly the R-34 defect
// (a figure with nothing writing it), so it reads from the real trending
// list instead of transcribing the mock tickers.
//
// 2026-08-27, ruling R-39 (closes B-6): recents are restored beneath
// "Popular this week" — the owner ruled KEEP BOTH, s25 drawing only the
// trending row was not a decision to drop the app's own locally-persisted
// search history. Recovered from git history (9a8e6c1, the commit before
// the redesign pass above dropped it) rather than rewritten: same
// shared_preferences-backed store, same up-to-5-unique-newest-first cap,
// same de-dupe, same "tap fills the search box" tap behaviour — only the
// presentation is restyled to this screen's current idiom (KEyebrow +
// s25's own 24px section padding/10px chip gap, matching
// [_popularSection] exactly, not the pre-redesign screen's 20px gutter/8px
// gap). The footer "Browse all of the market" CTA stays dropped — R-39
// only restores recents, and s25 still draws no footer at all. Still no
// "Trending" section anywhere on this screen; "Popular this week" already
// covers that role.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/asset_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _recentsKey = 'kudimata.search.recents';
const _maxRecents = 5;

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  List<String> _recents = const [];

  late final _repo = AssetRepository(AppScope.read(context).apiClient);
  late Future<List<Asset>> _assetsFuture = _repo.byAssetClass(null);
  late final Future<List<Asset>> _trendingFuture = _repo.trending();

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_recentsKey) ?? const [];
    if (!mounted) return;
    setState(() => _recents = saved);
  }

  /// Records [term] as the newest recent search — de-duped case-insensitively,
  /// capped at [_maxRecents], newest first. Called when the investor selects
  /// a search result (see [_open]).
  Future<void> _addRecent(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    final updated = [
      trimmed,
      ..._recents.where((r) => r.toLowerCase() != trimmed.toLowerCase()),
    ].take(_maxRecents).toList();
    setState(() => _recents = updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentsKey, updated);
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
    _addRecent(ticker);
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
  ///
  /// R-39: "Recent" comes back beneath "Popular this week" — a locally
  /// persisted section, independent of both the query and the trending
  /// fetch, so it's appended unconditionally rather than folded into either
  /// FutureBuilder above it.
  Widget _content(bool hasQuery) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (hasQuery) _resultsSection(),
        _popularSection(),
        _recentSection(),
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

  /// R-39 (closes B-6): locally-persisted search history, restored beneath
  /// "Popular this week" — recovered from git history (see file header),
  /// restyled to this screen's current idiom rather than the pre-redesign
  /// screen's own. Same padding/eyebrow/chip-gap treatment as
  /// [_popularSection] immediately above it, so the two read as one family
  /// of chip rows rather than two different eras of this screen. A fresh
  /// install / no searches made yet has nothing to show, so — same as
  /// [_popularSection]'s empty/error branch — the section is omitted
  /// entirely rather than rendering an empty eyebrow.
  Widget _recentSection() {
    if (_recents.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KEyebrow('Recent'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final term in _recents)
                KPillChip(
                  label: term,
                  onTap: () {
                    _controller.text = term;
                    setState(() => _query = term);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
