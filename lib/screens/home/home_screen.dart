// Home tab root — two structurally DIFFERENT bodies per canvas screens 29
// (verified) and 30 (not verified yet), not one layout with a banner bolted
// on. Ported from canvas s29/s30. Root tab: builds a Scaffold body WITHOUT a
// bottom nav — the shell owns that. Numbers tabular; movement colour on numbers.
//
// 2026-08-24 rebuild: the prior verified-state body additionally rendered a
// Watchlist strip, a Trending section and an Orders/Activity link card —
// none of those exist in canvas s29 at all (s29 is: header → BalancePanel →
// 3 quick actions → DigestCard → "Your holdings" list). Confirmed via fresh
// screenshot vs. canvas markup, not assumed. Removed. The not-verified body
// was previously the SAME layout with a `_KycPrompt` banner inserted — s30
// is a genuinely different screen (onboarding checklist panel + "Biggest
// mover today" single-asset row, no BalancePanel/quick-actions/digest/
// holdings at all) and is now built as its own distinct body.
//
// Wired to the backend per lib/data/api/README.md's FutureBuilder convention.
// Repositories back this screen's reads, combined into one `Future.wait`-style
// load (kicked off concurrently) fed through a single screen-level
// FutureBuilder — one spinner/retry for the whole tab rather than several:
//   UserRepository.me()             GET /users/me                — greeting name
//   HoldingsRepository.summary()    GET /portfolio-summary        — BalancePanel
//     (totalValue/change/chartSeries; replaces the old hardcoded literals —
//     STUB-home-1 in .pipeline/fragments/home.json — with the SAME aggregate
//     the portfolio screen uses, per that stub's own reconciliation note)
//   HoldingsRepository.holdings()   GET /holdings                 — holdings list
//     (Holding itself has no display fields; .asset is the joined Asset&Quote
//     HoldingsRepository already resolves — see that file's header.)
//   AssetRepository.trending()      GET /assets/trending          — not-verified
//     state's "Biggest mover today" row (the single highest-|change| asset)
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

