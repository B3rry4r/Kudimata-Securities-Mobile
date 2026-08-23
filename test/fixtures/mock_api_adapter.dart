// Screenshot-harness ONLY fixture backend (test/shots.dart) — flutter test
// runs with no real network (any real HttpClient call synthesizes a bare
// 400, per Flutter's own test-binding warning), so every API-backed screen
// previously rendered nothing but its generic KErrorView. That made
// test/shots.dart useless for actually verifying a screen's designed
// content, only its error-state layout.
//
// This adapter answers every endpoint the screenshotted routes touch with
// realistic JSON — where screen-specs.md gives worked example figures for a
// screen (Home #29, Wallet #40, Asset detail #33, ...) those exact figures
// are reused here so a screenshot is directly comparable to the spec's own
// prose. Everything else gets plausible, internally-consistent data derived
// from each repository's own parsing code (lib/data/repositories/*.dart) —
// every field read there uses `as T? ?? default`, so an unmodelled endpoint
// falling through to [_fallback] never crashes a screen, it just renders
// emptier than the real backend would.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

Map<String, dynamic> _asset({
  required String ticker,
  required String name,
  required int priceKobo,
  required double changePct,
  String assetClass = 'ngx',
  String logoColor = '#6524A8',
  String? about,
  int changeAbsKobo = 0,
  String? sector,
}) {
  return {
    'ticker': ticker,
    'name': name,
    'priceKobo': priceKobo,
    'changePct': changePct,
    'changeAbsKobo': changeAbsKobo,
    'assetClass': assetClass,
    'logoColor': logoColor,
    'about': ?about,
    'sector': sector,
  };
}

// Screen-specs.md #29 (Home · verified) + #32/#33's own MTNN/GTCO figures —
// reused everywhere an asset list/detail is needed so every screen agrees
// with the same worked example. `sector`/`changeAbsKobo` mirror the real
// backend's Asset.sector + Quote.changeAbsKobo fields (2026-08-24).
final _assets = [
  _asset(
    ticker: 'MTNN',
    name: 'MTN Nigeria',
    priceKobo: 26840,
    changePct: 1.94,
    changeAbsKobo: 510,
    logoColor: '#F5C542',
    sector: 'Telecoms',
    about: 'MTN Nigeria Communications Plc provides mobile telecommunications '
        'services across Nigeria, including voice, data, and digital financial '
        'services, and is listed on the Nigerian Exchange.',
  ),
  _asset(ticker: 'GTCO', name: 'Guaranty Trust Holding', priceKobo: 4815, changePct: 4.10, changeAbsKobo: 190, logoColor: '#2AA36B', sector: 'Banking'),
  _asset(ticker: 'ZENITHBANK', name: 'Zenith Bank', priceKobo: 3620, changePct: -0.82, changeAbsKobo: -30, logoColor: '#6524A8', sector: 'Banking'),
  _asset(ticker: 'DANGCEM', name: 'Dangote Cement', priceKobo: 41500, changePct: 0.35, changeAbsKobo: 145, logoColor: '#F07A45', sector: 'Industrial Goods'),
];
// No 'us'-class fixture asset: markets_screen.dart's own header comment
// documents the real backend as NGX(+ETF)-only (2026-08-07 directive) — a
// zero-priced AAPL row here doesn't represent anything the real API would
// ever return, it just misleads anyone reading a screenshot from this
// fixture into thinking a $0.00 price is a live bug.

Map<String, dynamic> _assetByTicker(String ticker) {
  final upper = ticker.toUpperCase();
  return _assets.firstWhere(
    (a) => a['ticker'] == upper,
    orElse: () => _asset(ticker: upper, name: upper, priceKobo: 26840, changePct: 1.94),
  );
}

Map<String, dynamic> _holding(String ticker) {
  // MTNN's own figures (screen-specs.md #29/#33): 120 shares @ ₦268.40,
  // +1.94% today, gain-toned.
  final avg = ticker.toUpperCase() == 'MTNN' ? 25000 : 4500;
  final asset = _assetByTicker(ticker);
  final priceKobo = asset['priceKobo'] as int;
  final units = 120;
  final marketValueKobo = priceKobo * units;
  final costKobo = avg * units;
  return {
    'ticker': ticker.toUpperCase(),
    'units': units,
    'avgPriceKobo': avg,
    'marketValueKobo': marketValueKobo,
    'totalReturnKobo': marketValueKobo - costKobo,
    'returnPct': asset['changePct'],
    'returnTrend': (asset['changePct'] as num) >= 0 ? 'gain' : 'loss',
  };
}

