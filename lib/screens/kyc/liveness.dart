// KYC 4 — liveness selfie (step 4 of 7; renumbered 8->7 2026-08-27 per
// X-2/bvn_nin.dart's derivation). On mobile: a framed selfie capture
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
import 'package:flutter/services.dart' show DeviceOrientation;
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
      // Bug 1 fix (2026-08-31, "the image is bad, not the integration" —
      // livenessMatchPct scoring ~0.02-0.06, effectively no face found, on a
      // provider that scores a genuine selfie 96.4): traced the whole
      // upload path — _capture() reads real bytes straight off
      // controller.takePicture() (never a widget/ClipOval screenshot), and
      // those bytes go to Dio's raw-Uint8List fast path (dio_mixin.dart's
      // `_transformData` — "Handle binary data which does not need to be
      // transformed") untouched: no crop, no resize, no re-encode. What's
      // NOT pinned down anywhere in that chain is orientation: without a
      // lock, the plugin infers upright from the device's live sensor
      // reading at the instant of capture, and this screen (like the rest
      // of the app) never constrains device orientation — a selfie is
      // routinely shot with the phone tilted off-vertical at exactly that
      // instant. A capture that lands rotated 90°, with the face pixels
      // themselves rotated (not just an EXIF tag some downstream decoder
      // may or may not honour), is indistinguishable from "no face" to a
      // detector that isn't rotation-invariant — which matches a
      // near-zero score far better than "low quality." Locking capture
      // orientation removes that ambiguity outright: every photo this
      // screen takes is now encoded upright in portrait regardless of how
      // the phone was actually held.
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
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
      // s15's own panel is `var(--feature)` (full-bleed grape in light,
      // flattened to the dark card colour in dark per R-26) — the one KYC
      // screen the canvas puts on that surface rather than `--bg`.
      backgroundColor: KColor.feature,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KycTopBar(
              // R-45 as amended: locked (pre-restart) goes to the checklist
              // hub, in-session goes to the normal predecessor — see
              // kycBackTarget's own doc comment.
              onBack: () => context.go(kycBackTarget(context, Routes.kycLiveness)),
              stepLabel: 'Verification · 4 of 7',
              onFeature: true,
            ),
            const KycStepProgress(total: 7, current: 4, onFeature: true),
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
                    //
                    // C-2 fix (2026-08-29 product-owner audit — "the camera
                    // cutout is wrong and not filling the proper circle"):
                    // this was a 240x240 CIRCLE. s15 itself draws
                    // `width:250px;height:320px;border-radius:50%` — an
                    // OVAL ("Fit your face in the oval" is s15's own
                    // headline) — and _DashedRingPainter's own old doc
                    // comment admitted it was "kept as a circle rather than
                    // the spec's oval — reshaping risks the live
                    // CameraPreview's FittedBox-cover math." That risk claim
                    // was wrong: BoxFit.cover and ClipOval both work on any
                    // target rect, square or not — nothing about the fit
                    // math depends on the frame being square. Fixed to
                    // 250x320 (s15's own literal px, not the older
                    // screen-specs.md's 250x330), with a single outer
                    // ClipOval (below) doing the clipping for every frame
                    // state instead of each branch clipping itself to a
                    // square.
                    SizedBox(
                      width: 250,
                      height: 320,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: ClipOval(
                              child: Container(
                                // s15's frame sits on the feature/grape panel
                                // with a translucent white wash
                                // (`rgba(255,255,255,.08)`) — not
                                // indicatorTint, a light-bg-card token that
                                // renders as a mismatched lavender block here.
                                color: KColor.featureInk.withValues(alpha: 0.08),
                                alignment: Alignment.center,
                                child: _buildFrameContent(),
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
                    Text(_error ?? _cameraError ?? (kIsWeb ? 'Upload a face liveness photo' : 'Look straight ahead'),
                        textAlign: TextAlign.center,
                        // On the feature/grape panel: featureInk (white) by
                        // default, lossOnInk (a light coral, legible on a
                        // dark/grape surface — plain `KColor.loss` is a
                        // saturated red tuned for a light card) for an error.
                        style: KType.title(
                            color: (_error ?? _cameraError) != null ? KColor.lossOnInk : KColor.featureInk)),
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
                        style: KType.body(color: KColor.featureInk2)),
                    if ((_error ?? _cameraError) == null && !_busy) ...[
                      const SizedBox(height: 20),
                      Text(
                        "We check the photo against your ID after you send it — that takes a few seconds, and you can retake it if it fails.",
                        textAlign: TextAlign.center,
                        style: KType.data(color: KColor.featureInk2),
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
                        width: 74,
                        height: 74,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          // s15 draws a plain white shutter
                          // (`background:#fff;border:5px solid
                          // rgba(255,255,255,.35)`) sitting ON the grape
                          // panel — a grape-filled circle (the old colours
                          // here) would now be invisible against the
                          // feature background this screen uses.
                          color: KColor.featureInk,
                          shape: BoxShape.circle,
                          border: Border.all(color: KColor.featureInk.withValues(alpha: 0.35), width: 5),
                        ),
                        child: _busy
                            ? KSpinner(size: 26, color: KColor.feature)
                            : KIcon(
                                kIsWeb
                                    ? 'upload'
                                    : (_cameraError != null ? 'refresh' : 'camera'),
                                size: 28,
                                stroke: 1.9,
                                color: KColor.feature),
                      ),
                    ),
                    // Canvas escape hatch (screen 17's ghost "My camera
                    // won't work" -> manual review) — mobile-only, since a
                    // camera failure only exists on the live-preview path;
                    // web already falls back to a file picker (see file
                    // header). Without this, a permanently denied/broken
                    // camera left the investor with nothing but a retry
                    // loop and no way forward.
                    if (!kIsWeb && _cameraError != null && !_busy) ...[
                      const SizedBox(height: 16),
                      // KButton's ghost variant's text is always KColor.ink —
                      // invisible on this screen's feature/grape panel, and
                      // lib/widgets/** is frozen for this wave (see this
                      // file's SHARED-CHANGE note in the screen agent's
                      // report). A screen-local text link, not a fork of
                      // KButton, stands in until it gains an on-feature fg.
                      GestureDetector(
                        onTap: () => context.go(Routes.kycOutcome),
                        behavior: HitTestBehavior.opaque,
                        child: Text("My camera won't work",
                            style: KType.cardTitle(color: KColor.featureInk)),
                      ),
                    ],
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

  // C-2 fix: each branch used to clip itself into its own square ClipOval
  // (238x238, one px shy of the old 240x240 frame). The frame's own
  // Positioned.fill ClipOval now does that clipping once, for whatever this
  // returns — square or not — so none of these branches clips itself any
  // more; they just fill a 250x320 rect (the frame's real size, matching
  // s15's oval) with BoxFit.cover.
  Widget _buildFrameContent() {
    if (kIsWeb) {
      if (_pickedBytes != null) {
        return Image.memory(_pickedBytes!, width: 250, height: 320, fit: BoxFit.cover);
      }
      return KIcon('upload', size: 64, color: KColor.ink3);
    }

    if (_capturedPath != null) {
      return Image.file(
        File(_capturedPath!),
        width: 250,
        height: 320,
        fit: BoxFit.cover,
      );
    }

    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      // previewSize is reported in the sensor's native (often landscape)
      // orientation regardless of the device's current orientation, so
      // width/height are swapped here before FittedBox scales+crops it to
      // fill the frame — the standard package:camera pattern for a
      // portrait-framed preview.
      final previewSize = controller.value.previewSize!;
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
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
      // Real client-side capture timestamp — review_submit_screen.dart's
      // "Selfie" row shows this (the backend has no such field of its own).
      AppScope.read(context).kycForm.setSelfieCapturedAt(DateTime.now());
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
/// indicator-soft border.
///
/// C-2 fix (2026-08-29 product-owner audit): this used to be a
/// `canvas.drawArc` loop at ONE fixed `radius` — correct only for a square
/// frame. The frame it rings is a 250x320 OVAL now (see the SizedBox above),
/// so a single radius no longer describes its edge at all (it drew a circle
/// touching the frame's left/right sides but well short of its top/bottom).
/// `Path.addOval` + `computeMetrics()` traces the real ellipse for whatever
/// `size` this paints into, so it keeps working if the frame's aspect ratio
/// ever changes again.
class _DashedRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = KColor.indicatorSoft;
    const dash = 7.0;
    const gap = 6.0;
    final path = Path()..addOval(Offset.zero & size);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter oldDelegate) => false;
}
