// 06 · Document, in plain English — canvas screen 06. Part of the AI/
// comprehension layer: a generated plain-English summary sits ABOVE the raw
// legal text, with the original always one tap away. STALE COMMENT FIXED
// 2026-08-24: this IS wired now — reused by legal_preview_screen.dart
// (pre-signup, unauthenticated preview from sign_up_screen.dart's "By
// continuing..." links, real original text via
// LegalDocumentsRepository.getPublicContent) via `Routes.legalPreview`.
// `summary`/`points` are still static per-document copy, not generated —
// no backend endpoint exists that generates a real per-document summary
// (see docs/redesign/BACKEND_GAPS.md's AI-comprehension-layer section);
// `original` is real.
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
  // String _lang = 'en'; // unused while the language switch is hidden — see below

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
                  // English/Pidgin switch temporarily hidden (2026-08-24,
                  // direct product instruction) — no real Pidgin
                  // translation exists anywhere yet.
                  // KLanguageSwitch(value: _lang, onChanged: (v) => setState(() => _lang = v)),
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
