// Tax documents (screen 85, 2026-08-23 design-canvas growth pass, 66 → 97
// screens). Reachable from Statements (52) and Dividends (84) per the
// canvas's own nav note — both entry points are owned by other clusters, so
// this screen is built standalone and ready to be pushed once those entry
// points exist.
//
// 2026-08-24 rebuild — the "2026 so far" card was previously a static
// "not tracked yet" notice, written before DividendsModule/
// dividend_repository.dart existed. Re-checked against the current backend:
// `GET /dividends/summary` + `GET /dividends` ARE real, live, per-investor
// endpoints (see dividend_repository.dart) — every Dividend row carries
// real grossKobo/whtKobo/netKobo. That was a stale gap claim, not a real
// one; fixed to use the real data, same class of bug as asset-detail's
// ProductCard rendering "—" for constants that already existed elsewhere.
//
// GENUINE REMAINING GAP: the "WHT credit note" / "Annual tax summary"
// DOCUMENT rows. Re-checked directly against Kudimata-Securities-Backend
// (2026-08-27), since a lot changed since this comment was last true:
//   - `annual_tax_summary` generation is NOW real and wired:
//     `StatementGeneratorService.generateTaxSummariesForAll` runs on a
//     `@Cron('30 2 2 1 *')` (02:30 on 2 January, once the tax year has
//     closed) and creates one real Statement row per investor who received
//     a dividend that year — matching this screen's own "after your first
//     full year" copy. No client call is needed to trigger it.
//   - `wht_credit_note` generation is still genuinely unwired — no cron,
//     no controller endpoint, no other caller anywhere calls
//     `StatementsService.generateTaxDocument('wht_credit_note', …)`. That
//     half of the gap still stands as originally filed.
//   - Both kinds ARE queryable via `GET /statements?kind=` — the backend's
//     `ListStatementsQueryDto.KIND_VALUES` already accepts both — but the
//     mobile `StatementKind` enum (statements_repository.dart) still only
//     declares `monthly`/`contractNote`. Extending it is a
//     `lib/data/**` change, off-limits to a screen agent per
//     SCREEN-AGENT-BRIEF.md rule 5 — filed as a SHARED-CHANGE REQUEST
//     rather than worked around locally.
// Kept as static, honestly-worded "not available yet" copy until the shared
// enum is extended — NOT a live call to a kind this mobile client can't yet
// ask for.
import 'package:flutter/material.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/repositories/dividend_repository.dart';
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
  });
  final int year;
  final int grossKobo;
  final int whtKobo;
  final int netKobo;
}

class TaxDocumentsScreen extends StatefulWidget {
  const TaxDocumentsScreen({super.key});

  @override
  State<TaxDocumentsScreen> createState() => _TaxDocumentsScreenState();
}

class _TaxDocumentsScreenState extends State<TaxDocumentsScreen> {
  late final _dividendRepo = DividendRepository(AppScope.read(context).apiClient);
  late Future<_TaxData> _future = _load();

  Future<_TaxData> _load() async {
    final summary = await _dividendRepo.summary();
    // history() sorts payDate:desc server-side and defaults to a 20-row
    // page; a generous single page is enough to sum THIS year's payouts for
    // any realistic investor without walking pagination for an MVP figure —
    // still real data, not fabricated, just bounded to the most recent 100.
    final historyPage = await _dividendRepo.history(pageSize: 100);
    final thisYear = historyPage.data.where((d) => d.payDate.year == summary.year);
    final grossKobo = thisYear.fold<int>(0, (sum, d) => sum + d.grossKobo);
    final whtKobo = thisYear.fold<int>(0, (sum, d) => sum + d.whtKobo);

    return _TaxData(
      year: summary.year,
      grossKobo: grossKobo,
      whtKobo: whtKobo,
      netKobo: summary.paidThisYearKobo,
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
              const SizedBox(height: 12),
              // See file header — a real, live document list needs the
              // shared StatementKind enum extended (out of this file's
              // ownership this pass) plus a real generation trigger on the
              // backend (doesn't exist yet either). Honest static copy,
              // not a fabricated document list.
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
