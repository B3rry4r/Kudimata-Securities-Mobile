// Home tab root — greeting, the one BalancePanel (portfolio value + KLineChart),
// quick-actions row, watchlist strip, holdings preview, trending, Orders link.
// Ported from app-screens.jsx `Home`. Root tab: builds a Scaffold body WITHOUT a
// bottom nav — the shell owns that. Numbers tabular; movement colour on numbers.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/mock.dart';
import 'package:kudimata_securities/data/models.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'package:kudimata_securities/screens/wallet/wallet_flows.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  KTrend _k(Trend t) => t == Trend.gain ? KTrend.gain : KTrend.loss;

  @override
  Widget build(BuildContext context) {
    final user = MockData.user;
    final first = user.fullName.split(' ').first;
    final watch = AppScope.of(context).watchlistTickers;

    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          // Tab root: clear the floating KBottomNav (~70px + 12 margin + safe area).
          padding: const EdgeInsets.only(top: 12, bottom: 100),
          children: [
            // greeting row
            Padding(
              padding: _gut,
              child: Row(
                children: [
                  _Avatar(initial: first.isNotEmpty ? first[0] : 'K'),
                  const SizedBox(width: 12),
                  Text('Hi, $first', style: KType.section()),
                  const Spacer(),
                  _BellButton(
                    onPressed: () => context.push(Routes.notifications),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // feature panel — the one ink surface
            Padding(
              padding: _gut,
              child: KBalancePanel(
                label: 'Portfolio value',
                balance: '₦2,418,650.00',
                change: '+₦34,210 · 1.43% today',
                changeTone: KTrend.gain,
                chart: KLineChart(
                  data: MockData.homeSeries,
                  onDark: true,
                  height: 120,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // quick actions
            Padding(
              padding: _gut,
              child: Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      label: 'Add money',
                      icon: 'arrowDownLeft',
                      onTap: () => showAddMoneyFlow(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      label: 'Invest',
                      icon: 'arrowUpRight',
                      onTap: () => context.go(Routes.markets),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      label: 'Withdraw',
                      icon: 'arrowUp',
                      onTap: () => showWithdrawFlow(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // watchlist strip
            Padding(
              padding: _gut,
              child: Row(
                children: [
                  const KEyebrow('Watchlist'),
                  const Spacer(),
                  _SeeAll(onTap: () => context.push(Routes.watchlist)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 152,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, 4),
                children: [
                  for (final a in MockData.watchlist.where((a) => watch.contains(a.ticker)))
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _WatchCard(
                        asset: a,
                        onTap: () => context.push(Routes.assetDetail(a.ticker)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // holdings preview → portfolio (header format matches Watchlist:
            // eyebrow left, See all right)
            Padding(
              padding: _gut,
              child: Row(
                children: [
                  const KEyebrow('Holdings'),
                  const Spacer(),
                  _SeeAll(onTap: () => context.go(Routes.portfolio)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: _gut,
              child: KCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < MockData.holdings.length; i++)
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: i == 0
                                ? BorderSide.none
                                : const BorderSide(color: KColor.hairline, width: 1),
                          ),
                        ),
                        child: KAssetRow(
                          name: MockData.holdings[i].name,
                          ticker: MockData.holdings[i].ticker,
                          price: MockData.holdings[i].price,
                          change: MockData.holdings[i].change,
                          trend: _k(MockData.holdings[i].trend),
                          logoColor: MockData.holdings[i].logoColor ?? KColor.ink,
                          onTap: () =>
                              context.push(Routes.assetDetail(MockData.holdings[i].ticker)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // trending
            const Padding(
              padding: _gut,
              child: KEyebrow('Trending'),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: _gut,
              child: KCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < MockData.trending.length; i++)
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: i == 0
                                ? BorderSide.none
                                : const BorderSide(color: KColor.hairline, width: 1),
                          ),
                        ),
                        child: KAssetRow(
                          name: MockData.trending[i].name,
                          ticker: MockData.trending[i].ticker,
                          price: MockData.trending[i].price,
                          change: MockData.trending[i].change,
                          trend: _k(MockData.trending[i].trend),
                          logoColor: MockData.trending[i].logoColor ?? KColor.ink,
                          onTap: () =>
                              context.push(Routes.assetDetail(MockData.trending[i].ticker)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Orders link
            const Padding(
              padding: _gut,
              child: KEyebrow('Activity'),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: _gut,
              child: KCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                onTap: () => context.push(Routes.orderStatus),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  child: Row(
                    children: [
                      const _Bubble(icon: 'transfer'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Orders', style: KType.cardTitle()),
                            const SizedBox(height: 2),
                            Text('Track your buy & sell orders',
                                style: KType.micro(color: KColor.ink3)),
                          ],
                        ),
                      ),
                      const KIcon('chevronRight', size: 20, color: KColor.ink3),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Local bits ───────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: KColor.bg,
        shape: BoxShape.circle,
        border: Border.all(color: KColor.hairline, width: 1),
      ),
      child: Text(initial.toUpperCase(),
          style: KType.cardTitle(w: KWeight.semibold).copyWith(fontSize: 14)),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          KIconButton(
            icon: 'bell',
            semanticLabel: 'Notifications',
            onPressed: onPressed,
          ),
          Positioned(
            top: 8,
            right: 9,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: KColor.indicator,
                shape: BoxShape.circle,
                border: Border.all(color: KColor.paper, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeeAll extends StatelessWidget {
  const _SeeAll({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text('See all'.upper,
          style: KType.micro(color: KColor.ink2, w: KWeight.semibold)
              .copyWith(letterSpacing: 0.06 * 10)),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.label, required this.icon, required this.onTap});
  final String label;
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KIcon(icon, size: 22, color: KColor.ink),
            const SizedBox(height: 8),
            Text(label,
                maxLines: 1,
                style: KType.micro(color: KColor.ink, w: KWeight.medium)
                    .copyWith(letterSpacing: 0.01 * 10)),
          ],
        ),
      ),
    );
  }
}

class _WatchCard extends StatelessWidget {
  const _WatchCard({required this.asset, required this.onTap});
  final Asset asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loss = asset.trend == Trend.loss;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KColor.paper,
          borderRadius: BorderRadius.circular(KRadii.card),
          border: Border.all(color: KColor.hairline, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: asset.logoColor ?? KColor.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Text(asset.ticker.substring(0, 2),
                      style: KType.label(color: KColor.paper, w: KWeight.semibold)
                          .copyWith(fontSize: 10, letterSpacing: 0, height: 1.0)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(asset.ticker,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KType.micro(color: KColor.ink2)
                          .copyWith(letterSpacing: 0.06 * 10)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(asset.price, style: KType.cardTitle(w: KWeight.semibold).tnum),
            const SizedBox(height: 2),
            Text(asset.change,
                style: KType.label(color: loss ? KColor.loss : KColor.gain)
                    .copyWith(letterSpacing: 0)
                    .tnum),
            const SizedBox(height: 10),
            KSparkline(
              data: asset.sparkline,
              trend: loss ? KTrend.loss : KTrend.gain,
              width: 118,
              height: 30,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small bubble icon used by list rows.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.icon});
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: KColor.bg,
        shape: BoxShape.circle,
        border: Border.all(color: KColor.hairline, width: 1),
      ),
      child: KIcon(icon, size: 18, color: KColor.ink),
    );
  }
}
