// KYC 5 of 7 — Bank & Direct Cash Settlement (canvas screen 19). NEW screen
// (2026-08-24, re-sequencing to the canvas's real 8-step flow; renumbered
// 8->7 (was 6 of 8) 2026-08-27 per X-2/bvn_nin.dart's derivation).
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
//
// 2026-08-29 (A-4 audit fix): post-confirm navigation used to go to
// Routes.kycChecklist unconditionally, forcing a tap through the checklist
// hub's own UI to continue. Now advances straight to the real next step
// (Declarations) via nextKycStepRoute (kyc_checklist_screen.dart) — the hub
// itself is unchanged and stays the resume point for an investor
// re-entering KYC part-way.
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
import 'kyc_checklist_screen.dart' show nextKycStepRoute;

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
    final accountNumber = _accountNumber.text.trim();
    try {
      final added = await _repo.add(bankCode: bank.code, accountNumber: accountNumber);
      if (_dcs && !added.primary) {
        await _repo.setPrimary(added.id);
      }
      if (!mounted) return;
      setState(() => _busy = false);
      // s18b — confirm before moving on. Only shown right after adding an
      // account THIS session, where the real bank/number/name are all in
      // hand; see _continueWithExisting's own comment for why a resumed
      // existing account skips this instead.
      await _showConfirmSheet(
        bankName: bank.name,
        accountNumber: accountNumber,
        holderName: _resolvedName,
      );
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

  // Resume path (an investor who already added a primary account before —
  // this session or an earlier one): "Continue just moves on", per this
  // file's header comment. No s18b sheet here — BankAccountSummary carries
  // only a MASKED account number and no account-holder name at all (see
  // BankAccountsRepository), so a confirm sheet built from it would show
  // "****6835" and a blank Name row rather than the real values s18b draws;
  // that's worse than the resume shortcut it would replace. The account was
  // already confirmed the session it was added.
  Future<void> _goToNextStep() async {
    final next = await nextKycStepRoute(AppScope.read(context).apiClient);
    if (!mounted) return;
    context.go(next);
  }

  void _continueWithExisting() => _goToNextStep();

  /// s18b "Confirm your bank account" sheet. Primary -> declarations; ghost
  /// "Edit" just dismisses back onto s18 (the form stays exactly as typed).
  Future<void> _showConfirmSheet({
    required String bankName,
    required String accountNumber,
    required String? holderName,
  }) async {
    final confirmed = await showKSheet<bool>(
      context,
      child: _BankConfirmSheet(bankName: bankName, accountNumber: accountNumber, holderName: holderName),
    );
    if (confirmed == true && mounted) await _goToNextStep();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KycTopBar(
              // R-45 as amended: locked (pre-restart) goes to the checklist
              // hub, in-session goes to the normal predecessor — see
              // kycBackTarget's own doc comment.
              onBack: () => context.go(kycBackTarget(context, Routes.kycBankDcs)),
              stepLabel: 'Verification · 5 of 7',
            ),
            const KycStepProgress(total: 7, current: 5),
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
                          body: 'Withdrawals and dividends are paid here. It must be in your name.',
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
              helper: _resolving ? 'Resolving account name…' : null,
              onChanged: (_) {
                setState(() {});
                _maybeResolveName();
              },
            ),
            // s18's resolved-name confirmation — a distinct gain-tinted
            // pill (check + the name in caps), not inline helper text under
            // the field.
            if (!_resolving && _resolvedName != null) ...[
              const SizedBox(height: 14),
              _ResolvedNameBanner(name: _resolvedName!),
            ],
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

/// s18's "ADEBAYO OKONKWO" confirmation row — a gain-tinted pill with a
/// check icon, shown once [BankAccountsRepository.resolveAccountName]
/// returns a real name for the bank+account-number pair just entered.
class _ResolvedNameBanner extends StatelessWidget {
  const _ResolvedNameBanner({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: KColor.gain.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          KIcon('check', size: 18, color: KColor.gain),
          const SizedBox(width: 12),
          Expanded(child: Text(name.toUpperCase(), style: KType.cardTitle())),
        ],
      ),
    );
  }
}

/// s18b "Confirm your bank account" — a sheet over s18, per the artboard:
/// title, subtitle, a three-row Bank/Account/Name card, a primary "The
/// details are correct" (-> declarations) and a ghost "Edit" (-> back to the
/// form, unchanged). NOT included: the artboard's "Changing it later takes a
/// 24-hour security hold" line — this codebase has no such mechanism
/// anywhere (grepped end to end), and shipping a security guarantee nothing
/// enforces is worse than a wrong figure; the same call already made for the
/// identical line elsewhere in this redesign.
class _BankConfirmSheet extends StatelessWidget {
  const _BankConfirmSheet({required this.bankName, required this.accountNumber, required this.holderName});
  final String bankName;
  final String accountNumber;
  final String? holderName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Confirm your bank account', textAlign: TextAlign.center, style: KType.section()),
        const SizedBox(height: 8),
        Text('Dividends and withdrawals will be paid here.',
            textAlign: TextAlign.center, style: KType.body(color: KColor.ink2)),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: KColor.bg,
            border: Border.all(color: KColor.hairline, width: 1),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              _ConfirmRow(label: 'Bank', value: bankName, divider: true),
              _ConfirmRow(label: 'Account', value: accountNumber, divider: true),
              _ConfirmRow(label: 'Name', value: holderName ?? '—', divider: false),
            ],
          ),
        ),
        const SizedBox(height: 22),
        KButton(label: 'The details are correct', onPressed: () => Navigator.of(context).pop(true)),
        const SizedBox(height: 10),
        KButton(label: 'Edit', variant: KButtonVariant.ghost, onPressed: () => Navigator.of(context).pop(false)),
      ],
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.label, required this.value, required this.divider});
  final String label;
  final String value;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: KColor.hairline, width: 1)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KType.data(color: KColor.ink3)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right, style: KType.cardTitle(), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
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

/// s18's DCS panel — checkbox (checked by default) + label + explainer, plus
/// a "What is Direct Cash Settlement?" link, copy verbatim from the canvas.
class _DcsPanel extends StatelessWidget {
  const _DcsPanel({required this.checked, required this.onChanged});
  final bool checked;
  final ValueChanged<bool> onChanged;

  void _explain(BuildContext context) {
    showKSheet<void>(
      context,
      child: const KExplainPanel(
        title: 'What is Direct Cash Settlement?',
        body: 'Direct Cash Settlement, required by the NGX. Money goes from the exchange to your bank, '
            'never through us.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border.all(color: KColor.hairline, width: 1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          KCheckbox(
            checked: checked,
            onChanged: onChanged,
            label: 'Pay my sales and dividends straight to this bank account',
            description:
                'Direct Cash Settlement, required by the NGX. Money goes from the exchange to your bank, never through us.',
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _explain(context),
            behavior: HitTestBehavior.opaque,
            child: Text('What is Direct Cash Settlement?',
                style: KType.data(color: KColor.indicator, w: KWeight.semibold)),
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
