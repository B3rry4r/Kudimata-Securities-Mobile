// 00 · Splash — centered brand lockup, the launch screen. After a brief beat it
// routes to the returning-user unlock or the sign-up flow. Ported from shared.jsx
// Splash. Root gated screen: builds its own Scaffold, no tab bar.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
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
    _timer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      final app = AppScope.read(context);
      context.go(app.passcodeSet ? Routes.login : Routes.signup);
    });
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
                Text('NGX & US markets'.upper, style: KType.label(color: KColor.ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
