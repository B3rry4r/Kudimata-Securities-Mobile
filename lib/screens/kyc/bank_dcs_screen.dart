// KYC 6 of 8 — Bank & Direct Cash Settlement (canvas screen 19). NEW screen
// (2026-08-24, re-sequencing to the canvas's real 8-step flow).
//
// Reuses the app's EXISTING real bank-linking mechanism —
// BankAccountsRepository (POST /bank-accounts, PATCH .../primary, GET
// /banks, POST /banks/resolve-account-name) — the SAME repository and
// picker/preview pattern bank_accounts_screen.dart's add-account sheet
// already uses, just inline on a full KYC step screen instead of a sheet.
//
// "Use this account for Direct Cash Settlement" (checked by default, per
// the canvas) maps onto setting the newly-added account `primary` — the
// SAME flag bank_accounts_screen.dart's "DCS active" pill already reads, and
// which the backend now requires Order.destinationBankAccountId to satisfy
// (confirmed 2026-08-24: "the DCS account" IS "the primary bank account",
// no separate concept). Unchecking it still adds the account (funding-only,
// like a _SecondaryAccountRow), just doesn't set it primary.
//
// Resume-aware: if the investor already has a primary account (added here
// before, or already had one), this shows it directly instead of asking to
// re-add — Continue just moves on.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/bank_accounts_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import '_kyc_chrome.dart';

class BankDcsScreen extends StatefulWidget {
  const BankDcsScreen({super.key});

  @override
  State<BankDcsScreen> createState() => _BankDcsScreenState();
}

class _BankDcsScreenState extends State<BankDcsScreen> {
  late final _repo = BankAccountsRepository(AppScope.read(context).apiClient);
  late final Future<List<BankAccountSummary>> _existingFuture = _repo.list();

  // Add-account form state — only used once no primary account exists yet,
  // or the investor chooses "Add a different account".
  late Future<List<Bank>> _banksFuture = _repo.banks();
  final _accountNumber = TextEditingController();
  Bank? _bank;
  String? _resolvedName;
  bool _resolving = false;
  bool _dcs = true; // checked by default, per the canvas.
  bool _showAddForm = false;
  bool _busy = false;
  bool _showErrors = false;
  String? _error;

  @override
  void dispose() {
    _accountNumber.dispose();
    super.dispose();
  }

  bool get _canAdd => _bank != null && _accountNumber.text.trim().length >= 10;

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

