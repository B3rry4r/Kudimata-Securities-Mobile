// Kudimata Securities — Asset repository.
//
// Illustrates (and now implements) the convention every per-screen wiring
// agent should follow — see lib/data/api/README.md for the full writeup.
// GET /assets, /assets/trending and /assets/:ticker all return `Asset&Quote`
// per registry.json — static asset fields (ticker, name, assetClass,
// logoColor, about) merged with live quote fields (priceKobo,
// changeAbsKobo, changePct). [_fromJson] maps that merged shape onto the
// app's existing `Asset` model, formatting kobo/cent minor units into the
// app's preformatted display strings ("₦268.40"/"$228.10"), and changePct
// into "+1.94%"/"−0.62%" (U+2212 minus, matching MockData) — reused by every
// method below. If a future screen needs a field this mapping doesn't yet
// carry (e.g. `about`), extend [_fromJson] additively, don't fork it.
//
// Construct with the ONE shared ApiClient, reached via
// `AppScope.read(context).apiClient` (see main.dart / AppState.apiClient /
// lib/data/api/README.md) — never a second ApiClient instance:
//   final _repo = AssetRepository(AppScope.read(context).apiClient);
import 'package:flutter/widgets.dart' show Color;

import '../api/api_client.dart';
import '../models.dart';

class AssetRepository {
  const AssetRepository(this._client);
  final ApiClient _client;

  /// Mirrors MockData.trending. GET /assets/trending — a plain
  /// (non-paginated) `list<Asset&Quote>` per registry.json, so this parses
  /// `response.data` directly as a List, no PaginatedResponse wrapper.
  Future<List<Asset>> trending() async {
    final response = await _client.get('/assets/trending');
    final items = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map(_fromJson).toList();
  }

  /// Mirrors MockData.assetByTicker. GET /assets/:ticker.
  Future<Asset> byTicker(String ticker) async {
    final response = await _client.get('/assets/$ticker');
    return _fromJson(response.data as Map<String, dynamic>);
  }

  /// Asset-detail screen variant of [byTicker]: same `GET /assets/:ticker`
  /// call (still `Asset&Quote`), additionally carrying the real `about`
  /// field registry.json's Asset resource now has. `about` has no home on
  /// the shared [Asset] model (kept out of lib/data/models.dart per this
  /// wiring pass's scope), so it's returned alongside the Asset as a record
  /// rather than by extending that model. Replaces asset-detail's old
  /// hardcoded per-assetClass `_about()` copy.
  Future<(Asset asset, String? about)> byTickerWithAbout(String ticker) async {
    final response = await _client.get('/assets/$ticker');
    final json = response.data as Map<String, dynamic>;
    return (_fromJson(json), json['about'] as String?);
  }

  /// Mirrors MockData.allAssets filtered by class (used by the asset-list
  /// screen). GET /assets?assetClass= — a plain (non-paginated)
  /// `list<Asset&Quote>` per registry.json. [assetClass] narrows the
  /// universe server-side; pass null for the full/NGX-default universe (the
  /// screen itself already defaults a null launch param to AssetClass.ngx
  /// before calling this).
  Future<List<Asset>> byClass(AssetClass assetClass) async {
    final response = await _client.get(
      '/assets',
      queryParameters: {'assetClass': _classParam(assetClass)},
    );
    final items = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map(_fromJson).toList();
  }

  /// Mirrors MockData.allAssets / MockData.allAssets.where(...) (Markets
  /// screen's category tabs — All / NGX). Same GET /assets endpoint as
  /// [byClass], but [assetClass] is nullable so the "All" tab can omit the
  /// query param entirely and get the unfiltered universe — [byClass]'s
  /// non-null signature exists for the asset-list screen, which always
  /// narrows to a concrete class and never needs an unfiltered call.
  /// Also used by the search screen (`byAssetClass(null)`), which fetches
  /// the full NGX+US+ETF universe once and filters it locally by name/ticker
  /// — see Kudimata-Securities-Backend/.pipeline/fragments/search.json,
  /// which confirms search is local-filter-only, no server-side /search.
  Future<List<Asset>> byAssetClass(AssetClass? assetClass) async {
    final response = await _client.get(
      '/assets',
      queryParameters: assetClass == null
          ? null
          : {'assetClass': _classParam(assetClass)},
    );
    final items = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map(_fromJson).toList();
  }

  String _classParam(AssetClass c) => switch (c) {
    AssetClass.ngx => 'ngx',
    AssetClass.us => 'us',
    AssetClass.etf => 'etf',
  };

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
    final changeAbsKobo = (json['changeAbsKobo'] as num?)?.toInt();
    final changePct = (json['changePct'] as num?)?.toDouble() ?? 0.0;
    final trend = changePct < 0 ? Trend.loss : Trend.gain;
    final logoColorHex = json['logoColor'] as String?;
    return Asset(
      name: json['name'] as String? ?? '',
      ticker: json['ticker'] as String? ?? '',
      price: '$symbol${_formatKobo(priceKobo)}',
      change: '${_formatPct(changePct)}%',
      changeAbs: changeAbsKobo == null
          ? null
          : '${changeAbsKobo < 0 ? '−' : '+'}$symbol${_formatKobo(changeAbsKobo.abs())}',
      trend: trend,
      assetClass: assetClass,
      logoColor: _colorFromHex(logoColorHex),
      sector: json['sector'] as String?,
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
