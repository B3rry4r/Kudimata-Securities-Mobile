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
/// `enum(monthly,contract_note,wht_credit_note,annual_tax_summary)`.
///
/// [whtCreditNote] and [annualTaxSummary] added 2026-08-27 to restore the
/// Tax documents hub row (account_screen.dart) — see
/// tax_documents_screen.dart's own header for which of the two kinds this
/// backend actually generates today.
enum StatementKind { monthly, contractNote, whtCreditNote, annualTaxSummary }

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
    StatementKind.whtCreditNote => 'wht_credit_note',
    StatementKind.annualTaxSummary => 'annual_tax_summary',
  };

  StatementKind _kindFromJson(String? kind) => switch (kind) {
    'contract_note' => StatementKind.contractNote,
    'wht_credit_note' => StatementKind.whtCreditNote,
    'annual_tax_summary' => StatementKind.annualTaxSummary,
    _ => StatementKind.monthly,
  };

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

  /// Generates (or returns) THIS month's statement for the caller.
  ///
  /// Statements are otherwise produced by a monthly job on the 1st, so a
  /// newly-active investor would see nothing at all until a month closed
  /// (2026-08-24: "how are statements generated... it is just contract
  /// notes I am seeing"). Idempotent server-side — calling it twice in a
  /// month costs nothing and produces no duplicate.
  Future<void> generateThisMonth() =>
      _client.post('/statements/generate-monthly', data: {});

  /// The real itemised note behind a `contract_note` Statement. [ref] is
  /// the Statement's own `periodOrTradeRef` (a KDM-CN-xxxx reference).
  Future<ContractNote> contractNote(String ref) async {
    final res = await _client.get('/orders/contract-note/$ref');
    return ContractNote.fromJson(res.data as Map<String, dynamic>);
  }
}

/// One real, itemised contract note — GET /orders/contract-note/:ref
/// (2026-08-24). Before this endpoint existed the contract note screen
/// could only show a Statement's metadata (title, size, date), because
/// nothing linked a note back to the order whose figures it represents —
/// which is why it rendered logos and a file size instead of a document.
class ContractNote {
  const ContractNote({
    required this.contractNoteRef,
    required this.clientName,
    required this.chn,
    required this.tradeDate,
    required this.settlesOn,
    required this.side,
    required this.ticker,
    required this.assetName,
    required this.units,
    required this.fillPriceKobo,
    required this.considerationKobo,
    required this.commissionKobo,
    required this.exchangeFeesKobo,
    required this.vatKobo,
    required this.totalKobo,
    required this.executingBroker,
    required this.downloadUrl,
  });

  final String contractNoteRef;
  final String clientName;
  final String? chn;
  final DateTime tradeDate;
  final DateTime? settlesOn;
  final String side;
  final String ticker;
  final String assetName;
  final String units;
  final int fillPriceKobo;
  final int considerationKobo;
  final int commissionKobo;
  final int exchangeFeesKobo;
  final int vatKobo;
  final int totalKobo;
  final String executingBroker;

  /// Short-lived presigned GET for the stored PDF. Null when the note's
  /// render or upload failed at fill time — the screen must then say so
  /// rather than offer a download button that leads nowhere.
  final String? downloadUrl;

  int get totalFeesKobo => commissionKobo + exchangeFeesKobo + vatKobo;

  static ContractNote fromJson(Map<String, dynamic> j) => ContractNote(
        contractNoteRef: j['contractNoteRef'] as String,
        clientName: j['clientName'] as String? ?? '',
        chn: j['chn'] as String?,
        tradeDate: DateTime.parse(j['tradeDate'] as String),
        settlesOn: j['settlesOn'] == null ? null : DateTime.tryParse(j['settlesOn'] as String),
        side: j['side'] as String,
        ticker: j['ticker'] as String,
        assetName: j['assetName'] as String? ?? '',
        units: j['units']?.toString() ?? '0',
        fillPriceKobo: (j['fillPriceKobo'] as num?)?.toInt() ?? 0,
        considerationKobo: (j['considerationKobo'] as num?)?.toInt() ?? 0,
        commissionKobo: (j['commissionKobo'] as num?)?.toInt() ?? 0,
        exchangeFeesKobo: (j['exchangeFeesKobo'] as num?)?.toInt() ?? 0,
        vatKobo: (j['vatKobo'] as num?)?.toInt() ?? 0,
        totalKobo: (j['totalKobo'] as num?)?.toInt() ?? 0,
        executingBroker: j['executingBroker'] as String? ?? '',
        downloadUrl: j['downloadUrl'] as String?,
      );
}
