// Kudimata Securities — immutable domain models. Prices/changes are PREFORMATTED
// strings exactly as the design (app-data.jsx) presents them: "₦268.40",
// "+1.94%", "−0.62%" (note: loss uses the unicode minus U+2212). Movement colour
// is carried by [Trend] on numbers only. Scope: NGX only.
import 'package:flutter/widgets.dart';
import 'mock.dart' show spark;

enum Trend { gain, loss }

/// Investable product universe. (No fixed income — by design.)
enum AssetClass { ngx, us, etf }

/// A tradable instrument. [price]/[change] are display strings, never numbers.
@immutable
class Asset {
  const Asset({
    required this.name,
    required this.ticker,
    required this.price,
    required this.change,
    required this.trend,
    this.assetClass = AssetClass.ngx,
    this.logoColor,
    this.changeAbs,
    this.sector,
  });

  final String name;
  final String ticker;
  final String price; // e.g. "₦268.40" / "$228.10"
  final String change; // e.g. "+1.94%" / "−0.62%"
  final Trend trend;
  final AssetClass assetClass;
  final Color? logoColor; // brand tint for the row logo circle (null → ink)

  /// Absolute price change, preformatted — e.g. "+₦5.10" / "−$1.20". Null
  /// when unknown (never fabricated). Backed by the real `changeAbsKobo`
  /// Quote field (registry.json) — see AssetRepository._fromJson.
  final String? changeAbs;

  /// NGX sector classification (e.g. "Banking", "Telecoms") — real data
  /// from the backend's Asset.sector field, null for ETFs / unclassified.
  final String? sector;

  /// Deterministic inline sparkline series (rises on gain, falls on loss).
  List<double> get sparkline => spark(trend == Trend.gain);
}

/// A position in the portfolio — derived from an [Asset] plus position figures.
@immutable
class Holding {
  const Holding({
    required this.asset,
    required this.units,
    required this.marketValue,
    required this.avgPrice,
    required this.totalReturn,
    required this.returnPct,
    required this.returnTrend,
    this.marketValueKobo,
  });

  final Asset asset;
  final String units; // e.g. "120"
  final String marketValue; // e.g. "₦32,208.00"
  final String avgPrice; // e.g. "₦240.10"
  final String totalReturn; // e.g. "+₦3,396.00"
  final String returnPct; // e.g. "+11.78%"
  final Trend returnTrend;

  /// Raw market value in kobo, alongside the preformatted [marketValue]
  /// string — needed to sum real position values across holdings (e.g. the
  /// Portfolio screen's by-sector allocation bar, ruling R-22) without
  /// re-parsing a currency string. Null for callers that only ever had the
  /// formatted string (e.g. `mock.dart`'s fixtures) — never fabricated.
  final int? marketValueKobo;
}

// 'dividend' added 2026-08-24 — matches the backend's TransactionType enum
// (a dividend payout credits the wallet via its own real Transaction row,
// see DividendsService). Canvas s40 gives it a distinct icon/tint (wallet ·
// sun) from a plain fund-in (arrowDown · indicator) — see wallet_screens.dart's
// `_TxnRow`.
enum TxnType { fund, withdraw, buy, sell, convert, dividend }

enum TxnStatus { completed, pending, failed }

/// A wallet / order ledger entry. [incoming] flips the amount sign affordance.
@immutable
class Txn {
  const Txn({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.type,
    required this.status,
    required this.incoming,
  });

  final String id;
  final String title;
  final String subtitle;
  final String amount; // preformatted, e.g. "+₦50,000.00"
  final String date; // e.g. "24 Jun 2026 · 14:32"
  final TxnType type;
  final TxnStatus status;
  final bool incoming;
}

/// Wire shape for the backend's Order resource (registry.json "Order" plus
/// the 2026-08-24 additions `reference`/`destinationBankAccountId` — see
/// Kudimata-Securities-Backend's src/common/types/order.types.ts). Returned
/// by `POST /orders` (OrderPlacementRepository.placeOrder) and
/// `PATCH /orders/:id/cancel` (OrdersRepository.cancel) — both parse it via
/// [Order.fromJson] rather than discarding the response body, so a real
/// order id/reference is available to the caller instead of being thrown
/// away.
///
/// [side]/[orderType]/[status] are kept as raw wire strings ('buy'/'sell',
/// 'market'/'limit', 'pending'/'approved'/'rejected'/'cancelled') rather
/// than new enums — `order_placement_repository.dart` already declares its
/// own `OrderSide`/`OrderType` enums for the *request* side of this same
/// resource, and this model only needs to round-trip the response, not
/// branch on it, in every screen that touches it today.
@immutable
class Order {
  const Order({
    required this.id,
    required this.ticker,
    required this.side,
    required this.units,
    required this.orderType,
    required this.status,
    required this.createdAt,
    this.amountKobo,
    this.limitPrice,
    this.price,
    this.value,
    this.reference,
    this.destinationBankAccountId,
  });

