// Kudimata Securities — canonical mock data. The NGX block is ported 1:1 from
// the design's app-data.jsx (spark / HOME_SERIES / MTNN_SERIES / HOLDINGS /
// TRENDING / NG_STOCKS / WATCHLIST). Extended with US stocks, ETFs, wallet
// transactions, notifications, derived holdings, and the demo user profile.
//
// SEAM: this is mock data only. Live quotes plug into a market-data feed; the
// ledger plugs into the sponsoring-broker order API + wallet processor.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';

/// Deterministic sparkline series — up trends rise, down trends fall, with a
/// little wobble. Ported verbatim from app-data.jsx `spark(up, n = 16)`.
List<double> spark(bool up, [int n = 16]) {
  final out = <double>[];
  for (var i = 0; i < n; i++) {
    out.add(
      math.sin(i * 0.7) * 2.4 + i * (up ? 0.55 : -0.55) + (i % 3) * 0.6,
    );
  }
  return out;
}

/// Brand logo tints for asset row circles. Most rows use ink; a few carry a
/// recognisable brand colour.
class _Logo {
  static const mtnn = Color(0xFFFFCB05); // MTN amber
  static const dangcem = Color(0xFF8B1E2D); // Dangote red
  static const gtco = Color(0xFFE35205); // GTCO orange
  static const zenith = Color(0xFFE2231A); // Zenith red
  static const apple = Color(0xFF1A1A1F); // near-ink
  static const tesla = Color(0xFFCC0000);
  static const nvidia = Color(0xFF76B900);
  static const microsoft = Color(0xFF0078D4);
  static const amazon = Color(0xFFFF9900);
  static const etf = Color(0xFF670099); // ETFs carry the brand purple
}

class MockData {
  MockData._();

  // ── Feature chart series (ported) ────────────────────────────────────────
  static const List<double> homeSeries = [
    12, 13, 12.4, 14, 15.2, 14.6, 16, 17.4, 16.8, 18.2, 19, 18.4, 20.1, 21.3, 20.8, 22.4,
  ];
  static const List<double> mtnnSeries = [
    240, 242, 239, 244, 248, 246, 251, 255, 252, 258, 262, 259, 264, 266, 263, 268.4,
  ];

  // ── NGX stocks (ported from NG_STOCKS) ───────────────────────────────────
  static const List<Asset> ngStocks = [
    Asset(name: 'MTN Nigeria', ticker: 'MTNN', price: '₦268.40', change: '+1.94%', trend: Trend.gain, assetClass: AssetClass.ngx, logoColor: _Logo.mtnn),
    Asset(name: 'Dangote Cement', ticker: 'DANGCEM', price: '₦485.00', change: '−0.62%', trend: Trend.loss, assetClass: AssetClass.ngx, logoColor: _Logo.dangcem),
    Asset(name: 'GTCO', ticker: 'GTCO', price: '₦48.20', change: '+3.10%', trend: Trend.gain, assetClass: AssetClass.ngx, logoColor: _Logo.gtco),
    Asset(name: 'Zenith Bank', ticker: 'ZENITHBANK', price: '₦39.85', change: '+0.50%', trend: Trend.gain, assetClass: AssetClass.ngx, logoColor: _Logo.zenith),
    Asset(name: 'Airtel Africa', ticker: 'AIRTELAFRI', price: '₦2,200.00', change: '−1.20%', trend: Trend.loss, assetClass: AssetClass.ngx),
    Asset(name: 'BUA Cement', ticker: 'BUACEMENT', price: '₦98.50', change: '+0.80%', trend: Trend.gain, assetClass: AssetClass.ngx),
    Asset(name: 'Nestlé Nigeria', ticker: 'NESTLE', price: '₦1,420.00', change: '−0.35%', trend: Trend.loss, assetClass: AssetClass.ngx),
    Asset(name: 'Seplat Energy', ticker: 'SEPLAT', price: '₦4,150.00', change: '+2.40%', trend: Trend.gain, assetClass: AssetClass.ngx),
    Asset(name: 'Stanbic IBTC', ticker: 'STANBIC', price: '₦64.00', change: '+1.10%', trend: Trend.gain, assetClass: AssetClass.ngx),
    Asset(name: 'United Bank for Africa', ticker: 'UBA', price: '₦34.50', change: '−0.90%', trend: Trend.loss, assetClass: AssetClass.ngx),
  ];

