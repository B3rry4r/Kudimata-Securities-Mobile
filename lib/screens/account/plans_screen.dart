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
          Text(
            'Every plan states how many written answers you get. There is no unlimited tier.',
            style: KType.body(color: KColor.ink3),
          ),
          const SizedBox(height: 20),
          KPlanCard(
            name: 'Plus',
            price: '₦500',
            credits: '60',
            features: const ['60 explanations a month', 'Prices, fees and the glossary stay free'],
            action: KButton(
              label: 'Choose Plus',
              onPressed: () => _previewOnly(context, 'Plus'),
            ),
          ),
          const SizedBox(height: 16),
          KPlanCard(
            name: 'Pro',
            price: '₦2,000',
            credits: '250',
            featured: true,
            features: const ['250 explanations a month', 'Priority document summaries'],
            action: KButton(
              label: 'Choose Pro',
              variant: KButtonVariant.warm,
              onPressed: () => _previewOnly(context, 'Pro'),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Top up any time: ₦300 for 30 answers. Prices, fees, risk labels, the glossary and Pidgin re-reads stay free on every plan — what happens when I run out.',
            style: KType.data(color: KColor.ink3),
          ),
        ],
      ),
    );
  }
}
