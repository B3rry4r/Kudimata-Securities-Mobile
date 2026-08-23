// Stage 9 — Bank accounts (pushed). Linked-bank list (with a Primary tag) + an
// add action. Mirrors `BankAccounts` in extra-screens.jsx.
//
// Wired per lib/data/api/README.md: GET /bank-accounts
// (BankAccountsRepository.list()) replaces the old hardcoded `_banks` list
// via the canonical FutureBuilder pattern. "Add bank account" now opens a
// minimal bank-select + account-number sheet (POST /bank-accounts, with
// POST /banks/resolve-account-name previewing the resolved account holder
// name once enough of the account number is entered). Tapping a row — the
// KRowChevron already signalled it was actionable, just unwired — opens a
// small action sheet offering "Set as primary" (PATCH .../primary) and
// "Remove" (DELETE), the only two actions the design implies for this row;
// no other row UI exists to wire beyond that.
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/bank_accounts_repository.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  late final _repo = BankAccountsRepository(AppScope.read(context).apiClient);
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);
  late Future<(List<BankAccountSummary> accounts, String holderName)> _future = _load();

  // Canvas #s64's per-account "Adebayo Okonkwo · added 14 Mar 2026" line
  // isn't a field on BankAccount at all — every linked account MUST be in
  // the investor's own name (this screen's own footer text says so, and
  // it's enforced server-side against BVN) — so the holder name is just
  // this investor's own registered name, fetched once alongside the list
  // rather than invented per-row.
  Future<(List<BankAccountSummary>, String)> _load() async {
    final (accounts, user) = await (_repo.list(), _userRepo.me()).wait;
    return (accounts, '${user.firstName} ${user.lastName}'.trim());
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _openAdd() async {
    final added = await showKSheet<bool>(
      context,
      title: 'Add bank account',
      child: _AddBankAccountSheet(repo: _repo),
    );
    if (added == true) _reload();
  }

  Future<void> _openActions(BankAccountSummary account) async {
    final action = await showKSheet<_RowAction>(
      context,
      title: account.bankName,
      child: _AccountActionsSheet(account: account),
    );
    if (action == null || !mounted) return;
    // Withdraw-mandate (screen 65) is its own confirm screen, not an
    // immediate repo call like the other two actions — see
    // withdraw_mandate_screen.dart's header comment for why it doesn't
    // call setPrimary()/remove() directly.
    if (action == _RowAction.withdrawMandate) {
      context.push(Routes.acctWithdrawMandate, extra: account);
      return;
    }
    try {
      if (action == _RowAction.setPrimary) {
        await _repo.setPrimary(account.id);
      } else {
        await _repo.remove(account.id);
      }
      if (!mounted) return;
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Bank accounts',
      child: FutureBuilder<(List<BankAccountSummary>, String)>(
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
              child: KErrorView(onPrimary: _reload),
            );
          }
          final (accounts, holderName) = snapshot.data ?? const (<BankAccountSummary>[], '');
          // screen-specs.md spec 64 (2026-08-23 exactness pass, re-verified
          // against the canvas mockup's real #s64 markup): the primary
          // account renders as its own self-contained card — icon, name,
          // "DCS active" pill, the mandate explainer, then inline "See the
          // mandate" / "Withdraw mandate" buttons INSIDE the card, not a
          // shared row list that opens an action sheet on tap. Non-primary
          // accounts stay simple icon+meta+pill rows in their own card. This
          // backend has no separate "DCS mandate" concept from the existing
          // `primary` flag, so "DCS active"/"No mandate" map directly onto
          // real `primary` rather than inventing a new field. The tap-to-
          // open-sheet affordance (Set as primary / Remove) is kept as an
          // ADDITIVE way to manage accounts beyond what the mockup shows —
          // real functionality the backend supports, not a mockup regression.
          final primary = accounts.where((a) => a.primary).toList();
          final others = accounts.where((a) => !a.primary).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: KEmptyView(
                    icon: 'wallet',
                    title: 'No bank accounts yet',
                    message: 'Link a bank account to fund your wallet or withdraw.',
                    actionLabel: 'Add bank account',
                    onAction: _openAdd,
                  ),
                )
              else ...[
                for (final account in primary) ...[
                  _PrimaryAccountCard(
                    account: account,
                    holderName: holderName,
                    onSeeMandate: () => context.push(Routes.acctStatements),
                    onWithdrawMandate: () =>
                        context.push(Routes.acctWithdrawMandate, extra: account),
                    onTap: () => _openActions(account),
                  ),
                  const SizedBox(height: 14),
                ],
                for (final account in others) ...[
                  _SecondaryAccountRow(
                    account: account,
                    holderName: holderName,
                    onTap: () => _openActions(account),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
              if (accounts.isNotEmpty) ...[
                const SizedBox(height: 2),
                // SEAM: bank-linking flow (account verification / mandate
                // provider) plugs in here.
                KButton(
                  label: 'Add another account',
                  iconLeft: 'plus',
                  variant: KButtonVariant.secondary,
                  onPressed: _openAdd,
                ),
                const SizedBox(height: 16),
                Text(
                  'Every account must be in your own name, matched to your BVN. One account carries the DCS mandate at a time.',
                  style: KType.data(color: KColor.ink3),
                ),
                const SizedBox(height: 12),
                KButton(
                  label: 'What is a DCS mandate?',
                  variant: KButtonVariant.ghost,
                  onPressed: () => context.push(Routes.acctHelp),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

enum _RowAction { setPrimary, remove, withdrawMandate }

/// A plain colour-filled circle icon, no border — matches #s64's exact
/// markup (`border-radius:50%;background:...`) rather than the shared
/// KIconBubble (hairline-border variant used elsewhere), since this screen's
/// two account cards use different bubble colours per status.
class _StatusIconBubble extends StatelessWidget {
  const _StatusIconBubble({required this.bg, required this.iconColor});
  final Color bg;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: KIcon('wallet', size: 18, color: iconColor),
    );
  }
}

/// The account carrying the DCS mandate — its own card with the explainer
/// and inline "See the mandate" / "Withdraw mandate" buttons, per #s64.
class _PrimaryAccountCard extends StatelessWidget {
  const _PrimaryAccountCard({
    required this.account,
    required this.holderName,
    required this.onSeeMandate,
    required this.onWithdrawMandate,
    required this.onTap,
  });
  final BankAccountSummary account;
  final String holderName;
  final VoidCallback onSeeMandate;
  final VoidCallback onWithdrawMandate;
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
          border: Border.all(color: KColor.hairline),
          borderRadius: BorderRadius.circular(KRadii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _StatusIconBubble(bg: KColor.indicatorTint, iconColor: KColor.indicator),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${account.bankName} ${account.accountNumberMasked}',
                          style: KType.cardTitle()),
                      Text(
                        account.addedDate == null
                            ? holderName
                            : '$holderName · added ${account.addedDate}',
                        style: KType.data(color: KColor.ink2),
                      ),
                    ],
                  ),
                ),
                const KStatusPill(status: KStatus.approved, label: 'DCS active', small: true),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Your Direct Cash Settlement mandate sends sale proceeds and dividends from the CSCS to this account.',
              style: KType.data(color: KColor.ink2),
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                KButton(label: 'See the mandate', variant: KButtonVariant.secondary, onPressed: onSeeMandate),
                const SizedBox(height: 8),
                KButton(
                  label: 'Withdraw mandate',
                  variant: KButtonVariant.destructive,
                  onPressed: onWithdrawMandate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A non-primary linked account — a simpler card, icon + meta + status pill,
/// no inline mandate actions. Tapping still opens the set-primary/remove
/// sheet — real backend functionality the mockup doesn't need to show.
class _SecondaryAccountRow extends StatelessWidget {
  const _SecondaryAccountRow({required this.account, required this.holderName, required this.onTap});
  final BankAccountSummary account;
  final String holderName;
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
          border: Border.all(color: KColor.hairline),
          borderRadius: BorderRadius.circular(KRadii.card),
        ),
        child: Row(
          children: [
            _StatusIconBubble(bg: KColor.track, iconColor: KColor.ink2),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${account.bankName} ${account.accountNumberMasked}',
                      style: KType.cardTitle()),
                  Text('$holderName · funding only',
                      style: KType.data(color: KColor.ink2)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const KStatusPill(status: KStatus.pending, label: 'No mandate', small: true),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Row actions sheet — set primary / remove.
// ─────────────────────────────────────────────────────────────────────────────

class _AccountActionsSheet extends StatelessWidget {
  const _AccountActionsSheet({required this.account});
  final BankAccountSummary account;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!account.primary)
          KAccountRow(
            icon: 'check',
            title: 'Set as primary',
            first: true,
            onTap: () => Navigator.of(context).pop(_RowAction.setPrimary),
          ),
        // "Withdraw mandate" (screen 65) only makes sense on the account
        // that actually carries the mandate.
        if (account.primary)
          KAccountRow(
            icon: 'close',
            title: 'Withdraw mandate',
            first: true,
            onTap: () => Navigator.of(context).pop(_RowAction.withdrawMandate),
          ),
        KAccountRow(
          icon: 'close',
          title: 'Remove account',
          first: false,
          onTap: () => Navigator.of(context).pop(_RowAction.remove),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add-account sheet — bank picker + account number, previewing the resolved
// account holder name before confirming.
// ─────────────────────────────────────────────────────────────────────────────

class _AddBankAccountSheet extends StatefulWidget {
  const _AddBankAccountSheet({required this.repo});
  final BankAccountsRepository repo;

  @override
  State<_AddBankAccountSheet> createState() => _AddBankAccountSheetState();
}

class _AddBankAccountSheetState extends State<_AddBankAccountSheet> {
  late Future<List<Bank>> _banksFuture = widget.repo.banks();
  final TextEditingController _accountNumber = TextEditingController();
  Bank? _bank;
  String? _resolvedName;
  bool _resolving = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _accountNumber.dispose();
    super.dispose();
  }

  /// Opens the full bank list in its own picker sheet (2026-08-20 fix —
  /// reported: "bank account screen shows a long dropdown before I see
  /// where to input my account number... bad UX"). The full list of NGX
  /// banks (dozens of rows) used to render inline, ABOVE the account-number
  /// field, pushing it far down the sheet — sometimes off-screen entirely.
  /// Now the form shows one compact selector row; tapping it opens the list
  /// (with a search field, since it's long) in a separate sheet, and
  /// selecting a bank collapses straight back to that one row.
  Future<void> _pickBank(List<Bank> banks) async {
    final picked = await showKSheet<Bank>(
      context,
      title: 'Select bank',
      child: _BankPickerSheet(banks: banks, selected: _bank),
    );
    if (picked == null) return;
    setState(() => _bank = picked);
    _maybeResolveName();
  }

  bool get _canSubmit =>
      _bank != null && _accountNumber.text.trim().length >= 10 && !_busy;

  Future<void> _maybeResolveName() async {
    final bank = _bank;
    final number = _accountNumber.text.trim();
    if (bank == null || number.length < 10) {
      if (_resolvedName != null) setState(() => _resolvedName = null);
      return;
    }
    setState(() => _resolving = true);
    try {
      final name =
          await widget.repo.resolveAccountName(bankCode: bank.code, accountNumber: number);
      if (!mounted) return;
      setState(() {
        _resolvedName = name;
        _resolving = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _resolvedName = null;
        _resolving = false;
      });
    }
  }

  Future<void> _submit() async {
    final bank = _bank;
    if (bank == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.add(bankCode: bank.code, accountNumber: _accountNumber.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    return FutureBuilder<List<Bank>>(
      future: _banksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: KLoadingView(),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: KErrorView(
              onPrimary: () => setState(() => _banksFuture = widget.repo.banks()),
            ),
          );
        }
        final banks = snapshot.data ?? const <Bank>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const KEyebrow('Bank'),
            const SizedBox(height: 10),
            if (banks.isEmpty)
              Text('No banks available.', style: KType.body(color: KColor.ink3))
            else
              GestureDetector(
                onTap: () => _pickBank(banks),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: KColor.paper,
                    borderRadius: BorderRadius.circular(KRadii.input),
                    border: Border.all(color: KColor.hairline, width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _bank?.name ?? 'Select bank',
                          style: KType.body(
                            color: _bank == null ? KColor.ink3 : KColor.ink,
                            w: KWeight.medium,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const KRowChevron(),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            KInput(
              label: 'Account number',
              controller: _accountNumber,
              numeric: true,
              keyboardType: TextInputType.number,
              placeholder: '0123456789',
              helper: _resolving
                  ? 'Resolving account name…'
                  : _resolvedName != null
                      ? 'Account name: $_resolvedName'
                      : null,
              onChanged: (_) {
                setState(() {}); // refresh _canSubmit against the new text
                _maybeResolveName();
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: KType.micro(color: KColor.loss)),
            ],
            const SizedBox(height: 22),
            KButton(
              label: 'Add bank account',
              loading: _busy,
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        );
      },
    );
  }
}

/// The full bank list, in its own sheet (see _pickBank's doc comment) —
/// pushed OVER the add-account sheet rather than inlined in it. Includes a
/// search field since NGX's bank list runs to several dozen entries; typing
/// filters the (already-fetched) list client-side, no extra network call.
class _BankPickerSheet extends StatefulWidget {
  const _BankPickerSheet({required this.banks, required this.selected});
  final List<Bank> banks;
  final Bank? selected;

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.banks
        : widget.banks.where((b) => b.name.toLowerCase().contains(query)).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KInput(
          controller: _search,
          placeholder: 'Search banks',
          icon: 'search',
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text('No banks match "$query".',
                      style: KType.body(color: KColor.ink3)),
                )
              : SingleChildScrollView(
                  child: KCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (var i = 0; i < filtered.length; i++)
                          _BankOptionRow(
                            bank: filtered[i],
                            selected: widget.selected?.code == filtered[i].code,
                            first: i == 0,
                            onTap: () => Navigator.of(context).pop(filtered[i]),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _BankOptionRow extends StatelessWidget {
  const _BankOptionRow({
    required this.bank,
    required this.selected,
    required this.first,
    required this.onTap,
  });
  final Bank bank;
  final bool selected;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: KColor.hairline, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(bank.name, style: KType.cardTitle())),
            if (selected) const KIcon('check', size: 18),
          ],
        ),
      ),
    );
  }
}