List<Map<String, dynamic>> _holdingsList() => [_holding('MTNN'), _holding('GTCO')];

// Wallet spec #40's own worked figures.
Map<String, dynamic> _walletBalance() => {
      'availableBalanceKobo': 21430000,
      'pendingBalanceKobo': 5067500,
    };

Map<String, dynamic> _transaction({
  required String id,
  required String title,
  required String subtitle,
  required int amountKobo,
  required bool incoming,
  required String type,
  required String status,
  required String createdAt,
}) {
  return {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'amountKobo': amountKobo,
    'incoming': incoming,
    'type': type,
    'status': status,
    'createdAt': createdAt,
    'counterparty': null,
    'holdingRule': null,
    'method': 'transfer',
    'bankCode': null,
    'accountNumber': null,
    'fromCurrency': null,
    'toCurrency': null,
    'statusHistory': [],
  };
}

// Wallet spec #40's exact recent-activity list, reused for /transactions
// (Wallet tab), /transactions/TX1042 (the txn detail route), and /orders
// (which reads the same endpoint filtered to buy/sell).
final _transactions = [
  _transaction(
    id: 'TX1042',
    title: 'Bank transfer in',
    subtitle: 'Bank transfer · GTB',
    amountKobo: 25000000,
    incoming: true,
    type: 'fund',
    status: 'completed',
    createdAt: '2026-03-14T09:12:00.000Z',
  ),
  _transaction(
    id: 'TX1043',
    title: 'Bought MTNN · 186',
    subtitle: 'Market order',
    amountKobo: -5067500,
    incoming: false,
    type: 'buy',
    status: 'pending',
    createdAt: '2026-03-14T09:41:00.000Z',
  ),
  _transaction(
    id: 'TX1044',
    title: 'MTN dividend',
    subtitle: 'Paid by DCS',
    amountKobo: 412000,
    incoming: true,
    type: 'sell',
    status: 'completed',
    createdAt: '2026-02-28T08:00:00.000Z',
  ),
];

Map<String, dynamic> _paginated(List<dynamic> items) => {
      'data': items,
      'meta': {'page': 1, 'pageSize': items.length, 'total': items.length, 'totalPages': 1},
    };

Map<String, dynamic> _user() => {
      'firstName': 'Adebayo',
      'middleName': null,
      'lastName': 'Okonkwo',
      'email': 'adebayo.okonkwo@example.com',
      'phone': '+2348012345678',
      'tier': 'Tier 2',
      'memberSince': '2025-11-02T00:00:00.000Z',
      'dob': '1994-06-12T00:00:00.000Z',
      'residentialAddress': '14 Adeola Odeku Street, Victoria Island',
      'city': 'Lagos',
      'state': 'Lagos',
      'cscsNumber': '1234567890',
      'accountStatus': 'active',
      'kycStatus': 'approved',
      'portfolioValue': 241865000,
      'returnPct': 1.43,
      'returnTrend': 'gain',
    };

Map<String, dynamic> _notification({
  required String id,
  required String title,
  required String body,
  required String icon,
  required bool unread,
  required String createdAt,
}) =>
    {'id': id, 'title': title, 'body': body, 'icon': icon, 'unread': unread, 'createdAt': createdAt};

final _notifications = [
  _notification(
    id: 'N1',
    title: 'Your order filled',
    body: 'Your buy order for 186 units of MTNN was completed.',
    icon: 'markets',
    unread: true,
    createdAt: '2026-03-14T09:41:30.000Z',
  ),
  _notification(
    id: 'N2',
    title: 'New sign-in to your account',
    body: 'A new device signed in from Lagos, Nigeria.',
    icon: 'shield',
    unread: false,
    createdAt: '2026-03-13T18:02:00.000Z',
  ),
];

Map<String, dynamic> _portfolioSummary() => {
      'totalValueKobo': 241865000,
      'allTimeReturnKobo': 3421000,
      'allTimeReturnPct': 1.43,
      'allocation': [
        {'label': 'MTNN', 'valueKobo': 3220800, 'pct': 62.0},
        {'label': 'GTCO', 'valueKobo': 1926000, 'pct': 38.0},
      ],
      'chartSeries': [2380000, 2395000, 2402000, 2410000, 2418650].map((v) => v * 100).toList(),
    };

