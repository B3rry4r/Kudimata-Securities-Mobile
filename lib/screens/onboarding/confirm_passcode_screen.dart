// 04 · Confirm your passcode — re-enter to confirm. Mismatch tints the dots loss
// and shows the error line (the design's seeded state). On match we set
// passcodeSet and advance to biometric. Ported from screens.jsx ConfirmPasscode.
//
// Re-entry (widget.reentry): when this flow is entered from Security's
// "Change passcode" (an already-signed-in investor) rather than first-time
// onboarding, create_passcode_screen.dart PUSHes here (instead of the
// gated-flow's go()) so the Security/account stack underneath survives. On
// a match we pop back to it (twice — dismissing this screen and the create
// step) and show a confirmation SnackBar, instead of continuing into
// biometric/KYC.
//
// A THIRD case (AppState.loginPasscodeSetup — see that flag's doc comment in
// app_state.dart): a fresh email+password login (log_in_screen.dart) that
// just created this device's first-ever local passcode. Neither of the two
// existing branches fits it — it isn't first-time signup onboarding (so
// shouldn't continue into Biometric/KYC-intro unconditionally) and it isn't
// Security's reentry (there's no Security screen underneath to pop back
// to; this was reached via go(), not push()). It's threaded via AppState
// rather than GoRouter `extra` because app_router.dart's ConfirmPasscode
// route builder only ever forwards `reentry`/`created`, not a third field.
// On a match we hand off to log_in_screen.dart's
// [hydrateGatingStateAndRoute], which fetches this investor's REAL
// KYC/suitability state from the server and routes to wherever that state
// actually says they belong (KYC, suitability, or straight to Home for an
// already-fully-onboarded account) instead of always restarting Biometric/KYC.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/api/passcode_store.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'log_in_screen.dart' show hydrateGatingStateAndRoute;
import 'onboarding_scaffold.dart';

/// Payload passed via GoRouter `extra` from create_passcode_screen.dart.
class ConfirmPasscodeArgs {
  const ConfirmPasscodeArgs({required this.code, this.reentry = false});

  /// The passcode chosen on the create step.
  final String code;

  /// See [ConfirmPasscodeScreen.reentry].
  final bool reentry;
}

class ConfirmPasscodeScreen extends StatefulWidget {
  const ConfirmPasscodeScreen({super.key, this.created, this.reentry = false});

  /// The passcode chosen on the create step (passed via GoRouter `extra`).
  final String? created;

  /// True when re-entering this flow from Security's "Change passcode"
  /// rather than first-time onboarding. Defaults to false so the ordinary
  /// signup → passcode → biometric → KYC flow is unaffected when this isn't
  /// explicitly set.
  final bool reentry;

  @override
  State<ConfirmPasscodeScreen> createState() => _ConfirmPasscodeScreenState();
}

class _ConfirmPasscodeScreenState extends State<ConfirmPasscodeScreen> {
  String _code = '';
  bool _error = false;
  final _passcodeStore = PasscodeStore();

  void _onKey(String k) {
    setState(() {
      if (k == 'del') {
        if (_code.isNotEmpty) _code = _code.substring(0, _code.length - 1);
        _error = false;
      } else if (_code.length < 6) {
        _code += k;
        _error = false;
      }
    });
    if (_code.length == 6) _evaluate();
  }

  Future<void> _evaluate() async {
    final created = widget.created;
    // No created code available (e.g. deep link): accept as the demo path.
    final matches = created == null || _code == created;
    if (matches) {
      // Persist a salted hash of the confirmed passcode so log_in_screen.dart
      // has a real local value to verify a re-entered passcode against — see
      // PasscodeStore. AppState.setPasscode(true) is kept alongside this: it's
      // the in-memory gate flag the router/other screens already read.
      await _passcodeStore.setPasscode(created ?? _code);
      if (!mounted) return;
      final app = AppScope.read(context);
      app.setPasscode(true);
      if (widget.reentry) {
        // Re-entry from Security: confirm the change and return there,
        // rather than continuing into onboarding's biometric/KYC screens.
        // Create+confirm were both pushed (not go()'d) so two pops land
        // back on Security with the account tab/shell intact.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passcode updated')),
        );
        context.pop(); // dismiss Confirm.
        context.pop(); // dismiss Create -> back to Security.
      } else if (app.loginPasscodeSetup) {
        // Fresh login re-entry — see file header. Consume the flag before
        // handing off so it can never leak into a later, unrelated flow.
        app.setLoginPasscodeSetup(false);
        await hydrateGatingStateAndRoute(context);
      } else if (kIsWeb) {
        // No local_auth backing store on web — skip straight past biometric
        // enrolment, same as BiometricScreen's own "Maybe later" path.
        app.setSignedIn(true);
        context.go(Routes.onboardingPersonal);
      } else {
        context.go(Routes.biometric);
      }
    } else {
      setState(() => _error = true);
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
            KOnboardTopBar(
              onBack: () => widget.reentry
                  ? context.pop()
                  : context.go(Routes.createPasscode),
            ),
            Expanded(
              child: KOnboardBody(
                paddingTop: 12,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: KScreenHead(title: 'Confirm your passcode'),
                  ),
                  const SizedBox(height: 40),
                  KPasscodeDots(filled: _code.length, error: _error),
                  const SizedBox(height: 18),
                  if (_error)
                    Text(
                      "Passcodes don't match",
                      style: KType.body(color: KColor.loss, w: KWeight.medium),
                    ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: KKeypad(onKey: _onKey),
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
