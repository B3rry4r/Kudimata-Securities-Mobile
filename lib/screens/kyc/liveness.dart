// KYC 5 — liveness selfie (step 4 of 5). A framed selfie placeholder: monochrome
// profile silhouette inside a circle with a dashed guidance ring, plus a round
// capture button. Mirrors Liveness, but uses the fingerprint/profile motif (no
// camera — there is no camera icon in the set and we don't open a real camera).
// SEAM: the KYC provider's liveness capture plugs into the capture button.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import '_kyc_chrome.dart';

class LivenessScreen extends StatelessWidget {
  const LivenessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KycTopBar(),
            const KycStepProgress(current: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),
                    // Selfie frame with dashed guidance ring.
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Circle with a profile silhouette.
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: KColor.bg,
                                shape: BoxShape.circle,
                                border: Border.all(color: KColor.hairline, width: 1),
                              ),
                              alignment: Alignment.center,
                              child: KIcon('profile', size: 96, color: KColor.ink3),
                            ),
                          ),
                          // Dashed guidance ring (slightly outset).
                          Positioned(
                            left: -8,
                            top: -8,
                            right: -8,
                            bottom: -8,
                            child: CustomPaint(painter: _DashedRingPainter()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text('Center your face',
                        textAlign: TextAlign.center, style: KType.title()),
                    const SizedBox(height: 10),
                    Text('and hold still',
                        textAlign: TextAlign.center,
                        style: KType.body(color: KColor.ink2)),
                    const Spacer(),
                    // Round capture button.
                    // SEAM: KYC provider liveness capture plugs in here.
                    GestureDetector(
                      onTap: () => context.go(Routes.kycChecking),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: KColor.ink,
                          shape: BoxShape.circle,
                          border: Border.all(color: KColor.paper, width: 4),
                          boxShadow: const [
                            BoxShadow(color: KColor.ink, blurRadius: 0, spreadRadius: 2),
                          ],
                        ),
                        child: const KIcon('fingerprint',
                            size: 30, stroke: 1.9, color: KColor.paper),
                      ),
                    ),
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

/// The dashed guidance ring around the selfie frame (ink at low opacity).
class _DashedRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = KColor.ink.withValues(alpha: 0.35);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    const dash = 7.0;
    const gap = 6.0;
    final circumference = 2 * 3.1415926535 * radius;
    final steps = (circumference / (dash + gap)).floor();
    final sweep = (dash / radius);
    final gapAngle = (gap / radius);
    double a = -1.5708;
    for (var i = 0; i < steps; i++) {
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius), a, sweep, false, paint);
      a += sweep + gapAngle;
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter oldDelegate) => false;
}
