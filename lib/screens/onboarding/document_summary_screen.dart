// 06 · Legal document viewer — opened by tapping a document row on the
// onboarding acceptance screen (legal_acceptance_screen.dart) and from the
// pre-signup preview (legal_preview_screen.dart).
//
// 2026-08-24: this screen used to put a plain-English GLOSS on top of the
// binding legal text — KDocumentSummary, the AI/comprehension-layer
// component (purple tint, AIMark "In plain English" badge), with the real
// document collapsed behind a "read the original" reveal. Removed on direct
// product instruction ("remove the glossaries on the legal documents please
// thats wrong"), and it was wrong on three counts:
//
//   1. Legal risk. Paraphrasing an executed agreement and showing the
//      paraphrase FIRST invites the question of which version the investor
//      actually agreed to. The acknowledgement recorded against this screen
//      (POST /compliance-acknowledgements, pinned to a documentVersion) is
//      only defensible if what was shown was the document itself.
//   2. The footer claimed "Summaries are generated and free on every plan."
//      Nothing was generated — every summary was a hardcoded Dart string in
//      legal_acceptance_screen.dart/legal_preview_screen.dart. And "free on
//      every plan" was left over from when the glossary was free, which it
//      no longer is.
//   3. It contradicted the same call already made for the four reference
//      legal screens (legal_reference_screens.dart, "written like the
//      others properly and not a shortcard looking like the ai explain").
//      The four MAIN documents kept the treatment the reference ones had
//      just had taken away.
//
// The document now renders plainly — same KCard + KEyebrow-heading + body
// treatment legal_screen.dart's own viewer uses, so a document reads
// identically wherever it is opened from.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

/// Payload passed via GoRouter `extra` when pushing Routes.documentSummary —
/// mirrors ConfirmPasscodeArgs's pattern (a screen whose content is richer
/// than a single path param).
class DocumentSummaryArgs {
  const DocumentSummaryArgs({required this.docTitle, this.original});

  final String docTitle;

  /// The real document text, headings included — see [DocumentSummaryScreen.
  /// original] for the expected shape.
  final String? original;
}

class DocumentSummaryScreen extends StatelessWidget {
  const DocumentSummaryScreen({
    super.key,
    required this.docTitle,
    this.original,
  });

  final String docTitle;

  /// The real document, as "heading\nbody" blocks separated by blank lines —
  /// exactly what both callers build from `LegalDocument.sections`. Null
  /// only when the fetch that produced it failed.
  final String? original;

  /// Splits [original] back into its (heading, body) blocks so headings can
  /// render as headings rather than as one undifferentiated wall of text.
  /// A block with no newline is treated as bodyless heading-less prose.
  static List<(String?, String)> _blocks(String text) {
    final out = <(String?, String)>[];
    for (final chunk in text.split('\n\n')) {
      final trimmed = chunk.trim();
      if (trimmed.isEmpty) continue;
      final split = trimmed.indexOf('\n');
      if (split == -1) {
        out.add((null, trimmed));
      } else {
        out.add((trimmed.substring(0, split).trim(), trimmed.substring(split + 1).trim()));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final text = original?.trim();
    final blocks = (text == null || text.isEmpty) ? const <(String?, String)>[] : _blocks(text);

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
                  Expanded(child: Text(docTitle, style: KType.section())),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: blocks.isEmpty
                      ? Text(
                          "This document couldn't be loaded. Go back and try again — you "
                          'should never be asked to accept something you cannot read.',
                          style: KType.body(color: KColor.ink2),
                        )
                      : KCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < blocks.length; i++) ...[
                                if (i != 0) const SizedBox(height: 18),
                                if (blocks[i].$1 != null) ...[
                                  KEyebrow(blocks[i].$1!),
                                  const SizedBox(height: 6),
                                ],
                                Text(blocks[i].$2, style: KType.body(color: KColor.ink2)),
                              ],
                            ],
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
