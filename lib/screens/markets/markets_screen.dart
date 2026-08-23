// Markets tab root — title, read-only SearchPill (pushes Search), trending +
// the asset list. Ported from app-screens.jsx `Markets`. Root tab: Scaffold
// body WITHOUT bottom nav (the shell owns it).
//
// The search bar's filter icon and the All/NGX category pills were removed
// (user directive 2026-08-07) — there's nothing meaningful left to filter by
// as a top-level category now that the catalog is NGX (+ETF) only, and the
// filter icon just duplicated tapping the search pill itself (both opened
// the same Search screen). This is a deliberate, previously-approved
// divergence from the "Soft Landing" mockup's spec screen 32 (which shows a
// SegmentedControl + category PillChips) — not reinstated during the
// 2026-08-22 exactness pass, since re-adding filter controls with nothing
// real behind them would be a fake affordance, not a fix.
//
// GENUINE GAP (2026-08-22 exactness pass): spec screen 32 also shows an
// "NGX All-Share" index row (value, % change, "Open · closes 14:30") above
// Trending. No index-level data source exists anywhere in this app or its
// repositories (AssetRepository only has per-instrument quotes) — this is
// NOT built here, since faking a market index figure would mean showing an
// investor a fictional number. Needs a real backend field before it can
// ship; see docs/redesign/PLAN.md.
//
// Wired to GET /assets/trending and GET /assets via
// AssetRepository.trending()/.byAssetClass(null) (see lib/data/api/README.md
// for the FutureBuilder convention this follows).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/asset_repository.dart';
import 'market_hours.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

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
    // Flow G, spec screen 60 — "Markets · closed". A client-side heuristic
    // (see market_hours.dart's header comment); computed once per build,
    // not polled, since a stale-by-a-few-minutes open/closed banner is
    // harmless and this screen already rebuilds on every navigation to it.
    final marketOpen = isNgxOpenNow();

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
                    placeholder: 'Search NGX companies',
                    readOnly: true,
                    onTap: () => context.push(Routes.search),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (!marketOpen) ...[
              Padding(
                padding: _gut,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: KColor.track, borderRadius: KRadii.cardR),
                  child: Row(
                    children: [
                      KIcon('clock', size: 18, color: KColor.ink2),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('The NGX is closed', style: KType.cardTitle()),
                            const SizedBox(height: 2),
                            Text('Opens tomorrow at 10:00 · prices below are from the last close',
                                style: KType.micro(color: KColor.ink3)),
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
                  tone: KNudgeTone.grape,
                  title: 'You can still place an order',
                  body: 'It queues for 10:00 tomorrow and fills at the opening price, which may differ from what you see now.',
                ),
              ),
            ],
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
