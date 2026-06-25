// KYC 8 — submitted (pending review). A centred pending StatusView. Auto-advances
// to Approved after a short delay (mocks the provider approving). Mirrors
// Submitted. SEAM: the real KYC provider's approval callback replaces the timer.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';

class SubmittedScreen extends StatefulWidget {
  const SubmittedScreen({super.key});

  @override
  State<SubmittedScreen> createState() => _SubmittedScreenState();
}

class _SubmittedScreenState extends State<SubmittedScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // SEAM: replace with the KYC provider's approval callback.
    _timer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) context.go(Routes.kycApproved);
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
          child: Center(
            child: KStatusView(
              tone: KStatusTone.pending,
              title: "We're reviewing your details",
              message:
                  "This usually takes a few minutes. We'll notify you when you're verified.",
              secondary: 'Continue',
              onSecondary: () => context.go(Routes.kycApproved),
            ),
          ),
        ),
      ),
    );
  }
}
