// Stage 7 · Holding detail (pushed). Ported from portfolio-screens.jsx
// `HoldingDetail`, made data-driven by ticker. mockup-raw/s39.html: a custom
// two-line header (name + "Your holding · TICKER"), a bare hero price (NOT a
// KBalancePanel — s39 has no purple panel at all), a divided key/value card,
// a "Your orders in {ticker}" list, and the Sell / Buy more footer. No price
// chart on this screen — s39's own footer note says "price chart lives on
// 33, one tap from the name".
//
// Wired to GET /holdings/:ticker via HoldingsRepository.byTicker (see
// lib/data/api/README.md's FutureBuilder convention). That endpoint's own
// JSON has no asset display fields, so the repository merges in a
// GET /assets/:ticker fetch itself — this screen just consumes the single
// resulting `Holding`. This also resolves the old silent not-found fallback
// (MockData.holdingByTicker(ticker) ?? MockData.portfolioHoldings.first): an
// unrecognized/failed ticker now surfaces KErrorView instead of silently
// showing a different holding's numbers.
//
// 2026-08-24: "Dividends received" and "Your orders in {ticker}" were
// previously omitted as backend gaps — re-checked and both are now real:
// GET /dividends (DividendRepository.history, added this session) carries a
// real per-payout `ticker` field, and GET /orders (investor-scoped, added
// this session — see OrdersRepository's header) carries a real `ticker` on
// every Order. Both are fetched here and filtered client-side by ticker
// (same "local filter over a generous page" convention this app already
// uses for search/asset-list). "Executing broker" is still genuinely
// omitted: Order/Holding have no brokerId/brokerCode field anywhere
// (confirmed against prisma/schema.prisma) — "Blue Marina" is the canvas's
// own placeholder co-branding, not a real integrated partner relationship
// this backend models, so showing it would fabricate a business
// relationship, not just fill in a missing field.
import 'package:flutter/material.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/dividend_repository.dart' as div;
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/data/repositories/orders_repository.dart';
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

typedef _HoldingDetailData = ({
  Holding holding,
  String cscsNumber,
  int dividendsReceivedKobo,
  List<Order> ownOrders,
});

class _HoldingDetailScreenState extends State<HoldingDetailScreen> {
  late final _repo = HoldingsRepository(AppScope.read(context).apiClient);
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);
  late final _dividendRepo = div.DividendRepository(AppScope.read(context).apiClient);
  late final _ordersRepo = OrdersRepository(AppScope.read(context).apiClient);
  late Future<_HoldingDetailData> _future = _load();

  // "Held in CSCS · CHN 1234567890" (spec 39) — cscsNumber is a real User
  // field (GET /users/me) already surfaced by UserRepository.personalInfo()
  // for the personal-info screen; joined here rather than added to the
  // shared UserProfile model, matching this repository's own established
  // convention (a second, self-contained GET /users/me call per screen that
  // needs different fields — see personalInfo()'s own doc comment).
  Future<_HoldingDetailData> _load() async {
    final (holding, info, dividendPage, orders) = await (
      _repo.byTicker(widget.ticker),
      _userRepo.personalInfo(),
      _dividendRepo.history(pageSize: 200),
      _ordersRepo.myOrders(),
    ).wait;
    final dividendsReceivedKobo = dividendPage.data
        .where((d) => d.ticker == widget.ticker)
        .fold<int>(0, (sum, d) => sum + d.netKobo);
    final ownOrders = orders.where((o) => o.ticker == widget.ticker).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return (
      holding: holding,
      cscsNumber: info.cscsNumber,
      dividendsReceivedKobo: dividendsReceivedKobo,
      ownOrders: ownOrders,
    );
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
                    return _HoldingDetailBody(
                      holding: data.holding,
                      cscsNumber: data.cscsNumber,
                      dividendsReceivedKobo: data.dividendsReceivedKobo,
                      ownOrders: data.ownOrders,
                    );
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
  const _HoldingDetailBody({
    required this.holding,
    required this.cscsNumber,
    required this.dividendsReceivedKobo,
    required this.ownOrders,
  });
  final Holding holding;
  final String cscsNumber;
  final int dividendsReceivedKobo;
  final List<Order> ownOrders;

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
              // the 2x2 KStatCard grid this design doesn't use here.
              //
              // "Dividends received" is now real (see file header — GET
              // /dividends carries a real per-payout ticker). "Executing
              // broker" is still genuinely omitted — no brokerId/brokerCode
              // field exists anywhere on Order/Holding (confirmed against
              // prisma/schema.prisma); "Blue Marina" is the canvas's own
              // placeholder co-branding, not a real partner relationship
              // this backend models yet.
              KCard(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _KVRow(label: 'Shares', value: holding.units),
                    _KVRow(label: 'Average cost', value: holding.avgPrice),
                    _KVRow(label: 'Market price', value: asset.price),
                    _KVRow(label: 'Dividends received', value: _formatKobo(dividendsReceivedKobo)),
                    _KVRow(label: 'Held in', value: 'CSCS · CHN $cscsNumber', last: true),
                  ],
                ),
              ),

              if (ownOrders.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Your orders in ${asset.ticker}'.upper, style: KType.label(color: KColor.ink3)),
                const SizedBox(height: 10),
                KCard(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < ownOrders.length; i++)
                        Container(
                          decoration: BoxDecoration(
                            border: i == ownOrders.length - 1
                                ? null
                                : Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
                          ),
                          child: _OwnOrderRow(order: ownOrders[i]),
                        ),
                    ],
                  ),
                ),
              ],
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

/// One row of the "Your orders in {ticker}" list — mockup-raw/s39.html:
/// "Bought 60 · ₦238.00" / "04 Feb 2026 · settled" + a small StatusPill.
class _OwnOrderRow extends StatelessWidget {
  const _OwnOrderRow({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final verb = order.side == 'sell' ? 'Sold' : 'Bought';
    final (KStatus status, String label, String descriptor) = switch (order.status) {
      'approved' => (KStatus.approved, 'Filled', 'settled'),
      'pending' => (KStatus.review, 'Filling', 'pending'),
      _ => (KStatus.rejected, 'Cancelled', 'not completed'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$verb ${order.units} · ${_formatKobo(order.price)}',
                    style: KType.data(color: KColor.ink)),
                Text('${_formatDate(order.createdAt)} · $descriptor'.upper,
                    style: KType.micro(color: KColor.ink3)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          KStatusPill(status: status, label: label, small: true),
        ],
      ),
    );
  }
}

/// Minor-unit integer (kobo) -> "₦1,234.56" — same grouping convention every
/// other repository/screen in this app already uses.
String _formatKobo(int? minorUnits) {
  final abs = (minorUnits ?? 0).abs();
  final major = abs ~/ 100;
  final minor = (abs % 100).toString().padLeft(2, '0');
  final majorStr = major.toString();
  final buf = StringBuffer();
  for (var i = 0; i < majorStr.length; i++) {
    final posFromEnd = majorStr.length - i;
    buf.write(majorStr[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(',');
  }
  return '₦$buf.$minor';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// ISO-8601 timestamp -> "04 Feb 2026" (date only — this row's own
/// descriptor word carries the status, matching the canvas's "settled").
String _formatDate(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  return '${dt.day.toString().padLeft(2, '0')} ${_months[dt.month - 1]} ${dt.year}';
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
