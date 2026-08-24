// Screen 90 — Close your account (2026-08-23, account-lifecycle/legal
// cluster). Reuses `KFreezeConfirm` per the recently-established pattern
// (see withdraw_mandate_screen.dart) of nulling `primary`/`secondary` so the
// buttons can sit below the shares/wallet summary card exactly as the canvas
// lays it out, rather than immediately after the effects list.
//
// REMAINING GAP (flagged per the cluster brief):
//   - "Shares to move or sell" / "Wallet to pay out" are wired to real data
//     (HoldingsRepository.holdings + WalletRepository.balance), but the
//     share/company count is computed by summing ONE page of holdings
//     (pageSize 100) — there is no dedicated "total units + distinct
//     company count" endpoint. Fine for any realistic retail portfolio,
//     but would silently undercount past 100 distinct holdings.
//
// "Request closure" is wired 2026-08-24 to the real POST
// /users/me/request-closure (UserRepository.requestClosure(), mirroring
// freeze()'s exact shape/error handling — see freeze_account_screen.dart).
// Unlike freeze, a closure REQUEST does not change the account's status or
// revoke sessions server-side (Kudimata-Securities-Backend
// UsersController.requestClosure() just records the request for staff to
// action) — the account stays fully open and functional, so this screen
// does NOT sign the user out on success; it shows a real confirmation and
// returns to Account.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/api/paginated_response.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/bank_accounts_repository.dart';
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/data/repositories/wallet_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';
import 'legal_reference_screens.dart';

class CloseAccountScreen extends StatefulWidget {
  const CloseAccountScreen({super.key});

  @override
  State<CloseAccountScreen> createState() => _CloseAccountScreenState();
}

class _ClosureSummary {
  const _ClosureSummary({
    required this.sharesLabel,
    required this.walletLabel,
    required this.payoutAccountLabel,
  });
  final String sharesLabel;
  final String walletLabel;
  final String payoutAccountLabel;
}

class _CloseAccountScreenState extends State<CloseAccountScreen> {
  late final _holdingsRepo = HoldingsRepository(AppScope.read(context).apiClient);
  late final _walletRepo = WalletRepository(AppScope.read(context).apiClient);
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);
  late final Future<_ClosureSummary> _future = _load();

  bool _requesting = false;
  String? _error;

  Future<_ClosureSummary> _load() async {
    final results = await Future.wait<dynamic>([
      _holdingsRepo.holdings(pageSize: 100),
      _walletRepo.balance(),
      _walletRepo.bankAccounts(),
    ]);
    final holdings = results[0] as PaginatedResponse<Holding>;
    final walletBalance = results[1] as String;
    final banks = results[2] as List<BankAccountSummary>;

    var totalUnits = 0;
    for (final h in holdings.data) {
      totalUnits += int.tryParse(h.units.replaceAll(',', '')) ?? 0;
    }
    final companyCount = holdings.data.length;
    final sharesLabel = companyCount == 0
        ? 'None held'
        : '$totalUnits · $companyCount ${companyCount == 1 ? 'company' : 'companies'}';

    final primary = banks.isNotEmpty
        ? banks.firstWhere((b) => b.primary, orElse: () => banks.first)
        : null;
    final payoutAccountLabel =
        primary != null ? '${primary.bankName} ${primary.accountNumberMasked}' : 'your DCS account';

    return _ClosureSummary(
      sharesLabel: sharesLabel,
      walletLabel: walletBalance,
      payoutAccountLabel: payoutAccountLabel,
    );
  }

  void _openClosureTerms() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AccountClosureTermsScreen()),
    );
  }

  Future<void> _requestClosure() async {
    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      await _userRepo.requestClosure();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: KColor.paper,
          title: Text('Closure requested', style: KType.cardTitle()),
          content: Text(
            'We\'ve received your request. Your account stays fully open and functional while '
            'our team reviews it — we\'ll be in touch about next steps.',
            style: KType.body(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: KType.cardTitle(color: KColor.indicator)),
            ),
          ],
        ),
      );
      if (!mounted) return;
      // A closure REQUEST doesn't change account status or revoke sessions
      // server-side (unlike freeze) — the account is still fully usable, so
      // just return to Account rather than signing out.
      context.go(Routes.account);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Close account',
      child: FutureBuilder<_ClosureSummary>(
        future: _future,
        builder: (context, snapshot) {
          final ready = snapshot.connectionState == ConnectionState.done && !snapshot.hasError;
          final summary = ready ? snapshot.data! : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KFreezeConfirm(
                title: 'Before you close',
                effects: [
                  'Your shares must be sold or moved to another broker first — we cannot '
                      'close an account holding stock.',
                  'Wallet money is paid to ${summary?.payoutAccountLabel ?? 'your DCS account'}.',
                  'Statements, contract notes and tax documents stay downloadable for 12 years, '
                      'as the SEC requires.',
                  'Your CHN stays yours for life; closing here does not close it at the CSCS.',
                ],
              ),
              const SizedBox(height: 12),
              KAccountCard(
                children: [
                  KKeyValueRow(
                    label: 'Shares to move or sell',
                    value: summary?.sharesLabel ?? (snapshot.hasError ? '—' : '…'),
                    first: true,
                  ),
                  KKeyValueRow(
                    label: 'Wallet to pay out',
                    value: summary?.walletLabel ?? (snapshot.hasError ? '—' : '…'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RichText(
                text: TextSpan(
                  style: KType.data(color: KColor.ink3),
                  children: [
                    const TextSpan(text: 'Closing is covered by the '),
                    TextSpan(
                      text: 'account closure terms',
                      style: KType.data(color: KColor.ink2).copyWith(decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()..onTap = _openClosureTerms,
                    ),
                    const TextSpan(
                      text: '. We keep the records the SEC requires and delete the rest.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              KButton(
                label: 'Sell my shares first',
                variant: KButtonVariant.secondary,
                onPressed: () => context.go(Routes.portfolio),
              ),
              const SizedBox(height: 10),
              KButton(
                label: 'Request closure',
                variant: KButtonVariant.destructive,
                loading: _requesting,
                onPressed: _requesting ? null : _requestClosure,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: KType.body(color: KColor.loss)),
              ],
            ],
          );
        },
      ),
    );
  }
}
