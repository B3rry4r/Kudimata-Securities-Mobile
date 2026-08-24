// Shared "explain this term" sheet — backs every KGlossaryTerm's onTap
// (lib/widgets/comprehension.dart) across the app (faq_screen.dart,
// trade_flows.dart). 2026-08-24: every call site used to pass onTap: () {}
// — a literal no-op, reported live as "dead buttons". Real Gemini call via
// POST /ai/explain-term (Kudimata-Securities-Backend's
// AiComprehensionService.explainTerm), not credit-metered — the glossary
// is advertised as free on every plan (plans_screen.dart).
import 'package:flutter/material.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/ai_repository.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

void showGlossaryExplainSheet(BuildContext context, String term) {
  showKSheet<void>(
    context,
    title: term,
    child: _GlossaryExplainBody(term: term),
  );
}

class _GlossaryExplainBody extends StatefulWidget {
  const _GlossaryExplainBody({required this.term});
  final String term;

  @override
  State<_GlossaryExplainBody> createState() => _GlossaryExplainBodyState();
}

class _GlossaryExplainBodyState extends State<_GlossaryExplainBody> {
  late Future<String> _future = AiRepository(
    AppScope.read(context).apiClient,
  ).explainTerm(widget.term);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: FutureBuilder<String>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 80,
              child: Center(child: KSpinner(size: 24)),
            );
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : "Couldn't load this explanation right now.";
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, style: KType.body(color: KColor.loss)),
                const SizedBox(height: 10),
                KButton(
                  label: 'Try again',
                  variant: KButtonVariant.secondary,
                  onPressed: () => setState(
                    () => _future = AiRepository(
                      AppScope.read(context).apiClient,
                    ).explainTerm(widget.term),
                  ),
                ),
              ],
            );
          }
          return Text(snapshot.data!, style: KType.body(color: KColor.ink2));
        },
      ),
    );
  }
}