  Future<void> _maybeResolveName() async {
    final bank = _bank;
    final number = _accountNumber.text.trim();
    if (bank == null || number.length < 10) {
      if (_resolvedName != null) setState(() => _resolvedName = null);
      return;
    }
    setState(() => _resolving = true);
    try {
      final name = await _repo.resolveAccountName(bankCode: bank.code, accountNumber: number);
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

  Future<void> _addAndContinue() async {
    final bank = _bank;
    if (bank == null || !_canAdd) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final added = await _repo.add(bankCode: bank.code, accountNumber: _accountNumber.text.trim());
      if (_dcs && !added.primary) {
        await _repo.setPrimary(added.id);
      }
      if (!mounted) return;
      context.go(Routes.kycDeclarations);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _continueWithExisting() => context.go(Routes.kycDeclarations);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KycTopBar(
              onBack: () => context.go(Routes.kycUtilityBill),
              stepLabel: 'Verification · 6 of 8',
            ),
            const KycStepProgress(total: 8, current: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: FutureBuilder<List<BankAccountSummary>>(
                  future: _existingFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: KLoadingView(),
                      );
                    }
                    final primaries = (snapshot.data ?? const []).where((a) => a.primary).toList();
                    final existingPrimary = primaries.isEmpty ? null : primaries.first;
                    final showExisting = existingPrimary != null && !_showAddForm;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const KScreenHead(
                          title: 'Add your bank account',
                          body: 'One account, in your own name. Dividends and sale proceeds land here directly.',
                        ),
                        const SizedBox(height: 20),
                        if (showExisting) ...[
                          _ExistingAccountCard(
                            account: existingPrimary,
                            onChangeAccount: () => setState(() => _showAddForm = true),
                          ),
                        ] else ...[
                          _buildAddForm(),
                        ],
                        const SizedBox(height: 14),
                        _DcsPanel(checked: _dcs, onChanged: (v) => setState(() => _dcs = v)),
                        const SizedBox(height: 14),
                        Text(
                          'Withdrawals can only ever go to a DCS account in your name. You can add another later in Account, under Bank accounts.',
                          style: KType.data(color: KColor.ink3),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
              child: FutureBuilder<List<BankAccountSummary>>(
                future: _existingFuture,
                builder: (context, snapshot) {
                  final hasPrimary = (snapshot.data ?? const []).any((a) => a.primary);
                  final showExisting = hasPrimary && !_showAddForm;
                  return KButton(
                    label: 'Continue',
                    loading: _busy,
                    onPressed: _busy
                        ? null
                        : (showExisting ? _continueWithExisting : _addAndContinue),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddForm() {
    return FutureBuilder<List<Bank>>(
      future: _banksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: KLoadingView(),
          );
        }
        if (snapshot.hasError) {
          return KErrorView(onPrimary: () => setState(() => _banksFuture = _repo.banks()));
        }
        final banks = snapshot.data ?? const <Bank>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KEyebrow('Bank'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: banks.isEmpty ? null : () => _pickBank(banks),
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
                        style: KType.body(color: _bank == null ? KColor.ink3 : KColor.ink, w: KWeight.medium),
                      ),
                    ),
                    const SizedBox(width: 10),
                    KIcon('chevronRight', size: 20, color: KColor.ink3),
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
              placeholder: '10 digits',
              error: _showErrors && !_canAdd ? 'Select a bank and enter a valid account number' : null,
              helper: _resolving
                  ? 'Resolving account name…'
                  : _resolvedName != null
                      ? 'Account name: $_resolvedName'
                      : null,
              onChanged: (_) {
                setState(() {});
                _maybeResolveName();
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: KType.body(color: KColor.loss)),
            ],
          ],
        );
      },
    );
  }
}

/// A primary account that already exists (resume, or a re-visit via Review's
/// "Edit") — shown instead of the add form so Continue doesn't re-add it.
class _ExistingAccountCard extends StatelessWidget {
  const _ExistingAccountCard({required this.account, required this.onChangeAccount});
  final BankAccountSummary account;
  final VoidCallback onChangeAccount;

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: KColor.indicatorTint, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: KIcon('wallet', size: 18, color: KColor.indicator),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(account.bankName, style: KType.cardTitle()),
                Text(account.accountNumberMasked, style: KType.data(color: KColor.ink2)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onChangeAccount,
            behavior: HitTestBehavior.opaque,
            child: Text('Change', style: KType.data(color: KColor.indicator)),
          ),
        ],
      ),
    );
  }
}

/// The DCS explainer panel + checkbox — canvas copy verbatim.
class _DcsPanel extends StatelessWidget {
  const _DcsPanel({required this.checked, required this.onChanged});
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: KColor.indicatorTint, borderRadius: KRadii.featureR),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Direct Cash Settlement',
                    style: KType.cardTitle(color: KColor.indicatorPress)),
              ),
              Text('REQUIRED BY THE NGX', style: KType.micro(color: KColor.ink3)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'With DCS, money from a sale or a dividend goes from the CSCS to your bank account — it never sits with a broker. That includes us.',
            style: KType.body(color: KColor.ink2),
          ),
          const SizedBox(height: 10),
          KCheckbox(
            checked: checked,
            onChanged: onChanged,
            label: 'Use this account for Direct Cash Settlement',
          ),
        ],
      ),
    );
  }
}

/// Same shape as bank_accounts_screen.dart's own _BankPickerSheet — this
/// codebase's per-screen small-widget convention duplicates rather than
/// shares (see id_upload.dart's _IdTypeRow comment).
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
        KInput(controller: _search, placeholder: 'Search banks', icon: 'search', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text('No banks match "$query".', style: KType.body(color: KColor.ink3)),
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
  const _BankOptionRow({required this.bank, required this.selected, required this.first, required this.onTap});
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
