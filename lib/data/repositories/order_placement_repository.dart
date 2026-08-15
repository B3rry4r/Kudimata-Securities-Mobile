// Kudimata Securities — Order placement repository (asset-detail Buy/Sell
// flows: trade_flows.dart's showBuyFlow/showSellFlow).
//
// NAMING NOTE (documented per this wiring pass's brief): a file named
// lib/data/repositories/orders_repository.dart already exists, built for the
// order-status screen. Despite the name, that file deliberately does NOT
// talk to registry.json's Order resource — its own header explains that
// `GET /orders` is staff-only, so it instead reads `GET /transactions` (the
// Transaction resource) and narrows to the buy/sell subset. This repository
// is the opposite job: placing a NEW order via `POST /orders`, the one
// investor-facing endpoint the Order resource actually exposes. Reusing the
// `OrdersRepository` name/class for that would misleadingly imply the two
// files talk to the same backend resource, so this is a distinct
// file/class rather than an additive method on the existing one.
//
// `POST /orders {ticker, side, units?, amountKobo?, orderType, limitPrice?}`
// -> Order, per registry.json's Order resource. Exactly one of
// units/amountKobo is required — the backend derives the other server-side
// (C-2 ruling) when amountKobo is supplied. The asset-detail Amount sheet
// has no limit-order selector, so [orderType] defaults to market and
// [limitPrice] stays unset from this screen.
//
// Non-custodial wallet redesign (backend supersedes.json S-11): a buy order
// no longer fills synchronously — POST /orders returns the Order with
// status 'awaiting_payment' plus a `checkoutUrl` the investor must complete
// a Flutterwave checkout on before it's sent to the broker. [placeOrder] and
// the new [getOrder] (GET /orders/:id, for trade_flows.dart's post-checkout
// polling) both return an [OrderResult] instead of discarding the response
// body — the caller needs `id`/`status`/`checkoutUrl` now, not just a
// success/failure signal. A sell is unaffected: it still fills immediately
// (status 'approved'/'pending'), `checkoutUrl` is simply absent.
//
// Construct with the ONE shared ApiClient, reached via
// `AppScope.read(context).apiClient` (see main.dart / AppState.apiClient /
// lib/data/api/README.md) — never a second ApiClient instance:
//   final _repo = OrderPlacementRepository(AppScope.read(context).apiClient);
import '../api/api_client.dart';

enum OrderSide { buy, sell }

enum OrderType { market, limit }

enum OrderStatus { awaitingPayment, pending, approved, rejected, expired }

/// POST /orders / GET /orders/:id response, narrowed to what the trade flow
/// needs. [checkoutUrl] is only ever present on the create response for a
/// fresh buy — GET /orders/:id never re-issues it (see backend Order.checkoutUrl
/// doc comment), so trade_flows.dart's polling sheet must have captured it
/// from [placeOrder]'s own result before it starts polling.
typedef OrderResult = ({String id, OrderStatus status, String? checkoutUrl});

class OrderPlacementRepository {
  const OrderPlacementRepository(this._client);
  final ApiClient _client;

  /// Places an order. Exactly one of [units]/[amountKobo] must be provided —
  /// mirrors the Amount sheet's naira/shares toggle (whichever the investor
  /// actually entered). Throws [ApiException] on failure (via
  /// [ApiClient.post]); never throws a raw DioException.
  Future<OrderResult> placeOrder({
    required String ticker,
    required OrderSide side,
    double? units,
    int? amountKobo,
    OrderType orderType = OrderType.market,
    int? limitPrice,
  }) async {
    assert(
      (units == null) != (amountKobo == null),
      'placeOrder: exactly one of units/amountKobo must be provided',
    );
    final data = <String, dynamic>{
      'ticker': ticker,
      'side': side == OrderSide.buy ? 'buy' : 'sell',
      'orderType': orderType == OrderType.market ? 'market' : 'limit',
    };
    if (units != null) data['units'] = units;
    if (amountKobo != null) data['amountKobo'] = amountKobo;
    if (limitPrice != null) data['limitPrice'] = limitPrice;
    final response = await _client.post('/orders', data: data);
    return _fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /orders/:id — polls a buy's payment/fill status after the investor
  /// completes (or abandons) the Flutterwave checkout opened from
  /// [placeOrder]'s `checkoutUrl`.
  Future<OrderResult> getOrder(String id) async {
    final response = await _client.get('/orders/$id');
    return _fromJson(response.data as Map<String, dynamic>);
  }

  OrderResult _fromJson(Map<String, dynamic> json) => (
        id: json['id'] as String? ?? '',
        status: switch (json['status'] as String?) {
          'awaiting_payment' => OrderStatus.awaitingPayment,
          'approved' => OrderStatus.approved,
          'rejected' => OrderStatus.rejected,
          'expired' => OrderStatus.expired,
          _ => OrderStatus.pending,
        },
        checkoutUrl: json['checkoutUrl'] as String?,
      );
}
