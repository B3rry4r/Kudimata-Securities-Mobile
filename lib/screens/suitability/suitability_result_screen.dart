// Suitability — completion screen. Per R-2 (docs/redesign/DECISIONS.md), this
// screen does not announce the computed profile; it confirms the assessment
// is done and sends the investor on to the legal documents screen, which
// includes the statutory Risk Disclosure and is where the categorisation is
// legally required to appear. No purple donut. Ported from risk-screens.jsx
// (SuitabilityResult).
//
// 2026-08-29 (DECISIONS.md's R-8a superseded note): this used to `push`
// Routes.riskDisclaimer, a standalone scroll-gated screen, with a
// RiskDisclaimerArgs `extra` carrying the just-computed profile (R-2 meant
// it was never actually rendered there either). Risk disclosure is back in
// the legal-documents list now (terms_and_privacy_screen.dart), so this
// screen just `go`es straight to Routes.termsOfService — no args to carry,
// no risk-disclaimer hop in between.
//
// GET /suitability-result/me (SuitabilityRepository.me, see
// lib/data/repositories/suitability_repository.dart) supplies the real
// computed profile — replaces the previous hardcoded "Balanced" literal
// (.pipeline/fragments/suitability-result.json STUB-suitability-result-1).
// The explanatory paragraph below the panel is this screen's one slot for
// descriptive text, so it's fed from the backend's `rationale` (nullable —
// falls back to a neutral line if the backend omits it) instead of the old
// profile-specific hardcoded copy.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/data/repositories/suitability_repository.dart';

class SuitabilityResultScreen extends StatefulWidget {
  const SuitabilityResultScreen({super.key});

  @override
  State<SuitabilityResultScreen> createState() => _SuitabilityResultScreenState();
}

class _SuitabilityResultScreenState extends State<SuitabilityResultScreen> {
  late final _repo = SuitabilityRepository(AppScope.read(context).apiClient);
  late Future<SuitabilityResult> _future = _repo.me();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: FutureBuilder<SuitabilityResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const KLoadingView();
            }
            if (snapshot.hasError) {
              return KErrorView(
                onPrimary: () => setState(() => _future = _repo.me()),
              );
            }
            return _SuitabilityResultBody(result: snapshot.data!);
          },
        ),
      ),
    );
  }
}

class _SuitabilityResultBody extends StatelessWidget {
  const _SuitabilityResultBody({required this.result});
  final SuitabilityResult result;

  @override
  Widget build(BuildContext context) {
    // 2026-08-22 "Soft Landing" — screen-specs.md screen 28: illustration on
    // a SUN plate (not the default grape) signals a positive milestone,
    // the one screen in this flow that breaks from the grape-plate
    // convention.
    //
    // Structure/spacing ported 1:1 from the canvas (#s28), which is TWO
    // stacked sections, not one uniformly-padded column: the illustration
    // sits in its own "16px 20px 0" banner slot ABOVE everything else (this
    // used to render AFTER the "Your profile" label, i.e. in the wrong
    // order), then a second "20px 20px 0" section holds the profile
    // label/title/description, the unlock card and the retake note
    // (column gap:16 between those three), then the two buttons in their
    // own "20px 20px 30px" footer (column gap:12).
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: KIllustration('suitability-accepted', role: KIlloRole.banner, tone: KIlloTone.sun),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // This is a completion screen, not a second announcement of
                // the categorisation. 2026-08-24: it used to also announce
                // the computed profile ("YOUR PROFILE / Conservative" +
                // rationale) and carry a "What this unlocks" card whose
                // second row read "Only Nigerian shares for now — no foreign
                // stocks". Both were removed on direct product instruction:
                // the profile announcement conflicted with R-2, and the
                // unlock card framed the whole product as a limitation at
                // the exact moment the investor finished onboarding. Naming
                // the profile twice in a row was also redundant — the
                // statutory Risk Disclosure, one of the documents on the
                // very next screen, is where the categorisation legally has
                // to appear (still true; it just no longer needs a
                // route-`extra` to get there — see file header).
                Text('Assessment complete', style: KType.title()),
                const SizedBox(height: 6),
                Text(
                  'Thanks — that helps us keep what you see here suited to you. '
                  "There's one short notice to read, then you're ready to invest.",
                  style: KType.body(color: KColor.ink2),
                ),
                const SizedBox(height: 16),
                Text(
                  // U+2192 (→) isn't in the bundled Nunito Sans font and
                  // there's no fontFamilyFallback configured, so it
                  // rendered as a tofu box on every device, not just in
                  // test screenshots (confirmed via fontTools:
                  // NunitoSans-Regular.ttf's cmap has no 0x2192). U+203A
                  // (›) is covered and reads the same way.
                  // Breadcrumb must name the row as the Account hub labels it. The hub
// renamed to s58's 'Personal details' on 2026-08-29; a breadcrumb
// pointing at a label that no longer exists sends the investor looking
// for a row they will not find.
                  'You can retake this any time in Account › Personal details.',
                  style: KType.data(color: KColor.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            child: Column(
              children: [
                KButton(
                  label: 'Continue',
                  // 2026-08-24: routes onward instead of straight to Home —
                  // per direct product instruction (real SEC compliance
                  // intake, "My observations on KSL papers.docx"): a
                  // statutory notice must appear immediately after
                  // suitability. 2026-08-29 (R-8a superseded, file header):
                  // that notice is one of termsOfService's documents now,
                  // not a standalone screen reached with a route `extra` —
                  // `go`, not `push`, matching this file's own "linear
                  // gated step" convention (routes.dart's header). Sign-in
                  // completion fires inside termsOfService's own accept
                  // action when its documents include risk_disclosure (see
                  // legal_acceptance_screen.dart) — this is still not the
                  // last gated step of onboarding.
                  fullWidth: true,
                  onPressed: () {
                    AppScope.read(context).setSuitabilityComplete(true);
                    context.go(Routes.termsOfService);
                  },
                ),
                const SizedBox(height: 12),
                KButton(
                  label: 'Change an answer',
                  variant: KButtonVariant.ghost,
                  fullWidth: true,
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