/// "Good morning" / "Good afternoon" / "Good evening" per spec screen 29 —
/// was a bare "Hi, {name}" before this exactness pass. Boundaries: before
/// noon, before 17:00, else evening — device-local time (no timezone/NGX
/// business-hours concept needed for a greeting).
String _timeGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// Picks the holding/asset with the largest |% change| — shared by the
/// verified body's digest sentence and the not-verified body's "Biggest
/// mover today" row. The actual number always traces to real data.
Asset _biggestMover(List<Asset> assets) {
  double pct(Asset a) => double.tryParse(a.change.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  return assets.reduce((a, b) => pct(a) >= pct(b) ? a : b);
}

/// A generated portfolio narrative — one plain sentence about the holding
/// that moved most this week. No real AI backend exists yet for this (see
/// docs/redesign/BACKEND_GAPS.md); the number is real, the template isn't.
String _weeklyDigest(List<Asset> holdings) {
  final top = _biggestMover(holdings);
  final verb = top.trend == Trend.gain ? 'carried' : 'weighed on';
  return '${top.name} $verb your portfolio this week, ${top.change} since your last check-in. '
      'Nothing here needs a decision from you today.';
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

  /// 2026-08-24, direct product instruction — reported live: "I just added
  /// a stock to watchlist and went back home screen and I did not see it".
  /// Not in canvas s29 (that screen was verified, and rebuilt earlier this
  /// same session, to have no watchlist section at all) — a direct
  /// override of that literal reading, same class of call as the earlier
  /// Trending-fallback addition below. Rides the same 8s silent-poll cycle
  /// as everything else on this screen (see _portfolioPollTimer), so a
  /// watchlist add made elsewhere in the app shows up here without a
  /// manual navigation round-trip.
  final List<Asset> watchlist;

  /// Preformatted "₦10,000.00" (WalletRepository.balance()) — 2026-08-20
  /// directive: "can we see amount in funded wallet too on the home
  /// screen somewhere please... or in the portfolio card". Added onto the
  /// SAME concurrent load/poll cycle the rest of this screen already
  /// runs, rather than a separate fetch. Verified-state only.
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
  /// reload (manual retry) so THAT still shows the loading state, same as
  /// before — only the silent background poll skips it.
  _HomeData? _data;

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
  // pull-to-refresh or an unrelated rebuild — so a fresh trade made from
  // Markets/asset-detail didn't show up here until the investor did
  // something else first. Silently re-fetches in the background (no
  // spinner, no error state of its own — a flaky tick just leaves the
  // last-good numbers showing, same treatment wallet_screens.dart's own
  // silent refresh uses) rather than reassigning `_future` naively, which
  // would otherwise flash the whole screen back to KLoadingView on every
  // tick.
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
    // Run all requests concurrently via the record `.wait` extension — NOT
    // firing them all then awaiting sequentially (`await a; await b; ...`)
    // like this used to: if an EARLIER-awaited future rejects, that pattern
    // throws immediately and abandons the still-in-flight later futures,
    // which then reject with nothing listening — an "unhandled exception"
    // (harmless-looking in a real run, but real: extra console noise/crash-
    // reporting spam, and it's exactly what made
    // test/theme_toggle_test.dart's Home render intermittently fail once
    // that test started giving AppState a real (network-dead) apiClient).
    // `.wait` attaches a listener to every future up front, so none of them
    // can ever go unhandled, regardless of which one fails first.
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
            // Prefer the freshest silently-polled data over the
            // FutureBuilder's own (possibly stale) snapshot — see `_data`'s
            // doc comment.
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

/// The loaded-state widget tree — routes to the structurally distinct
/// verified/not-verified bodies per canvas s29/s30 (see file header).
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
        // greeting row — shared shape, canvas s29 vs s30: "Good {time}" vs
        // "Browse only", and s30 drops the bell entirely (no notifications
        // affordance while browse-only). Both carry the search button.
        Padding(
          padding: _gut,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.push(Routes.acctPersonal),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    data.user.avatarKey != null
                        ? KAvatar(avatarKey: data.user.avatarKey!, size: 38)
                        : _Avatar(initial: first.isNotEmpty ? first[0] : 'K'),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text((notVerified ? 'Browse only' : _timeGreeting()).upper,
                            style: KType.micro(color: KColor.ink3)),
                        Text(first, style: KType.section()),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              KIconButton(
                icon: 'search',
                semanticLabel: 'search',
                onPressed: () => context.push(Routes.search),
              ),
              if (!notVerified) ...[
                const SizedBox(width: 8),
                _BellButton(
                  onPressed: () => context.push(Routes.notifications),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (notVerified) ..._NotVerifiedContent(data: data).build(context) else ..._VerifiedContent(data: data).build(context),
      ],
    );
  }
}

/// Canvas s29 — "Home · verified": BalancePanel → 3 quick actions →
/// DigestCard → "Your holdings" list. No Watchlist/Trending/Orders sections.
class _VerifiedContent {
  const _VerifiedContent({required this.data});
  final _HomeData data;

  List<Widget> build(BuildContext context) => [
        // feature panel — the one ink surface
        Padding(
          padding: _gut,
          child: KBalancePanel(
            label: 'Portfolio value',
            balance: data.summary.totalValue,
            change: data.summary.change,
            changeTone: _kTrend(data.summary.changeTrend),
            // 2026-08-24: canvas s29's own BalancePanel import has no
            // `chart` prop at all — confirmed against the real
            // BalancePanel.jsx source (chart is optional, `chart ? ... :
            // null`), not just the shorthand markup. Direct product
            // feedback: "that stock line is not meant to be there again".
            // Portfolio's own BalancePanel (screen 38) has no chart prop
            // either — see portfolio_screen.dart's matching fix.
            // 2026-08-20 directive: "can we see amount in funded wallet
            // too on the home screen somewhere please... or in the
            // portfolio card" — a compact row inside the SAME ink panel,
            // rather than a whole second surface. Polled alongside
            // everything else this screen already fetches.
            action: _WalletBalanceRow(balance: data.walletBalance),
          ),
        ),
        const SizedBox(height: 16),

        // quick actions — exact spec 29 labels/icons: "Add money" / "Buy
        // shares" / "Orders" (plus/markets/clock).
        Padding(
          padding: _gut,
          child: Row(
            children: [
              Expanded(
                child: _QuickAction(
                  label: 'Add money',
                  icon: 'plus',
                  onTap: () => showAddMoneyFlow(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  label: 'Buy shares',
                  icon: 'markets',
                  onTap: () => context.go(Routes.markets),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  label: 'Orders',
                  icon: 'clock',
                  onTap: () => context.push(Routes.orderStatus),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // "Your week on the NGX" — a generated portfolio narrative (canvas
        // s29's DigestCard). Only real holdings drive the number.
        if (data.holdings.isNotEmpty) ...[
          Padding(
            padding: _gut,
            child: KDigestCard(
              title: 'Your week in the market',
              body: _weeklyDigest(data.holdings),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // "Your holdings" — no "See all" affordance in canvas s29.
        Padding(padding: _gut, child: const KEyebrow('Your holdings')),
        const SizedBox(height: 8),
        if (data.holdings.isEmpty)
          Padding(
            padding: _gut,
            // 2026-08-24, direct product instruction ("add an illustration
            // on home") — 'empty-portfolio' is the same illustration the
            // Portfolio tab's own real empty state already uses
            // (state_views.dart's KEmptyView.holdings) for this exact
            // concept, reused honestly here rather than picking a mismatched
            // one. Only shown for a first-time investor with zero holdings —
            // a populated dashboard stays illustration-free, matching this
            // app's established pattern of illustrations belonging to
            // empty/state moments, not data-dense screens.
            child: Column(
              children: [
                const KIllustration('empty-portfolio', role: KIlloRole.small),
                const SizedBox(height: 12),
                _HoldingsEmptyCard(onTap: () => context.go(Routes.markets)),
              ],
            ),
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

        // Watchlist — see _HomeData.watchlist's doc comment for why this
        // exists despite not being in canvas s29. Same compact list shape
        // as "Your holdings" above; only shown when non-empty.
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

        // 2026-08-24: a verified investor with zero holdings previously saw
        // a near-dead screen below the quick actions (no DigestCard —
        // that's gated on real holdings — just one bare empty-state card).
        // Direct feedback: "home not showing any market cards". Not a
        // canvas element (s29 assumes an investor who already holds
        // MTNN/GTCO) — but real trending data was ALREADY fetched for the
        // not-verified body's "Biggest mover" row, so reusing it here is
        // honest, not fabricated: real quotes, just surfaced in a state
        // canvas doesn't cover.
        if (data.holdings.isEmpty && data.trending.isNotEmpty) ...[
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

/// Canvas s30 — "Home · not verified yet": a "Get set up · 1 of 3 done"
/// checklist panel (real onboarding phases, not the literal 8 KYC
/// sub-steps) + a single "Biggest mover today" asset row. No BalancePanel/
/// quick-actions/digest/holdings — this is a genuinely different screen
/// from the verified body, not that body with a banner inserted.
class _NotVerifiedContent {
  const _NotVerifiedContent({required this.data});
  final _HomeData data;

  List<Widget> build(BuildContext context) {
    final app = AppScope.of(context);
    final gap = tradingEligibilityGap(app);
    final mover = data.trending.isNotEmpty ? _biggestMover(data.trending) : null;

    return [
      // "Get set up" checklist panel — the one indicator-tint feature
      // surface on this screen (same treatment as the DCS explainer).
      Padding(
        padding: _gut,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: KColor.indicatorTint, borderRadius: KRadii.featureR),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Get set up · 1 of 3 done'.upper, style: KType.micro(color: KColor.ink3)),
                  ),
                  const SizedBox(width: 10),
                  const KStatusPill(status: KStatus.pending, label: 'In progress', small: true),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Three things and you can buy your first share',
                style: KType.section(color: KColor.indicatorPress),
              ),
              const SizedBox(height: 14),
              Column(
                children: [
                  const _ChecklistStep.done(title: 'Account created', subtitle: 'Email verified'),
                  const SizedBox(height: 8),
                  _ChecklistStep.active(
                    number: 2,
                    title: gap?.title ?? 'Verify your identity',
                    subtitle: gap?.message ?? 'Continue your verification',
                    onTap: gap == null ? null : () => context.push(gap.route),
                  ),
                  const SizedBox(height: 8),
                  const _ChecklistStep.inactive(
                    number: 3,
                    title: 'Fund your wallet',
                    subtitle: '₦5,000 minimum to buy a share',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              KButton(
                label: 'Continue where you left off',
                onPressed: gap == null ? null : () => context.push(gap.route),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),

      if (mover != null) ...[
        Padding(padding: _gut, child: const KEyebrow('Biggest mover today')),
        const SizedBox(height: 8),
        Padding(
          padding: _gut,
          child: KCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: KAssetRow(
              name: mover.name,
              ticker: mover.ticker,
              price: mover.price,
              change: mover.change,
              trend: _kTrend(mover.trend),
              logoColor: mover.logoColor ?? KColor.ink,
              onTap: () => context.push(Routes.assetDetail(mover.ticker)),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],

      Padding(
        padding: _gut,
        child: Text(
          'You can follow prices and read explanations while you verify — orders open once your account is confirmed.',
          style: KType.data(color: KColor.ink3),
        ),
      ),
    ];
  }
}

// ── Local bits ───────────────────────────────────────────────────────────────

/// "Wallet balance · ₦X" row inside the portfolio panel's own `action` slot
/// — see the balance panel's own comment above for why (2026-08-20
/// directive, additive to canvas, not a canvas element itself). 2026-08-24
/// redesign: was a bare label/value text row; direct feedback wanted "a
/// better design". Given an icon bubble (matching the small `_Bubble`
/// treatment already used elsewhere on this screen, tinted for the dark
/// feature surface instead of the light page background) so it reads as
/// its own small stat, not just a second line of text.
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
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KColor.featureInk2.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: KIcon('wallet', size: 16, color: KColor.featureInk),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Wallet balance'.upper, style: KType.micro(color: KColor.featureInk2)),
          ),
          Text(balance, style: KType.cardTitle(color: KColor.featureInk, w: KWeight.bold).tnum),
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

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.label, required this.icon, required this.onTap});
  final String label;
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Ported 1:1 from the canvas mockup's #s29 block: icon 20px, label in
    // the --text-data role (not tracked/uppercase micro), padding 14px 10px.
    return KCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KIcon(icon, size: 20, color: KColor.ink),
            const SizedBox(height: 8),
            Text(label, maxLines: 1, style: KType.data(color: KColor.ink)),
          ],
        ),
      ),
    );
  }
}

/// Inline prompt shown in place of the holdings list when the investor
/// holds nothing yet. Mirrors the same KCard row treatment used elsewhere.
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

/// One row of the not-verified body's "Get set up" checklist — canvas
/// s30's three variants: done (green check bubble), active (numbered,
/// indicator-outlined, tappable), inactive (numbered, muted, untappable).
class _ChecklistStep extends StatelessWidget {
  const _ChecklistStep.done({required this.title, required this.subtitle})
      : _variant = _StepVariant.done,
        number = 0,
        onTap = null;

  const _ChecklistStep.active({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.onTap,
  }) : _variant = _StepVariant.active;

  const _ChecklistStep.inactive({required this.number, required this.title, required this.subtitle})
      : _variant = _StepVariant.inactive,
        onTap = null;

  final _StepVariant _variant;
  final int number;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget bubble;
    final BoxBorder? border;
    switch (_variant) {
      case _StepVariant.done:
        bubble = Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: KColor.gain, shape: BoxShape.circle),
          child: KIcon('check', size: 15, color: KColor.featureInk),
        );
        border = null;
      case _StepVariant.active:
        bubble = Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: KColor.indicator, shape: BoxShape.circle),
          child: Text('$number', style: KType.micro(color: KColor.featureInk)),
        );
        border = Border.all(color: KColor.indicator, width: 1.5);
      case _StepVariant.inactive:
        bubble = Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: KColor.track, shape: BoxShape.circle),
          child: Text('$number', style: KType.micro(color: KColor.ink2)),
        );
        border = null;
    }

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: KColor.paper,
        borderRadius: KRadii.cardR,
        border: border,
      ),
      child: Row(
        children: [
          bubble,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: KType.data(color: KColor.ink)),
                Text(subtitle.upper, style: KType.micro(color: KColor.ink3)),
              ],
            ),
          ),
          if (_variant != _StepVariant.done)
            KIcon('chevronRight', size: 16,
                color: _variant == _StepVariant.active ? KColor.indicator : KColor.ink3),
        ],
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: content);
  }
}

enum _StepVariant { done, active, inactive }
