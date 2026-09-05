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
import 'package:kudimata_invest/screens/kyc/_kyc_chrome.dart' show kKycTotalSteps;

/// The real flow length: BVN & NIN, CHN, documents (ID + utility bill),
/// selfie, bank & DCS, source of funds, declarations, next of kin.
///
/// Went 7 -> 8 on 2026-09-04 when the Nigerian SEC's No Objection condition 2
/// added a dedicated Source of Funds step to the onboarding questionnaire.
///
/// This literal is DELIBERATELY independent of [kKycTotalSteps] — it is the
/// test's own idea of the truth, and the first assertion below is that the two
/// agree. A test that imported the constant and compared it to itself would
/// pass no matter what the app shipped.
const int kRealKycSteps = 8;

void main() {
  test(
    'the app has exactly ONE definition of the step count, and it is right',
    () {
      // kKycTotalSteps (lib/screens/kyc/_kyc_chrome.dart) is the single
      // definition every step screen, the progress strip and the checklist
      // hub now derive from. Before 2026-09-04 there was no such constant:
      // bvn_nin.dart held a private one, eight screens re-spelled it as a
      // `7` literal, and KycStepProgress carried a stale `total = 4` default
      // waiting for someone to rely on it.
      expect(
        kKycTotalSteps,
        kRealKycSteps,
        reason: 'kKycTotalSteps ($kKycTotalSteps) disagrees with the real flow '
            'length ($kRealKycSteps). Whichever is wrong, the app is now telling '
            'investors a number that does not match the steps they walk.',
      );
    },
  );

  test(
    'the checklist hub builds exactly that many steps',
    () {
      // The hub's list IS the flow — kycProgressSummary() reports
      // "N of steps.length done" straight off it, and nextKycStepRoute()
      // walks it. If the constant says 8 and the hub builds 7, the progress
      // strip and the checklist disagree about the same fact, which is
      // precisely the shape of all three previous reports.
      final source = File('lib/screens/kyc/kyc_checklist_screen.dart').readAsStringSync();
      final built = RegExp(r'_ChecklistStep\(\s*\n\s*title:').allMatches(source).length;
      expect(
        built,
        kRealKycSteps,
        reason: 'kyc_checklist_screen.dart builds $built checklist steps, but the '
            'flow has $kRealKycSteps. The hub, the "N of M done" figure and the '
            'progress strip all read from this list.',
      );
    },
  );

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
      // Two shapes, not one. The original regex only caught "N of M steps" /
      // "N/M done" — it never caught the step screens' own
      // "Verification · 5 of 7" labels or a `total: 7` on KycStepProgress,
      // which is how eight screens carried a hardcoded total right past this
      // file for weeks. Both are swept now.
      final ratio = RegExp(
        r'''(\d+)\s*(?:of|/)\s*(\d+)\s*(?:steps?|done)|[Vv]erification\s*[·.-]\s*(\d+)\s+of\s+(\d+)|KycStepProgress\([^)]*\btotal:\s*(\d+)''',
      );

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final code = line.trimLeft();
          if (code.startsWith('//') || code.startsWith('///') || code.startsWith('*')) continue;
          for (final m in ratio.allMatches(line)) {
            // Whichever alternative matched — "N of M steps", a
            // "Verification · N of M" label, or a literal
            // KycStepProgress(total: M).
            final raw = m.group(2) ?? m.group(4) ?? m.group(5);
            final total = raw == null ? null : int.tryParse(raw);
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
