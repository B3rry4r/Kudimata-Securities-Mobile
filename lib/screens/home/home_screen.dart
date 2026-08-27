// Home tab root — REBUILT from scratch per DECISIONS.md R-32: this file used
// to be built against stale old-canvas ids "s29"/"s30", which in the current
// 56-artboard canvas point at unrelated screens (the R-5 trap). Home is a
// new screen against the artboard ids named in RULINGS.md/R-15/R-32 —
// `s22`/`s22d` (verified investor) and `s23`/`s23d` (verification not
// finished), both in
// docs/design/redesign-2026-08/03 Home and Markets.dc.html — never from a
// comment in this file (R-5). Root tab: builds a Scaffold body WITHOUT a
// bottom nav — the shell owns that.
//
// s22/s23 structure, top to bottom (R-32's own checklist, all now built):
//   header: avatar + "Hi {name}" (tap → Account, R-28's header-avatar entry
//     point) + a bell (badge only when verified — s22's IconButton carries
//     `badge="{{ true }}"`, s23's omits it). No search icon in Home's own
//     header — Markets owns its own search pill (markets_screen.dart).
//   s23 only: a KYC banner above the money card (_VerifyBanner).
//   the "Total wealth" money card, paper surface + the naira illustration
//     (money-coins.svg) + two stat pills (verified) or a plain sentence
//     (not verified) — KBalancePanel's new `light` variant (see
//     lib/widgets/finance.dart's doc comment on why this is a shared-widget
//     prop, not a fork: the same card shape recurs on Portfolio/Wallet's own
//     canvas, '05 Portfolio and Wallet.dc.html').
//   five round quick actions (Add/Withdraw/Invest/Orders/Learn) — s22 all
//     active, s23 Withdraw+Invest disabled and Invest additionally locked.
//   "Grow with Kudimata" (s22) / "While you wait" (s23) — R-29 external
//     links (KLinks) to existing kudimata.app products, static promo cards,
//     never progress cards (R-29's own instruction: no "Lesson N of 12").
//   the rotating "Top movers today" (s22, with a "Markets" link) / "Have a
//     look around" (s23, no link) card — _TopMoverCard, real data from
//     AssetRepository.trending().
//   s22 only, kept per D-6b/R-15 ("the app's holdings and trending rails are
//     kept within it"): "Your holdings" and "Trending now". Watchlist is
//     ALSO kept, despite not being in s22 at all — a 2026-08-24 direct
//     product instruction ("I just added a stock to watchlist and went back
//     home screen and I did not see it"), the same standing as Cancel on
//     Orders (R-17): real and wired, the canvas just never drew it.
//
// REMOVED per R-6: the "WRITTEN FOR YOU" AI digest card (portfolioDigest).
// The AI-credits line is parked, not cut — AiRepository and its screens
// stay in the tree; only this entry point is gone.
//
// Wired to the backend per lib/data/api/README.md's FutureBuilder
// convention. Repositories back this screen's reads, combined into one
// `Future.wait`-style load (kicked off concurrently) fed through a single
// screen-level FutureBuilder — one spinner/retry for the whole tab rather
// than several:
//   UserRepository.me()             GET /users/me                — greeting name
//   HoldingsRepository.summary()    GET /portfolio-summary        — money card
//   HoldingsRepository.holdings()   GET /holdings                 — holdings list
//   AssetRepository.trending()      GET /assets/trending          — movers card
//     + the kept "Trending now" rail (same real feed, two different views)
//   WalletRepository.balance()      GET /wallet-balance           — money card
//   WatchlistRepository.items()     GET /watchlist                — kept rail
//
// "Total wealth" (s22/s23's headline figure) is wallet balance + portfolio
// value summed client-side — both real, already-fetched numbers (the
// backend has no single combined endpoint), not an invented one; see
// _formatWealth/_parseAmount below.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/asset_repository.dart';
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/data/repositories/watchlist_repository.dart';
import 'package:kudimata_invest/k_links.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/data/repositories/wallet_repository.dart';
import 'package:kudimata_invest/screens/onboarding/log_in_screen.dart' show refreshKycGatingState;
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/screens/wallet/wallet_flows.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);

KTrend _kTrend(Trend t) => t == Trend.gain ? KTrend.gain : KTrend.loss;

