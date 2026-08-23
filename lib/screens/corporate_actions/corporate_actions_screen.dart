// Corporate actions hub (screen 81, 2026-08-23 "Soft Landing"). Wired per
// lib/data/api/README.md's FutureBuilder convention:
// CorporateActionsRepository.rightsIssues() (GET /rights-issues) +
// .agmMeetings() (GET /agm-meetings) replace corporate_actions_data.dart's
// static `kMockRightsIssue`/`kMockAgm` fixtures. Both endpoints return
// every item at a ticker the caller currently holds, ANY status (open or
// closed) — an item the caller already elected/voted on, or whose deadline
// has passed, stays visible as "Done for you" history instead of just
// disappearing, replacing the old static "Zenith bonus shares" placeholder
// card with real settled items.
//
// Entry point (still true — unchanged by this pass): from
// lib/screens/portfolio/portfolio_screen.dart (screen 38) or
// lib/screens/portfolio/holding_detail_screen.dart (screen 39), or a
// notification, per s81.html's own footer note. Suggested spot: a row/
// button near the top of PortfolioScreen's holdings list — out of scope
// here (portfolio_screen.dart isn't part of this cluster).
//
// NOTE on navigation: app_router.dart's GoRoute builders for
// Routes.corpActionsRightsIssue / Routes.corpActionsAgm construct
// RightsIssueScreen()/AgmVoteScreen() with NO `extra` forwarded (confirmed
// in that file — router files are out of scope for this pass per this
// cluster's brief), so pushing here with an `extra` would silently be
// dropped. Both detail screens instead fetch their own most-relevant item
// directly from the repository (see their own header comments) — this hub
// just pushes the bare route.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/repositories/corporate_actions_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'corporate_actions_widgets.dart';

typedef _HubData = ({List<RightsIssueListItem> rightsIssues, List<AgmMeetingListItem> agmMeetings});

class CorporateActionsScreen extends StatefulWidget {
  const CorporateActionsScreen({super.key});

  @override
  State<CorporateActionsScreen> createState() => _CorporateActionsScreenState();
}

class _CorporateActionsScreenState extends State<CorporateActionsScreen> {
  late final _repo = CorporateActionsRepository(AppScope.read(context).apiClient);
  late Future<_HubData> _future = _load();

  Future<_HubData> _load() async {
    final (rightsIssues, agmMeetings) = await (_repo.rightsIssues(), _repo.agmMeetings()).wait;
    return (rightsIssues: rightsIssues, agmMeetings: agmMeetings);
  }

  @override
  Widget build(BuildContext context) {
    return KCorpActionScaffold(
      title: 'Things to decide',
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
          if (data.rightsIssues.isEmpty && data.agmMeetings.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: KEmptyView(
                icon: 'portfolio',
                title: 'Nothing to decide right now',
                message: 'Rights issues and AGM votes on companies you hold will show up here.',
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

    final pending = <(DateTime deadline, Widget card)>[];
    final settled = <(DateTime when, Widget card)>[];

    for (final r in data.rightsIssues) {
      final isPending = r.status == CorpActionStatus.open && !r.alreadyElected;
      if (isPending) {
        pending.add((
          r.closeDate,
          KDecisionCard(
            deadlineLabel: 'Closes ${_shortDate(r.closeDate)}',
            title: '${r.ticker} rights issue · ${r.ratioText}',
            body: r.entitlementUnits > 0
                ? 'You can buy ${r.entitlementUnits} new shares at ${_formatNaira(r.subscriptionPriceKobo)} '
                    'each.'
                : 'Closes ${_shortDate(r.closeDate)}.',
            onTap: () => context.push(Routes.corpActionsRightsIssue),
          ),
        ));
      } else {
        final election = r.election;
        final body = election == null
            ? 'This offer closed.'
            : election.decision == RightsIssueDecision.takeUp
                ? 'You took up ${election.unitsSubscribed} shares.'
                : 'You let this one lapse.';
        settled.add((
          election?.decidedAt ?? r.closeDate,
          _SettledCard(
            dateLabel: _shortDate(election?.decidedAt ?? r.closeDate),
            title: '${r.ticker} rights issue · ${r.ratioText}',
            body: body,
          ),
        ));
      }
    }

    for (final m in data.agmMeetings) {
      final isPending =
          m.status == CorpActionStatus.open && !m.alreadyVoted && m.votesCloseAt.isAfter(now);
      if (isPending) {
        pending.add((
          m.votesCloseAt,
          KDecisionCard(
            deadlineLabel: 'Votes close ${_shortDate(m.votesCloseAt)}',
            title: '${m.ticker} AGM · ${m.resolutions.length} resolution'
                '${m.resolutions.length == 1 ? '' : 's'}',
            body: m.eligibleUnits > 0
                ? 'Vote your ${m.eligibleUnits} shares, or let it pass.'
                : 'Votes close ${_shortDate(m.votesCloseAt)}.',
            onTap: () => context.push(Routes.corpActionsAgm),
          ),
        ));
      } else {
        final vote = m.vote;
        settled.add((
          vote?.submittedAt ?? m.votesCloseAt,
          _SettledCard(
            dateLabel: _shortDate(vote?.submittedAt ?? m.votesCloseAt),
            title: '${m.ticker} AGM · ${m.resolutions.length} resolution'
                '${m.resolutions.length == 1 ? '' : 's'}',
            body: vote != null ? 'You voted on this meeting.' : 'Voting closed on this meeting.',
          ),
        ));
      }
    }

    pending.sort((a, b) => a.$1.compareTo(b.$1));
    settled.sort((a, b) => b.$1.compareTo(a.$1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_headline(pending.length), style: KType.data(color: KColor.ink2)),
        const SizedBox(height: 12),
        for (final (_, card) in pending) ...[card, const SizedBox(height: 12)],
        for (final (_, card) in settled) ...[card, const SizedBox(height: 12)],
        const KNudgeCard(
          tone: KNudgeTone.grape,
          title: 'What is a rights issue?',
          body: 'The company is raising money and offering existing owners first '
              'refusal, usually below the market price.',
        ),
        const SizedBox(height: 20),
        KButton(
          label: 'Dividends and unclaimed money',
          variant: KButtonVariant.ghost,
          onPressed: () => context.push(Routes.corpActionsDividends),
        ),
      ],
    );
  }

  String _headline(int pendingCount) {
    if (pendingCount == 0) return "Companies you own are doing things. Nothing needs your answer right now.";
    final noun = pendingCount == 1 ? 'One needs' : '$pendingCount need';
    return 'Companies you own are doing things. $noun an answer from you.';
  }
}

/// A settled action — reports only, no decision needed, so it's a plain
/// (non-tappable) card, same shape s81.html's own "Zenith bonus shares"
/// example used, now fed real already-elected/voted/closed items.
class _SettledCard extends StatelessWidget {
  const _SettledCard({required this.dateLabel, required this.title, required this.body});
  final String dateLabel;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              const KStatusPill(status: KStatus.approved, label: 'Done for you', small: true),
              const SizedBox(width: 10),
              Text(dateLabel.toUpperCase(), style: KType.micro(color: KColor.ink3)),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: KType.cardTitle()),
          const SizedBox(height: 2),
          Text(body, style: KType.data(color: KColor.ink2)),
        ],
      ),
    );
  }
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
