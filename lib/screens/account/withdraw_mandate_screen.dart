// Withdraw the DCS mandate (screen 65, 2026-08-23 "Soft Landing" exactness
// pass — Flow G was entirely unbuilt until now). Reuses KFreezeConfirm, per
// screen-specs.md spec 65's own note that the design system treats "freeze
// account" and "withdraw DCS mandate" as the same class of type-to-confirm
// destructive action.
//
// Real backend limitation, flagged rather than faked: BankAccountsRepository
// only exposes setPrimary()/remove() — there is no dedicated "demote this
// account's mandate without promoting another" endpoint, and the mockup's
// "funding only" (non-mandate but still linked) state has no backing field
// either. So this screen's confirm button does NOT silently call remove()
// (which would delete the account entirely, a bigger and different action
// than what the button says) or silently no-op — it tells the investor
// honestly that self-service mandate withdrawal isn't wired to a real
// action yet, the same "not available yet" pattern used elsewhere in this
// app (receipts, statements downloads) for a real, known, unbuilt backend
// capability.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/data/repositories/bank_accounts_repository.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

class WithdrawMandateScreen extends StatefulWidget {
  const WithdrawMandateScreen({super.key, required this.account});
  final BankAccountSummary account;

  @override
  State<WithdrawMandateScreen> createState() => _WithdrawMandateScreenState();
}

class _WithdrawMandateScreenState extends State<WithdrawMandateScreen> {
  final _confirmController = TextEditingController();
  String _confirmText = '';

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canConfirm => _confirmText.trim().toUpperCase() == 'WITHDRAW';

  void _confirm() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Withdrawing a mandate isn't available yet — contact support to change your DCS account.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Withdraw mandate',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KFreezeConfirm(
            title: 'Withdraw your mandate on ${widget.account.bankName} '
                '${widget.account.accountNumberMasked}?',
            effects: const [
              'This account stops receiving sale proceeds and dividends',
              'The CSCS takes up to two business days to remove a mandate',
              "We'll email you a copy of the instruction either way",
              'Withdrawals are blocked until a new mandate is active',
            ],
            primary: KButton(
              label: 'Withdraw mandate',
              variant: KButtonVariant.destructive,
              onPressed: _canConfirm ? _confirm : null,
            ),
            secondary: KButton(
              label: 'Keep it',
              variant: KButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(height: 16),
          KInput(
            label: 'Type WITHDRAW to confirm',
            placeholder: 'WITHDRAW',
            controller: _confirmController,
            onChanged: (v) => setState(() => _confirmText = v),
          ),
          const SizedBox(height: 12),
          Text(
            'The CSCS takes up to two business days to remove a mandate. '
            'We email you a copy of the instruction either way.',
            style: KType.data(color: KColor.ink3),
          ),
        ],
      ),
    );
  }
}
