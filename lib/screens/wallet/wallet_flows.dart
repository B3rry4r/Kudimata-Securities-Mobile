// Kudimata Invest — Stage 8: Wallet money-movement flows as bottom sheets.
// Mirrors wallet-screens.jsx (AddMoney / Withdraw) as showKSheet
// sequences: amount → method/bank → review → KStatusView success. The
// launching wallet screen stays behind the scrim.
//
// Wired per lib/data/api/README.md. Withdraw's review step calls
// WalletRepository.withdraw() (POST /transactions/withdraw) same as before.
// On ApiException from the call itself (e.g. a real 422 for insufficient
// balance) an error variant of the KStatusView sheet shows, and the review
// step is left in place (not popped) so the user can retry without
// re-entering anything.
//
// Add money (2026-08-07, backend supersedes.json S-8): no longer a
// checkout-link redirect. WalletRepository.virtualAccount() (GET
// /transactions/virtual-account) returns the investor's own permanent,
// dedicated bank account (Flutterwave v4 Virtual Accounts) — _AddMoneySheet
// just displays it with a copy button. No amount entry, no method choice,
// no review/confirm step: the investor transfers whatever they want,
// whenever they want, from their own banking app, and the wallet balance
// updates once the backend's webhook confirms the transfer landed (same
// "check back later / pull to refresh" pattern the old pending-checkout
// sheet used, just without ever leaving this app). Withdraw is UNCHANGED —
// withdrawals still go server-to-bank directly via v3, so its review step
// keeps the original immediate KStatusView success flow.
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
// screen; adding/choosing others requires the account-banks screen. When
// there are NO saved accounts at all, the row routes there instead of
// sitting inert (2026-08-07 — previously a no-op, so an investor with no
// bank account had no way forward from this sheet).
//
// NGX-only: the Convert (₦ → $) flow was removed — Blue Marina supplies NGX
// equities only, and Convert existed solely to fund USD stock buys.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/bank_accounts_repository.dart'
    show BankAccountSummary;
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/data/repositories/wallet_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public flow launchers (cross-stage contract — see BUILD_CONTRACT.md §d).
// ─────────────────────────────────────────────────────────────────────────────

/// Add money: amount + method → review → success. Gated on
/// [tradingEligibilityGap]. browsing the Wallet tab never requires
/// KYC/suitability, only actually funding does (also enforced server-side,
/// TransactionsService.assertEligibleToTransact, since this check alone is
/// bypassable).
Future<void> showAddMoneyFlow(BuildContext context) async {
  if (!await _ensureEligibleToTransact(context)) return;
  if (!context.mounted) return;
  await showKSheet<void>(
    context,
    title: 'Add money',
    child: const _AddMoneySheet(),
  );
}

/// Withdraw: amount + destination bank → review → success. Same gate as
/// [showAddMoneyFlow].
Future<void> showWithdrawFlow(BuildContext context) async {
  if (!await _ensureEligibleToTransact(context)) return;
  if (!context.mounted) return;
  await showKSheet<void>(
    context,
    title: 'Withdraw',
    child: const _WithdrawSheet(),
  );
}

/// Shows a sheet pointing the investor at whichever KYC/suitability step
/// they're missing instead of opening the fund/withdraw sheet. Returns true
/// (no sheet shown) once they're actually eligible. Mirrors
/// trade_flows.dart's `_ensureEligibleToTrade` (duplicated rather than
/// shared per this codebase's per-module convention).
Future<bool> _ensureEligibleToTransact(BuildContext context) async {
  final gap = tradingEligibilityGap(AppScope.read(context));
  if (gap == null) return true;
  await showKSheet<void>(
    context,
    child: KStatusView(
      tone: KStatusTone.pending,
      title: gap.title,
      message: gap.message,
      primary: 'Continue',
      onPrimary: () {
        Navigator.of(context).pop();
        context.push(gap.route);
      },
      secondary: 'Not now',
      onSecondary: () => Navigator.of(context).pop(),
    ),
  );
  return false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared bits.
// ─────────────────────────────────────────────────────────────────────────────

// A selectable row inside a hairline card (method / destination).
class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.icon,
    required this.title,
    required this.sub,
    this.trailingChevron = false,
    this.subVerified = false,
    required this.first,
    this.onTap,
  });

  final String icon;
  final String title;
  final String sub;
  final bool trailingChevron;

  /// A small gain-toned check icon beside [sub] — spec 42's "Adebayo
  /// Okonkwo (check icon)" name-match confirmation on the withdraw
  /// destination row.
  final bool subVerified;
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(sub,
                            style: KType.micro(color: KColor.ink3)
                                .copyWith(letterSpacing: 0.04 * 10, height: 15 / 10)
                                .tnum),
                      ),
                      if (subVerified) ...[
                        const SizedBox(width: 4),
                        KIcon('check', size: 12, color: KColor.gain),
                      ],
                    ],
                  ),
                ],
              ),
            ),
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