Map<String, dynamic> _priceAlert({
  required String id,
  required String ticker,
  double? thresholdPct,
  int? thresholdPriceKobo,
  required bool active,
}) {
  final asset = _assetByTicker(ticker);
  return {
    'id': id,
    'userId': 'U1',
    'ticker': ticker,
    'thresholdPct': thresholdPct,
    'thresholdPriceKobo': thresholdPriceKobo,
    'active': active,
    'createdAt': '2026-03-01T00:00:00.000Z',
    'priceKobo': asset['priceKobo'],
    'changeAbsKobo': 0,
    'changePct': asset['changePct'],
    'asOf': '2026-03-14T09:41:00.000Z',
  };
}

// Screen 86 (price alerts): MTNN (the watchlist's first item, i.e. the
// screen's "featured" card) carries a %-based alert; ZENITHBANK carries a
// price-target alert, so a screenshot exercises both threshold shapes.
// GTCO deliberately has none, so the toggle-row "No alert set" state also
// renders.
final _priceAlerts = [
  _priceAlert(id: 'PA1', ticker: 'MTNN', thresholdPct: 5, active: true),
  _priceAlert(id: 'PA2', ticker: 'ZENITHBANK', thresholdPriceKobo: 3620, active: true),
];

// ── Dividends + e-dividend mandate (screen 84) ─────────────────────────────

Map<String, dynamic> _dividend({
  required String id,
  required String ticker,
  required int grossKobo,
  required int whtKobo,
  required int netKobo,
  required String payDate,
}) {
  return {
    'id': id,
    'userId': 'U1',
    'ticker': ticker,
    'grossKobo': grossKobo,
    'whtKobo': whtKobo,
    'netKobo': netKobo,
    'payDate': payDate,
    'transactionId': 'TX1044',
  };
}

// MTNN dividend, WHT_RATE=10% (dividends.service.ts) — 457,778 gross,
// 45,778 WHT, 412,000 net, matching _transactions' own "MTN dividend"
// +412000 entry so the two screens agree.
final _dividends = [
  _dividend(
    id: 'DIV1',
    ticker: 'MTNN',
    grossKobo: 457778,
    whtKobo: 45778,
    netKobo: 412000,
    payDate: '2026-02-28',
  ),
];

Map<String, dynamic> _dividendSummary() => {
      'year': 2026,
      'paidThisYearKobo': 412000,
      // Genuinely null from the real backend — no registrar integration
      // exists (dividend_repository.dart's header comment). Mirrored here
      // so the screenshot shows the real "—" honest-gap rendering, not a
      // fabricated estimate.
      'unclaimedKobo': null,
    };

// Unsigned by default so the screenshot exercises the "Sign the e-dividend
// mandate" call-to-action button, same default state the old static
// fixture always showed.
Map<String, dynamic> _eDividendMandate({String status = 'unsigned', String? signedAt}) => {
      'userId': 'U1',
      'status': status,
      'signedAt': signedAt,
    };

// ── Corporate actions — rights issues + AGM meetings (screens 81-83) ──────

// GTCO (a held ticker per _holdingsList()) 1-for-5 rights issue — 120 GTCO
// units held -> 24-unit entitlement, matching ratio.util.ts's floor(units *
// numerator/denominator) shape.
Map<String, dynamic> _rightsIssue() => {
      'id': 'RI1',
      'ticker': 'GTCO',
      'ratioText': '1 for 5',
      'subscriptionPriceKobo': 4200,
      'closeDate': '2026-09-27',
      'status': 'open',
      'entitlementUnits': 24,
      'alreadyElected': false,
      'election': null,
    };

// MTNN (the other held ticker) AGM — 5 real resolutions (not a fixed
// 3-item placeholder), same NGX order-of-business set the old static
// fixture used.
Map<String, dynamic> _agmMeeting() => {
      'id': 'AGM1',
      'ticker': 'MTNN',
      'title': 'MTN Nigeria Annual General Meeting 2026',
      'votesCloseAt': '2026-09-04T18:00:00.000Z',
      'status': 'open',
      'resolutions': [
        {'id': 'RES1', 'order': 1, 'description': 'Approve the 2025 accounts'},
        {'id': 'RES2', 'order': 2, 'description': 'Declare a final dividend of ₦20.00'},
        {'id': 'RES3', 'order': 3, 'description': "Re-elect a director retiring by rotation"},
        {'id': 'RES4', 'order': 4, 'description': "Fix the auditors' remuneration"},
        {'id': 'RES5', 'order': 5, 'description': 'Elect the audit committee'},
      ],
      'eligibleUnits': 120,
      'alreadyVoted': false,
      'vote': null,
    };

