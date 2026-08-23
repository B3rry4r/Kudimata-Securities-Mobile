// Kudimata Securities — Orders repository (order-status screen).
//
// ENDPOINT NOTE: the task brief for this screen pointed at registry.json's
// Order resource (`GET /orders?page&pageSize&status`), but registry.json
// itself shows that endpoint's `roles` are staff-only — support,
// kyc_reviewer, compliance_officer, super_admin. An investor CAN call
// `POST /orders` (roles: ["investor"], to place a trade) but there is no
// investor-facing "list my orders" route on the Order resource; `GET /orders`
// is an internal admin/compliance order queue, not this screen's data
// source.
//
// The Transaction resource is the correct source: its own `sourceScreens`
// entry in registry.json explicitly credits this screen as
// "order-status(buy/sell subset)", `GET /transactions` IS investor-scoped,
// and Transaction.status carries the note "Investor-facing UI may collapse
// this to a simplified completed/pending/failed view client-side" — exactly
// the TxnStatus enum this screen already renders via KBadge. So this
// repository (kept named/shaped around "orders" to mirror the
// `MockData.txns`-filtered accessor it replaces — see
// lib/screens/portfolio/order_status_screen.dart) fetches `GET /transactions`
// and narrows the result to the buy/sell subset, matching the screen's
// original mock filter (`MockData.txns.where((t) => t.type == TxnType.buy ||
// t.type == TxnType.sell)`).
//
// Transaction.title/subtitle already arrive preformatted from the backend
// (e.g. "Buy MTNN" / "120 units @ ₦240.10") — no client-side string
// construction needed for those. `amountKobo` (signed integer kobo) and
// `createdAt` (ISO-8601) still need client-side formatting into this app's
// existing preformatted display strings ("−₦28,812.00" / "24 Jun 2026 ·
// 14:35"), matching MockData's fixtures exactly.
//
// Construct with the ONE shared ApiClient, reached via
// `AppScope.read(context).apiClient` (see main.dart / AppState.apiClient /
// lib/data/api/README.md) — never a second ApiClient instance:
//   final _repo = OrdersRepository(AppScope.read(context).apiClient);
//
// NAMING NOTE: this class does NOT place orders — see
// order_placement_repository.dart's OrderPlacementRepository for `POST
// /orders` (asset-detail's Buy/Sell flows). Kept as a separate file/class so
// the name doesn't imply this one talks to the Order resource, which it
// deliberately does not (see above).
import '../api/api_client.dart';
import '../api/paginated_response.dart';
import '../models.dart';

class OrdersRepository {
  const OrdersRepository(this._client);
  final ApiClient _client;

  /// Added 2026-08-24 alongside the backend's new `PATCH /orders/:id/cancel`
  /// (see BACKEND_GAPS.md §6/§14 — previously "no cancel endpoint exists
  /// anywhere in this backend"). Added here — despite this class's header
  /// comment explaining it otherwise deliberately avoids the Order resource
  /// — because `OrderStatusScreen` already constructs exactly this
  /// repository and nothing else; cancel is the one Order-resource route an
  /// investor can call directly, given an id they already hold.
  ///
  /// Investor-only, own-order-only, and only while the order is still
  /// `pending` server-side — cancelling an order that has since filled
  /// (or was already rejected/cancelled) 422s with
  /// `ORDER_NOT_CANCELLABLE`, which arrives as [ApiException.message] and
  /// is NOT swallowed here; the caller must catch it and show the real
  /// message rather than pretending the cancel succeeded. Returns the
  /// updated [Order] (status now `cancelled`) on success.
  ///
  /// CALLER NOTE (real, verified gap — see this repository's own header
  /// comment): `OrdersRepository.orders()` above sources its list from
  /// `GET /transactions`, whose wire `Transaction` shape carries no
  /// `orderId` (confirmed against
  /// Kudimata-Securities-Backend/src/common/types/transaction.types.ts and
  /// prisma/schema.prisma's `Transaction.orderId` comment: "NOT a
  /// registry.json wire field... Internal linkage only"). A `Txn.id` from
  /// that list is a Transaction id, not an Order id, so it cannot be passed
  /// to this method — doing so would 404 against the Order table on every
  /// call, not genuinely cancel anything. This method is real and correct;
  /// what's still missing is a way for `OrderStatusScreen` to obtain a real
  /// Order id per row (either an investor-scoped `GET /orders` list, or
  /// `orderId` added to the Transaction wire shape) — see
  /// order_status_screen.dart's own comment on the (still un-added)
  /// "Cancel the unfilled N order" button.
  Future<Order> cancel(String orderId) async {
    final response = await _client.patch('/orders/$orderId/cancel');
    return Order.fromJson(response.data as Map<String, dynamic>);
  }

