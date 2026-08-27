// Markets tab root — artboard s24 (light) / s24d (dark),
// docs/design/redesign-2026-08/03 Home and Markets.dc.html. Root tab:
// Scaffold body WITHOUT a bottom nav — the shell owns it.
//
// 2026-08-27 rebuild against s24 (taken from the build queue, NOT from any
// in-code comment — see DECISIONS.md R-5: the "screen 32/60" ids this file
// used to cite are from the OLD 97-screen canvas and point at unrelated
// screens in the current one). s24's structure, top to bottom:
//   header: "Markets" title + a market-status pill (dot + "Open till
//     4:30pm") — NOT a search icon button.
//   a full-width SearchPill ("Search companies"), tap → search screen.
//   a "Market mood today" feature card: eyebrow, "Green day"/"Red day"
//     headline, "N up · N down" line, growth illustration.
//   sector PillChip row: "All" + each distinct real `Asset.sector` value
//     present in the loaded list (a real backend column, not fabricated
//     categories with nothing behind them — kept from the prior version of
//     this file, still correct against s24's own equivalent row).
//   "Biggest gainers" — horizontal scroll of the top real gainers.
//   "All companies" — a flat list (no card chrome), filtered by sector.
//
// GENUINE GAP, filed in docs/redesign/BACKEND_GAPS.md (s24): the mood
// card's copy is "32 up · 14 down · NGX All-Share +1.4%" — the NGX
// All-Share index is a specific real, published NGX figure this app has no
// live feed for (AssetRepository only has per-instrument quotes). Up/down
// counts ARE built (real, computed from the loaded asset list); the index
// clause is left off rather than shown as a fabricated number.
//
// 2026-08-24, still true: ETFs removed per direct product instruction —
// "remove ETFs, just shares for now". NGX ordinary shares only,
// `AssetClass.ngx` is the only universe this screen fetches.
//
// Wired to GET /assets via AssetRepository.byAssetClass (see
// lib/data/api/README.md for the FutureBuilder convention this follows).
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
/// (already used identically by this screen's own "Open till 4:30pm" /
/// "Opens tomorrow at 10:00" banners), not per-instrument data.
const _ngxCloseTime = '4:30pm';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  late final _repo = AssetRepository(AppScope.read(context).apiClient);

  late Future<List<Asset>> _sharesFuture = _repo.byClass(AssetClass.ngx);

  String _sector = 'All';

  KTrend _k(Trend t) => t == Trend.gain ? KTrend.gain : KTrend.loss;

  @override
  Widget build(BuildContext context) {
    // s24's own header pill ("Open till 4:30pm") only draws the open state
    // — AppState.marketOpen (GET /market-status, polled every 30s) is real
    // and can be false, so the pill also carries a closed reading built to
    // match its visual language rather than left undesigned.
    final marketOpen = AppScope.of(context).marketOpen;

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
                  _MarketStatusPill(open: marketOpen),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Padding(
              padding: _gut,
              child: KSearchPill(
                placeholder: 'Search companies',
                readOnly: true,
                onTap: () => context.push(Routes.search),
              ),
            ),
            const SizedBox(height: 16),

            if (!marketOpen) ...[
              Padding(padding: _gut, child: const KMarketClosedBanner()),
              const SizedBox(height: 16),
            ],

            FutureBuilder<List<Asset>>(
              future: _sharesFuture,
              builder: (context, snapshot) {
                final assets = snapshot.data;
                if (assets == null || assets.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: _gut,
                  child: _MarketMoodCard(assets: assets),
                );
              },
            ),
            const SizedBox(height: 16),

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
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),

            // "Biggest gainers" — market-wide, independent of the sector
            // filter below (the filter only narrows "All companies").
            FutureBuilder<List<Asset>>(
              future: _sharesFuture,
              builder: (context, snapshot) {
                final assets = snapshot.data ?? const <Asset>[];
                final gainers = _topGainers(assets);
                if (gainers.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: _gut,
                      child: Row(
                        children: [
                          Expanded(child: Text('Biggest gainers', style: KType.section())),
                          Text('Swipe', style: KType.data(color: KColor.ink3)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: _gut,
                        itemCount: gainers.length,
                        separatorBuilder: (context, i) => const SizedBox(width: 12),
                        itemBuilder: (context, i) => _GainerCard(
                          asset: gainers[i],
                          onTap: () => context.push(Routes.assetDetail(gainers[i].ticker)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

            Padding(padding: _gut, child: Text('All companies', style: KType.section())),
            const SizedBox(height: 10),

            Padding(
              padding: _gut,
              child: _asyncList(
                _sharesFuture,
                onRetry: () =>
                    setState(() => _sharesFuture = _repo.byClass(AssetClass.ngx)),
                marketOpen: marketOpen,
                sectorFilter: _sector == 'All' ? null : _sector,
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
                      'It queues for 10:00 ${marketNextOpenLabel()} and fills at the opening price, which may differ from what you see now.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Top real gainers (positive movers, highest % first), capped at 3 to
  /// match s24's own gainer-card count. Empty when nothing is up — never
  /// padded with flat/losing assets to fill the row.
  List<Asset> _topGainers(List<Asset> assets) {
    final up = assets.where((a) => a.trend == Trend.gain).toList()
      ..sort((a, b) => _pct(b).compareTo(_pct(a)));
    return up.take(3).toList();
  }

  double _pct(Asset a) => double.tryParse(a.change.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

  /// FutureBuilder wrapper — same loading/error/empty states per
  /// lib/data/api/README.md's canonical pattern.
  Widget _asyncList(
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
        return _list(data, marketOpen: marketOpen);
      },
    );
  }

  /// Flat list, no card chrome — s24's "All companies" list sits directly
  /// on the page background with a hairline between rows, not inside a
  /// bordered/shadowed KCard.
  Widget _list(List<Asset> assets, {required bool marketOpen}) {
    return Column(
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
              ticker: marketOpen
                  ? assets[i].ticker
                  : '${assets[i].ticker} · closed at $_ngxCloseTime',
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
    );
  }
}

/// Header market-status pill — s24's "Open till 4:30pm" (dot + label,
/// tinted pill). `statusApprovedTint` is the exact token match for the
/// pill's own rgba(42,163,107,.12) / rgba(111,211,164,.16) background in
/// light/dark; s24 draws no closed reading, so that half is built to the
/// same visual language using the app's existing neutral/closed tokens.
class _MarketStatusPill extends StatelessWidget {
  const _MarketStatusPill({required this.open});
  final bool open;

  @override
  Widget build(BuildContext context) {
    final dark = KColor.active.brightness == Brightness.dark;
    final label = open ? 'Open till $_ngxCloseTime' : 'Closed · opens ${marketNextOpenLabel()}';
    final fg = open ? (dark ? KColor.gainOnInk : KColor.gain) : KColor.ink2;
    final bg = open ? KColor.statusApprovedTint : KColor.track;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: KRadii.pillR),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(label, style: KType.data(color: fg, w: KWeight.bold).copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

/// "Market mood today" feature card — s24's grape panel (flattens to the
/// dark card colour in dark per R-26), decorative circle, growth
/// illustration. Up/down counts are real, computed from the loaded asset
/// list; the NGX All-Share index clause s24 also draws is a genuine
/// backend gap (see BACKEND_GAPS.md, s24) and is left off rather than
/// fabricated.
class _MarketMoodCard extends StatelessWidget {
  const _MarketMoodCard({required this.assets});
  final List<Asset> assets;

  @override
  Widget build(BuildContext context) {
    final up = assets.where((a) => a.trend == Trend.gain).length;
    final down = assets.length - up;
    final headline = up == down ? 'Flat day' : (up > down ? 'Green day' : 'Red day');
    final dark = KColor.active.brightness == Brightness.dark;
    // Dark's decorative circle is a faint white overlay, not a solid
    // feature2 fill — s24d draws it that way (rgba(255,255,255,.04))
    // rather than carrying the light card's purple ramp into dark, the
    // same flattening R-26 already documents for the panel itself.
    final circleColor = dark ? KColor.featureInk.withValues(alpha: 0.04) : KColor.feature2;

    return ClipRRect(
      borderRadius: KRadii.featureR,
      child: Container(
        decoration: BoxDecoration(color: KColor.feature),
        child: Stack(
          children: [
            Positioned(
              right: -70,
              bottom: -80,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Market mood today'.upper, style: KType.label(color: KColor.featureInk2)),
                        const SizedBox(height: 6),
                        Text(headline,
                            style: KType.section(color: KColor.featureInk).copyWith(fontSize: 24)),
                        const SizedBox(height: 6),
                        Text('$up up · $down down', style: KType.body(color: KColor.featureInk2)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SvgPicture.asset('assets/illustrations/kd-growth.svg', height: 74),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One "Biggest gainers" card — 150-wide, avatar + ticker/price + %.
class _GainerCard extends StatelessWidget {
  const _GainerCard({required this.asset, required this.onTap});
  final Asset asset;
  final VoidCallback onTap;

  String get _initials {
    final letters = asset.ticker.replaceAll(RegExp(r'[^A-Za-z]'), '');
    return letters.substring(0, letters.length < 2 ? letters.length : 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: KCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: asset.logoColor ?? KColor.indicatorTint, shape: BoxShape.circle),
              child: Text(_initials,
                  style: KType.label(
                          color: asset.logoColor != null ? KColor.featureInk : KColor.indicator,
                          w: KWeight.bold)
                      .copyWith(fontSize: 13)),
            ),
            const SizedBox(height: 10),
            Text(asset.ticker, style: KType.cardTitle().copyWith(fontSize: 15)),
            const SizedBox(height: 1),
            Text(asset.price, style: KType.data(color: KColor.ink3).copyWith(fontSize: 13).tnum),
            const SizedBox(height: 8),
            Text(asset.change,
                style: KType.cardTitle(color: KColor.gain, w: KWeight.black).copyWith(fontSize: 15).tnum),
          ],
        ),
      ),
    );
  }
}
