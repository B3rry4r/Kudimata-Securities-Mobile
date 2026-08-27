// Holding detail (pushed). Artboard s34 (light) / s34d (dark),
// docs/design/redesign-2026-08/05 Portfolio and Wallet.dc.html — reached by
// tapping a row on the Portfolio holdings list (s33). Structure, top to
// bottom: a centered `[TICKER] / "Your holding"` header, a bordered "Worth
// today" hero card (value + a gain/loss pill, NOT a KBalancePanel — s34's
// card is plain paper, not the rich purple surface), a divided key/value
// card (Shares you hold / Average price you paid / Price now), a "Dividend
// paid {date}. {amount} went to your wallet" callout for the most recent
// payout, a "Your trades" list, and a Buy more / Sell footer (Buy more
// first, per s34's own left-to-right order). No price chart on this screen
// — that lives on the asset detail screen, one tap from the name.
//
// Wired to GET /holdings/:ticker via HoldingsRepository.byTicker (see
// lib/data/api/README.md's FutureBuilder convention). That endpoint's own
// JSON has no asset display fields, so the repository merges in a
// GET /assets/:ticker fetch itself — this screen just consumes the single
// resulting `Holding`. An unrecognized/failed ticker surfaces KErrorView
// instead of silently showing a different holding's numbers.
//
// R-23 (docs/redesign/DECISIONS.md): s34's key/value card only draws three
// rows. Two more real, backend-real figures are kept alongside them —
// "Dividends received" (GET /dividends, DividendRepository.history, carries
// a real per-payout `ticker`) and "Held in" (the investor's real CSCS
// number, via UserRepository.personalInfo()). Both are fetched here and
// filtered/joined client-side by ticker (same "local filter over a
// generous page" convention this app already uses for search/asset-list).
//
// The per-holding trades list ("Your trades") is real, backend-wired
// (OrdersRepository.myOrders(), filtered by ticker) — s34 still draws it,
// it is not superseded by the standalone Orders hub (s41). s34's own rows
// show the trade's total value (`order.value`) with no status pill drawn.
//
// DECISIONS.md B-1 (2026-08-27 ruling): the pill was dropped during the s34
// rebuild since R-23 only authorised dividends/CSCS as extras beyond the
// artboard, but the product owner ruled it back in — whether a trade is
// still pending is directly relevant on the screen showing that holding, and
// making the user go to the Orders hub to find out is a downgrade. Restored
// here, using the same KStatus vocabulary/labels order_status_screen.dart's
// own `_StatusBadge` uses (Filled / Filling / Queued / Cancelled).
//
// "Executing broker" is not built: s34 does not draw it at all (unlike the
// screen this file used to be ported from), so there is nothing to match
// against s34's authority. Order/Holding also carry no brokerId/brokerCode
// field anywhere (confirmed against prisma/schema.prisma).
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
  div.Dividend? mostRecentDividend,
  List<Order> ownOrders,
});

