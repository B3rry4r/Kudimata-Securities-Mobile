// KYC 4 — liveness selfie (step 3 of 5). On mobile: a framed selfie capture
// — a live front-camera preview inside a circle with a dashed guidance
// ring (or the captured photo once taken), plus a round shutter button. On
// web: a file picker instead (2026-08-19) — package:camera's web support is
// unreliable across browsers for this kind of in-place capture UI, and
// testing against real production keys needs a dependable path to actually
// get a selfie uploaded, not a flaky live preview. Both paths converge on
// the exact same upload flow (_uploadAndContinue).
//
// Real camera capture (package:camera, in-app live preview + in-place
// takePicture()) + the shared presigned-upload flow: POST
// /kyc-documents/upload-url -> PUT the bytes to the returned uploadUrl ->
// POST /kyc-documents (registers against the draft created on step 1 —
// see lib/screens/kyc/kyc_form_state.dart). The ACTUAL liveness
// verification doesn't happen here — this screen only gets the selfie
// uploaded+registered; kyc-checking (next screen, repurposed 2026-08-20)
// is what calls POST /kyc-submissions/draft/liveness to trigger it.
//
// 2026-08-14 (BUG-02): previously used image_picker's ImageSource.camera,
// which hands off to the OS's own camera app on a separate screen — no live
// preview inside the circular frame beforehand, and the shutter button was
// styled with the 'fingerprint' glyph (a biometric affordance, not a camera
// one). Rewritten on package:camera for a real CameraPreview rendered in
// place and an in-app shutter that captures without leaving this screen.
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  String? _capturedPath; // mobile: package:camera's captured file path.
  Uint8List? _pickedBytes; // web: file_picker's picked bytes (no real path).
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return; // web never touches the camera — see file header.
    WidgetsBinding.instance.addObserver(this);
    _initializing = _initCamera();
  }

  @override
  void dispose() {
    if (!kIsWeb) WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  // Cameras are a scarce OS resource — release on backgrounding and
  // re-acquire on resume, the standard package:camera lifecycle pattern
  // (its own README documents this exact observer). Skipped once a photo's
  // already been taken; nothing to keep a live feed running for at that
  // point. Mobile-only — see initState.
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
            KycTopBar(onBack: () => context.go(Routes.kycId)),
            const KycStepProgress(total: 5, current: 3),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Scrollable-but-still-centered on tall screens: the
                  // `Spacer()`s below only work if this Column is allowed to
                  // be exactly as tall as the available space when content
                  // is short, and to scroll (not overflow) when content is
                  // taller than that — e.g. once the "we check the photo…"
                  // footnote line is showing. Found live via
                  // test/route_walk_test.dart: a fixed-height Column here
                  // overflowed by 20px on a real device-sized viewport the
                  // moment that footnote was added. Same pattern as
                  // KOnboardBody (onboarding_scaffold.dart).
                  final maxH = constraints.maxHeight;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                        KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: maxH.isFinite ? maxH - KSpace.gutter : 0,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Spacer(),
                    // Selfie frame: captured/picked photo, else the live
                    // preview (mobile only), else a placeholder — with a
                    // dashed guidance ring.
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: KColor.indicatorTint,
                                shape: BoxShape.circle,
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
                    Text(_error ?? _cameraError ?? (kIsWeb ? 'Upload a face liveness photo' : 'Look straight ahead'),
                        textAlign: TextAlign.center,
                        style: KType.title(color: (_error ?? _cameraError) != null ? KColor.loss : null)),
                    const SizedBox(height: 10),
                    Text(
                        _cameraError != null
                            ? 'Tap below to try again'
                            : _error != null
                                ? 'Tap the button to try again'
                                : (_busy
                                    ? 'Uploading…'
                                    : kIsWeb
                                        ? 'A clear, front-facing photo of yourself'
                                        : 'Good light, no hat, no glasses. Fill the frame with your face and take one photo.'),
                        textAlign: TextAlign.center,
                        style: KType.body(color: KColor.ink2)),
                    if ((_error ?? _cameraError) == null && !_busy) ...[
                      const SizedBox(height: 20),
                      Text(
                        "We check the photo against your ID after you send it — that takes a few seconds, and you can retake it if it fails.",
                        textAlign: TextAlign.center,
                        style: KType.data(color: KColor.ink3),
                      ),
                    ],
                    const Spacer(),
                    // Round shutter — captures in place (no navigation to a
                    // separate camera screen) when a live preview is ready;
                    // retries camera init if it previously failed. On web,
                    // opens the file picker instead.
                    GestureDetector(
                      onTap: _busy
                          ? null
                          : (kIsWeb
                              ? _pickFile
                              : (_cameraError != null
                                  ? () => setState(() => _initializing = _initCamera())
                                  : _capture)),
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
                            : KIcon(
                                kIsWeb
                                    ? 'upload'
                                    : (_cameraError != null ? 'refresh' : 'camera'),
                                size: 30,
                                stroke: 1.9,
                                color: KColor.featureInk),
                      ),
                    ),
                  ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrameContent() {
    if (kIsWeb) {
      if (_pickedBytes != null) {
        return ClipOval(
          child: Image.memory(_pickedBytes!, width: 238, height: 238, fit: BoxFit.cover),
        );
      }
      return KIcon('upload', size: 64, color: KColor.ink3);
    }

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

  /// Web path: file_picker instead of a live camera (see file header).
  /// Converges on the same upload flow as [_capture].
  Future<void> _pickFile() async {
    setState(() => _error = null);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null) {
      setState(() => _error = "Couldn't read that file. Please try again.");
      return;
    }

    setState(() {
      _busy = true;
      _pickedBytes = bytes;
    });
    await _uploadAndContinue(bytes, picked.name.isNotEmpty ? picked.name : 'liveness-selfie.jpg');
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

    final bytes = await shot.readAsBytes();
    await _uploadAndContinue(bytes, shot.name.isNotEmpty ? shot.name : 'liveness-selfie.jpg');
  }

  /// Shared tail for both capture paths: presigned upload -> register
  /// against the draft (POST /kyc-documents) -> advance to kyc-checking,
  /// which triggers the actual verification. `_busy`/`_capturedPath`/
  /// `_pickedBytes` are set by the caller before this runs.
  Future<void> _uploadAndContinue(Uint8List bytes, String fileName) async {
    final draftId = AppScope.read(context).kycForm.draftId;
    if (draftId == null) {
      setState(() {
        _busy = false;
        _error = 'Something went wrong — please restart verification.';
      });
      return;
    }

    try {
      final upload = await _repo.requestUploadUrl(
        documentKind: 'liveness_selfie',
        documentName: fileName,
      );
      await _repo.putFile(upload.uploadUrl, bytes, contentType: 'image/jpeg');
      await _repo.registerDocument(
        kycSubmissionId: draftId,
        objectKey: upload.objectKey,
        // Display name only (documentKind stays the real 'liveness_selfie'
        // enum value below, untouched) — 2026-08-20, "please don't use
        // selfie wording for face liveness check".
        documentName: 'Face liveness check',
        documentKind: 'liveness_selfie',
      );

      if (!mounted) return;
      context.go(Routes.kycChecking);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      // Widened from `on ApiException` only (2026-08-20) — any OTHER
      // exception type used to leave `_busy` stuck true forever (a
      // permanent loading spinner over the selfie).
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }
}

/// The dashed guidance ring around the selfie frame — 2026-08-22 "Soft
/// Landing": docs/redesign/screen-specs.md screen 17 calls for a dashed
/// indicator-soft border (kept as a circle rather than the spec's 250×330
/// oval — reshaping risks the live CameraPreview's FittedBox-cover math).
class _DashedRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = KColor.indicatorSoft;
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
