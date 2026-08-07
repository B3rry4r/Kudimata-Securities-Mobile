// Kudimata Securities — Wallet repository.
//
// Backs the wallet tab's balance panel (lib/screens/wallet/wallet_screens.dart
// WalletScreen — replaces the hardcoded `KBalancePanel(balance: '₦310,400.00')`
// literal) and the Add money / Withdraw sheet flows (lib/screens/wallet/
// wallet_flows.dart showAddMoneyFlow/showWithdrawFlow — replaces their mocked
// processor delays). Backing resources (registry.json):
//   GET /wallet-balance         WalletBalance{availableBalanceKobo,...}
//   POST /transactions/fund     {amountKobo, method} -> Transaction + checkoutUrl
//   POST /transactions/withdraw {amountKobo, bankAccountId} -> Transaction
//   GET /bank-accounts          list<BankAccount> — withdraw destination
//
// POST /transactions/fund no longer attempts a direct card charge: the
// backend creates a pending Transaction and returns a Flutterwave
// hosted-checkout `checkoutUrl` the investor completes payment on in their
// own browser (their own webhook is what actually confirms the money moved,
// server-to-server — never something this client can assume from a
// synchronous 200 alone). `method` is now purely informational — Flutterwave's
// hosted page lets the payer choose freely — see [fund]'s doc comment.
//
// `POST /transactions/withdraw` needs a saved `BankAccount.id`, not a raw
// bank code/account number — [bankAccounts] fetches the investor's saved
// payout accounts for that purpose (see wallet_flows.dart's _WithdrawSheet
// for how the picker-UI gap is handled: no picker exists yet, so the sheet
// wires against the primary/first saved account and leaves the row's tap
// target as the documented gap, not something invented here).
//
// fund()/withdraw() parse their Transaction response with the same
// kobo/date-formatting shape TransactionRepository's `_fromJson` uses (that
// method is private to that file, so it's duplicated here rather than
// exposed cross-file — mirrors HoldingsRepository/NotificationsRepository's
// established convention of self-contained per-repository formatting
// helpers rather than a shared formatting module).
//
// Construct with the ONE shared ApiClient:
//   final _repo = WalletRepository(AppScope.read(context).apiClient);
import '../api/api_client.dart';
import '../models.dart';

/// [WalletRepository.fund]'s result: the `pending` Transaction the backend
/// created plus the Flutterwave hosted-checkout link the caller must send
/// the investor to in order to actually move money (see [WalletRepository]'s
/// file header — the backend no longer attempts a direct card charge).
typedef FundResult = ({Txn transaction, String checkoutUrl});

class WalletRepository {
  const WalletRepository(this._client);
  final ApiClient _client;

  /// Mirrors the wallet tab's KBalancePanel literal. GET /wallet-balance —
  /// WalletBalance{availableBalanceKobo,...} formatted into the same
  /// preformatted "₦310,400.00" display-string shape the panel already
  /// renders.
  Future<String> balance() async {
    final response = await _client.get('/wallet-balance');
    final json = response.data as Map<String, dynamic>;
    final kobo = (json['availableBalanceKobo'] as num?)?.toInt() ?? 0;
    return _formatNaira(kobo);
  }

  /// POST /transactions/fund. [amountKobo] is the amount the Add money sheet
  /// collected, converted from its entered naira string; [method] is
  /// 'card' or 'transfer' (registry.json enum) — advisory only now, since
  /// Flutterwave's own hosted checkout page (linked by the returned
  /// [FundResult.checkoutUrl]) is where the investor actually picks how to
  /// pay. The [FundResult.transaction] this returns is a `pending` row —
  /// NOT a completed fund; the caller must send the investor to
  /// [FundResult.checkoutUrl] to actually move money.
  Future<FundResult> fund({required int amountKobo, required String method}) async {
    final response = await _client.post('/transactions/fund', data: {
      'amountKobo': amountKobo,
      'method': method,
    });
    final json = response.data as Map<String, dynamic>;
    return (
      transaction: _fromJson(json),
      checkoutUrl: json['checkoutUrl'] as String? ?? '',
    );
  }

  /// POST /transactions/withdraw. [bankAccountId] must be a saved
  /// `BankAccount.id` from [bankAccounts] — never a raw bank code/account
  /// number.
  Future<Txn> withdraw({required int amountKobo, required String bankAccountId}) async {
    final response = await _client.post('/transactions/withdraw', data: {
      'amountKobo': amountKobo,
      'bankAccountId': bankAccountId,
    });
    return _fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /bank-accounts — the investor's saved payout destinations, used to
  /// populate the withdraw sheet's destination row. See file header for the
  /// picker-UI gap this stands in for.
  Future<List<BankAccountSummary>> bankAccounts() async {
    final response = await _client.get('/bank-accounts');
    final items = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map(BankAccountSummary.fromJson).toList();
  }

  Txn _fromJson(Map<String, dynamic> json) {
    final incoming = json['incoming'] as bool? ?? false;
    final amountKobo = (json['amountKobo'] as num?)?.toInt() ?? 0;
    return Txn(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      amount: _formatSignedNaira(amountKobo: amountKobo, incoming: incoming),
      date: _formatDate(json['createdAt'] as String?),
      type: TxnType.values.firstWhere(
        (t) => t.name == json['type'] as String?,
        orElse: () => TxnType.fund,
      ),
      status: switch (json['status'] as String?) {
        'completed' => TxnStatus.completed,
        'failed' || 'rejected' => TxnStatus.failed,
        _ => TxnStatus.pending,
      },
      incoming: incoming,
    );
  }

  // ── Formatting helpers — kobo → the app's preformatted display strings
  // (docs/BUILD_CONTRACT.md: "₦268.40", loss uses unicode minus U+2212).
  // Mirrors TransactionRepository._formatAmount/_formatDate's shape. ──────

  static String _formatNaira(int kobo) {
    final absKobo = kobo.abs();
    final wholeNaira = absKobo ~/ 100;
    final koboRemainder = absKobo % 100;
    final wholeStr = wholeNaira.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '₦$wholeStr.${koboRemainder.toString().padLeft(2, '0')}';
  }

  static String _formatSignedNaira({required int amountKobo, required bool incoming}) {
    final sign = incoming ? '+' : '−';
    return '$sign${_formatNaira(amountKobo)}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year} · $hh:$mm';
  }
}

/// Minimal saved-bank-account shape for the withdraw sheet's destination row
/// (registry.json BankAccount resource). Not in lib/data/models.dart — out
/// of scope for a per-screen wiring agent to add there (README.md) — so it
/// lives here, WalletRepository being its only consumer.
class BankAccountSummary {
  const BankAccountSummary({
    required this.id,
    required this.bankName,
    required this.accountNumberMasked,
    required this.primary,
  });

  final String id;
  final String bankName;
  final String accountNumberMasked;
  final bool primary;

  factory BankAccountSummary.fromJson(Map<String, dynamic> json) => BankAccountSummary(
        id: json['id'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        accountNumberMasked: json['accountNumberMasked'] as String? ?? '',
        primary: json['primary'] as bool? ?? false,
      );
}
