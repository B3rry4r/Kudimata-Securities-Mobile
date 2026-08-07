// Stage 9 — Security (pushed). Change passcode row + biometric & 2FA KSwitches.
// Biometric reflects AppState.biometricEnabled (client-local, unchanged).
// Two-factor authentication now fires PATCH /auth/step-up-preference via
// AuthRepository.setStepUpAuth — registry.json has no GET endpoint for the
// current AuthSession.stepUpAuthEnabled value, so this screen cannot fetch
// the real preference on load; it initializes to `false` (the backend's
// documented default) and lets the PATCH response reflect server state from
// then on. Mirrors `Security` in settings-screens.jsx.
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
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/api/api_exception.dart';
import 'package:kudimata_securities/data/api/passcode_store.dart';
import 'package:kudimata_securities/data/repositories/auth_repository.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/screens/onboarding/onboarding_scaffold.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'account_widgets.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  late final _authRepo = AuthRepository(AppScope.read(context).apiClient);
  final _passcodeStore = PasscodeStore();

  // No GET /auth/step-up-preference (or equivalent) exists in registry.json
  // to read the investor's current value on screen load, so this starts at
  // the backend's documented default and is corrected by whatever the first
  // PATCH response returns.
  bool _twoFa = false;

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

  /// Optimistic toggle: flips immediately for instant UI feedback, then
  /// fires the real PATCH. On success, reconciles with the server's
  /// authoritative returned value. On failure, reverts and surfaces the
  /// error — mirrors the pattern in watchlist_screen.dart's _removeTicker.
  Future<void> _setTwoFa(bool v) async {
    final previous = _twoFa;
    setState(() => _twoFa = v);
    try {
      final confirmed = await _authRepo.setStepUpAuth(v);
      if (!mounted) return;
      setState(() => _twoFa = confirmed);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _twoFa = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return KAccountSubScaffold(
      title: 'Security',
      child: KAccountCard(
        children: [
          KAccountRow(
            icon: 'card',
            title: 'Change passcode',
            // PasscodeStore (lib/data/api/passcode_store.dart) doesn't track
            // a last-set timestamp, so this stays a plain, honest label
            // rather than a fabricated "Last changed N days ago" — see this
            // file's header note.
            sub: 'Set a new 6-digit passcode',
            right: const KRowChevron(),
            first: true,
            onTap: _changePasscode,
          ),
          KAccountRow(
            icon: 'fingerprint',
            title: 'Biometric unlock',
            sub: 'Unlock with your face or fingerprint',
            crossAlign: CrossAxisAlignment.start,
            right: KSwitch(
              checked: app.biometricEnabled,
              // SEAM: real biometric enrolment plugs in here.
              onChanged: (v) => app.setBiometric(v),
            ),
          ),
          KAccountRow(
            icon: 'eye',
            title: 'Two-factor authentication',
            sub: 'Extra check at sign-in',
            crossAlign: CrossAxisAlignment.start,
            right: KSwitch(
              checked: _twoFa,
              onChanged: (v) => _setTwoFa(v),
            ),
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
