// Real biometric authentication (2026-08-24).
//
// WHAT WAS WRONG BEFORE THIS FILE EXISTED — this is the single worst
// security defect found in the app to date, so it is written down in full:
//
//   log_in_screen.dart's `_unlock({bool viaBiometric})` guarded its ONLY
//   credential check with `if (!viaBiometric)`. So the passcode path
//   verified a salted hash, and the biometric path verified NOTHING — it
//   fell straight through to `repo.me()` and unlocked the account. There
//   was no biometric check to fall through to either: `local_auth` was not
//   a dependency of this project at all, and the Security screen's
//   "Biometric unlock" switch was commented `SEAM: real biometric
//   enrolment plugs in here`, flipping a client-local bool and nothing
//   more.
//
//   Net effect: on any device where that switch had ever been turned on,
//   ANYONE holding the phone could tap the fingerprint key on the lock
//   screen and be inside a funded brokerage account. No face, no
//   fingerprint, no passcode.
//
// This wrapper is the real thing. It is deliberately small and total:
// every failure mode resolves to `false` (deny), never to `true`, so a
// plugin error, an unsupported platform or a user cancel can never be
// mistaken for a successful authentication.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  BiometricAuth._();

  static final LocalAuthentication _auth = LocalAuthentication();

  /// Whether this device can actually perform a biometric check RIGHT NOW —
  /// hardware present, and at least one face/fingerprint enrolled.
  ///
  /// Always false on web: `local_auth` has no web implementation, and this
  /// app is routinely exercised as a web build during testing. Returning
  /// false there means the lock screen simply doesn't offer the affordance,
  /// rather than offering one that cannot work.
  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Runs the system biometric prompt. Returns true ONLY on a genuine
  /// success.
  ///
  /// `biometricOnly: true` deliberately refuses the OS's device-PIN
  /// fallback: this app has its own passcode on the very same screen, and
  /// silently accepting the phone's lock PIN instead would mean "biometric
  /// unlock" sometimes wasn't biometric at all — precisely the class of
  /// confusion that produced the original hole.
  static Future<bool> authenticate({
    String reason = 'Unlock your Kudimata account',
  }) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        sensitiveTransaction: true,
      );
    } on LocalAuthException {
      // Cancelled, locked out, no hardware, no enrolment, or a platform
      // fault. All of them mean "not authenticated".
      return false;
    } catch (_) {
      return false;
    }
  }
}