// ── KYC draft (2026-08-24 — chn/bank-dcs/declarations/review screens) ─────

Map<String, dynamic> _kycDocument({
  required String kind,
  required String name,
  required String uploadedAt,
}) =>
    {
      'id': 'DOC-$kind',
      'kycSubmissionId': 'KYC1',
      'objectKey': 'kyc/$kind.jpg',
      'documentName': name,
      'documentKind': kind,
      'uploadedAt': uploadedAt,
    };

/// A fully-populated in-progress draft — every field the new review/chn/
/// declarations screens read has a realistic, non-null value so their
/// screenshots exercise the real rendered content, not the "not provided
/// yet" fallback text.
Map<String, dynamic> _kycDraft() => {
      'id': 'KYC1',
      'userId': 'U1',
      'bvn': '22143459901',
      'nin': '77889012345',
      'chn': '1234567890',
      'pepSelfDeclared': false,
      'tier': 'Tier 2',
      'documentType': 'drivers_licence',
      'documents': [
        _kycDocument(kind: 'drivers_licence', name: "Driver's licence", uploadedAt: '2026-03-14T09:30:00.000Z'),
        _kycDocument(kind: 'liveness_selfie', name: 'Face liveness check', uploadedAt: '2026-03-14T09:35:00.000Z'),
        _kycDocument(kind: 'proof_of_address', name: 'IBEDC bill', uploadedAt: '2026-02-20T00:00:00.000Z'),
      ],
      'name': 'Adebayo Okonkwo',
      'dob': '1994-06-12',
      'address': '14 Adeola Odeku Street, Victoria Island',
      'city': 'Lagos',
      'state': 'Lagos',
      'nextOfKin': null,
      'vendorDecision': 'no_decision',
      'vendorDetail': null,
      'status': 'draft',
      'flagReason': null,
      'flagDetail': null,
      'submittedAt': '2026-03-14T09:00:00.000Z',
      'assignedTo': null,
      'attemptCount': 0,
      'maxAttempts': 3,
      'livenessMatchPct': 97.5,
      'providerChecks': {'bvnLookup': 'CONFIRMED', 'sanctionsPep': 'not_checked', 'duplicateAccount': 'not_checked'},
      'reviewerChecks': null,
      'internalNote': null,
      'currentStep': 5,
      'totalSteps': 5,
      'verificationSignals': {'nin': true, 'bvn': true, 'name': true, 'dob': true, 'liveness': true},
    };

// GET /banks — a small realistic subset (bank_dcs_screen.dart's picker).
final _banks = [
  {'code': '058', 'name': 'Guaranty Trust Bank'},
  {'code': '011', 'name': 'First Bank of Nigeria'},
  {'code': '057', 'name': 'Zenith Bank'},
  {'code': '033', 'name': 'United Bank for Africa'},
  {'code': '044', 'name': 'Access Bank'},
];

