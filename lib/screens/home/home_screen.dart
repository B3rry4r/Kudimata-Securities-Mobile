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
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/asset_repository.dart';
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/data/repositories/watchlist_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/data/repositories/wallet_repository.dart';
import 'package:kudimata_invest/screens/onboarding/log_in_screen.dart' show refreshKycGatingState;
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/screens/wallet/wallet_flows.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);

KTrend _kTrend(Trend t) => t == Trend.gain ? KTrend.gain : KTrend.loss;

/// Picks the holding with the largest |% change| and writes one plain
/// sentence about it — the digest's actual number always traces to real
/// data, even though the wording template itself is static.
String _weeklyDigest(List<Asset> holdings) {
  double pct(Asset a) =>
      double.tryParse(a.change.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  final top = holdings.reduce((a, b) => pct(a) >= pct(b) ? a : b);
  final verb = top.trend == Trend.gain ? 'carried' : 'weighed on';
  return '${top.name} $verb your portfolio this week, ${top.change} since your last check-in. '
      'Nothing here needs a decision from you today.';
}

/// Combined payload for the single screen-level FutureBuilder.
class _HomeData {
  const _HomeData({
    required this.user,
    required this.summary,
    required this.watchlist,
    required this.holdings,
    required this.trending,
    required this.walletBalance,
  });

  final UserProfile user;
  final PortfolioSummary summary;
  final List<Asset> watchlist;
  final List<Asset> holdings;
  final List<Asset> trending;

  /// Preformatted "₦10,000.00" (WalletRepository.balance()) — 2026-08-20
  /// directive: "can we see amount in funded wallet too on the home
  /// screen somewhere please... or in the portfolio card". Added onto the
  /// SAME concurrent load/poll cycle the rest of this screen already
  /// runs, rather than a separate fetch.
  final String walletBalance;
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
  late final _walletRepo = WalletRepository(AppScope.read(context).apiClient);
  late Future<_HomeData> _future = _load();

  /// The data actually rendered — set once the FIRST silent poll succeeds,
  /// and from then on preferred over the FutureBuilder's own snapshot (see
  /// build()). This is what lets _silentRefresh() update the screen
  /// WITHOUT ever touching `_future` — reassigning `_future` on every poll
  /// tick (this screen's own earlier approach) made FutureBuilder drop
  /// back to ConnectionState.waiting for one frame every time, flashing
  /// the whole screen back to KLoadingView (2026-08-20 fix — reported:
  /// "when I said poll, I didn't say poll and keep refreshing and
  /// flashing my screen... when there is data change the UI should be
  /// updated like it's real time"). Reset to null on an intentional
  /// reload (watchlist change, manual retry) so THOSE still show the
  /// loading state, same as before — only the silent background poll
  /// skips it.
  _HomeData? _data;

  // Tracks AppState.watchlistVersion as of the last _load() so a toggle made
  // elsewhere (asset_detail_screen.dart, watchlist_screen.dart) is reflected
  // in the watchlist strip immediately, instead of only on the next
  // unrelated rebuild of this tab. Seeded from the current version in
  // initState (a non-listening read) so the very first build doesn't
  // trigger a redundant second _load().
  late int _loadedWatchlistVersion;

  // POLLING (2026-08-20, "poll the KYC endpoint... so we can see changes
  // instantly without refreshing since no realtime yet"). A staff decision
  // (or the auto-approve path) can flip AppState.kycApproved while an
  // investor just sits on Home — without this, they'd only see it after
  // force-quitting/relaunching, since hydrateGatingStateAndRoute otherwise
  // only runs once, at login. Same 8s interval submitted.dart's own polling
  // uses, for consistency; stops itself once the outcome is final either
  // way (approved, or a genuine terminal rejected/flagged/expired).
  //
  // Starts whenever `!kycApproved` — NOT gated on `kycSubmitted` (fixed
  // 2026-08-20, reported: "why am I seeing complete kyc on my account
  // that has already been approved"). refreshKycGatingState only updates
  // AppState's flags when GET /kyc-submissions/me actually succeeds; if
  // that ONE call fails for any reason at login (a network blip, or the
  // API being mid-restart at that exact moment), kycSubmitted/kycApproved
  // silently stay at their `false` defaults — a fully-approved investor
  // then looks identical to a brand-new one, with nothing to self-correct
  // it, since the old `kycSubmitted &&` guard never let polling start in
  // that state at all.
  Timer? _kycPollTimer;
  static const _kycPollInterval = Duration(seconds: 8);

  // POLLING (2026-08-20, "when I buy a stock I can't see the changes on
  // home screen immediately... poll, we would do real time web sockets
  // later"). A buy/sell fill changes portfolio value and the holdings
  // preview, but this screen otherwise only reloads on a manual
  // pull-to-refresh or an unrelated rebuild (e.g. a watchlist toggle
  // elsewhere) — so a fresh trade made from Markets/asset-detail didn't
  // show up here until the investor did something else first. Silently
  // re-fetches in the background (no spinner, no error state of its own —
  // a flaky tick just leaves the last-good numbers showing, same
  // treatment wallet_screens.dart's own silent refresh uses) rather than
  // reassigning `_future` naively, which would otherwise flash the whole
  // screen back to KLoadingView on every tick.
  Timer? _portfolioPollTimer;
  static const _portfolioPollInterval = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _loadedWatchlistVersion = AppScope.read(context).watchlistVersion;
    final app = AppScope.read(context);
    if (!app.kycApproved) {
      _kycPollTimer = Timer.periodic(_kycPollInterval, (_) => _pollKycStatus());
    }
    _portfolioPollTimer = Timer.periodic(_portfolioPollInterval, (_) => _silentRefresh());
  }

  Future<void> _silentRefresh() async {
    try {
      final data = await _load();
      if (!mounted) return;
      setState(() => _data = data);
    } on Object {
      // A poll tick failing (flaky network blip) shouldn't blank out an
      // already-loaded screen — just try again next tick.
    }
  }

  Future<void> _pollKycStatus() async {
    await refreshKycGatingState(context);
    if (!mounted) return;
    final app = AppScope.read(context);
    // Stop once the outcome is final either way — approved, or a genuine
    // terminal rejected/flagged/expired (2026-08-20 fix, see
    // AppState.kycOutcomeStatus) — no point re-checking a decision that's
    // already landed.
    if (app.kycApproved || app.kycOutcomeStatus != null) {
      _kycPollTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _kycPollTimer?.cancel();
    _portfolioPollTimer?.cancel();
    super.dispose();
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
    final (user, summary, watchlist, holdingsPage, trending, walletBalance) = await (
      _userRepo.me(),
      _holdingsRepo.summary(),
      _watchlistRepo.items(),
      _holdingsRepo.holdings(pageSize: 5),
      _assetRepo.trending(),
      _walletRepo.balance(),
    ).wait;

    return _HomeData(
      user: user,
      summary: summary,
      watchlist: watchlist,
      holdings: holdingsPage.data.map((h) => h.asset).toList(),
      trending: trending,
      walletBalance: walletBalance,
    );
  }

  @override
  Widget build(BuildContext context) {
    final watchlistVersion = AppScope.of(context).watchlistVersion;
    if (watchlistVersion != _loadedWatchlistVersion) {
      _loadedWatchlistVersion = watchlistVersion;
      _future = _load();
      // An intentional reload SHOULD show the loading state — only a
      // silent background poll skips it. Dropping the last poll's data
      // here means this reload's own FutureBuilder snapshot drives the
      // screen until it resolves, same as before polling existed.
      _data = null;
    }

    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snapshot) {
            // Prefer the freshest silently-polled data over the
            // FutureBuilder's own (possibly stale, or momentarily
            // "waiting" if `_future` was just reassigned above) snapshot —
            // see `_data`'s doc comment.
            final effective = _data ?? snapshot.data;
            if (effective == null) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const KLoadingView();
              }
              if (snapshot.hasError) {
                return KErrorView.failedLoad(
                  onPrimary: () => setState(() {
                    _future = _load();
                    _data = null;
                  }),
                );
              }
            }
            return _HomeBody(data: effective!);
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
    final first = data.user.firstName;

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
            // 2026-08-20 directive: "can we see amount in funded wallet
            // too on the home screen somewhere please... or in the
            // portfolio card" — a compact row inside the SAME ink panel,
            // rather than a whole second surface. Polled alongside
            // everything else this screen already fetches (see
            // _HomeData.walletBalance).
            action: _WalletBalanceRow(balance: data.walletBalance),
          ),
        ),
        const SizedBox(height: 16),

        // Browsing is open to everyone; only trading/funding require KYC +
        // suitability (see wallet_flows.dart's showAddMoneyFlow/
        // showWithdrawFlow and markets/asset_detail_screen.dart's Buy/Sell,
        // which all gate on these same AppState flags — backed server-side
        // too, OrdersService/TransactionsService). This prompts the investor
        // toward whichever step of that they haven't finished yet; shows
        // nothing once both are done. AppScope.of (not .read) so it reacts
        // live once hydrateGatingStateAndRoute (log_in_screen.dart) or the
        // KYC/suitability flow itself updates these flags.
        _KycPrompt(app: AppScope.of(context)),

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

        // "Your week on the NGX" — a generated portfolio narrative
        // (2026-08-22 "Soft Landing" redesign's comprehension layer, spec
        // screen 29). No real AI backend exists yet for this (see
        // docs/redesign/PLAN.md) — the sentence below is computed from the
        // investor's own real holdings data (biggest mover), not canned
        // per-account text, but it isn't LLM-generated either.
        if (data.holdings.isNotEmpty) ...[
          Padding(padding: _gut, child: KDigestCard(
            title: 'Your week on the NGX',
            body: _weeklyDigest(data.holdings),
          )),
          const SizedBox(height: 28),
        ],

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

