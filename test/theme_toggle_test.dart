// Verifies that toggling AppState.themeMode at RUNTIME actually re-themes the
// currently-mounted screen (incl. the shell/navbar) — the global KColor palette
// alone doesn't, so each route is wrapped in a ListenableBuilder on AppState.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/router/app_router.dart';
import 'package:kudimata_securities/theme/app_theme.dart';
import 'package:kudimata_securities/theme/tokens.dart';

// Reactive wrapper mirroring main.dart (sets KColor.active each build).
class _Reactive extends StatefulWidget {
  const _Reactive(this.state, this.router);
  final AppState state;
  final GoRouterStub router;
  @override
  State<_Reactive> createState() => _ReactiveState();
}

typedef GoRouterStub = dynamic; // buildRouter returns a GoRouter

class _ReactiveState extends State<_Reactive> {
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_b);
  }

  void _b() => setState(() {});

  @override
  void dispose() {
    widget.state.removeListener(_b);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    KColor.active =
        widget.state.themeMode == ThemeMode.dark ? KPalette.dark : KPalette.light;
    return AppScope(
      state: widget.state,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: KTheme.light(),
        darkTheme: KTheme.dark(),
        themeMode: widget.state.themeMode,
        routerConfig: widget.router,
      ),
    );
  }
}

Future<void> _loadFonts() async {
  final loader = FontLoader('Space Grotesk');
  for (final p in const [
    'assets/fonts/SpaceGrotesk-Regular.ttf',
    'assets/fonts/SpaceGrotesk-Medium.ttf',
    'assets/fonts/SpaceGrotesk-SemiBold.ttf',
    'assets/fonts/SpaceGrotesk-Bold.ttf',
  ]) {
    loader.addFont(rootBundle.load(p));
  }
  await loader.load();
}

void main() {
  testWidgets('runtime theme toggle re-themes the live screen', (tester) async {
    await _loadFonts();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Directory('/tmp/shots').createSync(recursive: true);

    final state = AppState()
      ..signedIn = true
      ..passcodeSet = true
      ..kycApproved = true
      ..suitabilityComplete = true
      ..themeMode = ThemeMode.light;
    final router = buildRouter(state);
    final key = GlobalKey();

    await tester.pumpWidget(RepaintBoundary(key: key, child: _Reactive(state, router)));
    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    Future<int> bgRed() async {
      final r = await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        // sample a top pixel (status-bar/safe-area region = scaffold bg)
        const x = 12, y = 12;
        final i = (y * image.width + x) * 4;
        return data!.getUint8(i); // red channel
      });
      return r!;
    }

    final lightRed = await bgRed();

    // Toggle to dark at runtime.
    state.setThemeMode(ThemeMode.dark);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final darkRed = await bgRed();

    // Capture a PNG of the toggled-dark Home for visual confirmation of the navbar.
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('/tmp/shots/toggled_dark_home.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    // Light bg ≈ #FAFAFA (red ~250); dark bg ≈ #0C0C0F (red ~12).
    expect(lightRed, greaterThan(180), reason: 'home should start light');
    expect(darkRed, lessThan(60), reason: 'home bg should be dark after toggle');

    state.dispose();
  });
}
