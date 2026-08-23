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
  });

  final String name;
  final String ticker;
  final String price; // e.g. "₦268.40" / "$228.10"
  final String change; // e.g. "+1.94%" / "−0.62%"
  final Trend trend;
  final AssetClass assetClass;
  final Color? logoColor; // brand tint for the row logo circle (null → ink)

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
  });

  final Asset asset;
  final String units; // e.g. "120"
  final String marketValue; // e.g. "₦32,208.00"
  final String avgPrice; // e.g. "₦240.10"
  final String totalReturn; // e.g. "+₦3,396.00"
  final String returnPct; // e.g. "+11.78%"
  final Trend returnTrend;
}

enum TxnType { fund, withdraw, buy, sell, convert }

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
  });

  final String firstName;
  final String? middleName;
  final String lastName;
  final String email;
  final String phone;
  final String tier; // e.g. "Premium"
  final String memberSince; // e.g. "2023"

  /// Composed display string — split into firstName/middleName/lastName
  /// 2026-08-19 (BVN/NIN verification needs a real first/last to compare
  /// against the registry's own name fields), kept as one getter here so
  /// every existing greeting/label call site doesn't need rewriting.
  String get fullName => [firstName, middleName, lastName]
      .where((p) => p != null && p.trim().isNotEmpty)
      .join(' ');
}
