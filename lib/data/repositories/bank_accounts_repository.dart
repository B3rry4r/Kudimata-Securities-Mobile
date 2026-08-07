// Kudimata Securities — Bank accounts repository.
//
// Backs the Account · Bank accounts screen (lib/screens/account/
// bank_accounts_screen.dart BankAccountsScreen — replaces the hardcoded
// static `_banks` list, wires the "Add bank account" button to a real
// add-account sheet, and wires each row's set-primary/remove actions).
// Backing resources (registry.json):
//   GET    /bank-accounts              list<BankAccount>
//   POST   /bank-accounts              {bankCode, accountNumber} -> BankAccount
//   DELETE /bank-accounts/:id          204 No Content
//   PATCH  /bank-accounts/:id/primary  -> BankAccount
//   GET    /banks                      list<Bank> — picker for the add-account sheet
//   POST   /banks/resolve-account-name {bankCode, accountNumber} -> {accountName}
//
// `BankAccount`'s response shape (id/bankName/accountNumberMasked/primary) is
// already modelled by `BankAccountSummary` in wallet_repository.dart (built
// for the withdraw sheet's destination row off the same GET /bank-accounts
// endpoint) — reused here rather than duplicating an identical class, per
// lib/data/api/README.md's note that a resource shape not yet in
// lib/data/models.dart is a per-screen judgment call, not something to
// reinvent per repository.
//
// Construct with the ONE shared ApiClient:
//   final _repo = BankAccountsRepository(AppScope.read(context).apiClient);
import '../api/api_client.dart';
import 'wallet_repository.dart' show BankAccountSummary;

class BankAccountsRepository {
  const BankAccountsRepository(this._client);
  final ApiClient _client;

  /// Mirrors the screen's old hardcoded `_banks` list. GET /bank-accounts —
  /// a plain (non-paginated) `list<BankAccount>` per registry.json.
  Future<List<BankAccountSummary>> list() async {
    final response = await _client.get('/bank-accounts');
    final items = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map(BankAccountSummary.fromJson).toList();
  }

  /// POST /bank-accounts. [bankCode] comes from a picked [Bank] ([banks]);
  /// [accountNumber] is the raw (unmasked) NUBAN entered in the add-account
  /// sheet — the server returns the newly saved account already masked.
  Future<BankAccountSummary> add({
    required String bankCode,
    required String accountNumber,
  }) async {
    final response = await _client.post('/bank-accounts', data: {
      'bankCode': bankCode,
      'accountNumber': accountNumber,
    });
    return BankAccountSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// DELETE /bank-accounts/:id — 204 No Content, nothing to parse.
  Future<void> remove(String id) async {
    await _client.delete('/bank-accounts/$id');
  }

  /// PATCH /bank-accounts/:id/primary.
  Future<BankAccountSummary> setPrimary(String id) async {
    final response = await _client.patch('/bank-accounts/$id/primary');
    return BankAccountSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /banks — the bank list for the add-account sheet's picker.
  Future<List<Bank>> banks() async {
    final response = await _client.get('/banks');
    final items = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map(Bank.fromJson).toList();
  }

  /// POST /banks/resolve-account-name — resolves the account holder name for
  /// [bankCode]/[accountNumber] so the add-account sheet can show it before
  /// the investor confirms. Returns null if the response carries no name
  /// (e.g. an unresolvable/incomplete account number); callers treat that as
  /// "no preview yet", not an error.
  Future<String?> resolveAccountName({
    required String bankCode,
    required String accountNumber,
  }) async {
    final response = await _client.post('/banks/resolve-account-name', data: {
      'bankCode': bankCode,
      'accountNumber': accountNumber,
    });
    final json = response.data as Map<String, dynamic>;
    return json['accountName'] as String?;
  }
}

/// A pickable bank (registry.json Bank resource) — [banks]' list item shape.
class Bank {
  const Bank({required this.code, required this.name});
  final String code;
  final String name;

  factory Bank.fromJson(Map<String, dynamic> json) => Bank(
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}
