// Corporate actions hub — artboard `s55`
// (docs/design/redesign-2026-08/06 Account and Support.dc.html#s55).
//
// R-5 correction (2026-08-27, docs/redesign/DECISIONS.md): this file used
// to be built against a stale "screen 81"/"s81.html" reference from an
// earlier, now-superseded pass — that id doesn't exist in the current
// canvas. Rebuilt from scratch against the real `s55` artboard, which the
// task brief names directly (never taken from a code comment, per R-5).
//
// Wired per lib/data/api/README.md's FutureBuilder convention:
// CorporateActionsRepository.rightsIssues() (GET /rights-issues) +
// .agmMeetings() (GET /agm-meetings) — every item at a ticker the caller
// currently holds, ANY status, so an already-elected/voted/closed item
// stays visible as history rather than disappearing. Additionally joined
// against DividendRepository.history() (GET /dividends), AssetRepository
// .byTicker() (GET /assets/:ticker) and HoldingsRepository.byTicker()
// (GET /holdings/:ticker) — see _load()'s own comment for why.
//
// s55 draws exactly ONE spotlighted decision (a rights issue) and TWO
// "Recent" rows (one dividend, one AGM) — one moment. The real hub can have
// more than one thing pending at once (a rights issue AND an AGM open
// together is entirely possible — they're independent corporate actions),
// so this screen extends the artboard's single-card treatment to however
// many are actually pending: the most urgent gets the full spotlight
// treatment s55 draws, and any others still get a compact, tappable,
// visibly-"needs you" row rather than silently losing their only way in.
// See this file's report for the same reasoning applied to "Recent".
//
// Entry point (unchanged): lib/screens/account/account_screen.dart's
// "Corporate actions" row (Routes.corpActions) — that row also computes its
// own "N waiting" count from this same repository/same pending definition,
// so the two must stay in step; this screen doesn't touch that file (it's
// outside this cluster's directory).
//
// NOTE on navigation: app_router.dart's GoRoute builders for
// Routes.corpActionsRightsIssue / Routes.corpActionsAgm construct
// RightsIssueScreen()/AgmVoteScreen() with no `extra` forwarded (router
// files are a different agent's directory this pass), so pushing here with
// an `extra` would silently be dropped. Both detail screens instead fetch
// their own most-relevant item directly from the repository — this hub
// just pushes the bare route, same as before.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/repositories/asset_repository.dart';
import 'package:kudimata_invest/data/repositories/corporate_actions_repository.dart';
import 'package:kudimata_invest/data/repositories/dividend_repository.dart';
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'corporate_actions_widgets.dart';

/// The single item that gets s55's full rich-card treatment — the most
/// urgent open, undecided item across both rights issues and AGMs. Carries
/// the extra display-only fields (company name, current price, units held)
/// that RightsIssueListItem/AgmMeetingListItem don't themselves carry, so
/// this hub joins them in from AssetRepository/HoldingsRepository rather
/// than showing a bare ticker where s55 draws "Zenith Bank".
sealed class _Spotlight {}

class _RightsSpotlight implements _Spotlight {
  const _RightsSpotlight({
    required this.item,
    required this.companyName,
    required this.currentPrice,
    required this.unitsHeld,
  });
  final RightsIssueListItem item;
  final String companyName;
  final String currentPrice;
  final String unitsHeld;
}

class _AgmSpotlight implements _Spotlight {
  const _AgmSpotlight({required this.item, required this.companyName});
  final AgmMeetingListItem item;
  final String companyName;
}

typedef _HubData = ({
  List<RightsIssueListItem> rightsIssues,
  List<AgmMeetingListItem> agmMeetings,
  List<Dividend> dividends,
  _Spotlight? spotlight,
});

class CorporateActionsScreen extends StatefulWidget {
  const CorporateActionsScreen({super.key});

  @override
  State<CorporateActionsScreen> createState() => _CorporateActionsScreenState();
}

class _CorporateActionsScreenState extends State<CorporateActionsScreen> {
  late final _repo = CorporateActionsRepository(AppScope.read(context).apiClient);
  late final _dividendRepo = DividendRepository(AppScope.read(context).apiClient);
  late final _assetRepo = AssetRepository(AppScope.read(context).apiClient);
  late final _holdingsRepo = HoldingsRepository(AppScope.read(context).apiClient);
  late Future<_HubData> _future = _load();

