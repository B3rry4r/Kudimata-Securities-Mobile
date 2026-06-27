// Search (pushed) — back chevron + KSearchPill, recent chips, and live results /
// trending list. Tapping a row pushes the asset detail. Ported from
// extra-screens.jsx `Search`, extended with live filtering over MockData.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/data/mock.dart';
import 'package:kudimata_securities/data/models.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);
const _recents = ['MTNN', 'GTCO', 'AAPL'];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  KTrend _k(Trend t) => t == Trend.gain ? KTrend.gain : KTrend.loss;

  List<Asset> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return MockData.allAssets
        .where((a) =>
            a.name.toLowerCase().contains(q) || a.ticker.toLowerCase().contains(q))
        .toList();
  }

  void _open(String ticker) => context.push(Routes.assetDetail(ticker));

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // header row: back + search pill
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, KSpace.gutter, 8),
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
                      placeholder: 'Search stocks, ETFs',
                      controller: _controller,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: hasQuery ? _resultsList() : _idleSections(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _idleSections() {
    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      children: [
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
        const Padding(padding: _gut, child: KEyebrow('Trending')),
        const SizedBox(height: 8),
        Padding(padding: _gut, child: _card(MockData.trending)),
      ],
    );
  }

  Widget _resultsList() {
    final results = _results;
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          children: [
            Text('No matches', style: KType.cardTitle(w: KWeight.semibold)),
            const SizedBox(height: 8),
            Text('Try a ticker like MTNN, AAPL or VOO.',
                textAlign: TextAlign.center,
                style: KType.body(color: KColor.ink2)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        Padding(padding: _gut, child: _card(results)),
      ],
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
                ticker: assets[i].ticker,
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