// ─────────────────────────────────────────────────────────────────────────────
// ADD MONEY — the investor's dedicated funding account (no amount/method
// entry, no review/confirm step — see file header).
// ─────────────────────────────────────────────────────────────────────────────

class _AddMoneySheet extends StatefulWidget {
  const _AddMoneySheet();
  @override
  State<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends State<_AddMoneySheet> {
  late final _repo = WalletRepository(AppScope.read(context).apiClient);
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);

  /// Spec 41's plate shows "Providus Bank · Adebayo Okonkwo" — a real
  /// account-holder name — but `VirtualAccountDetails` (GET
  /// /transactions/virtual-account) only ever carries accountNumber/bankName,
  /// no holder-name field (checked against the backend's actual wire type,
  /// common/types/transaction.types.ts's VirtualAccount). Flutterwave opens
  /// this account in the signed-in investor's own name, though, so joining
  /// it with GET /users/me's real fullName is a true fact about this
  /// specific account, not an invented one — same one extra call
  /// account_screen.dart already makes for its own profile header.
  late Future<({VirtualAccountDetails account, String holderName})> _future = _load();

  Future<({VirtualAccountDetails account, String holderName})> _load() async {
    final (account, profile) = await (_repo.virtualAccount(), _userRepo.me()).wait;
    return (account: account, holderName: profile.fullName);
  }