class _HoldingDetailScreenState extends State<HoldingDetailScreen> {
  late final _repo = HoldingsRepository(AppScope.read(context).apiClient);
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);
  late final _dividendRepo = div.DividendRepository(AppScope.read(context).apiClient);
  late final _ordersRepo = OrdersRepository(AppScope.read(context).apiClient);
  late Future<_HoldingDetailData> _future = _load();

  Future<_HoldingDetailData> _load() async {
    final (holding, info, dividendPage, orders) = await (
      _repo.byTicker(widget.ticker),
      _userRepo.personalInfo(),
      _dividendRepo.history(pageSize: 200),
      _ordersRepo.myOrders(),
    ).wait;
    // dividendPage is server-sorted payDate:desc (DividendRepository.history's
    // own doc comment), so the first ticker match after filtering is the
    // most recent payout for this holding.
    final tickerDividends = dividendPage.data.where((d) => d.ticker == widget.ticker);
    final dividendsReceivedKobo = tickerDividends.fold<int>(0, (sum, d) => sum + d.netKobo);
    final mostRecentDividend = tickerDividends.isEmpty ? null : tickerDividends.first;
    final ownOrders = orders.where((o) => o.ticker == widget.ticker).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return (
      holding: holding,
      cscsNumber: info.cscsNumber,
      dividendsReceivedKobo: dividendsReceivedKobo,
      mostRecentDividend: mostRecentDividend,
      ownOrders: ownOrders,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HoldingDetailData>(
      future: _future,
      builder: (context, snapshot) {
        // The header can't wait on the fetch (it's outside the scrollable
        // body), so it shows the ticker passed in via the route — always
        // known up front, same fallback asset_detail_screen.dart uses.
        return Scaffold(
          backgroundColor: KColor.bg,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(ticker: widget.ticker),
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
                      mostRecentDividend: data.mostRecentDividend,
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

/// s34: `[back][centered TICKER / "Your holding"][40px spacer]` — a
/// symmetric centered title, mirrored by a spacer the same width as the
/// back button so the title sits dead-center rather than next to the icon.
class _Header extends StatelessWidget {
  const _Header({required this.ticker});
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
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ticker, style: KType.cardTitle()),
                Text('Your holding', style: KType.data(color: KColor.ink3).copyWith(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// The loaded-state widget tree, parameterized on the fetched `Holding`.
class _HoldingDetailBody extends StatelessWidget {
  const _HoldingDetailBody({
    required this.holding,
    required this.cscsNumber,
    required this.dividendsReceivedKobo,
    required this.mostRecentDividend,
    required this.ownOrders,
  });
  final Holding holding;
  final String cscsNumber;
  final int dividendsReceivedKobo;
  final div.Dividend? mostRecentDividend;
  final List<Order> ownOrders;

  @override
  Widget build(BuildContext context) {
    final asset = holding.asset;
    final marketOpen = AppScope.of(context).marketOpen;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(KSpace.gutter, 22, KSpace.gutter, 24),
            children: [
              _HeroCard(holding: holding),
              const SizedBox(height: 16),

              // Divided key/value card — s34: Shares you hold / Average
              // price you paid / Price now, each a hairline-divided row.
              // R-23 keeps two more real rows past what s34 itself draws:
              // Dividends received and Held in (CSCS).
              KCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                radius: KRadii.card,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _KVRow(label: 'Shares you hold', value: holding.units),
                    _KVRow(label: 'Average price you paid', value: holding.avgPrice),
                    _KVRow(label: 'Price now', value: asset.price),
                    _KVRow(label: 'Dividends received', value: _formatKobo(dividendsReceivedKobo)),
                    _KVRow(label: 'Held in', value: 'CSCS · CHN $cscsNumber', last: true),
                  ],
                ),
              ),

              if (mostRecentDividend != null) ...[
                const SizedBox(height: 18),
                _DividendCallout(dividend: mostRecentDividend!),
              ],

              if (ownOrders.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Your trades', style: KType.cardTitle()),
                const SizedBox(height: 10),
                for (var i = 0; i < ownOrders.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _TradeRow(order: ownOrders[i], marketOpen: marketOpen),
                ],
              ],
            ],
          ),
        ),

        // Buy more (indicator, the one purple/primary moment) + Sell
        // (secondary), in that left-to-right order per s34. Both launch the
        // shared trade_flows.dart flow that order_status_screen.dart and
        // asset_detail_screen.dart also launch — this screen is just
        // another entry point into it, not a second implementation of it.
        _ActionFooter(asset: asset),
      ],
    );
  }
}

