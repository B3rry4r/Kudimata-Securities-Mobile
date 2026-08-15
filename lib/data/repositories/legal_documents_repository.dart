// Kudimata Securities — Legal documents repository (account-legal screen).
//
// registry.json's LegalDocument resource: `{id, title, versionLabel,
// publishedAt, fileObjectKey}`. It has no counterpart in lib/data/models.dart
// (out of scope for a per-screen wiring agent to edit, per lib/data/api/
// README.md), so — mirroring NotificationItem in notifications_repository.dart
// and BankAccountSummary in bank_accounts_repository.dart — this repository declares
// its own small local [LegalDocument] model.
//
// GET /legal-documents is a plain (non-paginated) `list<LegalDocument>` per
// registry.json (Kudimata-Securities-Backend's own service comment confirms:
// "small fixed list, no pagination per conventions.md"), so [list] parses
// `response.data` directly as a List.
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

/// A single legal document (registry.json's LegalDocument resource). Not in
/// lib/data/models.dart — see file header.
class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.title,
    required this.versionLabel,
    required this.publishedAt,
    required this.fileObjectKey,
  });

  final String id;
  final String title;
  final String versionLabel;

  /// ISO-8601 publish timestamp, as returned by the backend.
  final DateTime? publishedAt;
  final String fileObjectKey;

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

  /// GET /legal-documents/:id/download-url — presigned S3 GET URL for the
  /// tapped document. Returns just the URL string (see file header).
  Future<String> downloadUrl(String id) async {
    final response = await _client.get('/legal-documents/$id/download-url');
    final data = response.data as Map<String, dynamic>;
    return data['downloadUrl'] as String? ?? '';
  }

  LegalDocument _fromJson(Map<String, dynamic> json) {
    return LegalDocument(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      versionLabel: json['versionLabel'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? '')?.toLocal(),
      fileObjectKey: json['fileObjectKey'] as String? ?? '',
    );
  }
}
