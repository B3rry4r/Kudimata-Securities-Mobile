// Suitability — risk-profile result. The one ink panel states the investor
// profile; a paragraph explains it; primary Continue advances. No purple donut.
// Ported from risk-screens.jsx (SuitabilityResult).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_securities/widgets/widgets.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/router/routes.dart';

class SuitabilityResultScreen extends StatelessWidget {
  const SuitabilityResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SEAM: the suitability scorer maps questionnaire answers → profile.
              KBalancePanel(
                label: 'Your investor profile',
                balance: 'Balanced',
                chart: Text(
                  "We may flag products that don't match this profile.",
                  style: KType.body(color: KColor.featureInk2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "A balanced profile means you're comfortable with some ups and "
                'downs in exchange for steady long-term growth. You can change '
                'your answers at any time, and your profile will update.',
                style: KType.body(color: KColor.ink2),
              ),
              const Spacer(),
              KButton(
                label: 'Continue',
                onPressed: () => context.go(Routes.riskDisclosure),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
