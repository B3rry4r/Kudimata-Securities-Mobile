// One password rule, and it must be the server's.
//
// Reported: "I get the OTP and enter it with a new password and it fails...
// tried it twice." The password policy (R-43) was applied to the server and to
// the sign-up screen on the same day, and the RESET-PASSWORD screen was missed.
// It validated only `length >= 8`, so `Password1` passed the client and the
// server rejected it for having no special character — and the app showed the
// envelope's summary, "Validation failed", while discarding the `details` entry
// that named the actual rule.
//
// Two guards, because two separate things were wrong:
//   1. every password screen enforces the shared rule, not its own copy
//   2. a VALIDATION_ERROR shows the detail, not the summary
//
//   flutter test test/password_policy_parity_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/password_policy.dart';

void main() {
  group('the shared rule matches the backend', () {
    // These mirror src/common/password-policy.ts. If the backend's rule moves,
    // these fail here rather than in front of an investor.
    test('rejects the exact password that failed in production', () {
      expect(passwordAcceptable('Password1'), isFalse); // no special character
    });
    test('rejects too short, and missing a number', () {
      expect(passwordAcceptable('Pass1!'), isFalse);
      expect(passwordAcceptable('Password!'), isFalse);
    });
    test('accepts 8+ with a number and a special character', () {
      expect(passwordAcceptable('Password1!'), isTrue);
      expect(passwordAcceptable('abcdefg1@'), isTrue);
    });
  });

  test('no password screen carries its own length rule', () {
    // The reset screen's `_newPassword.length >= 8` is exactly what drifted.
    final offenders = <String>[];
    final ownRule = RegExp(r'\.length\s*>=\s*\d+');
    for (final f in Directory('lib/screens').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!line.toLowerCase().contains('password')) continue;
        final code = line.trimLeft();
        if (code.startsWith('//') || code.startsWith('///')) continue;
        if (ownRule.hasMatch(line)) offenders.add('${f.path}:${i + 1}  ${line.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'A password screen is checking length itself instead of using '
            'lib/data/password_policy.dart. That is how the reset screen came '
            'to accept a password the server rejected:\n${offenders.join('\n')}');
  });

  group('a validation error tells the investor what is wrong', () {
    test('prefers the detail over the useless summary', () {
      final e = ApiException(
        code: 'VALIDATION_ERROR',
        message: 'Validation failed',
        statusCode: 400,
        details: const [
          {
            'field': 'newPassword',
            'issue': 'newPassword must be at least 8 characters and include a '
                'number and a special character',
          }
        ],
      );
      expect(e.displayMessage, contains('special character'));
      expect(e.displayMessage, isNot('Validation failed'));
      // Field-prefixed wording reads as a sentence, not a variable name.
      expect(e.displayMessage, startsWith('New password'));
    });

    test('falls back to the summary when there is no usable detail', () {
      final e = ApiException(
        code: 'EMAIL_OTP_MISMATCH',
        message: 'The verification code is incorrect.',
        statusCode: 400,
      );
      expect(e.displayMessage, 'The verification code is incorrect.');
    });
  });
}
