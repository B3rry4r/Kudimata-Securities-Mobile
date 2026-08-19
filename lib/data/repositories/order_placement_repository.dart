// Kudimata Invest — Order placement repository (asset-detail Buy/Sell
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
// The Order resource shape itself isn't threaded into a domain model here —
// this call only needs to succeed or throw; the caller already knows the
// ticker/side/amount it just submitted and renders the existing success UI
// from that, not from the response body. Kudimata holds client funds in a
// custodial wallet (see wallet_repository.dart), so a buy fills against that
// balance synchronously — no per-order checkout/payment step here.
//
// Construct with the ONE shared ApiClient, reached via
// `AppScope.read(context).apiClient` (see main.dart / AppState.apiClient /
// lib/data/api/README.md) — never a second ApiClient instance:
//   final _repo = OrderPlacementRepository(AppScope.read(context).apiClient);
import '../api/api_client.dart';

enum OrderSide { buy, sell }

enum OrderType { market, limit }

class OrderPlacementRepository {
  const OrderPlacementRepository(this._client);
  final ApiClient _client;

  /// Places an order. Exactly one of [units]/[amountKobo] must be provided —
  /// mirrors the Amount sheet's naira/shares toggle (whichever the investor
  /// actually entered). Throws [ApiException] on failure (via
  /// [ApiClient.post]); never throws a raw DioException.
  Future<void> placeOrder({
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
    await _client.post('/orders', data: data);
  }
}
