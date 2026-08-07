// KYC 5 — checking (step 4 of 4). A centred spinner that auto-advances to the
// next-of-kin step after a short delay (mocks the provider review). Mirrors
// Checking. SEAM: the KYC provider's verification result replaces this timer.
//
// WIRING NOTE (kyc-checking pass): confirmed against
// .pipeline/fragments/kyc-checking.json — reads: [KycVerification.status]
// with no gating condition described, actions: [], uiStatesHandled: only
// "checking" (entered unconditionally on build, left unconditionally on the
// timer). There is no incremental-verification endpoint mid-KYC-collection:
// the whole submission (bvn/nin/documentType/nextOfKin/address) goes to the
// backend in ONE `POST /kyc-submissions` call from the next-of-kin screen
// (see kyc_form_state.dart). Gating this screen's advance on KycFormState
// fields was considered and rejected: the fields required by that POST body
// (bvn, nin, documentType) belong to earlier screens (kyc-bvn, kyc-id), not
// to anything collected here, and `nin` in particular has no collecting UI
// anywhere yet (documented gap, see kyc_form_state.dart lines 28-33) — so a
// field-presence gate here would just block on a gap that belongs to a
// different screen's wiring pass, not this one's. Real validation happens
// where the real call happens: on kyc-next-of-kin's submit. This timer stays
// as a client-side UX pacing beat with no backend counterpart to wire.
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
