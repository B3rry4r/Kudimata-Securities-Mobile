// Onboarding avatar choice — NEW screen (2026-08-24, direct product
// instruction: "users should have the option to choose [an avatar] at a
// strategic point when coming onboard... then it is used everywhere...
// and those who don't select gets only their name text"). Not part of the
// canvas (avatars weren't a real, user-chosen field when it was drawn).
//
// Reached the same way personal_details_screen.dart is — from
// kyc_intro.dart's `_start()`, right after personal details are confirmed
// and before KYC actually begins — NOT forced between login and Home
// (personal_details_screen.dart's own header comment documents why that
// blocking-before-Home shape was already tried and reverted: "a few more
// details should be part of the KYC and not a separate step after login").
// Same reasoning applies here: this is offered at the one point an investor
// has already signaled intent to go further (starting verification), not a
// forced gate on every fresh sign-up. Entirely optional — "Skip" and
// "Continue" both proceed to KYC; only "Continue" (after picking) or
// tapping an avatar actually saves anything.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import '_pickers.dart';

class OnboardingAvatarScreen extends StatefulWidget {
  const OnboardingAvatarScreen({super.key});

  @override
  State<OnboardingAvatarScreen> createState() => _OnboardingAvatarScreenState();
}

class _OnboardingAvatarScreenState extends State<OnboardingAvatarScreen> {
  String? _chosen;
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    final picked = await showAvatarPicker(context, selected: _chosen);
    if (picked == null) return;
    setState(() => _chosen = picked == 'none' ? null : picked);
  }

  Future<void> _continue() async {
    if (_chosen == null) {
      context.go(Routes.kycIntro);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final userRepo = UserRepository(AppScope.read(context).apiClient);
    try {
      await userRepo.updateProfile(avatarKey: _chosen);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(KSpace.gutter, 18, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(
                      title: 'Choose an avatar',
                      body: 'Pick a character to represent you, or skip and we\'ll just show your name — you can change this anytime from Personal info.',
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: _pick,
                        child: _chosen != null
                            ? KAvatar(avatarKey: _chosen!, size: 96)
                            : Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: KColor.track,
                                  border: Border.all(color: KColor.hairline),
                                ),
                                child: KIcon('plus', size: 28, color: KColor.ink3),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: _pick,
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          _chosen != null ? 'Choose a different one' : 'Choose an avatar',
                          style: KType.data(color: KColor.indicator),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: KType.micro(color: KColor.loss)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
              child: Column(
                children: [
                  KButton(
                    label: _chosen != null ? 'Continue' : 'Skip for now',
                    loading: _busy,
                    onPressed: _busy ? null : _continue,
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
