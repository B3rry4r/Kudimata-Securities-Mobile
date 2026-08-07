// Kudimata Securities — Compliance repository.
//
// See lib/data/api/README.md for the shared convention. Construct with the
// ONE shared ApiClient, reached via `AppScope.read(context).apiClient` —
// never a second ApiClient instance:
//   final _repo = ComplianceRepository(AppScope.read(context).apiClient);
//
// registry.json's `ComplianceAcknowledgement` resource:
//   POST /compliance-acknowledgements {kind, documentVersion}
//     -> ComplianceAcknowledgement {id, userId, kind, documentVersion, acknowledgedAt}
//
// Backs the risk-disclosure and client-agreement screens, whose stubs
// (Kudimata-Securities-Backend/.pipeline/fragments/risk-disclosure.json,
// STUB-risk-disclosure-1) flagged that tapping "Agree" was pure client-side
// navigation with no durable record of consent. This persists that consent
// server-side (user id + timestamp + document version), tied to whichever
// document version the calling screen's copy corresponds to.
import '../api/api_client.dart';

class ComplianceRepository {
  const ComplianceRepository(this._client);
  final ApiClient _client;

  /// POST /compliance-acknowledgements {kind, documentVersion} ->
  /// ComplianceAcknowledgement. The response body isn't needed by any
  /// calling screen (the kind/version it sent are already known) — a
  /// non-2xx surfaces as [ApiException] via ApiClient's guard, which is all
  /// the caller needs to know the acknowledgement failed to persist.
  Future<void> acknowledge({required String kind, required String documentVersion}) async {
    await _client.post(
      '/compliance-acknowledgements',
      data: {'kind': kind, 'documentVersion': documentVersion},
    );
  }
}
