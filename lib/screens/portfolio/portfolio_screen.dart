// Stage 7 · Portfolio overview (root tab; also the R-28 landing spot for the
// old separate "Assets" tab, now folded into this one). Rebuilt against the
// 2026-08 redesign canvas, docs/design/redesign-2026-08/05 Portfolio and
// Wallet.dc.html #s33 ("33 · Portfolio") — see docs/redesign/RULINGS.md's
// `portfolio/portfolio_screen.dart` row for that mapping. Any earlier comment
// in this file citing a different id (the old 97-screen canvas) was stale
// per R-5 and has been replaced.
//
// Ruling R-22: the allocation chart moves from a donut-by-asset-class to a
// bar-by-sector ("Where your money sits"). Real per-holding sector data now
// flows through HoldingsRepository (see its own history note) — no backend
// gap for the grouping itself.
//
// NGX-only: US stocks/ETFs removed (Blue Marina supplies NGX equities only).
// Tab root: builds a Scaffold body WITHOUT a bottom nav — the shell owns nav.
//
// Wired to the backend per lib/data/api/README.md's FutureBuilder convention:
// HoldingsRepository.holdings() (GET /holdings) + .summary() (GET
// /portfolio-summary).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  late final _repo = HoldingsRepository(AppScope.read(context).apiClient);
  late Future<(PortfolioSummary, List<Holding>)> _future = _load();

  // Silent refresh (2026-08-24). Reported live: "I just bought a share and
  // the assets screen did not change" — the Holding row existed in the
  // database immediately, but this screen kept showing pre-purchase data
  // until a full app reload.
  //
  // Root cause: the tabs live in a StatefulNavigationShell, which by design
  // NEVER disposes a branch when you switch away from it. `_future` above
  // is a `late` field, so it resolves exactly once — the first time the
  // Portfolio tab is built — and every later visit re-renders that same
  // completed future. Buying on the Trade tab therefore could not change
  // anything here, no matter how correct the backend was.
  //
  // home_screen.dart already hit this and solved it with a poll timer
  // (_portfolioPollInterval, 8s); this mirrors that rather than inventing a
  // second mechanism. Silent by design: `_future` is only swapped once the
  // new data has ARRIVED, so the FutureBuilder never flips back to its
  // loading spinner underneath someone who is reading the screen.
  static const _pollInterval = Duration(seconds: 8);
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _silentRefresh() async {
    try {
      final data = await _load();
      if (!mounted) return;
      setState(() => _future = Future.value(data));
    } catch (_) {
      // Best-effort: a failed poll leaves whatever is already on screen.
    }
  }

  Future<(PortfolioSummary, List<Holding>)> _load() async {
    // Record `.wait`, not fire-then-sequential-await: if summary() rejects
    // while holdings() is still in flight, sequential awaiting would throw
    // immediately and leave holdings()'s future unlistened-to — an
    // "unhandled exception" once it too resolves. `.wait` listens to both
    // up front regardless of which fails first. See home_screen.dart's
    // _load() for the same fix with the fuller writeup.
    final (summary, holdingsPage) = await (_repo.summary(), _repo.holdings()).wait;
    return (summary, holdingsPage.data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<(PortfolioSummary, List<Holding>)>(
          future: _future,
          builder: (context, snapshot) {
            // Loading: the very first fetch, before either GET has resolved.
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const KLoadingView();
            }
            // Error: /holdings or /portfolio-summary rejected (network,
            // 5xx, etc) — no partial render, matching R-30's "reuse
            // state_views.dart" instruction.
            if (snapshot.hasError) {
              return KErrorView.failedLoad(
                onPrimary: () => setState(() => _future = _load()),
              );
            }
            final (summary, holdings) = snapshot.data!;
            // Empty: a verified investor with zero positions (never bought,
            // or sold out entirely) — the only real way this screen has
            // nothing to show.
            if (holdings.isEmpty) {
              return KEmptyView.holdings(
                onAction: () => context.go(Routes.markets),
              );
            }
            return _PortfolioBody(summary: summary, holdings: holdings);
          },
        ),
      ),
    );
  }
}

/// The loaded-state widget tree.
class _PortfolioBody extends StatelessWidget {
  const _PortfolioBody({required this.summary, required this.holdings});
  final PortfolioSummary summary;
  final List<Holding> holdings;

