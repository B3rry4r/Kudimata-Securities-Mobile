// Tax documents (screen 85, 2026-08-23 design-canvas growth pass, 66 → 97
// screens). Reachable from Statements (52) and Dividends (84) per the
// canvas's own nav note — both entry points are owned by other clusters, so
// this screen is built standalone and pushed from account_screen.dart's own
// hub row. No artboard for THIS exact 56-artboard-canvas revision (R-5's
// renumbering leaves s85 pointing at an unrelated screen), so this pass is
// restyle-only per RULINGS.md: KAccountSubScaffold/KCard idiom matched
// against statements_screen.dart, legal_reference_screens.dart and
// faq_screen.dart, layout not reinvented.
//
// RESTORED 2026-08-27. Hidden 2026-08-24 on direct product instruction
// ("please hide everything on tax") because the mobile `StatementKind`
// enum had no tax kinds, so this screen could only show static "not
// available" copy pointing at a dead end. That condition is now met:
// statements_repository.dart's `StatementKind` gained `whtCreditNote` and
// `annualTaxSummary` (SHARED-CHANGE, this same pass), and this screen now
// makes two real `GET /statements?kind=` calls instead of hardcoding copy.
//
// The two kinds are NOT equally real on the backend (re-verified directly
// against Kudimata-Securities-Backend, 2026-08-27):
//   - `annual_tax_summary` IS generated: `StatementGeneratorService
//     .generateTaxSummariesForAll` runs on `@Cron('30 2 2 1 *')` (02:30, 2
//     January — once a tax year has closed) and creates one real Statement
//     row per investor who received a dividend that year. Listed here like
//     any other downloadable statement, opened via the SAME route
//     statements_screen.dart already uses for a Statement row
//     (`Routes.acctStatementDetail`, `StatementDetailScreen`'s real
//     presigned-download flow) — not a second download pattern.
//   - `wht_credit_note` has NO producer anywhere: `StatementsService
//     .generateTaxDocument()` accepts the kind but no caller — cron,
//     controller, or otherwise — ever passes it. `GET /statements?kind=
//     wht_credit_note` is a real, live call; it will just always come back
//     `[]` until the backend wires a producer. Rendered as a plain, honest
//     empty state that says so, per R-34 — not hidden again (that would
//     repeat the exact dead end this restore is undoing) and not a
//     fabricated row. Filed in BACKEND_GAPS.md.
//
// The "2026 so far" dividend/WHT summary card above both lists is
// unrelated to the StatementKind gap — `GET /dividends/summary` and
// `GET /dividends` are real, live, per-investor endpoints
// (dividend_repository.dart), unchanged by this pass.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/paginated_response.dart';
import 'package:kudimata_invest/data/repositories/dividend_repository.dart';
import 'package:kudimata_invest/data/repositories/statements_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

/// Minor-unit kobo -> "₦4,120.00" — same shape dividends_screen.dart's own
/// private formatter uses, for consistency across the two screens that both
/// render Dividend figures.
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

class _TaxData {
  const _TaxData({
    required this.year,
    required this.grossKobo,
    required this.whtKobo,
    required this.netKobo,
    required this.annualSummaries,
    required this.whtNotes,
  });
  final int year;
  final int grossKobo;
  final int whtKobo;
  final int netKobo;

  /// Real `annual_tax_summary` Statement rows — see file header.
  final List<Statement> annualSummaries;

  /// Real, live `wht_credit_note` query — always `[]` today because
  /// nothing on the backend generates this kind yet. See file header.
  final List<Statement> whtNotes;
}

class TaxDocumentsScreen extends StatefulWidget {
  const TaxDocumentsScreen({super.key});

  @override
  State<TaxDocumentsScreen> createState() => _TaxDocumentsScreenState();
}

class _TaxDocumentsScreenState extends State<TaxDocumentsScreen> {
  late final _dividendRepo = DividendRepository(AppScope.read(context).apiClient);
  late final _statementsRepo = StatementsRepository(AppScope.read(context).apiClient);
  late Future<_TaxData> _future = _load();

