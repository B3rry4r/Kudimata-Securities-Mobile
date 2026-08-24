// Kudimata Securities — Compliance repository.
//
// See lib/data/api/README.md for the shared convention. Construct with the
// ONE shared ApiClient, reached via `AppScope.read(context).apiClient` —
// never a second ApiClient instance:
//   final _repo = ComplianceRepository(AppScope.read(context).apiClient);
//
// registry.json's `ComplianceAcknowledgement` resource:
//   POST /compliance-acknowledgements {kind}
//     -> ComplianceAcknowledgement {id, userId, kind, documentVersion, legalDocumentId, acknowledgedAt}
//
// Backs the four onboarding acceptance screens (terms of service, privacy
// policy, risk disclosure, client agreement). No `documentVersion` in the
// request: the backend resolves the current LegalDocument for `kind` itself
// at acceptance time (LegalDocumentsRepository.getContent(kind) is what the
// calling screen used moments earlier to fetch the content it displayed —
// this call re-resolves the same "current" document server-side, so the
// acknowledgement always points at whatever was actually shown rather than
// trusting a client-supplied version string).
import '../api/api_client.dart';

class ComplianceRepository {
  const ComplianceRepository(this._client);
  final ApiClient _client;

  /// POST /compliance-acknowledgements {kind} -> ComplianceAcknowledgement.
  /// The response body isn't needed by any calling screen — a non-2xx
  /// surfaces as [ApiException] via ApiClient's guard, which is all the
  /// caller needs to know the acknowledgement failed to persist.
  Future<void> acknowledge({required String kind}) async {
    await _client.post('/compliance-acknowledgements', data: {'kind': kind});
  }

  /// GET /compliance-acknowledgements/me — not a registry.json endpoint
  /// (see Kudimata-Securities-Backend's
  /// ComplianceAcknowledgementsService.findAllForUser doc comment), added
  /// 2026-08-24 so app_state.dart can hydrate whether a RETURNING investor
  /// already accepted the risk disclosure in a past session — without
  /// this, the mandatory once-per-investor risk-disclaimer gate would
  /// re-block every returning investor on every fresh app boot (in-memory
  /// AppState flags reset to their defaults on every launch). Returns just
  /// the set of acknowledged kinds — no caller needs the full record shape.
  Future<Set<String>> myAcknowledgedKinds() async {
    final response = await _client.get('/compliance-acknowledgements/me');
    final items = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map((j) => j['kind'] as String).toSet();
  }
}
