// Dividends & e-mandate (screen 84, 2026-08-23 "Soft Landing"). Wired per
// lib/data/api/README.md's FutureBuilder convention:
// DividendRepository.summary() (GET /dividends/summary) replaces the
// hardcoded `kDividendsPaidThisYearLabel`, DividendRepository.history()
// (GET /dividends) replaces `kMockDividendHistory`, and
// DividendRepository.mandate()/.signMandate() (GET /e-dividend-mandate/me,
// POST /e-dividend-mandate/sign) replace the always-unsigned
// "Sign the e-dividend mandate" button that used to just show a "not
// available yet" snackbar. BankAccountsRepository.list() (already wired
// elsewhere, GET /bank-accounts) supplies the real primary-account subtitle
// instead of the old static "GTB ••••6789" fixture — reused here rather
// than duplicated, same as wallet_repository.dart importing
// BankAccountSummary from bank_accounts_repository.dart.
//
// IMPORTANT — the e-dividend mandate here is NOT the same thing as the
// existing DCS mandate in bank_accounts_screen.dart, even though both are
// called "the mandate" informally:
//   - DCS mandate (bank_accounts_screen.dart, backed by the real
//     `BankAccountSummary.primary` flag) routes CURRENT/FUTURE sale
//     proceeds and dividends from the CSCS straight to a bank account, for
//     shares already held through Kudimata.
//   - The e-dividend mandate this screen's warm card is about is a
//     registrar-level mechanism (per NGX/SEC market practice — Datamax,
//     Meristem, First Registrars etc.) for CLAIMING dividends that were
//     declared BEFORE any e-mandate existed on those shares — money that
//     sits unclaimed with a registrar, not with the CSCS, and isn't touched
//     by signing a DCS mandate. s84.html's own copy makes this explicit:
//     "Dividends from shares you held before an e-mandate existed sit with
//     the registrar." There is still no registrar-integration entity
//     anywhere in this codebase — DividendSummary.unclaimedKobo is
//     genuinely `null` from the backend (dividend.types.ts's own doc
//     comment), so that figure is rendered as "—", never fabricated.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/bank_accounts_repository.dart';
import 'package:kudimata_invest/data/repositories/dividend_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'corporate_actions_widgets.dart';

typedef _DividendsData = ({
  DividendSummary summary,
  List<Dividend> history,
  EDividendMandate mandate,
  BankAccountSummary? primaryBank,
});

class DividendsScreen extends StatefulWidget {
  const DividendsScreen({super.key});

  @override
  State<DividendsScreen> createState() => _DividendsScreenState();
}

class _DividendsScreenState extends State<DividendsScreen> {
  late final _repo = DividendRepository(AppScope.read(context).apiClient);
  late final _bankRepo = BankAccountsRepository(AppScope.read(context).apiClient);
  late Future<_DividendsData> _future = _load();

  // Same "prefer the freshest loaded data over FutureBuilder's own
  // snapshot" shape wallet_screens.dart's _WalletScreenState uses — signing
  // the mandate reloads everything (below) and should update the rendered
  // body without flashing back to KLoadingView.
  _DividendsData? _data;
  bool _signing = false;

