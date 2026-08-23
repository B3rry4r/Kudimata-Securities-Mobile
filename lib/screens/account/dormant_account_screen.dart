// Screen 89 — Dormant account (2026-08-23, account-lifecycle/legal cluster).
// Shown when a signed-in investor's account has gone dormant after 12
// months of no sign-in — trading pauses, but holdings/dividends are
// untouched. Ported from the design canvas's
// `StatusView(name="account-suspended", tone="pending")` — reuses the
// existing `assets/illustrations/account-suspended.svg`, which already
// matches the canvas's illustration name exactly.
//
// REAL GAP (flagged per the cluster brief's "flag every real gap honestly"
// rule): there is no dormancy concept anywhere in the backend today.
// `UserRepository`/`PersonalInfo.accountStatus` is the only account-state
// signal that exists (a raw string like 'active'/'suspended' per its own
// doc comment) — no 'dormant' value or 12-month-idle detection is
// documented or implemented anywhere in the repositories this app has.
// This screen is fully built and wired for real DATA (the holdings total
// via `HoldingsRepository.summary()`), but nothing today actually ROUTES an
// investor here automatically on sign-in — that needs a real backend
// dormancy signal plus a router-level check, both outside a per-screen
// wiring agent's scope (and `lib/router/app_router.dart` is explicitly
// off-limits for this cluster).
//
// "Reactivate my account" also has no dedicated backend action (no
// `POST /users/me/reactivate` exists). Per the design canvas's own note —
// "Reactivate re-confirms personal details" — this pushes the existing,
// real Personal info screen (`Routes.acctPersonal`), which is the closest
// working action available; that is a judgment call, not a verified
// reactivation flow, and is called out here rather than invented as a fake
// "reactivated!" success state.
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
                // #s89's own markup centers the StatusView+card in the
                // available flex:1 space above a fixed-bottom button block —
                // preserved here, but via a scrollable min-height container
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
