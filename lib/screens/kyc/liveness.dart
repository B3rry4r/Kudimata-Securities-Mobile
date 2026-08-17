// KYC 4 — liveness selfie (step 3 of 4). A framed selfie capture: a live
// front-camera preview inside a circle with a dashed guidance ring (or the
// captured photo once taken), plus a round shutter button.
//
// Real camera capture (package:camera, in-app live preview + in-place
// takePicture()) + the shared presigned-upload flow: POST
// /kyc-documents/upload-url -> PUT the bytes to the returned uploadUrl ->
// KycFormState.registerUploadedDocument(objectKey, 'liveness_selfie'). See
// lib/data/repositories/kyc_document_repository.dart for why the PUT
// bypasses the shared ApiClient, and kyc_form_state.dart for why this screen
// does NOT call POST /kyc-documents itself (no kycSubmissionId exists yet —
// that only comes from the final POST /kyc-submissions call on the
// next-of-kin screen).
//
// 2026-08-14 (BUG-02): previously used image_picker's ImageSource.camera,
// which hands off to the OS's own camera app on a separate screen — no live
// preview inside the circular frame beforehand, and the shutter button was
// styled with the 'fingerprint' glyph (a biometric affordance, not a camera
// one). Rewritten on package:camera for a real CameraPreview rendered in
// place and an in-app shutter that captures without leaving this screen.
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_document_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import '_kyc_chrome.dart';

class LivenessScreen extends StatefulWidget {
  const LivenessScreen({super.key});

  @override
  State<LivenessScreen> createState() => _LivenessScreenState();
}

class _LivenessScreenState extends State<LivenessScreen> with WidgetsBindingObserver {
  late final _repo = KycDocumentRepository(AppScope.read(context).apiClient);

  CameraController? _controller;
  Future<void>? _initializing;
  String? _cameraError;

  String? _capturedPath;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializing = _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  // Cameras are a scarce OS resource — release on backgrounding and
  // re-acquire on resume, the standard package:camera lifecycle pattern
  // (its own README documents this exact observer). Skipped once a photo's
  // already been taken; nothing to keep a live feed running for at that
  // point.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && _capturedPath == null) {
      setState(() => _initializing = _initCamera());
    }
  }

  Future<void> _initCamera() async {
    setState(() => _cameraError = null);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('noCamerasAvailable', 'No camera found on this device');
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      if (!mounted) return;
      // Covers permission-denied (CameraAccessDenied/CameraAccessDeniedWithoutPrompt
      // on Android, denied on iOS) the same as any other init failure — the
      // retry affordance below re-runs this, which re-prompts if the OS
      // hasn't permanently blocked the permission.
      setState(() => _cameraError = e.description ?? "Couldn't access the camera");
    } catch (_) {
      // Anything not surfaced as a CameraException (e.g. no camera plugin
      // registered on this platform/build at all) still needs to land on
      // the same retryable error state rather than leaving the frame
      // showing an inert placeholder forever with no feedback.
      if (!mounted) return;
      setState(() => _cameraError = "Couldn't access the camera");
    }
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
            const KycStepProgress(current: 3),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),
                    // Selfie frame: captured photo, else the live preview,
                    // else a placeholder (still initializing, or the camera
                    // couldn't be reached) — with a dashed guidance ring.
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: KColor.bg,
                                shape: BoxShape.circle,
                                border: Border.all(color: KColor.hairline, width: 1),
                              ),
                              alignment: Alignment.center,
                              child: _buildFrameContent(),
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
                    Text(_error ?? _cameraError ?? 'Center your face',
                        textAlign: TextAlign.center,
                        style: KType.title(color: (_error ?? _cameraError) != null ? KColor.loss : null)),
                    const SizedBox(height: 10),
                    Text(
                        _cameraError != null
                            ? 'Tap below to try again'
                            : _error != null
                                ? 'Tap the button to try again'
                                : (_busy ? 'Uploading...' : 'and hold still'),
                        textAlign: TextAlign.center,
                        style: KType.body(color: KColor.ink2)),
                    const Spacer(),
                    // Round shutter — captures in place (no navigation to a
                    // separate camera screen) when a live preview is ready;
                    // retries camera init if it previously failed.
                    GestureDetector(
                      onTap: _busy ? null : (_cameraError != null ? () => setState(() => _initializing = _initCamera()) : _capture),
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
                            : KIcon(_cameraError != null ? 'refresh' : 'camera',
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

  Widget _buildFrameContent() {
    if (_capturedPath != null) {
      return ClipOval(
        child: Image.file(
          File(_capturedPath!),
          width: 238,
          height: 238,
          fit: BoxFit.cover,
        ),
      );
    }

    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      // previewSize is reported in the sensor's native (often landscape)
      // orientation regardless of the device's current orientation, so
      // width/height are swapped here before FittedBox scales+crops it to
      // fill the circle — the standard package:camera pattern for a
      // portrait-framed preview.
      final previewSize = controller.value.previewSize!;
      return ClipOval(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewSize.height,
            height: previewSize.width,
            child: CameraPreview(controller),
          ),
        ),
      );
    }

    if (_cameraError != null) {
      return KIcon('close', size: 40, color: KColor.loss);
    }

    return FutureBuilder<void>(
      future: _initializing,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return KSpinner(size: 32, color: KColor.ink3);
        }
        return KIcon('profile', size: 96, color: KColor.ink3);
      },
    );
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || controller.value.isTakingPicture) {
      return;
    }

    setState(() {
      _error = null;
    });

    final XFile shot;
    try {
      shot = await controller.takePicture();
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.description ?? "Couldn't capture — try again");
      return;
    }

    setState(() {
      _busy = true;
      _capturedPath = shot.path;
    });
    // The live feed's only purpose was framing the shot — release it now
    // rather than holding the camera open through the upload.
    await controller.dispose();
    _controller = null;

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
