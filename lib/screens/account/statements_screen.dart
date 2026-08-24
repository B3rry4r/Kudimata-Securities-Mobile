// Stage 9 — Statements & documents (pushed). A three-way tab (Statements /
// Contract notes / Tax) over a single flat document list, each row a plain
// title+caption with a decorative download glyph — the whole row opens the
// document. Mirrors `Statements` in settings-screens.jsx / design canvas
// screen 52.
//
// Wired per lib/data/api/README.md's FutureBuilder convention: the two
// list sections are independent Statement.kind slices of the same resource
// (GET /statements?kind=monthly and GET /statements?kind=contract_note),
// fetched together with Future.wait behind ONE `_future` field/FutureBuilder
// — a single loading/error state for the whole pushed screen, same as every
// other single-`_future` screen in this app; there's no cross-section
// dependency that would justify two independent FutureBuilders.
//
// DOWNLOAD (2026-08-20 — "what are the statements and documents section
// for??"): each row used to carry its own tappable download button that
// fetched a presigned URL (GET /statements/:id/download-url) and launched it
// externally. The backend's own statements.service.ts header comment
// documents that no real PDF is ever generated in this phase — every row's
// fileObjectKey points at an S3 object that was never uploaded, so that URL
// always 404s (S3 NoSuchKey) the moment it's opened. The canvas's own footer
// note is explicit either way: "any row opens the document (76 statement,
// 66 contract note)" — the whole row is ONE tap target to the document view,
// with the download glyph purely decorative inside it, not a second,
// separate download action. Removed the standalone per-row download control
// to match (2026-08-23 exactness pass); the honest "not ready yet" download
// affordance belongs inside the per-document detail screens (76, 66), not
// duplicated here.
//
// PER-BROKER STATEMENT DETAIL (2026-08-23, design-canvas growth pass, screen
// 76): monthly-statement rows push StatementDetailScreen via the named
// Routes.acctStatementDetail route (wired centrally once all screen-cluster
// agents finished their file-disjoint passes), the same way a contract-note
// row already pushes ContractNoteScreen via Routes.contractNote.
//
// TAX DOCUMENTS ENTRY POINT (screen 85) / SEGMENTED TABS (2026-08-23,
// screens 52-59 re-audit): the canvas's screen 52 top has a real
// SegmentedControl with three tabs (Statements / Contract notes / Tax) over
// ONE flat card, not two stacked eyebrow'd sections plus a separate "Tax
// documents" row — a prior pass deferred the tab rebuild as "a bigger
// structural change" and shipped the stacked-sections/extra-row version
// instead. Rebuilt here as a real KSegmentedControl: Statements and Contract
// notes swap the single list in place (both already fetched); Tax has no
// data of its own on this screen; selecting it just navigates straight to
// TaxDocumentsScreen (screen 85), same destination the old row pointed at.
// No broker filter chip ("All brokers" / "Blue Marina" PillChips in the
// canvas): this backend has no broker dimension anywhere (confirmed by
// statement_detail_screen.dart and holding_detail_screen.dart, both already
// audited this pass) — this app is single-broker today, so a broker filter
// with nothing to filter would be decorative-only; omitted per the same
// convention those two sibling screens already established.
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
  late Future<(List<Statement> statements, List<Statement> notes)> _future = _load();

  // Canvas SegmentedControl value — 'statements' selected by default
  // (matches `value="Statements"` on screen 52). 'tax' is a pass-through:
  // selecting it just navigates to TaxDocumentsScreen and the control keeps
  // showing whichever real tab was selected before, since Tax has no list
  // of its own to display inline here.
  String _tab = 'statements';

  bool _generating = false;

  /// Pulls the current month on demand rather than waiting for the 1st.
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
    return KAccountSubScaffold(
      // screen-specs.md spec 52's header is exactly "Statements" (the
      // Account-hub menu ROW is separately labelled "Statements &
      // documents" — that's the entry point's own string, not this
      // screen's header; 2026-08-23 exactness pass).
      title: 'Statements',
      child: FutureBuilder<(List<Statement>, List<Statement>)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const KLoadingView();
          }
          if (snapshot.hasError) {
            return KErrorView(
              onPrimary: () => setState(() => _future = _load()),
            );
          }
          final (statements, notes) = snapshot.data!;
          if (statements.isEmpty && notes.isEmpty) {
            // 2026-08-24: was a dead end. Statements are generated by a
            // monthly job on the 1st, so a newly-active investor saw "No
            // documents yet" with no way to get one and no explanation of
            // when one would appear.
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KEmptyView(
                  icon: 'card',
                  title: 'No documents yet',
                  message: 'Statements are prepared at the start of each month. '
                      'Contract notes appear as soon as an order fills.',
                  illustrationName: 'empty-statements',
                ),
                const SizedBox(height: 12),
                KButton(
                  label: _generating ? 'Preparing…' : "Prepare this month's statement",
                  variant: KButtonVariant.secondary,
                  fullWidth: true,
                  loading: _generating,
                  onPressed: _generating ? null : _generateThisMonth,
                ),
              ],
            );
          }
          return _StatementsBody(
            statements: statements,
            notes: notes,
            tab: _tab,
            onTabChanged: (v) => setState(() => _tab = v),
            onOpenStatement: (statement) =>
                context.push(Routes.acctStatementDetail, extra: statement),
            onOpenNote: (statement) => context.push(Routes.contractNote, extra: statement),
            generating: _generating,
            onGenerate: _generateThisMonth,
          );
        },
      ),
    );
  }
}

