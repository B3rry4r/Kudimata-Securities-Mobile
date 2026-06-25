// KYC 3 — BVN verification (step 2 of 5). Single numeric field with the privacy
// helper. Mirrors Bvn. SEAM: the KYC provider verifies the BVN here.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import '_kyc_chrome.dart';

class BvnScreen extends StatefulWidget {
  const BvnScreen({super.key});

  @override
  State<BvnScreen> createState() => _BvnScreenState();
}

class _BvnScreenState extends State<BvnScreen> {
  final _bvn = TextEditingController();

  @override
  void dispose() {
    _bvn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KycTopBar(),
            const KycStepProgress(current: 2),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(title: 'Verify your BVN'),
                    const SizedBox(height: 24),
                    KInput(
                      label: 'BVN',
                      numeric: true,
                      placeholder: '0000000000',
                      helper:
                          'We use this only to verify your identity — we never see your bank.',
                      controller: _bvn,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
              // SEAM: KYC provider verifies the BVN before continuing.
              child: KButton(
                label: 'Verify',
                onPressed: () => context.go(Routes.kycId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
