// Search (pushed) — back chevron + KSearchPill, recent chips, live results and
// a NudgeCard. Ported from extra-screens.jsx `Search`. Per the canvas (#s31),
// there is no "Trending" section on this screen at all — that existed in an
// earlier port and has been removed; Markets owns trending.
//
// Wired to GET /assets (AssetRepository.byAssetClass(null), fetched once —
// not a server-side search endpoint) for the local string-filter list. Per
// Kudimata-Securities-Backend/.pipeline/fragments/search.json, this screen
// is local-filter-only: no debounce, no query param ever leaves the widget,
// filtering is a synchronous getter over the already-fetched list.
//
// Bug fix: the mock version hardcoded `.where((a) => a.assetClass ==
// AssetClass.ngx)`, so US stocks/ETFs could never appear in search even
// though they're in scope and reachable from Markets/asset-detail. Fetching
// the full universe via byAssetClass(null) (instead of a single NGX-only
// list) fixes that — the local filter below no longer narrows by class.
//
// "Recent" chips are real, locally-persisted search history (shared_preferences
// — plain on-device key-value storage, not a backend concern) rather than the
// old hardcoded MTNN/GTCO/ZENITHBANK literals. The last up-to-5 unique terms
// the investor actually selected are stored newest-first; a fresh install has
// none, so the section is simply omitted until the investor searches once.
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

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);
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
            // header row: back + search pill. Canvas (#s31): padding
            // "14px 20px 6px", gap:12 between the back button and the pill —
            // was an asymmetric 8/8/20/8 padding with a 10px gap.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  KIconButton(
                    icon: 'back',
                    semanticLabel: 'Back',
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KSearchPill(
                      placeholder: 'Search NGX companies',
                      controller: _controller,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _content(hasQuery)),
            // Canvas footer: ghost "Browse all of the market", pinned below
            // the scrolling content (margin-top:auto), NOT swapped out once
            // there's a query — the canvas's own query-state frame (#s31,
            // pre-filled "dang") still shows this button.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: KButton(
                label: 'Browse all of the market',
                variant: KButtonVariant.ghost,
                fullWidth: true,
                onPressed: () {
                  context.pop();
                  context.go(Routes.markets);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Canvas (#s31) stacks, top to bottom: a "Results" section (only present
  /// once there's a query — the annotation is explicit: "empty search →
  /// this screen with the nudge only"), then "Recent" chips, then the
  /// NudgeCard — all in ONE scrolling column, not two mutually-exclusive
  /// screens. There is no "Trending" section anywhere on this screen (that
  /// was invented by an earlier port) — Results replaces it once the
  /// investor types something.
  Widget _content(bool hasQuery) {
    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      children: [
        if (hasQuery) ...[
          _resultsSection(),
          const SizedBox(height: 24),
        ],
        // Fresh install / no searches yet → omit the section entirely
        // rather than show stale hardcoded tickers.
        if (_recents.isNotEmpty) ...[
          const Padding(padding: _gut, child: KEyebrow('Recent')),
          const SizedBox(height: 10),
          Padding(
            padding: _gut,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in _recents)
                  KPillChip(
                    label: r,
                    onTap: () {
                      _controller.text = r;
                      setState(() => _query = r);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        Padding(
          padding: _gut,
          child: KNudgeCard(
            tone: KNudgeTone.grape,
            title: 'Not sure what to search for?',
            body: "Try a sector — banking, telecoms, cement — and we'll show the NGX-listed companies in it.",
          ),
        ),
      ],
    );
  }

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
        return Column(
          children: [
            const Padding(padding: _gut, child: KEyebrow('Results')),
            const SizedBox(height: 8),
            Padding(padding: _gut, child: _card(results)),
          ],
        );
      },
    );
  }

  Widget _card(List<Asset> assets) {
    return KCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < assets.length; i++)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: i == 0
                      ? BorderSide.none
                      : BorderSide(color: KColor.hairline, width: 1),
                ),
              ),
              child: KAssetRow(
                name: assets[i].name,
                ticker: assets[i].sector == null
                    ? assets[i].ticker
                    : '${assets[i].ticker} · ${assets[i].sector}',
                initialsSource: assets[i].ticker,
                price: assets[i].price,
                change: assets[i].change,
                trend: _k(assets[i].trend),
                logoColor: assets[i].logoColor ?? KColor.ink,
                onTap: () => _open(assets[i].ticker),
              ),
            ),
        ],
      ),
    );
  }
}
