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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KBalancePanel(
          label: 'Your investor profile',
          balance: result.profile,
          chart: Text(
            "We may flag products that don't match this profile.",
            style: KType.body(color: KColor.featureInk2),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          result.rationale ??
              'You can change your answers at any time, and your profile '
                  'will update.',
          style: KType.body(color: KColor.ink2),
        ),
        const Spacer(),
        KButton(
          label: 'Continue',
          // Terms of service / privacy policy are accepted earlier, right
          // after OTP verification (see terms_of_service_screen.dart) —
          // from here suitability hands off straight to the two
          // investment-specific documents: risk disclosure -> client
          // agreement.
          onPressed: () => context.go(Routes.riskDisclosure),
        ),
      ],
    );
  }
}
