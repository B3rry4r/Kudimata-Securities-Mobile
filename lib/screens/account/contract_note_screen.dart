// Contract note document (screen 66, 2026-08-23 "Soft Landing" exactness
// pass — Flow G was entirely unbuilt until now).
//
// Real backend limitation, flagged rather than faked — precise version,
// corrected 2026-08-24 (the previous comment here overstated the gap): a
// real Order DOES carry units/price/value/reference/createdAt (real trade
// figures — see Kudimata-Securities-Backend's src/common/types/order.types.ts),
// so client name/date/shares/price/consideration are NOT fundamentally
// unavailable data. The actual gap is a data-model link: this screen only
// ever receives a `Statement` (statements_repository.dart:
// {id, kind, title, periodOrTradeRef, fileSizeBytes, generatedAt,
// fileObjectKey}), and for a contract-note Statement, `periodOrTradeRef` is
// set server-side to a Transaction id (src/statements/statements.service.ts
// `generateContractNote`), NOT an Order id/reference — and Transaction has
// no `orderId` foreign key back to the Order it originated from (confirmed
// against prisma/schema.prisma's own Transaction.orderId comment and
// order_status_screen.dart's identical finding). So there is no reliable
// way, client-side, to resolve a given contract-note Statement back to the
// specific Order whose real figures it should show — matching by any
// available id doesn't work, the id spaces are unrelated. Closing this for
// real needs backend work: either an `orderId` FK added to Transaction, or
// `generateContractNote()` embedding the real order's figures into the
// Statement/document at generation time — not a frontend wiring fix. The
// fee/commission/NGX·SEC·CSCS/VAT breakdown is a SEPARATE, deeper gap even
// once that's fixed: Order itself has no persisted fee breakdown fields at
// all (the "1.35%"/"commission, NGX, SEC, CSCS" figures shown at order
// placement in trade_flows.dart are computed client-side at that moment and
// never saved with the order) — so a true itemised breakdown needs new
// persisted fields on Order, not just a link. Until both are closed, this
// screen shows the real document metadata it DOES have (title, date, size)
// and an honest "not available yet" state for the rest — same pattern
// statements_screen.dart's own download button already uses.
//
// Also genuinely missing (canvas's own footer note on #s66): entry points
// from Orders (#s44) and Holding detail (#s39) — canvas says a filled order
// should open this screen from either of those, but the only real route
// today is from Statements (#s52). Adding those needs
// order_status_screen.dart / holding_detail_screen.dart changes, which are
// outside this file's scope.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/data/repositories/statements_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
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
      // Canvas #66's header carries a trailing download icon-button
      // (mockup wires it to `nav.s52`, but that's the prototype's stand-in
      // for a real download it can't perform either — literally navigating
      // this app to Statements on tap would be actively misleading, so this
      // uses the SAME honest "not available yet" treatment as the footer
      // Download PDF button below, not a fake navigation).
      headerTrailing: KIconButton(
        icon: 'download',
        semanticLabel: 'Download',
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Downloads are not available yet — check back soon.'),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Canvas #66 builds this as distinct full-bleed bands (each its
          // own padding/background, some `--paper`, some `--bg`, divided by
          // hairlines) rather than one uniformly-padded column — restructured
          // 2026-08-24 to match that exactly (was previously a single
          // padding:20 Column with Dividers, which couldn't show a band with
          // a different background reaching the card's own edges).
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: KColor.paper,
                border: Border.all(color: KColor.hairline, width: 1),
                boxShadow: KShadow.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const KMark(size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Kudimata Securities Ltd', style: KType.cardTitle()),
                              Text(statement.title.upper, style: KType.micro(color: KColor.ink3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // "Executed through" band — canvas #66's real, confirmed
                  // fact (not mockup placeholder): Blue Marina Securities is
                  // Kudimata's actual sponsoring/executing broker per the
                  // real Client Agreement (see legal_reference_screens.dart's
                  // PartnerDisclosuresScreen, which cites the same document)
                  // — every trade on this single-broker platform executes
                  // through them, so this is unconditional, not per-trade
                  // data. Reuses the same real asset legal_reference_screens.dart
                  // already established (assets/partners/blue-marina.png) —
                  // a smaller inline treatment here since canvas #66's row is
                  // a compact band inside the document, not #94's own
                  // dedicated bordered card.
                  GestureDetector(
                    onTap: () => context.push(Routes.acctLegalPartnerDisclosures),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                      decoration: BoxDecoration(
                        color: KColor.bg,
                        border: Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
                      ),
                      child: Row(
                        children: [
                          Text('Executed through'.upper, style: KType.micro(color: KColor.ink3)),
                          const SizedBox(width: 10),
                          Image.asset('assets/partners/blue-marina.png', height: 16, fit: BoxFit.contain),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
                    ),
                    child: Text(statement.sub, style: KType.data(color: KColor.ink2).tnum),
                  ),
                  // Honest stand-in for the line-item breakdown — see this
                  // file's header comment for why the real figures can't be
                  // shown yet.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
                    ),
                    child: Text(
                      "The itemised breakdown isn't available yet — check back soon or ask support for a copy.",
                      style: KType.body(color: KColor.ink2),
                    ),
                  ),
                  // Static compliance copy from #s66's legal footer band —
                  // not backend-dependent (unlike the line-item breakdown
                  // above), so shown verbatim rather than omitted.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    color: KColor.bg,
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