  @override
  Widget build(BuildContext context) {
    final sectorAllocation = _sectorAllocation(holdings);
    return ListView(
      // Tab-root: pad the bottom so the last holdings row clears the
      // floating KBottomNav (~70px + 12 margin + safe area).
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 14, KSpace.gutter, 100),
      children: [
        // #s33 header: "Portfolio" title + a circular "doc" icon button that
        // opens Statements (section 6) — KScreenHead.trailing, added for
        // this rather than a bespoke header.
        KScreenHead(
          title: 'Portfolio',
          trailing: _StatementsButton(onTap: () => context.push(Routes.acctStatements)),
        ),
        const SizedBox(height: 14),

        // "What you own" — #s33's money card: paper surface + a soft
        // decorative circle, the kd-growth illustration, the hero total,
        // and two pills ("all time" gain amount, holding count) in place of
        // Home's plain BalancePanel change-line. Structurally different
        // enough from KBalancePanel (fill colour, layout, illustration,
        // pills vs a text line) that extending KBalancePanel would be
        // adding a second widget's worth of props to it rather than one
        // variant — kept screen-local instead, per the shared-widget rule.
        _MoneyCard(
          totalValue: summary.totalValue,
          allTimeReturnAmount: summary.allTimeReturnAmount,
          holdingCount: holdings.length,
        ),

        const SizedBox(height: 20),
        Text('Where your money sits', style: KType.section()),
        const SizedBox(height: 12),
        _AllocationBarSection(allocation: sectorAllocation),

        const SizedBox(height: 22),
        Text('Your companies', style: KType.section()),
        const SizedBox(height: 10),
        _HoldingsList(holdings: holdings),

        const SizedBox(height: 18),
        const _HealthNudgeCard(),
      ],
    );
  }
}

/// Real per-holding sector totals (ruling R-22 — the bar-by-sector, replacing
/// the old donut-by-asset-class). Grouped from [holdings] itself — each
/// holding's `marketValueKobo` and `asset.sector` are both real backend
/// fields (see holdings_repository.dart), so this is arithmetic over live
/// data, not an invented figure. A holding with no sector on record (the
/// backend seeds this null for ETFs; NGX equities carry a real value) is
/// still counted — under "Other" — rather than silently dropped, so the bar
/// always accounts for the investor's full portfolio value.
List<PortfolioAllocationSlice> _sectorAllocation(List<Holding> holdings) {
  final totalsKobo = <String, int>{};
  var grandTotalKobo = 0;
  for (final h in holdings) {
    final kobo = h.marketValueKobo;
    if (kobo == null || kobo <= 0) continue;
    final sector = h.asset.sector ?? 'Other';
    totalsKobo[sector] = (totalsKobo[sector] ?? 0) + kobo;
    grandTotalKobo += kobo;
  }
  if (grandTotalKobo <= 0) return const [];
  final entries = totalsKobo.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in entries)
      PortfolioAllocationSlice(label: e.key, value: e.value / grandTotalKobo * 100),
  ];
}

/// #s33's decorative paper money card — "What you own": eyebrow + eye icon,
/// the kd-growth illustration, the hero total, and the two stat pills.
class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.totalValue,
    required this.allTimeReturnAmount,
    required this.holdingCount,
  });

  final String totalValue;
  final String allTimeReturnAmount;
  final int holdingCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: KColor.paper,
        borderRadius: KRadii.featureR,
        border: isDark ? null : Border.all(color: KColor.hairline),
        boxShadow: isDark ? null : KShadow.card,
      ),
      child: Stack(
        children: [
          // The blob — indicator-tint in light, a faint white wash in dark
          // (#s33d's own `rgba(255,255,255,.05)`, nearest to KColor.track).
          Positioned(
            right: -80,
            top: -80,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? KColor.track : KColor.indicatorTint,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('What you own'.upper,
                              style: KType.label(color: KColor.ink3).copyWith(height: 1.0)),
                          const SizedBox(width: 8),
                          KIcon('eye', size: 15, color: KColor.ink3),
                        ],
                      ),
                    ),
                  ),
                  SvgPicture.asset('assets/illustrations/kd-growth.svg', height: 64),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                totalValue,
                style: KType.hero(color: KColor.ink).copyWith(fontSize: 42, height: 46 / 42).tnum,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatChip(
                    label: '$allTimeReturnAmount all time',
                    background: KColor.statusApprovedTint,
                    foreground: isDark ? KColor.gainOnInk : KColor.gain,
                  ),
                  _StatChip(
                    label: holdingCount == 1 ? '1 company' : '$holdingCount companies',
                    background: KColor.indicatorTint,
                    foreground: KColor.ink,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.background, required this.foreground});
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(KRadii.pill)),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: KType.fontCore,
          fontSize: 13,
          fontWeight: KWeight.bold,
          color: foreground,
          height: 1.0,
        ).tnum,
      ),
    );
  }
}

