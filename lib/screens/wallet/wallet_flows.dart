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
// Add money offers TWO real funding paths (2026-08-23 — restored the card
// option after "isnt there a way we can offer two options, one for
// transfer... one for payment gateway"): _AddMoneyChooser picks between
// them, then either
//   - Bank transfer: WalletRepository.virtualAccount() (GET
//     /transactions/virtual-account), the investor's own permanent, dedicated
//     bank account (Flutterwave v4 Virtual Accounts) — _AddMoneySheet just
//     displays it with a copy button. No amount entry, no review/confirm
//     step: the investor transfers whatever they want, whenever they want,
//     from their own banking app, and the wallet balance updates once the
//     backend's webhook confirms the transfer landed.
//   - Card: WalletRepository.fund() (POST /transactions/fund) creates a
//     pending Transaction and returns a Flutterwave hosted-checkout link,
//     which _CardFundSheet opens externally (same launchUrl pattern
//     help_support_screen.dart uses) — the investor completes payment in
//     their browser/card app, and the balance updates once Flutterwave's
//     webhook confirms it server-to-server.
// Withdraw is UNCHANGED — withdrawals still go server-to-bank directly via
// v3, so its review step keeps the original immediate KStatusView success
// flow.
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
import 'package:url_launcher/url_launcher.dart';

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
    child: const _AddMoneyChooser(),
  );
}

/// Withdraw: amount + destination bank → review → success. Same gate as
/// [showAddMoneyFlow]. Outside roughly 09:00-21:00 on a weekday, spec screen
/// 63's "outside hours" variant shows instead — see [_isOutsideWithdrawHours]
/// and [_OutsideHoursWithdrawSheet].
Future<void> showWithdrawFlow(BuildContext context) async {
  if (!await _ensureEligibleToTransact(context)) return;
  if (!context.mounted) return;
  if (_isOutsideWithdrawHours()) {
    await showKSheet<void>(context, child: const _OutsideHoursWithdrawSheet());
    return;
  }
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
    this.trailingCheck = false,
    required this.first,
    this.onTap,
  });

  final String icon;
  final String title;
  final String sub;
  final bool trailingChevron;

  /// mockup-raw/s42.html's withdraw-destination row: a standalone 18px
  /// gain-toned check icon as the row's OWN trailing element (not beside
  /// [sub], and not a chevron) — the name-match confirmation.
  final bool trailingCheck;
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
                    ],
                  ),
                ],
              ),
            ),
            if (trailingCheck) KIcon('check', size: 18, color: KColor.gain),
            if (trailingChevron) KIcon('chevronRight', size: 20, color: KColor.ink3),
          ],
        ),
      ),
    );
  }
}

// Summary row for review sheets — label left, tabular value right.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.divider = true,
    this.small = false,
  });
  final String label;
  final String value;

  /// Whether this row draws its own bottom hairline — the mockup's last row
  /// in a bordered card has none. Defaults `true` (existing behaviour
  /// unchanged for every already-shipped call site).
  final bool divider;

  /// mockup-raw/s41.html's info rows use `text-data`/regular weight, not
  /// this row's original `text-body`/medium — added as an opt-in instead of
  /// changed in place so already-shipped call sites render unchanged.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final labelStyle = small ? KType.data(color: KColor.ink2) : KType.body(color: KColor.ink2);
    final valueStyle = small
        ? KType.data(color: KColor.ink)
        : KType.body(color: KColor.ink, w: KWeight.medium);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: KColor.hairline, width: 1)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle),
          Text(value, style: valueStyle.tnum),
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

