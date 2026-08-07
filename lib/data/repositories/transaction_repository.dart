// Kudimata Securities — Transaction repository.
//
// See lib/data/api/README.md for the shared convention. Construct with the
// ONE shared ApiClient, reached via `AppScope.read(context).apiClient` —
// never a second ApiClient instance:
//   final _repo = TransactionRepository(AppScope.read(context).apiClient);
//
// Backend resource: registry.json "Transaction". Money crosses the wire as
// `amountKobo` (signed integer kobo) now, not the preformatted "+₦..."
// string the `Txn` model still carries (S-1/T-09, UA-10) — [_formatAmount]
// below does that client-side kobo→₦ conversion so `Txn.amount` keeps
// rendering the same preformatted string every screen already expects.
// Likewise `createdAt` (ISO-8601) is formatted client-side into `Txn.date`'s
// existing "24 Jun 2026 · 14:32" shape.
//
// `byId` backs transaction-detail (GET /transactions/:id). `list` (added by
// the wallet-tab wiring pass) backs the wallet screen's "Recent" ledger card
// (GET /transactions — PaginatedList<Transaction>, mirrors MockData.txns) —
// extended additively per this file's own instruction above, reusing the
// same `_fromJson`/formatting helpers so a ledger row and a transaction
// detail format identically. WalletRepository also reuses `_fromJson`'s
// shape (duplicated there, not imported — see that file) to parse the
// single-Transaction response of POST /transactions/fund and
// POST /transactions/withdraw.
import '../api/api_client.dart';
import '../api/paginated_response.dart';
import '../models.dart';

class TransactionRepository {
  const TransactionRepository(this._client);
  final ApiClient _client;

  /// Mirrors MockData.txns. GET /transactions — `PaginatedList<Transaction>`,
  /// sorted `when:desc` server-side (registry.json). The wallet tab's
  /// "Recent" card has no pagination/"load more" UI of its own (same as the
  /// mock version, which just rendered every item), so this fetches one page
  /// sized generously enough to stand in for that card.
  Future<PaginatedResponse<Txn>> list({int page = 1, int pageSize = 20}) async {
    final response = await _client.get(
      '/transactions',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return PaginatedResponse<Txn>.fromJson(
      response.data as Map<String, dynamic>,
      _fromJson,
    );
  }

  /// Mirrors MockData.txnById. GET /transactions/:id — a bare
  /// (non-paginated) `Transaction` object per registry.json.
  Future<Txn> byId(String id) async {
    final response = await _client.get('/transactions/$id');
    return _fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /transactions/:id/receipt — registry.json describes the response
  /// only as "presigned download URL"; the backend's chosen field name is
  /// `url` (see Kudimata-Securities-Backend
  /// src/common/types/transaction.types.ts PresignedDownloadUrlResponse).
  ///
  /// NOTE: the backend's receipt generation is a known stub — it returns a
  /// placeholder URL, not a real PDF, since no PDF-generation service exists
  /// yet (see transactions.service.ts's getReceiptUrl doc comment). This
  /// method still calls the real endpoint so the plumbing is correct
  /// end-to-end; the caller should not expect a real downloadable document
  /// yet.
  Future<String> receiptUrl(String id) async {
    final response = await _client.get('/transactions/$id/receipt');
    final data = response.data as Map<String, dynamic>;
    return data['url'] as String? ?? '';
  }

  Txn _fromJson(Map<String, dynamic> json) {
    final incoming = json['incoming'] as bool? ?? false;
    final amountKobo = (json['amountKobo'] as num?)?.toInt() ?? 0;
    return Txn(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      amount: _formatAmount(amountKobo: amountKobo, incoming: incoming),
      date: _formatDate(json['createdAt'] as String?),
      type: _mapType(json['type'] as String?),
      status: _mapStatus(json['status'] as String?),
      incoming: incoming,
    );
  }

  /// e.g. amountKobo: 5000000, incoming: true → "+₦50,000.00" (ASCII '+');
  /// amountKobo: -2881200, incoming: false → "−₦28,812.00" (U+2212 minus,
  /// matching MockData.txns' existing fixtures).
  static String _formatAmount({required int amountKobo, required bool incoming}) {
    final absKobo = amountKobo.abs();
    final wholeNaira = absKobo ~/ 100;
    final koboRemainder = absKobo % 100;
    final wholeStr = wholeNaira.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    final sign = incoming ? '+' : '−';
    return '$sign₦$wholeStr.${koboRemainder.toString().padLeft(2, '0')}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// e.g. "2026-06-24T14:32:00.000Z" → "24 Jun 2026 · 14:32".
  static String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year} · $hh:$mm';
  }

  static TxnType _mapType(String? type) {
    return TxnType.values.firstWhere((t) => t.name == type, orElse: () => TxnType.fund);
  }

  /// Backend's unified lifecycle (pending/review/flagged/approved/rejected/
  /// completed/failed, registry.json "Transaction".status note) collapses
  /// client-side to this app's simplified completed/pending/failed view, per
  /// that same note: pending/review/flagged/approved are all still "in
  /// flight" → pending; rejected is a terminal non-success → failed.
  static TxnStatus _mapStatus(String? status) {
    return switch (status) {
      'completed' => TxnStatus.completed,
      'failed' || 'rejected' => TxnStatus.failed,
      _ => TxnStatus.pending,
    };
  }
}
