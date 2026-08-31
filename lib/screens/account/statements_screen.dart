// Statements & documents — artboard s52, `docs/design/redesign-2026-08/
// 06 Account and Support.dc.html`. Id from RULINGS.md, not from a code
// comment (R-5): a prior pass here cited "screen 52" from the OLD 97-screen
// canvas, whose numbering renumbered `52` onto an unrelated screen. Rebuilt
// against the REAL s52, which turned out to differ from what was previously
// assumed in three real ways:
//
//   1. NOT a segmented Statements/Contract-notes/Tax tab bar. s52 is ONE
//      flat, chronologically-sorted document list mixing both kinds
//      together — "August 2026 · all brokers" (statement) sits directly
//      above "Contract note · MTNN buy" in the same list. The tab bar this
//      screen used to render doesn't exist on the real artboard at all, so
//      it's gone, along with the "Tax" pass-through it carried (s52 has no
//      Tax entry point either — see `tax_documents_screen.dart`'s own build
//      report re: reachability).
//   2. s52 draws a search pill ("Search by month, broker or company") and a
//      filter-chip row ("All brokers"/"Blue Marina"/"Meristem"/"2026").
//      Search is real (client-side, over the already-fetched title+date —
//      no server search endpoint exists). The broker chips are not: this
//      backend has no broker dimension anywhere on `Statement`
//      (statements_repository.dart's own header — `{id, kind, title,
//      periodOrTradeRef, fileSizeBytes, generatedAt, fileObjectKey}`, no
//      broker field), confirmed against statements.service.ts directly —
//      same standing gap statement_detail_screen.dart and
//      holding_detail_screen.dart already established for this backend.
//      Per that precedent, the broker chips are not built. The interaction
//      *pattern* — a quick filter-chip row — is kept, backed by something
//      real instead: distinct calendar years actually present in the
//      investor's own document list.
//   3. s52's footer button reads "Request a statement" and its own caption
//      note routes it to a dedicated `s56` screen (date-range picker +
//      broker picker). 2026-08-29: `s56` is now built
//      (request_statement_screen.dart) — the product owner named this
//      button specifically ("request statement is still wrong") after an
//      earlier pass kept it pointed at the plain generate-current-month
//      action instead of the real screen, because no backend endpoint
//      existed for a custom date range. `POST /statements/request`
//      (Kudimata-Securities-Backend's StatementGeneratorService.
//      generateRange) closes that gap, so the button now pushes to the
//      real screen, matching s56's own `onClick`.
//
// Wired per lib/data/api/README.md's FutureBuilder convention: the two
// kind-scoped lists (GET /statements?kind=monthly,
// GET /statements?kind=contract_note) are fetched together with
// Future.wait behind ONE `_future`/FutureBuilder — a single loading/error
// state for the whole pushed screen — then merged and sorted client-side
// for the flat list s52 actually draws.
//
// DOWNLOAD: each row is ONE tap target to the document view (the trailing
// download glyph is decorative, matching s52's own "any row opens the
// document" convention already established for this screen family) — not a
// second, separate download action. The per-document detail screens
// (statement_detail_screen.dart, contract_note_screen.dart) carry the real
// download button.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/statements_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

class StatementsScreen extends StatefulWidget {
  const StatementsScreen({super.key});

  @override
  State<StatementsScreen> createState() => _StatementsScreenState();
}

class _StatementsScreenState extends State<StatementsScreen> {
  late final _repo = StatementsRepository(AppScope.read(context).apiClient);

  /// R-49 — statements exist for a verified account. Read from AppState
  /// rather than re-fetching: it is already hydrated on every entry to
  /// this screen, and a second network call to answer a question the app
  /// already knows would make the empty state slower than the full one.
  bool get _kycApproved => AppScope.read(context).kycApproved;
  late Future<(List<Statement> statements, List<Statement> notes)> _future = _load();

  bool _generating = false;

