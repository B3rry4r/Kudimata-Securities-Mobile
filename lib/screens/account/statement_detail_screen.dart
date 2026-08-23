// Statement · per broker (screen 76, 2026-08-23 design-canvas growth pass,
// 66 → 97 screens). Pushed from a monthly-statement row in
// statements_screen.dart (mirrors how a contract-note row already pushes
// contract_note_screen.dart).
//
// Real backend limitation, flagged rather than faked — TWO separate gaps:
//
// 1. No broker dimension exists anywhere on this backend. Screen 76 mocks a
//    per-broker statement: a "Brokers · 1 of 1" summary field, all-brokers
//    opening/closing totals, then one section PER EXECUTING BROKER — its own
//    account number ("Acct BM-4471"), its own holdings, its own movements,
//    its own subtotal — with a note that a second broker would add a second
//    section. holding_detail_screen.dart's own header comment already
//    documents the direct check against this backend's real types
//    (Order/Holding, confirmed against prisma/schema.prisma): there is no
//    brokerId/brokerCode field anywhere, this app is single-broker today,
//    and "Blue Marina" (the co-brand this canvas uses as its example broker)
//    is the mockup's own placeholder co-branding, not a real integrated
//    partner. statements_repository.dart's `Statement` model is the same
//    story — {id, kind, title, periodOrTradeRef, fileSizeBytes, generatedAt,
//    fileObjectKey}, no broker field, no client/CHN field, no
//    balance/holdings/movements breakdown at all. For this screen to be
//    real, the backend would need a broker dimension on trades/holdings
//    (e.g. an Order/Holding `brokerId`) AND the Statement resource would
//    need to return structured per-broker sections instead of a flat file
//    reference. Neither exists, so this screen does not invent broker
//    names, account numbers or balances.
// 2. The mockup's dividend movement row ("28 Feb · MTN dividend +₦4,120.00")
//    has no backing data either: lib/data/models.dart's `TxnType` enum is
//    {fund, withdraw, buy, sell, convert} — no `dividend` value — the same
//    gap holding_detail_screen.dart already found and documented ("no such
//    field exists anywhere on the Holding/Transaction wire types").
//
// Given none of the structured content exists server-side, this screen
// follows contract_note_screen.dart's precedent exactly: render the real
// document metadata that IS on the wire (title, generated date, file size —
// the same `Statement.sub` getter contract_note_screen.dart already uses),
// and show one honest "not available yet" block for everything else,
// instead of fabricating broker names, balances or holdings that would look
// like real money but aren't.
import 'package:flutter/material.dart';

import 'package:kudimata_invest/data/repositories/statements_repository.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class StatementDetailScreen extends StatelessWidget {
  const StatementDetailScreen({super.key, required this.statement});
  final Statement statement;

  void _notAvailable(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: KDetailHeader(
        // #s76: header shows the statement's own period label ("February
        // 2026"), not a generic "Statement" title.
        title: statement.title,
        trailing: KIconButton(
          icon: 'download',
          semanticLabel: 'Download',
          onPressed: () => _notAvailable(
            context,
            'Downloads are not available yet — check back soon.',
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, 20, KSpace.gutter, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: KColor.paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KColor.hairline, width: 1),
                  boxShadow: KShadow.card,
                ),
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
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    // Honest stand-in for the per-broker balances/holdings/
                    // movements breakdown — see this file's header comment
                    // for the two confirmed backend gaps behind it.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: KColor.track,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "The full breakdown — balances, holdings and movements by "
                        "executing broker — isn't available yet. We'll let you know "
                        "when it's ready.",
                        style: KType.body(color: KColor.ink2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    // #s76's static compliance copy — only the part that
                    // doesn't describe the per-broker page structure this
                    // build doesn't have yet (see header comment).
                    Text(
                      'Valuations are NGX closing prices. Dividends are net of '
                      'withholding tax.',
                      style: KType.micro(color: KColor.ink3).copyWith(letterSpacing: 0, height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              KButton(
                label: 'Download PDF',
                iconLeft: 'download',
                onPressed: () => _notAvailable(
                  context,
                  'Downloads are not available yet — check back soon.',
                ),
              ),
              const SizedBox(height: 10),
              KButton(
                label: 'Email me this statement',
                variant: KButtonVariant.ghost,
                onPressed: () => _notAvailable(
                  context,
                  "Emailing statements isn't available yet — check back soon.",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
