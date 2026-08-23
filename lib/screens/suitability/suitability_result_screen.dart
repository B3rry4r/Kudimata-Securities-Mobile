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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your profile'.upper, style: KType.label(color: KColor.ink3)),
          const SizedBox(height: 12),
          const KIllustration('suitability-accepted', role: KIlloRole.banner, tone: KIlloTone.sun),
          const SizedBox(height: 20),
          Text(result.profile, style: KType.title()),
          const SizedBox(height: 8),
          Text(
            result.rationale ??
                'You can change your answers at any time, and your profile '
                    'will update.',
            style: KType.body(color: KColor.ink2),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: KColor.paper, borderRadius: KRadii.cardR, border: Border.all(color: KColor.hairline)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What this unlocks', style: KType.cardTitle()),
                const SizedBox(height: 12),
                _UnlockRow(icon: 'check', color: KColor.gain, label: 'NGX shares and ETFs'),
                const SizedBox(height: 10),
                _UnlockRow(icon: 'check', color: KColor.gain, label: 'NGX-listed ETFs and bonds'),
                const SizedBox(height: 10),
                _UnlockRow(
                  icon: 'alert',
                  color: KColor.ink3,
                  label: 'Only NGX-listed instruments for now — no foreign stocks',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You can retake this any time in Account → Personal info.',
            style: KType.data(color: KColor.ink3),
          ),
          const SizedBox(height: 28),
          KButton(
            label: 'Go to my home',
            // All four legal documents (terms of service, privacy policy,
            // risk disclosure, client agreement) are accepted upfront, right
            // after OTP verification (see terms_and_privacy_screen.dart) —
            // 2026-08-20, "move client agreement to the beginning, let users
            // accept it all in the terms and disclosures". This is now the
            // LAST step of onboarding: complete suitability, sign in, go
            // straight to Home.
            onPressed: () {
              final app = AppScope.read(context);
              app.setSuitabilityComplete(true);
              app.setSignedIn(true);
              context.go(Routes.home);
            },
          ),
          const SizedBox(height: 10),
          KButton(
            label: 'Change an answer',
            variant: KButtonVariant.ghost,
            onPressed: () => context.pop(),
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
        KIcon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: KType.body(color: KColor.ink2))),
      ],
    );
  }
}
