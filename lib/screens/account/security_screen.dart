// Stage 9 — Security (pushed). Change passcode row + biometric KSwitch.
// Biometric reflects AppState.biometricEnabled (client-local, unchanged);
// the row itself is hidden on web (kIsWeb) since there's no local_auth
// backing store there — same reasoning as biometric_screen.dart being
// skipped in the web onboarding flow (confirm_passcode_screen.dart).
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
import 'package:kudimata_invest/data/api/passcode_store.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/onboarding/onboarding_scaffold.dart';
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
      builder: (_) => _ConfirmCurrentPasscodeSheet(store: _passcodeStore),
    );
    if (!mounted || confirmed != true) return;
    context.push(Routes.createPasscode, extra: true);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return KAccountSubScaffold(
      title: 'Security',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KAccountCard(
            children: [
              KAccountRow(
                icon: 'card',
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
              if (!kIsWeb)
                KAccountRow(
                  icon: 'fingerprint',
                  // screen-specs.md spec 50 literally says "Face ID" — kept
                  // as the cross-platform "Biometric unlock" instead
                  // (2026-08-23 exactness pass: deliberate deviation, not an
                  // oversight). "Face ID" is an Apple-specific term; this
                  // toggle also drives Android fingerprint/face unlock, so
                  // the mockup's iOS-only copy would be wrong on Android.
                  title: 'Biometric unlock',
                  sub: 'Unlock with your face or fingerprint',
                  crossAlign: CrossAxisAlignment.start,
                  right: KSwitch(
                    checked: app.biometricEnabled,
                    // SEAM: real biometric enrolment plugs in here.
                    onChanged: (v) => app.setBiometric(v),
                  ),
                ),
              // Real, existing behaviour, not a new toggle — the withdraw
              // sheet already always asks for passcode confirmation before
              // money leaves (see wallet_flows.dart's withdraw footnote:
              // "Your passcode confirms this withdrawal."). Shown here as
              // disabled/always-on per spec 50, matching what the app
              // actually does rather than adding an unwired setting.
              KAccountRow(
                icon: 'card',
                title: 'Passcode for withdrawals',
                sub: 'Always ask before money leaves',
                crossAlign: CrossAxisAlignment.start,
                right: const KSwitch(checked: true, disabled: true),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('DEVICES SIGNED IN', style: KType.label()),
          const SizedBox(height: 12),
          // No real device/session feed exists on the backend yet (2026-08-22
          // — see docs/redesign/PLAN.md) — this device's row is genuine
          // (we're looking at it right now); everything else here is a
          // placeholder shape for when that feed lands.
          KAccountCard(
            children: [
              KAccountRow(
                icon: 'card',
                title: 'This device',
                sub: 'Active now',
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
          KButton(
            label: 'Freeze my account',
            variant: KButtonVariant.destructive,
            onPressed: () => context.push(Routes.acctFreeze),
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
class _ConfirmCurrentPasscodeSheet extends StatefulWidget {
  const _ConfirmCurrentPasscodeSheet({required this.store});
  final PasscodeStore store;

  @override
  State<_ConfirmCurrentPasscodeSheet> createState() =>
      _ConfirmCurrentPasscodeSheetState();
}

class _ConfirmCurrentPasscodeSheetState
    extends State<_ConfirmCurrentPasscodeSheet> {
  String _code = '';
  bool _error = false;
  bool _checking = false;

  Future<void> _onKey(String k) async {
    if (_checking) return;
    setState(() {
      if (k == 'del') {
        if (_code.isNotEmpty) _code = _code.substring(0, _code.length - 1);
        _error = false;
      } else if (_code.length < 6) {
        _code += k;
        _error = false;
      }
    });
    if (_code.length == 6) {
      setState(() => _checking = true);
      final ok = await widget.store.verifyPasscode(_code);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = true;
          _checking = false;
          _code = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Confirm your current passcode', style: KType.section()),
            const SizedBox(height: 8),
            Text(
              'Enter your current passcode to continue.',
              textAlign: TextAlign.center,
              style: KType.body(color: KColor.ink3),
            ),
            const SizedBox(height: 28),
            KPasscodeDots(filled: _code.length, error: _error),
            const SizedBox(height: 14),
            if (_error)
              Text(
                'Incorrect passcode',
                style: KType.body(color: KColor.loss, w: KWeight.medium),
              ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: KKeypad(onKey: _onKey),
            ),
          ],
        ),
      ),
    );
  }
}
