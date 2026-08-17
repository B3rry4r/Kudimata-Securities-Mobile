// Home tab root — greeting, the one BalancePanel (portfolio value + KLineChart),
// quick-actions row, watchlist strip, holdings preview, trending, Orders link.
// Ported from app-screens.jsx `Home`. Root tab: builds a Scaffold body WITHOUT a
// bottom nav — the shell owns that. Numbers tabular; movement colour on numbers.
//
// Wired to the backend per lib/data/api/README.md's FutureBuilder convention.
// Four repositories back this screen's five reads, combined into one
// `Future.wait`-style load (kicked off concurrently, awaited in sequence) fed
// through a single screen-level FutureBuilder — one spinner/retry for the
// whole tab rather than five nested ones:
//   UserRepository.me()             GET /users/me                — greeting name
//   HoldingsRepository.summary()    GET /portfolio-summary        — BalancePanel
//     (totalValue/change/chartSeries; replaces the old hardcoded literals —
//     STUB-home-1 in .pipeline/fragments/home.json — with the SAME aggregate
//     the portfolio screen uses, per that stub's own reconciliation note)
//   WatchlistRepository.items()     GET /watchlist-items          — watchlist strip
//     (already scoped server-side to the caller's saved tickers, so this
//     screen no longer intersects it with AppState.watchlistTickers itself —
//     that set/toggleWatch stays for the add/remove-watchlist UI elsewhere)
//   HoldingsRepository.holdings()   GET /holdings                 — holdings preview
//     (Holding itself has no display fields; .asset is the joined Asset&Quote
//     HoldingsRepository already resolves — see that file's header. pageSize: 5
//     keeps this a "preview" card, matching its "See all → portfolio" link)
//   AssetRepository.trending()      GET /assets/trending           — trending list
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/asset_repository.dart';
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/data/repositories/watchlist_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);

KTrend _kTrend(Trend t) => t == Trend.gain ? KTrend.gain : KTrend.loss;

/// Combined payload for the single screen-level FutureBuilder.
class _HomeData {
  const _HomeData({
    required this.user,
    required this.summary,
    required this.watchlist,
    required this.holdings,
    required this.trending,
  });

  final UserProfile user;
  final PortfolioSummary summary;
  final List<Asset> watchlist;
  final List<Asset> holdings;
  final List<Asset> trending;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);
  late final _holdingsRepo = HoldingsRepository(AppScope.read(context).apiClient);
  late final _watchlistRepo = WatchlistRepository(AppScope.read(context).apiClient);
  late final _assetRepo = AssetRepository(AppScope.read(context).apiClient);
  late Future<_HomeData> _future = _load();

  // Tracks AppState.watchlistVersion as of the last _load() so a toggle made
  // elsewhere (asset_detail_screen.dart, watchlist_screen.dart) is reflected
  // in the watchlist strip immediately, instead of only on the next
  // unrelated rebuild of this tab. Seeded from the current version in
  // initState (a non-listening read) so the very first build doesn't
  // trigger a redundant second _load().
  late int _loadedWatchlistVersion;

  @override
  void initState() {
    super.initState();
    _loadedWatchlistVersion = AppScope.read(context).watchlistVersion;
  }

  Future<_HomeData> _load() async {
    // Run all five requests concurrently via the record `.wait` extension —
    // NOT firing them all then awaiting sequentially (`await a; await b; ...`)
    // like this used to: if an EARLIER-awaited future rejects, that pattern
    // throws immediately and abandons the still-in-flight later futures,
    // which then reject with nothing listening — an "unhandled exception"
    // (harmless-looking in a real run, but real: extra console noise/crash-
    // reporting spam, and it's exactly what made
    // test/theme_toggle_test.dart's Home render intermittently fail once
    // that test started giving AppState a real (network-dead) apiClient).
    // `.wait` attaches a listener to every future up front, so none of them
    // can ever go unhandled, regardless of which one fails first.
    final (user, summary, watchlist, holdingsPage, trending) = await (
      _userRepo.me(),
      _holdingsRepo.summary(),
      _watchlistRepo.items(),
      _holdingsRepo.holdings(pageSize: 5),
      _assetRepo.trending(),
    ).wait;

    return _HomeData(
      user: user,
      summary: summary,
      watchlist: watchlist,
      holdings: holdingsPage.data.map((h) => h.asset).toList(),
      trending: trending,
    );
  }

  @override
  Widget build(BuildContext context) {
    final watchlistVersion = AppScope.of(context).watchlistVersion;
    if (watchlistVersion != _loadedWatchlistVersion) {
      _loadedWatchlistVersion = watchlistVersion;
      _future = _load();
    }

    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const KLoadingView();
            }
            if (snapshot.hasError) {
              return KErrorView.failedLoad(
                onPrimary: () => setState(() => _future = _load()),
              );
            }
            return _HomeBody(data: snapshot.data!);
          },
        ),
      ),
    );
  }
}