/// A single, generic mock [HttpClientAdapter] for test/shots.dart — matches
/// on [RequestOptions.path] (the relative path passed to ApiClient's verbs,
/// never the full resolved URL) since that's what every repository call
/// actually passes.
class MockApiAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final body = _resolve(path, options.queryParameters);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  dynamic _resolve(String path, Map<String, dynamic> query) {
    if (path == '/wallet-balance') return _walletBalance();
    if (path == '/portfolio-summary') return _portfolioSummary();
    if (path == '/users/me') return _user();
    if (path == '/assets/trending') return _assets;
    if (path == '/assets') {
      final assetClass = query['assetClass'] as String?;
      if (assetClass == null) return _assets;
      return _assets.where((a) => a['assetClass'] == assetClass).toList();
    }
    if (path == '/watchlist-items') return _assets.take(3).toList();
    if (path == '/price-alerts') return _priceAlerts;
    if (path == '/bank-accounts') {
      return [
        {'id': 'BA1', 'bankName': 'GTBank', 'accountNumberMasked': '••••6789', 'primary': true},
      ];
    }
    if (path == '/notifications') return _paginated(_notifications);
    if (path == '/dividends') return _paginated(_dividends);
    if (path == '/dividends/summary') return _dividendSummary();
    if (path == '/e-dividend-mandate/sign') return _eDividendMandate(status: 'signed', signedAt: '2026-03-14T09:00:00.000Z');
    if (path == '/e-dividend-mandate/me') return _eDividendMandate();
    if (path == '/rights-issues') return [_rightsIssue()];
    if (path.startsWith('/rights-issues/') && path.endsWith('/elect')) {
      return {
        'id': 'RE1',
        'rightsIssueId': 'RI1',
        'userId': 'U1',
        'decision': 'take_up',
        'entitlementUnits': 24,
        'unitsSubscribed': 24,
        'decidedAt': '2026-03-14T09:00:00.000Z',
      };
    }
    if (path == '/agm-meetings') return [_agmMeeting()];
    if (path.startsWith('/agm-meetings/') && path.endsWith('/vote')) {
      return {
        'id': 'AV1',
        'agmMeetingId': 'AGM1',
        'userId': 'U1',
        'votes': {'RES1': 'for', 'RES2': 'for', 'RES3': 'for', 'RES4': 'for', 'RES5': 'for'},
        'eligibleUnits': 120,
        'submittedAt': '2026-03-14T09:00:00.000Z',
      };
    }
    if (path == '/transactions') return _paginated(_transactions);
    // Must be checked before the generic '/transactions/:id' fallback below
    // — 'virtual-account' would otherwise match as an :id and return a
    // Transaction shape, which VirtualAccountDetails' accountNumber/bankName
    // fields both parse as empty strings from (silently — every field is
    // `as String? ?? ''`, so this renders a real screen with a blank account
    // number instead of crashing or erroring).
    if (path == '/transactions/virtual-account') {
      return {'accountNumber': '9902447108', 'bankName': 'Providus Bank'};
    }
    if (path.startsWith('/transactions/') && path.endsWith('/receipt')) {
      return {'url': 'https://example.com/receipt.pdf'};
    }
    if (path.startsWith('/transactions/')) {
      final id = path.split('/').last;
      return _transactions.firstWhere((t) => t['id'] == id, orElse: () => _transactions.first);
    }
    if (path == '/holdings') return _paginated(_holdingsList());
    if (path.startsWith('/holdings/')) return _holding(path.split('/').last);
    if (path.startsWith('/assets/')) return _assetByTicker(path.split('/').last);
    if (path == '/suitability-result/me') {
      // Field names match registry.json's Suitability-result resource
      // (id, userId, profile, rationale, answers, computedAt) — see
      // suitability_repository.dart's fromJson. Was 'riskProfile', a key
      // the repository never reads, so SuitabilityResult.profile silently
      // parsed to '' and the result screen rendered with no profile title
      // at all (found while shot-testing this audit's suitability_result
      // screen).
      return {
        'profile': 'Balanced',
        'rationale': "You'll take some ups and downs for better long-term "
            "returns, but not wild swings.",
        'completedAt': '2025-11-02T00:00:00.000Z',
      };
    }
    if (path == '/kyc-submissions/me') {
      return {'status': 'approved', 'submittedAt': '2025-11-01T00:00:00.000Z'};
    }
    // GET (resume)/POST (draftStep1)/PATCH (updateDraftFields) all resolve
    // by path only — see this file's header — so one fixture answers all
    // three for '/kyc-submissions/draft'. Realistic enough for
    // review_submit_screen.dart (2026-08-24) to render every summary row
    // with real-looking data, and for chn_screen.dart/declarations_screen.dart's
    // resume-prefill fetch.
    if (path == '/kyc-submissions/draft') return _kycDraft();
    if (path == '/banks') return _banks;
    if (path == '/banks/resolve-account-name') return {'accountName': 'ADEBAYO OKONKWO'};
    if (path == '/notification-preferences/me') {
      return {'orderUpdates': true, 'security': true, 'marketing': false};
    }
    return _fallback(path);
  }

  /// Any endpoint not modelled above. A bare `{}` satisfies every
  /// object-shaped consumer (every field read is `as T? ?? default`, per
  /// this file's header) and `_paginated([])` satisfies every list-shaped
  /// one — returning the paginated shape whenever the path doesn't look
  /// like a single-resource fetch (no trailing `/:id` segment) covers both.
  dynamic _fallback(String path) {
    final looksLikeList = !RegExp(r'/[A-Za-z0-9_-]{6,}$').hasMatch(path);
    return looksLikeList ? _paginated(const []) : <String, dynamic>{};
  }
}
