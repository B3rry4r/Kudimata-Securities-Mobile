// Stage 9 — Statements & documents (pushed). Monthly statements + contract
// notes, each a file row with a download control. Mirrors `Statements` in
// settings-screens.jsx.
//
// Wired per lib/data/api/README.md's FutureBuilder convention: the two
// sections are independent Statement.kind slices of the same resource
// (GET /statements?kind=monthly and GET /statements?kind=contract_note),
// fetched together with Future.wait behind ONE `_future` field/FutureBuilder
// — a single loading/error state for the whole pushed screen, same as every
// other single-`_future` screen in this app; there's no cross-section
// dependency that would justify two independent FutureBuilders.
//
// DOWNLOAD (2026-08-20 — "what are the statements and documents section
// for??"): each row's download button used to fetch a presigned URL (GET
// /statements/:id/download-url) and launch it externally. The backend's
// own statements.service.ts header comment documents that no real PDF is
// ever generated in this phase — every row's fileObjectKey points at an
// S3 object that was never uploaded, so that URL always 404s (S3
// NoSuchKey) the moment it's opened, the same gap Account -> Legal hit
// before it stopped using S3 links entirely. Statements are real binary
// PDFs, not text content this app already has server-side (unlike a legal
// document's sections), so there's no in-app-viewer workaround available
// here — the button now tells the investor honestly that downloads
// aren't ready yet, instead of silently launching a link that just shows
// a raw S3 error in their browser.
// PER-BROKER STATEMENT DETAIL (2026-08-23, design-canvas growth pass, screen
// 76): monthly-statement rows push StatementDetailScreen via the named
// Routes.acctStatementDetail route (wired centrally once all screen-cluster
// agents finished their file-disjoint passes), the same way a contract-note
// row already pushes ContractNoteScreen via Routes.contractNote.
//
// TAX DOCUMENTS ENTRY POINT (same pass, screen 85): the design canvas's
// screen 52 footer describes reaching Tax documents from a "tax" tab on
// this screen (alongside statements/contract notes) or from the Dividends
// screen (84, owned by another agent's cluster this pass). Rebuilding this
// screen's two stacked sections into a three-way tab/segmented-control
// layout is a bigger structural change than this pass's two-screen scope
// (76, 85) covers, so instead this adds one more small section — same
// eyebrow + card-row shape as the sections above — as an honest, working
// entry point today; it can be folded into a real tab control later without
// changing TaxDocumentsScreen itself.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
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

  Future<(List<Statement>, List<Statement>)> _load() async {
    final results = await Future.wait([
      _repo.list(StatementKind.monthly),
      _repo.list(StatementKind.contractNote),
    ]);
    return (results[0], results[1]);
  }

  Future<void> _download(Statement statement) async {
    // Backend note (statements.service.ts's own header comment): no real
    // PDF is ever rendered in this phase — every statement/contract-note
    // row's fileObjectKey points at an S3 object that was never actually
    // uploaded, so the presigned URL this fetches 404s (S3 NoSuchKey) the
    // moment it's opened, same underlying gap the Account -> Legal screen
    // hit before it stopped using S3 links entirely. Statements are real
    // binary PDFs (not text content this app already has, like a legal
    // document's sections), so there's no equivalent in-app-viewer
    // workaround available here — this now tells the investor honestly
    // that it isn't ready, instead of silently launching a link that was
    // just going to show a raw S3 XML error in their browser.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloads are not available yet — check back soon.')),
    );
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
            return const KEmptyView(
              icon: 'card',
              title: 'No documents yet',
              message: 'Your statements and contract notes will show here.',
              illustrationName: 'empty-statements',
            );
          }
          return _StatementsBody(
            statements: statements,
            notes: notes,
            onDownload: _download,
            onOpenStatement: (statement) =>
                context.push(Routes.acctStatementDetail, extra: statement),
            onOpenNote: (statement) => context.push(Routes.contractNote, extra: statement),
            onOpenTax: () => context.push(Routes.acctTax),
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
    required this.onDownload,
    required this.onOpenStatement,
    required this.onOpenNote,
    required this.onOpenTax,
  });

  final List<Statement> statements;
  final List<Statement> notes;
  final void Function(Statement statement) onDownload;
  final void Function(Statement statement) onOpenStatement;
  final void Function(Statement statement) onOpenNote;
  final VoidCallback onOpenTax;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KEyebrow('Monthly statements'),
        const SizedBox(height: 10),
        // Rows here open the per-broker statement detail (screen 76) on tap
        // — mirrors the contract-notes row -> screen 66 wiring just below.
        _Section(
          items: statements,
          emptyLabel: 'No statements yet.',
          onDownload: onDownload,
          onOpen: onOpenStatement,
        ),
        const SizedBox(height: 24),
        const KEyebrow('Contract notes'),
        const SizedBox(height: 10),
        // Rows here open the contract-note document view (screen 66) on tap
        // — screen-specs.md spec 52's nav note ("rows -> 66") — the download
        // icon-button stays a separate, smaller tap target for the direct
        // download action.
        _Section(
          items: notes,
          emptyLabel: 'No contract notes yet.',
          onDownload: onDownload,
          onOpen: onOpenNote,
        ),
        const SizedBox(height: 24),
        const KEyebrow('Tax'),
        const SizedBox(height: 10),
        KAccountCard(
          children: [
            KAccountRow(
              icon: 'card',
              title: 'Tax documents',
              sub: 'Dividends & withholding tax',
              right: const KRowChevron(),
              first: true,
              onTap: onOpenTax,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const KNudgeCard(
          tone: KNudgeTone.grape,
          title: 'What is a contract note?',
          body:
              'The receipt for one trade — what you bought, at what price, and every fee inside it. Free to read in plain English.',
        ),
        const SizedBox(height: 16),
        // Mockup's "Email me a statement" action — same honest-gap pattern
        // as the per-row download button above: no email-dispatch endpoint
        // exists yet, so this tells the investor rather than silently
        // failing (2026-08-23 exactness pass).
        KButton(
          label: 'Email me a statement',
          variant: KButtonVariant.secondary,
          iconLeft: 'mail',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Emailing statements isn\'t available yet — check back soon.')),
            );
          },
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.items,
    required this.emptyLabel,
    required this.onDownload,
    this.onOpen,
  });

  final List<Statement> items;
  final String emptyLabel;
  final void Function(Statement statement) onDownload;
  final void Function(Statement statement)? onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(emptyLabel, style: KType.body(color: KColor.ink3));
    }
    return KAccountCard(
      children: [
        for (var i = 0; i < items.length; i++)
          KAccountRow(
            icon: 'card',
            title: items[i].title,
            sub: items[i].sub,
            onTap: onOpen == null ? null : () => onOpen!(items[i]),
            right: KIconButton(
              icon: 'arrowDown',
              semanticLabel: 'Download',
              onPressed: () => onDownload(items[i]),
            ),
            first: i == 0,
          ),
      ],
    );
  }
}
