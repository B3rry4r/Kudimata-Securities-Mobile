// KYC 2 — personal details (step 1 of 5). Name / DOB / address / city. Mirrors
// PersonalDetails. Continue advances the linear flow to BVN.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import '_kyc_chrome.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _name = TextEditingController();
  final _dob = TextEditingController();
  final _addr = TextEditingController();
  final _city = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _dob.dispose();
    _addr.dispose();
    _city.dispose();
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
            const KycStepProgress(current: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(title: 'Your details'),
                    const SizedBox(height: 20),
                    KCard(
                      child: Column(
                        children: [
                          KInput(
                              label: 'Full name',
                              placeholder: 'Chidi Okafor',
                              controller: _name),
                          const SizedBox(height: 16),
                          KInput(
                              label: 'Date of birth',
                              placeholder: 'DD / MM / YYYY',
                              controller: _dob),
                          const SizedBox(height: 16),
                          KInput(
                              label: 'Residential address',
                              placeholder: '12 Bourdillon Road',
                              controller: _addr),
                          const SizedBox(height: 16),
                          KInput(
                              label: 'City',
                              placeholder: 'Lagos',
                              controller: _city),
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
              child: KButton(
                label: 'Continue',
                onPressed: () => context.go(Routes.kycBvn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
