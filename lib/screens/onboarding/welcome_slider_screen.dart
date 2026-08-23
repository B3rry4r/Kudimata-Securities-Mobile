// 02 · Welcome slider — the illustrated pre-account flow a first-time
// investor sees before Sign up / Log in. NEW SCREEN (2026-08-22 "Soft
// Landing" redesign, docs/redesign/screen-specs.md screen 02) — no prior
// equivalent existed in this app (Splash routed straight to Sign up/Log in).
// NOT YET WIRED into lib/router/routes.dart / app_router.dart — that needs
// a route constant + GoRoute entry (and deciding whether Splash routes here
// first-launch-only, e.g. via a "seen onboarding" local flag) before this
// screen is reachable. Built ready for that wiring.
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
  String _lang = 'en';

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
              const SizedBox(height: KSpace.s12),
              Row(
                children: [
                  const Expanded(child: KWordmark(size: 20)),
                  KLanguageSwitch(
                    value: _lang,
                    onChanged: (v) => setState(() => _lang = v),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final s = _slides[i];
                    return Center(
                      child: KOnboardingSlide(
                        illustrationName: s.illustration,
                        title: s.title,
                        message: s.body,
                        index: _index,
                        count: _slides.length,
                      ),
                    );
                  },
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
