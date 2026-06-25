// Kudimata Securities — immutable domain models. Prices/changes are PREFORMATTED
// strings exactly as the design (app-data.jsx) presents them: "₦268.40",
// "+1.94%", "−0.62%" (note: loss uses the unicode minus U+2212). Movement colour
// is carried by [Trend] on numbers only. Scope: NGX, US, ETF — no fixed income.
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
    required this.fullName,
    required this.email,
    required this.phone,
    required this.tier,
    required this.memberSince,
  });

  final String fullName;
  final String email;
  final String phone;
  final String tier; // e.g. "Premium"
  final String memberSince; // e.g. "2023"
}
