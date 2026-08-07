// Kudimata Securities — Watchlist repository.
//
// See lib/data/api/README.md for the shared convention. Construct with the
// ONE shared ApiClient, reached via `AppScope.read(context).apiClient` —
// never a second ApiClient instance:
//   final _repo = WatchlistRepository(AppScope.read(context).apiClient);
//
// registry.json's `WatchlistItem` resource:
//   GET    /watchlist-items          -> list<Asset&Quote>   (the investor's saved set, merged)
//   POST   /watchlist-items {ticker} -> WatchlistItem        (add)
//   DELETE /watchlist-items/:ticker  -> 204 No Content        (remove)
//
// The Asset&Quote -> Asset mapping (money/percent formatting) mirrors
// AssetRepository._fromJson (lib/data/repositories/asset_repository.dart) —
// duplicated here rather than shared, since neither repository exposes its
// private mapping helpers and this file's scope is the watchlist screen only.
import 'package:flutter/widgets.dart' show Color;

import '../api/api_client.dart';
import '../models.dart';

class WatchlistRepository {
  const WatchlistRepository(this._client);
  final ApiClient _client;

  /// Mirrors the watchlist screen's previous `MockData.allAssets.where(...)`
  /// resolution. GET /watchlist-items — a plain (non-paginated)
  /// `list<Asset&Quote>` per registry.json (already scoped server-side to
  /// the signed-in investor's saved tickers), so this parses `response.data`
  /// directly as a List, no PaginatedResponse wrapper.
  Future<List<Asset>> items() async {
    final response = await _client.get('/watchlist-items');
    final items = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map(_fromJson).toList();
  }

  /// POST /watchlist-items {ticker} -> WatchlistItem. Response body isn't
  /// needed by the screen (the ticker it sent is already known) — a
  /// non-2xx surfaces as [ApiException] via ApiClient's guard, which is all
  /// the caller needs to know the add failed.
  Future<void> add(String ticker) async {
    await _client.post('/watchlist-items', data: {'ticker': ticker});
  }

  /// DELETE /watchlist-items/:ticker -> 204 No Content.
  Future<void> remove(String ticker) async {
    await _client.delete('/watchlist-items/$ticker');
  }

  AssetClass _classFromJson(String? c) => switch (c) {
        'us' => AssetClass.us,
        'etf' => AssetClass.etf,
        _ => AssetClass.ngx,
      };

  /// Merged `Asset&Quote` mapping (registry.json): static Asset fields
  /// (ticker, name, assetClass, logoColor) plus live Quote fields
  /// (priceKobo, changeAbsKobo, changePct) formatted into this app's
  /// existing preformatted display strings — "₦268.40" / "$228.10" for
  /// price, "+1.94%" / "−0.62%" (U+2212 minus, matching MockData) for
  /// change. Kobo/cent integers are minor units of the asset's own
  /// currency (₦ for ngx, $ for us/etf), so 100 minor units == 1 major unit
  /// for both.
  Asset _fromJson(Map<String, dynamic> json) {
    final assetClass = _classFromJson(json['assetClass'] as String?);
    final symbol = assetClass == AssetClass.ngx ? '₦' : '\$';
    final priceKobo = (json['priceKobo'] as num?)?.toInt() ?? 0;
    final changePct = (json['changePct'] as num?)?.toDouble() ?? 0.0;
    final trend = changePct < 0 ? Trend.loss : Trend.gain;
    final logoColorHex = json['logoColor'] as String?;
    return Asset(
      name: json['name'] as String? ?? '',
      ticker: json['ticker'] as String? ?? '',
      price: '$symbol${_formatKobo(priceKobo)}',
      change: '${_formatPct(changePct)}%',
      trend: trend,
      assetClass: assetClass,
      logoColor: _colorFromHex(logoColorHex),
    );
  }

  /// Minor-unit integer (kobo/cents) -> "1,234.56" with thousands separators.
  String _formatKobo(int minorUnits) {
    final negative = minorUnits < 0;
    final abs = negative ? -minorUnits : minorUnits;
    final major = abs ~/ 100;
    final minor = (abs % 100).toString().padLeft(2, '0');
    final majorStr = major.toString();
    final buf = StringBuffer();
    for (var i = 0; i < majorStr.length; i++) {
      final posFromEnd = majorStr.length - i;
      buf.write(majorStr[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(',');
    }
    return '${negative ? '−' : ''}$buf.$minor';
  }

  /// Percentage -> "+1.94" / "−0.62" (U+2212 minus, 2dp, always signed).
  String _formatPct(double pct) {
    final sign = pct < 0 ? '−' : '+';
    return '$sign${pct.abs().toStringAsFixed(2)}';
  }

  Color? _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    final value = int.tryParse(h, radix: 16);
    return value == null ? null : Color(value);
  }
}
