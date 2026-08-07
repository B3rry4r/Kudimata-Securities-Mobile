// KYC 5 — liveness selfie (step 4 of 5). A framed selfie capture: monochrome
// profile silhouette inside a circle with a dashed guidance ring (or the
// captured photo once taken), plus a round capture button that opens the
// device camera. Mirrors Liveness, but uses the fingerprint/profile motif
// for the button glyph.
//
// Real camera capture (image_picker, ImageSource.camera) + the shared
// presigned-upload flow: POST /kyc-documents/upload-url -> PUT the bytes to
// the returned uploadUrl -> KycFormState.registerUploadedDocument(objectKey,
// 'liveness_selfie'). See lib/data/repositories/kyc_document_repository.dart
// for why the PUT bypasses the shared ApiClient, and kyc_form_state.dart for
// why this screen does NOT call POST /kyc-documents itself (no
// kycSubmissionId exists yet — that only comes from the final
// POST /kyc-submissions call on the next-of-kin screen).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/api/api_exception.dart';
import 'package:kudimata_securities/data/repositories/kyc_document_repository.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import '_kyc_chrome.dart';

class LivenessScreen extends StatefulWidget {
  const LivenessScreen({super.key});

  @override
  State<LivenessScreen> createState() => _LivenessScreenState();
}

class _LivenessScreenState extends State<LivenessScreen> {
  late final _repo = KycDocumentRepository(AppScope.read(context).apiClient);
  final _picker = ImagePicker();

  String? _capturedPath;
  bool _busy = false;
  String? _error;

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
                          // Circle with either the captured photo or the
                          // placeholder profile silhouette.
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: KColor.bg,
                                shape: BoxShape.circle,
                                border: Border.all(color: KColor.hairline, width: 1),
                              ),
                              alignment: Alignment.center,
                              child: _capturedPath == null
                                  ? KIcon('profile', size: 96, color: KColor.ink3)
                                  : ClipOval(
                                      child: Image.file(
                                        File(_capturedPath!),
                                        width: 238,
                                        height: 238,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
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
                    Text(_error ?? 'Center your face',
                        textAlign: TextAlign.center,
                        style: KType.title(color: _error != null ? KColor.loss : null)),
                    const SizedBox(height: 10),
                    Text(
                        _error != null
                            ? 'Tap the button to try again'
                            : (_busy ? 'Uploading...' : 'and hold still'),
                        textAlign: TextAlign.center,
                        style: KType.body(color: KColor.ink2)),
                    const Spacer(),
                    // Round capture button — opens the device camera, then
                    // runs the presigned-upload flow.
                    GestureDetector(
                      onTap: _busy ? null : _capture,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: KColor.feature,
                          shape: BoxShape.circle,
                          border: Border.all(color: KColor.featureInk, width: 4),
                          boxShadow: [
                            BoxShadow(color: KColor.feature, blurRadius: 0, spreadRadius: 2),
                          ],
                        ),
                        child: _busy
                            ? KSpinner(size: 26, color: KColor.featureInk)
                            : KIcon('fingerprint',
                                size: 30, stroke: 1.9, color: KColor.featureInk),
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

  Future<void> _capture() async {
    setState(() {
      _error = null;
    });

    final XFile? shot;
    try {
      shot = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Couldn't open the camera");
      return;
    }
    if (shot == null) return; // user cancelled — stay on the frame as-is.

    setState(() {
      _busy = true;
      _capturedPath = shot!.path;
    });

    try {
      final bytes = await shot.readAsBytes();
      final upload = await _repo.requestUploadUrl(
        documentKind: 'liveness_selfie',
        documentName: shot.name.isNotEmpty ? shot.name : 'liveness-selfie.jpg',
      );
      await _repo.putFile(upload.uploadUrl, bytes, contentType: 'image/jpeg');

      if (!mounted) return;
      AppScope.read(context).kycForm.registerUploadedDocument(upload.objectKey, 'liveness_selfie');

      if (!mounted) return;
      context.go(Routes.kycChecking);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
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
