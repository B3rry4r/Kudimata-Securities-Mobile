// 02 · Welcome slider — the illustrated pre-account flow a first-time
// investor sees before Sign up / Log in. NEW SCREEN (2026-08-22 "Soft
// Landing" redesign, docs/redesign/screen-specs.md screen 02) — no prior
// equivalent existed in this app (Splash routed straight to Sign up/Log in).
// Wired at Routes.welcome (app_router.dart); splash_screen.dart routes here
// for any first-time investor (passcodeSet == false) instead of straight to
// sign-up/log-in.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class _Slide {
  const _Slide(this.illustration, this.title, this.body);
  final String illustration;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    'onboarding-welcome',
    'Investing, explained as you go',
    "Buy shares in MTN, Dangote and 140 other companies on the Nigerian Exchange from ₦5,000. We explain every term the first time you meet it.",
  ),
  _Slide(
    'onboarding-explore',
    'Follow what you own',
    'Real-time prices, plain-English explanations, and a portfolio view built for a first-time investor.',
  ),
  _Slide(
    'onboarding-investing',
    'Verified once, invested for good',
    'A phased verification gets you a real NGX trading account — then buying and selling takes seconds.',
  ),
];

class WelcomeSliderScreen extends StatefulWidget {
  const WelcomeSliderScreen({super.key});

  @override
  State<WelcomeSliderScreen> createState() => _WelcomeSliderScreenState();
}

class _WelcomeSliderScreenState extends State<WelcomeSliderScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: KWordmark(size: 20)),
                  // English/Pidgin switch temporarily hidden (2026-08-24,
                  // direct product instruction) — no real Pidgin
                  // translation exists anywhere in the app yet.
                  // KLanguageSwitch(
                  //   value: _lang,
                  //   onChanged: (v) => setState(() => _lang = v),
                  // ),
                ],
              ),
              const SizedBox(height: 20),
              // The tinted card FRAME and its dot row are built ONCE here
              // and stay stationary — only the PageView inside it (the
              // illustration/title/body) swipes. See
              // KOnboardingSlideFrame/KOnboardingSlideContent's doc
              // comments (lib/widgets/mobile.dart) for why this is split
              // this way, not one widget per PageView page.
              Expanded(
                child: KOnboardingSlideFrame(
                  index: _index,
                  count: _slides.length,
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      final s = _slides[i];
                      return KOnboardingSlideContent(
                        illustrationName: s.illustration,
                        title: s.title,
                        message: s.body,
                      );
                    },
                  ),
                ),
              ),
              Column(
                children: [
                  KButton(
                    label: 'Get started',
                    size: KButtonSize.lg,
                    fullWidth: true,
                    onPressed: () => context.go(Routes.signup),
                  ),
                  const SizedBox(height: KSpace.s12),
                  KButton(
                    label: 'I already have an account',
                    variant: KButtonVariant.ghost,
                    size: KButtonSize.lg,
                    fullWidth: true,
                    onPressed: () => context.go(Routes.login),
                  ),
                ],
              ),
              const SizedBox(height: KSpace.s24),
            ],
          ),
        ),
      ),
    );
  }
}
