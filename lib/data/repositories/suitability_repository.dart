// Kudimata Securities — Suitability repository.
//
// Backs the suitability questionnaire (lib/screens/suitability/
// questionnaire_screen.dart) — replaces the previous dead-state where
// `_answers` was collected via setState but never submitted anywhere (see
// .pipeline/fragments/suitability-questionnaire.json STUB-
// suitability-questionnaire-1/2, HIGH-PRIORITY / "compliance-relevant gap").
// Backing resource (registry.json SuitabilityResult):
//   POST /suitability-result {answers: [{questionId, selectedOptionIndex}]}
//     -> SuitabilityResult
//
// The backend (Kudimata-Securities-Backend src/suitability-result/
// scoring.ts) derives a real risk profile from the submitted answers —
// `selectedOptionIndex` is an ordinal risk rank (0 = most conservative)
// averaged across all submitted answers, so [questionId] itself carries no
// scoring semantics; the DTO only requires it be a non-empty string. This
// screen's questionnaire has no natural stable id (5 hardcoded questions,
// no backend-defined question bank), so the caller uses the question's
// list index as its id ("q0".."q4") — see questionnaire_screen.dart.
//
// The suitability-result screen (separate agent) re-fetches the computed
// result via GET /suitability-result/me, so [submit] here doesn't need to
// return a parsed SuitabilityResult — the caller just needs to know the
// submission succeeded before navigating.
//
// [me] backs that result screen: GET /suitability-result/me -> SuitabilityResult
// (registry.json fields: id, userId, profile, rationale, answers, computedAt).
// There's no SuitabilityResult domain model in lib/data/models.dart (this
// resource is new, out of scope for that shared file), so — mirroring the
// existing [SuitabilityAnswer] local DTO below — [SuitabilityResult] here
// only carries the two fields the result screen's fragment says it reads
// (profile, rationale); extend additively if a future screen needs more.
//
// Construct with the ONE shared ApiClient:
//   final _repo = SuitabilityRepository(AppScope.read(context).apiClient);
import '../api/api_client.dart';

/// One submitted answer: which question, and the risk-ordinal index of the
/// option the user picked (0 = most conservative, per scoring.ts).
class SuitabilityAnswer {
  const SuitabilityAnswer({required this.questionId, required this.selectedOptionIndex});
  final String questionId;
  final int selectedOptionIndex;

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'selectedOptionIndex': selectedOptionIndex,
      };
}

/// GET /suitability-result/me response, trimmed to what the result screen
/// renders (see .pipeline/fragments/suitability-result.json "reads").
class SuitabilityResult {
  const SuitabilityResult({required this.profile, this.rationale});
  final String profile;
  final String? rationale;
}

class SuitabilityRepository {
  const SuitabilityRepository(this._client);
  final ApiClient _client;

  /// POST /suitability-result. Submits all collected answers so the backend
  /// can compute a real risk profile (see file header). Response is
  /// intentionally discarded — the result screen re-fetches via
  /// GET /suitability-result/me.
  Future<void> submit(List<SuitabilityAnswer> answers) async {
    await _client.post('/suitability-result', data: {
      'answers': answers.map((a) => a.toJson()).toList(),
    });
  }

  /// GET /suitability-result/me — the real computed profile (replaces the
  /// suitability-result screen's previous hardcoded "Balanced" literal, see
  /// .pipeline/fragments/suitability-result.json STUB-suitability-result-1).
  Future<SuitabilityResult> me() async {
    final response = await _client.get('/suitability-result/me');
    final json = response.data as Map<String, dynamic>;
    return SuitabilityResult(
      profile: json['profile'] as String? ?? '',
      rationale: json['rationale'] as String?,
    );
  }
}
