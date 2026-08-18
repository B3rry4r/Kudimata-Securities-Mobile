// Kudimata Securities — Legal documents repository (account-legal screen,
// and the four onboarding acceptance screens: terms of service, privacy
// policy, risk disclosure, client agreement).
//
// registry.json's LegalDocument resource: `{id, title, versionLabel,
// publishedAt, fileObjectKey, kind, sections}`. It has no counterpart in
// lib/data/models.dart (out of scope for a per-screen wiring agent to edit,
// per lib/data/api/README.md), so — mirroring NotificationItem in
// notifications_repository.dart and BankAccountSummary in
// bank_accounts_repository.dart — this repository declares its own small
// local [LegalDocument] model.
//
// GET /legal-documents is a plain (non-paginated) `list<LegalDocument>` per
// registry.json (Kudimata-Securities-Backend's own service comment confirms:
// "small fixed list, no pagination per conventions.md"), so [list] parses
// `response.data` directly as a List.
//
// GET /legal-documents/content/:kind (non-custodial-redesign-era addition —
// backend supersedes.json, "backend-driven legal document content"):
// returns the CURRENT published document for one of the four in-app
// acceptance kinds ('terms_of_service' | 'privacy_policy' |
// 'risk_disclosure' | 'client_agreement'), including its `sections` — this
// is what the four onboarding acceptance screens render instead of
// hardcoded copy, so a content update never requires a mobile release.
//
// GET /legal-documents/:id/download-url returns a presigned S3 GET URL as
// `{downloadUrl, expiresAt}` (Kudimata-Securities-Backend
// src/legal-documents/dto/legal-document.dto.ts —
// LegalDocumentDownloadUrlResponse). [downloadUrl] returns just the URL
// string; `expiresAt` isn't needed since the screen launches it immediately
// rather than caching it.
//
// Construct with the ONE shared ApiClient, reached via
// `AppScope.read(context).apiClient` (see main.dart / AppState.apiClient /
// lib/data/api/README.md) — never a second ApiClient instance:
//   final _repo = LegalDocumentsRepository(AppScope.read(context).apiClient);
import '../api/api_client.dart';

/// One rendered section of a LegalDocument's inline content — an
/// eyebrow-led heading + body, the same shape the onboarding acceptance
/// screens already rendered from a hardcoded `_Section`/`_Clause` list.
class LegalDocumentSection {
  const LegalDocumentSection({required this.heading, required this.body});
  final String heading;
  final String body;

  factory LegalDocumentSection.fromJson(Map<String, dynamic> json) => LegalDocumentSection(
        heading: json['heading'] as String? ?? '',
        body: json['body'] as String? ?? '',
      );
}

/// A single legal document (registry.json's LegalDocument resource). Not in
/// lib/data/models.dart — see file header.
class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.title,
    required this.versionLabel,
    required this.publishedAt,
    required this.fileObjectKey,
    required this.kind,
    required this.sections,
  });

  final String id;
  final String title;
  final String versionLabel;

  /// ISO-8601 publish timestamp, as returned by the backend.
  final DateTime? publishedAt;
  final String fileObjectKey;

  /// 'risk_disclosure' | 'client_agreement' | 'privacy_policy' |
  /// 'terms_of_service' | 'other'.
  final String kind;

  /// Present only for the four kinds with an in-app acceptance flow — the
  /// content GET /legal-documents/content/:kind exists to serve. Null (or
  /// empty) for a plain reference/download document (kind == 'other').
  final List<LegalDocumentSection> sections;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "Version 1.0 · 25 Jun 2026" — matches the sub string the old
  /// hardcoded `_docs` list in legal_screen.dart baked in statically.
  String get sub {
    final date = publishedAt;
    final formatted = date == null
        ? ''
        : '${date.day} ${_months[date.month - 1]} ${date.year}';
    return 'Version $versionLabel${formatted.isEmpty ? '' : ' · $formatted'}';
  }
}

class LegalDocumentsRepository {
  const LegalDocumentsRepository(this._client);
  final ApiClient _client;

  /// Mirrors the old hardcoded `_docs` list in legal_screen.dart.
  /// GET /legal-documents — a plain (non-paginated) `list<LegalDocument>`.
  Future<List<LegalDocument>> list() async {
    final response = await _client.get('/legal-documents');
    final items = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map(_fromJson).toList();
  }

  /// GET /legal-documents/content/:kind — the current document (with
  /// sections) for one of the four onboarding acceptance screens. [kind]
  /// is one of 'terms_of_service' | 'privacy_policy' | 'risk_disclosure' |
  /// 'client_agreement'. Throws [ApiException] (404) if no document has
  /// been published for that kind yet — the calling screen has no
  /// reasonable fallback for that, so it surfaces as this sheet/screen's
  /// normal error-retry state rather than being caught here.
  Future<LegalDocument> getContent(String kind) async {
    final response = await _client.get('/legal-documents/content/$kind');
    return _fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /public/legal-documents/content/:kind — unauthenticated mirror of
  /// [getContent], for sign_up_screen.dart's "By continuing..." links. This
  /// is the ONE screen with no account/token yet, so it can't call the
  /// investor-gated route above; the backend registers a second, guardless
  /// controller for exactly this case (see
  /// Kudimata-Securities-Backend/src/legal-documents/
  /// legal-documents-public.controller.ts).
  Future<LegalDocument> getPublicContent(String kind) async {
    final response = await _client.get('/public/legal-documents/content/$kind');
    return _fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /legal-documents/:id/download-url — presigned S3 GET URL for the
  /// tapped document. Returns just the URL string (see file header).
  Future<String> downloadUrl(String id) async {
    final response = await _client.get('/legal-documents/$id/download-url');
    final data = response.data as Map<String, dynamic>;
    return data['downloadUrl'] as String? ?? '';
  }

  LegalDocument _fromJson(Map<String, dynamic> json) {
    final sectionsJson = json['sections'] as List<dynamic>?;
    return LegalDocument(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      versionLabel: json['versionLabel'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? '')?.toLocal(),
      fileObjectKey: json['fileObjectKey'] as String? ?? '',
      kind: json['kind'] as String? ?? 'other',
      sections: sectionsJson == null
          ? const []
          : sectionsJson
              .cast<Map<String, dynamic>>()
              .map(LegalDocumentSection.fromJson)
              .toList(),
    );
  }
}