  /// Mirrors the order-status screen's old
  /// `MockData.txns.where((t) => t.type == TxnType.buy || t.type ==
  /// TxnType.sell)` filter. `GET /transactions` is a
  /// `PaginatedList<Transaction>` per registry.json; this screen's fragment
  /// declares `"pagination": "none"` (no load-more UI), so a single generous
  /// page is fetched and narrowed client-side to the buy/sell subset — the
  /// backend's `type` query filter takes one value, not a list, so
  /// client-side filtering (same as the original mock) avoids two round
  /// trips for one screen.
  Future<List<Txn>> orders() async {
    final response = await _client.get(
      '/transactions',
      queryParameters: const {'page': 1, 'pageSize': 100},
    );
    final page = PaginatedResponse<Txn>.fromJson(
      response.data as Map<String, dynamic>,
      _fromJson,
    );
    return page.data
        .where((t) => t.type == TxnType.buy || t.type == TxnType.sell)
        .toList();
  }

  Txn _fromJson(Map<String, dynamic> json) {
    final amountKobo = (json['amountKobo'] as num?)?.toInt() ?? 0;
    final incoming = json['incoming'] as bool? ?? amountKobo >= 0;
    return Txn(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      amount: _formatAmount(amountKobo, incoming),
      date: _formatDate(json['createdAt'] as String?),
      type: _typeFromJson(json['type'] as String?),
      status: _statusFromJson(json['status'] as String?),
      incoming: incoming,
    );
  }

  TxnType _typeFromJson(String? t) => switch (t) {
        'fund' => TxnType.fund,
        'withdraw' => TxnType.withdraw,
        'sell' => TxnType.sell,
        'convert' => TxnType.convert,
        _ => TxnType.buy,
      };

  /// Collapses the backend's 7-state Transaction lifecycle
  /// (pending/review/flagged/approved/rejected/completed/failed) down to the
  /// 3-state investor-facing view (per registry.json's own note on
  /// Transaction.status): completed -> completed; rejected/failed ->
  /// failed (terminal negative); everything else (pending/review/flagged/
  /// approved) is still in flight -> pending.
  TxnStatus _statusFromJson(String? s) => switch (s) {
        'completed' => TxnStatus.completed,
        'rejected' || 'failed' => TxnStatus.failed,
        _ => TxnStatus.pending,
      };

  /// Signed minor-unit integer (kobo) -> "+₦1,234.56" / "−₦1,234.56"
  /// (U+2212 minus, matching MockData). [incoming] decides the sign shown,
  /// same convention as the mock fixtures (a positive/incoming order like a
  /// sell shows "+", a negative/outgoing order like a buy shows "−").
  String _formatAmount(int amountKobo, bool incoming) {
    final abs = amountKobo < 0 ? -amountKobo : amountKobo;
    final major = abs ~/ 100;
    final minor = (abs % 100).toString().padLeft(2, '0');
    final majorStr = major.toString();
    final buf = StringBuffer();
    for (var i = 0; i < majorStr.length; i++) {
      final posFromEnd = majorStr.length - i;
      buf.write(majorStr[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(',');
    }
    return '${incoming ? '+' : '−'}₦$buf.$minor';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// ISO-8601 timestamp -> "24 Jun 2026 · 14:35" (matching MockData).
  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final day = dt.day.toString();
    final month = _months[dt.month - 1];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$day $month ${dt.year} · $hh:$mm';
  }
}
