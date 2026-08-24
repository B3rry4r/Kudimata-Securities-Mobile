// Kudimata Securities — AI comprehension repository.
//
// See lib/data/api/README.md for the shared convention. Construct with the
// ONE shared ApiClient, reached via `AppScope.read(context).apiClient`.
//
// Backs the real Gemini-backed /ai/* endpoints (2026-08-24) —
// replaces explain_screen.dart's hardcoded `_canned()` strings and
// home_screen.dart's client-side `_weeklyDigest()` template, and makes
// account_screen.dart's KCreditMeter / plans_screen.dart's plan buttons
// real instead of decorative. See Kudimata-Securities-Backend's
// src/ai-comprehension module for the full server-side implementation.
import '../api/api_client.dart';

class AiCreditLedgerEntry {
  const AiCreditLedgerEntry({
    required this.delta,
    required this.reason,
    required this.relatedId,
    required this.createdAt,
  });
  final int delta;
  final String reason;
  final String? relatedId;
  final DateTime createdAt;
}

class AiCreditStatus {
  const AiCreditStatus({
    required this.creditsRemaining,
    required this.plan,
    required this.planRenewsAt,
    required this.recentLedger,
  });
  final int creditsRemaining;
  /// null | 'plus' | 'pro'.
  final String? plan;
  final DateTime? planRenewsAt;
  final List<AiCreditLedgerEntry> recentLedger;
}

class AiPlan {
  const AiPlan({
    required this.key,
    required this.name,
    required this.priceKobo,
    required this.credits,
    required this.features,
  });
  final String key;
  final String name;
  final int priceKobo;
  final int credits;
  final List<String> features;
}

class ExplainAssetResult {
  const ExplainAssetResult({required this.text, required this.creditsRemaining});
  final String text;
  final int creditsRemaining;
}

class PortfolioDigestResult {
  const PortfolioDigestResult({
    required this.text,
    required this.creditsRemaining,
    required this.cached,
  });
  final String text;
  final int creditsRemaining;
  final bool cached;
}

class AiRepository {
  const AiRepository(this._client);
  final ApiClient _client;

  Future<AiCreditStatus> credits() async {
    final response = await _client.get('/ai/credits');
    return _statusFromJson(response.data as Map<String, dynamic>);
  }

  Future<List<AiPlan>> plans() async {
    final response = await _client.get('/ai/plans');
    final items = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return items
        .map((j) => AiPlan(
              key: j['key'] as String,
              name: j['name'] as String,
              priceKobo: j['priceKobo'] as int,
              credits: j['credits'] as int,
              features: (j['features'] as List<dynamic>).cast<String>(),
            ))
        .toList();
  }

  Future<AiCreditStatus> subscribe(String plan) async {
    final response = await _client.post('/ai/plans/subscribe', data: {'plan': plan});
    return _statusFromJson(response.data as Map<String, dynamic>);
  }

  Future<AiCreditStatus> cancelPlan() async {
    final response = await _client.post('/ai/plans/cancel', data: {});
    return _statusFromJson(response.data as Map<String, dynamic>);
  }

  Future<ExplainAssetResult> explainAsset(String ticker) async {
    final response = await _client.post('/ai/explain-asset/$ticker', data: {});
    final json = response.data as Map<String, dynamic>;
    return ExplainAssetResult(
      text: json['text'] as String,
      creditsRemaining: json['creditsRemaining'] as int,
    );
  }

  Future<PortfolioDigestResult> portfolioDigest() async {
    final response = await _client.post('/ai/portfolio-digest', data: {});
    final json = response.data as Map<String, dynamic>;
    return PortfolioDigestResult(
      text: json['text'] as String,
      creditsRemaining: json['creditsRemaining'] as int,
      cached: json['cached'] as bool,
    );
  }

  AiCreditStatus _statusFromJson(Map<String, dynamic> json) {
    final ledger = (json['recentLedger'] as List<dynamic>).cast<Map<String, dynamic>>();
    return AiCreditStatus(
      creditsRemaining: json['creditsRemaining'] as int,
      plan: json['plan'] as String?,
      planRenewsAt:
          json['planRenewsAt'] == null ? null : DateTime.tryParse(json['planRenewsAt'] as String),
      recentLedger: ledger
          .map((e) => AiCreditLedgerEntry(
                delta: e['delta'] as int,
                reason: e['reason'] as String,
                relatedId: e['relatedId'] as String?,
                createdAt: DateTime.parse(e['createdAt'] as String),
              ))
          .toList(),
    );
  }
}