  Future<_DividendsData> _load() async {
    final (summary, historyPage, mandate, banks) = await (
      _repo.summary(),
      _repo.history(),
      _repo.mandate(),
      _bankRepo.list(),
    ).wait;
    BankAccountSummary? primary;
    for (final b in banks) {
      if (b.primary) {
        primary = b;
        break;
      }
    }
    return (summary: summary, history: historyPage.data, mandate: mandate, primaryBank: primary);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    try {
      final data = await _future;
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException {
      // Leave `_data` as-is; FutureBuilder's own error branch handles a
      // failed FIRST load, and a failed reload just leaves the last-good
      // numbers showing (same posture as wallet_screens.dart's refresh).
    }
  }

  Future<void> _signMandate() async {
    setState(() => _signing = true);
    try {
      await _repo.signMandate();
      final data = await _load();
      if (!mounted) return;
      setState(() {
        _signing = false;
        _data = data;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _signing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return KCorpActionScaffold(
      title: 'Dividends',
      child: FutureBuilder<_DividendsData>(
        future: _future,
        builder: (context, snapshot) {
          final effective = _data ?? snapshot.data;
          if (effective == null) {
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
          }
          final data = effective!;
          return _DividendsBody(
            data: data,
            signing: _signing,
            onSignMandate: _signMandate,
          );
        },
      ),
    );
  }
}

class _DividendsBody extends StatelessWidget {
  const _DividendsBody({required this.data, required this.signing, required this.onSignMandate});

  final _DividendsData data;
  final bool signing;
  final VoidCallback onSignMandate;

  @override
  Widget build(BuildContext context) {
    final mandate = data.mandate;
    final summary = data.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: KColor.feature, borderRadius: KRadii.featureR),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paid to you this year', style: KType.micro(color: KColor.sun)),
              const SizedBox(height: 8),
              Text(
                _formatNaira(summary.paidThisYearKobo),
                style: TextStyle(
                  fontFamily: KType.fontDisplay,
                  fontWeight: KWeight.black,
                  fontSize: 32,
                  height: 1.0,
                  letterSpacing: -0.025 * 32,
                  color: KColor.featureInk,
                ).tnum,
              ),
              const SizedBox(height: 4),
              Text(
                data.primaryBank != null
                    ? 'All by Direct Cash Settlement · ${data.primaryBank!.bankName} '
                        '${data.primaryBank!.accountNumberMasked}'
                    : 'No DCS mandate set up yet',
                style: KType.data(color: KColor.featureInk2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: KColor.warmTint, borderRadius: KRadii.cardR),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Unclaimed from before Kudimata', style: KType.cardTitle()),
                  ),
                  const SizedBox(width: 10),
                  KStatusPill(
                    status: KStatus.pending,
                    // unclaimedKobo has no real registrar integration behind
                    // it yet (dividend_repository.dart's header comment) —
                    // an honest "—" rather than a fabricated estimate.
                    label: summary.unclaimedKobo != null ? _formatNaira(summary.unclaimedKobo!) : '—',
                    small: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Dividends from shares you held before an e-mandate existed sit with '
                'the registrar. Signing the e-dividend mandate once lets them pay '
                'everything to your bank.',
                style: KType.data(color: KColor.ink2),
              ),
              const SizedBox(height: 10),
              if (mandate.isSigned)
                Row(
                  children: [
                    const KStatusPill(status: KStatus.approved, label: 'Signed', small: true),
                    if (mandate.signedAt != null) ...[
                      const SizedBox(width: 8),
                      Text('on ${_formatDate(mandate.signedAt!)}',
                          style: KType.micro(color: KColor.ink3)),
                    ],
                  ],
                )
              else
                KButton(
                  label: 'Sign the e-dividend mandate',
                  variant: KButtonVariant.warm,
                  size: KButtonSize.md,
                  loading: signing,
                  onPressed: signing ? null : onSignMandate,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (data.history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No dividends paid yet.', style: KType.data(color: KColor.ink3)),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: KColor.paper,
              border: Border.all(color: KColor.hairline, width: 1),
              borderRadius: BorderRadius.circular(KRadii.card),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                for (var i = 0; i < data.history.length; i++)
                  _DividendRow(entry: data.history[i], first: i == 0),
              ],
            ),
          ),
        const SizedBox(height: 20),
        KButton(
          label: 'Withholding tax statement',
          variant: KButtonVariant.ghost,
          // Statements & documents is a real, already-existing screen
          // (lib/screens/account/statements_screen.dart, out of this
          // cluster's scope) — reusing its route here is plain navigation,
          // not a new backend action.
          onPressed: () => context.push(Routes.acctStatements),
        ),
      ],
    );
  }
}

class _DividendRow extends StatelessWidget {
  const _DividendRow({required this.entry, required this.first});
  final Dividend entry;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final whtPct = entry.grossKobo > 0 ? (entry.whtKobo / entry.grossKobo * 100).round() : 0;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: first ? BorderSide.none : BorderSide(color: KColor.hairline, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.ticker, style: KType.data(color: KColor.ink)),
                const SizedBox(height: 2),
                Text('${_formatDate(entry.payDate)} · net of $whtPct% WHT',
                    style: KType.micro(color: KColor.ink3)),
              ],
            ),
          ),
          Text(
            '+${_formatNaira(entry.netKobo)}',
            style: KType.data(color: KColor.gain, w: KWeight.semibold).tnum,
          ),
        ],
      ),
    );
  }
}

/// Minor-unit kobo -> "₦4,120.00" (thousands-grouped, 2dp) — same shape the
/// old static fixture used.
String _formatNaira(int kobo) {
  final abs = kobo.abs();
  final whole = abs ~/ 100;
  final minor = (abs % 100).toString().padLeft(2, '0');
  final wholeStr = whole.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  return '${kobo < 0 ? '−' : ''}₦$wholeStr.$minor';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "2026-02-28T00:00:00.000Z" -> "28 Feb 2026".
String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}
