// Dividends & e-mandate (screen 84, 2026-08-23 "Soft Landing" — new feature
// area). No `extra` — the figures are the same static illustrative fixtures
// as the rest of this cluster (see corporate_actions_data.dart).
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
//     the registrar." There is no registrar-integration entity anywhere in
//     this codebase.
// Neither the dividend ledger (paid-this-year total + history) nor the
// e-dividend-mandate-signing action has a real backend endpoint — see
// corporate_actions_data.dart's header for the full gap writeup. This
// screen is real, complete UI fed by that file's static fixtures, and the
// "Sign the e-dividend mandate" button surfaces the same honest "not
// available yet" message the rest of this app uses (it deliberately does
// NOT navigate into the onboarding bank/DCS screen — s19.html's own footer
// says that screen exists to set up DCS at account opening, gated behind
// KYC steps; re-entering onboarding for an already-verified investor would
// be wrong even if the UI shapes look similar).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'corporate_actions_data.dart';
import 'corporate_actions_widgets.dart';

class DividendsScreen extends StatelessWidget {
  const DividendsScreen({super.key});

  void _notAvailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Signing the e-dividend mandate isn't available yet — contact support to "
          'claim unclaimed dividends.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KCorpActionScaffold(
      title: 'Dividends',
      child: Column(
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
                  kDividendsPaidThisYearLabel,
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
                Text(kDcsAccountLabel, style: KType.data(color: KColor.featureInk2)),
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
                    const KStatusPill(
                      status: KStatus.pending,
                      label: kUnclaimedEstimateLabel,
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
                KButton(
                  label: 'Sign the e-dividend mandate',
                  variant: KButtonVariant.warm,
                  size: KButtonSize.md,
                  onPressed: () => _notAvailable(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: KColor.paper,
              border: Border.all(color: KColor.hairline, width: 1),
              borderRadius: BorderRadius.circular(KRadii.card),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                for (var i = 0; i < kMockDividendHistory.length; i++)
                  _DividendRow(entry: kMockDividendHistory[i], first: i == 0),
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
      ),
    );
  }
}

class _DividendRow extends StatelessWidget {
  const _DividendRow({required this.entry, required this.first});
  final DividendHistoryEntry entry;
  final bool first;

  @override
  Widget build(BuildContext context) {
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
                Text(entry.companyName, style: KType.data(color: KColor.ink)),
                const SizedBox(height: 2),
                Text(entry.metaLabel, style: KType.micro(color: KColor.ink3)),
              ],
            ),
          ),
          Text(
            entry.amountLabel,
            style: (entry.isCash
                    ? KType.data(color: KColor.gain, w: KWeight.semibold)
                    : KType.data(color: KColor.ink))
                .tnum,
          ),
        ],
      ),
    );
  }
}
