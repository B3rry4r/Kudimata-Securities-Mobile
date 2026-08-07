// 00 · Splash — centered brand lockup, the launch screen. After a brief beat it
// routes to the returning-user unlock or the sign-up flow. Ported from shared.jsx
// Splash. Root gated screen: builds its own Scaffold, no tab bar.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/api/api_exception.dart';
import 'package:kudimata_securities/data/repositories/user_repository.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';

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
    context.go(app.passcodeSet ? Routes.login : Routes.signup);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.paper,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KMark(size: 56),
                const SizedBox(height: 22),
                Text.rich(
                  TextSpan(
                    style: KType.hero(color: KColor.ink).copyWith(
                      fontSize: 26,
                      letterSpacing: -0.39,
                    ),
                    children: [
                      const TextSpan(text: 'Kudimata '),
                      TextSpan(
                        text: 'Securities',
                        style: TextStyle(
                          fontWeight: KWeight.regular,
                          color: KColor.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 56,
            child: Column(
              children: [
                KSpinner(size: 22, color: KColor.ink3),
                const SizedBox(height: 18),
                Text('NGX markets'.upper, style: KType.label(color: KColor.ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
