// Kudimata Securities — Corporate actions repository (rights issues + AGM
// meetings).
//
// See lib/data/api/README.md for the shared convention. Construct with the
// ONE shared ApiClient, reached via `AppScope.read(context).apiClient` —
// never a second ApiClient instance:
//   final _repo = CorporateActionsRepository(AppScope.read(context).apiClient);
//
// Backs the corporate-actions hub + detail screens (lib/screens/
// corporate_actions/corporate_actions_screen.dart,
// rights_issue_screen.dart, agm_vote_screen.dart) — replaces
// corporate_actions_data.dart's static `kMockRightsIssue`/`kMockAgm`
// fixtures with real reads/writes. Backing resources
// (Kudimata-Securities-Backend src/common/types/corporate-action.types.ts,
// src/corporate-actions/rights-issues.controller.ts,
// src/corporate-actions/agm-meetings.controller.ts):
//   GET  /rights-issues            -> list<RightsIssueListItem> (investor;
//                                      every issue at a ticker the caller
//                                      currently holds, any status — a
//                                      closed one the caller already acted
//                                      on stays visible as history)
//   POST /rights-issues/:id/elect  {decision, unitsSubscribed?}
//                                    -> RightsIssueElection
//   GET  /agm-meetings             -> list<AgmMeetingListItem> (same
//                                      "every ticker the caller holds, any
//                                      status" shape as rights issues)
//   POST /agm-meetings/:id/vote    {votes: {resolutionId: choice}}
//                                    -> AgmVote
//
// entitlementUnits/eligibleUnits/alreadyElected/alreadyVoted/election/vote
// are all server-computed fresh on every GET — never trust/cache a stale
// copy client-side once an elect/vote call succeeds; re-render from that
// call's own response instead (see the screens for how).
//
// Local models — not in lib/data/models.dart, out of scope for a per-screen
// wiring agent to add there (README.md) — mirror the backend's wire shapes
// exactly, including fields the current screens don't render yet (e.g.
// RightsIssue.status), so a later screen change doesn't need a repository
// change too.
import '../api/api_client.dart';

class CorporateActionsRepository {
  const CorporateActionsRepository(this._client);
  final ApiClient _client;

  /// GET /rights-issues — bare (non-paginated) `list<RightsIssueListItem>`.
  Future<List<RightsIssueListItem>> rightsIssues() async {
    final response = await _client.get('/rights-issues');
    final items = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map(RightsIssueListItem.fromJson).toList();
  }

  /// POST /rights-issues/:id/elect. [unitsSubscribed] is required (and must
  /// be > 0) when [decision] is [RightsIssueDecision.takeUp]; the backend
  /// forces it to 0 regardless of what's sent when [decision] is
  /// [RightsIssueDecision.lapse], so omitting it for a lapse is fine.
  /// entitlementUnits is never sent — the server always recomputes it from
  /// the caller's live Holding.
  Future<RightsIssueElection> electRightsIssue(
    String rightsIssueId, {
    required RightsIssueDecision decision,
    int? unitsSubscribed,
  }) async {
    final response = await _client.post('/rights-issues/$rightsIssueId/elect', data: {
      'decision': decision.wireValue,
      'unitsSubscribed': ?unitsSubscribed,
    });
    return RightsIssueElection.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /agm-meetings — bare (non-paginated) `list<AgmMeetingListItem>`.
  Future<List<AgmMeetingListItem>> agmMeetings() async {
    final response = await _client.get('/agm-meetings');
    final items = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map(AgmMeetingListItem.fromJson).toList();
  }

  /// POST /agm-meetings/:id/vote. [votes] is keyed by
  /// `AgmResolutionDef.id` (NOT display order) — must contain at least one
  /// entry, and every key must be a resolution id that actually belongs to
  /// this meeting, or the backend rejects with 400.
  Future<AgmVote> submitAgmVote(String agmMeetingId, Map<String, AgmVoteChoice> votes) async {
    final response = await _client.post('/agm-meetings/$agmMeetingId/vote', data: {
      'votes': votes.map((id, choice) => MapEntry(id, choice.wireValue)),
    });
    return AgmVote.fromJson(response.data as Map<String, dynamic>);
  }
}

// ── Shared status ────────────────────────────────────────────────────────

/// CorporateActionStatus — RightsIssue.status / AgmMeeting.status.
enum CorpActionStatus { open, closed }

CorpActionStatus _statusFromJson(String? status) =>
    status == 'closed' ? CorpActionStatus.closed : CorpActionStatus.open;

// ── Rights issues ────────────────────────────────────────────────────────

/// RightsIssueElection.decision.
enum RightsIssueDecision {
  takeUp('take_up'),
  lapse('lapse');