/// Pulls the leading signed percentage out of `PortfolioSummary.change`
/// ("+₦418,650.00 · 20.9% all-time" → "+20.9%") for the money card's
/// portfolio pill. Real, already-fetched data — s22 draws an unlabeled
/// "+3.1%" with no day/all-time qualifier, and the backend has no separate
/// day-change figure to show in its place.
String _pctOf(String change) {
  final m = RegExp(r'[+\-−]\s?\d+(?:\.\d+)?%').firstMatch(change);
  return m == null ? '' : m.group(0)!.replaceAll(' ', '');
}

double _parseAmount(String formatted) =>
    double.tryParse(formatted.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

/// Same comma-grouped "₦x,xxx.xx" shape HoldingsRepository/WalletRepository
/// already format every other naira figure into.
String _formatWealth(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final fromEnd = whole.length - i;
    if (i != 0 && fromEnd % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  return '₦${buf.toString()}.${parts[1]}';
}

/// Best-effort hand-off to the device browser for the R-29 external links —
/// same seam as help_support_screen.dart's `_launch`: a promo card, not a
/// form, has no in-app surface to report failure on.
Future<void> _openExternal(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    // Silently stays on Home — see doc comment above.
  }
}

/// Combined payload for the single screen-level FutureBuilder.
class _HomeData {
  const _HomeData({
    required this.user,
    required this.summary,
    required this.holdings,
    required this.trending,
    required this.walletBalance,
    required this.watchlist,
  });

  final UserProfile user;
  final PortfolioSummary summary;
  final List<Asset> holdings;
  final List<Asset> trending;
  final List<Asset> watchlist;

  /// Preformatted "₦10,000.00" (WalletRepository.balance()).
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
  late final _assetRepo = AssetRepository(AppScope.read(context).apiClient);
  late final _walletRepo = WalletRepository(AppScope.read(context).apiClient);
  late final _watchlistRepo = WatchlistRepository(AppScope.read(context).apiClient);

  // 2026-08-24 fix — reported live: "for a couple of seconds I still see
  // the not verified state" before it flips to the real verified body.
  // Root cause: AppState.kycApproved is in-memory only and only ever gets
  // hydrated by hydrateGatingStateAndRoute/refreshKycGatingState, which
  // normally runs before Home is ever navigated to — EXCEPT on a plain
  // page reload (this is a web build): app_router.dart's _gateRedirect
  // free-roams straight to whatever location the URL already had once
  // AppState.signedIn restores from secure storage, with no login/unlock
  // step in between to trigger that hydration. The FIRST load now always
  // awaits a fresh gating check before Home decides which body to show —
  // _load() itself (used by every later reload/silent refresh) is
  // untouched, so this doesn't repeat the check on every 8s portfolio poll
  // tick.
  late Future<_HomeData> _future = _initialLoad();

  Future<_HomeData> _initialLoad() async {
    await refreshKycGatingState(context);
    return _load();
  }

  /// The data actually rendered — set once the FIRST silent poll succeeds,
  /// and from then on preferred over the FutureBuilder's own snapshot (see
  /// build()). This is what lets _silentRefresh() update the screen
  /// WITHOUT ever touching `_future` — reassigning `_future` on every poll
  /// tick made FutureBuilder drop back to ConnectionState.waiting for one
  /// frame every time, flashing the whole screen back to KLoadingView.
  /// Reset to null on an intentional reload (manual retry) so THAT still
  /// shows the loading state — only the silent background poll skips it.
  _HomeData? _data;

  // POLLING (2026-08-20, "poll the KYC endpoint... so we can see changes
  // instantly without refreshing since no realtime yet"). A staff decision
  // (or the auto-approve path) can flip AppState.kycApproved while an
  // investor just sits on Home — without this, they'd only see it after
  // force-quitting/relaunching. Same 8s interval submitted.dart's own
  // polling uses; stops itself once the outcome is final either way
  // (approved, or a genuine terminal rejected/flagged/expired).
  Timer? _kycPollTimer;
  static const _kycPollInterval = Duration(seconds: 8);

  // POLLING (2026-08-20, "when I buy a stock I can't see the changes on
  // home screen immediately... poll, we would do real time web sockets
  // later"). Silently re-fetches in the background (no spinner, no error
  // state of its own — a flaky tick just leaves the last-good numbers
  // showing) rather than reassigning `_future` naively, which would
  // otherwise flash the whole screen back to KLoadingView on every tick.
  Timer? _portfolioPollTimer;
  static const _portfolioPollInterval = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
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
    // Run all requests concurrently via the record `.wait` extension — an
    // earlier-awaited future rejecting must not abandon still-in-flight
    // later futures with nothing listening (an unhandled-exception source
    // found live via test/theme_toggle_test.dart's Home render).
    final (user, summary, holdingsPage, trending, walletBalance, watchlist) = await (
      _userRepo.me(),
      _holdingsRepo.summary(),
      _holdingsRepo.holdings(pageSize: 5),
      _assetRepo.trending(),
      _walletRepo.balance(),
      _watchlistRepo.items(),
    ).wait;

    return _HomeData(
      user: user,
      summary: summary,
      holdings: holdingsPage.data.map((h) => h.asset).toList(),
      trending: trending,
      walletBalance: walletBalance,
      watchlist: watchlist,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snapshot) {
            final effective = _data ?? snapshot.data;
            if (effective == null) {
              // LOADING — first paint, before the initial load resolves.
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const KLoadingView();
              }
              // ERROR — the initial load rejected and nothing is cached yet.
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

/// The loaded-state widget tree — routes to the structurally distinct
/// verified/not-verified bodies per s22/s23 (see file header).
class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.data});
  final _HomeData data;

  @override
  Widget build(BuildContext context) {
    final first = data.user.firstName;
    final notVerified = tradingEligibilityGap(AppScope.of(context)) != null;

    return ListView(
      // Tab root: clear the floating KBottomNav (~70px + 12 margin + safe area).
      padding: const EdgeInsets.only(top: 12, bottom: 100),
      children: [
        Padding(
          padding: _gut,
          child: Row(
            children: [
              GestureDetector(
                // R-28: the header avatar is Account's only entry point from
                // Home (the removed "You" tab used to go here).
                onTap: () => context.push(Routes.account),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    data.user.avatarKey != null
                        ? KAvatar(avatarKey: data.user.avatarKey!, size: 36)
                        : _Avatar(initial: first.isNotEmpty ? first[0] : 'K'),
                    const SizedBox(width: 10),
                    Text('Hi $first',
                        style: KType.cardTitle(w: KWeight.bold).copyWith(fontSize: 17)),
                  ],
                ),
              ),
              const Spacer(),
              _BellButton(
                onPressed: () => context.push(Routes.notifications),
                showBadge: !notVerified,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (notVerified)
          ..._NotVerifiedContent(data: data).build(context)
        else
          ..._VerifiedContent(data: data).build(context),
      ],
    );
  }
}

/// s22 — "Home, verified".
class _VerifiedContent {
  const _VerifiedContent({required this.data});
  final _HomeData data;

  List<Widget> build(BuildContext context) {
    final pct = _pctOf(data.summary.change);
    final totalWealth =
        _formatWealth(_parseAmount(data.summary.totalValue) + _parseAmount(data.walletBalance));
    final movers = data.trending.take(3).toList();

    return [
      // Money card — paper surface, naira illustration, two stat pills.
      Padding(
        padding: _gut,
        child: KBalancePanel(
          label: 'Total wealth',
          balance: totalWealth,
          light: true,
          illustration: SvgPicture.asset('assets/illustrations/money-coins.svg', height: 64),
          action: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatPill(
                icon: 'wallet',
                child: Text(data.walletBalance,
                    style: KType.data(color: KColor.ink, w: KWeight.semibold).copyWith(fontSize: 13)),
              ),
              _StatPill(
                icon: 'portfolio',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(data.summary.totalValue,
                        style:
                            KType.data(color: KColor.ink, w: KWeight.semibold).copyWith(fontSize: 13)),
                    if (pct.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(pct,
                          style: KType.data(
                                  color:
                                      data.summary.changeTrend == Trend.loss ? KColor.loss : KColor.gain,
                                  w: KWeight.bold)
                              .copyWith(fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),

      // Five round quick actions — exact s22 set/order/labels, all active.
      Padding(
        padding: const EdgeInsets.only(left: KSpace.gutter),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.only(right: KSpace.gutter),
            child: Row(
              children: [
                _QuickAction(
                  label: 'Add',
                  icon: 'plus',
                  style: _ActionStyle.primary,
                  onTap: () => showAddMoneyFlow(context),
                ),
                const SizedBox(width: 18),
                _QuickAction(
                  label: 'Withdraw',
                  icon: 'arrowUpRight',
                  style: _ActionStyle.tinted,
                  onTap: () => showWithdrawFlow(context),
                ),
                const SizedBox(width: 18),
                _QuickAction(
                  label: 'Invest',
                  icon: 'markets',
                  style: _ActionStyle.tinted,
                  onTap: () => context.go(Routes.markets),
                ),
                const SizedBox(width: 18),
                _QuickAction(
                  label: 'Orders',
                  icon: 'clock',
                  style: _ActionStyle.tinted,
                  onTap: () => context.push(Routes.orderStatus),
                ),
                const SizedBox(width: 18),
                // 'Learn' carries no destination in s22's own markup (no
                // onClick drawn, unlike Add/Orders). Routed to the app's one
                // general reading surface (FAQ + the surviving plain-
                // language glossary, R-6) as the closest real match for a
                // doc-icon "Learn" action.
                _QuickAction(
                  label: 'Learn',
                  icon: 'doc',
                  style: _ActionStyle.tinted,
                  onTap: () => context.push(Routes.acctFaq),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 30),

      // "Grow with Kudimata" — R-29 external links, static promo cards.
      Padding(
        padding: _gut,
        child: Text('Grow with Kudimata',
            style: KType.cardTitle(w: KWeight.black).copyWith(fontSize: 22, height: 26 / 22)),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.only(left: KSpace.gutter),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.only(right: KSpace.gutter),
            child: Row(
              children: [
                _GrowCard(
                  illustration: 'kd-readiness',
                  background: KColor.feature,
                  titleColor: KColor.featureInk,
                  title: 'How ready are you to invest?',
                  cta: 'Check your readiness',
                  ctaColor: KColor.sun,
                  url: KLinks.readiness,
                ),
                const SizedBox(width: 12),
                _GrowCard(
                  illustration: 'kd-persona',
                  background: KColor.sunTint,
                  titleColor: KColor.ink,
                  title: "What's your money persona?",
                  cta: 'Take the quiz',
                  ctaColor: KColor.indicator,
                  url: KLinks.persona,
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: _gut,
        child: _LiteracyRow(onTap: () => _openExternal(KLinks.financialLiteracy)),
      ),
      const SizedBox(height: 26),

      // "Top movers today" — rotating, real data (AssetRepository.trending).
      // EMPTY: no trending assets at all — the whole section is left off
      // rather than a rotator with nothing to show.
      if (movers.isNotEmpty) ...[
        Padding(
          padding: _gut,
          child: Row(
            children: [
              Expanded(
                child: Text('Top movers today', style: KType.cardTitle().copyWith(fontSize: 18)),
              ),
              GestureDetector(
                onTap: () => context.go(Routes.markets),
                child: Text('Markets',
                    style:
                        KType.data(color: KColor.indicator, w: KWeight.semibold).copyWith(fontSize: 15)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(padding: _gut, child: _TopMoverCard(movers: movers)),
        const SizedBox(height: 28),
      ],

      // "Your holdings" — kept per D-6b/R-15. No "See all" affordance in s22.
      Padding(padding: _gut, child: const KEyebrow('Your holdings')),
      const SizedBox(height: 8),
      // EMPTY: a verified investor with zero holdings.
      if (data.holdings.isEmpty)
        Padding(
          padding: _gut,
          child: KEmptyView.holdings(onAction: () => context.go(Routes.markets)),
        )
      else
        Padding(
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

      // Watchlist — kept despite not being in s22 at all: a 2026-08-24
      // direct product instruction ("I just added a stock to watchlist and
      // went back home screen and I did not see it"), the same standing as
      // Cancel on Orders (R-17) — real and wired, the canvas just never
      // drew it. Only shown when non-empty.
      if (data.watchlist.isNotEmpty) ...[
        const SizedBox(height: 20),
        Padding(padding: _gut, child: const KEyebrow('Watchlist')),
        const SizedBox(height: 8),
        Padding(
          padding: _gut,
          child: KCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < data.watchlist.length; i++)
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: i == 0
                            ? BorderSide.none
                            : BorderSide(color: KColor.hairline, width: 1),
                      ),
                    ),
                    child: KAssetRow(
                      name: data.watchlist[i].name,
                      ticker: data.watchlist[i].ticker,
                      price: data.watchlist[i].price,
                      change: data.watchlist[i].change,
                      trend: _kTrend(data.watchlist[i].trend),
                      logoColor: data.watchlist[i].logoColor ?? KColor.ink,
                      onTap: () =>
                          context.push(Routes.assetDetail(data.watchlist[i].ticker)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],

      // Trending — kept per D-6b/R-15, a standing section (not an
      // empty-state fallback — see 01d69a0). Only shown when non-empty.
      if (data.trending.isNotEmpty) ...[
        const SizedBox(height: 28),
        Padding(padding: _gut, child: const KEyebrow('Trending now')),
        const SizedBox(height: 8),
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
      ],
    ];
  }
}

/// s23 — "Home, first time (verification not finished)".
class _NotVerifiedContent {
  const _NotVerifiedContent({required this.data});
  final _HomeData data;

  List<Widget> build(BuildContext context) {
    final app = AppScope.of(context);
    final gap = tradingEligibilityGap(app);
    final totalWealth =
        _formatWealth(_parseAmount(data.summary.totalValue) + _parseAmount(data.walletBalance));
    final movers = data.trending.take(3).toList();

    return [
      if (gap != null) ...[
        Padding(padding: _gut, child: _VerifyBanner(gap: gap)),
        const SizedBox(height: 16),
      ],

      Padding(
        padding: _gut,
        child: KBalancePanel(
          label: 'Total wealth',
          balance: totalWealth,
          light: true,
          illustration: Opacity(
            opacity: 0.5,
            child: SvgPicture.asset('assets/illustrations/money-coins.svg', height: 64),
          ),
          action: Text(
            "You can add money now and buy once you're verified.",
            style: KType.body(color: KColor.ink3).copyWith(fontSize: 14, height: 20 / 14),
          ),
        ),
      ),
      const SizedBox(height: 20),

      // Five round quick actions — Withdraw disabled, Invest disabled +
      // locked (s23's own markup); Add/Orders/Learn stay active.
      Padding(
        padding: const EdgeInsets.only(left: KSpace.gutter),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.only(right: KSpace.gutter),
            child: Row(
              children: [
                _QuickAction(
                  label: 'Add',
                  icon: 'plus',
                  style: _ActionStyle.primary,
                  onTap: () => showAddMoneyFlow(context),
                ),
                const SizedBox(width: 18),
                const _QuickAction(label: 'Withdraw', icon: 'arrowUpRight', style: _ActionStyle.disabled),
                const SizedBox(width: 18),
                const _QuickAction(
                  label: 'Invest',
                  icon: 'markets',
                  style: _ActionStyle.disabled,
                  locked: true,
                ),
                const SizedBox(width: 18),
                _QuickAction(
                  label: 'Orders',
                  icon: 'clock',
                  style: _ActionStyle.tinted,
                  onTap: () => context.push(Routes.orderStatus),
                ),
                const SizedBox(width: 18),
                _QuickAction(
                  label: 'Learn',
                  icon: 'doc',
                  style: _ActionStyle.tinted,
                  onTap: () => context.push(Routes.acctFaq),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 30),

      // "While you wait" — same R-29 external-link cards, s23's own pair
      // (persona + the financial-literacy "market works" lesson card).
      Padding(
        padding: _gut,
        child: Text('While you wait',
            style: KType.cardTitle(w: KWeight.black).copyWith(fontSize: 22, height: 26 / 22)),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.only(left: KSpace.gutter),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.only(right: KSpace.gutter),
            child: Row(
              children: [
                _GrowCard(
                  illustration: 'kd-persona',
                  background: KColor.sunTint,
                  titleColor: KColor.ink,
                  title: "What's your money persona?",
                  cta: 'Take the quiz',
                  ctaColor: KColor.indicator,
                  url: KLinks.persona,
                ),
                const SizedBox(width: 12),
                _GrowCard(
                  illustration: 'kd-lesson',
                  background: KColor.feature,
                  titleColor: KColor.featureInk,
                  title: 'How the market works, in 4 minutes',
                  cta: 'Start lesson 1',
                  ctaColor: KColor.sun,
                  url: KLinks.financialLiteracy,
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 26),

      // "Have a look around" — same rotator as s22's "Top movers today",
      // no "Markets" link (s23's own markup omits it).
      // EMPTY: no trending assets at all — section left off.
      if (movers.isNotEmpty) ...[
        Padding(
          padding: _gut,
          child: Text('Have a look around', style: KType.cardTitle().copyWith(fontSize: 18)),
        ),
        const SizedBox(height: 8),
        Padding(padding: _gut, child: _TopMoverCard(movers: movers)),
      ],
    ];
  }
}

// ── Local bits ───────────────────────────────────────────────────────────────

/// s23's KYC banner — headline/subtitle come straight off the same real
/// `TradingEligibilityGap` every other trade/fund entry point in the app
/// already gates on, so a rejected/flagged/expired/pending investor sees
/// accurate copy here too, not just s22's literal "Finish verifying to
/// start investing" example text.
class _VerifyBanner extends StatelessWidget {
  const _VerifyBanner({required this.gap});
  final TradingEligibilityGap gap;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final step = app.kycDraftStep;
    final total = app.kycDraftTotal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KColor.warmTint,
        border: Border.all(color: KColor.warm.withValues(alpha: 0.35), width: 1),
        borderRadius: KRadii.featureR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: KColor.warm, shape: BoxShape.circle),
                child: KIcon('shield', size: 20, color: KColor.featureInk),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(gap.title,
                        style:
                            KType.cardTitle(w: KWeight.black).copyWith(fontSize: 18, height: 23 / 18)),
                    const SizedBox(height: 4),
                    Text(gap.message,
                        style: KType.body(color: KColor.ink2).copyWith(fontSize: 14, height: 20 / 14)),
                  ],
                ),
              ),
            ],
          ),
          // Real step progress only — s22's own "2 of 5 steps done" example
          // is the in-progress-draft case (kycDraftStep/kycDraftTotal, set
          // once GET /kyc-submissions/draft returns). Other gap states
          // (submitted-pending, rejected, flagged, expired) carry no step
          // count, so the bar is left off for them rather than a guessed
          // fill — same treatment R-34 gives any figure with nothing
          // writing it.
          if (step != null && total != null && total > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < total; i++) ...[
                  if (i != 0) const SizedBox(width: 5),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < step ? KColor.warm : KColor.warm.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          // KButtonVariant.primary (the app's one indicator-purple CTA)
          // stands in for the canvas's literal one-off near-black fill —
          // reusing the app's real "primary" affordance rather than adding
          // a variant for a single button.
          KButton(label: 'Continue verification', onPressed: () => context.push(gap.route)),
        ],
      ),
    );
  }
}

/// A pill inside the money card's action row — wallet balance / portfolio
/// value + change.
class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.child});
  final String icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: KColor.indicatorTint, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [KIcon(icon, size: 14, color: KColor.ink), const SizedBox(width: 6), child],
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
      width: 36,
      height: 36,
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
  const _BellButton({required this.onPressed, this.showBadge = true});
  final VoidCallback onPressed;

  /// s22's IconButton carries `badge="{{ true }}"`; s23's omits it — no
  /// unread guarantee is drawn for the not-verified state.
  final bool showBadge;

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
          if (showBadge)
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

enum _ActionStyle { primary, tinted, disabled }

/// One round quick action — 56px circle + label. `locked` adds the small
/// corner lock badge s23's own "Invest" action draws while disabled.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.style,
    this.onTap,
    this.locked = false,
  });

  final String label;
  final String icon;
  final _ActionStyle style;
  final VoidCallback? onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (style) {
      _ActionStyle.primary => (KColor.indicator, KColor.featureInk),
      _ActionStyle.tinted => (KColor.indicatorTint, KColor.indicator),
      _ActionStyle.disabled => (KColor.track, KColor.ink3),
    };
    final circle = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          KIcon(icon, size: 22, color: fg),
          if (locked)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KColor.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: KColor.hairline, width: 1),
                ),
                child: KIcon('lock', size: 11, color: KColor.ink3),
              ),
            ),
        ],
      ),
    );
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        circle,
        const SizedBox(height: 8),
        Text(
          label,
          style: KType.data(color: style == _ActionStyle.disabled ? KColor.ink3 : KColor.ink,
                  w: KWeight.semibold)
              .copyWith(fontSize: 13),
        ),
      ],
    );
    if (onTap == null) return column;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: column);
  }
}

