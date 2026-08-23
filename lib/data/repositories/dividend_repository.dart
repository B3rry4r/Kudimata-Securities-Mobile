// Kudimata Securities — Dividend + e-dividend-mandate repository.
//
// See lib/data/api/README.md for the shared convention. Construct with the
// ONE shared ApiClient, reached via `AppScope.read(context).apiClient` —
// never a second ApiClient instance:
//   final _repo = DividendRepository(AppScope.read(context).apiClient);
//
// Backs the Dividends & e-mandate screen (lib/screens/corporate_actions/
// dividends_screen.dart) — replaces the static `kDividendsPaidThisYearLabel`
// / `kMockDividendHistory` / "Sign the e-dividend mandate → not available
// yet" fixtures in corporate_actions_data.dart with real reads/writes.
// Backing resources (Kudimata-Securities-Backend src/common/types/
// dividend.types.ts, src/dividends/dividends.controller.ts):
//   GET  /dividends?page&pageSize   -> PaginatedList<Dividend>  (own records only)
//   GET  /dividends/summary         -> DividendSummary
//   POST /e-dividend-mandate/sign   {} -> EDividendMandate
//   GET  /e-dividend-mandate/me     -> EDividendMandate
//
// `Dividend`/`EDividendMandate`/`DividendSummary` are not in
// lib/data/models.dart — out of scope for a per-screen wiring agent to add
// there (README.md) — so they live here, this repository being their only
// consumer. Field names/types mirror the backend's wire shapes exactly.
//
// IMPORTANT — `DividendSummary.unclaimedKobo` is genuinely `null` from the
// backend: there is no real share-registrar integration to source a figure
// for dividends declared before any e-mandate existed (see
// dividend.types.ts's own doc comment on this field). Never fabricate a
// number for it — render the null as-is and let the screen decide how to
// show "unknown" honestly.
//
// Every `Dividend` row this backend can produce is a CASH payout
// (grossKobo/whtKobo/netKobo, always crediting the wallet) — there is no
// scrip/bonus-share dividend concept in the Prisma model, unlike the old
// static fixture's "Zenith Bank · scrip / 40 bonus shares" entry. That
// fixture entry has no real backend counterpart and is not reproduced here.
import '../api/api_client.dart';
import '../api/paginated_response.dart';

class DividendRepository {
  const DividendRepository(this._client);
  final ApiClient _client;

  /// GET /dividends?page&pageSize — `PaginatedList<Dividend>`, sorted
  /// `payDate:desc` server-side (dividends.service.ts findAll()).
  Future<PaginatedResponse<Dividend>> history({int page = 1, int pageSize = 20}) async {
    final response = await _client.get(
      '/dividends',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return PaginatedResponse<Dividend>.fromJson(
      response.data as Map<String, dynamic>,
      Dividend.fromJson,
    );
  }

  /// GET /dividends/summary — bare (non-paginated) `DividendSummary` object.
  Future<DividendSummary> summary() async {
    final response = await _client.get('/dividends/summary');
    return DividendSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /e-dividend-mandate/sign — empty body (a single attestation
  /// action; the investor's identity comes from the JWT, not the request).
  Future<EDividendMandate> signMandate() async {
    final response = await _client.post('/e-dividend-mandate/sign', data: const <String, dynamic>{});
    return EDividendMandate.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /e-dividend-mandate/me. The backend returns a synthetic
  /// `{status: 'unsigned', signedAt: null}` (not a 404) when the investor
  /// has never signed — a normal, expected state, not an error.
  Future<EDividendMandate> mandate() async {
    final response = await _client.get('/e-dividend-mandate/me');
    return EDividendMandate.fromJson(response.data as Map<String, dynamic>);
  }
}

/// One dividend PAYOUT row to this investor (dividend.types.ts `Dividend`).
class Dividend {
  const Dividend({
    required this.id,
    required this.ticker,
    required this.grossKobo,
    required this.whtKobo,
    required this.netKobo,
    required this.payDate,
    required this.transactionId,
  });

  final String id;
  final String ticker;
  final int grossKobo;
  final int whtKobo;
  final int netKobo;
  final DateTime payDate;

  /// The wallet-crediting Transaction row this payout created — null only
  /// if that link is somehow missing.
  final String? transactionId;

  factory Dividend.fromJson(Map<String, dynamic> json) => Dividend(
        id: json['id'] as String? ?? '',
        ticker: json['ticker'] as String? ?? '',
        grossKobo: (json['grossKobo'] as num?)?.toInt() ?? 0,
        whtKobo: (json['whtKobo'] as num?)?.toInt() ?? 0,
        netKobo: (json['netKobo'] as num?)?.toInt() ?? 0,
        payDate: DateTime.tryParse(json['payDate'] as String? ?? '') ?? DateTime(1970),
        transactionId: json['transactionId'] as String?,
      );
}

/// EDividendMandate.status (dividend.types.ts / prisma EDividendMandateStatus
/// enum) — 'signed' here is investor-attested only, not registrar-confirmed.
enum EDividendMandateStatus { unsigned, pending, signed }

EDividendMandateStatus _mandateStatusFromJson(String? status) => switch (status) {
      'signed' => EDividendMandateStatus.signed,
      'pending' => EDividendMandateStatus.pending,
      _ => EDividendMandateStatus.unsigned,
    };

/// EDividendMandate (dividend.types.ts) — one row per investor.
class EDividendMandate {
  const EDividendMandate({required this.status, required this.signedAt});

  final EDividendMandateStatus status;
  final DateTime? signedAt;

  bool get isSigned => status == EDividendMandateStatus.signed;

  factory EDividendMandate.fromJson(Map<String, dynamic> json) => EDividendMandate(
        status: _mandateStatusFromJson(json['status'] as String?),
        signedAt: json['signedAt'] == null
            ? null
            : DateTime.tryParse(json['signedAt'] as String),
      );
}

/// DividendSummary (dividend.types.ts) — GET /dividends/summary response.
class DividendSummary {
  const DividendSummary({
    required this.year,
    required this.paidThisYearKobo,
    required this.unclaimedKobo,
  });

  final int year;
  final int paidThisYearKobo;

  /// Deliberately nullable — see this file's header comment. Never
  /// fabricate a fallback number when this is null.
  final int? unclaimedKobo;

  factory DividendSummary.fromJson(Map<String, dynamic> json) => DividendSummary(
        year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
        paidThisYearKobo: (json['paidThisYearKobo'] as num?)?.toInt() ?? 0,
        unclaimedKobo: (json['unclaimedKobo'] as num?)?.toInt(),
      );
}
