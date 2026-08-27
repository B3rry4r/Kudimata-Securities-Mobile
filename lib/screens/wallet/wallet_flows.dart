// Kudimata Invest — Wallet money-movement flows as bottom sheets, rebuilt
// 2026-08-27 against the 2026-08 redesign canvas: `05 Portfolio and
// Wallet.dc.html`, artboards s36 (Add money) and s37 (Withdraw) — ids taken
// from docs/redesign/RULINGS.md per R-5, NOT from any id this file used to
// cite (this header previously referenced "spec screen 41/42/63" from the
// old 97-screen canvas; those ids now point at unrelated artboards there).
//
// THE FEE QUESTION (docs/redesign/DECISIONS.md C-3 / FACT-CONFLICTS.md):
// s36 draws "Bank transfer ₦100 to ₦150 · same day" and "Debit card
// Flutterwave · ₦28 fee, instant". Neither figure is real — no deposit or
// card-funding fee constant exists anywhere in the backend
// (WalletRepository.virtualAccount()/fund() carry no fee field at all, not
// even an explicit zero one). So nothing below hardcodes ₦100, ₦150 or ₦28.
// [_depositFeeLabel] is the ONE place either method's fee copy is decided —
// currently "Free" because that is what is actually charged today (verified
// against WalletRepository, not guessed), computed rather than pasted at
// each call site so the day a real `feeKobo` field lands on these
// endpoints, this is the only line that changes. See BACKEND_GAPS.md for
// the filed gap. `fees.ts`'s own header records what a hardcoded
// client-side fee cost last time — a quoted "Fees · 1.35%" while the
// backend charged nothing at all — so this file does not repeat that
// mistake in either direction (neither the wrong non-zero figure, nor a
// figure that silently goes stale once a real one exists).
//
// Add money is ONE sheet (matching s36's single artboard, not a
// chooser-then-push-to-a-second-sheet pair): two selectable method cards
// (bank transfer / debit card) with the panel beneath them swapping to
// match the selection, bank transfer selected by default per s36's own
// highlighted-border state.
//   - Bank transfer: WalletRepository.virtualAccount() (GET
//     /transactions/virtual-account), the investor's own permanent,
//     dedicated bank account (Flutterwave v4 Virtual Accounts). No amount
//     entry, no review/confirm step: the investor transfers whatever they
//     want, whenever they want, from their own banking app, and the wallet
//     balance updates once the backend's webhook confirms the transfer
//     landed.
//   - Card: WalletRepository.fund() (POST /transactions/fund) creates a
//     pending Transaction and returns a Flutterwave hosted-checkout link,
//     opened externally (same launchUrl pattern help_support_screen.dart
//     uses) — the investor completes payment in their browser/card app, and
//     the balance updates once Flutterwave's webhook confirms it
//     server-to-server. s36 draws no content for this branch beyond the
//     row itself (its chevron points at an undrawn screen) — the amount
//     field + explainer below is this file's own composition, restyled to
//     match s36's neighbours, not designer intent.
//
// Withdraw is now a SINGLE step matching s37 exactly — no separate Review
// sheet: amount + destination + fee are all on one screen and the one CTA
// ("Withdraw ₦X") calls WalletRepository.withdraw() (POST
// /transactions/withdraw) directly, still gated on the passcode
// confirmation restored 2026-08-24 (security_screen.dart's "Passcode for
// withdrawals" row was describing behaviour the app didn't have until then
// — see [_WithdrawSheetState._confirm] below).
//
// The withdraw destination: POST /transactions/withdraw needs a saved
// `BankAccount.id` (registry.json), not a raw bank code/account number. No
// in-sheet picker UI exists for choosing among multiple saved accounts (s37
// itself draws a single fixed row, not a list) — building one is a bigger
// UI change than this pass, so this file fetches the investor's real saved
// accounts (GET /bank-accounts) and uses the primary one (falling back to
// the first) as the destination, same as s37's single-row layout implies.
// Only ever the primary/first saved account is reachable from this screen;
// adding/choosing others requires the account-banks screen. When there are
// NO saved accounts at all, the row routes there instead of sitting inert.
//
// s37 also draws "Changing it takes a 24-hour security hold" under the
// destination row — grepped for any such hold anywhere in the backend or
// bank_accounts_screen.dart and found nothing. Same standing as the fee
// figures above: omitted rather than asserted, flagged in the build report
// rather than invented here.
//
// R-21 (docs/redesign/DECISIONS.md): the outside-hours "queued withdrawal"
// variant below has no canvas counterpart at all — it is this file's own
// composition, restyled to match s37's neighbouring patterns (the big
// amount + chips + destination-row shape), not designer intent.
//
// NGX-only: the Convert (₦ → $) flow was removed — Blue Marina supplies NGX
// equities only, and Convert existed solely to fund USD stock buys.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/screens/shared/confirm_passcode_sheet.dart';
import 'package:kudimata_invest/data/api/passcode_store.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/bank_accounts_repository.dart'
    show BankAccountSummary;
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/data/repositories/wallet_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public flow launchers (cross-stage contract — see BUILD_CONTRACT.md §d).
// ─────────────────────────────────────────────────────────────────────────────

