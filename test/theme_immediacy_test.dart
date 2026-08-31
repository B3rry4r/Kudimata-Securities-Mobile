// Verifies the fix for a real shipped bug: "dark and light mode switch is
// buggy, i have to switch tabs before everything changes properly ... it
// should be immediate."
//
// Root cause (confirmed by reading both sides, not assumed): every route in
// app_router.dart is wrapped in `themed()`/`themedGated()`, a
// `ListenableBuilder` whose own doc comment already said its purpose was to
// force a repaint on a theme change — but it was listening to `state`
// (AppState), a session/session-data notifier that never fires for a theme
// change. Nothing ever re-ran the wrapped screen's `build()` for a theme
// toggle; the only thing that "fixed" it was switching tabs, because
// go_router only (re)constructs a branch's screen instance when you actually
// navigate into it — exactly the reported per-tab symptom.
//
// The fix merges in `KThemeRuntime.instance` (lib/theme/tokens.dart), which
// notifies on both a `KThemePreference` change AND a live OS-brightness flip
// under `ThemeMode.system`. This test proves two things about that fix:
//   1. Immediate: a screen's own rendered colour flips on the very next
//      frame, with NO navigation of any kind in between — including a tab
//      that is not even the active one (kept alive offstage in the shell's
//      IndexedStack).
//   2. Lossless: the screen's State object is the SAME instance before and
//      after — i.e. `ListenableBuilder` replaced its subtree in place rather
//      than the route being torn down and rebuilt, so whatever that State
//      was holding (scroll position, form input, in-flight futures) was
//      never disturbed.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/data/api/theme_mode_store.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/screens/home/home_screen.dart';
import 'package:kudimata_invest/screens/portfolio/portfolio_screen.dart';
import 'package:kudimata_invest/screens/kyc/kyc_form_state.dart';
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/theme/tokens.dart';

/// `KThemePreference.set()` persists via `flutter_secure_storage`'s method
/// channel — with no handler registered, that call never returns under
/// `flutter test` (no real platform to answer it), which hangs `set()`'s
/// `await` forever. Same in-memory fake as security_persistence_test.dart's
/// `_mockSecureStorage`, trimmed to just the `write` this test needs.
void _mockSecureStorageWrites() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => null,
  );
}

void main() {
  // Continuous animations/pollers forbid pumpAndSettle project-wide (see
  // CLAUDE.md) — pump explicit durations instead, same pattern as
  // route_walk_test.dart's `settle()`.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets(
    'a theme toggle repaints the active AND an offstage tab on the very next frame, without remounting either',
    (tester) async {
      _mockSecureStorageWrites();
      addTearDown(() => KThemePreference.instance.set(ThemeMode.system));

      final state = AppState()
        ..passcodeSet = true
        ..biometricEnabled = true
        ..kycSubmitted = true
        ..kycApproved = true
        ..signedIn = true
        ..apiClient = ApiClient()
        ..kycForm = KycFormState();
      final router = buildRouter(state);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp.router(
            theme: KTheme.light(),
            darkTheme: KTheme.dark(),
            themeMode: KThemePreference.instance.mode,
            routerConfig: router,
          ),
        ),
      );
      await settle(tester);

      // Visit Portfolio once so its branch is actually mounted, then go back
      // to Home — Portfolio's screen is now alive but OFFSTAGE inside the
      // shell's IndexedStack, exactly the "other tab" the bug report says
      // never updates until you switch to it.
      router.go('/portfolio');
      await settle(tester);
      router.go('/home');
      await settle(tester);

      expect(KColor.active.brightness, Brightness.light);

      // `offstage: true` means the screen is currently hidden inside the
      // shell's IndexedStack — finders must be told NOT to skip it
      // (`skipOffstage: false`) or they'd find nothing at all.
      Color scaffoldBg(Type screenType, {required bool offstage}) {
        final scaffold = find.descendant(
          of: find.byType(screenType, skipOffstage: !offstage),
          matching: find.byType(Scaffold, skipOffstage: !offstage),
        );
        return tester.widget<Scaffold>(scaffold.first).backgroundColor!;
      }

      // Baseline: both tabs render light's `bg` right now.
      expect(scaffoldBg(HomeScreen, offstage: false), KPalette.light.bg);
      expect(scaffoldBg(PortfolioScreen, offstage: true), KPalette.light.bg);

      // Prove statefulness survives: capture the SAME State instances.
      final homeStateBefore = tester.state(find.byType(HomeScreen));
      final portfolioStateBefore =
          tester.state(find.byType(PortfolioScreen, skipOffstage: false));

      // The toggle itself — no navigation call anywhere near this.
      await KThemePreference.instance.set(ThemeMode.dark);
      await tester.pump(); // exactly one frame: this is the "immediate" claim.

      expect(KColor.active.brightness, Brightness.dark);

      // Both the ACTIVE tab and the OFFSTAGE one repainted, on that one frame,
      // with zero navigation in between.
      expect(scaffoldBg(HomeScreen, offstage: false), KPalette.dark.bg);
      expect(scaffoldBg(PortfolioScreen, offstage: true), KPalette.dark.bg);

      // Nothing was torn down and remounted to get there.
      expect(tester.state(find.byType(HomeScreen)), same(homeStateBefore));
      expect(
        tester.state(find.byType(PortfolioScreen, skipOffstage: false)),
        same(portfolioStateBefore),
      );

      // Navigation state itself is intact too: the shell still resolves the
      // same current tab, and switching to the previously-offstage tab still
      // lands on the same screen type (branch wasn't discarded).
      expect(find.byType(HomeScreen), findsOneWidget);
      router.go('/portfolio');
      await settle(tester);
      expect(find.byType(PortfolioScreen), findsOneWidget);
      expect(tester.state(find.byType(PortfolioScreen)), same(portfolioStateBefore));

      state.dispose();
    },
  );
}
