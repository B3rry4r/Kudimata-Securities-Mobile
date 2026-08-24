// Regression guard for the worst security defect found in this app
// (2026-08-24): the lock screen's biometric path verified NOTHING.
//
// `_unlock({bool viaBiometric})` wrapped its only credential check in
// `if (!viaBiometric)`, so tapping the fingerprint key skipped the passcode
// entirely and unlocked a funded brokerage account. `local_auth` was not
// even a dependency, and the "Biometric unlock" switch flipped a local bool
// with a `SEAM: real biometric enrolment plugs in here` comment.
//
// These tests pin the two properties that make the fix safe. They are
// deliberately about BiometricAuth's fail-closed contract rather than about
// driving the lock screen: the real prompt cannot be summoned in a widget
// test, but "every failure path denies" is exactly the property whose
// absence caused the bug.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:kudimata_invest/data/biometric_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BiometricAuth fails closed', () {
    test('isAvailable() returns false when no platform can answer', () async {
      // In the test host there is no local_auth platform implementation, so
      // the plugin call throws. The contract is that this resolves to false
      // (deny) rather than propagating or — catastrophically — defaulting
      // to true.
      await expectLater(BiometricAuth.isAvailable(), completion(isFalse));
    });

    test('authenticate() returns false when no platform can answer', () async {
      // Same contract on the path that actually gates the account. A plugin
      // fault, a cancelled prompt and an unsupported device must all be
      // indistinguishable from "not authenticated".
      await expectLater(BiometricAuth.authenticate(), completion(isFalse));
    });

    test('authenticate() never throws, whatever the platform does', () async {
      // The caller unlocks on `true`. If this could throw past the caller's
      // guard the account would be left in an indeterminate state, so the
      // wrapper swallows everything and denies.
      await expectLater(
        BiometricAuth.authenticate(reason: 'unit test'),
        completes,
      );
    });

    test('both entry points deny on web, where local_auth has no implementation', () async {
      // The app ships a web build (it is how this project is smoke-tested),
      // and local_auth has no web support at all. Both must short-circuit
      // to false rather than offering an affordance that cannot work.
      if (!kIsWeb) return; // meaningful only in the web test target
      expect(await BiometricAuth.isAvailable(), isFalse);
      expect(await BiometricAuth.authenticate(), isFalse);
    });
  });
}
