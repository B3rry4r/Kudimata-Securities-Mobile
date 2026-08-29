// One number, one writer.
//
// The KYC step count was reported wrong three separate times. Each fix
// corrected a DIFFERENT renderer of the same fact — first the step screens
// ("of 7"), then the checklist hub, then Home's progress bar — while some
// other surface kept showing the backend's stale KYC_TOTAL_STEPS = 5. The
// third report was Home's banner reading "Complete your KYC — 4/5 done"
// directly above a correct 7-step progress bar.
//
// The old test asserted "of 7" on the step screens, which is exactly why it
// passed through all three reports: it checked the surfaces that were already
// right. So this file guards the two things that actually let it recur.
//
//   flutter test test/kyc_step_count_single_truth_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';

/// The real flow length per the 2026-08-24 canvas re-sequencing: id, liveness,
/// utility bill, CHN, bank & DCS, declarations, next of kin.
const int kRealKycSteps = 7;

void main() {
  test(
    'the KYC gap banner states no step figure of its own',
    () {
      // AppState cannot derive the real count — it is per-item, fetched, and
      // lives in kycProgressSummary(). So the one thing this title must never
      // do is quote a number, because the only number available to it here is
      // the backend total that has been wrong since August.
      final app = AppState()
        ..signedIn = true
        ..passcodeSet = true
        ..apiClient = ApiClient()
        ..kycSubmitted = false;
      app.setKycDraftProgress(4);

      final gap = tradingEligibilityGap(app);
      expect(gap, isNotNull, reason: 'a mid-draft investor should get a KYC gap');

      final copy = '${gap!.title} ${gap.message}';
      expect(
        RegExp(r'\d').hasMatch(copy),
        isFalse,
        reason:
            'The KYC gap banner is quoting a step figure again: "$copy". AppState '
            'has no access to the real per-item count, so any number here can only '
            'come from the backend\'s KYC_TOTAL_STEPS = 5, which has never matched '
            'the real $kRealKycSteps-step flow (BR-9). The count belongs to '
            'kycProgressSummary(), rendered by _VerifyBanner underneath this title.',
      );
    },
  );

  test(
    'no source file hardcodes a KYC step total other than the real one',
    () {
      // A source sweep rather than a render walk: the render tests kept
      // passing because they looked at screens that were already correct. This
      // catches a FOURTH renderer the day it is written, wherever it is.
      final offenders = <String>[];
      final ratio = RegExp(r'''(\d+)\s*(?:of|/)\s*(\d+)\s*(?:steps?|done)''', caseSensitive: false);

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final code = line.trimLeft();
          if (code.startsWith('//') || code.startsWith('///') || code.startsWith('*')) continue;
          for (final m in ratio.allMatches(line)) {
            final total = int.tryParse(m.group(2)!);
            if (total == null || total > 12) continue;
            if (total != kRealKycSteps) {
              offenders.add('${entity.path}:${i + 1}  ${line.trim()}');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'A KYC step total that is not $kRealKycSteps is hardcoded in live code:\n'
            '${offenders.join('\n')}',
      );
    },
  );
}