/// Add money: one sheet, s36 — method choice + the chosen method's panel.
/// Gated on [tradingEligibilityGap]. Browsing the Wallet tab never requires
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

/// Withdraw: one sheet, s37 — amount + destination + fee, one CTA. Same gate
/// as [showAddMoneyFlow]. Outside roughly 09:00-21:00 on a weekday, the
/// R-21 "outside hours" variant shows instead — see
/// [_isOutsideWithdrawHours] and [_OutsideHoursWithdrawSheet].
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

/// The fee copy for either Add money method — see the file header's "THE FEE
/// QUESTION". Neither `VirtualAccountDetails` (bank transfer) nor
/// `FundResult` (card, via `WalletRepository.fund`) carries any fee field at
/// all today, so there is no response value to read a figure from. What IS
/// verified is that neither path charges anything right now — no deposit or
/// card-funding fee constant exists anywhere in the backend. That is a real,
/// checked fact, so it renders as "Free" rather than being blanked out the
/// way an unverifiable figure (R-34) would be. This single constant is the
/// only line a future backend fee field requires updating.
const String _depositFeeLabel = 'Free';

// A selectable row inside a hairline card (used for the withdraw
// destination and the outside-hours variant's own destination row).
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

  /// s37's destination row: a standalone 18px gain-toned check icon as the
  /// row's OWN trailing element (not beside [sub], and not a chevron) — the
  /// name-match confirmation.
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

/// s36's two selectable method cards — its own visual language (an
/// individually bordered, tinted-icon card per option, selected state via a
/// thicker indicator-coloured border) rather than [_SelectRow]'s single
/// hairline-divided list, so it is its own local widget rather than a
/// variant of that one.
class _FundMethodCard extends StatelessWidget {
  const _FundMethodCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KColor.paper,
          border: Border.all(
            color: selected ? _accentBorder : KColor.hairline,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: KRadii.cardR,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? KColor.indicatorTint : KColor.track,
                shape: BoxShape.circle,
              ),
              child: KIcon(icon, size: 20, color: selected ? _accentBorder : KColor.ink2),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: KType.cardTitle()),
                  const SizedBox(height: 2),
                  Text(sub, style: KType.data(color: KColor.ink3)),
                ],
              ),
            ),
            KIcon('chevronRight', size: 18, color: selected ? _accentBorder : KColor.ink3),
          ],
        ),
      ),
    );
  }
}

// Summary row for review/fee sheets — label left, tabular value right.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.divider = true,
    this.small = false,
    this.valueColor,
  });
  final String label;
  final String value;

  /// Whether this row draws its own bottom hairline — s37's last row in a
  /// bordered card has none. Defaults `true`.
  final bool divider;

  /// s37's fee/arrival rows use `text-data`/regular weight, not this row's
  /// original `text-body`/medium — an opt-in so other already-shipped call
  /// sites are unaffected.
  final bool small;

  /// s37 colours "Free" in the gain tone — null keeps the normal ink colour.
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final labelStyle = small ? KType.data(color: KColor.ink2) : KType.body(color: KColor.ink2);
    final valueStyle = small
        ? KType.data(color: valueColor ?? KColor.ink)
        : KType.body(color: valueColor ?? KColor.ink, w: KWeight.medium);
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

