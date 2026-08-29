// Cross-platform biometric wording — direct product instruction: "face id is
// generic please finger print if android face id if iOS". Before this file,
// every user-visible mention of biometrics hardcoded the word "Face ID",
// which names an Apple-only feature and is simply wrong on the Android
// devices that make up most of this app's market (NGX retail investors).
//
// The mapping is NOT a bare `Platform.isIOS` branch: a fingerprint-only
// iPhone SE and a face-unlock Android both exist. `local_auth`'s own
// `getAvailableBiometrics()` says what THIS device actually has enrolled;
// platform only breaks the naming tie for the same underlying sensor type
// (iOS calls a fingerprint sensor "Touch ID", Android just calls it
// "fingerprint").
//
// Every screen that names the biometric feature reads through here —
// security_screen.dart's toggle description and biometric_screen.dart's
// enable-prompt copy/button/caption. Never re-derive or hardcode this
// mapping a second time; that duplication is exactly the pattern that let
// three earlier defects in this app drift out of sync across files.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

class BiometricLabel {
  BiometricLabel._();

  /// Used when nothing more specific is known: web (`local_auth` has no web
  /// implementation at all — see biometric_auth.dart), a plugin failure, or
  /// a device that reports biometrics without saying what kind (Android's
  /// `strong`/`weak` classes with no more specific type attached).
  static const String neutral = 'biometric unlock';

  /// Queries this device directly. Never throws — every failure mode
  /// resolves to [neutral], the same fail-safe posture BiometricAuth itself
  /// takes for the actual authentication check.
  static Future<String> resolve() async {
    if (kIsWeb) return neutral;
    try {
      final types = await LocalAuthentication().getAvailableBiometrics();
      return fromTypes(types);
    } catch (_) {
      return neutral;
    }
  }

  /// Pure mapping from what `local_auth` reports (plus platform, for
  /// wording only) to display copy. Split out from [resolve] so it is
  /// cheaply unit-testable without a platform channel.
  ///
  /// Every returned phrase is written to read correctly both as a button
  /// verb ("Turn on $label") and inline ("Use $label instead of typing your
  /// passcode") — sentence case, no trailing "unlock" duplicated by a
  /// caller that already says "unlock" itself.
  static String fromTypes(List<BiometricType> types) {
    final isIOS = !kIsWeb && Platform.isIOS;
    if (isIOS) {
      if (types.contains(BiometricType.face)) return 'Face ID';
      if (types.contains(BiometricType.fingerprint)) return 'Touch ID';
      return neutral;
    }
    // Android (and any other non-iOS platform local_auth supports): never
    // "Face ID" — an Apple-specific term — regardless of which biometric is
    // actually enrolled.
    if (types.contains(BiometricType.fingerprint)) return 'fingerprint unlock';
    if (types.contains(BiometricType.face)) return 'face unlock';
    if (types.contains(BiometricType.iris)) return 'iris unlock';
    return neutral;
  }
}
