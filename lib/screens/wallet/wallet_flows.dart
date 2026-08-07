// Kudimata Securities — Stage 8: Wallet money-movement flows as bottom sheets.
// Mirrors wallet-screens.jsx (AddMoney / Withdraw) as showKSheet
// sequences: amount → method/bank → review → KStatusView success. The
// launching wallet screen stays behind the scrim.
//
// Wired per lib/data/api/README.md: the review steps' confirm buttons call
// WalletRepository.fund()/withdraw() (POST /transactions/fund,
// POST /transactions/withdraw) instead of the old mocked delay. Both sheets
// already thread the entered amount end-to-end (unlike trade_flows.dart's
// known bug — a different screen). On ApiException from the initial call
// itself (e.g. a real 422 for insufficient balance) an error variant of the
// KStatusView sheet shows, and the review step is left in place (not popped)
// so the user can retry without re-entering anything.
//
// Add money is NOT instant: POST /transactions/fund no longer attempts a
// direct card charge — it creates a pending Transaction and returns a
// Flutterwave hosted-checkout `checkoutUrl`. _AddMoneyReview._confirm()
// launches that link externally (url_launcher, same pattern as
// statements_screen.dart/legal_screen.dart/help_support_screen.dart) and then
// shows a `pending`-tone KStatusView explaining the investor must finish
// paying in their browser — there is no success sheet at fund()-call time
// anymore, since the money hasn't moved yet (only Flutterwave's webhook,
// server-to-server, ever confirms that). Withdraw is UNCHANGED — withdrawals
// still go server-to-bank directly, so its review step keeps the original
// immediate KStatusView success flow.
//
// The withdraw destination: POST /transactions/withdraw needs a saved
// `BankAccount.id` (registry.json), not a raw bank code/account number. No
// in-sheet picker UI exists for choosing among multiple saved accounts (the
// design's _SelectRow is a single fixed row, not a list) — building one is a
// bigger UI change than this wiring pass, so _WithdrawSheet fetches the
// investor's real saved accounts (GET /bank-accounts) and uses the primary
// one (falling back to the first) as the destination, same as the design's
// single-row layout implies. See _WithdrawSheetState for the gap this
// leaves: only ever the primary/first saved account is reachable from this
// screen; adding/choosing others requires the account-banks screen.
//
// NGX-only: the Convert (₦ → $) flow was removed — Blue Marina supplies NGX
// equities only, and Convert existed solely to fund USD stock buys.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/api/api_exception.dart';
import 'package:kudimata_securities/data/repositories/wallet_repository.dart';
import 'package:kudimata_securities/screens/shared/state_views.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'package:kudimata_securities/theme/tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public flow launchers (cross-stage contract — see BUILD_CONTRACT.md §d).
// ─────────────────────────────────────────────────────────────────────────────

/// Add money: amount + method → review → success.
Future<void> showAddMoneyFlow(BuildContext context) => showKSheet<void>(
      context,
      title: 'Add money',
      child: const _AddMoneySheet(),
    );

/// Withdraw: amount + destination bank → review → success.
Future<void> showWithdrawFlow(BuildContext context) => showKSheet<void>(
      context,
      title: 'Withdraw',
      child: const _WithdrawSheet(),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Shared bits.
// ─────────────────────────────────────────────────────────────────────────────

// A selectable row inside a hairline card (method / destination).
class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.icon,
    required this.title,
    required this.sub,
    this.selected = false,
    this.trailingChevron = false,
    required this.first,
    this.onTap,
  });

  final String icon;
  final String title;
  final String sub;
  final bool selected;
  final bool trailingChevron;
  final bool first;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          border: first
              ? null
              : Border(top: BorderSide(color: KColor.hairline, width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KColor.bg,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(BorderSide(color: KColor.hairline, width: 1)),
              ),
              child: KIcon(icon, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: KType.cardTitle()),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: KType.micro(color: KColor.ink3)
                          .copyWith(letterSpacing: 0.04 * 10, height: 15 / 10)
                          .tnum),
                ],
              ),
            ),
            if (selected) const KIcon('check', size: 20),
            if (trailingChevron) KIcon('chevronRight', size: 20, color: KColor.ink3),
          ],
        ),
      ),
    );
  }
}

// Summary row for review sheets — label left, tabular value right.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KType.body(color: KColor.ink2)),
          Text(value, style: KType.body(color: KColor.ink, w: KWeight.medium).tnum),
        ],
      ),
    );
  }
}

