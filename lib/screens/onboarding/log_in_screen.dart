// 06 · Log in — the returning-user unlock. Centered wordmark, passcode dots, the
// keypad (with a biometric shortcut bottom-left), and a Forgot passcode link.
// On a full passcode we sign in and go home. Ported from screens.jsx LogIn.
// Root gated screen: own Scaffold, no tab bar.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'onboarding_scaffold.dart';

class LogInScreen extends StatefulWidget {
  const LogInScreen({super.key});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  String _code = '';

  void _onKey(String k) {
    setState(() {
      if (k == 'del') {
        if (_code.isNotEmpty) _code = _code.substring(0, _code.length - 1);
      } else if (_code.length < 6) {
        _code += k;
      }
    });
    if (_code.length == 6) _unlock();
  }

  void _unlock() {
    // SEAM: real passcode/biometric verification plugs in here.
    AppScope.read(context).setSignedIn(true);
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    // A returning-user lock screen: the whole block — brand, prompt, dots, keypad,
    // forgot link — is vertically centred as one cohesive unit (scrolls if it ever
    // exceeds the viewport). No spacer pushing the keypad to an extreme.
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KWordmark(center: true),
                const SizedBox(height: 28),
                Text('Enter your passcode', style: KType.body(color: KColor.ink2)),
                const SizedBox(height: 24),
                KPasscodeDots(filled: _code.length),
                const SizedBox(height: 44),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: KKeypad(
                    onKey: _onKey,
                    leftAction: app.biometricEnabled
                        ? KFingerprint(size: 26, stroke: 1.6, color: KColor.ink)
                        : null,
                    onLeftAction: app.biometricEnabled ? _unlock : null,
                  ),
                ),
                const SizedBox(height: 8),
                KButton(
                  label: 'Forgot passcode',
                  variant: KButtonVariant.ghost,
                  size: KButtonSize.sm,
                  fullWidth: false,
                  onPressed: () => context.go(Routes.reset),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
