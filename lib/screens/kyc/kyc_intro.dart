// KYC 1 — intro. What we'll verify (identity / document / selfie) and a single
// purple "Start" primary that enters the linear flow. Mirrors KycIntro.
//
// RESUME (2026-08-20, phased-KYC directive: "so users who goes out and
// comes back don't have to start all over"): "Start" first checks
// GET /kyc-submissions/draft. A draft in progress routes straight to
// whichever step it's at (see _routeForStep) instead of always restarting
// at step 1 — the same check home_screen.dart's "Complete your KYC — N/5
// done" prompt already makes via AppState.kycDraftStep, but re-checked
// live here rather than trusting a value that may be stale by the time the
// investor actually taps Start.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class _KycRow {
  const _KycRow(this.eyebrow, this.line, this.icon);
  final String eyebrow;
  final String line;
  final String icon; // KIcon name
}

class KycIntroScreen extends StatefulWidget {
  const KycIntroScreen({super.key});

  @override
  State<KycIntroScreen> createState() => _KycIntroScreenState();
}

class _KycIntroScreenState extends State<KycIntroScreen> {
  static const _rows = [
    _KycRow('IDENTITY', 'Your BVN — Bank Verification Number.', 'profile'),
    _KycRow('DOCUMENT', 'A government ID — NIN, passport or licence.', 'card'),
    // Liveness selfie — fingerprint/profile motif (no camera icon in the set).
    _KycRow('SELFIE', 'A quick liveness check to match your face.', 'fingerprint'),
  ];

  bool _busy = false;

  /// Which route a given currentStep (2-5, per KycRepository.getDraft's doc
  /// comment — a draft always exists past step 1) resumes into. Step 1 has
  /// no entry here since a draft's currentStep is never reported as 1.
  static const _stepRoutes = {
    2: Routes.kycId,
    3: Routes.kycLiveness,
    4: Routes.kycUtilityBill,
    5: Routes.kycNextOfKin,
  };

  Future<void> _start() async {
    setState(() => _busy = true);
    final app = AppScope.read(context);
    try {
      final draft = await KycRepository(app.apiClient).getDraft();
      if (!mounted) return;
      if (draft != null && draft.id != null) {
        app.kycForm.setDraftId(draft.id!);
        context.go(_stepRoutes[draft.currentStep] ?? Routes.kycBvn);
        return;
      }
    } on ApiException {
      // Best-effort — if the resume check itself fails, fall through to a
      // normal fresh start rather than stranding the investor on this
      // screen. Step 1 re-checks/re-creates a draft regardless.
    }
    if (!mounted) return;
    setState(() => _busy = false);
    context.go(Routes.kycBvn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              KSpace.gutter, 24, KSpace.gutter, KSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const KScreenHead(title: "Let's verify you"),
              const SizedBox(height: 28),
              KCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < _rows.length; i++)
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: i == 0
                                ? BorderSide.none
                                : BorderSide(color: KColor.hairline, width: 1),
                          ),
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: KColor.bg,
                                shape: BoxShape.circle,
                                border: Border.all(color: KColor.hairline, width: 1),
                              ),
                              child: KIcon(_rows[i].icon, size: 20, color: KColor.ink),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  KEyebrow(_rows[i].eyebrow),
                                  const SizedBox(height: 4),
                                  Text(_rows[i].line, style: KType.body(color: KColor.ink)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Required by our regulator before you can invest.',
                style: KType.body(color: KColor.ink3),
              ),
              const Spacer(),
              KButton(
                label: 'Start',
                iconRight: 'arrowUpRight',
                loading: _busy,
                onPressed: _busy ? null : _start,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
