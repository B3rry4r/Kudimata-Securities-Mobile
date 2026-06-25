// KYC 4 — ID upload (step 3 of 5). ID-type chips + a file dropzone. Mirrors
// IdUpload. SEAM: the real file picker / KYC document store plugs into onPick.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import '_kyc_chrome.dart';

class _IdType {
  const _IdType(this.id, this.label);
  final String id;
  final String label;
}

class IdUploadScreen extends StatefulWidget {
  const IdUploadScreen({super.key});

  @override
  State<IdUploadScreen> createState() => _IdUploadScreenState();
}

class _IdUploadScreenState extends State<IdUploadScreen> {
  static const _types = [
    _IdType('nin', 'NIN'),
    _IdType('passport', 'Passport'),
    _IdType('licence', "Driver's licence"),
  ];

  String _type = 'nin';
  KFileInfo? _file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KycTopBar(),
            const KycStepProgress(current: 3),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(title: 'Upload your ID'),
                    const SizedBox(height: 20),
                    const KEyebrow('ID type'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in _types)
                          KPillChip(
                            label: t.label,
                            selected: _type == t.id,
                            onTap: () => setState(() => _type = t.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    KFileUpload(
                      label: 'Upload your ID',
                      hint: 'JPG or PDF, up to 10MB',
                      prompt: 'Tap to upload, or take a photo',
                      file: _file,
                      // SEAM: real file picker / KYC document store plugs in here.
                      onPick: () => setState(
                          () => _file = const KFileInfo(name: 'id-document.jpg', size: 2_400_000)),
                      onRemove: () => setState(() => _file = null),
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
                onPressed: () => context.go(Routes.kycLiveness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
