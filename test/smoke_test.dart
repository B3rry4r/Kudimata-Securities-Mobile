// Smoke test: boots the REAL app (MaterialApp.router via the GoRouter under
// AppScope) at the splash entry and confirms it builds and settles without
// throwing. google_fonts may fall back to a bundled/asset font when offline —
// that fallback must not raise.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/router/app_router.dart';
import 'package:kudimata_securities/theme/app_theme.dart';

void main() {
  testWidgets('Real app boots at splash without exceptions', (tester) async {
    final state = AppState();
    final router = buildRouter(state);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp.router(
          theme: KTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    // Let the splash render, then advance past its 1400ms launch beat so it
    // navigates on to the sign-up entry — exercising a real route transition.
    // Continuous animations (spinner) mean pumpAndSettle would never settle, so
    // we pump explicit durations instead. The key assertion is that no exception
    // is thrown across build/layout/paint and the route swap.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500)); // fire splash timer
    await tester.pump(const Duration(milliseconds: 400)); // route transition
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);

    state.dispose();
  });
}