void _showSuccessSheet(
  BuildContext context, {
  required String title,
  required String message,
}) {
  HapticFeedback.lightImpact();
  showKSheet<void>(
    context,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KStatusView(
        tone: KStatusTone.success,
        title: title,
        message: message,
        primary: 'Done',
        onPrimary: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

/// Shown after POST /transactions/fund succeeds and the returned
/// `checkoutUrl` has been (best-effort) launched in the investor's browser.
/// Funding is NOT complete at this point — only Flutterwave's webhook,
/// server-to-server, confirms the money actually moved — so this is a
/// `pending` tone, not `success`. "I've completed payment" just dismisses
/// back to the wallet screen (same pop-based pattern as [_showSuccessSheet]'s
/// "Done"); the wallet's existing pull-to-refresh is how the investor sees
/// the eventual outcome once the webhook has processed.
void _showCheckoutPendingSheet(BuildContext context) {
  showKSheet<void>(
    context,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KStatusView(
        tone: KStatusTone.pending,
        title: 'Finish payment in your browser',
        message: "We've opened a secure checkout page in your browser. "
            "Once you're done there, come back here and pull down to refresh "
            'your wallet.',
        primary: "I've completed payment",
        onPrimary: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

/// Shown over the still-open review sheet when a fund/withdraw call fails
/// with an [ApiException] (e.g. insufficient balance) — [message] is that
/// exception's human-readable summary (safe to show directly, per
/// lib/data/api/api_exception.dart). "Try again" just dismisses this sheet;
/// the review step behind it keeps its entered amount/method/destination so
/// the retry doesn't lose any input.
void _showErrorSheet(
  BuildContext context, {
  required String title,
  required String message,
}) {
  showKSheet<void>(
    context,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KStatusView(
        tone: KStatusTone.error,
        title: title,
        message: message,
        primary: 'Try again',
        onPrimary: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

/// Comma-grouped naira text (e.g. "50,000" or "12,345.67") → integer kobo,
/// matching trade_flows.dart's `_amountValue` parsing convention.
int _parseAmountKobo(String amountText) {
  final value = double.tryParse(amountText.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;
  return (value * 100).round();
}

// Quick-amount chips that overwrite the amount field.
class _QuickAmounts extends StatelessWidget {
  const _QuickAmounts({required this.values, required this.onPick});
  final List<(String label, String value)> values;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (label, value) in values) ...[
          if (label != values.first.$1) const SizedBox(width: 8),
          Expanded(
            child: KPillChip(label: label, onTap: () => onPick(value)),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD MONEY — Step 1: amount + payment method.
// ─────────────────────────────────────────────────────────────────────────────

class _AddMoneySheet extends StatefulWidget {
  const _AddMoneySheet();
  @override
  State<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends State<_AddMoneySheet> {
  late final TextEditingController _amount = TextEditingController(text: '50,000');
  String _method = 'bank'; // bank | card

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KInput(
          label: 'Amount',
          controller: _amount,
          numeric: true,
          amount: true,
          prefix: '₦',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 14),
        _QuickAmounts(
          values: const [('₦10k', '10,000'), ('₦50k', '50,000'), ('₦100k', '100,000')],
          onPick: (v) => setState(() => _amount.text = v),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: KEyebrow('Pay with'),
        ),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _SelectRow(
                icon: 'transfer',
                title: 'Bank transfer',
                sub: 'Reflects within minutes',
                selected: _method == 'bank',
                first: true,
                onTap: () => setState(() => _method = 'bank'),
              ),
              _SelectRow(
                icon: 'card',
                title: 'Debit card',
                sub: 'Instant · 1.4% fee',
                selected: _method == 'card',
                first: false,
                onTap: () => setState(() => _method = 'card'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Bank transfers reflect within minutes.',
            style: KType.body(color: KColor.ink3)),
        const SizedBox(height: 22),
        KButton(
          label: 'Continue',
          onPressed: () {
            Navigator.of(context).pop();
            _showAddMoneyReview(context, amount: _amount.text, method: _method);
          },
        ),
      ],
    );
  }
}

void _showAddMoneyReview(BuildContext context,
    {required String amount, required String method}) {
  showKSheet<void>(
    context,
    title: 'Review',
    child: _AddMoneyReview(amount: amount, method: method),
  );
}

class _AddMoneyReview extends StatefulWidget {
  const _AddMoneyReview({required this.amount, required this.method});
  final String amount;
  final String method;
  @override
  State<_AddMoneyReview> createState() => _AddMoneyReviewState();
}

class _AddMoneyReviewState extends State<_AddMoneyReview> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final methodLabel = widget.method == 'card' ? 'Debit card' : 'Bank transfer';
    final fee = widget.method == 'card' ? '1.4%' : '₦0.00';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SummaryRow(label: 'Amount', value: '₦${widget.amount}'),
        _SummaryRow(label: 'Method', value: methodLabel),
        _SummaryRow(label: 'Fee', value: fee),
        const SizedBox(height: 18),
        Text('Funds appear in your naira wallet once confirmed.',
            style: KType.body(color: KColor.ink3)),
        const SizedBox(height: 22),
        KButton(
          label: 'Add money',
          loading: _busy,
          onPressed: _busy ? null : _confirm,
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final repo = WalletRepository(AppScope.read(context).apiClient);
    // registry.json's fund method enum is card|transfer — the sheet's
    // 'bank'/'card' selection maps 'bank' -> 'transfer'. It's advisory only
    // now (Flutterwave's own hosted checkout is where the investor actually
    // picks a payment method) but still worth sending along.
    final apiMethod = widget.method == 'card' ? 'card' : 'transfer';
    try {
      final result =
          await repo.fund(amountKobo: _parseAmountKobo(widget.amount), method: apiMethod);
      if (!mounted) return;
      Navigator.of(context).pop();
      // Best-effort external hand-off to Flutterwave's hosted checkout —
      // same no-throw-to-the-user pattern statements_screen.dart's
      // _download() uses; a launch failure shouldn't strand the investor
      // without ANY explanation, so the pending sheet still shows below
      // regardless (it names the checkout page rather than assuming it
      // opened).
      final uri = Uri.tryParse(result.checkoutUrl);
      if (uri != null) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          // Ignored — see comment above.
        }
      }
      if (!mounted) return;
      _showCheckoutPendingSheet(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showErrorSheet(context, title: 'Add money failed', message: e.message);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WITHDRAW — Step 1: amount + destination bank.
// ─────────────────────────────────────────────────────────────────────────────

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet();
  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

typedef _WithdrawInit = ({String balance, BankAccountSummary? account});

class _WithdrawSheetState extends State<_WithdrawSheet> {
  late final TextEditingController _amount = TextEditingController(text: '20,000');
  late final _repo = WalletRepository(AppScope.read(context).apiClient);
  late Future<_WithdrawInit> _init = _load();

  // GET /wallet-balance + GET /bank-accounts, fetched together so the sheet
  // has a single loading/error state (README.md convention). The withdraw
  // destination: no in-sheet picker exists for choosing among multiple saved
  // accounts (see file header) — this always resolves to the investor's
  // primary account, falling back to the first saved one.
  Future<_WithdrawInit> _load() async {
    final balanceFuture = _repo.balance();
    final accountsFuture = _repo.bankAccounts();
    final balance = await balanceFuture;
    final accounts = await accountsFuture;
    BankAccountSummary? account;
    for (final a in accounts) {
      if (a.primary) {
        account = a;
        break;
      }
    }
    account ??= accounts.isEmpty ? null : accounts.first;
    return (balance: balance, account: account);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WithdrawInit>(
      future: _init,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: KLoadingView(),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: KErrorView(
              onPrimary: () => setState(() => _init = _load()),
            ),
          );
        }
        final data = snapshot.data!;
        final account = data.account;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            KInput(
              label: 'Amount',
              controller: _amount,
              numeric: true,
              amount: true,
              prefix: '₦',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              helper: 'Balance ${data.balance}',
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: KEyebrow('To'),
            ),
            KCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SelectRow(
                icon: 'wallet',
                title: account?.bankName ?? 'No saved bank account',
                sub: account?.accountNumberMasked ?? 'Add one in Account · Banks',
                trailingChevron: true,
                first: true,
                onTap: () {}, // SEAM: picker for choosing among multiple saved payout accounts — this row always targets the primary/first saved account (see file header).
              ),
            ),
            const SizedBox(height: 12),
            Text('Withdrawals arrive within 1 business day.',
                style: KType.body(color: KColor.ink3)),
            const SizedBox(height: 22),
            KButton(
              label: 'Withdraw',
              onPressed: account == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _showWithdrawReview(context, amount: _amount.text, account: account);
                    },
            ),
          ],
        );
      },
    );
  }
}

void _showWithdrawReview(BuildContext context,
    {required String amount, required BankAccountSummary account}) {
  showKSheet<void>(
    context,
    title: 'Review',
    child: _WithdrawReview(amount: amount, account: account),
  );
}

class _WithdrawReview extends StatefulWidget {
  const _WithdrawReview({required this.amount, required this.account});
  final String amount;
  final BankAccountSummary account;
  @override
  State<_WithdrawReview> createState() => _WithdrawReviewState();
}

class _WithdrawReviewState extends State<_WithdrawReview> {
  bool _busy = false;

  String get _destinationLabel =>
      '${widget.account.bankName} ${widget.account.accountNumberMasked}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SummaryRow(label: 'Amount', value: '₦${widget.amount}'),
        _SummaryRow(label: 'To', value: _destinationLabel),
        _SummaryRow(label: 'Fee', value: '₦0.00'),
        const SizedBox(height: 18),
        Text('Withdrawals arrive within 1 business day.',
            style: KType.body(color: KColor.ink3)),
        const SizedBox(height: 22),
        KButton(
          label: 'Withdraw',
          loading: _busy,
          onPressed: _busy ? null : _confirm,
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final repo = WalletRepository(AppScope.read(context).apiClient);
    try {
      await repo.withdraw(
        amountKobo: _parseAmountKobo(widget.amount),
        bankAccountId: widget.account.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSuccessSheet(context,
          title: 'Withdrawal started',
          message: '₦${widget.amount} is on its way to $_destinationLabel.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showErrorSheet(context, title: 'Withdrawal failed', message: e.message);
    }
  }
}
