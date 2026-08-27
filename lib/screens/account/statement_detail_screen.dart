// Statement · per broker. No artboard (restyle-only per RULINGS.md — the
// old code comment cited "screen 76" from the pre-renumbering 97-screen
// canvas; per R-5, that id points at an unrelated screen in the current
// 56-artboard canvas and is stripped rather than kept as a false citation).
// Pushed from a monthly-statement row in statements_screen.dart (mirrors
// how a contract-note row already pushes contract_note_screen.dart).
//
// This pass brings the screen onto the KAccountSubScaffold/KCard idiom the
// rest of the Account cluster uses (contract_note_screen.dart,
// tax_documents_screen.dart, statements_screen.dart) — same header shape,
// same card token — instead of the bespoke Scaffold + shadowed Container it
// had. Content, copy and functionality are unchanged; this is restyle-only,
// not a redesign.
//
// Real backend limitation, flagged rather than faked — TWO separate gaps:
//
// 1. No broker dimension exists anywhere on this backend. The old canvas's
//    per-broker statement mock (a "Brokers · 1 of 1" summary field,
//    all-brokers opening/closing totals, then one section PER EXECUTING
//    BROKER with its own account number, holdings, movements and subtotal)
//    has no real counterpart: holding_detail_screen.dart's own header
//    comment already documents the direct check against this backend's
//    real types (Order/Holding, confirmed against prisma/schema.prisma) —
//    no brokerId/brokerCode field anywhere, this app is single-broker
//    today. statements_repository.dart's `Statement` model is the same
//    story — {id, kind, title, periodOrTradeRef, fileSizeBytes, generatedAt,
//    fileObjectKey}, no broker field, no client/CHN field, no
//    balance/holdings/movements breakdown at all on the list resource.
//    What IS real and verified (2026-08-24, against
//    Kudimata-Securities-Backend's statement-pdf.service.ts directly): the
//    generated PDF genuinely renders consolidated opening/closing totals
//    then one section per executing broker with its own holdings,
//    movements and subtotal — the generator is structurally per-broker
//    even though only one broker exists in practice today. So the "full
//    breakdown is in the PDF" copy below is a verified true claim, not an
//    invented one (R-9/R-34) — it is the inline rendering of that same
//    breakdown that doesn't exist, which is what the callout says.
// 2. The dividend movement row concept ("28 Feb · MTN dividend +₦4,120.00")
//    has no backing data on this resource either: lib/data/models.dart's
//    `TxnType` enum is {fund, withdraw, buy, sell, convert} — no
//    `dividend` value — the same gap holding_detail_screen.dart already
//    found and documented.
//
// Given none of the structured per-broker content exists on the list/detail
// resource this screen actually receives, it renders the real document
// metadata that IS on the wire (title, generated date, file size — the
// same `Statement.sub` getter contract_note_screen.dart already uses), and
// one honest explainer for everything else, instead of fabricating broker
// names, balances or holdings that would look like real money but aren't.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kudimata_invest/data/repositories/statements_repository.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

class StatementDetailScreen extends StatelessWidget {
  const StatementDetailScreen({super.key, required this.statement});
  final Statement statement;

  /// Opens the statement's real stored PDF via a short-lived presigned URL
  /// (GET /statements/:id/download-url). 2026-08-24: this button was an
  /// inert snackbar because nothing generated a PDF — monthly statements
  /// are now really rendered and uploaded (see the backend's
  /// StatementGeneratorService), so the download works. A statement with
  /// fileSizeBytes == 0 never got a file stored (its render or upload
  /// failed), and says so rather than opening a broken link.
  Future<void> _download(BuildContext context) async {
    if (statement.fileSizeBytes == 0) {
      _notAvailable(context, "This statement's PDF isn't available to download.");
      return;
    }
    try {
      final url = await StatementsRepository(AppScope.read(context).apiClient)
          .downloadUrl(statement.id);
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        _notAvailable(context, "Couldn't open the download. Try again.");
      }
    } on ApiException catch (e) {
      if (context.mounted) _notAvailable(context, e.message);
    }
  }

  void _notAvailable(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      // The statement's own period label ("August 2026 · all brokers"),
      // not a generic "Statement" title.
      title: statement.title,
      headerTrailing: KIconButton(
        icon: 'download',
        semanticLabel: 'Download',
        onPressed: () => _download(context),
      ),
      footer: KButton(
        label: 'Download PDF',
        iconLeft: 'download',
        onPressed: () => _download(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const KMark(size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Kudimata Securities Ltd', style: KType.cardTitle()),
                          Text(statement.sub, style: KType.data(color: KColor.ink3).tnum),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: KColor.hairline),
                const SizedBox(height: 16),
                // See file header point 1 — this claim is verified against
                // the real PDF generator, not asserted on faith.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: KColor.track,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'The full breakdown is in the PDF — your opening and closing '
                    'balances, then every holding, movement and subtotal for each '
                    'broker that executed for you.',
                    style: KType.body(color: KColor.ink2),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: KColor.hairline),
                const SizedBox(height: 16),
                // Verified against statement-pdf.service.ts's own compliance
                // copy — "dividends are net of withholding tax" is a direct
                // match, not a transcribed mock figure.
                Text(
                  'Valuations are market closing prices. Dividends are net of '
                  'withholding tax.',
                  style: KType.micro(color: KColor.ink3).copyWith(letterSpacing: 0, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Kept honest rather than removed: unlike a contract note
          // (emailed automatically on every fill), statements are not
          // dispatched by email anywhere — that needs a real send
          // endpoint. Download works, so the investor is not stuck.
          Text(
            'Statements are not emailed. Download keeps a copy on your device.',
            style: KType.data(color: KColor.ink3),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