  // ── Trending (ported from TRENDING) ──────────────────────────────────────
  static const List<Asset> trending = [
    Asset(name: 'MTN Nigeria', ticker: 'MTNN', price: '₦268.40', change: '+1.94%', trend: Trend.gain, assetClass: AssetClass.ngx, logoColor: _Logo.mtnn),
    Asset(name: 'Dangote Cement', ticker: 'DANGCEM', price: '₦485.00', change: '−0.62%', trend: Trend.loss, assetClass: AssetClass.ngx, logoColor: _Logo.dangcem),
    Asset(name: 'GTCO', ticker: 'GTCO', price: '₦48.20', change: '+3.10%', trend: Trend.gain, assetClass: AssetClass.ngx, logoColor: _Logo.gtco),
    Asset(name: 'Zenith Bank', ticker: 'ZENITHBANK', price: '₦39.85', change: '+0.50%', trend: Trend.gain, assetClass: AssetClass.ngx, logoColor: _Logo.zenith),
    Asset(name: 'Airtel Africa', ticker: 'AIRTELAFRI', price: '₦2,200.00', change: '−1.20%', trend: Trend.loss, assetClass: AssetClass.ngx),
  ];

  // ── US stocks (extension — realistic $ prices) ───────────────────────────
  static const List<Asset> usStocks = [
    Asset(name: 'Apple', ticker: 'AAPL', price: '\$228.10', change: '+0.90%', trend: Trend.gain, assetClass: AssetClass.us, logoColor: _Logo.apple),
    Asset(name: 'Tesla', ticker: 'TSLA', price: '\$410.30', change: '+2.20%', trend: Trend.gain, assetClass: AssetClass.us, logoColor: _Logo.tesla),
    Asset(name: 'NVIDIA', ticker: 'NVDA', price: '\$134.70', change: '−1.45%', trend: Trend.loss, assetClass: AssetClass.us, logoColor: _Logo.nvidia),
    Asset(name: 'Microsoft', ticker: 'MSFT', price: '\$429.80', change: '+0.55%', trend: Trend.gain, assetClass: AssetClass.us, logoColor: _Logo.microsoft),
    Asset(name: 'Amazon', ticker: 'AMZN', price: '\$201.45', change: '−0.30%', trend: Trend.loss, assetClass: AssetClass.us, logoColor: _Logo.amazon),
  ];

  // ── ETFs (extension) ─────────────────────────────────────────────────────
  static const List<Asset> etfs = [
    Asset(name: 'Vanguard S&P 500 ETF', ticker: 'VOO', price: '\$542.60', change: '+0.48%', trend: Trend.gain, assetClass: AssetClass.etf, logoColor: _Logo.etf),
    Asset(name: 'SPDR S&P 500 ETF', ticker: 'SPY', price: '\$590.20', change: '+0.51%', trend: Trend.gain, assetClass: AssetClass.etf, logoColor: _Logo.etf),
    Asset(name: 'Invesco QQQ Trust', ticker: 'QQQ', price: '\$508.90', change: '−0.72%', trend: Trend.loss, assetClass: AssetClass.etf, logoColor: _Logo.etf),
    Asset(name: 'Vanguard Total Stock Market', ticker: 'VTI', price: '\$295.30', change: '+0.40%', trend: Trend.gain, assetClass: AssetClass.etf, logoColor: _Logo.etf),
  ];

  // ── Watchlist (ported from WATCHLIST) ────────────────────────────────────
  static const List<Asset> watchlist = [
    Asset(name: 'MTN Nigeria', ticker: 'MTNN', price: '₦268.40', change: '+1.94%', trend: Trend.gain, assetClass: AssetClass.ngx, logoColor: _Logo.mtnn),
    Asset(name: 'Apple', ticker: 'AAPL', price: '\$228.10', change: '+0.90%', trend: Trend.gain, assetClass: AssetClass.us, logoColor: _Logo.apple),
    Asset(name: 'Tesla', ticker: 'TSLA', price: '\$410.30', change: '+2.20%', trend: Trend.gain, assetClass: AssetClass.us, logoColor: _Logo.tesla),
    Asset(name: 'Dangote Cement', ticker: 'DANGCEM', price: '₦485.00', change: '−0.62%', trend: Trend.loss, assetClass: AssetClass.ngx, logoColor: _Logo.dangcem),
  ];

  /// Every quotable asset across all classes (search / asset lookup).
  static List<Asset> get allAssets => [...ngStocks, ...usStocks, ...etfs];

  /// Lookup an asset by ticker (falls back to the first NGX name).
  static Asset? assetByTicker(String ticker) {
    for (final a in allAssets) {
      if (a.ticker == ticker) return a;
    }
    return null;
  }

  // ── Holdings (ported HOLDINGS → derived Holding records) ──────────────────
  static const Asset _hMtnn = Asset(name: 'MTN Nigeria', ticker: 'MTNN', price: '₦268.40', change: '+1.94%', trend: Trend.gain, assetClass: AssetClass.ngx, logoColor: _Logo.mtnn);
  static const Asset _hDang = Asset(name: 'Dangote Cement', ticker: 'DANGCEM', price: '₦485.00', change: '−0.62%', trend: Trend.loss, assetClass: AssetClass.ngx, logoColor: _Logo.dangcem);
  static const Asset _hAapl = Asset(name: 'Apple', ticker: 'AAPL', price: '\$228.10', change: '+0.90%', trend: Trend.gain, assetClass: AssetClass.us, logoColor: _Logo.apple);

