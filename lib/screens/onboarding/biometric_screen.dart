// Artboard `s06` (+ dark `s06d`) in `01 Getting In.dc.html` — enable Face ID.
// Illustration + headline, "Turn on Face ID" / "Maybe later". Both paths sign
// the investor in and land straight on Home — Enable also flips
// biometricEnabled. KYC/suitability are no longer forced here — browsing is
// open to everyone, only trading/funding require them (see Home's "Complete
// your KYC" prompt and the KYC-gate checks on Buy/Sell/Add money/Withdraw).
//
// 2026-08-24: used to detour through the onboarding personal-details step
// (personal_details_screen.dart) before Home — direct product feedback: "a
// few more details should be part of the KYC and not a separate step after
// login". That screen's fields were collected as part of STARTING KYC
// verification instead (kyc_intro.dart's `_start()`), so a fresh signup
// reaches Home immediately, browse-only, same as any other not-yet-verified
// investor.
//
// 2026-08-29 (A-1 audit fix): kyc_intro.dart no longer detours anywhere
// either — see its own header for where each of that screen's fields ended
// up (mostly duplicates of sign_up_screen.dart's phone field and
// utility_bill.dart's address fields; DOB folded into bvn_nin.dart's
// confirm step). Nothing changes here: this screen still signs in and
// lands on Home either way, same as always.
//
// 2026-08-27 (SCREEN-AGENT-BRIEF.md R-5 audit): dropped the "Step 4 of 4"
// KOnboardTopBar this screen had grown. It was justified by an in-code
// comment citing "canvas #s09" — an id from the retired 97-screen canvas
// that no longer means anything in the current one. The real `s06` starts
// content directly under the status bar with no header row at all (the same
// shape personal_details_screen.dart's own #s10 audit already corrected).
//
// Ported from screens.jsx Biometric.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/biometric_auth.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'log_in_screen.dart' show hydrateGatingStateAndRoute;
import 'onboarding_scaffold.dart';

class BiometricScreen extends StatelessWidget {
  const BiometricScreen({super.key});

  Future<void> _enable(BuildContext context) async {
    // 2026-08-24: this used to flip the flag with no check at all ("SEAM:
    // real biometric enrolment plugs in here"), which is half of what let
    // the lock screen's fingerprint key unlock the account without
    // authenticating anyone — see lib/data/biometric_auth.dart. Enrolment
    // now has to actually succeed on this device before the flag is set; if
    // it doesn't, we simply carry on without biometrics rather than
    // promising one that cannot work.
    final ok = await BiometricAuth.isAvailable() &&
        await BiometricAuth.authenticate(
          reason: 'Confirm it is you to turn on biometric unlock',
        );
    if (!context.mounted) return;
    if (ok) AppScope.read(context).setBiometric(true);
    await hydrateGatingStateAndRoute(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: KOnboardBody(
          paddingTop: 24,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),
            KStatusView(
              illustrationName: 'sign-in',
              // `s06`'s illustration sits on the sun-tinted plate, not the
              // purple `indicator` tint `pending` resolves to — `success` is
              // the only KStatusTone that maps to the sun plate (see
              // KStatusView's tone switch). Its default illustration name
              // is irrelevant here since illustrationName overrides it.
              tone: KStatusTone.success,
              title: 'Unlock with your face',
              message: 'Faster than typing your passcode.',
            ),
            const Spacer(),
            KButton(
              label: 'Turn on Face ID',
              onPressed: () => _enable(context),
            ),
            const SizedBox(height: 10),
            KButton(
              label: 'Maybe later',
              variant: KButtonVariant.ghost,
              onPressed: () => hydrateGatingStateAndRoute(context),
            ),
            // 2026-08-29 (A-7 audit — "a skip that is honest about what it
            // costs them"): one true, verifiable line, not in `s06` (which
            // draws no caption under its two buttons at all — see this
            // file's header for the exact markup) but added in the same
            // spirit as R-10's "designed fresh" precedent, since the audit
            // asked for it directly. Says only what the app actually does:
            // passcode entry every time (real — see log_in_screen.dart's
            // unlock keypad, gated on `AppState.biometricEnabled`, and
            // main.dart's resume-lock, A-6), and that Security's toggle
            // genuinely re-offers this later (real — security_screen.dart's
            // `_setBiometric` runs the exact same BiometricAuth check this
            // screen's `_enable` does).
            const SizedBox(height: 10),
            Text(
              "You'll use your passcode to unlock instead. Turn Face ID on "
              'any time from Security.',
              textAlign: TextAlign.center,
              style: KType.body(color: KColor.ink3).copyWith(fontSize: 13, height: 18 / 13),
            ),
          ],
        ),
      ),
    );
  }
}
