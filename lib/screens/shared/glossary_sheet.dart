// Shared "explain this term" sheet — backs every KGlossaryTerm's onTap
// (lib/widgets/comprehension.dart) across the app (faq_screen.dart,
// trade_flows.dart) and KProductCard's onTapStat (asset_detail_screen.dart).
// 2026-08-24: two-tier design, direct product instruction ("glossary they
// should be self explained... all bigterms explain them properly there so
// when they cick they see it but they can now still also have the option
// to explain with ai better again after they read it"). Tier 1 is the
// static, pre-written definition from lib/data/glossary.dart — instant,
// free, no network call. Tier 2 is "Explain further", a real Gemini call
// via POST /ai/explain-term (AiComprehensionService.explainTermFurther)
// grounded in the tier-1 text, and — per the same correction — it DOES
// cost a credit even though the static read doesn't: "glossary is not
// free please... they take a cost so it should still count on the
// credits".
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/glossary.dart';
import 'package:kudimata_invest/data/repositories/ai_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

/// Opens the glossary sheet for [term].
///
/// [allowAiFollowUp] false hides the credit-metered "Explain further"
/// button entirely, making this a purely static, free, offline lookup.
/// Used where an AI call would be inappropriate rather than merely
/// unnecessary — currently the suitability questionnaire (2026-08-24:
/// "do that as a hand written glossary not an ai call"). Charging an
/// investor a credit, or making a network call, to understand a MANDATORY
/// regulatory question they cannot skip would be the wrong trade.
void showGlossaryExplainSheet(
  BuildContext context,
  String term, {
  bool allowAiFollowUp = true,
}) {
  showKSheet<void>(
    context,
    title: term,
    child: _GlossaryExplainBody(term: term, allowAiFollowUp: allowAiFollowUp),
  );
}

enum _AiState { idle, loading, error }

class _GlossaryExplainBody extends StatefulWidget {
  const _GlossaryExplainBody({required this.term, this.allowAiFollowUp = true});
  final String term;
  final bool allowAiFollowUp;

  @override
  State<_GlossaryExplainBody> createState() => _GlossaryExplainBodyState();
}

class _GlossaryExplainBodyState extends State<_GlossaryExplainBody> {
  late final String? _staticDefinition = glossaryDefinition(widget.term);
  _AiState _aiState = _AiState.idle;
  String? _aiText;
  String? _errorMessage;

  Future<void> _explainFurther() async {
    setState(() {
      _aiState = _AiState.loading;
      _errorMessage = null;
    });
    try {
      final repo = AiRepository(AppScope.read(context).apiClient);
      final result = await repo.explainTermFurther(widget.term, readContext: _staticDefinition);
      if (!mounted) return;
      setState(() {
        _aiText = result.text;
        _aiState = _AiState.idle;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'INSUFFICIENT_CREDITS') {
        Navigator.of(context).pop();
        context.push(Routes.acctPlans);
        return;
      }
      setState(() {
        _errorMessage = e.message;
        _aiState = _AiState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Couldn't load that explanation right now.";
        _aiState = _AiState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final staticDefinition = _staticDefinition;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            staticDefinition ?? "We don't have a written definition for this yet.",
            style: KType.body(color: KColor.ink2),
          ),
          const SizedBox(height: 16),
          if (_aiText != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: KColor.indicatorTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_aiText!, style: KType.body(color: KColor.ink)),
            ),
            const SizedBox(height: 12),
          ] else if (_aiState == _AiState.loading) ...[
            const SizedBox(
              height: 48,
              child: Center(child: KSpinner(size: 24)),
            ),
          ] else if (widget.allowAiFollowUp) ...[
            if (_aiState == _AiState.error && _errorMessage != null) ...[
              Text(_errorMessage!, style: KType.body(color: KColor.loss)),
              const SizedBox(height: 10),
            ],
            KButton(
              label: "Still don't understand? Explain further",
              variant: KButtonVariant.secondary,
              onPressed: _explainFurther,
            ),
          ],
        ],
      ),
    );
  }
}
