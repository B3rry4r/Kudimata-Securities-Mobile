// Kudimata Securities — Referral repository.
//
// Backs the account-refer screen (lib/screens/account/refer_earn_screen.dart
// ReferEarnScreen) — replaces the hardcoded `_code = 'CHIDI-2026'`,
// `KBalancePanel(balance: '₦4,000')`, and "From 4 friends who joined."
// literals. Backing resource (registry.json ReferralCode):
//   GET  /referral-code/me           ReferralCode{userId, code,
//                                    earningsTotalKobo, referredCount}
//   POST /referral-code/track-share  204 No Content — fire-and-forget share
//                                    attribution ping, no response body to
//                                    parse.
//
// ReferralAccount is not in lib/data/models.dart — out of scope for a
// per-screen wiring agent to add there (README.md) — so it lives here,
// ReferralRepository being its only consumer. Mirrors WalletRepository's
// BankAccountSummary convention.
//
// Construct with the ONE shared ApiClient:
//   final _repo = ReferralRepository(AppScope.read(context).apiClient);
import '../api/api_client.dart';

class ReferralRepository {
  const ReferralRepository(this._client);
  final ApiClient _client;

  /// Mirrors the screen's hardcoded code/earnings/friend-count literals.
  /// GET /referral-code/me — a bare (non-paginated) `ReferralCode` object.
  Future<ReferralAccount> me() async {
    final response = await _client.get('/referral-code/me');
    return _fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /referral-code/track-share — 204 No Content, nothing to parse.
  /// Callers should fire this off without awaiting/blocking the OS share
  /// sheet on it (see refer_earn_screen.dart's Share invite button).
  Future<void> trackShare() async {
    await _client.post('/referral-code/track-share');
  }

  ReferralAccount _fromJson(Map<String, dynamic> json) {
    final earningsKobo = (json['earningsTotalKobo'] as num?)?.toInt() ?? 0;
    return ReferralAccount(
      code: json['code'] as String? ?? '',
      earningsTotal: _formatNairaWhole(earningsKobo),
      referredCount: (json['referredCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Minor-unit kobo -> the screen's existing preformatted "₦4,000" shape —
  /// whole naira, thousands-grouped, no decimal component (unlike e.g.
  /// WalletRepository._formatNaira's "₦310,400.00", the literal this screen
  /// replaces never showed kobo, so this intentionally rounds/truncates
  /// rather than introduce a decimal the design never had).
  static String _formatNairaWhole(int kobo) {
    final wholeNaira = kobo.abs() ~/ 100;
    final wholeStr = wholeNaira.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '₦$wholeStr';
  }
}

/// Minimal referral-account shape for the refer-earn screen (registry.json
/// ReferralCode resource, minus `userId` — the screen has no use for it).
class ReferralAccount {
  const ReferralAccount({
    required this.code,
    required this.earningsTotal,
    required this.referredCount,
  });

  final String code;

  /// Preformatted "₦4,000" — see [ReferralRepository._formatNairaWhole].
  final String earningsTotal;
  final int referredCount;
}
