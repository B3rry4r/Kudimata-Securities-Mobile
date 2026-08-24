// Plans & credits (screen 53, 2026-08-22 "Soft Landing"). UI-complete
// preview of the AI-credit subscription system described in the design
// system's readme — no real metering/billing backend exists yet (see
// docs/redesign/PLAN.md), so choosing a plan doesn't charge anything; it
// tells the investor plainly that this is a preview.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  void _previewOnly(BuildContext context, String plan) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$plan isn\'t available yet — this is a preview of what\'s coming.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Plans & credits',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Canvas s53: this line is var(--ink-2), not ink-3 (2026-08-23
          // exactness pass — was ink3, one shade too light).
          Text(
            'Every plan states how many written answers you get. There is no unlimited tier.',
            style: KType.body(color: KColor.ink2),
          ),
          // Mockup: gap:12px uniformly between every child in this column
          // (was 20/16/20 — inconsistent with the source; 2026-08-23 pass).
          const SizedBox(height: 12),
          // Feature bullets: canvas s53 passes these as template variables
          // (`{{ plusFeatures }}` / `{{ proFeatures }}`), resolved in the
          // design source's own data block (kudimata-invest-app.dc.html) —
          // matched verbatim here rather than the previous placeholder
          // copy ("60 explanations a month" etc., which duplicated the
          // `credits` figure already shown elsewhere on the card;
          // 2026-08-23 exactness pass).
          KPlanCard(
            name: 'Plus',
            price: '₦500',
            credits: '60',
            features: const ['Weekly portfolio digest', 'Pidgin and English'],
            action: KButton(
              label: 'Choose Plus',
              onPressed: () => _previewOnly(context, 'Plus'),
            ),
          ),
          const SizedBox(height: 12),
          KPlanCard(
            name: 'Pro',
            price: '₦2,000',
            credits: '250',
            featured: true,
            features: const ['Summaries for every NGX filing', 'Priority support'],
            action: KButton(
              label: 'Choose Pro',
              variant: KButtonVariant.warm,
              onPressed: () => _previewOnly(context, 'Pro'),
            ),
          ),
          const SizedBox(height: 12),
          // 2026-08-24: the "Top up any time: ₦300 for 30 answers" one-off
          // credit purchase was removed per direct product instruction —
          // there's no real metering/billing backend behind any of this
          // preview screen yet (see file header), and a one-off top-up
          // purchase isn't part of what's being previewed right now.
          Text(
            'Prices, fees, risk labels, the glossary and Pidgin re-reads stay free on every plan — what happens when I run out.',
            style: KType.data(color: KColor.ink3),
          ),
        ],
      ),
    );
  }
}
