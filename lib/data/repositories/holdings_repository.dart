// Kudimata Securities — Holding/Portfolio repository.
//
// Backs the "portfolio" screen (lib/screens/portfolio/portfolio_screen.dart).
// Two backend resources per registry.json:
//   GET /holdings           PaginatedList<Holding>  — mirrors MockData.portfolioHoldings
//   GET /portfolio-summary  {totalValueKobo,allTimeReturnKobo,allTimeReturnPct,
//                            allocation,chartSeries} — mirrors the screen's
//                            BalancePanel + allocation donut (flagged
//                            STUB-portfolio-1/2 in .pipeline/fragments/portfolio.json
//                            as hardcoded literals before this wiring).
//
// GET /holdings' own shape (id/userId/ticker/units/avgPriceKobo/
// marketValueKobo/totalReturnKobo/returnPct/returnTrend — registry.json's
// Holding entity) does NOT embed the asset display fields the app's
// `Holding.asset` sub-object needs (name/price/change/trend/logoColor) — only
// a bare `ticker`. Those live on the separate Asset/Quote resource
// (`GET /assets` -> list<Asset&Quote>), so [holdings] additionally fetches
// that list once per call and joins it in-memory by ticker. This is a
// per-screen judgment call (see lib/data/api/README.md: "if a field is
// genuinely missing, that's a per-screen judgment call to flag, not silently
// invent") rather than a change to the shared Holding/Asset models.
//
// Construct with the ONE shared ApiClient:
//   final _repo = HoldingsRepository(AppScope.read(context).apiClient);
import 'package:flutter/widgets.dart' show Color;

import '../api/api_client.dart';
import '../api/paginated_response.dart';
import '../models.dart';

/// One slice of the portfolio allocation donut (e.g. {label: 'Nigerian
/// stocks', value: 85}). registry.json only names `allocation` inline on the
/// portfolio-summary response shape — it isn't a registered entity of its
/// own — so this small DTO is kept local to this repository rather than
/// added to lib/data/models.dart.
class PortfolioAllocationSlice {
  const PortfolioAllocationSlice({required this.label, required this.value});
  final String label;
  final double value;
}

/// Mirrors the portfolio screen's BalancePanel (total value + all-time
/// return + chart) and allocation donut — GET /portfolio-summary, kobo
/// fields formatted into the same preformatted display strings the screen's
/// stub literals used (see STUB-portfolio-1/2 in
/// .pipeline/fragments/portfolio.json).
class PortfolioSummary {
  const PortfolioSummary({
    required this.totalValue,
    required this.change,
    required this.changeTrend,
    required this.allocation,
    required this.chartSeries,
    required this.allTimeReturnAmount,
  });

  final String totalValue; // e.g. "₦2,418,650.00"
  final String change; // e.g. "+₦418,650.00 · 20.9% all-time"
  final Trend changeTrend;
  final List<PortfolioAllocationSlice> allocation;
  final List<double> chartSeries; // feeds KLineChart, same shape as MockData.homeSeries

  /// Amount-only all-time return, no percentage — e.g. "+₦12,540". Portfolio
  /// screen #s33's money card shows this alone in its "all time" pill,
  /// separately from the "N companies" pill; [change] (which bundles the %)
  /// stays as-is for Home's BalancePanel, its other real caller.
  final String allTimeReturnAmount;
}

class HoldingsRepository {
  const HoldingsRepository(this._client);
  final ApiClient _client;

