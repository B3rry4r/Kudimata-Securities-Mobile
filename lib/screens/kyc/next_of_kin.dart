// KYC 7 — next of kin (post-check; no step strip). Name / relationship / phone.
// Mirrors NextOfKin. Continue submits the application: sets kycSubmitted and
// advances to the Submitted (pending review) screen.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import '_kyc_chrome.dart';

class NextOfKinScreen extends StatefulWidget {
  const NextOfKinScreen({super.key});

  @override
  State<NextOfKinScreen> createState() => _NextOfKinScreenState();
}

class _NextOfKinScreenState extends State<NextOfKinScreen> {
  final _name = TextEditingController();
  final _rel = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _rel.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    // SEAM: real KYC submission to the provider happens here.
    AppScope.read(context).setKycSubmitted(true);
    context.go(Routes.kycSubmitted);
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 8, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(title: 'Next of kin'),
                    const SizedBox(height: 20),
                    KCard(
                      child: Column(
                        children: [
                          KInput(
                              label: 'Full name',
                              placeholder: 'Amara Okafor',
                              controller: _name),
                          const SizedBox(height: 16),
                          KInput(
                              label: 'Relationship',
                              placeholder: 'Sister',
                              controller: _rel),
                          const SizedBox(height: 16),
                          KInput(
                              label: 'Phone number',
                              prefix: '+234',
                              placeholder: '801 234 5678',
                              keyboardType: TextInputType.phone,
                              controller: _phone),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
              child: KButton(label: 'Continue', onPressed: _submit),
            ),
          ],
        ),
      ),
    );
  }
}
