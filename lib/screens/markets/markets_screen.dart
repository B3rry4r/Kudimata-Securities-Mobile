// Markets tab root — title + search icon-button, SegmentedControl
// (Shares/ETFs), sector PillChip row, one unified asset list. Ported from
// canvas screen 32 ("Markets · NGX", open) / 60 ("Markets · closed"). Root
// tab: Scaffold body WITHOUT a bottom nav — the shell owns it.
//
// 2026-08-24 rebuild: the prior version (a search PILL, no segmented
// control, no sector chips, a fabricated Trending/"All assets" split) was a
// real, confirmed deviation from the canvas — not a defensible adaptation.
// It's rebuilt here to match screens 32/60 structurally:
//   header: "Markets" title (text-title) + search IconButton (not a pill)
//   SegmentedControl: "Shares" (NGX ordinary shares) / "ETFs" — no "Bonds"
//     segment, since this product carries no fixed income instruments at
//     all (AssetClass is ngx/us/etf only; "us" isn't offered in this tab,
//     see AssetRepository/asset seed — NGX-only per product direction).
//   PillChip row: "All" + each distinct real `Asset.sector` value present
//     in the loaded Shares list (Banking/Telecoms/Consumer Goods/etc. — a
//     real backend column added 2026-08-24, not fabricated categories with
//     nothing behind them). Sectors don't apply to ETFs, so the row only
//     shows on the Shares segment.
//   one unified AssetRow list, filtered by segment + selected sector.
//
// GENUINE GAP (kept, not silently dropped): canvas's "NGX All-Share
// 104,562.18 · +0.84% today · Open · closes 14:30" index row is NOT built.
// The NGX All-Share Index is a specific real, published NGX figure this app
// has no live feed for — AssetRepository only has per-instrument quotes.
// Rendering a fabricated index number would show the investor a fictional
// figure, which is worse than the gap. Flagged in docs/redesign/
// BACKEND_GAPS.md — needs a real NGX index data source before it can ship.
//
// Wired to GET /assets via AssetRepository.byAssetClass (see
// lib/data/api/README.md for the FutureBuilder convention this follows).
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

/// NGX's own daily trading close — a real, fixed market-hours constant
/// (already used identically by this screen's own "Open · closes 14:30" /
/// "Opens tomorrow at 10:00" banners), not per-instrument data.
const _ngxCloseTime = '14:30';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  late final _repo = AssetRepository(AppScope.read(context).apiClient);

  late Future<List<Asset>> _sharesFuture = _repo.byClass(AssetClass.ngx);
  late Future<List<Asset>> _etfsFuture = _repo.byClass(AssetClass.etf);

  String _segment = 'Shares';
  String _sector = 'All';

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
              child: Row(
                children: [
                  Expanded(child: Text('Markets', style: KType.title())),
                  KIconButton(
                    icon: 'search',
                    semanticLabel: 'search',
                    onPressed: () => context.push(Routes.search),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (!marketOpen) ...[
              Padding(
                padding: _gut,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: KColor.track, borderRadius: KRadii.cardR),
                  child: Row(
                    children: [
                      KIcon('clock', size: 18, color: KColor.ink2),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('The NGX is closed', style: KType.cardTitle()),
                            const SizedBox(height: 2),
                            Text(
                              "Opens tomorrow at 10:00 · prices below are Friday's close",
                              style: KType.data(color: KColor.ink2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            Padding(
              padding: _gut,
              child: KSegmentedControl(
                options: const [
                  KSegmentOption(value: 'Shares', label: 'Shares'),
                  KSegmentOption(value: 'ETFs', label: 'ETFs'),
                ],
                value: _segment,
                onChanged: (v) => setState(() {
                  _segment = v;
                  _sector = 'All';
                }),
              ),
            ),
            const SizedBox(height: 12),

            if (_segment == 'Shares')
              FutureBuilder<List<Asset>>(
                future: _sharesFuture,
                builder: (context, snapshot) {
                  final sectors = (snapshot.data ?? const <Asset>[])
                      .map((a) => a.sector)
                      .whereType<String>()
                      .toSet()
                      .toList()
                    ..sort();
                  if (sectors.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: _gut,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            KPillChip(
                              label: 'All',
                              selected: _sector == 'All',
                              onTap: () => setState(() => _sector = 'All'),
                            ),
                            for (final s in sectors)
                              KPillChip(
                                label: s,
                                selected: _sector == s,
                                onTap: () => setState(() => _sector = s),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),

            Padding(
              padding: _gut,
              child: _segment == 'Shares'
                  ? _asyncCard(
                      _sharesFuture,
                      onRetry: () =>
                          setState(() => _sharesFuture = _repo.byClass(AssetClass.ngx)),
                      marketOpen: marketOpen,
                      sectorFilter: _sector == 'All' ? null : _sector,
                    )
                  : _asyncCard(
                      _etfsFuture,
                      onRetry: () => setState(() => _etfsFuture = _repo.byClass(AssetClass.etf)),
                      marketOpen: marketOpen,
                      sectorFilter: null,
                    ),
            ),

            if (!marketOpen) ...[
              const SizedBox(height: 16),
              Padding(
                padding: _gut,
                child: KNudgeCard(
                  tone: KNudgeTone.grape,
                  title: 'You can still place an order',
                  body:
                      'It queues for 10:00 tomorrow and fills at the opening price, which may differ from what you see now.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// FutureBuilder wrapper — same loading/error/empty states per
  /// lib/data/api/README.md's canonical pattern.
  Widget _asyncCard(
    Future<List<Asset>> future, {
    required VoidCallback onRetry,
    required bool marketOpen,
    required String? sectorFilter,
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
        final data = sectorFilter == null
            ? snapshot.data!
            : snapshot.data!.where((a) => a.sector == sectorFilter).toList();
        if (data.isEmpty) {
          return const KEmptyView(
            icon: 'markets',
            title: 'No assets found',
            message: 'There are no assets to show in this category right now.',
          );
        }
        return _card(data, marketOpen: marketOpen);
      },
    );
  }

  Widget _card(List<Asset> assets, {required bool marketOpen}) {
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
                ticker: marketOpen ? assets[i].ticker : '${assets[i].ticker} · closed at $_ngxCloseTime',
                initialsSource: marketOpen ? null : assets[i].ticker,
                price: assets[i].price,
                change: assets[i].change,
                trend: _k(assets[i].trend),
                logoColor: assets[i].logoColor ?? KColor.ink,
                sparkline: marketOpen ? assets[i].sparkline : null,
                onTap: () => context.push(Routes.assetDetail(assets[i].ticker)),
              ),
            ),
        ],
      ),
    );
  }
}
