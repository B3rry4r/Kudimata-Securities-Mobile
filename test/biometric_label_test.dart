// Regression guard for a live product complaint: "face id is generic please
// finger print if android face id if iOS" — every biometric-copy site used
// to hardcode "Face ID" regardless of platform, which names an Apple-only
// feature and was simply wrong on Android. BiometricLabel.fromTypes is the
// one place that mapping lives now (security_screen.dart, biometric_screen.dart
// both read through it) — these tests pin it directly, since it's a pure
// function and doesn't need a platform channel or a pumped widget.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:kudimata_invest/widgets/biometric_label.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BiometricLabel.fromTypes', () {
    test('empty list resolves to the neutral fallback', () {
      expect(BiometricLabel.fromTypes(const []), BiometricLabel.neutral);
    });

    test('strong/weak-only (no specific kind) resolves to neutral, not a guess', () {
      // Real shape on some Android devices: hardware is enrolled but
      // local_auth won't say which kind. Guessing "fingerprint" here could
      // be wrong (it might be face-only), so this must stay neutral.
      expect(BiometricLabel.fromTypes(const [BiometricType.strong]), BiometricLabel.neutral);
      expect(BiometricLabel.fromTypes(const [BiometricType.weak]), BiometricLabel.neutral);
    });

    test('never returns the Apple-only term "Face ID" on a non-iOS test host', () {
      // This test binary runs on the VM/web test platform, never iOS, so
      // Platform.isIOS is false (or unavailable on web) for every case
      // below — exactly the Android-shaped branch the product owner's
      // complaint was about.
      for (final types in [
        [BiometricType.face],
        [BiometricType.fingerprint],
        [BiometricType.iris],
        [BiometricType.face, BiometricType.fingerprint],
      ]) {
        final label = BiometricLabel.fromTypes(types);
        expect(label, isNot(contains('Face ID')), reason: 'types=$types produced "$label"');
      }
    });

    test('a face-capable, non-iOS device gets "face unlock", not "Face ID"', () {
      if (kIsWeb) return; // Platform.isIOS is unavailable on the web test target.
      expect(BiometricLabel.fromTypes(const [BiometricType.face]), 'face unlock');
    });

    test('a fingerprint-capable, non-iOS device gets "fingerprint unlock"', () {
      if (kIsWeb) return;
      expect(BiometricLabel.fromTypes(const [BiometricType.fingerprint]), 'fingerprint unlock');
    });

    test('an iris-capable, non-iOS device gets "iris unlock"', () {
      if (kIsWeb) return;
      expect(BiometricLabel.fromTypes(const [BiometricType.iris]), 'iris unlock');
    });

    test('resolve() never throws and falls back to neutral without a platform implementation', () async {
      // Same fail-closed posture as BiometricAuth: the test host has no
      // local_auth platform channel wired up, so this exercises the catch
      // path exactly as a real plugin fault or missing hardware would.
      await expectLater(BiometricLabel.resolve(), completion(BiometricLabel.neutral));
    });
  });
}