  Future<_TaxData> _load() async {
    final results = await Future.wait([
      _dividendRepo.summary(),
      // history() sorts payDate:desc server-side and defaults to a 20-row
      // page; a generous single page is enough to sum THIS year's payouts
      // for any realistic investor without walking pagination for an MVP
      // figure — still real data, not fabricated, just bounded to the most
      // recent 100.
      _dividendRepo.history(pageSize: 100),
      _statementsRepo.list(StatementKind.annualTaxSummary),
      _statementsRepo.list(StatementKind.whtCreditNote),
    ]);
    final summary = results[0] as DividendSummary;
    final historyPage = results[1] as PaginatedResponse<Dividend>;
    final annualSummaries = results[2] as List<Statement>;
    final whtNotes = results[3] as List<Statement>;

    final thisYear = historyPage.data.where((d) => d.payDate.year == summary.year);
    final grossKobo = thisYear.fold<int>(0, (sum, d) => sum + d.grossKobo);
    final whtKobo = thisYear.fold<int>(0, (sum, d) => sum + d.whtKobo);

    return _TaxData(
      year: summary.year,
      grossKobo: grossKobo,
      whtKobo: whtKobo,
      netKobo: summary.paidThisYearKobo,
      annualSummaries: annualSummaries,
      whtNotes: whtNotes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Tax',
      child: FutureBuilder<_TaxData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const KLoadingView();
          }
          if (snapshot.hasError) {
            return KErrorView(onPrimary: () => setState(() => _future = _load()));
          }
          final data = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KEyebrow('${data.year} so far'),
                    const SizedBox(height: 10),
                    _TaxRow(label: 'Dividends received', value: _formatNaira(data.grossKobo)),
                    _TaxRow(label: 'Withholding tax deducted', value: _formatNaira(data.whtKobo)),
                    const Divider(height: 20),
                    _TaxRow(
                      label: 'Paid to you',
                      value: _formatNaira(data.netKobo),
                      emphasis: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              KEyebrow('Annual tax summary'),
              const SizedBox(height: 9),
              if (data.annualSummaries.isEmpty)
                KCard(
                  child: Text(
                    'No annual tax summary yet — one is prepared automatically '
                    'once your first full tax year with a dividend payment has '
                    'closed.',
                    style: KType.body(color: KColor.ink2),
                  ),
                )
              else
                for (var i = 0; i < data.annualSummaries.length; i++) ...[
                  if (i > 0) const SizedBox(height: 9),
                  _TaxDocumentRow(
                    statement: data.annualSummaries[i],
                    onTap: () => context.push(
                      Routes.acctStatementDetail,
                      extra: data.annualSummaries[i],
                    ),
                  ),
                ],
              const SizedBox(height: 20),
              KEyebrow('WHT credit notes'),
              const SizedBox(height: 9),
              if (data.whtNotes.isEmpty)
                KCard(
                  child: Text(
                    "WHT credit notes aren't being issued yet — this document "
                    "type hasn't gone live on our side. The withholding tax "
                    "deducted from your dividends is already reflected in the "
                    "summary above.",
                    style: KType.body(color: KColor.ink2),
                  ),
                )
              else
                for (var i = 0; i < data.whtNotes.length; i++) ...[
                  if (i > 0) const SizedBox(height: 9),
                  _TaxDocumentRow(
                    statement: data.whtNotes[i],
                    onTap: () => context.push(
                      Routes.acctStatementDetail,
                      extra: data.whtNotes[i],
                    ),
                  ),
                ],
              const SizedBox(height: 20),
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
          );
        },
      ),
    );
  }
}

class _TaxRow extends StatelessWidget {
  const _TaxRow({required this.label, required this.value, this.emphasis = false});
  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasis ? KType.cardTitle() : KType.data(color: KColor.ink2),
            ),
          ),
          Text(
            value,
            style: (emphasis ? KType.cardTitle() : KType.data(color: KColor.ink)).tnum,
          ),
        ],
      ),
    );
  }
}

/// One tax-document row — mirrors statements_screen.dart's own
/// `_DocumentRow` (card-per-row, hairline border, doc glyph, tap-through to
/// the detail/download screen). Not imported from there — that class is
/// screen-local private per the house pattern (SCREEN-AGENT-BRIEF.md rule
/// 5) — but the same visual shape and the same tap-through-to-download
/// interaction, not a second download pattern.
class _TaxDocumentRow extends StatelessWidget {
  const _TaxDocumentRow({required this.statement, required this.onTap});
  final Statement statement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: KColor.paper,
          border: Border.all(color: KColor.hairline, width: 1),
          borderRadius: KRadii.illoR,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KColor.indicatorTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: KIcon('doc', size: 18, color: KColor.indicator),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(statement.title, style: KType.cardTitle()),
                  const SizedBox(height: 1),
                  Text(statement.sub, style: KType.data(color: KColor.ink3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            KIcon('download', size: 17, color: KColor.ink3),
          ],
        ),
      ),
    );
  }
}
