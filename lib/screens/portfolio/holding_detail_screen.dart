// Stage 7 · Holding detail (pushed). Ported from portfolio-screens.jsx
// `HoldingDetail`, made data-driven by ticker. mockup-raw/s39.html: a custom
// two-line header (name + "Your holding · TICKER"), a bare hero price (NOT a
// KBalancePanel — s39 has no purple panel at all), a divided key/value card,
// and the Sell / Buy more footer. No price chart on this screen — s39's own
// footer note says "price chart lives on 33, one tap from the name".
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
        // The header can't wait on the fetch (it's outside the scrollable
        // body), so it shows the ticker — always known up front, same
        // fallback asset_detail_screen.dart uses — until the real
        // asset.name resolves.
        final name = snapshot.data?.holding.asset.name ?? widget.ticker;

        return Scaffold(
          backgroundColor: KColor.bg,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(name: name, ticker: widget.ticker),
                Expanded(
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
              ],
            ),
          ),
        );
      },
    );
  }
}

/// mockup-raw/s39.html: `[IconButton back][name / "Your holding · TICKER"]`
/// — a bespoke two-line header, not KDetailHeader (which has no subtitle
/// slot). Same pattern asset_detail_screen.dart's own custom top bar uses.
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.ticker});
  final String name;
  final String ticker;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 14, KSpace.gutter, 4),
      child: Row(
        children: [
          KIconButton(
            icon: 'back',
            semanticLabel: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: KType.cardTitle()),
                Text('Your holding · $ticker'.upper, style: KType.micro(color: KColor.ink3)),
              ],
            ),
          ),
        ],
      ),
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
    final trendColor = holding.returnTrend == Trend.loss ? KColor.loss : KColor.gain;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(KSpace.gutter, 10, KSpace.gutter, 24),
            children: [
              // Bare hero price + gain/loss line — mockup-raw/s39.html lines
              // 9-11: NOT a KBalancePanel (no purple panel on this screen at
              // all). Was wrapping this in a KBalancePanel ("{name} · your
              // position") that doesn't exist in the design.
              Text(holding.marketValue, style: KType.hero(color: KColor.ink).tnum),
              Text(
                '${holding.totalReturn} · ${holding.returnPct} since you bought',
                style: KType.data(color: trendColor, w: KWeight.semibold).tnum,
              ),
              const SizedBox(height: 16),

              // Divided key/value card — mockup-raw/s39.html lines 14-21:
              // Shares / Average cost / Market price / Dividends received /
              // Held in / Executing broker, each a hairline-divided row, NOT
              // the 2x2 KStatCard grid this screen used to render (that grid
              // isn't in the design at all).
              //
              // "Dividends received" and "Executing broker" are deliberately
              // NOT added:
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _KVRow(label: 'Shares', value: holding.units),
                    _KVRow(label: 'Average cost', value: holding.avgPrice),
                    _KVRow(label: 'Market price', value: asset.price),
                    _KVRow(label: 'Held in', value: 'CSCS · CHN $cscsNumber', last: true),
                  ],
                ),
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

/// One hairline-divided key/value row — mockup-raw/s39.html's details card
/// rows (`[label flex:1][value]`, 12px vertical padding, divider except the
/// last row).
class _KVRow extends StatelessWidget {
  const _KVRow({required this.label, required this.value, this.last = false});
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: KType.data(color: KColor.ink2))),
          Text(value, style: KType.data(color: KColor.ink).tnum),
        ],
      ),
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
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 18, KSpace.gutter, 24),
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