  /// Pulls the current month on demand rather than waiting for the 1st.
  /// Backs ONLY the empty-state's own quick action now (s56 exists as its
  /// own screen — see file header — so s52's real footer button pushes
  /// there instead of calling this directly).
  Future<void> _generateThisMonth() async {
    setState(() => _generating = true);
    try {
      await _repo.generateThisMonth();
      if (!mounted) return;
      setState(() {
        _generating = false;
        _future = _load();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    }
  }

  Future<(List<Statement>, List<Statement>)> _load() async {
    final results = await Future.wait([
      _repo.list(StatementKind.monthly),
      _repo.list(StatementKind.contractNote),
    ]);
    return (results[0], results[1]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Statement>, List<Statement>)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const KAccountSubScaffold(title: 'Statements', child: KLoadingView());
        }
        if (snapshot.hasError) {
          return KAccountSubScaffold(
            title: 'Statements',
            child: KErrorView(onPrimary: () => setState(() => _future = _load())),
          );
        }
        final (statements, notes) = snapshot.data!;
        final merged = [...statements, ...notes]
          ..sort((a, b) {
            final ad = a.generatedAt;
            final bd = b.generatedAt;
            if (ad == null && bd == null) return 0;
            if (ad == null) return 1;
            if (bd == null) return -1;
            return bd.compareTo(ad);
          });

        if (merged.isEmpty) {
          // 2026-08-24: was a dead end. Statements are generated by a
          // monthly job on the 1st, so a newly-active investor saw "No
          // documents yet" with no way to get one and no explanation of
          // when one would appear. Kept from the prior pass — still true.
          return KAccountSubScaffold(
            title: 'Statements',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KEmptyView(
                  icon: 'card',
                  title: 'No documents yet',
                  message: 'Statements are prepared at the start of each month. '
                      'Contract notes appear as soon as an order fills.',
                  illustrationName: 'empty-statements',
                ),
                // R-49 (2026-08-31): the screen stays reachable before KYC —
                // every screen does — but preparing a statement does not. It
                // is not a passive read: it renders a PDF, uploads it and
                // emails it, for an account that has verified nothing and
                // traded nothing. Reported by the owner, who generated one on
                // an unverified account.
                //
                // The control is ABSENT rather than disabled. A dead button
                // fails this repo's own gate and, more to the point, tells the
                // investor nothing about why. The line below does.
                if (!_kycApproved) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Statements start once your account is verified.',
                    textAlign: TextAlign.center,
                    style: KType.body(color: KColor.ink3),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  KButton(
                    label: _generating ? 'Preparing…' : "Prepare this month's statement",
                    variant: KButtonVariant.secondary,
                    fullWidth: true,
                    loading: _generating,
                    onPressed: _generating ? null : _generateThisMonth,
                  ),
                ],
              ],
            ),
          );
        }

        return KAccountSubScaffold(
          title: 'Statements',
          // R-49: no request control until the account is verified. Same
          // reasoning as the prepare button above.
          footer: !_kycApproved
              ? null
              : KButton(
            label: 'Request a statement',
            iconLeft: 'plus',
            onPressed: () async {
              // s56 pops `true` on a successful request (see its own
              // header) — reload so the just-generated statement shows up
              // without a manual pull-to-refresh.
              final requested = await context.push<bool>(Routes.acctRequestStatement);
              if (requested == true && mounted) setState(() => _future = _load());
            },
          ),
          child: _StatementsBody(
            items: merged,
            onOpenStatement: (statement) =>
                context.push(Routes.acctStatementDetail, extra: statement),
            onOpenNote: (statement) => context.push(Routes.contractNote, extra: statement),
          ),
        );
      },
    );
  }
}

class _StatementsBody extends StatefulWidget {
  const _StatementsBody({
    required this.items,
    required this.onOpenStatement,
    required this.onOpenNote,
  });

  final List<Statement> items;
  final void Function(Statement statement) onOpenStatement;
  final void Function(Statement statement) onOpenNote;

  @override
  State<_StatementsBody> createState() => _StatementsBodyState();
}

class _StatementsBodyState extends State<_StatementsBody> {
  final _searchController = TextEditingController();
  String _query = '';
  int? _year;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<int> get _years {
    final years = widget.items
        .map((s) => s.generatedAt?.year)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return years;
  }

  List<Statement> get _filtered {
    final q = _query.trim().toLowerCase();
    return widget.items.where((s) {
      if (_year != null && s.generatedAt?.year != _year) return false;
      if (q.isEmpty) return true;
      return '${s.title} ${s.sub}'.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final years = _years;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KSearchPill(
          placeholder: 'Search by month or company',
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v),
        ),
        if (years.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                KPillChip(
                  label: 'All',
                  selected: _year == null,
                  onTap: () => setState(() => _year = null),
                ),
                for (final y in years) ...[
                  const SizedBox(width: 8),
                  KPillChip(
                    label: '$y',
                    selected: _year == y,
                    onTap: () => setState(() => _year = y == _year ? null : y),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No documents match your search.',
                style: KType.body(color: KColor.ink3)),
          )
        else ...[
          KEyebrow('Ready to download · ${filtered.length}'),
          const SizedBox(height: 9),
          for (var i = 0; i < filtered.length; i++) ...[
            if (i > 0) const SizedBox(height: 9),
            _DocumentRow(
              statement: filtered[i],
              onTap: filtered[i].kind == StatementKind.contractNote
                  ? () => widget.onOpenNote(filtered[i])
                  : () => widget.onOpenStatement(filtered[i]),
            ),
          ],
        ],
        const SizedBox(height: 18),
        // s52's real green callout. The prior pass's copy ("appear within
        // 24 hours") doesn't hold: `OrdersService.recordContractNote` runs
        // synchronously in the same request that fills the order
        // (Kudimata-Securities-Backend orders.service.ts), so a contract
        // note is filed the moment the trade executes, not up to a day
        // later. Per DECISIONS.md's standing rule on claims (R-9/R-34): a
        // designed line that overstates a real delay is corrected to what
        // the system actually does, not transcribed as drawn.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: KColor.statusApprovedTint,
            borderRadius: KRadii.illoR,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: KIcon('check', size: 17, color: KColor.gain),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Contract notes appear as soon as your order fills, issued by the '
                  'broker who executed it.',
                  style: KType.data(color: KColor.ink2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One document row — s52's card-per-row list ("background:paper;border:
/// hairline;radius:18;padding:14 16"), not the hairline-divided
/// `KAccountCard`/`KAccountRow` grouping other Account screens use. Built
/// local to this file rather than forked from `KAccountRow`, since s52's
/// visual shape (an individually bordered card per row) is genuinely
/// different from that shared widget's continuous-card-with-dividers shape.
class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.statement, required this.onTap});
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