  /// Mirrors MockData.portfolioHoldings. GET /holdings — a
  /// `PaginatedList<Holding>` per registry.json — joined against
  /// `GET /assets` (`list<Asset&Quote>`) to fill in each Holding's asset
  /// sub-fields. See file header for why the join is needed.
  Future<PaginatedResponse<Holding>> holdings({int page = 1, int pageSize = 20}) async {
    final holdingsResponse = await _client.get(
      '/holdings',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    final assetsByTicker = await _fetchAssetsByTicker();

    return PaginatedResponse<Holding>.fromJson(
      holdingsResponse.data as Map<String, dynamic>,
      (json) => _holdingFromJson(json, assetsByTicker),
    );
  }

  /// Mirrors the portfolio screen's aggregate header. GET /portfolio-summary.
  Future<PortfolioSummary> summary() async {
    final response = await _client.get('/portfolio-summary');
    final json = response.data as Map<String, dynamic>;

    final totalValueKobo = json['totalValueKobo'] as int? ?? 0;
    final allTimeReturnKobo = json['allTimeReturnKobo'] as int? ?? 0;
    final allTimeReturnPct = (json['allTimeReturnPct'] as num?)?.toDouble() ?? 0.0;
    final trend = allTimeReturnKobo < 0 ? Trend.loss : Trend.gain;

    final allocationJson = (json['allocation'] as List<dynamic>?) ?? const [];
    final chartSeriesJson = (json['chartSeries'] as List<dynamic>?) ?? const [];

    return PortfolioSummary(
      totalValue: _formatNaira(totalValueKobo),
      change: '${_formatSignedNaira(allTimeReturnKobo)} · '
          '${allTimeReturnPct.abs().toStringAsFixed(1)}% all-time',
      changeTrend: trend,
      allocation: allocationJson.map((e) {
        final m = e as Map<String, dynamic>;
        final label = (m['label'] ?? m['name'] ?? '') as String;
        final value = ((m['value'] ?? m['percentage'] ?? m['pct'] ?? 0) as num).toDouble();
        return PortfolioAllocationSlice(label: label, value: value);
      }).toList(),
      chartSeries: chartSeriesJson.map((e) => (e as num).toDouble()).toList(),
      allTimeReturnAmount: _formatSignedNaira(allTimeReturnKobo),
    );
  }

  Future<Map<String, Asset>> _fetchAssetsByTicker() async {
    final response = await _client.get('/assets');
    final items = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return {
      for (final json in items) (json['ticker'] as String? ?? ''): _assetFromJson(json),
    };
  }

  /// Mirrors MockData.holdingByTicker for a single position (used by the
  /// holding-detail screen). GET /holdings/:ticker returns the bare Holding
  /// position fields only — same shape as each item in [holdings]'s
  /// PaginatedList — it does not embed the asset display fields either, so
  /// this fetches GET /assets/:ticker (`Asset&Quote`, the same single-ticker
  /// endpoint AssetRepository.byTicker uses) and merges it in via
  /// [_mergeHolding] — same join rationale as [holdings]/
  /// [_fetchAssetsByTicker] above, just scoped to one ticker instead of the
  /// whole universe. Both requests are kicked off before either is awaited,
  /// so they run concurrently rather than serially.
  Future<Holding> byTicker(String ticker) async {
    final holdingResponseFuture = _client.get('/holdings/$ticker');
    final assetResponseFuture = _client.get('/assets/$ticker');
    final holdingResponse = await holdingResponseFuture;
    final assetResponse = await assetResponseFuture;
    final asset = _assetFromJson(assetResponse.data as Map<String, dynamic>);
    return _mergeHolding(holdingResponse.data as Map<String, dynamic>, asset);
  }

  Holding _holdingFromJson(Map<String, dynamic> json, Map<String, Asset> assetsByTicker) {
    final ticker = json['ticker'] as String? ?? '';
    final asset = assetsByTicker[ticker] ??
        Asset(name: ticker, ticker: ticker, price: '', change: '', trend: Trend.gain);
    return _mergeHolding(json, asset);
  }

  /// Shared position-field mapping for both [holdings] (list, joined by an
  /// assets-by-ticker map) and [byTicker] (single, joined against one
  /// GET /assets/:ticker fetch) — see both call sites for why the asset
  /// can't come from this endpoint's own JSON.
  Holding _mergeHolding(Map<String, dynamic> json, Asset asset) {
    final units = (json['units'] as num?) ?? 0;
    final avgPriceKobo = json['avgPriceKobo'] as int? ?? 0;
    final marketValueKobo = json['marketValueKobo'] as int? ?? 0;
    final totalReturnKobo = json['totalReturnKobo'] as int? ?? 0;
    final returnPct = (json['returnPct'] as num?)?.toDouble() ?? 0.0;
    final returnTrend = json['returnTrend'] == 'loss' ? Trend.loss : Trend.gain;

    return Holding(
      asset: asset,
      units: _formatUnits(units),
      marketValue: _formatNaira(marketValueKobo),
      avgPrice: _formatNaira(avgPriceKobo),
      totalReturn: _formatSignedNaira(totalReturnKobo),
      returnPct: _formatSignedPercent(returnPct),
      returnTrend: returnTrend,
      // Raw kobo alongside the formatted string above — the Portfolio
      // screen's by-sector allocation bar (ruling R-22) sums real position
      // values across holdings and can't do that from a preformatted "₦x"
      // string.
      marketValueKobo: marketValueKobo,
    );
  }

  Asset _assetFromJson(Map<String, dynamic> json) {
    final priceKobo = json['priceKobo'] as int? ?? 0;
    final changePct = (json['changePct'] as num?)?.toDouble() ?? 0.0;
    final trend = changePct < 0 ? Trend.loss : Trend.gain;
    final assetClass = switch (json['assetClass'] as String?) {
      'us' => AssetClass.us,
      'etf' => AssetClass.etf,
      _ => AssetClass.ngx,
    };
    return Asset(
      name: json['name'] as String? ?? '',
      ticker: json['ticker'] as String? ?? '',
      price: _formatNaira(priceKobo),
      change: _formatSignedPercent(changePct),
      trend: trend,
      assetClass: assetClass,
      logoColor: _colorFromHex(json['logoColor'] as String?),
      // Real NGX sector classification (backend's Asset.sector — see
      // models.dart's Asset.sector doc) — was dropped here even though
      // asset_repository.dart's own _assetFromJson already reads it; this
      // repository has its own copy (see file header) and needed the same
      // fix for the by-sector allocation bar (ruling R-22) to have anything
      // to group by.
      sector: json['sector'] as String?,
    );
  }

  // ── Formatting helpers — kobo/number → the app's preformatted display
  // strings (docs/BUILD_CONTRACT.md: "₦268.40", "+1.94%", "−0.62%" — loss
  // uses unicode minus U+2212). ─────────────────────────────────────────

  static String _formatNaira(int kobo) => '₦${_grouped(kobo.abs() / 100)}';

  static String _formatSignedNaira(int kobo) {
    final sign = kobo < 0 ? '−' : '+';
    return '$sign₦${_grouped(kobo.abs() / 100)}';
  }

  static String _formatSignedPercent(double pct) {
    final sign = pct < 0 ? '−' : '+';
    return '$sign${pct.abs().toStringAsFixed(2)}%';
  }

  static String _grouped(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final fromEnd = whole.length - i;
      if (i != 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(whole[i]);
    }
    return '${buf.toString()}.${parts[1]}';
  }

  static String _formatUnits(num units) =>
      units % 1 == 0 ? units.toInt().toString() : units.toString();

  static Color? _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var normalized = hex.startsWith('#') ? hex.substring(1) : hex;
    if (normalized.length == 6) normalized = 'FF$normalized';
    final value = int.tryParse(normalized, radix: 16);
    return value == null ? null : Color(value);
  }
}