  const RightsIssueDecision(this.wireValue);
  final String wireValue;

  static RightsIssueDecision fromWire(String? value) =>
      value == 'take_up' ? RightsIssueDecision.takeUp : RightsIssueDecision.lapse;
}

/// GET /rights-issues response item — RightsIssue annotated with the
/// caller's own live-computed entitlement + election state.
class RightsIssueListItem {
  const RightsIssueListItem({
    required this.id,
    required this.ticker,
    required this.ratioText,
    required this.subscriptionPriceKobo,
    required this.closeDate,
    required this.status,
    required this.entitlementUnits,
    required this.alreadyElected,
    required this.election,
  });

  final String id;
  final String ticker;

  /// Display string only (e.g. "1 for 5") — not intended to be parsed for
  /// arithmetic client-side; [entitlementUnits] below is the already
  /// server-computed number.
  final String ratioText;
  final int subscriptionPriceKobo;
  final DateTime closeDate;
  final CorpActionStatus status;

  /// Caller's current Holding.units at [ticker] × the parsed ratio, floored.
  /// 0 if the caller holds none.
  final int entitlementUnits;
  final bool alreadyElected;
  final RightsIssueElection? election;

  /// Used by rights_issue_screen.dart to reflect a just-submitted election
  /// locally (real updated state, not a re-fetch) without re-declaring
  /// every field.
  RightsIssueListItem withElection(RightsIssueElection election) => RightsIssueListItem(
        id: id,
        ticker: ticker,
        ratioText: ratioText,
        subscriptionPriceKobo: subscriptionPriceKobo,
        closeDate: closeDate,
        status: status,
        entitlementUnits: entitlementUnits,
        alreadyElected: true,
        election: election,
      );

  factory RightsIssueListItem.fromJson(Map<String, dynamic> json) => RightsIssueListItem(
        id: json['id'] as String? ?? '',
        ticker: json['ticker'] as String? ?? '',
        ratioText: json['ratioText'] as String? ?? '',
        subscriptionPriceKobo: (json['subscriptionPriceKobo'] as num?)?.toInt() ?? 0,
        closeDate: DateTime.tryParse(json['closeDate'] as String? ?? '') ?? DateTime(1970),
        status: _statusFromJson(json['status'] as String?),
        entitlementUnits: (json['entitlementUnits'] as num?)?.toInt() ?? 0,
        alreadyElected: json['alreadyElected'] as bool? ?? false,
        election: json['election'] == null
            ? null
            : RightsIssueElection.fromJson(json['election'] as Map<String, dynamic>),
      );
}

/// RightsIssueElection — the caller's own election row on a RightsIssue.
class RightsIssueElection {
  const RightsIssueElection({
    required this.id,
    required this.rightsIssueId,
    required this.decision,
    required this.entitlementUnits,
    required this.unitsSubscribed,
    required this.decidedAt,
  });

  final String id;
  final String rightsIssueId;
  final RightsIssueDecision decision;

  /// Snapshotted server-side at election time.
  final int entitlementUnits;

  /// 0 when [decision] is [RightsIssueDecision.lapse].
  final int unitsSubscribed;
  final DateTime decidedAt;

  factory RightsIssueElection.fromJson(Map<String, dynamic> json) => RightsIssueElection(
        id: json['id'] as String? ?? '',
        rightsIssueId: json['rightsIssueId'] as String? ?? '',
        decision: RightsIssueDecision.fromWire(json['decision'] as String?),
        entitlementUnits: (json['entitlementUnits'] as num?)?.toInt() ?? 0,
        unitsSubscribed: (json['unitsSubscribed'] as num?)?.toInt() ?? 0,
        decidedAt: DateTime.tryParse(json['decidedAt'] as String? ?? '') ?? DateTime(1970),
      );
}

// ── AGM meetings ─────────────────────────────────────────────────────────

/// AgmVote.votes value per resolution.
enum AgmVoteChoice {
  forIt('for'),
  against('against'),
  abstain('abstain');

