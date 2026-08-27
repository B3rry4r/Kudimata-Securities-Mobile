// Stage 9 — Security (pushed). Change passcode row + biometric KSwitch.
// Biometric reflects AppState.biometricEnabled (client-local, unchanged);
// the row itself is hidden on web (kIsWeb) since there's no local_auth
// backing store there — same reasoning as biometric_screen.dart being
// skipped in the web onboarding flow (confirm_passcode_screen.dart).
//
// R-5 correction (2026-08-27, docs/redesign/DECISIONS.md): this file used
// to cite "#s50" for both the freeze/log-out placement and the current
// device row — that id is from the OLD 97-screen canvas. The real, current
// artboard is `06 Account and Support.dc.html#s54` ("54 · Security").
// Re-verified against s54 below:
//  - s54 draws NO Log out button anywhere (unlike old #s50) — the row here
//    stays anyway as a real, kept convenience (account_screen.dart also has
//    its own, per direct product instruction; two working entry points,
//    neither a design match).
//  - s54's toggles are "Face ID to open the app" (→ this screen's
//    Biometric unlock, already cross-platform-renamed for the same reason
//    documented below), "Ask for PIN on every trade", and "Alert me on new
//    logins". The first two are real (see the PIN row added below); "Alert
//    me on new logins" has no backing preference/notification field
//    anywhere in this app — filed in BACKEND_GAPS.md, not built.
//  - s54's "Change transaction PIN" row (24-hour hold) is NOT built: R-31
//    already rules that per-order PIN reuses the existing passcode rather
//    than a second, separately-managed credential, and grepping the
//    backend for any 24-hour hold found nothing (same null result as the
//    wallet withdraw screen's identical claim — see wallet_flows.dart).
//  - s54's second signed-in device ("iPhone 13, Abuja") stays NOT
//    fabricated — no real multi-device feed exists (see below).
//
// Two-factor authentication was removed from this screen (2026-08-10) — no
// real 2FA infrastructure exists distinct from the OTP verification the app
// already does at sign-up/sign-in; the toggle only fired
// PATCH /auth/step-up-preference with nothing behind it. Mirrors `Security`
// in settings-screens.jsx, minus that row.
//
// "Change passcode" re-enters the onboarding create/confirm-passcode flow
// (Routes.createPasscode → Routes.confirmPasscode), pushed with
// `extra: true` so create_passcode_screen.dart / confirm_passcode_screen.dart
// know this is a re-entry passcode change rather than first-time onboarding:
// on success they pop back to this screen (with a "Passcode updated"
// SnackBar) instead of continuing into biometric-enrollment/KYC-intro. Since
// PasscodeStore (lib/data/api/passcode_store.dart) exists and can verify a
// passcode locally, re-entry is gated behind a quick "confirm your current
// passcode" bottom sheet using its verifyPasscode — a device with no
// passcode set yet skips straight to the create flow (nothing to confirm
// against).
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/api/passcode_store.dart';
import 'package:kudimata_invest/data/biometric_auth.dart';
import 'package:kudimata_invest/screens/shared/confirm_passcode_sheet.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _passcodeStore = PasscodeStore();

  /// "Change passcode" row: re-enters the create/confirm-passcode flow,
  /// gated behind a "confirm your current passcode" step when a passcode
  /// already exists on this device (nothing to gate against on a fresh
  /// install, so that case skips straight through).
  Future<void> _changePasscode() async {
    final hasExisting = await _passcodeStore.hasPasscode();
    if (!mounted) return;
    if (!hasExisting) {
      context.push(Routes.createPasscode, extra: true);
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KColor.bg,
      builder: (_) => ConfirmPasscodeSheet(store: _passcodeStore),
    );
    if (!mounted || confirmed != true) return;
    context.push(Routes.createPasscode, extra: true);
  }

  /// Sign-out (moved here from account_screen.dart, 2026-08-23 exactness
  /// pass — the canvas's #s45 Account hub has no sign-out affordance at
  /// all; it's #s50 Security that carries the "Log out" ghost button, right
  /// below "Freeze my account").
  /// Enabling requires a real biometric check on this device; disabling
  /// never does. A silent failure here would leave the switch reading "on"
  /// while nothing could actually authenticate, so an unavailable or failed
  /// check says so plainly instead.
  Future<void> _setBiometric(AppState app, bool value) async {
    if (!value) {
      app.setBiometric(false);
      return;
    }
    if (!await BiometricAuth.isAvailable()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No face or fingerprint is set up on this device yet. Add one in your '
            'phone settings, then turn this on.',
          ),
        ),
      );
      return;
    }
    final ok = await BiometricAuth.authenticate(
      reason: 'Confirm it is you to turn on biometric unlock',
    );
    if (!mounted) return;
    if (ok) app.setBiometric(true);
  }

  Future<void> _signOut(BuildContext context) async {
    final app = AppScope.read(context);
    try {
      await app.apiClient.post('/auth/logout');
    } on ApiException {
      // A network hiccup shouldn't trap the user signed in locally — fall
      // through to local teardown regardless of whether the API call
      // succeeded.
    }
    // signOut(), not forceSignOut() — a plain voluntary sign-out preserves
    // this device's passcode (BUG-03) instead of wiping it; see
    // AppState.signOut()'s doc comment.
    await app.signOut();
    if (!context.mounted) return;
    context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return KAccountSubScaffold(
      title: 'Security',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plain text+chevron / bare-Switch rows — the canvas's #s50 rows
          // have no leading icon bubble, and Face ID / Passcode-for-
          // withdrawals are each a single `Switch` x-import (label+
          // description+toggle in one component), not a Row wrapping a
          // Switch (2026-08-23 exactness pass; mirrors
          // notifications_settings_screen.dart's already-correct pattern).
          KAccountCard(
            children: [
              KAccountRow(
                title: 'Change passcode',
                // PasscodeStore (lib/data/api/passcode_store.dart) doesn't
                // track a last-set timestamp, so this stays a plain, honest
                // label rather than a fabricated "Last changed N days ago"
                // — see this file's header note.
                sub: 'Set a new 6-digit passcode',
                right: const KRowChevron(),
                first: true,
                onTap: _changePasscode,
              ),
              // 2026-08-24 fix — reported live, same flaw as
              // notifications_settings_screen.dart had: a bare KSwitch
              // separated only by a plain Divider has no vertical padding
              // of its own, so the label sits cramped against the divider
              // and the knob reads as vertically misaligned against its
              // two-line label. data_privacy_screen.dart/
              // price_alerts_screen.dart already wrap each KSwitch in a
              // padded, top-bordered Container instead — matching that
              // here rather than the bare-Divider shape this screen had.
              if (!kIsWeb)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
                  ),
                  // screen-specs.md spec 50 literally says "Face ID" — kept
                  // as the cross-platform "Biometric unlock" instead
                  // (2026-08-23 exactness pass: deliberate deviation, not an
                  // oversight). "Face ID" is an Apple-specific term; this
                  // toggle also drives Android fingerprint/face unlock, so
                  // the mockup's iOS-only copy would be wrong on Android.
                  child: KSwitch(
                    label: 'Biometric unlock',
                    description: 'Unlock with your face or fingerprint',
                    checked: app.biometricEnabled,
                    // 2026-08-24: was `onChanged: (v) => app.setBiometric(v)`
                    // with the comment "SEAM: real biometric enrolment plugs
                    // in here" — it flipped a client-local bool and nothing
                    // else, which is half of what let the lock screen's
                    // fingerprint key unlock the account without
                    // authenticating anyone (see lib/data/biometric_auth.dart).
                    // Turning it ON now requires passing a real biometric
                    // check on this device. Turning it OFF never does — you
                    // must always be able to disable a security feature you
                    // can no longer satisfy, e.g. after wiping your prints.
                    onChanged: (v) => _setBiometric(app, v),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
                ),
                // Real, existing behaviour, not a new toggle — the withdraw
                // flow requires passcode confirmation before money leaves
                // (wallet_flows.dart's _confirm() gates on
                // confirmPasscode()). NOTE: this row previously made that
                // claim while it was FALSE — no passcode step existed
                // anywhere in the withdraw flow until 2026-08-24. It is
                // accurate now; do not let the two drift apart again.
                // Shown here as disabled/always-on per spec 50, matching
                // what the app actually does rather than adding an unwired
                // setting.
                child: const KSwitch(
                  label: 'Passcode for withdrawals',
                  description: 'Always ask before money leaves',
                  checked: true,
                  disabled: true,
                ),
              ),
              // s54's "Ask for PIN on every trade" — real, existing
              // behaviour, same shape as the withdrawal row above: every
              // buy/sell order is gated on `confirmPasscode()` before it's
              // placed (trade_flows.dart, R-31 — the "PIN" reuses this
              // app's existing 6-digit passcode, not a second credential).
              // Shown disabled/always-on, matching what the app actually
              // does, not an unwired setting.
              Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
                ),
                child: const KSwitch(
                  label: 'PIN on every trade',
                  description: 'Always ask before an order is placed',
                  checked: true,
                  disabled: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Devices signed in'.upper, style: KType.label()),
          const SizedBox(height: 12),
          // No real device/session feed exists on the backend yet (2026-08-22
          // — see docs/redesign/PLAN.md) — this device's row is genuine
          // (we're looking at it right now). The canvas's example second
          // device ("Infinix Hot 30 · Ibadan", with a "Remove" action) isn't
          // shown: fabricating a second signed-in device this app has no way
          // to actually see or revoke would be actively misleading on a
          // security screen, unlike a harmless static example elsewhere
          // (e.g. the credits meter) — left as a placeholder shape for when
          // a real multi-device feed lands, not copied verbatim.
          KAccountCard(
            children: [
              KAccountRow(
                title: 'This device',
                sub: 'Active now',
                subUppercase: true,
                first: true,
                right: const KStatusPill(status: KStatus.approved, label: 'Trusted', small: true),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const KNudgeCard(
            tone: KNudgeTone.grape,
            title: 'Nobody from Kudimata will ask for your passcode',
            body: 'Not by call, not by WhatsApp, not by email. If someone does, it isn\'t us.',
          ),
          const SizedBox(height: 24),
          // s54's own explanatory line above "Freeze my account" —
          // "Freezing stops all trading and withdrawals until you
          // unfreeze" — is NOT transcribed: freeze_account_screen.dart's
          // real behaviour (POST /users/me/freeze) has no self-service
          // unfreeze at all ("Reversible only by contacting support"), and
          // it also revokes every session immediately, which "until you
          // unfreeze" doesn't convey. Copy corrected to match what freezing
          // actually does, reusing that screen's own accurate wording.
          Text(
            'Freezing blocks new orders and withdrawals and signs you out everywhere, '
            'immediately. Your shares stay yours at the CSCS — nothing is sold. Contact '
            'support to lift it.',
            style: KType.data(color: KColor.ink3),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              KButton(
                label: 'Freeze my account',
                variant: KButtonVariant.destructive,
                fullWidth: true,
                onPressed: () => context.push(Routes.acctFreeze),
              ),
              const SizedBox(height: 10),
              KButton(
                label: 'Log out',
                variant: KButtonVariant.ghost,
                fullWidth: true,
                onPressed: () => _signOut(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet gate in front of "Change passcode": re-enters the same
/// 6-dot passcode entry idiom as onboarding's KPasscodeDots/KKeypad (see
/// onboarding_scaffold.dart) but checks the entry against the locally
/// stored hash via [PasscodeStore.verifyPasscode] instead of advancing a
/// flow. Pops `true` once verified, `false`/null if dismissed.