/// One "Grow with Kudimata"/"While you wait" promo card — a static, external
/// link (R-29). Never shows a completion/progress figure per that ruling.
class _GrowCard extends StatelessWidget {
  const _GrowCard({
    required this.illustration,
    required this.background,
    required this.titleColor,
    required this.title,
    required this.cta,
    required this.ctaColor,
    required this.url,
  });

  final String illustration;
  final Color background;
  final Color titleColor;
  final String title;
  final String cta;
  final Color ctaColor;
  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openExternal(url),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: background, borderRadius: KRadii.featureR),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: SvgPicture.asset('assets/illustrations/$illustration.svg', height: 84)),
            const SizedBox(height: 10),
            Text(title,
                style: KType.cardTitle(color: titleColor, w: KWeight.black)
                    .copyWith(fontSize: 17, height: 22 / 17)),
            const SizedBox(height: 10),
            // The bundled Nunito/Nunito Sans faces carry no U+2192 glyph, so
            // the canvas's literal "→" (Check your readiness →, etc.) is a
            // tofu box, not a render — this is a real, offline device
            // constraint (see pubspec.yaml's font-bundling note), not a
            // design opinion. A trailing chevron icon carries the same
            // directional cue with a glyph the app actually ships.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cta, style: KType.data(color: ctaColor, w: KWeight.bold).copyWith(fontSize: 13)),
                const SizedBox(width: 4),
                KIcon('chevronRight', size: 13, color: ctaColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// s22's full-width "Financial literacy" row (distinct shape from the
/// hscroll _GrowCard above). R-29: the canvas draws "Lesson 3 of 12 · 4
/// min" here — the lesson number is per-user progress this app has no
/// reader for (the lessons live on kudimata.app, not in this app), so only
/// the non-progress half of that string ships.
class _LiteracyRow extends StatelessWidget {
  const _LiteracyRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: KColor.sunTint, borderRadius: BorderRadius.circular(12)),
            child: SvgPicture.asset('assets/illustrations/kd-lesson.svg', height: 38),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Financial literacy', style: KType.cardTitle().copyWith(fontSize: 15)),
                Text('4 min', style: KType.micro(color: KColor.ink3).copyWith(fontSize: 13)),
              ],
            ),
          ),
          KIcon('chevronRight', size: 17, color: KColor.ink3),
        ],
      ),
    );
  }
}