/// s34's "Worth today" card — bordered paper, NOT the rich-purple
/// KBalancePanel (that widget is reserved for the one purple surface per
/// screen; s34 draws a plain card here). Label / hero value / gain-loss
/// pill + "since you bought".
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.holding});
  final Holding holding;

  @override
  Widget build(BuildContext context) {
    final loss = holding.returnTrend == Trend.loss;
    final trendColor = loss ? KColor.loss : KColor.gain;
    final trendTint = loss ? KColor.statusRejectedTint : KColor.statusApprovedTint;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border.all(color: KColor.hairline, width: 1),
        borderRadius: KRadii.featureR,
        boxShadow: KShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Worth today'.upper, style: KType.label(color: KColor.ink3)),
          const SizedBox(height: 12),
          Text(holding.marketValue, style: KType.hero(color: KColor.ink).tnum),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: trendTint, borderRadius: KRadii.pillR),
                child: Text(
                  '${holding.totalReturn} (${holding.returnPct})',
                  style: KType.data(color: trendColor, w: KWeight.bold).copyWith(fontSize: 13).tnum,
                ),
              ),
              const SizedBox(width: 8),
              Text('since you bought',
                  style: KType.data(color: KColor.ink3).copyWith(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

/// s34's dividend callout: "Dividend paid {date}. {amount} went to your
/// wallet." over an indicator-tinted plate — the single most recent payout
/// for this ticker, distinct from the cumulative "Dividends received" row.
class _DividendCallout extends StatelessWidget {
  const _DividendCallout({required this.dividend});
  final div.Dividend dividend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: KColor.indicatorTint, borderRadius: KRadii.illoR),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: KIcon('card', size: 18, color: KColor.indicator),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: KType.data(color: KColor.ink2),
                children: [
                  TextSpan(
                    text: 'Dividend paid ${_formatShortDate(dividend.payDate)} ',
                    style: KType.data(color: KColor.ink, w: KWeight.bold),
                  ),
                  TextSpan(text: '${_formatKobo(dividend.netKobo)} went to your wallet.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of "Your trades" — s34: `[Bought {units} / date][total value]`,
/// no divider/card chrome (plain rows under the heading). DECISIONS.md B-1
/// restores a status pill beside the value — R-23's extra rows established
/// that this screen may carry real figures s34 doesn't draw when they're
/// directly relevant to the holding shown, and pending/cancelled status is
/// exactly that.
class _TradeRow extends StatelessWidget {
  const _TradeRow({required this.order, required this.marketOpen});
  final Order order;
  final bool marketOpen;

  @override
  Widget build(BuildContext context) {
    final verb = order.side == 'sell' ? 'Sold' : 'Bought';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$verb ${order.units}',
                  style: KType.data(color: KColor.ink, w: KWeight.semibold)),
              Text(_formatDate(order.createdAt),
                  style: KType.data(color: KColor.ink3).copyWith(fontSize: 13)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_formatKobo(order.value), style: KType.data(color: KColor.ink, w: KWeight.bold).tnum),
            const SizedBox(height: 4),
            _StatusBadge(status: order.status, marketOpen: marketOpen),
          ],
        ),
      ],
    );
  }
}

/// Status pill mapped from the real Order.status — same vocabulary/mapping
/// as order_status_screen.dart's own `_StatusBadge` (Filled / Filling·Queued
/// / Cancelled), kept as a screen-local private widget per the brief's rule
/// 5 (shared widgets are off-limits; `KStatusPill` itself is reused, not
/// forked).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.marketOpen});
  final String status;
  final bool marketOpen;

  @override
  Widget build(BuildContext context) {
    final (KStatus status_, String label) = switch (status) {
      'approved' => (KStatus.approved, 'Filled'),
      'pending' => marketOpen ? (KStatus.pending, 'Filling') : (KStatus.review, 'Queued'),
      _ => (KStatus.rejected, 'Cancelled'),
    };
    return KStatusPill(status: status_, label: label, small: true);
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

/// ISO-8601 timestamp -> "3 Jun 2026" (unpadded day, matching s34's own
/// "25 Aug 2026" / "3 Jun 2026" trade-row copy).
String _formatDate(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
}

/// DateTime -> "12 Jul." (day + abbreviated month + period, no year) —
/// matches s34's dividend-callout copy exactly.
String _formatShortDate(DateTime dt) => '${dt.day} ${_months[dt.month - 1]}.';

/// One hairline-divided key/value row — s34's details card rows
/// (`[label flex:1][value]`, 12px vertical padding, divider except the last
/// row).
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
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 14, KSpace.gutter, 30),
      child: Row(
        children: [
          Expanded(
            child: KButton(
              label: 'Buy more',
              onPressed: () => showBuyFlow(context, asset),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: KButton(
              label: 'Sell',
              variant: KButtonVariant.secondary,
              onPressed: () => showSellFlow(context, asset),
            ),
          ),
        ],
      ),
    );
  }
}