/// The loaded-state widget tree — identical to the original mock-fed
/// `build()`, just parameterized on fetched data instead of `MockData.x`.
class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.data});
  final _HomeData data;

  @override
  Widget build(BuildContext context) {
    final first = data.user.fullName.split(' ').first;

    return ListView(
      // Tab root: clear the floating KBottomNav (~70px + 12 margin + safe area).
      padding: const EdgeInsets.only(top: 12, bottom: 100),
      children: [
        // greeting row
        Padding(
          padding: _gut,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.push(Routes.acctPersonal),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    _Avatar(initial: first.isNotEmpty ? first[0] : 'K'),
                    const SizedBox(width: 12),
                    Text('Hi, $first', style: KType.section()),
                  ],
                ),
              ),
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
            balance: data.summary.totalValue,
            change: data.summary.change,
            changeTone: _kTrend(data.summary.changeTrend),
            chart: KLineChart(
              data: data.summary.chartSeries,
              onDark: true,
              height: 120,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Browsing is open to everyone; only trading requires KYC +
        // suitability (see markets/asset_detail_screen.dart's Buy/Sell,
        // which gates on these same AppState flags — backed server-side too,
        // OrdersService). This prompts the investor toward whichever step of
        // that they haven't finished yet; shows nothing once both are done.
        // AppScope.of (not .read) so it reacts live once
        // hydrateGatingStateAndRoute (log_in_screen.dart) or the
        // KYC/suitability flow itself updates these flags.
        _KycPrompt(app: AppScope.of(context)),
        const SizedBox(height: 12),

        // watchlist strip — GET /watchlist-items is already scoped server-side
        // to the caller's saved tickers, so no local AppState.watchlistTickers
        // filter here (unlike the old MockData.watchlist.where(...) version).
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
        data.watchlist.isEmpty
            ? Padding(
                padding: _gut,
                child: _WatchlistEmptyCard(
                  onTap: () => context.push(Routes.watchlist),
                ),
              )
            : SizedBox(
                height: 152,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, 4),
                  children: [
                    for (final a in data.watchlist)
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
        data.holdings.isEmpty
            ? Padding(
                padding: _gut,
                child: _HoldingsEmptyCard(
                  onTap: () => context.go(Routes.markets),
                ),
              )
            : Padding(
                padding: _gut,
                child: KCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < data.holdings.length; i++)
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: i == 0
                                  ? BorderSide.none
                                  : BorderSide(color: KColor.hairline, width: 1),
                            ),
                          ),
                          child: KAssetRow(
                            name: data.holdings[i].name,
                            ticker: data.holdings[i].ticker,
                            price: data.holdings[i].price,
                            change: data.holdings[i].change,
                            trend: _kTrend(data.holdings[i].trend),
                            logoColor: data.holdings[i].logoColor ?? KColor.ink,
                            onTap: () =>
                                context.push(Routes.assetDetail(data.holdings[i].ticker)),
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
                for (var i = 0; i < data.trending.length; i++)
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: i == 0
                            ? BorderSide.none
                            : BorderSide(color: KColor.hairline, width: 1),
                      ),
                    ),
                    child: KAssetRow(
                      name: data.trending[i].name,
                      ticker: data.trending[i].ticker,
                      price: data.trending[i].price,
                      change: data.trending[i].change,
                      trend: _kTrend(data.trending[i].trend),
                      logoColor: data.trending[i].logoColor ?? KColor.ink,
                      onTap: () =>
                          context.push(Routes.assetDetail(data.trending[i].ticker)),
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
                  KIcon('chevronRight', size: 20, color: KColor.ink3),
                ],
              ),
            ),
          ),
        ),
      ],
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

/// Prompts an investor who can't yet trade toward whichever step
/// they're missing (see the call site's comment). Renders nothing once
/// [AppState.kycApproved] and [AppState.suitabilityComplete] are both true.
/// Reuses the same `_Bubble`/KCard row treatment as `_WatchlistEmptyCard`
/// and the Orders card below, rather than a new visual language.
class _KycPrompt extends StatelessWidget {
  const _KycPrompt({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final gap = tradingEligibilityGap(app);
    if (gap == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, 16),
      child: KCard(
        onTap: () => context.push(gap.route),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const _Bubble(icon: 'profile'),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gap.title, style: KType.cardTitle()),
                  const SizedBox(height: 2),
                  Text(gap.message, style: KType.micro(color: KColor.ink3)),
                ],
              ),
            ),
            KIcon('chevronRight', size: 20, color: KColor.ink3),
          ],
        ),
      ),
    );
  }
}

/// Inline prompt shown in place of the holdings list when the investor
/// holds nothing yet — was previously just an empty KCard (zero children,
/// rendering as a bare sliver of padding/border), not an actual empty
/// state. Mirrors `_WatchlistEmptyCard` below. Taps through to Markets.
class _HoldingsEmptyCard extends StatelessWidget {
  const _HoldingsEmptyCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const _Bubble(icon: 'portfolio'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You have no holdings yet', style: KType.cardTitle()),
                const SizedBox(height: 2),
                Text('Browse Markets to make your first investment',
                    style: KType.micro(color: KColor.ink3)),
              ],
            ),
          ),
          KIcon('chevronRight', size: 20, color: KColor.ink3),
        ],
      ),
    );
  }
}

/// Inline prompt shown in place of the horizontal watchlist strip when the
/// investor has zero watched tickers — matches this screen's existing
/// `KCard` treatment (see the Orders card below) rather than leaving the
/// section blank. Taps through to the dedicated Watchlist screen.
class _WatchlistEmptyCard extends StatelessWidget {
  const _WatchlistEmptyCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const _Bubble(icon: 'plus'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your watchlist is empty', style: KType.cardTitle()),
                const SizedBox(height: 2),
                Text('Add stocks to your watchlist to see them here',
                    style: KType.micro(color: KColor.ink3)),
              ],
            ),
          ),
          KIcon('chevronRight', size: 20, color: KColor.ink3),
        ],
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
                      style: KType.label(color: KColor.featureInk, w: KWeight.semibold)
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