  final String id;
  final String ticker;
  final String side; // 'buy' | 'sell'
  final num units;
  final String orderType; // 'market' | 'limit'
  final String status; // 'pending' | 'approved' | 'rejected' | 'cancelled'
  final String createdAt; // ISO-8601 timestamp
  final int? amountKobo;
  final int? limitPrice;
  final int? price;
  final int? value;

  /// Short investor-facing reference (e.g. "KDM-SL-9021"), distinct from
  /// [id] (a UUID). Null only for an order created before this field
  /// existed (2026-08-24) — screens must degrade gracefully (omit the row),
  /// never render the literal string "null".
  final String? reference;

  /// Bank account a sell order's proceeds pay out to directly; null means
  /// proceeds go to the wallet (today's only real behavior for every order
  /// that predates this field, and for every buy order).
  final String? destinationBankAccountId;

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String? ?? '',
        ticker: json['ticker'] as String? ?? '',
        side: json['side'] as String? ?? 'buy',
        units: (json['units'] as num?) ?? 0,
        orderType: json['orderType'] as String? ?? 'market',
        status: json['status'] as String? ?? 'pending',
        createdAt: json['createdAt'] as String? ?? '',
        amountKobo: (json['amountKobo'] as num?)?.toInt(),
        limitPrice: (json['limitPrice'] as num?)?.toInt(),
        price: (json['price'] as num?)?.toInt(),
        value: (json['value'] as num?)?.toInt(),
        reference: json['reference'] as String?,
        destinationBankAccountId: json['destinationBankAccountId'] as String?,
      );
}

@immutable
class AppNotification {
  const AppNotification({
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    this.unread = false,
  });

  final String title;
  final String body;
  final String time; // e.g. "2h ago"
  final String icon; // KIcon name
  final bool unread;
}

/// One price level in an [OrderBook]'s bid or ask side — mirrors the
/// backend's `OrderBookLevel` (Kudimata-Securities-Backend's
/// src/common/types/asset.types.ts) 1:1. Deliberately carries raw kobo/unit
/// integers rather than a preformatted string — unlike [Asset]'s
/// price/change fields, this model follows contract_note_screen.dart's
/// convention (raw ints formatted by the screen), per SHARED-CHANGES.md S-7.
@immutable
class OrderBookLevel {
  const OrderBookLevel({required this.priceKobo, required this.units});

  final int priceKobo;
  final int units;

  factory OrderBookLevel.fromJson(Map<String, dynamic> json) => OrderBookLevel(
        priceKobo: (json['priceKobo'] as num?)?.toInt() ?? 0,
        units: (json['units'] as num?)?.toInt() ?? 0,
      );
}

/// Wire shape for the backend's OrderBook resource — BR-5's simulated depth
/// feed (`SimulatedNgxBroker#getOrderBook`, `GET /assets/:ticker/order-book`).
/// [bids] is sorted best-first (highest price first), [asks] is sorted
/// best-first (lowest price first); every bid price is strictly less than
/// every ask price. The backend always returns exactly five levels a side;
/// this model does not assume that (an empty list on either side is a valid,
/// renderable state — see asset_detail_screen.dart's `_OrderBookTab`).
///
/// NOTE: this depth feed is simulated, like every price this app already
/// shows (see SimulatedNgxBroker) — no user-facing "simulated" label is
/// added here, matching the rest of the app's honesty convention (no other
/// price/quote in this app carries one either).
@immutable
class OrderBook {
  const OrderBook({
    required this.ticker,
    required this.bids,
    required this.asks,
    required this.asOf,
  });

  final String ticker;
  final List<OrderBookLevel> bids;
  final List<OrderBookLevel> asks;
  final String asOf; // ISO-8601 timestamp

  factory OrderBook.fromJson(Map<String, dynamic> json) => OrderBook(
        ticker: json['ticker'] as String? ?? '',
        bids: ((json['bids'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(OrderBookLevel.fromJson)
            .toList(),
        asks: ((json['asks'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(OrderBookLevel.fromJson)
            .toList(),
        asOf: json['asOf'] as String? ?? '',
      );
}

@immutable
class UserProfile {
  const UserProfile({
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.tier,
    required this.memberSince,
    this.avatarKey,
  });

  final String firstName;
  final String? middleName;
  final String lastName;
  final String email;
  final String phone;
  final String tier; // e.g. "Premium"
  final String memberSince; // e.g. "2023"
  // See PersonalInfo.avatarKey (user_repository.dart) for the full doc —
  // same field, same 8-character set, null when unset.
  final String? avatarKey;

  /// Composed display string — split into firstName/middleName/lastName
  /// 2026-08-19 (BVN/NIN verification needs a real first/last to compare
  /// against the registry's own name fields), kept as one getter here so
  /// every existing greeting/label call site doesn't need rewriting.
  String get fullName => [firstName, middleName, lastName]
      .where((p) => p != null && p.trim().isNotEmpty)
      .join(' ');
}
