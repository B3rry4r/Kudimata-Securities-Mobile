// Artboard `s07` (+ dark `s07d`) in `01 Getting In.dc.html` — "Your account
// is ready" / three-step checklist. NEW screen per R-33
// (docs/redesign/DECISIONS.md): one of six artboards with no app
// counterpart, built as ordinary flow work rather than waiting on a further
// product ruling.
//
// Where it slots in: the canvas's own linear flow is Face ID (`s06`) ->
// avatar (`s06b`) -> this screen, and its two exits are "Start step 1" ->
// Verification (KYC) and "Look around first" -> Home (canvas's own captions:
// "Start step 1 → Section 2 (Verification)" / "Look around → Section 3
// (Home)"). Both destinations already exist as real routes
// (Routes.kycIntro, Routes.home) and are wired directly below — no shared
// file touched for that part.
//
// What's missing: reaching THIS screen at all. Today avatar_screen.dart's
// `_skip()`/`_continue()` both `context.go(Routes.kycIntro)` directly once
// avatar selection finishes — there is no route constant for this screen, and
// neither `lib/router/**` nor avatar_screen.dart itself belong to this
// screen's own file boundary (SCREEN-AGENT-BRIEF.md rule 5/6). Filed as a
// SHARED-CHANGE REQUEST (docs/redesign/SHARED-CHANGES.md, X-4): add
// `Routes.onboardingNextSteps` (e.g. '/onboarding/next-steps') routed to
// [WhatsNextScreen], and repoint avatar_screen.dart's two
// `Routes.kycIntro` calls at it instead. Until that lands this screen is
// built and correct but unreachable from the live flow — nothing here calls
// a route that doesn't exist, per the brief.
//
// No back arrow: `s07`'s own markup has no back-button row at all (status
// bar, then content starts straight at 34px padding) — this is a one-way
// "here's what's next" screen, not a step to back out of.
//
// No loading/error/empty states: this screen makes no network call and
// renders no fetched data — both buttons are plain navigation. Per R-30/rule
// 4, a state with no way to be entered has no business being drawn as
// decoration; no condition here would put this screen into any of the three.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class WhatsNextScreen extends StatelessWidget {
  const WhatsNextScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 34, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Your account is ready', style: KType.title(color: KColor.ink)),
                    const SizedBox(height: 12),
                    Text(
                      'Three steps before you can buy your first share.',
                      style: KType.body(color: KColor.ink2),
                    ),
                    const SizedBox(height: 28),
                    const _NextStepRow(
                      number: 1,
                      title: 'Verify your identity',
                      subtitle: 'BVN, NIN, ID & a selfie · about 5 minutes',
                    ),
                    const SizedBox(height: 14),
                    const _NextStepRow(
                      number: 2,
                      title: 'Add your bank account',
                      subtitle: 'Where your money comes back to',
                    ),
                    const SizedBox(height: 14),
                    const _NextStepRow(
                      number: 3,
                      title: 'Add money & buy',
                      subtitle: 'From ₦5,000',
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.s40),
              child: Column(
                children: [
                  KButton(
                    label: 'Start step 1',
                    onPressed: () => context.go(Routes.kycIntro),
                  ),
                  const SizedBox(height: 12),
                  KButton(
                    label: 'Look around first',
                    variant: KButtonVariant.secondary,
                    onPressed: () => context.go(Routes.home),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the three-step checklist — numbered badge, title, subtitle.
/// Screen-local per this codebase's small-widget convention (not a
/// candidate for lib/widgets/: nothing else in the app draws a numbered
/// onboarding checklist row).
class _NextStepRow extends StatelessWidget {
  const _NextStepRow({required this.number, required this.title, required this.subtitle});

  final int number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border.all(color: KColor.hairline, width: 1),
        borderRadius: KRadii.cardR,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: KColor.indicatorTint, shape: BoxShape.circle),
            child: Text(
              '$number',
              style: KType.cardTitle(color: KColor.indicator).copyWith(fontSize: 17),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: KType.cardTitle(color: KColor.ink).copyWith(fontSize: 17)),
                const SizedBox(height: 2),
                Text(subtitle, style: KType.body(color: KColor.ink3).copyWith(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
