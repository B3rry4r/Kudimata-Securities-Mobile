// Kudimata Securities — Orders repository (order-status screen + holding
// detail's "Your orders in {ticker}" list).
//
// 2026-08-24 rewrite: this repository used to source from `GET
// /transactions` because, at the time it was written, `GET /orders` was
// staff-only and no buy/sell Transaction row was ever actually created by
// TransactionsService — meaning the Orders screen was permanently empty
// against the real backend regardless of which resource it read from. Both
// of those are now fixed: `GET /orders` accepts the `investor` role and
// scopes to the caller's own orders (OrdersController.findAll,
// 2026-08-24), and real Order rows exist for real (every `POST /orders`
// placement creates one — that's the resource orders were always placed
// against). This repository now reads the real Order resource directly —
// no more Transaction detour, no more collapsed 3-state view.
//
// Construct with the ONE shared ApiClient, reached via
// `AppScope.read(context).apiClient` (see main.dart / AppState.apiClient /
// lib/data/api/README.md) — never a second ApiClient instance:
//   final _repo = OrdersRepository(AppScope.read(context).apiClient);
//
// NAMING NOTE: this class does NOT place orders — see
// order_placement_repository.dart's OrderPlacementRepository for `POST
// /orders` (asset-detail's Buy/Sell flows).
import '../api/api_client.dart';
import '../api/paginated_response.dart';
import '../models.dart';

class OrdersRepository {
  const OrdersRepository(this._client);
  final ApiClient _client;

  /// GET /orders?page&pageSize (role: investor — scoped server-side to the
  /// caller's own orders), newest first. A single generous page (matching
  /// this app's established "no load-more UI on this screen" convention,
  /// same as the old Transaction-based `orders()` this replaces).
  Future<List<Order>> myOrders({int pageSize = 100}) async {
    final response = await _client.get(
      '/orders',
      queryParameters: {'page': 1, 'pageSize': pageSize},
    );
    final page = PaginatedResponse<Order>.fromJson(
      response.data as Map<String, dynamic>,
      Order.fromJson,
    );
    return page.data;
  }

  /// Investor-only, own-order-only, and only while the order is still
  /// `pending` server-side — cancelling an order that has since filled
  /// (or was already rejected/cancelled) 422s with
  /// `ORDER_NOT_CANCELLABLE`, which arrives as [ApiException.message] and
  /// is NOT swallowed here; the caller must catch it and show the real
  /// message rather than pretending the cancel succeeded. Returns the
  /// updated [Order] (status now `cancelled`) on success.
  Future<Order> cancel(String orderId) async {
    final response = await _client.patch('/orders/$orderId/cancel');
    return Order.fromJson(response.data as Map<String, dynamic>);
  }
}