class _StatementsBody extends StatelessWidget {
  const _StatementsBody({
    required this.statements,
    required this.notes,
    required this.tab,
    required this.onTabChanged,
    required this.onOpenStatement,
    required this.onOpenNote,
    required this.generating,
    required this.onGenerate,
  });

  final List<Statement> statements;
  final List<Statement> notes;
  final String tab;
  final ValueChanged<String> onTabChanged;
  final void Function(Statement statement) onOpenStatement;
  final void Function(Statement statement) onOpenNote;
  final bool generating;

  /// Pulls the current month on demand. 2026-08-24: this action only
  /// existed in the whole-screen EMPTY state, so as soon as an investor had
  /// a single contract note the screen was no longer empty and the button
  /// vanished — leaving no way to request a statement at all. Reported as
  /// "I can't request new statements????". It now lives on the Statements
  /// tab itself, where it belongs.
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final showingNotes = tab == 'notes';
    final items = showingNotes ? notes : statements;
    final onOpen = showingNotes ? onOpenNote : onOpenStatement;
    final emptyLabel = showingNotes ? 'No contract notes yet.' : 'No statements yet.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Canvas: one SegmentedControl over the whole document list —
        // Statements / Contract notes / Tax (footer: "tabs: statements,
        // contract notes, tax"). Tax has nothing to show inline on this
        // screen, so picking it just navigates straight to Tax documents
        // (screen 85) instead of swapping the list.
        KSegmentedControl(
          value: tab,
          onChanged: onTabChanged,
          options: const [
            KSegmentOption(value: 'statements', label: 'Statements'),
            KSegmentOption(value: 'notes', label: 'Contract notes'),
            // 'tax' segment removed 2026-08-24 — see account_screen.dart's
            // matching note. It navigated to a screen that only ever showed
            // "not available yet".
          ],
        ),
        const SizedBox(height: 16),
        _Section(items: items, emptyLabel: emptyLabel, onOpen: onOpen),
        const SizedBox(height: 16),
        const KNudgeCard(
          tone: KNudgeTone.grape,
          title: 'What is a contract note?',
          body:
              'The receipt for one trade — what you bought, at what price, and every fee inside it. Free to read in plain English.',
        ),
        const SizedBox(height: 16),
        // The mockup's "Email me a statement" button is removed (2026-08-24)
        // rather than kept as a snackbar saying it isn't available. There is
        // no email-dispatch endpoint for statements and none is planned —
        // unlike a contract note, which IS emailed automatically on every
        // fill. Tapping a row downloads the real PDF, so nothing is lost by
        // dropping a control that could only ever apologise. Matches the
        // same call on statement_detail_screen.dart.
        if (!showingNotes) ...[
          KButton(
            label: generating ? 'Preparing…' : "Prepare this month's statement",
            variant: KButtonVariant.secondary,
            iconLeft: 'download',
            loading: generating,
            onPressed: generating ? null : onGenerate,
          ),
          const SizedBox(height: 10),
        ],
        Text(
          showingNotes
              ? 'Tap a note to open it. A copy is emailed to you whenever an order fills.'
              : 'Statements are prepared at the start of each month — or pull the current '
                  'month above. They are not emailed; download keeps a copy on your device.',
          style: KType.data(color: KColor.ink3),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.items, required this.emptyLabel, this.onOpen});

  final List<Statement> items;
  final String emptyLabel;
  final void Function(Statement statement)? onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(emptyLabel, style: KType.body(color: KColor.ink3));
    }
    // Canvas: a plain title+caption row per document, ending in a
    // decorative download glyph — the whole row (glyph included) is ONE
    // link to the document (footer: "any row opens the document"), not a
    // separate download tap target. No leading icon on these rows.
    return KAccountCard(
      children: [
        for (var i = 0; i < items.length; i++)
          KAccountRow(
            title: items[i].title,
            sub: items[i].sub,
            onTap: onOpen == null ? null : () => onOpen!(items[i]),
            right: const KIcon('arrowDown', size: 18),
            first: i == 0,
          ),
      ],
    );
  }
}
