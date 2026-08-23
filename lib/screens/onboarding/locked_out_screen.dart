// Screen 92 — Locked out (2026-08-23, account-lifecycle/legal cluster).
// Meant to be shown after too many wrong local-passcode attempts on the
// returning-user unlock screen (log_in_screen.dart's `_buildUnlock`).
//
// REAL GAP: there is no failed-attempt counter or lockout timer anywhere in
// this app today. `PasscodeStore` (lib/data/api/passcode_store.dart) only
// exposes setPasscode/verifyPasscode/hasPasscode/belongsTo — no attempt
// count, no lockout timestamp. `log_in_screen.dart`'s `_onKey`/`_unlock`
// just clear the entered digits and show "Incorrect passcode" on every
// wrong attempt; there is no branch that ever reaches a lockout state. This
// screen is built to match the design canvas exactly (illustration,
// tries-used/unlocks-at card, both real actions wired to existing routes)
// and is ready to be shown, but nothing calls it yet — teaching
// `log_in_screen.dart` to count attempts and navigate here after 5 wrong
// tries touches a file outside this cluster's brief (only new files were
// expected here; `lib/router/app_router.dart` — where the route itself
// would be registered — is also explicitly off-limits for this cluster).
// [triesUsed]/[maxTries]/[unlocksAt] are therefore constructor params, not
// fetched from anywhere — a future caller passes the real numbers once a
// counter exists; sensible design-matching defaults render if this is ever
// reached without them.
//
// NAVIGATION NOTE — also worth flagging: "Reset with my email" targets
// `Routes.reset`, matching both the design canvas and this exact button's
// existing wording/target on log_in_screen.dart's own local-unlock screen.
// But `Routes.reset` is in `app_router.dart`'s `preAuthOnly` set, which
// redirects straight to Home whenever `AppState.signedIn` is true — and a
// locally-locked-out investor (this screen's whole premise) still has a
// valid signed-in SESSION, only a locked local passcode. That looks like a
// pre-existing latent bug shared with log_in_screen.dart's own "Forgot your
// password?" button (also reachable only while signed in), not something
// this screen introduces — surfacing it here since it directly affects
// this screen's primary action, for the router-owning agent to weigh in on.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class LockedOutScreen extends StatelessWidget {
  const LockedOutScreen({
    super.key,
    this.triesUsed = 5,
    this.maxTries = 5,
    this.unlocksAt,
  });

  final int triesUsed;
  final int maxTries;

  /// Wall-clock time the lockout lifts. Defaults to "now + 15 minutes" (the
  /// canvas's own stated lockout duration) when not supplied.
  final DateTime? unlocksAt;

  String get _unlocksAtLabel {
    final at = unlocksAt ?? DateTime.now().add(const Duration(minutes: 15));
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

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
                // #s92's own markup centers the StatusView+card in the
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
                        child: KStatusView(
                          tone: KStatusTone.pending,
                          illustrationName: 'timeout',
                          title: 'Too many tries',
                          message:
                              'Your passcode is locked for 15 minutes. Nobody can reach your '
                              'money in the meantime — a withdrawal needs the passcode too.',
                          extra: KCard(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                KKeyValueRow(
                                    label: 'Tries used',
                                    value: '$triesUsed of $maxTries',
                                    first: true),
                                KKeyValueRow(label: 'Unlocks at', value: _unlocksAtLabel),
                              ],
                            ),
                          ),
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
                      label: 'Reset with my email',
                      onPressed: () => context.go(Routes.reset),
                    ),
                    const SizedBox(height: 10),
                    KButton(
                      label: 'Talk to support',
                      variant: KButtonVariant.ghost,
                      onPressed: () => context.push(Routes.acctHelp),
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
