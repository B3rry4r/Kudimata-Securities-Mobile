// AGM · vote your shares — R-24 (docs/redesign/DECISIONS.md): kept and
// restyled onto the new tokens; no artboard of its own (R-5 correction,
// 2026-08-27 — this file used to cite a stale "screen 83" id from an
// earlier, now-superseded pass; the task brief is the only valid source
// for an artboard id and it names none for this screen).
//
// Wired per lib/data/api/README.md's FutureBuilder convention:
// CorporateActionsRepository.agmMeetings() (GET /agm-meetings) replaces the
// static `AgmFixture` (and its 3 fabricated placeholder resolutions — only
// 2 ever had real canvas content) this screen used to be pushed with, and
// .submitAgmVote() (POST /agm-meetings/:id/vote) replaces the
// always-"not available yet" Submit button. Real resolutions come straight
// from `AgmMeetingListItem.resolutions` — whatever count/text the backend
// actually declared for the meeting, not a fixed 3/5.
//
// NOTE — no `extra`/id argument, same reasoning as rights_issue_screen.dart:
// app_router.dart's GoRoute for Routes.corpActionsAgm constructs
// `AgmVoteScreen()` with no forwarded `extra` (router files are a
// different agent's directory this pass), so this screen fetches the
// caller's own AGM list and picks the most relevant meeting itself: the
// first still-open one with voting not yet closed that the caller hasn't
// voted on, falling back to the most recent meeting overall.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/corporate_actions_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'corporate_actions_widgets.dart';

class AgmVoteScreen extends StatefulWidget {
  const AgmVoteScreen({super.key});

  @override
  State<AgmVoteScreen> createState() => _AgmVoteScreenState();
}

class _AgmVoteScreenState extends State<AgmVoteScreen> {
  late final _repo = CorporateActionsRepository(AppScope.read(context).apiClient);
  late Future<List<AgmMeetingListItem>> _future = _repo.agmMeetings();

  AgmMeetingListItem? _pickRelevant(List<AgmMeetingListItem> items) {
    final now = DateTime.now();
    for (final item in items) {
      if (item.status == CorpActionStatus.open &&
          !item.alreadyVoted &&
          item.votesCloseAt.isAfter(now)) {
        return item;
      }
    }
    return items.isEmpty ? null : items.first;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AgmMeetingListItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const KCorpActionScaffold(
            title: 'AGM',
            child: Padding(padding: EdgeInsets.symmetric(vertical: 40), child: KLoadingView()),
          );
        }
        if (snapshot.hasError) {
          return KCorpActionScaffold(
            title: 'AGM',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: KErrorView(onPrimary: () => setState(() => _future = _repo.agmMeetings())),
            ),
          );
        }
        final items = snapshot.data ?? const <AgmMeetingListItem>[];
        final item = _pickRelevant(items);
        if (item == null) {
          return const KCorpActionScaffold(
            title: 'AGM',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: KEmptyView(
                icon: 'portfolio',
                title: 'No AGM to show',
                message: 'AGM meetings on companies you hold will show up here.',
              ),
            ),
          );
        }
        return KCorpActionScaffold(
          title: '${item.ticker} AGM',
          child: _AgmDetail(key: ValueKey(item.id), repo: _repo, item: item),
        );
      },
    );
  }
}

class _AgmDetail extends StatefulWidget {
  const _AgmDetail({super.key, required this.repo, required this.item});
  final CorporateActionsRepository repo;
  final AgmMeetingListItem item;

  @override
  State<_AgmDetail> createState() => _AgmDetailState();
}

class _AgmDetailState extends State<_AgmDetail> {
  late AgmMeetingListItem _item = widget.item;

  // Every resolution defaults to "For", matching s83.html's own chips
  // (selected="{{ true }}" on the first PillChip shown). Keyed by
  // resolution id (the real backend key), not display order.
  late final Map<String, AgmVoteChoice> _votes = {
    for (final r in _item.resolutions) r.id: AgmVoteChoice.forIt,
  };

  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final vote = await widget.repo.submitAgmVote(_item.id, _votes);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _item = _item.withVote(vote);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final agm = _item;
    final vote = agm.vote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          agm.eligibleUnits > 0
              ? 'You hold ${agm.eligibleUnits} shares, so you have ${agm.eligibleUnits} votes on '
                  'each resolution. Votes close ${_fullDate(agm.votesCloseAt)}.'
              : 'Votes close ${_fullDate(agm.votesCloseAt)}.',
          style: KType.data(color: KColor.ink2),
        ),
        const SizedBox(height: 12),
        for (final resolution in agm.resolutions) ...[
          _ResolutionCard(
            index: resolution.order,
            description: resolution.description,
            selected: vote != null ? vote.votes[resolution.id] : _votes[resolution.id],
            readOnly: vote != null,
            onChanged: (b) => setState(() => _votes[resolution.id] = b),
          ),
          const SizedBox(height: 12),
        ],
        if (vote != null) ...[
          Row(
            children: [
              const KStatusPill(status: KStatus.approved, label: 'Voted', small: true),
              const SizedBox(width: 10),
              Text('on ${_fullDate(vote.submittedAt)}', style: KType.micro(color: KColor.ink3)),
            ],
          ),
        ] else ...[
          Text(
            'We submit your votes as your proxy.',
            style: KType.data(color: KColor.ink3),
          ),
          const SizedBox(height: 20),
          KButton(
            label: 'Submit my votes',
            loading: _busy,
            onPressed: _busy ? null : _submit,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: KType.micro(color: KColor.loss)),
          ],
        ],
        const SizedBox(height: 10),
        // No document-email endpoint exists anywhere in
        // Kudimata-Securities-Backend's corporate-actions module — a real,
        // still-accurate backend gap (not something this pass wires),
        // same honest "not available yet" message the rest of this app
        // uses rather than pretending an email was sent.
        KButton(
          label: 'Email me the notice of meeting',
          variant: KButtonVariant.ghost,
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Emailing the notice of meeting isn't available yet — check back soon."),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResolutionCard extends StatelessWidget {
  const _ResolutionCard({
    required this.index,
    required this.description,
    required this.selected,
    required this.readOnly,
    required this.onChanged,
  });

  final int index;
  final String description;
  final AgmVoteChoice? selected;
  final bool readOnly;
  final ValueChanged<AgmVoteChoice> onChanged;

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
          Text('$index · $description', style: KType.cardTitle()),
          const SizedBox(height: 10),
          Row(
            children: [
              KPillChip(
                label: 'For',
                selected: selected == AgmVoteChoice.forIt,
                onTap: readOnly ? null : () => onChanged(AgmVoteChoice.forIt),
              ),
              const SizedBox(width: 8),
              KPillChip(
                label: 'Against',
                selected: selected == AgmVoteChoice.against,
                onTap: readOnly ? null : () => onChanged(AgmVoteChoice.against),
              ),
              const SizedBox(width: 8),
              KPillChip(
                label: 'Abstain',
                selected: selected == AgmVoteChoice.abstain,
                onTap: readOnly ? null : () => onChanged(AgmVoteChoice.abstain),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "2026-04-04T18:00:00.000Z" -> "04 Apr 2026 · 18:00".
String _fullDate(DateTime dt) {
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day.toString().padLeft(2, '0')} ${_months[local.month - 1]} ${local.year} · $hh:$mm';
}
