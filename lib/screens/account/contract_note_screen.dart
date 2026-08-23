// Contract note document (screen 66, 2026-08-23 "Soft Landing" exactness
// pass — Flow G was entirely unbuilt until now).
//
// Real backend limitation, flagged rather than faked: screen-specs.md spec
// 66 mocks a full printable trade-confirmation document — client name, CHN,
// trade date, settlement date, a Bought/Shares·price/Consideration/
// Commission/NGX·SEC·CSCS fees/VAT/Total line-item breakdown, and a
// co-branded "Executed through" partner slot. NONE of that structured data
// exists anywhere on this backend: statements_repository.dart's `Statement`
// model carries only {id, kind, title, periodOrTradeRef, fileSizeBytes,
// generatedAt, fileObjectKey} — no trade figures at all — and that same
// file's header comment already documents that no real PDF is ever
// generated server-side (every fileObjectKey points at an S3 object that
// was never uploaded). Rather than inventing share counts, fees and VAT
// figures that would look like real money but aren't, this screen shows
// the real document metadata it DOES have (title, date, size) and an
// honest "not available yet" state for the rest — the same pattern
// statements_screen.dart's own download button already uses for this exact
// gap.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/data/repositories/statements_repository.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

class ContractNoteScreen extends StatelessWidget {
  const ContractNoteScreen({super.key, required this.statement});
  final Statement statement;

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Contract note',
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
                    const KMark(size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Kudimata Securities Ltd', style: KType.cardTitle()),
                          Text(statement.title, style: KType.data(color: KColor.ink3)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text(statement.sub, style: KType.data(color: KColor.ink2).tnum),
                const SizedBox(height: 20),
                // Honest stand-in for the line-item breakdown — see this
                // file's header comment for why the real figures can't be
                // shown yet.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: KColor.track,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "The itemised breakdown isn't available yet — check back soon or ask support for a copy.",
                    style: KType.body(color: KColor.ink2),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                // Static compliance copy from #s66's legal footer band — not
                // backend-dependent (unlike the line-item breakdown above),
                // so shown verbatim rather than omitted.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
                  child: Text(
                    'Kudimata Securities Ltd, SEC-registered · shares registered to your CHN at the '
                    'CSCS on settlement · this is a record of an executed order, not advice · fees '
                    'comprise broker commission plus NGX, SEC and CSCS charges and VAT.',
                    // #s66 explicitly overrides the micro role's usual
                    // tracked-uppercase treatment for this block:
                    // letter-spacing:0;text-transform:none — plain sentence
                    // case, not a label.
                    style: KType.micro(color: KColor.ink3).copyWith(letterSpacing: 0, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // #s66: buttons stack full-width (not a 2-up row); Download PDF is
          // the primary action with a download icon, Email is ghost.
          KButton(
            label: 'Download PDF',
            iconLeft: 'download',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Downloads are not available yet — check back soon.'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          KButton(
            label: 'Email me this receipt',
            variant: KButtonVariant.ghost,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Receipts are not available yet — check back soon.'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
