// KYC 9 — approved (success). A centred success StatusView. Sets kycApproved and
// the primary "Start investing" hands off to the suitability questionnaire.
// Mirrors Approved.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';

class ApprovedScreen extends StatefulWidget {
  const ApprovedScreen({super.key});

  @override
  State<ApprovedScreen> createState() => _ApprovedScreenState();
}

class _ApprovedScreenState extends State<ApprovedScreen> {
  @override
  void initState() {
    super.initState();
    // Verified — flip the gate flag once we land here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).setKycApproved(true);
    });
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
              tone: KStatusTone.success,
              title: "You're verified",
              message: 'Your money is ready to invest.',
              primary: 'Start investing',
              onPrimary: () => context.go(Routes.questionnaire),
            ),
          ),
        ),
      ),
    );
  }
}
