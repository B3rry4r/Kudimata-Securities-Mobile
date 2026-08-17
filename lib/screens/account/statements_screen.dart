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
// dependency that would justify two independent FutureBuilders. Tapping a
// row's download button fetches a presigned URL (GET
// /statements/:id/download-url) and launches it externally — there is no
// in-app document viewer to build one for (same seam legal_screen.dart uses).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/repositories/statements_repository.dart';
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
    try {
      final url = await _repo.downloadUrl(statement.id);
      if (url.isEmpty) return;
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No in-app surface to report this on (an icon-only download button)
      // — matches this screen's original no-op-on-failure seam; the
      // download is a best-effort external hand-off.
    }
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Statements & documents',
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
            );
          }
          return _StatementsBody(
            statements: statements,
            notes: notes,
            onDownload: _download,
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
  });

  final List<Statement> statements;
  final List<Statement> notes;
  final void Function(Statement statement) onDownload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KEyebrow('Monthly statements'),
        const SizedBox(height: 10),
        _Section(items: statements, emptyLabel: 'No statements yet.', onDownload: onDownload),
        const SizedBox(height: 24),
        const KEyebrow('Contract notes'),
        const SizedBox(height: 10),
        _Section(items: notes, emptyLabel: 'No contract notes yet.', onDownload: onDownload),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.items, required this.emptyLabel, required this.onDownload});

  final List<Statement> items;
  final String emptyLabel;
  final void Function(Statement statement) onDownload;

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
