// Markets tab root — title, read-only SearchPill (pushes Search), trending +
// the asset list. Ported from app-screens.jsx `Markets`. Root tab: Scaffold
// body WITHOUT bottom nav (the shell owns it).
//
// The search bar's filter icon and the All/NGX category pills were removed
// (user directive 2026-08-07) — there's nothing meaningful left to filter by
// as a top-level category now that the catalog is NGX (+ETF) only, and the
// filter icon just duplicated tapping the search pill itself (both opened
// the same Search screen).
//
// Wired to GET /assets/trending and GET /assets via
// AssetRepository.trending()/.byAssetClass(null) (see lib/data/api/README.md
// for the FutureBuilder convention this follows).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/models.dart';
import 'package:kudimata_securities/data/repositories/asset_repository.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/screens/shared/state_views.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  late final _repo = AssetRepository(AppScope.read(context).apiClient);

  late Future<List<Asset>> _trendingFuture = _repo.trending();
  late Future<List<Asset>> _listFuture = _repo.byAssetClass(null);

  KTrend _k(Trend t) => t == Trend.gain ? KTrend.gain : KTrend.loss;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          // Tab root: clear the floating KBottomNav (~70px + 12 margin + safe area).
          padding: const EdgeInsets.only(top: 14, bottom: 100),
          children: [
            Padding(
              padding: _gut,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Markets', style: KType.title()),
                  const SizedBox(height: 16),
                  KSearchPill(
                    placeholder: 'Search stocks',
                    readOnly: true,
                    onTap: () => context.push(Routes.search),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // trending
            Padding(
              padding: _gut,
              child: Row(
                children: [
                  const KEyebrow('Trending'),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push(Routes.assetList),
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      'See all'.upper,
                      style: KType.micro(
                        color: KColor.ink2,
                        w: KWeight.semibold,
                      ).copyWith(letterSpacing: 0.06 * 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: _gut,
              child: _asyncCard(
                _trendingFuture,
                spark: false,
                onRetry: () =>
                    setState(() => _trendingFuture = _repo.trending()),
              ),
            ),
            const SizedBox(height: 28),

            // the full list
            const Padding(
              padding: _gut,
              child: KEyebrow('All assets'),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: _gut,
              child: _asyncCard(
                _listFuture,
                spark: true,
                onRetry: () =>
                    setState(() => _listFuture = _repo.byAssetClass(null)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// FutureBuilder wrapper shared by the Trending block and the filtered
  /// list — same loading/error/empty states either way, per
  /// lib/data/api/README.md's canonical pattern.
  Widget _asyncCard(
    Future<List<Asset>> future, {
    required bool spark,
    required VoidCallback onRetry,
  }) {
    return FutureBuilder<List<Asset>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const KLoadingView();
        }
        if (snapshot.hasError) {
          return KErrorView(onPrimary: onRetry);
        }
        final data = snapshot.data!;
        if (data.isEmpty) {
          return const KEmptyView(
            icon: 'markets',
            title: 'No assets found',
            message: 'There are no assets to show in this category right now.',
          );
        }
        return _card(data, spark: spark);
      },
    );
  }

  Widget _card(List<Asset> assets, {required bool spark}) {
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
                sparkline: spark ? assets[i].sparkline : null,
                onTap: () => context.push(Routes.assetDetail(assets[i].ticker)),
              ),
            ),
        ],
      ),
    );
  }
}
