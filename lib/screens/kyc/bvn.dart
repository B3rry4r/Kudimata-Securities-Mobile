// KYC 3 — BVN verification (step 2 of 5). Single numeric field with the privacy
// helper. Mirrors Bvn. SEAM: the KYC provider verifies the BVN here.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import '_kyc_chrome.dart';

// A Nigerian BVN is exactly 11 numeric digits (LumiID `POST /ng/bvn-basic/`
// takes it as `id_number`; see Kudimata-Securities-Backend
// .pipeline/conventions.md's BVN/NIN row and declared/kyc.json).
final RegExp _bvnPattern = RegExp(r'^\d{11}$');

class BvnScreen extends StatefulWidget {
  const BvnScreen({super.key});

  @override
  State<BvnScreen> createState() => _BvnScreenState();
}

class _BvnScreenState extends State<BvnScreen> {
  final _bvn = TextEditingController();

  bool _showErrors = false;

  @override
  void dispose() {
    _bvn.dispose();
    super.dispose();
  }

  // Basic non-empty + 11-digit-numeric validation (matches the flow's
  // no-live-validation pattern — errors only surface after Continue/Verify
  // is pressed). This screen does not call the backend itself: the real
  // KYC provider verification happens server-side as part of the final
  // POST /kyc-submissions call on kyc-next-of-kin.
  void _continue() {
    final valid = _bvnPattern.hasMatch(_bvn.text.trim());
    if (!valid) {
      setState(() => _showErrors = true);
      return;
    }
    AppScope.read(context).kycForm.setBvn(_bvn.text.trim());
    context.go(Routes.kycId);
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
                      error: _showErrors && !_bvnPattern.hasMatch(_bvn.text.trim())
                          ? 'Enter a valid 11-digit BVN'
                          : null,
                      controller: _bvn,
                      onChanged: (_) {
                        if (_showErrors) setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
              // SEAM: KYC provider verifies the BVN server-side, as part of
              // the final POST /kyc-submissions call on kyc-next-of-kin.
              child: KButton(
                label: 'Verify',
                onPressed: _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
