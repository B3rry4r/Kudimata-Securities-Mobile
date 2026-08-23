// Stage 7 · Holding detail (pushed). Ported from portfolio-screens.jsx
// `HoldingDetail`, made data-driven by ticker. Position BalancePanel, a KLineChart,
// position stats via KStatCard, and the Sell / Buy more footer wired to the
// trade flow launchers. KDetailHeader (back chevron, no tab bar).
//
// Wired to GET /holdings/:ticker via HoldingsRepository.byTicker (see
// lib/data/api/README.md's FutureBuilder convention). That endpoint's own
// JSON has no asset display fields, so the repository merges in a
// GET /assets/:ticker fetch itself — this screen just consumes the single
// resulting `Holding`. This also resolves the old silent not-found fallback
// (MockData.holdingByTicker(ticker) ?? MockData.portfolioHoldings.first): an
// unrecognized/failed ticker now surfaces KErrorView instead of silently
// showing a different holding's numbers.
import 'package:flutter/material.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/screens/trade/trade_flows.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class HoldingDetailScreen extends StatefulWidget {
  const HoldingDetailScreen({super.key, required this.ticker});

  /// The held instrument's ticker (e.g. 'MTNN').
  final String ticker;

  @override
  State<HoldingDetailScreen> createState() => _HoldingDetailScreenState();
}

typedef _HoldingDetailData = ({Holding holding, String cscsNumber});

class _HoldingDetailScreenState extends State<HoldingDetailScreen> {
  late final _repo = HoldingsRepository(AppScope.read(context).apiClient);
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);
  late Future<_HoldingDetailData> _future = _load();

  // "Held in CSCS · CHN 1234567890" (spec 39) — cscsNumber is a real User
  // field (GET /users/me) already surfaced by UserRepository.personalInfo()
  // for the personal-info screen; joined here rather than added to the
  // shared UserProfile model, matching this repository's own established
  // convention (a second, self-contained GET /users/me call per screen that
  // needs different fields — see personalInfo()'s own doc comment).
  Future<_HoldingDetailData> _load() async {
    final (holding, info) = await (_repo.byTicker(widget.ticker), _userRepo.personalInfo()).wait;
    return (holding: holding, cscsNumber: info.cscsNumber);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HoldingDetailData>(
      future: _future,
      builder: (context, snapshot) {
        // KDetailHeader's title can't wait on the fetch (it's outside the
        // scrollable body), so it shows the ticker — always known up front,
        // same fallback asset_detail_screen.dart uses — until the real
        // asset.name (the fragment's intended title) resolves.
        final title = snapshot.data?.holding.asset.name ?? widget.ticker;

        return Scaffold(
          backgroundColor: KColor.bg,
          appBar: KDetailHeader(title: title),
          body: SafeArea(
            top: false,
            child: Builder(builder: (context) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const KLoadingView();
              }
              if (snapshot.hasError) {
                return KErrorView.failedLoad(
                  onPrimary: () => setState(() => _future = _load()),
                );
              }
              final data = snapshot.data!;
              return _HoldingDetailBody(holding: data.holding, cscsNumber: data.cscsNumber);
            }),
          ),
        );
      },
    );
  }
}

/// The loaded-state widget tree — identical to the original mock-fed
/// `build()`, just parameterized on the fetched `Holding` instead of
/// `MockData.holdingByTicker`.
class _HoldingDetailBody extends StatelessWidget {
  const _HoldingDetailBody({required this.holding, required this.cscsNumber});
  final Holding holding;
  final String cscsNumber;