  bool _isPendingRights(RightsIssueListItem r) =>
      r.status == CorpActionStatus.open && !r.alreadyElected;

  bool _isPendingAgm(AgmMeetingListItem m, DateTime now) =>
      m.status == CorpActionStatus.open && !m.alreadyVoted && m.votesCloseAt.isAfter(now);

  // Combined load, same one-FutureBuilder-per-screen convention every other
  // screen in this app uses. The extra Asset/Holding joins only ever fire
  // for the ONE item that ends up spotlighted (never per-row across a
  // whole list), so this stays a bounded number of calls regardless of how
  // much history an investor has.
  Future<_HubData> _load() async {
    final (rightsIssues, agmMeetings, dividendsPage) = await (
      _repo.rightsIssues(),
      _repo.agmMeetings(),
      _dividendRepo.history(),
    ).wait;

    final now = DateTime.now();
    RightsIssueListItem? topRights;
    for (final r in rightsIssues) {
      if (!_isPendingRights(r)) continue;
      if (topRights == null || r.closeDate.isBefore(topRights.closeDate)) topRights = r;
    }
    AgmMeetingListItem? topAgm;
    for (final m in agmMeetings) {
      if (!_isPendingAgm(m, now)) continue;
      if (topAgm == null || m.votesCloseAt.isBefore(topAgm.votesCloseAt)) topAgm = m;
    }

    _Spotlight? spotlight;
    final rightsIsMoreUrgent =
        topRights != null && (topAgm == null || !topAgm.votesCloseAt.isBefore(topRights.closeDate));
    if (rightsIsMoreUrgent) {
      final (asset, holding) = await (
        _assetRepo.byTicker(topRights.ticker),
        _holdingsRepo.byTicker(topRights.ticker),
      ).wait;
      spotlight = _RightsSpotlight(
        item: topRights,
        companyName: asset.name,
        currentPrice: asset.price,
        unitsHeld: holding.units,
      );
    } else if (topAgm != null) {
      final asset = await _assetRepo.byTicker(topAgm.ticker);
      spotlight = _AgmSpotlight(item: topAgm, companyName: asset.name);
    }

    return (
      rightsIssues: rightsIssues,
      agmMeetings: agmMeetings,
      dividends: dividendsPage.data,
      spotlight: spotlight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return KCorpActionScaffold(
      title: 'Corporate actions',
      child: FutureBuilder<_HubData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: KLoadingView(),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: KErrorView(onPrimary: () => setState(() => _future = _load())),
            );
          }
          final data = snapshot.data!;
          if (data.rightsIssues.isEmpty && data.agmMeetings.isEmpty && data.dividends.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: KEmptyView(
                icon: 'portfolio',
                title: 'Nothing here yet',
                message: 'Rights issues, AGM votes and dividends on companies you hold will show up here.',
              ),
            );
          }
          return _HubBody(data: data);
        },
      ),
    );
  }
}

class _HubBody extends StatelessWidget {
  const _HubBody({required this.data});
  final _HubData data;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final pendingRights = <RightsIssueListItem>[];
    final settledRights = <RightsIssueListItem>[];
    for (final r in data.rightsIssues) {
      (r.status == CorpActionStatus.open && !r.alreadyElected ? pendingRights : settledRights).add(r);
    }
    final pendingAgm = <AgmMeetingListItem>[];
    final settledAgm = <AgmMeetingListItem>[];
    for (final m in data.agmMeetings) {
      (m.status == CorpActionStatus.open && !m.alreadyVoted && m.votesCloseAt.isAfter(now)
              ? pendingAgm
              : settledAgm)
          .add(m);
    }

    final spotlight = data.spotlight;
    final pendingCount = pendingRights.length + pendingAgm.length;

    // "Also waiting" — every pending item OTHER than the one spotlighted.
    // s55 only ever draws one; this is the "code path serves more than the
    // artboard depicts" case (see this file's header comment).
    final alsoWaiting = <(DateTime, Widget)>[];
    for (final r in pendingRights) {
      if (spotlight is _RightsSpotlight && spotlight.item.id == r.id) continue;
      alsoWaiting.add((r.closeDate, _waitingRow(context, rights: r)));
    }
    for (final m in pendingAgm) {
      if (spotlight is _AgmSpotlight && spotlight.item.id == m.id) continue;
      alsoWaiting.add((m.votesCloseAt, _waitingRow(context, agm: m)));
    }
    alsoWaiting.sort((a, b) => a.$1.compareTo(b.$1));