  static const List<Asset> holdings = [_hMtnn, _hDang, _hAapl];

  static const List<Holding> portfolioHoldings = [
    Holding(
      asset: _hMtnn,
      units: '120',
      marketValue: '₦32,208.00',
      avgPrice: '₦240.10',
      totalReturn: '+₦3,396.00',
      returnPct: '+11.78%',
      returnTrend: Trend.gain,
    ),
    Holding(
      asset: _hDang,
      units: '40',
      marketValue: '₦19,400.00',
      avgPrice: '₦498.50',
      totalReturn: '−₦540.00',
      returnPct: '−2.71%',
      returnTrend: Trend.loss,
    ),
    Holding(
      asset: _hAapl,
      units: '15',
      marketValue: '\$3,421.50',
      avgPrice: '\$208.00',
      totalReturn: '+\$301.50',
      returnPct: '+9.66%',
      returnTrend: Trend.gain,
    ),
  ];

  static Holding? holdingByTicker(String ticker) {
    for (final h in portfolioHoldings) {
      if (h.asset.ticker == ticker) return h;
    }
    return null;
  }

  // ── Wallet / order transactions ──────────────────────────────────────────
  static const List<Txn> txns = [
    Txn(id: 'TX1042', title: 'Wallet funding', subtitle: 'Bank transfer · GTBank', amount: '+₦50,000.00', date: '24 Jun 2026 · 14:32', type: TxnType.fund, status: TxnStatus.completed, incoming: true),
    Txn(id: 'TX1041', title: 'Buy MTNN', subtitle: '120 units @ ₦240.10', amount: '−₦28,812.00', date: '24 Jun 2026 · 14:35', type: TxnType.buy, status: TxnStatus.completed, incoming: false),
    Txn(id: 'TX1040', title: 'Buy AAPL', subtitle: '15 units @ \$208.00', amount: '−\$3,120.00', date: '20 Jun 2026 · 16:02', type: TxnType.buy, status: TxnStatus.completed, incoming: false),
    Txn(id: 'TX1039', title: 'Currency conversion', subtitle: '₦ → \$ · rate 1,580.00', amount: '−₦4,932,000.00', date: '20 Jun 2026 · 15:58', type: TxnType.convert, status: TxnStatus.completed, incoming: false),
    Txn(id: 'TX1038', title: 'Sell DANGCEM', subtitle: '10 units @ ₦485.00', amount: '+₦4,850.00', date: '18 Jun 2026 · 11:14', type: TxnType.sell, status: TxnStatus.completed, incoming: true),
    Txn(id: 'TX1037', title: 'Withdrawal', subtitle: 'To GTBank ····4821', amount: '−₦25,000.00', date: '16 Jun 2026 · 09:40', type: TxnType.withdraw, status: TxnStatus.pending, incoming: false),
    Txn(id: 'TX1036', title: 'Buy TSLA', subtitle: '5 units @ \$410.30', amount: '−\$2,051.50', date: '15 Jun 2026 · 18:21', type: TxnType.buy, status: TxnStatus.failed, incoming: false),
    Txn(id: 'TX1035', title: 'Wallet funding', subtitle: 'Card · Visa ····1199', amount: '+₦100,000.00', date: '12 Jun 2026 · 08:05', type: TxnType.fund, status: TxnStatus.completed, incoming: true),
  ];

  static Txn? txnById(String id) {
    for (final t in txns) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ── Notifications ────────────────────────────────────────────────────────
  static const List<AppNotification> notifications = [
    AppNotification(title: 'Order filled', body: 'Your buy order for 120 MTNN was filled at ₦240.10.', time: '2h ago', icon: 'check', unread: true),
    AppNotification(title: 'Price alert', body: 'TSLA is up 2.20% today, now at \$410.30.', time: '5h ago', icon: 'markets', unread: true),
    AppNotification(title: 'Wallet funded', body: 'We received ₦50,000.00 via bank transfer.', time: '1d ago', icon: 'wallet'),
    AppNotification(title: 'Withdrawal pending', body: 'Your ₦25,000.00 withdrawal is being processed.', time: '2d ago', icon: 'transfer'),
    AppNotification(title: 'Welcome to Kudimata', body: 'Your account is verified. Start investing in NGX, US stocks and ETFs.', time: '5d ago', icon: 'bell'),
  ];

  // ── Demo user ────────────────────────────────────────────────────────────
  static const UserProfile user = UserProfile(
    fullName: 'Ada Okeke',
    email: 'ada.okeke@email.com',
    phone: '+234 803 555 0192',
    tier: 'Premium',
    memberSince: '2023',
  );
}
