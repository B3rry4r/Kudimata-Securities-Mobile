// KYC 6 — checking (step 5 of 5). A centred spinner that auto-advances to the
// next-of-kin step after a short delay (mocks the provider review). Mirrors
// Checking. SEAM: the KYC provider's verification result replaces this timer.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import '_kyc_chrome.dart';

class CheckingScreen extends StatefulWidget {
  const CheckingScreen({super.key});

  @override
  State<CheckingScreen> createState() => _CheckingScreenState();
}

class _CheckingScreenState extends State<CheckingScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // SEAM: replace this delay with the real KYC provider verification result.
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) context.go(Routes.kycNextOfKin);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
            const KycStepProgress(current: 5),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    KSpinner(size: 40, stroke: 2, color: KColor.ink),
                    const SizedBox(height: 22),
                    Text('Checking your details…',
                        textAlign: TextAlign.center,
                        style: KType.section()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
