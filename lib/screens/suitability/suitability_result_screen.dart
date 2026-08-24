// Suitability — risk-profile result. The one ink panel states the investor
// profile; a paragraph explains it; primary Continue advances. No purple donut.
// Ported from risk-screens.jsx (SuitabilityResult).
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
import 'risk_disclaimer_screen.dart' show RiskDisclaimerArgs;
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your profile'.upper, style: KType.label(color: KColor.ink3)),
                    const SizedBox(height: 4),
                    Text(result.profile, style: KType.title()),
                    const SizedBox(height: 6),
                    Text(
                      result.rationale ??
                          'You can change your answers at any time, and your profile '
                              'will update.',
                      style: KType.body(color: KColor.ink2),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: KColor.paper, borderRadius: KRadii.cardR, border: Border.all(color: KColor.hairline)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What this unlocks', style: KType.cardTitle()),
                      const SizedBox(height: 12),
                      // 2026-08-24: dropped "and ETFs" — this product
                      // carries no ETFs at all (Markets is NGX ordinary
                      // shares only, see markets_screen.dart's own header
                      // comment), same "don't promise a product this app
                      // has never offered" reasoning as the row below.
                      _UnlockRow(icon: 'check', color: KColor.gain, label: 'Nigerian shares'),
                      const SizedBox(height: 12),
                      // Canvas #s28's second row literally says "NGX-listed
                      // ETFs and bonds" — dropped here, not ported verbatim:
                      // this product carries NO fixed-income instruments at
                      // all (see lib/data/models.dart's AssetClass doc
                      // comment, "No fixed income — by design"). Repeating
                      // "bonds" would tell an investor they can buy a
                      // product this app has never offered — a product
                      // invariant overriding the canvas's literal copy, per
                      // this codebase's own established rule (see the
                      // referral-terms "never cash" correction elsewhere).
                      _UnlockRow(
                        icon: 'alert',
                        color: KColor.ink3,
                        label: 'Only Nigerian shares for now — no foreign stocks',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  // U+2192 (→) isn't in the bundled Nunito Sans font and
                  // there's no fontFamilyFallback configured, so it
                  // rendered as a tofu box on every device, not just in
                  // test screenshots (confirmed via fontTools:
                  // NunitoSans-Regular.ttf's cmap has no 0x2192). U+203A
                  // (›) is covered and reads the same way.
                  'You can retake this any time in Account › Personal info.',
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
                  // 2026-08-24: routes to the Statutory Risk Disclaimer
                  // instead of straight to Home — restored per direct
                  // product instruction (real SEC compliance intake, "My
                  // observations on KSL papers.docx"): the disclaimer must
                  // appear immediately after suitability and show this
                  // computed profile dynamically. setSignedIn(true) moved
                  // to that screen's own Accept & Proceed action — this is
                  // no longer the last gated step of onboarding.
                  fullWidth: true,
                  onPressed: () {
                    AppScope.read(context).setSuitabilityComplete(true);
                    context.push(
                      Routes.riskDisclaimer,
                      extra: RiskDisclaimerArgs(profile: result.profile),
                    );
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

class _UnlockRow extends StatelessWidget {
  const _UnlockRow({required this.icon, required this.color, required this.label});
  final String icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Canvas: Icon size="16".
        KIcon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: KType.body(color: KColor.ink2))),
      ],
    );
  }
}