  @override
  Widget build(BuildContext context) {
    final asset = holding.asset;
    final trend = holding.returnTrend == Trend.loss ? KTrend.loss : KTrend.gain;
    final subTone =
        holding.returnTrend == Trend.loss ? KSubTone.loss : KSubTone.gain;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                KSpace.gutter, 16, KSpace.gutter, 24),
            children: [
              // Position panel — your value + total return.
              KBalancePanel(
                label: '${asset.name} · your position',
                balance: holding.marketValue,
                change: '${holding.totalReturn} · ${holding.returnPct}',
                changeTone: trend,
              ),
              const SizedBox(height: 16),

              // Position stats — 2×2 grid of KStatCard.
              _StatGrid(
                children: [
                  KStatCard(
                    icon: KIcon('transfer', size: 18, color: KColor.ink2),
                    label: 'Avg cost',
                    value: holding.avgPrice,
                  ),
                  KStatCard(
                    icon: KIcon('portfolio', size: 18, color: KColor.ink2),
                    label: 'Quantity',
                    value: holding.units,
                  ),
                  KStatCard(
                    icon: KIcon('markets', size: 18, color: KColor.ink2),
                    label: 'Current',
                    value: asset.price,
                  ),
                  KStatCard(
                    icon: KIcon('arrowUpRight', size: 18, color: KColor.ink2),
                    label: 'P/L',
                    value: holding.returnPct,
                    sub: holding.totalReturn,
                    subTone: subTone,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // "Held in CSCS · CHN 1234567890" (spec 39) — a real fact,
              // GET /users/me's cscsNumber. Spec 39 also lists "Dividends
              // received" and "Executing broker · Blue Marina · BM-4471" on
              // this screen — deliberately NOT added:
              //  - Dividends received: no such field exists anywhere on the
              //    Holding/Transaction wire types (checked the backend's
              //    actual types directly); there's no per-holding dividend
              //    total to report yet.
              //  - Executing broker: Order/Holding have no brokerId/
              //    brokerCode at all (confirmed against prisma/schema.prisma)
              //    — this app is single-broker today, and "Blue Marina" is
              //    the mockup's own placeholder co-branding, not a real
              //    partner this build integrates with. Showing it would be
              //    fabricating a business relationship, not just missing a
              //    field.
              // A "Your orders in {ticker}" list (also spec 39) is likewise
              // omitted: no investor-facing endpoint returns order history
              // filtered by ticker — GET /orders (list) is staff-only, and
              // Transaction (the one investor-scoped resource this app can
              // read) carries no ticker field at all.
              KCard(
                child: _DetailKV(label: 'Held in', value: 'CSCS · CHN $cscsNumber'),
              ),
            ],
          ),
        ),

        // Sticky footer: Sell (secondary) + Buy more (the one purple moment).
        // Sell launches showSellFlow(context, asset) from trade_flows.dart —
        // that flow's own contract belongs to the asset-detail screen agent;
        // this screen is only a second launch point into it.
        _ActionFooter(asset: asset),
      ],
    );
  }
}

/// One label/value row on its own card — "Held in · CSCS · CHN ..." (spec 39).
class _DetailKV extends StatelessWidget {
  const _DetailKV({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: KType.body(color: KColor.ink2)),
        Text(value, style: KType.data(color: KColor.ink).tnum),
      ],
    );
  }
}

/// 2-column grid of equal-height stat cards.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      // 1.55 (the original ratio) only fit KStatCard's icon+label+value —
      // the P/L card is the one cell with a 4th `sub` line (see below),
      // which overflowed every cell's identical fixed height by 15px since
      // GridView.count forces all children to the same size regardless of
      // their own content. 1.3 gives every cell enough room for that 4th
      // line even though only P/L uses it.
      childAspectRatio: 1.3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: children,
    );
  }
}

class _ActionFooter extends StatelessWidget {
  const _ActionFooter({required this.asset});
  final Asset asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 14, KSpace.gutter, 14),
      child: Row(
        children: [
          Expanded(
            child: KButton(
              label: 'Sell',
              variant: KButtonVariant.secondary,
              onPressed: () => showSellFlow(context, asset),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: KButton(
              label: 'Buy more',
              onPressed: () => showBuyFlow(context, asset),
            ),
          ),
        ],
      ),
    );
  }
}