/// Circular header icon button — #s33's "doc" glyph opening Statements.
/// Fill (`--track`) and lack of a hairline border don't match either
/// [KIconButton] variant (both draw a hairline; neither takes a custom
/// fill), so this stays a screen-local one-off rather than adding a third
/// button variant for a single call site.
class _StatementsButton extends StatelessWidget {
  const _StatementsButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: KColor.track, shape: BoxShape.circle),
        child: KIcon('doc', size: 19, color: KColor.ink),
      ),
    );
  }
}

/// "Where your money sits" — the R-22 bar-by-sector: one proportional bar
/// (KAllocationBar) plus a wrapped legend, replacing the old donut+column
/// legend pair.
class _AllocationBarSection extends StatelessWidget {
  const _AllocationBarSection({required this.allocation});
  final List<PortfolioAllocationSlice> allocation;

  @override
  Widget build(BuildContext context) {
    if (allocation.isEmpty) return const SizedBox.shrink();
    final ramp = KColor.ramp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KAllocationBar(
          segments: [
            for (var i = 0; i < allocation.length; i++)
              KDonutSegment(value: allocation[i].value, color: ramp[i % ramp.length]),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (var i = 0; i < allocation.length; i++)
              _LegendChip(
                color: ramp[i % ramp.length],
                label: allocation[i].label,
                value: '${allocation[i].value.round()}%',
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 7),
        Text('$label $value', style: KType.body(color: KColor.ink2).copyWith(fontSize: 13, height: 19 / 13)),
      ],
    );
  }
}

/// "Your companies" — #s33 draws each holding as its OWN bordered, rounded
/// card with a 10px gap between rows (not one card with hairline dividers,
/// which is what this screen drew before the redesign).
class _HoldingsList extends StatelessWidget {
  const _HoldingsList({required this.holdings});
  final List<Holding> holdings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < holdings.length; i++) ...[
          if (i != 0) const SizedBox(height: 10),
          KCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            radius: KRadii.illo,
            onTap: () => context.push(Routes.holdingDetail(holdings[i].asset.ticker)),
            child: KAssetRow(
              name: holdings[i].asset.name,
              // The AssetRow's subtitle here is "{units} shares · avg
              // {avgPrice}" and its trailing figures are the POSITION's
              // market value + total return (holding.marketValue /
              // holding.returnPct) — this is this holding's own position
              // numbers, not the asset's daily per-share price/change
              // (that's Markets-screen data).
              ticker: '${holdings[i].units} shares · avg ${holdings[i].avgPrice}',
              initialsSource: holdings[i].asset.ticker,
              logoColor: holdings[i].asset.logoColor ?? KColor.ink,
              price: holdings[i].marketValue,
              change: holdings[i].returnPct,
              trend: holdings[i].returnTrend == Trend.loss ? KTrend.loss : KTrend.gain,
            ),
          ),
        ],
      ],
    );
  }
}

/// #s33's "Is my portfolio healthy?" card — a static nudge (illustration +
/// title + subtitle), not a computed digest. The artboard's copy carries no
/// `{{ }}` binding anywhere (unlike every genuinely dynamic element on the
/// same screen — the holdings `sc-for`, the allocation legend) and reuses
/// the same `kd-lesson` illustration Home Variants.dc.html uses for its
/// static "Financial literacy" promo rail (R-29) — both read as the same
/// static-teaser pattern, not a live insight. Superseded the previous
/// deterministic "Heavy on two names…" KDigestCard copy this screen used to
/// show in this slot; that computed sentence doesn't match what's drawn here.
///
/// `kd-lesson.svg` itself isn't in this app's `assets/illustrations/`
/// (only the design canvas has it) — `portfolio-health.svg` already is,
/// unused, and purpose-built for exactly this card, so it's used here
/// instead of copying over an asset the canvas didn't ship into the app.
///
/// No `onTap`: unlike every other tappable element in this artboard file,
/// this card's `cursor:pointer` has no paired `nav.sXX` target, and no
/// artboard exists for a destination — wiring one would be an invented
/// route, not a designed one.
class _HealthNudgeCard extends StatelessWidget {
  const _HealthNudgeCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? KColor.paper : KColor.sunTint,
        borderRadius: BorderRadius.circular(KRadii.illo),
      ),
      child: Row(
        children: [
          SvgPicture.asset('assets/illustrations/portfolio-health.svg', height: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Is my portfolio healthy?', style: KType.cardTitle().copyWith(fontSize: 15, height: 20 / 15)),
                const SizedBox(height: 2),
                Text(
                  'A plain reading of your spread and risk.',
                  style: KType.body(color: KColor.ink2).copyWith(fontSize: 13, height: 19 / 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