/// Shown after a card-fund checkout link has been handed off to an external
/// browser/card app — the payment itself is NOT confirmed yet (that only
/// happens once Flutterwave's webhook lands, server-to-server), so this is
/// deliberately `KStatusTone.pending`, not `success`, matching
/// `_ensureEligibleToTransact`'s own use of the pending tone for an
/// in-progress, not-yet-true state.
void _showAwaitingPaymentSheet(BuildContext context) {
  showKSheet<void>(
    context,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KStatusView(
        tone: KStatusTone.pending,
        title: 'Complete your payment',
        message: 'Finish paying in the window that just opened. Your '
            'balance updates here as soon as we confirm it.',
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
// ADD MONEY — Step 0: choose a funding path (see file header).
// ─────────────────────────────────────────────────────────────────────────────

class _AddMoneyChooser extends StatelessWidget {
  const _AddMoneyChooser();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _SelectRow(
                icon: 'wallet',
                title: 'Bank transfer',
                sub: 'Free · usually under 5 minutes',
                trailingChevron: true,
                first: true,
                onTap: () {
                  Navigator.of(context).pop();
                  showKSheet<void>(
                    context,
                    title: 'Bank transfer',
                    child: const _AddMoneySheet(),
                  );
                },
              ),
              _SelectRow(
                icon: 'card',
                title: 'Debit or credit card',
                sub: 'Instant, via Flutterwave',
                trailingChevron: true,
                first: false,
                onTap: () {
                  Navigator.of(context).pop();
                  showKSheet<void>(
                    context,
                    title: 'Add money by card',
                    child: const _CardFundSheet(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD MONEY — Card: amount entry → Flutterwave hosted checkout (external).
// ─────────────────────────────────────────────────────────────────────────────

class _CardFundSheet extends StatefulWidget {
  const _CardFundSheet();
  @override
  State<_CardFundSheet> createState() => _CardFundSheetState();
}

class _CardFundSheetState extends State<_CardFundSheet> {
  late final TextEditingController _amount = TextEditingController(text: '20,000');
  bool _busy = false;
  String? _amountError;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final amountKobo = _parseAmountKobo(_amount.text);
    if (amountKobo <= 0) {
      setState(() => _amountError = 'Enter an amount to continue');
      return;
    }
    setState(() {
      _amountError = null;
      _busy = true;
    });
    final repo = WalletRepository(AppScope.read(context).apiClient);
    try {
      final result = await repo.fund(amountKobo: amountKobo, method: 'card');
      // A checkout link failure on the backend (Flutterwave unreachable/
      // rejected) comes back as an empty string, NOT a thrown ApiException —
      // `Uri.tryParse('')` returns a valid EMPTY Uri, not null, so checking
      // for null alone here would silently "succeed" at launching nothing.
      final url = result.checkoutUrl;
      final uri = url.isEmpty ? null : Uri.tryParse(url);
      final launched = uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          await _launchExternally(uri);
      if (!mounted) return;
      if (!launched) {
        setState(() => _busy = false);
        _showErrorSheet(
          context,
          title: 'Could not open checkout',
          message: "We couldn't open a payment window. Please try again.",
        );
        return;
      }
      Navigator.of(context).pop();
      _showAwaitingPaymentSheet(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showErrorSheet(context, title: 'Could not start payment', message: e.message);
    }
  }

  /// launchUrl() can fail two ways: throwing (no app/browser can handle the
  /// scheme) or just returning false — checking only for a thrown exception,
  /// as this sheet originally did, misses the second case entirely.
  Future<bool> _launchExternally(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
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
          error: _amountError,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 16),
        Text(
          "You'll pay by card on Flutterwave's secure checkout page — your "
          'balance updates here once the payment is confirmed.',
          style: KType.body(color: KColor.ink3),
        ),
        const SizedBox(height: 22),
        KButton(
          label: 'Continue to payment',
          loading: _busy,
          onPressed: _busy ? null : _continue,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD MONEY — Bank transfer: the investor's dedicated funding account (no
// amount entry, no review/confirm step — see file header).
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
                  // mockup-raw/s41.html line 9: just the number, no inline
                  // "Copy" pill inside the plate — that action lives in the
                  // "Copy number" button below (was a duplicate control not
                  // in the design).
                  Text(
                    account.accountNumber,
                    // 30px/800/-0.02em — bigger and heavier than
                    // KType.title's 26px/700/-0.02em role.
                    style: KType.title(color: KColor.featureInk)
                        .copyWith(fontSize: 30, fontWeight: KWeight.black, letterSpacing: -0.6)
                        .tnum,
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
            // mockup-raw/s41.html line 12: "Copy number" / "Share details"
            // sit directly under the plate, BEFORE the info rows — was
            // ordered after the footnote, past the info card.
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: KButton(
                    label: 'Copy number',
                    variant: KButtonVariant.secondary,
                    size: KButtonSize.md,
                    iconLeft: 'card',
                    onPressed: () => _copy(account.accountNumber),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KButton(
                    label: 'Share details',
                    variant: KButtonVariant.secondary,
                    size: KButtonSize.md,
                    iconLeft: 'send',
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
            const SizedBox(height: 14),
            // Info rows (spec 41) — all three are real, fixed facts about
            // this funding path (a dedicated Flutterwave virtual account),
            // not placeholders. mockup-raw/s41.html line 16: wrapped in its
            // own bordered card — was floating loose with no card at all.
            Container(
              decoration: BoxDecoration(
                color: KColor.bg,
                border: Border.all(color: KColor.hairline, width: 1),
                borderRadius: KRadii.cardR,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _SummaryRow(label: 'Transfer fee', value: 'Free', small: true),
                  _SummaryRow(label: 'Arrives', value: 'Usually under 5 minutes', small: true),
                  _SummaryRow(
                      label: 'Send from',
                      value: 'Any account in your name',
                      small: true,
                      divider: false),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Money sent from an account that isn't yours is returned — the "
              'names must match.',
              style: KType.body(color: KColor.ink3),
            ),
            const SizedBox(height: 16),
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
              // mockup-raw/s42.html line 7: no label prop on this Input.
              controller: _amount,
              numeric: true,
              amount: true,
              prefix: '₦',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              // Rebuilds "You receive" below as the investor types.
              onChanged: (_) => setState(() {}),
              // Spec 42: "₦214,300.00 available · minimum ₦1,000 out" — the
              // "minimum ₦1,000" half is dropped deliberately: the backend's
              // real validation (WithdrawDto) only enforces amountKobo >= 1
              // kobo, no ₦1,000 floor. Showing a specific minimum the
              // backend doesn't actually enforce would be its own kind of
              // inexact — a rule a user could disprove by trying ₦500.
              helper: '${data.balance} available',
            ),
            const SizedBox(height: 14),
            // No "To" eyebrow label here (mockup-raw/s42.html) — the
            // destination row sits directly under the amount input. bg
            // (not paper) background, 14px/16px padding, per line 8 — was
            // paper (KCard's default) with 16px horizontal only.
            KCard(
              color: KColor.bg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: _SelectRow(
                icon: 'wallet',
                // "GTB ••••6789 · DCS account" (spec 42) — DCS accounts are
                // always the investor's own name-matched settlement account,
                // so the qualifier is accurate for every saved account here,
                // not just one particular one.
                title: account == null
                    ? 'No saved bank account'
                    : '${account.bankName} ${account.accountNumberMasked} · DCS account',
                // "Adebayo Okonkwo" (spec 42) — a DCS account is required to
                // be in the investor's own name (enforced at add-time), so
                // the signed-in investor's real fullName is a true fact
                // about whichever account this resolves to. The standalone
                // 18px gain check (spec 42's trailing element, not a
                // chevron) only makes sense once a real, verified account is
                // resolved; the "no saved account" case keeps the chevron
                // affordance routing to add one instead.
                sub: account == null ? 'Tap to add one' : data.holderName,
                trailingCheck: account != null,
                trailingChevron: account == null,
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
            const SizedBox(height: 14),
            // mockup-raw/s42.html lines 13-16: Fee/Arrives/You-receive
            // breakdown card — was dropped entirely on a claim that it
            // needed data this backend can't compute, but Fee is already
            // established elsewhere in this very file (_WithdrawReview
            // below) as a real, known fact: ₦0.00, no fee concept exists
            // anywhere in the Transaction model. "You receive" is therefore
            // just the entered amount — not fabricated, a direct
            // consequence of that same known fact.
            Container(
              decoration: BoxDecoration(
                color: KColor.bg,
                border: Border.all(color: KColor.hairline, width: 1),
                borderRadius: KRadii.cardR,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _SummaryRow(label: 'Fee', value: '₦0.00', small: true),
                  _SummaryRow(
                      label: 'Arrives', value: 'Within 1 business day', small: true, divider: false),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('You receive', style: KType.cardTitle()),
                        Text('₦${_amount.text}', style: KType.cardTitle().tnum),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // "Your passcode confirms this withdrawal" (spec 42's footnote)
            // — dropped: there is no passcode-reentry step anywhere in this
            // flow (see _WithdrawReview._confirm below), so that clause is a
            // false security claim, not just an inexact one. Was kept here
            // verbatim even though the identical claim was already found and
            // dropped from _WithdrawReview's own footnote.
            Text(
              'Money from a sale is available after it settles on T+3.',
              style: KType.body(color: KColor.ink3),
            ),
            const SizedBox(height: 16),
            // "Cancel" / "Review" (spec 42) — was a single "Withdraw" button
            // that skipped straight past the review step's own confirmation.
            // Cancel is a fixed-width ghost button (hint-size "100px,50px"),
            // not full-width like Review — was stretching both equally.
            Row(
              children: [
                KButton(
                  label: 'Cancel',
                  variant: KButtonVariant.ghost,
                  fullWidth: false,
                  onPressed: () => Navigator.of(context).pop(),
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

// ─────────────────────────────────────────────────────────────────────────────
// WITHDRAW — outside-hours variant (spec screen 63, 2026-08-23 "Soft
// Landing" exactness pass — Flow G was entirely unbuilt until now).
//
// REAL BACKEND GAP, flagged rather than faked: WalletRepository.withdraw()
// (POST /transactions/withdraw) has no queuing/scheduling concept — this
// file's own header already documents "Withdraw is UNCHANGED — withdrawals
// still go server-to-bank directly via v3", i.e. no off-hours-vs-daytime
// branching exists server-side. So this sheet does NOT claim spec 63's
// literal "Sent to your bank · Tomorrow from 09:00" — that promises a
// specific processing time nothing server-side actually commits to. It
// keeps the honest "Within 1 business day" wording the normal withdraw
// review already uses (_WithdrawReview above), and "Queue it for 09:00"
// submits the SAME real withdraw() call right away — a transfer initiated
// at night genuinely does land the next business day anyway, so the framing
// is honest; only the literal "09:00" clock promise is dropped. Fee is
// genuinely ₦0.00, same established fact as the normal withdraw flow (no
// fee concept exists anywhere in this backend's Transaction model) — spec
// 63's "₦50.00" is mock example data, not a real rate.
//
// Trigger: outside a rough 09:00-21:00 weekday window, client-clock only —
// same class of heuristic as market_hours.dart's isNgxOpenNow(), not
// authoritative bank-processing-window data (no such field exists in this
// API). Spec 63's footer third trigger, "...or with unsettled cash", is
// shown as CONTEXT inside the sheet (the settling-amount line, whenever
// [WalletRepository.balanceDetail]'s `pending` is non-null) rather than a
// second independent trigger — modelling "does THIS entered amount touch
// unsettled cash" before the amount is even typed would itself be a
// fabricated distinction.
//
// No destination-bank row here, matching s63.html exactly (unlike s42's
// _WithdrawSheet above, this sheet's markup never shows one) — it resolves
// to the same primary/first saved account [_WithdrawSheet] does, silently,
// same documented picker-UI gap as this file's header.
//
// "Queue -> 43 Transaction" (spec footer): on success this pushes straight
// to the real transaction-detail screen instead of a generic success sheet,
// matching that nav note.
// ─────────────────────────────────────────────────────────────────────────────

bool _isOutsideWithdrawHours() {
  final now = DateTime.now();
  if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) return true;
  final minutes = now.hour * 60 + now.minute;
  return minutes < 9 * 60 || minutes >= 21 * 60;
}

typedef _OutsideHoursInit = ({String available, String? pending, BankAccountSummary? account});

class _OutsideHoursWithdrawSheet extends StatefulWidget {
  const _OutsideHoursWithdrawSheet();
  @override
  State<_OutsideHoursWithdrawSheet> createState() => _OutsideHoursWithdrawSheetState();
}

class _OutsideHoursWithdrawSheetState extends State<_OutsideHoursWithdrawSheet> {
  late final TextEditingController _amount = TextEditingController(text: '20,000');
  late final _repo = WalletRepository(AppScope.read(context).apiClient);
  late Future<_OutsideHoursInit> _init = _load();
  bool _busy = false;
  String? _error;

  Future<_OutsideHoursInit> _load() async {
    final (detail, accounts) = await (_repo.balanceDetail(), _repo.bankAccounts()).wait;
    BankAccountSummary? account;
    for (final a in accounts) {
      if (a.primary) {
        account = a;
        break;
      }
    }
    account ??= accounts.isEmpty ? null : accounts.first;
    return (available: detail.available, pending: detail.pending, account: account);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String get _requestedAtLabel {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return 'Today · $hh:$mm';
  }

  Future<void> _confirm(BankAccountSummary account) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final txn = await _repo.withdraw(
        amountKobo: _parseAmountKobo(_amount.text),
        bankAccountId: account.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push(Routes.transactionDetail(txn.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OutsideHoursInit>(
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
            child: KErrorView(onPrimary: () => setState(() => _init = _load())),
          );
        }
        final data = snapshot.data!;
        final account = data.account;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // s63.html: "Withdraw" + the "Queued for morning" pill share one
            // row — the sheet is opened untitled and this row built
            // explicitly, same pattern as trade_flows.dart's market-closed
            // buy sheet.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Withdraw', style: KType.section()),
                const KStatusPill(status: KStatus.pending, label: 'Queued for morning', small: true),
              ],
            ),
            const SizedBox(height: 14),
            KInput(
              label: 'Amount',
              controller: _amount,
              numeric: true,
              amount: true,
              prefix: '₦',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              helper: data.pending != null
                  ? '${data.available} available · ${data.pending} of it still settling'
                  : '${data.available} available',
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: KColor.bg,
                border: Border.all(color: KColor.hairline, width: 1),
                borderRadius: KRadii.cardR,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _SummaryRow(label: 'Requested', value: _requestedAtLabel),
                  // Honest wording — see this section's header comment for
                  // why this isn't spec 63's literal "Tomorrow from 09:00".
                  _SummaryRow(label: 'Sent to your bank', value: 'Within 1 business day'),
                  _SummaryRow(label: 'Fee', value: '₦0.00'),
                  _SummaryRow(label: 'You receive', value: '₦${_amount.text}'),
                ],
              ),
            ),
            if (data.pending != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: KColor.sunTint, borderRadius: KRadii.cardR),
                child: Text(
                  "${data.pending} of your balance is still settling and can't be withdrawn "
                  'until it clears — usually T+3 after a sale.',
                  style: KType.data(color: KColor.ink2),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: KType.body(color: KColor.loss)),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: KButton(
                    label: 'Cancel',
                    variant: KButtonVariant.ghost,
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KButton(
                    label: 'Queue it for 09:00',
                    loading: _busy,
                    onPressed: account == null || _busy ? null : () => _confirm(account),
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
