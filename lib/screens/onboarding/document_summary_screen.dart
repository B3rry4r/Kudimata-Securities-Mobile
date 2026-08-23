// 06 · Document, in plain English — NEW SCREEN (2026-08-22 "Soft Landing"
// redesign, docs/redesign/screen-specs.md screen 06). Part of the AI/
// comprehension layer: a generated plain-English summary sits ABOVE the raw
// legal text, with the original always one tap away. NOT YET WIRED into
// lib/router/routes.dart / app_router.dart, and the summary content below is
// STATIC placeholder copy — there is no backend endpoint yet that generates
// a real per-document summary (see docs/redesign/PLAN.md). Built ready for
// both once that lands; the real original document text should come from
// LegalDocumentsRepository.getContent(kind), same as legal_acceptance_screen.dart.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

/// Payload passed via GoRouter `extra` when pushing Routes.documentSummary —
/// mirrors ConfirmPasscodeArgs's pattern (a screen whose content is richer
/// than a single path param).
class DocumentSummaryArgs {
  const DocumentSummaryArgs({
    required this.docTitle,
    required this.summary,
    this.points = const [],
    this.original,
  });

  final String docTitle;
  final String summary;
  final List<String> points;
  final String? original;
}

class DocumentSummaryScreen extends StatefulWidget {
  const DocumentSummaryScreen({
    super.key,
    required this.docTitle,
    required this.summary,
    this.points = const [],
    this.original,
  });

  final String docTitle;
  final String summary;
  final List<String> points;
  final String? original;

  @override
  State<DocumentSummaryScreen> createState() => _DocumentSummaryScreenState();
}

class _DocumentSummaryScreenState extends State<DocumentSummaryScreen> {
  String _lang = 'en';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  KIconButton(icon: 'back', onPressed: () => context.pop()),
                  const SizedBox(width: 12),
                  Expanded(child: Text(widget.docTitle, style: KType.section())),
                  KLanguageSwitch(value: _lang, onChanged: (v) => setState(() => _lang = v)),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: KDocumentSummary(
                    kind: 'Legal document',
                    title: 'What this document says',
                    summary: widget.summary,
                    points: widget.points,
                    original: widget.original,
                    footer: Text(
                      'The English original is the authoritative version. Summaries are generated and free on every plan.',
                      style: KType.data(color: KColor.ink3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              KButton(
                label: 'Back to the agreement',
                variant: KButtonVariant.secondary,
                fullWidth: true,
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
