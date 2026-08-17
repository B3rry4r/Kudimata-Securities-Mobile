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
}
