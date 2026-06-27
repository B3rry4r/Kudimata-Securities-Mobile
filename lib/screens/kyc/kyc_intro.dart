// KYC 1 — intro. What we'll verify (identity / document / selfie) and a single
// purple "Start" primary that enters the linear flow. Mirrors KycIntro.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';

class _KycRow {
  const _KycRow(this.eyebrow, this.line, this.icon);
  final String eyebrow;
  final String line;
  final String icon; // KIcon name
}

class KycIntroScreen extends StatelessWidget {
  const KycIntroScreen({super.key});

  static const _rows = [
    _KycRow('IDENTITY', 'Your name, date of birth and BVN.', 'profile'),
    _KycRow('DOCUMENT', 'A government ID — NIN, passport or licence.', 'card'),
    // Liveness selfie — fingerprint/profile motif (no camera icon in the set).
    _KycRow('SELFIE', 'A quick liveness check to match your face.', 'fingerprint'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              KSpace.gutter, 24, KSpace.gutter, KSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const KScreenHead(title: "Let's verify you"),
              const SizedBox(height: 28),
              KCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < _rows.length; i++)
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: i == 0
                                ? BorderSide.none
                                : BorderSide(color: KColor.hairline, width: 1),
                          ),
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: KColor.bg,
                                shape: BoxShape.circle,
                                border: Border.all(color: KColor.hairline, width: 1),
                              ),
                              child: KIcon(_rows[i].icon, size: 20, color: KColor.ink),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  KEyebrow(_rows[i].eyebrow),
                                  const SizedBox(height: 4),
                                  Text(_rows[i].line, style: KType.body(color: KColor.ink)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Required by our regulator before you can invest.',
                style: KType.body(color: KColor.ink3),
              ),
              const Spacer(),
              KButton(
                label: 'Start',
                iconRight: 'arrowUpRight',
                onPressed: () => context.go(Routes.kycPersonal),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