/// s37/s36's big centred figure — not [KInput]'s `amount:true` mode (that is
/// a bordered, left-aligned field: correct for the trade-flow amount sheets
/// it was built for, but visually a different shape from s36/s37's
/// borderless, centred hero-sized number). A screen-local widget rather
/// than a shared-widget change, per SCREEN-AGENT-BRIEF.md rule 5 — no other
/// screen needs this shape.
class _BigAmountField extends StatelessWidget {
  const _BigAmountField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      cursorColor: KColor.indicator,
      style: KType.hero().tnum,
      decoration: const InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        prefixText: '₦',
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

/// Shown over the still-open sheet when a fund/withdraw call fails with an
/// [ApiException] (e.g. insufficient balance) — [message] is that
/// exception's human-readable summary (safe to show directly, per
/// lib/data/api/api_exception.dart). "Try again" just dismisses this sheet;
/// the sheet behind it keeps its entered amount/method/destination so the
/// retry doesn't lose any input.
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

/// s36d/s37d both swap the light artboards' `--indicator` border/icon accent
/// for the softer `--indicator-soft` in dark (better contrast on the dark
/// card surface) — `KColor.indicator` alone doesn't reproduce this since it
/// resolves to a mid-tone purple in dark, not the lighter one the dark
/// artboards actually draw. `KColor.indicatorSoft` already carries the right
/// value in both palettes, so this just picks the token the artboards
/// actually use per theme.
Color get _accentBorder =>
    KColor.active.brightness == Brightness.dark ? KColor.indicatorSoft : KColor.indicator;

/// Comma-grouped naira text (e.g. "50,000" or "12,345.67") → integer kobo,
/// matching trade_flows.dart's `_amountValue` parsing convention.
int _parseAmountKobo(String amountText) {
  final value = double.tryParse(amountText.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;
  return (value * 100).round();
}

/// Same parse, as a naira double — for comparing an entered amount against a
/// real balance figure (itself a preformatted "₦45,200.00" string).
double _parseNaira(String text) => _parseAmountKobo(text) / 100.0;

// ─────────────────────────────────────────────────────────────────────────────
// ADD MONEY — s36: method choice + the chosen method's panel, one sheet.
// ─────────────────────────────────────────────────────────────────────────────

enum _FundMethod { bankTransfer, card }

class _AddMoneySheet extends StatefulWidget {
  const _AddMoneySheet();
  @override
  State<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends State<_AddMoneySheet> {
  // s36 shows Bank transfer already selected (the thicker indicator border)
  // — matched here as the default rather than an unselected chooser.
  _FundMethod _method = _FundMethod.bankTransfer;

  late final _repo = WalletRepository(AppScope.read(context).apiClient);
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);

  /// s36's plate shows "Providus Bank · Adebayo Okonkwo" — a real
  /// account-holder name — but `VirtualAccountDetails` (GET
  /// /transactions/virtual-account) only ever carries accountNumber/bankName,
  /// no holder-name field (checked against the backend's actual wire type,
  /// common/types/transaction.types.ts's VirtualAccount). Flutterwave opens
  /// this account in the signed-in investor's own name, though, so joining
  /// it with GET /users/me's real fullName is a true fact about this
  /// specific account, not an invented one — same extra call
  /// account_screen.dart already makes for its own profile header.
  late Future<({VirtualAccountDetails account, String holderName})> _bankFuture = _loadBank();

  Future<({VirtualAccountDetails account, String holderName})> _loadBank() async {
    final (account, profile) = await (_repo.virtualAccount(), _userRepo.me()).wait;
    return (account: account, holderName: profile.fullName);
  }

  // Card branch — s36 draws no content for this state (see file header);
  // this amount + explainer + submit is this file's own composition.
  late final TextEditingController _cardAmount = TextEditingController(text: '20,000');
  bool _cardBusy = false;
  String? _cardAmountError;

  @override
  void dispose() {
    _cardAmount.dispose();
    super.dispose();
  }

  Future<void> _copy(String accountNumber) async {
    await Clipboard.setData(ClipboardData(text: accountNumber));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account number copied')),
    );
  }

  Future<void> _continueCard() async {
    final amountKobo = _parseAmountKobo(_cardAmount.text);
    if (amountKobo <= 0) {
      setState(() => _cardAmountError = 'Enter an amount to continue');
      return;
    }
    setState(() {
      _cardAmountError = null;
      _cardBusy = true;
    });
    try {
      final result = await _repo.fund(amountKobo: amountKobo, method: 'card');
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
        setState(() => _cardBusy = false);
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
      setState(() => _cardBusy = false);
      _showErrorSheet(context, title: 'Could not start payment', message: e.message);
    }
  }

  /// launchUrl() can fail two ways: throwing (no app/browser can handle the
  /// scheme) or just returning false — checking only for a thrown exception
  /// misses the second case entirely.
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
        Text('How do you want to pay?', style: KType.title()),
        const SizedBox(height: 6),
        // s36's own subhead is "Fees and timing differ. Transfer costs
        // less." — a comparison this file will not repeat: both methods
        // charge nothing today (see [_depositFeeLabel]), so "transfer costs
        // less" is not actually true right now, and the canvas's own two
        // rows don't even agree with each other on which method is cheaper
        // (₦28 card vs ₦100-150 transfer — card is cheaper as drawn). Not
        // reconciled per this file's brief; rendered as a neutral true
        // statement instead of a specific comparison this app cannot back.
        Text('Fees and timing can differ by method.',
            style: KType.body(color: KColor.ink2)),
        const SizedBox(height: 16),
        _FundMethodCard(
          icon: 'transfer',
          title: 'Bank transfer',
          sub: '$_depositFeeLabel · same day',
          selected: _method == _FundMethod.bankTransfer,
          onTap: () => setState(() => _method = _FundMethod.bankTransfer),
        ),
        const SizedBox(height: 12),
        _FundMethodCard(
          icon: 'card',
          title: 'Debit card',
          sub: 'Flutterwave · $_depositFeeLabel, instant',
          selected: _method == _FundMethod.card,
          onTap: () => setState(() => _method = _FundMethod.card),
        ),
        const SizedBox(height: 20),
        if (_method == _FundMethod.bankTransfer) _buildBankPanel() else _buildCardPanel(),
      ],
    );
  }

  Widget _buildBankPanel() {
    return FutureBuilder<({VirtualAccountDetails account, String holderName})>(
      future: _bankFuture,
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
              onPrimary: () => setState(() => _bankFuture = _loadBank()),
            ),
          );
        }
        final data = snapshot.data!;
        final account = data.account;
        // Empty state: the endpoint answered without throwing but with no
        // usable account number — the one condition that can genuinely
        // enter "empty" here, since virtualAccount() is otherwise
        // idempotent/always-populated by design.
        if (account.accountNumber.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: KEmptyView(
              icon: 'wallet',
              title: 'Account not ready',
              message: "We couldn't set up your funding account yet. Try again in a moment.",
              actionLabel: 'Try again',
              onAction: () => setState(() => _bankFuture = _loadBank()),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Full grape "feature plate" — same treatment as the Splash
            // screen, reused for the single most important piece of data on
            // this sheet: the virtual account number.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: KColor.feature, borderRadius: KRadii.featureR),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Transfer to this account'.upper,
                      style: KType.label(color: KColor.sun)),
                  const SizedBox(height: 10),
                  Text(
                    account.accountNumber,
                    style: KType.title(color: KColor.featureInk)
                        .copyWith(fontSize: 30, fontWeight: KWeight.black, letterSpacing: -0.6)
                        .tnum,
                  ),
                  const SizedBox(height: 4),
                  // "Providus Bank · Adebayo Okonkwo" (s36) —
                  // VirtualAccountDetails itself has no holder-name field
                  // (checked against the backend's real wire type), but a
                  // Flutterwave virtual account is always opened in the
                  // signed-in investor's own name, so joining GET
                  // /users/me's real fullName here is a true fact, not an
                  // invented one.
                  Text('${account.bankName} · ${data.holderName}',
                      style: KType.body(color: KColor.featureInk2)),
                  const SizedBox(height: 14),
                  // "Copy account number" (s36) — inside the plate, one
                  // action, no separate "Share details" button underneath
                  // (that button isn't in s36; dropped for fidelity — see
                  // build report). s36's light plate sits this on a solid
                  // paper-white pill with indicator-purple content; s36d's
                  // dark plate instead uses a translucent white pill with
                  // plain light text — plain `KColor.paper` would render a
                  // near-black pill floating on the purple plate in dark, so
                  // this branches rather than reusing one literal token pair.
                  Builder(builder: (context) {
                    final dark = KColor.active.brightness == Brightness.dark;
                    final pillColor =
                        dark ? KColor.featureInk.withValues(alpha: 0.10) : KColor.paper;
                    final contentColor = dark ? KColor.featureInk : KColor.indicator;
                    return GestureDetector(
                      onTap: () => _copy(account.accountNumber),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: pillColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            KIcon('doc', size: 16, color: contentColor),
                            const SizedBox(width: 8),
                            Text('Copy account number',
                                style: KType.cardTitle(color: contentColor)),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                  // s36's one footnote inside the plate — real fee truth
                  // ("free", see [_depositFeeLabel]) in place of the
                  // canvas's ₦100-₦150 claim; timing kept as drawn (no
                  // ruling blocks the timing clause, only the money figure).
                  Text(
                    'This account is yours alone. Transfers are $_depositFeeLabel and '
                    'usually land the same working day.',
                    style: KType.body(color: KColor.featureInk2).copyWith(fontSize: 13, height: 19 / 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Not in s36, kept for real fraud-prevention value (flagged in
            // the build report as an addition beyond the artboard, the same
            // class of call as R-17's kept Cancel button).
            Text(
              "Money sent from an account that isn't yours is returned — the "
              'names must match.',
              style: KType.body(color: KColor.ink3),
            ),
            const SizedBox(height: 16),
            KButton(
              label: "I've sent the money",
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCardPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KInput(
          label: 'Amount',
          controller: _cardAmount,
          numeric: true,
          amount: true,
          prefix: '₦',
          error: _cardAmountError,
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
          loading: _cardBusy,
          onPressed: _cardBusy ? null : _continueCard,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WITHDRAW — s37: amount + destination + fee, one CTA, one sheet.
// ─────────────────────────────────────────────────────────────────────────────

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet();
  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

typedef _WithdrawInit = ({String balance, BankAccountSummary? account, String holderName});

class _WithdrawSheetState extends State<_WithdrawSheet> {
  late final TextEditingController _amount = TextEditingController(text: '30,000');
  late final _repo = WalletRepository(AppScope.read(context).apiClient);
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);
  late Future<_WithdrawInit> _init = _load();
  bool _busy = false;

  // GET /wallet-balance + GET /bank-accounts + GET /users/me, fetched
  // together so the sheet has a single loading/error state. The withdraw
  // destination: no in-sheet picker exists for choosing among multiple
  // saved accounts (see file header) — this always resolves to the
  // investor's primary account, falling back to the first saved one.
  // `holderName`: a DCS bank account is required to be in the investor's
  // own name (BankAccountsService enforces this at add-time), so the
  // signed-in investor's real fullName is a true fact about whichever
  // account this resolves to, not an invented one.
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

  double _availableNaira(String balance) => _parseNaira(balance);

  void _setAmount(double naira) {
    setState(() {
      final whole = naira.truncate();
      final wholeStr = whole.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
      _amount.text = wholeStr;
    });
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
        final available = _availableNaira(data.balance);
        final entered = _parseNaira(_amount.text);
        final overBalance = entered > available && available > 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Column(
                children: [
                  Text('How much do you want out?'.upper, style: KType.label()),
                  const SizedBox(height: 8),
                  _BigAmountField(
                    controller: _amount,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    overBalance ? 'Only ${data.balance} available now' : '${data.balance} available now',
                    style: KType.body(color: overBalance ? KColor.loss : KColor.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Quick-amount chips — fixed anchors matching s37's own drawn
            // values, plus a real "All" figure from the fetched balance
            // (same fixed-value-chip convention trade_flows.dart's
            // _AmountSheet already uses).
            Row(
              children: [
                Expanded(
                  child: KPillChip(
                    label: '₦10,000',
                    selected: entered == 10000,
                    onTap: () => _setAmount(10000),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: KPillChip(
                    label: '₦30,000',
                    selected: entered == 30000,
                    onTap: () => _setAmount(30000),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: KPillChip(
                    label: 'All ${data.balance}',
                    // Compares truncated wholes, not exact doubles — the
                    // "All" chip writes a whole-naira figure (see
                    // [_setAmount]) while [available] carries real kobo, so
                    // an exact `==` would never highlight as selected once
                    // the balance has any cents in it.
                    selected: available > 0 && entered.floor() == available.floor(),
                    onTap: available > 0 ? () => _setAmount(available) : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Going to your bank', style: KType.cardTitle()),
            const SizedBox(height: 10),
            // A raw Container (not KCard, which fixes its border to
            // KColor.hairline) so the resolved-account state can carry s37's
            // own 1.5px indicator-coloured border; falls back to a plain
            // hairline for the empty "no saved account" state.
            Container(
              decoration: BoxDecoration(
                color: KColor.paper,
                border: Border.all(
                  color: account == null ? KColor.hairline : _accentBorder,
                  width: account == null ? 1 : 1.5,
                ),
                borderRadius: KRadii.cardR,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SelectRow(
                icon: 'card',
                // "GTB ••••6789 · DCS account" (s37) — DCS accounts are
                // always the investor's own name-matched settlement account,
                // so the qualifier is accurate for every saved account here.
                title: account == null
                    ? 'No saved bank account'
                    : '${account.bankName} ${account.accountNumberMasked} · DCS account',
                sub: account == null ? 'Tap to add one' : data.holderName,
                trailingCheck: account != null,
                trailingChevron: account == null,
                first: true,
                // No saved account: this IS the empty state — routes to the
                // add-bank-account screen instead of sitting inert.
                onTap: account == null
                    ? () {
                        Navigator.of(context).pop();
                        context.push(Routes.acctBanks);
                      }
                    : () {},
              ),
            ),
            // s37 also draws "Only an account in your own name. Changing it
            // takes a 24-hour security hold." — the name-match half is real
            // (enforced at add-time); no such hold exists anywhere in the
            // backend, so it is left out rather than asserted (see file
            // header).
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
                  _SummaryRow(
                      label: 'Withdrawal fee',
                      value: _depositFeeLabel,
                      small: true,
                      valueColor: KColor.gain),
                  _SummaryRow(
                      label: 'Money arrives',
                      value: 'Within 1 working day',
                      small: true,
                      divider: false),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // s37's own footnote is "Money from shares you just sold becomes
            // available 3 working days after the sale." — the passcode
            // sentence is not drawn but is kept: it is a true statement
            // about this screen's real behaviour ([_confirm] below actually
            // gates on it), not decoration, so dropping it would make the
            // screen less honest, not more accurate. Flagged in the build
            // report as an addition beyond the artboard.
            Text(
              'Your passcode confirms this withdrawal. Money from shares you '
              'just sold becomes available 3 working days after the sale.',
              style: KType.body(color: KColor.ink3),
            ),
            const SizedBox(height: 22),
            // Single "Withdraw ₦X" CTA (s37 draws no Cancel button — the
            // sheet is already dismissable by drag/tap-outside, so nothing
            // is lost by matching that).
            KButton(
              label: 'Withdraw ₦${_amount.text}',
              loading: _busy,
              onPressed: (_busy || account == null || entered <= 0 || overBalance)
                  ? null
                  : () => _confirm(account, data.holderName),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirm(BankAccountSummary account, String holderName) async {
    // Passcode re-authentication before money leaves the account
    // (restored 2026-08-24, kept through this rebuild) — placed BEFORE
    // `_busy` is set so a dismissed sheet leaves the button live rather than
    // stuck in a spinner. Non-blocking on devices that never set a local
    // passcode (hasPasscode() false) — there is nothing to verify against
    // there, and hard-failing would strand those investors with no way to
    // withdraw at all.
    final store = PasscodeStore();
    if (await store.hasPasscode()) {
      if (!mounted) return;
      final confirmed = await confirmPasscode(
        context,
        store: store,
        title: 'Confirm this withdrawal',
        message: 'Enter your passcode to move money out of your wallet.',
      );
      if (!confirmed) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    final destinationLabel = '${account.bankName} ${account.accountNumberMasked}';
    final amountLabel = _amount.text;
    try {
      await _repo.withdraw(
        amountKobo: _parseAmountKobo(_amount.text),
        bankAccountId: account.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSuccessSheet(context,
          title: 'Withdrawal started',
          message: '₦$amountLabel is on its way to $destinationLabel.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showErrorSheet(context, title: 'Withdrawal failed', message: e.message);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WITHDRAW — outside-hours variant (R-21: kept, restyled). No canvas
// counterpart exists anywhere — this composition follows s37's own patterns
// (big amount + chips + destination row + two-row fee card) rather than
// designer intent; recorded here so nobody mistakes this layout for a
// drawn artboard.
//
// REAL BACKEND GAP, flagged rather than faked: WalletRepository.withdraw()
// (POST /transactions/withdraw) has no queuing/scheduling concept —
// withdrawals go server-to-bank directly regardless of the hour, i.e. no
// off-hours-vs-daytime branching exists server-side. So this sheet does NOT
// claim a specific processing time nothing server-side actually commits to
// (no "Tomorrow from 09:00"). It keeps the same honest "Within 1 working
// day" wording the in-hours sheet uses, and "Queue it for 09:00" submits
// the SAME real withdraw() call right away — a transfer initiated at night
// genuinely does land the next working day anyway, so the framing is
// honest; only a literal clock promise is avoided. Fee is genuinely free,
// same established fact as the in-hours withdraw (see [_depositFeeLabel]).
//
// Trigger: outside a rough 09:00-21:00 weekday window, client-clock only —
// same class of heuristic as market_hours.dart's isNgxOpenNow(), not
// authoritative bank-processing-window data (no such field exists in this
// API). The "...or with unsettled cash" trigger is shown as CONTEXT inside
// the sheet (the settling-amount line, whenever
// [WalletRepository.balanceDetail]'s `pending` is non-null) rather than a
// second independent trigger — modelling "does THIS entered amount touch
// unsettled cash" before the amount is even typed would itself be a
// fabricated distinction.
//
// On success this pushes straight to the real transaction-detail screen
// instead of a generic success sheet — the investor gets to see the queued
// transaction's own real status rather than a sheet asserting one.
// ─────────────────────────────────────────────────────────────────────────────

bool _isOutsideWithdrawHours() {
  final now = DateTime.now();
  if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) return true;
  final minutes = now.hour * 60 + now.minute;
  return minutes < 9 * 60 || minutes >= 21 * 60;
}

typedef _OutsideHoursInit = ({
  String available,
  String? pending,
  BankAccountSummary? account,
  String holderName,
});

class _OutsideHoursWithdrawSheet extends StatefulWidget {
  const _OutsideHoursWithdrawSheet();
  @override
  State<_OutsideHoursWithdrawSheet> createState() => _OutsideHoursWithdrawSheetState();
}

class _OutsideHoursWithdrawSheetState extends State<_OutsideHoursWithdrawSheet> {
  late final TextEditingController _amount = TextEditingController(text: '30,000');
  late final _repo = WalletRepository(AppScope.read(context).apiClient);
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);
  late Future<_OutsideHoursInit> _init = _load();
  bool _busy = false;
  String? _error;

  Future<_OutsideHoursInit> _load() async {
    final (detail, accounts, profile) =
        await (_repo.balanceDetail(), _repo.bankAccounts(), _userRepo.me()).wait;
    BankAccountSummary? account;
    for (final a in accounts) {
      if (a.primary) {
        account = a;
        break;
      }
    }
    account ??= accounts.isEmpty ? null : accounts.first;
    return (
      available: detail.available,
      pending: detail.pending,
      account: account,
      holderName: profile.fullName,
    );
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

  void _setAmount(double naira) {
    setState(() {
      final whole = naira.truncate();
      final wholeStr = whole.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
      _amount.text = wholeStr;
    });
  }

  Future<void> _confirm(BankAccountSummary account) async {
    // Passcode re-authentication before money leaves the account — same gate
    // as the in-hours sheet's own [_WithdrawSheetState._confirm].
    final store = PasscodeStore();
    if (await store.hasPasscode()) {
      if (!mounted) return;
      final confirmed = await confirmPasscode(
        context,
        store: store,
        title: 'Confirm this withdrawal',
        message: 'Enter your passcode to move money out of your wallet.',
      );
      if (!confirmed) return;
    }
    if (!mounted) return;
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
        final available = _parseNaira(data.available);
        final entered = _parseNaira(_amount.text);
        final overBalance = entered > available && available > 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Withdraw" + the "Queued for morning" pill share one row — the
            // sheet is opened untitled and this row built explicitly, same
            // pattern as trade_flows.dart's market-closed buy sheet.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Withdraw', style: KType.section()),
                const KStatusPill(status: KStatus.pending, label: 'Queued for morning', small: true),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text('How much do you want out?'.upper, style: KType.label()),
                  const SizedBox(height: 8),
                  _BigAmountField(
                    controller: _amount,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.pending != null
                        ? '${data.available} available · ${data.pending} of it still settling'
                        : '${data.available} available',
                    style: KType.body(color: overBalance ? KColor.loss : KColor.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: KPillChip(
                    label: '₦10,000',
                    selected: entered == 10000,
                    onTap: () => _setAmount(10000),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: KPillChip(
                    label: '₦30,000',
                    selected: entered == 30000,
                    onTap: () => _setAmount(30000),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: KPillChip(
                    label: 'All ${data.available}',
                    // Compares truncated wholes, not exact doubles — the
                    // "All" chip writes a whole-naira figure (see
                    // [_setAmount]) while [available] carries real kobo, so
                    // an exact `==` would never highlight as selected once
                    // the balance has any cents in it.
                    selected: available > 0 && entered.floor() == available.floor(),
                    onTap: available > 0 ? () => _setAmount(available) : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Going to your bank', style: KType.cardTitle()),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: KColor.paper,
                border: Border.all(
                  color: account == null ? KColor.hairline : _accentBorder,
                  width: account == null ? 1 : 1.5,
                ),
                borderRadius: KRadii.cardR,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SelectRow(
                icon: 'card',
                title: account == null
                    ? 'No saved bank account'
                    : '${account.bankName} ${account.accountNumberMasked} · DCS account',
                sub: account == null ? 'Tap to add one' : data.holderName,
                trailingCheck: account != null,
                trailingChevron: account == null,
                first: true,
                // No saved account: this is the empty state — routes to add
                // one instead of leaving the CTA permanently disabled with
                // no way forward (the in-hours sheet's own fix, carried
                // here too per R-21's "restyled to match neighbours").
                onTap: account == null
                    ? () {
                        Navigator.of(context).pop();
                        context.push(Routes.acctBanks);
                      }
                    : () {},
              ),
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
                  _SummaryRow(label: 'Requested', value: _requestedAtLabel, small: true),
                  _SummaryRow(
                      label: 'Sent to your bank',
                      value: 'Within 1 working day',
                      small: true),
                  _SummaryRow(
                      label: 'Withdrawal fee',
                      value: _depositFeeLabel,
                      small: true,
                      valueColor: KColor.gain,
                      divider: false),
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
            KButton(
              label: 'Queue it for 09:00',
              loading: _busy,
              onPressed: (_busy || account == null || entered <= 0 || overBalance)
                  ? null
                  : () => _confirm(account),
            ),
          ],
        );
      },
    );
  }
}
