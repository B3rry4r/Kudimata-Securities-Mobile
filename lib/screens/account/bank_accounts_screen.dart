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

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/bank_accounts_repository.dart';
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
  late Future<List<BankAccountSummary>> _future = _repo.list();

  void _reload() => setState(() => _future = _repo.list());

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
      child: FutureBuilder<List<BankAccountSummary>>(
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
          final accounts = snapshot.data ?? const <BankAccountSummary>[];
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
              else
                KAccountCard(
                  children: [
                    for (var i = 0; i < accounts.length; i++)
                      _BankRow(
                        account: accounts[i],
                        first: i == 0,
                        onTap: () => _openActions(accounts[i]),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              // SEAM: bank-linking flow (account verification / mandate provider)
              // plugs in here.
              KButton(label: 'Add bank account', iconLeft: 'plus', onPressed: _openAdd),
            ],
          );
        },
      ),
    );
  }
}

enum _RowAction { setPrimary, remove }

class _BankRow extends StatelessWidget {
  const _BankRow({required this.account, required this.first, required this.onTap});
  final BankAccountSummary account;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: first
                ? BorderSide.none
                : BorderSide(color: KColor.hairline, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Row(
          children: [
            const KIconBubble('wallet', iconSize: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(account.bankName, style: KType.cardTitle(w: KWeight.medium)),
                      if (account.primary) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(KRadii.pill),
                            border: Border.all(color: KColor.hairline, width: 1),
                          ),
                          child: Text('Primary',
                              style: KType.micro(color: KColor.ink3)
                                  .copyWith(letterSpacing: 0.06 * 10)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(account.accountNumberMasked,
                      style: KType.micro(color: KColor.ink3)
                          .copyWith(letterSpacing: 0.06 * 10)
                          .tnum),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const KRowChevron(),
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
        KAccountRow(
          icon: 'close',
          title: 'Remove account',
          first: account.primary,
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
