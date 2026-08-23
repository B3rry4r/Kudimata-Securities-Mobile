// Kudimata Securities — Price alert repository.
//
// See lib/data/api/README.md for the shared convention. Construct with the
// ONE shared ApiClient, reached via `AppScope.read(context).apiClient` —
// never a second ApiClient instance:
//   final _repo = PriceAlertRepository(AppScope.read(context).apiClient);
//
// registry.json's `PriceAlert` resource (Kudimata-Securities-Backend
// src/price-alerts/price-alerts.controller.ts, role: investor):
//   GET    /price-alerts      -> list<PriceAlert&Quote>  (the investor's alerts, merged with each ticker's live quote)
//   POST   /price-alerts      -> PriceAlert               (create; body: {ticker, thresholdPct?, thresholdPriceKobo?} — exactly one threshold field)
//   PATCH  /price-alerts/:id  -> PriceAlert                (body: {active?} — the ONLY field the backend accepts post-create; ticker/thresholds are immutable, delete + re-create to change them)
//   DELETE /price-alerts/:id  -> 204 No Content
//
// [PriceAlertWithQuote] extends [PriceAlert] (rather than duplicating its
// fields) so a `Map<String, PriceAlert>` built from either [list]'s or
// [create]'s response type-checks without extra mapping — the price-alerts
// screen keeps exactly one such map, refreshed from whichever call last
// touched a given ticker's alert.
import '../api/api_client.dart';

/// Wire shape for the PriceAlert resource (registry.json "PriceAlert").
/// Exactly one of [thresholdPct] / [thresholdPriceKobo] is non-null for any
/// alert the backend will accept — enforced server-side, not re-validated
/// here on read.
class PriceAlert {
  const PriceAlert({
    required this.id,
    required this.userId,
    required this.ticker,
    required this.thresholdPct,
    required this.thresholdPriceKobo,
    required this.active,
    required this.createdAt,
  });

  factory PriceAlert.fromJson(Map<String, dynamic> json) => PriceAlert(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        ticker: json['ticker'] as String? ?? '',
        thresholdPct: (json['thresholdPct'] as num?)?.toDouble(),
        thresholdPriceKobo: (json['thresholdPriceKobo'] as num?)?.toInt(),
        active: json['active'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  final String id;
  final String userId;
  final String ticker;
  final double? thresholdPct;
  final int? thresholdPriceKobo;
  final bool active;
  final DateTime createdAt;
}

/// GET /price-alerts response row: PriceAlert merged with its ticker's
/// current Quote (registry.json's `PriceAlert&Quote`) — same flattened-merge
/// convention `AssetWithQuote` documents in asset_repository.dart, and the
/// same pattern GET /watchlist-items already uses. Only the raw Quote
/// fields are kept here (no kobo->"₦x,xxx.xx" formatting like
/// WatchlistRepository/AssetRepository do for [Asset]) — the price-alerts
/// screen already has each watched asset's formatted price/change from
/// WatchlistRepository, so this type only needs to carry enough of the
/// quote to identify "as of" freshness if a future screen wants it.
class PriceAlertWithQuote extends PriceAlert {
  const PriceAlertWithQuote({
    required super.id,
    required super.userId,
    required super.ticker,
    required super.thresholdPct,
    required super.thresholdPriceKobo,
    required super.active,
    required super.createdAt,
    required this.priceKobo,
    required this.changeAbsKobo,
    required this.changePct,
    required this.asOf,
  });

  factory PriceAlertWithQuote.fromJson(Map<String, dynamic> json) => PriceAlertWithQuote(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        ticker: json['ticker'] as String? ?? '',
        thresholdPct: (json['thresholdPct'] as num?)?.toDouble(),
        thresholdPriceKobo: (json['thresholdPriceKobo'] as num?)?.toInt(),
        active: json['active'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        priceKobo: (json['priceKobo'] as num?)?.toInt() ?? 0,
        changeAbsKobo: (json['changeAbsKobo'] as num?)?.toInt() ?? 0,
        changePct: (json['changePct'] as num?)?.toDouble() ?? 0.0,
        asOf: json['asOf'] as String?,
      );

  final int priceKobo;
  final int changeAbsKobo;
  final double changePct;
  final String? asOf;
}

class PriceAlertRepository {
  const PriceAlertRepository(this._client);
  final ApiClient _client;

  /// GET /price-alerts — a plain (non-paginated) `list<PriceAlert&Quote>`
  /// per registry.json (already scoped server-side to the signed-in
  /// investor's own alerts), so this parses `response.data` directly as a
  /// List, no PaginatedResponse wrapper.
  Future<List<PriceAlertWithQuote>> list() async {
    final response = await _client.get('/price-alerts');
    final items = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map(PriceAlertWithQuote.fromJson).toList();
  }

  /// POST /price-alerts. Exactly one of [thresholdPct] / [thresholdPriceKobo]
  /// must be set — the same cross-field rule PriceAlertsService#create
  /// enforces server-side (400 VALIDATION_ERROR, surfaced here as
  /// [ApiException] if this assertion is somehow bypassed in release mode).
  /// Asserted here so a caller mistake fails loudly in debug builds instead
  /// of silently preferring one field over the other.
  Future<PriceAlert> create({
    required String ticker,
    double? thresholdPct,
    int? thresholdPriceKobo,
  }) async {
    assert(
      (thresholdPct != null) != (thresholdPriceKobo != null),
      'PriceAlertRepository.create: exactly one of thresholdPct/'
      'thresholdPriceKobo must be set (got thresholdPct=$thresholdPct, '
      'thresholdPriceKobo=$thresholdPriceKobo).',
    );
    final response = await _client.post('/price-alerts', data: {
      'ticker': ticker,
      'thresholdPct': ?thresholdPct,
      'thresholdPriceKobo': ?thresholdPriceKobo,
    });
    return PriceAlert.fromJson(response.data as Map<String, dynamic>);
  }

  /// PATCH /price-alerts/:id {active}. The only field worth patching
  /// post-creation — see this file's header.
  Future<PriceAlert> setActive(String id, bool active) async {
    final response = await _client.patch('/price-alerts/$id', data: {'active': active});
    return PriceAlert.fromJson(response.data as Map<String, dynamic>);
  }

  /// DELETE /price-alerts/:id -> 204 No Content.
  Future<void> remove(String id) async {
    await _client.delete('/price-alerts/$id');
  }
}
