// 01 · Splash — centered brand lockup, the launch screen. After a brief beat it
// routes to the returning-user unlock or the sign-up flow. Root gated screen:
// builds its own Scaffold, no tab bar.
//
// Artboard: docs/design/redesign-2026-08/01 Getting In.dc.html, `s01`/`s01d`
// (2026-08 redesign, per RULINGS.md — the id comes from the ruling sheet, not
// from any older comment that may once have lived here; see DECISIONS.md R-5).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Launch beat, then hand off to the right entry. SEAM: a secure store read
    // (passcode present? session valid?) decides login vs. sign-up here.
    _timer = Timer(const Duration(milliseconds: 1400), _afterBeat);
  }

  // AppState.signedIn only reflects a LOCAL presence check (a token was
  // found in secure storage at launch) — it has not been confirmed against
  // the backend yet. If it's set, spend one cheap authenticated call
  // (GET /users/me) confirming that token is still valid before routing into
  // the app; a session-expired/401 there means the stored token is stale, so
  // force a local sign-out and fall back to the same signed-out routing the
  // rest of this method already does. If `signedIn` is false, there is
  // nothing to confirm — go straight to the existing routing decision.
  //
  // A-6 cold-start fix (2026-08-29): for a signed-in investor with a
  // passcode set, app_router.dart's `_gateRedirect` now bounces THIS screen
  // straight to Routes.login itself, the instant startup hydration settles
  // — usually well inside this screen's own 1400ms brand beat, so the
  // `app.signedIn` branch below rarely gets to run before that redirect
  // wins. It stays as a defensive fallback for the rare case hydration is
  // slower than the beat (a cold OS cache, a first-run device): the
  // destination it computes is identical either way, and LogInScreen's own
  // `_unlock` re-verifies the session server-side regardless of which path
  // got it there.
  Future<void> _afterBeat() async {
    if (!mounted) return;
    final app = AppScope.read(context);

    // Startup hydration (signedIn from AuthTokenStore, passcodeSet from
    // PasscodeStore) is async and may not have completed yet — both flags
    // start `false` synchronously. Wait for it so the checks/routing below
    // read the real persisted state, not the pre-hydration default.
    await app.ready;
    if (!mounted) return;

    if (app.signedIn) {
      final repo = UserRepository(app.apiClient);
      try {
        await repo.me();
      } on ApiException catch (e) {
        if (e.isSessionExpired || e.statusCode == 401) {
          await app.forceSignOut();
        }
      }
    }

    if (!mounted) return;
    // First-time (no passcode set yet) investors see the illustrated welcome
    // slider first (2026-08-22 "Soft Landing" redesign, screen 02) instead
    // of landing straight on the sign-up form.
    context.go(app.passcodeSet ? Routes.login : Routes.welcome);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The one full-bleed feature-tinted (grape) screen in the whole app;
    // everything else sits on --bg/--paper. `KColor.feature` already
    // flattens to the ordinary dark card colour in dark mode per
    // DECISIONS.md R-26, so no separate dark branch is needed here.
    return Scaffold(
      backgroundColor: KColor.feature,
      body: SafeArea(
        child: Column(
          children: [
            // `s01`: mark + wordmark centered in the remaining space, no
            // subtitle — the artboard draws only the lockup, not the old
            // "Own a piece of Nigeria's biggest companies" strap line.
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const KMark(size: 92, white: true),
                    const SizedBox(height: 24),
                    // `s01`: ONE uniform string, weight 800, 30px, -0.02em,
                    // solid --feature-ink — not split into a bold/
                    // translucent pair like the Wordmark component renders
                    // elsewhere. Splash spells this out by hand.
                    Text(
                      'Kudimata Invest',
                      style: KType.hero(color: KColor.featureInk).copyWith(
                        fontSize: 30,
                        fontWeight: KWeight.black,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 44),
              child: Column(
                children: [
                  KSpinner(size: 20, color: KColor.featureInk2),
                  const SizedBox(height: 14),
                  Text(
                    'Kudimata Securities Ltd · SEC registered'.upper,
                    textAlign: TextAlign.center,
                    style: KType.micro(color: KColor.featureInk2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
