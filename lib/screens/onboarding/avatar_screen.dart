// Artboard `s06b` (+ dark `s06bd`) in `01 Getting In.dc.html` — pick your
// avatar. NEW screen (2026-08-24, direct product instruction: "users should
// have the option to choose [an avatar] at a strategic point when coming
// onboard... then it is used everywhere... and those who don't select gets
// only their name text").
//
// R-44 (DECISIONS.md, 2026-08-29): reached from biometric_screen.dart's two
// exits (`_proceed()`, after "Turn on <biometric>"/"Maybe later"), in
// ONBOARDING — never from KYC. Owner's words: "avatar should never be on
// KYC — onboarding." This screen used to be reached from
// kyc_intro.dart's `_start()`, the same way personal_details_screen.dart
// still claims to be — that entry point stopped existing when kyc_intro.dart
// was rewritten to route straight to Routes.kycChecklist/Routes.kycBvn
// (2026-08-29 A-1 audit fix), and nothing else called `context.go`/`push`
// on this route afterwards: it sat fully built, registered, and completely
// unreachable until the owner noticed it was gone. R-44 records the fix and
// the rule ("a screen losing its entry point is not the same as a screen
// being cut") so it does not happen again silently. `s06b` itself draws the
// back arrow returning to `s06` (Face ID) since in the canvas's own linear
// flow this sits right after it — this app's real flow reaches this screen
// via `context.go` from `Routes.biometric`, so "back" returns there
// instead, the nearest real equivalent of "the step before this one".
//
// Both exits go straight to Routes.home. They used to go to
// Routes.onboardingNextSteps (X-4, SHARED-CHANGES.md 2026-08-27) —
// "s07"/whats_next_screen.dart's "Your account is ready" checklist, which
// sat between avatar selection and KYC start in the canvas's own linear
// flow. Removed 2026-08-31 per direct product-owner instruction ("remove
// the screen that says start... look around, please user should just go to
// the home page after onboarding") — see DECISIONS.md's superseding note
// under R-33 (the ruling that originally built s07) for the full record.
// whats_next_screen.dart, its route, and the onboardingNextSteps constant
// are all deleted; nothing else pointed at that route.
//
// Entirely optional (still true under R-44 — "choosing one is optional...
// the screen offers a choice, it does not gate Home") — both "Skip"
// (top-right) and "Use this avatar" (with nothing chosen) proceed onward
// without saving anything, and whoever skips gets their name rendered as an
// initial-letter avatar instead (the null-avatarKey fallback home_screen.dart
// / account_screen.dart / log_in_screen.dart each already draw — this
// screen has no fallback of its own to build; it only ever writes
// `avatarKey` when the investor actually picks a tile). Only choosing a
// tile and continuing calls updateProfile. `s06b`
// itself shows its first tile pre-selected purely to demonstrate the
// selected-tile styling in the static mock — defaulting a fresh signup to
// an avatar they never tapped would contradict the "only those who select
// get one" product direction above, so this screen starts with nothing
// chosen.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class OnboardingAvatarScreen extends StatefulWidget {
  const OnboardingAvatarScreen({super.key});

  @override
  State<OnboardingAvatarScreen> createState() => _OnboardingAvatarScreenState();
}

class _OnboardingAvatarScreenState extends State<OnboardingAvatarScreen> {
  String? _chosen;
  bool _busy = false;

  void _skip() => context.go(Routes.home);

  Future<void> _continue() async {
    if (_chosen == null) {
      _skip();
      return;
    }
    setState(() => _busy = true);
    final userRepo = UserRepository(AppScope.read(context).apiClient);
    try {
      await userRepo.updateProfile(avatarKey: _chosen);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showErrorSheet(context, message: e.message);
      return;
    }
    if (!mounted) return;
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  KIconButton(
                    icon: 'back',
                    semanticLabel: 'Back',
                    onPressed: () => context.go(Routes.biometric),
                  ),
                  GestureDetector(
                    onTap: _skip,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Text('Skip', style: KType.data(color: KColor.ink3)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(KSpace.gutter, 12, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(
                      title: 'Pick your avatar',
                      body: 'Just for your profile. You can change it any time.',
                    ),
                    const SizedBox(height: 22),
                    GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1,
                      // `UserRepository.avatarKeys` — real, selectable
                      // avatars. `s06b` draws a 9th tile ('guide'), which is
                      // the app's mascot glyph (KAvatar.guide), not one of
                      // the interchangeable identity avatars
                      // UserRepository.avatarKeys lists — see this file's
                      // SHARED-CHANGE REQUEST in the delivery report.
                      children: [
                        for (final key in UserRepository.avatarKeys)
                          _AvatarTile(
                            avatarKey: key,
                            selected: _chosen == key,
                            onTap: () => setState(() => _chosen = key),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
              child: KButton(
                label: 'Use this avatar',
                loading: _busy,
                onPressed: _busy ? null : _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({required this.avatarKey, required this.selected, required this.onTap});
  final String avatarKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 2026-08-31: KAvatar now draws its own literal-white plate for these
    // persona characters (KIllo.platePaper — see its doc comment), so this
    // tile no longer needs to supply a background of its own. The
    // selection state is an OUTER ring instead of the old inset tint fill
    // — matching kudimata.app's own avatar-pick tile (assessment.module.css:
    // "the selection ring is drawn as an OUTER ring ... so it sits outside
    // the art instead of hiding behind it").
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KRadii.card + 4),
          border: Border.all(
            color: selected ? KColor.indicator : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(child: KAvatar(avatarKey: avatarKey, size: 72)),
      ),
    );
  }
}

void _showErrorSheet(BuildContext context, {required String message}) {
  showKSheet<void>(
    context,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KStatusView(
        tone: KStatusTone.error,
        title: "Couldn't save your avatar",
        message: message,
        primary: 'Try again',
        onPrimary: () => Navigator.of(context).pop(),
      ),
    ),
  );
}