  const AgmVoteChoice(this.wireValue);
  final String wireValue;

  static AgmVoteChoice fromWire(String? value) => switch (value) {
        'against' => AgmVoteChoice.against,
        'abstain' => AgmVoteChoice.abstain,
        _ => AgmVoteChoice.forIt,
      };
}

/// AgmResolutionDef — one resolution on an AgmMeeting.
class AgmResolutionDef {
  const AgmResolutionDef({required this.id, required this.order, required this.description});

  final String id;

  /// Display order, 1-based, server-assigned.
  final int order;
  final String description;

  factory AgmResolutionDef.fromJson(Map<String, dynamic> json) => AgmResolutionDef(
        id: json['id'] as String? ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
        description: json['description'] as String? ?? '',
      );
}

/// GET /agm-meetings response item — AgmMeeting annotated with the caller's
/// own live-computed voting eligibility + vote state.
class AgmMeetingListItem {
  const AgmMeetingListItem({
    required this.id,
    required this.ticker,
    required this.title,
    required this.votesCloseAt,
    required this.status,
    required this.resolutions,
    required this.eligibleUnits,
    required this.alreadyVoted,
    required this.vote,
  });

  final String id;
  final String ticker;
  final String title;
  final DateTime votesCloseAt;
  final CorpActionStatus status;
  final List<AgmResolutionDef> resolutions;

  /// Caller's current Holding.units at [ticker], floored. 0 if the caller
  /// holds none.
  final int eligibleUnits;
  final bool alreadyVoted;
  final AgmVote? vote;

  /// Used by agm_vote_screen.dart to reflect a just-submitted vote locally
  /// (real updated state, not a re-fetch) without re-declaring every field.
  AgmMeetingListItem withVote(AgmVote vote) => AgmMeetingListItem(
        id: id,
        ticker: ticker,
        title: title,
        votesCloseAt: votesCloseAt,
        status: status,
        resolutions: resolutions,
        eligibleUnits: eligibleUnits,
        alreadyVoted: true,
        vote: vote,
      );

  factory AgmMeetingListItem.fromJson(Map<String, dynamic> json) => AgmMeetingListItem(
        id: json['id'] as String? ?? '',
        ticker: json['ticker'] as String? ?? '',
        title: json['title'] as String? ?? '',
        votesCloseAt: DateTime.tryParse(json['votesCloseAt'] as String? ?? '') ?? DateTime(1970),
        status: _statusFromJson(json['status'] as String?),
        resolutions: ((json['resolutions'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(AgmResolutionDef.fromJson)
            .toList(),
        eligibleUnits: (json['eligibleUnits'] as num?)?.toInt() ?? 0,
        alreadyVoted: json['alreadyVoted'] as bool? ?? false,
        vote: json['vote'] == null ? null : AgmVote.fromJson(json['vote'] as Map<String, dynamic>),
      );
}

/// AgmVote — the caller's own vote row on an AgmMeeting.
class AgmVote {
  const AgmVote({
    required this.id,
    required this.agmMeetingId,
    required this.votes,
    required this.eligibleUnits,
    required this.submittedAt,
  });

  final String id;
  final String agmMeetingId;

  /// Keyed by AgmResolutionDef.id.
  final Map<String, AgmVoteChoice> votes;

  /// Snapshotted server-side at submission time.
  final int eligibleUnits;
  final DateTime submittedAt;

  factory AgmVote.fromJson(Map<String, dynamic> json) => AgmVote(
        id: json['id'] as String? ?? '',
        agmMeetingId: json['agmMeetingId'] as String? ?? '',
        votes: ((json['votes'] as Map<String, dynamic>?) ?? const {})
            .map((id, choice) => MapEntry(id, AgmVoteChoice.fromWire(choice as String?))),
        eligibleUnits: (json['eligibleUnits'] as num?)?.toInt() ?? 0,
        submittedAt: DateTime.tryParse(json['submittedAt'] as String? ?? '') ?? DateTime(1970),
      );
}