  Future<void> _copy(String accountNumber) async {
    await Clipboard.setData(ClipboardData(text: accountNumber));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account number copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({VirtualAccountDetails account, String holderName})>(
      future: _future,
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
              onPrimary: () => setState(() => _future = _load()),
            ),
          );
        }
        final data = snapshot.data!;
        final account = data.account;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Full grape "feature plate" (2026-08-22 "Soft Landing" —
            // screen-specs.md #41's colour note: same treatment as the
            // Splash screen, reused for the single most important piece of
            // data on this sheet — the virtual account number).
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: KColor.feature, borderRadius: KRadii.featureR),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Your account number'.upper,
                      style: KType.label(color: KColor.sun)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(account.accountNumber,
                            style: KType.title(color: KColor.featureInk).tnum),
                      ),
                      GestureDetector(
                        onTap: () => _copy(account.accountNumber),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0x29FFFFFF),
                            borderRadius: KRadii.pillR,
                          ),
                          child: Text('Copy',
                              style: KType.label(color: KColor.featureInk)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // "Providus Bank · Adebayo Okonkwo" (spec #41) —
                  // VirtualAccountDetails itself has no holder-name field
                  // (checked against the backend's real wire type), but a
                  // Flutterwave virtual account is always opened in the
                  // signed-in investor's own name, so joining GET /users/me's
                  // real fullName here is a true fact, not an invented one.
                  Text('${account.bankName} · ${data.holderName}',
                      style: KType.body(color: KColor.featureInk2)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Info rows (spec 41) — all three are real, fixed facts about
            // this funding path (a dedicated Flutterwave virtual account),
            // not placeholders.
            _SummaryRow(label: 'Transfer fee', value: 'Free'),
            _SummaryRow(label: 'Arrives', value: 'Usually under 5 minutes'),
            _SummaryRow(label: 'Send from', value: 'Any account in your name'),
            const SizedBox(height: 18),
            Text(
              "Money sent from an account that isn't yours is returned — the "
              'NGX requires the names to match.',
              style: KType.body(color: KColor.ink3),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: KButton(
                    label: 'Copy number',
                    variant: KButtonVariant.secondary,
                    onPressed: () => _copy(account.accountNumber),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KButton(
                    label: 'Share details',
                    variant: KButtonVariant.secondary,
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text: 'Send money to my Kudimata Invest account: '
                            '${account.accountNumber}, ${account.bankName} '
                            '(${data.holderName}).',
                        subject: 'My Kudimata Invest funding account',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            KButton(
              label: "I've sent it",
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
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

typedef _WithdrawInit = ({String balance, BankAccountSummary? account, String holderName});

class _WithdrawSheetState extends State<_WithdrawSheet> {
  late final TextEditingController _amount = TextEditingController(text: '20,000');
  late final _repo = WalletRepository(AppScope.read(context).apiClient);
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);
  late Future<_WithdrawInit> _init = _load();

  // GET /wallet-balance + GET /bank-accounts + GET /users/me, fetched
  // together so the sheet has a single loading/error state (README.md
  // convention). The withdraw destination: no in-sheet picker exists for
  // choosing among multiple saved accounts (see file header) — this always
  // resolves to the investor's primary account, falling back to the first
  // saved one. `holderName`: a DCS bank account is required to be in the
  // investor's own name (BankAccountsService enforces this at add-time), so
  // the signed-in investor's real fullName is a true fact about whichever
  // account this resolves to, not an invented one — same join
  // wallet_flows.dart's Add Money sheet already makes.
  Future<_WithdrawInit> _load() async {
    final (balance, accounts, profile) =
        await (_repo.balance(), _repo.bankAccounts(), _userRepo.me()).wait;
    BankAccountSummary? account;
    for (final a in accounts) {
      if (a.primary) {
        account = a;
        break;
      }
    }
    account ??= accounts.isEmpty ? null : accounts.first;
    return (balance: balance, account: account, holderName: profile.fullName);
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
              // Spec 42: "₦214,300.00 available · minimum ₦1,000 out" — the
              // "minimum ₦1,000" half is dropped deliberately: the backend's
              // real validation (WithdrawDto) only enforces amountKobo >= 1
              // kobo, no ₦1,000 floor. Showing a specific minimum the
              // backend doesn't actually enforce would be its own kind of
              // inexact — a rule a user could disprove by trying ₦500.
              helper: '${data.balance} available',
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
                // "GTB ••••6789 · DCS account" (spec 42) — DCS accounts are
                // always the investor's own name-matched settlement account,
                // so the qualifier is accurate for every saved account here,
                // not just one particular one.
                title: account == null
                    ? 'No saved bank account'
                    : '${account.bankName} ${account.accountNumberMasked} · DCS account',
                // "Adebayo Okonkwo" + check icon (spec 42) — a DCS account is
                // required to be in the investor's own name (enforced at
                // add-time), so the signed-in investor's real fullName is a
                // true fact about whichever account this resolves to.
                sub: account == null ? 'Tap to add one' : data.holderName,
                subVerified: account != null,
                trailingChevron: true,
                first: true,
                // No saved account: routes to the add-bank-account screen
                // instead of sitting inert. With a saved account, this row
                // still has no picker for choosing among multiple saved
                // payout accounts (see file header) — it always targets the
                // primary/first one.
                onTap: account == null
                    ? () {
                        Navigator.of(context).pop();
                        context.push(Routes.acctBanks);
                      }
                    : () {},
              ),
            ),
            const SizedBox(height: 12),
            Text('Withdrawals arrive within 1 business day.',
                style: KType.body(color: KColor.ink3)),
            const SizedBox(height: 22),
            // "Cancel" / "Review" (spec 42) — was a single "Withdraw" button
            // that skipped straight past the review step's own confirmation.
            Row(
              children: [
                Expanded(
                  child: KButton(
                    label: 'Cancel',
                    variant: KButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KButton(
                    label: 'Review',
                    onPressed: account == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            _showWithdrawReview(context,
                                amount: _amount.text, account: account, holderName: data.holderName);
                          },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

void _showWithdrawReview(BuildContext context,
    {required String amount, required BankAccountSummary account, required String holderName}) {
  showKSheet<void>(
    context,
    title: 'Review',
    child: _WithdrawReview(amount: amount, account: account, holderName: holderName),
  );
}

class _WithdrawReview extends StatefulWidget {
  const _WithdrawReview({required this.amount, required this.account, required this.holderName});
  final String amount;
  final BankAccountSummary account;
  final String holderName;
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
        // Fee/Arrives/You receive (spec 42) — Fee is genuinely ₦0.00 (no fee
        // concept exists anywhere in the backend's Transaction model, so
        // this isn't a placeholder, it's the real answer), "You receive" is
        // therefore always the full requested amount.
        _SummaryRow(label: 'Fee', value: '₦0.00'),
        _SummaryRow(label: 'Arrives', value: 'Within 1 business day'),
        _SummaryRow(label: 'You receive', value: '₦${widget.amount}'),
        const SizedBox(height: 18),
        // Spec 42's exact footnote also claims "Your passcode confirms this
        // withdrawal" — dropped: there is no passcode-reentry step anywhere
        // in this flow (see _confirm() below), so that clause describes a
        // control this build doesn't actually have. Copying it verbatim
        // would be a false security claim, not just an inexact one.
        Text(
          'Money from a sale is available after it settles on T+3.',
          style: KType.body(color: KColor.ink3),
        ),
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
