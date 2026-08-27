// Dormant account (pushed, restyled 2026-08-27 — no artboard in the
// redesign-2026-08 canvas; kept and restyled per RULINGS.md as a real
// account-lifecycle edge state with a live auto-redirect from login).
// Shown when a signed-in investor's account has gone dormant after 12
// months of no sign-in — trading pauses, but holdings/dividends are
// untouched. Ported from the design canvas's
// `StatusView(name="account-suspended", tone="pending")` — reuses the
// existing `assets/illustrations/account-suspended.svg`, which already
// matches the canvas's illustration name exactly.
//
// STALE COMMENT CORRECTED 2026-08-24 (was claiming no dormancy backend
// exists — it does): `AccountStatus` has a real 'dormant' value,
// `UsersService.checkAndApplyDormancy` promotes active -> dormant after 12
// idle months and runs on every login (`AuthService.login`), and
// `log_in_screen.dart`'s `hydrateGatingStateAndRoute` routes here
// automatically when `PersonalInfo.accountStatus == 'dormant'`. "Reactivate
// my account" pushing the real Personal info screen is also a verified
// reactivation path, not a guess — `UsersService.updateProfile` explicitly
// flips a dormant account back to 'active' on a successful update
// ("Reactivate re-confirms personal details", matching the canvas's own
// note exactly). Nothing left to flag here — this screen is fully real.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'close_account_screen.dart';

class DormantAccountScreen extends StatefulWidget {
  const DormantAccountScreen({super.key});

  @override
  State<DormantAccountScreen> createState() => _DormantAccountScreenState();
}

class _DormantAccountScreenState extends State<DormantAccountScreen> {
  late final _repo = HoldingsRepository(AppScope.read(context).apiClient);
  late final Future<PortfolioSummary> _future = _repo.summary();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
          child: Column(
            children: [
              Expanded(
                // The StatusView+card center in the available flex:1 space
                // above a fixed-bottom button block, via a scrollable
                // min-height container rather than a bare Center
                // instead of a bare Center, so short viewports scroll
                // instead of RenderFlex-overflowing (real bug this test
                // caught; content still centers normally once there's room).
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: FutureBuilder<PortfolioSummary>(
                          future: _future,
                          builder: (context, snapshot) {
                            // A failed/loading holdings fetch never blocks
                            // this screen from rendering — it's a state
                            // screen with a real primary action, not a data
                            // screen — it just shows a dash where the
                            // figure would be.
                            final holdingsValue = snapshot.connectionState ==
                                        ConnectionState.done &&
                                    !snapshot.hasError
                                ? snapshot.data!.totalValue
                                : '—';
                            return KStatusView(
                              tone: KStatusTone.pending,
                              illustrationName: 'account-suspended',
                              title: 'Your account is dormant',
                              message:
                                  "You haven't signed in for 12 months, so trading is paused. "
                                  'Your shares are untouched at the CSCS and your dividends '
                                  'kept arriving.',
                              extra: KCard(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    KKeyValueRow(
                                        label: 'Your holdings',
                                        value: holdingsValue,
                                        first: true),
                                    const KKeyValueRow(
                                        label: 'To reactivate', value: 'Confirm your details'),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 26, top: 16),
                child: Column(
                  children: [
                    KButton(
                      label: 'Reactivate my account',
                      onPressed: () => context.push(Routes.acctPersonal),
                    ),
                    const SizedBox(height: 10),
                    KButton(
                      label: 'Close it instead',
                      variant: KButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const CloseAccountScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