    // "Recent" — settled rights issues + voted/closed AGMs + dividend
    // payouts, merged and sorted newest first. s55's own example mixes a
    // dividend row and an AGM row in one list, so real activity is merged
    // here rather than split into three separate lists. Capped at 8 so the
    // hub stays a hub rather than growing into an unbounded ledger —
    // exhaustive history for each kind already has its own screen one tap
    // away (Dividends / a settled item's own detail screen).
    final recent = <(DateTime, Widget)>[];
    for (final r in settledRights) {
      final election = r.election;
      final body = election == null
          ? 'This offer closed.'
          : election.decision == RightsIssueDecision.takeUp
              ? 'You took up ${election.unitsSubscribed} shares.'
              : 'You let this one lapse.';
      recent.add((
        election?.decidedAt ?? r.closeDate,
        KCorpActivityRow(
          badge: KCorpAvatarBadge(
            icon: 'transfer',
            background: KColor.statusApprovedTint,
            foreground: KColor.indicator,
          ),
          title: '${r.ticker} rights issue',
          subtitle: '$body · ${_shortDate(election?.decidedAt ?? r.closeDate)}',
          onTap: () => context.push(Routes.corpActionsRightsIssue),
        ),
      ));
    }
    for (final m in settledAgm) {
      final vote = m.vote;
      recent.add((
        vote?.submittedAt ?? m.votesCloseAt,
        KCorpActivityRow(
          // 'users' has no glyph in lib/widgets/k_icon.dart's frozen
          // registry — same missing-icon substitution
          // lib/screens/account/account_screen.dart already makes for this
          // exact artboard glyph name, not a new request.
          badge: KCorpAvatarBadge(
            icon: 'profile',
            background: KColor.indicatorTint,
            foreground: KColor.indicator,
          ),
          title: '${m.ticker} annual meeting',
          subtitle: vote != null
              ? 'You voted by proxy · ${_shortDate(vote.submittedAt)}'
              : 'Voting closed · ${_shortDate(m.votesCloseAt)}',
          onTap: () => context.push(Routes.corpActionsAgm),
        ),
      ));
    }
    for (final d in data.dividends) {
      recent.add((
        d.payDate,
        KCorpActivityRow(
          badge: KCorpAvatarBadge(
            icon: 'card',
            background: KColor.statusApprovedTint,
            foreground: KColor.indicator,
          ),
          title: '${d.ticker} dividend',
          // Credited to the in-app wallet balance (DividendsService.declare
          // -> WalletBalanceService.adjustBalance) — there is no bank-
          // transfer/Direct Cash Settlement step in this codebase, so this
          // does not claim the money left the wallet for a bank account.
          subtitle: '+${_formatNaira(d.netKobo)} to your wallet · ${_shortDate(d.payDate)}',
          onTap: () => context.push(Routes.corpActionsDividends),
        ),
      ));
    }
    recent.sort((a, b) => b.$1.compareTo(a.$1));
    final recentCapped = recent.take(8).map((e) => e.$2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _headline(pendingCount),
          style: KType.title(color: KColor.ink).copyWith(fontWeight: KWeight.black),
        ),
        const SizedBox(height: 8),
        Text(
          'Companies you own sometimes ask you to choose something.',
          style: KType.body(color: KColor.ink2),
        ),
        const SizedBox(height: 20),
        if (spotlight != null) ...[
          switch (spotlight) {
            _RightsSpotlight s => _RightsSpotlightCard(spotlight: s),
            _AgmSpotlight s => _AgmSpotlightCard(spotlight: s),
          },
          const SizedBox(height: 12),
        ],
        for (final (_, row) in alsoWaiting) ...[row, const SizedBox(height: 9)],
        if (recentCapped.isNotEmpty) ...[
          SizedBox(height: spotlight != null || alsoWaiting.isNotEmpty ? 4 : 0),
          Text('Recent', style: KType.cardTitle().copyWith(fontSize: 17)),
          const SizedBox(height: 10),
          for (final row in recentCapped) ...[row, const SizedBox(height: 9)],
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => context.push(Routes.corpActionsDividends),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
            ),
            child: Text(
              // No registrar integration exists (dividend.types.ts:
              // "no real share-registrar integration is contracted yet"),
              // so this does not promise Kudimata will chase/recover the
              // money — only that a mandate can be signed from Dividends.
              'Dividends from before you joined Kudimata? Sign an e-dividend '
              'mandate from Dividends.',
              style: KType.data(color: KColor.ink3).copyWith(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _waitingRow(BuildContext context, {RightsIssueListItem? rights, AgmMeetingListItem? agm}) {
    if (rights != null) {
      return KCorpActivityRow(
        badge: KCorpAvatarBadge(
          initials: _initials(rights.ticker),
          background: KColor.gain,
          foreground: KColor.featureInk,
        ),
        title: '${rights.ticker} rights issue',
        subtitle: 'Closes ${_shortDate(rights.closeDate)}',
        trailing: const KStatusPill(status: KStatus.review, label: 'Needs you', small: true),
        onTap: () => context.push(Routes.corpActionsRightsIssue),
      );
    }
    return KCorpActivityRow(
      badge: KCorpAvatarBadge(
        initials: _initials(agm!.ticker),
        background: KColor.indicator,
        foreground: KColor.featureInk,
      ),
      title: '${agm.ticker} annual meeting',
      subtitle: 'Votes close ${_shortDate(agm.votesCloseAt)}',
      trailing: const KStatusPill(status: KStatus.review, label: 'Needs you', small: true),
      onTap: () => context.push(Routes.corpActionsAgm),
    );
  }

  String _headline(int pendingCount) {
    if (pendingCount == 0) return 'Nothing waiting right now';
    if (pendingCount == 1) return 'One decision waiting';
    return '$pendingCount decisions waiting';
  }
}

/// The rich spotlight card s55 itself draws — avatar, hold count, deadline
/// pill, description, cost/closes facts, Take it up / Skip it.
///
/// Both buttons push into RightsIssueScreen rather than acting immediately
/// from this list card. That's a deliberate divergence from s55's own
/// literal one-tap buttons: "Take it up" needs a quantity (R-12, partial
/// take-up — there's nowhere on this compact card to enter one), and
/// "Skip it" permanently forfeits the entitlement's value, which deserves
/// the same reviewable screen a take-up gets rather than a single tap with
/// no way to reconsider.
class _RightsSpotlightCard extends StatelessWidget {
  const _RightsSpotlightCard({required this.spotlight});
  final _RightsSpotlight spotlight;

  @override
  Widget build(BuildContext context) {
    final r = spotlight.item;
    final costLabel = _formatNaira(r.entitlementUnits * r.subscriptionPriceKobo);
    return _SpotlightShell(
      avatarInitials: _initials(r.ticker),
      avatarColor: KColor.gain,
      title: '${spotlight.companyName} rights issue',
      subtitle: 'You hold ${spotlight.unitsHeld} shares',
      deadlineLabel: _daysLeftLabel(r.closeDate),
      body: r.entitlementUnits > 0
          ? 'You can buy ${r.entitlementUnits} new shares at ${_formatNaira(r.subscriptionPriceKobo)} '
              "each — today's price is ${spotlight.currentPrice}. If you do nothing, your stake in "
              '${r.ticker} gets smaller.'
          : 'Closes ${_shortDate(r.closeDate)}.',
      facts: [('Cost if you take it all', costLabel), ('Closes', _shortDate(r.closeDate))],
      actions: [
        Expanded(
          child: KButton(
            label: 'Take it up',
            size: KButtonSize.md,
            onPressed: () => context.push(Routes.corpActionsRightsIssue),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: KButton(
            label: 'Skip it',
            variant: KButtonVariant.secondary,
            size: KButtonSize.md,
            onPressed: () => context.push(Routes.corpActionsRightsIssue),
          ),
        ),
      ],
    );
  }
}

/// AGM equivalent of the same spotlight treatment — s55 doesn't draw this
/// variant (it only draws a rights issue in the spotlight slot), but an
/// open AGM vote is exactly as much "a decision waiting" as a rights issue
/// is, so it gets the same visual weight when it's the most urgent pending
/// item, adapted where a rights issue's own copy/actions don't fit an AGM
/// (a quantity-free "Vote now" instead of Take it up/Skip it; no
/// cost/closes facts since a vote has neither).
class _AgmSpotlightCard extends StatelessWidget {
  const _AgmSpotlightCard({required this.spotlight});
  final _AgmSpotlight spotlight;

  @override
  Widget build(BuildContext context) {
    final m = spotlight.item;
    final n = m.resolutions.length;
    return _SpotlightShell(
      avatarInitials: _initials(m.ticker),
      avatarColor: KColor.indicator,
      title: '${spotlight.companyName} annual meeting',
      subtitle: 'You hold ${m.eligibleUnits} shares',
      deadlineLabel: _daysLeftLabel(m.votesCloseAt),
      body: m.eligibleUnits > 0
          ? 'You have ${m.eligibleUnits} votes on $n resolution${n == 1 ? '' : 's'}. Votes close '
              '${_shortDate(m.votesCloseAt)}.'
          : 'Votes close ${_shortDate(m.votesCloseAt)}.',
      facts: const [],
      actions: [
        Expanded(
          child: KButton(
            label: 'Vote now',
            size: KButtonSize.md,
            onPressed: () => context.push(Routes.corpActionsAgm),
          ),
        ),
      ],
    );
  }
}

/// Shared chrome for both spotlight variants above — avatar row, deadline
/// pill, description, optional fact rows, action row. s55's own layout,
/// literally: `06 Account and Support.dc.html#s55`.
class _SpotlightShell extends StatelessWidget {
  const _SpotlightShell({
    required this.avatarInitials,
    required this.avatarColor,
    required this.title,
    required this.subtitle,
    required this.deadlineLabel,
    required this.body,
    required this.facts,
    required this.actions,
  });

  final String avatarInitials;
  final Color avatarColor;
  final String title;
  final String subtitle;
  final String deadlineLabel;
  final String body;
  final List<(String, String)> facts;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border.all(color: KColor.hairline, width: 1),
        borderRadius: BorderRadius.circular(KRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              KCorpAvatarBadge(
                initials: avatarInitials,
                background: avatarColor,
                foreground: KColor.featureInk,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: KType.cardTitle().copyWith(fontSize: 16)),
                    Text(subtitle, style: KType.data(color: KColor.ink3).copyWith(fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: KColor.warmTint, borderRadius: KRadii.pillR),
                child: Text(
                  deadlineLabel,
                  style: KType.data(color: KColor.warmPress)
                      .copyWith(fontSize: 12, fontWeight: KWeight.bold, letterSpacing: 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(body, style: KType.data(color: KColor.ink2).copyWith(fontSize: 14, height: 21 / 14)),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Column(
              children: [
                for (final (label, value) in facts) ...[
                  Row(
                    children: [
                      Expanded(child: Text(label, style: KType.data(color: KColor.ink2))),
                      Text(value, style: KType.cardTitle().copyWith(fontSize: 14).tnum),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(children: actions),
        ],
      ),
    );
  }
}

String _initials(String ticker) {
  final letters = ticker.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (letters.isEmpty) return '?';
  return letters.substring(0, letters.length < 2 ? letters.length : 2).toUpperCase();
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "2026-03-27T14:30:00.000Z" -> "27 Mar" (deadline eyebrow shape).
String _shortDate(DateTime dt) {
  final local = dt.toLocal();
  return '${local.day} ${_months[local.month - 1]}';
}

/// Real deadline -> "4 days left" / "1 day left" / "Closes today" — s55's
/// own pill copy, generalised from its one drawn example.
String _daysLeftLabel(DateTime deadline) {
  final diff = deadline.difference(DateTime.now());
  if (diff.isNegative) return 'Closed';
  final days = (diff.inHours / 24).ceil();
  if (days <= 0) return 'Closes today';
  return days == 1 ? '1 day left' : '$days days left';
}

/// Minor-unit kobo -> "₦42.00" (thousands-grouped, 2dp).
String _formatNaira(int kobo) {
  final abs = kobo.abs();
  final whole = abs ~/ 100;
  final minor = (abs % 100).toString().padLeft(2, '0');
  final wholeStr = whole.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  return '₦$wholeStr.$minor';
}
