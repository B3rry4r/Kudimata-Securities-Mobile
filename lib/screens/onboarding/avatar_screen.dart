// Artboard `s06b` (+ dark `s06bd`) in `01 Getting In.dc.html` — pick your
// avatar. NEW screen (2026-08-24, direct product instruction: "users should
// have the option to choose [an avatar] at a strategic point when coming
// onboard... then it is used everywhere... and those who don't select gets
// only their name text").
//
// Reached the same way personal_details_screen.dart is — from
// kyc_intro.dart's `_start()`, right after personal details are confirmed
// and before KYC actually begins — NOT forced between login and Home
// (personal_details_screen.dart's own header comment documents why that
// blocking-before-Home shape was already tried and reverted: "a few more
// details should be part of the KYC and not a separate step after login").
// Same reasoning applies here: this is offered at the one point an investor
// has already signaled intent to go further (starting verification), not a
// forced gate on every fresh sign-up. `s06b` itself draws the back arrow
// returning to `s06` (Face ID) since in the canvas's own linear flow this
// sits right after it — this app's real flow reaches this screen via
// `context.go` from `onboarding/personal`, so "back" returns there instead,
// the nearest real equivalent of "the step before this one".
//
// Entirely optional — both "Skip" (top-right) and "Use this avatar" (with
// nothing chosen) proceed to KYC without saving anything; only choosing a
// tile and continuing calls updateProfile. `s06b` itself shows its first
// tile pre-selected purely to demonstrate the selected-tile styling in the
// static mock — defaulting a fresh signup to an avatar they never tapped
// would contradict the "only those who select get one" product direction
// above, so this screen starts with nothing chosen.
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

  void _skip() => context.go(Routes.kycIntro);

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
    context.go(Routes.kycIntro);
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
                    onPressed: () => context.go(Routes.onboardingPersonal),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? KColor.indicator : Colors.transparent,
            width: 2,
          ),
          color: selected ? KColor.indicatorTint : Colors.transparent,
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