/// Compact "Wallet balance · ₦X" row inside the portfolio panel's own
/// `action` slot — see the balance panel's own comment above for why.
class _WalletBalanceRow extends StatelessWidget {
  const _WalletBalanceRow({required this.balance});
  final String balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: KColor.featureInk2.withValues(alpha: 0.16), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Wallet balance', style: KType.label(color: KColor.featureInk2)),
          Text(balance, style: KType.body(color: KColor.featureInk, w: KWeight.semibold).tnum),
        ],
      ),
    );
  }
}

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

/// Prompts an investor who can't yet trade/fund toward whichever step
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

    // "This is the one important thing" grape-feature plate (2026-08-22
    // redesign, spec screen 30's colour note) — the same indicator-tint /
    // r-feature treatment used for the DCS explainer (KYC screen 19) and
    // this screen's own onboarding-progress card.
    return Padding(
      padding: EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, 16),
      child: GestureDetector(
        onTap: () => context.push(gap.route),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: KColor.indicatorTint, borderRadius: KRadii.featureR),
          child: Row(
            children: [
              const _Bubble(icon: 'profile'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gap.title, style: KType.cardTitle(color: KColor.indicatorPress)),
                    const SizedBox(height: 2),
                    Text(gap.message, style: KType.micro(color: KColor.ink3)),
                  ],
                ),
              ),
              KIcon('chevronRight', size: 20, color: KColor.indicator),
            ],
          ),
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
