// Kudimata Securities — Statements repository (account-statements screen).
//
// registry.json's Statement resource: `{id, userId, kind, title,
// periodOrTradeRef, fileSizeBytes, generatedAt, fileObjectKey}`. It has no
// counterpart in lib/data/models.dart (out of scope for a per-screen wiring
// agent to edit, per lib/data/api/README.md), so — mirroring LegalDocument in
// legal_documents_repository.dart — this repository declares its own small
// local [Statement] model.
//
// GET /statements?kind=monthly|contract_note is a plain (non-paginated)
// `list<Statement>` per registry.json, so [list] parses `response.data`
// directly as a List. `userId` filtering is forced server-side from the
// authenticated request (Kudimata-Securities-Backend's
// src/statements/statements.service.ts — `findAll` always scopes to the
// caller's own rows), never a client-selectable param.
//
// GET /statements/:id/download-url returns a presigned S3 GET URL. Unlike
// legal-documents' `{downloadUrl, expiresAt}` shape, the statements module
// reuses the SHARED `PresignedDownloadUrlResponse` type
// (Kudimata-Securities-Backend src/common/types/transaction.types.ts —
// `{url: string}`, confirmed by src/statements/s3-presigner.service.ts,
// which returns `{ url }` with no separate `expiresAt` field), so [downloadUrl]
// reads the `url` key, not `downloadUrl`.
//
// The backend's Statement rows are currently placeholder-generated (no real
// PDF content exists yet, per statements.service.ts's own header comment on
// its generator methods) — that's a future backend concern, not this
// repository's; the plumbing here is wired against the real contract either
// way.
//
// Construct with the ONE shared ApiClient, reached via
// `AppScope.read(context).apiClient` (see main.dart / AppState.apiClient /
// lib/data/api/README.md) — never a second ApiClient instance:
//   final _repo = StatementsRepository(AppScope.read(context).apiClient);
import '../api/api_client.dart';

/// Which Statement.kind to fetch — mirrors registry.json's
/// `enum(monthly,contract_note)`.
enum StatementKind { monthly, contractNote }

/// A single statement/contract-note document (registry.json's Statement
/// resource). Not in lib/data/models.dart — see file header.
class Statement {
  const Statement({
    required this.id,
    required this.kind,
    required this.title,
    required this.periodOrTradeRef,
    required this.fileSizeBytes,
    required this.generatedAt,
    required this.fileObjectKey,
  });

  final String id;
  final StatementKind kind;
  final String title;
  final String? periodOrTradeRef;
  final int fileSizeBytes;

  /// ISO-8601 generation timestamp, as returned by the backend.
  final DateTime? generatedAt;
  final String fileObjectKey;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "25 Jun 2026 · 145 KB" — nearest real-data equivalent to the old
  /// hardcoded sub strings ('PDF · 240 KB' for statements, 'date · side' for
  /// contract notes). The backend's Statement carries no trade-side field
  /// (`periodOrTradeRef` on a contract note is an internal transaction id,
  /// not a formatted date/side pair), so this uses the two fields that are
  /// actually on the wire — [generatedAt] and [fileSizeBytes] — for both
  /// kinds, rather than inventing a side label that doesn't exist server-side.
  String get sub {
    final date = generatedAt;
    final dateStr =
        date == null ? '' : '${date.day} ${_months[date.month - 1]} ${date.year}';
    final sizeKb = (fileSizeBytes / 1024).round();
    final sizeStr = '$sizeKb KB';
    return dateStr.isEmpty ? sizeStr : '$dateStr · $sizeStr';
  }
}

class StatementsRepository {
  const StatementsRepository(this._client);
  final ApiClient _client;

  /// Mirrors the old hardcoded `_statements`/`_notes` lists in
  /// statements_screen.dart. GET /statements?kind= — a plain
  /// (non-paginated) `list<Statement>`.
  Future<List<Statement>> list(StatementKind kind) async {
    final response = await _client.get(
      '/statements',
      queryParameters: {'kind': _kindParam(kind)},
    );
    final items = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map(_fromJson).toList();
  }

  /// GET /statements/:id/download-url — presigned S3 GET URL for the tapped
  /// document. Returns just the URL string (see file header re: `url` vs
  /// `downloadUrl`).
  Future<String> downloadUrl(String id) async {
    final response = await _client.get('/statements/$id/download-url');
    final data = response.data as Map<String, dynamic>;
    return data['url'] as String? ?? '';
  }

  String _kindParam(StatementKind kind) => switch (kind) {
    StatementKind.monthly => 'monthly',
    StatementKind.contractNote => 'contract_note',
  };

  StatementKind _kindFromJson(String? kind) =>
      kind == 'contract_note' ? StatementKind.contractNote : StatementKind.monthly;

  Statement _fromJson(Map<String, dynamic> json) {
    return Statement(
      id: json['id'] as String? ?? '',
      kind: _kindFromJson(json['kind'] as String?),
      title: json['title'] as String? ?? '',
      periodOrTradeRef: json['periodOrTradeRef'] as String?,
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '')?.toLocal(),
      fileObjectKey: json['fileObjectKey'] as String? ?? '',
    );
  }
}