/// The rotating "Top movers today" (s22) / "Have a look around" (s23) card
/// — cycles through up to 3 real trending assets, dots showing position,
/// same shape both screens draw it in. Rule 8: the rotation Timer is
/// cancelled in dispose().
class _TopMoverCard extends StatefulWidget {
  const _TopMoverCard({required this.movers});
  final List<Asset> movers;

  @override
  State<_TopMoverCard> createState() => _TopMoverCardState();
}

class _TopMoverCardState extends State<_TopMoverCard> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant _TopMoverCard old) {
    super.didUpdateWidget(old);
    if (_index >= widget.movers.length) _index = 0;
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    if (widget.movers.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        setState(() => _index = (_index + 1) % widget.movers.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _initials(Asset a) {
    final letters = a.ticker.replaceAll(RegExp(r'[^A-Za-z]'), '');
    return letters.substring(0, letters.length < 2 ? letters.length : 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final mover = widget.movers[_index];
    return KCard(
      onTap: () => context.push(Routes.assetDetail(mover.ticker)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: mover.logoColor ?? KColor.indicatorTint, shape: BoxShape.circle),
                child: Text(_initials(mover),
                    style: KType.cardTitle(color: KColor.ink, w: KWeight.black).copyWith(fontSize: 14)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(mover.name, style: KType.cardTitle().copyWith(fontSize: 16)),
                    Text(mover.ticker, style: KType.data(color: KColor.ink3).copyWith(fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(mover.price, style: KType.cardTitle().copyWith(fontSize: 16).tnum),
                  Text(mover.change,
                      style: KType.data(
                              color: mover.trend == Trend.loss ? KColor.loss : KColor.gain, w: KWeight.bold)
                          .copyWith(fontSize: 13)
                          .tnum),
                ],
              ),
            ],
          ),
          if (widget.movers.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.movers.length; i++) ...[
                  if (i != 0) const SizedBox(width: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index ? KColor.indicator : KColor.track,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
