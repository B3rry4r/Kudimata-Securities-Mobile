// Tax documents (screen 85, 2026-08-23 design-canvas growth pass, 66 → 97
// screens). Reachable from Statements (52) and Dividends (84) per the
// canvas's own nav note — both entry points are outside this agent's file
// ownership (statements_screen.dart's tab structure and the Dividends
// screen are owned by concurrent agents/clusters), so this screen is built
// standalone and ready to be pushed once those entry points exist; see this
// pass's report for the exact route this needs.
//
// Real backend limitation, flagged rather than faked — this screen is
// almost entirely gap:
//
// 1. "2026 so far" (dividends received / withholding tax deducted / paid to
//    you) has no data source anywhere on this backend. lib/data/models.dart's
//    `TxnType` enum is {fund, withdraw, buy, sell, convert} — no `dividend`
//    value — and holding_detail_screen.dart's own header comment already
//    documents the direct check against this backend's real Holding/
//    Transaction wire types confirming no dividend field exists there
//    either. There is nothing to sum for this card.
// 2. No tax-document resource exists to back the "WHT credit note" / "Annual
//    tax summary" rows. Two existing repositories were weighed for reuse:
//      - legal_documents_repository.dart's LegalDocument: a small, GLOBAL,
//        unscoped list of legal agreements (kind: risk_disclosure /
//        client_agreement / privacy_policy / terms_of_service / other,
//        confirmed by the backend's own service comment "small fixed list,
//        no pagination"). A WHT credit note or an annual tax summary is
//        investor-specific generated output, not a shared legal agreement —
//        forcing it into LegalDocument.kind would misuse a resource that
//        was deliberately built to NOT be per-user.
//      - statements_repository.dart's Statement: already per-user
//        (server-scoped to the caller), already generated-PDF shaped ({id,
//        kind, title, periodOrTradeRef, fileSizeBytes, generatedAt,
//        fileObjectKey}), and already has the download-URL plumbing this
//        kind of document needs. This is the right shape.
//    Judgment call: if/when the backend builds tax documents, they should
//    extend Statement.kind with new values (e.g. `wht_credit_note`,
//    `annual_tax_summary`) and reuse GET /statements?kind=... + GET
//    /statements/:id/download-url — NOT a new endpoint bolted onto
//    /legal-documents. Those kind values don't exist yet, so this screen
//    makes no speculative network call against either repository; a call
//    against a `kind` the backend doesn't recognise would just fail, which
//    is no more honest than not calling at all (same reasoning
//    withdraw_mandate_screen.dart's header comment already applies to a
//    missing endpoint rather than a missing kind value).
//
// The one thing on this screen that IS real: the "Do I owe tax on this?"
// explainer is static compliance/educational copy (register-agnostic tax
// guidance, not user data), so it's shown verbatim via KExplainPanel, same
// as contract_note_screen.dart keeps its static compliance footer.
import 'package:flutter/material.dart';

import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

class TaxDocumentsScreen extends StatelessWidget {
  const TaxDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Tax',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const KEyebrow('2026 so far'),
                const SizedBox(height: 10),
                Text(
                  "Dividend and withholding-tax figures aren't tracked on this "
                  'account yet — check back once this is available.',
                  style: KType.body(color: KColor.ink2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          KCard(
            child: Text(
              'No tax documents are available yet — a WHT credit note is '
              'issued after your first dividend payment, and an annual tax '
              'summary after your first full year.',
              style: KType.body(color: KColor.ink2),
            ),
          ),
          const SizedBox(height: 12),
          const KExplainPanel(
            title: 'Do I owe tax on this?',
            body:
                'Withholding tax on dividends is deducted before you are paid, '
                'and the credit note is your proof. Nigeria charges no capital '
                'gains tax on NGX shares held over a year. Your own tax '
                'position is yours to confirm.',
          ),
          const SizedBox(height: 20),
          KButton(
            label: 'Email me all tax documents',
            variant: KButtonVariant.secondary,
            iconLeft: 'mail',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Emailing tax documents isn't available yet — check back soon."),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
