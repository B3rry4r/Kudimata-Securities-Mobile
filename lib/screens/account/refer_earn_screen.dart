// Stage 9 — Refer & earn (pushed). Feature-tinted code panel + copy/share
// button row + a real-data stats card + a footnote with a "Referral terms"
// link. Mirrors `ReferEarn` in extra-screens.jsx / design canvas screen 55.
//
// Wired to GET /referral-code/me via ReferralRepository (see
// lib/data/api/README.md for the FutureBuilder convention) — replaces the
// hardcoded code/earnings/friend-count literals. Share invite POSTs
// /referral-code/track-share fire-and-forget (see ReferralRepository.trackShare)
// alongside a real OS share sheet (share_plus — see _ReferEarnScreenState._share).
// Copy button copies the referral code to the clipboard (Clipboard.setData)
// and confirms via SnackBar.
//
// EXACTNESS PASS (2026-08-23, screens 52-59 re-audit): the previous version of
// this screen had drifted structurally from the canvas — a KBalancePanel and
// a fabricated "How it works" numbered list that don't exist on screen 55 at
// all, a plain KCard instead of the feature-tinted "Your code" panel, one
// inline Copy button instead of the Copy/Share full-width pair, no
// "Referral terms" link, and no bottom "See how credits work" nav to Plans
// (screen 53). Rebuilt to match: feature panel (mirrors the wallet virtual-
// account-number treatment in wallet_flows.dart — "the single most important
// piece of data on this sheet"), Copy code + Share side by side, a stats
// card, and the two nav affordances. The canvas's own stats card shows
// "Friends joined / Still verifying / Explanations earned" — this backend's
// ReferralCode resource only carries `referredCount` and `earningsTotalKobo`
// (registry.json; see referral_repository.dart), no "still verifying" split
// and no AI-credit counter (this backend pays real naira, not credits), so
// the stats card here shows only the two fields that are real rather than
// inventing the rest.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/repositories/referral_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'account_widgets.dart';

class ReferEarnScreen extends StatefulWidget {
  const ReferEarnScreen({super.key});

  @override
  State<ReferEarnScreen> createState() => _ReferEarnScreenState();
}

class _ReferEarnScreenState extends State<ReferEarnScreen> {
  late final _repo = ReferralRepository(AppScope.read(context).apiClient);
  late Future<ReferralAccount> _future = _repo.me();

  // Canvas footnote: "Rewards are credits, never cash. Referral terms." —
  // the underlined inline link, same TapGestureRecognizer convention as
  // sign_up_screen.dart's Terms/Privacy/Risk links.
  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => context.push(Routes.acctLegalReferralTerms);

  @override
  void dispose() {
    _termsTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Refer & earn',
      child: FutureBuilder<ReferralAccount>(
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
          return _ReferEarnBody(
            account: snapshot.data!,
            onShare: () => _share(snapshot.data!),
            termsTap: _termsTap,
            onSeeCredits: () => context.push(Routes.acctPlans),
          );
        },
      ),
    );
  }

  /// Fires the attribution ping (fire-and-forget, never blocks/gates the
  /// share sheet) and opens the real OS share sheet with the referral
  /// code/message.
  void _share(ReferralAccount account) {
    _repo.trackShare();
    SharePlus.instance.share(
      ShareParams(
        text: "Join me on Kudimata Invest! Use my referral code "
            "${account.code} when you sign up and we both earn ₦1,000.",
        subject: 'My Kudimata Invest referral code',
      ),
    );
  }
}

class _ReferEarnBody extends StatelessWidget {
  const _ReferEarnBody({
    required this.account,
    required this.onShare,
    required this.termsTap,
    required this.onSeeCredits,
  });

  final ReferralAccount account;
  final VoidCallback onShare;
  final TapGestureRecognizer termsTap;
  final VoidCallback onSeeCredits;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mockup: support-chat illustration on a sun plate.
        const KIllustration('support-chat', role: KIlloRole.small, tone: KIlloTone.sun),
        const SizedBox(height: 14),
        Text('Bring a friend in', style: KType.title()),
        const SizedBox(height: 6),
        // screen-specs.md spec 55's body, adapted for real cash rewards —
        // this backend's ReferralAccount.earningsTotal is genuine naira, not
        // AI-explanation credits, so "20 free explanations" is replaced with
        // the real reward (2026-08-23 exactness pass).
        Text(
          'You both earn ₦1,000 when they finish verification and place their first order.',
          style: KType.body(color: KColor.ink2),
        ),
        const SizedBox(height: 14),
        // Feature-tinted "Your code" panel — mirrors the wallet screen's
        // virtual-account-number treatment (wallet_flows.dart): the single
        // most important piece of data on this sheet gets the full grape
        // plate, sun eyebrow, 30px/800 value.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: KColor.feature, borderRadius: KRadii.featureR),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Your code'.upper, style: KType.label(color: KColor.sun)),
              const SizedBox(height: 6),
              Text(
                account.code,
                style: KType.title(color: KColor.featureInk)
                    .copyWith(fontSize: 30, fontWeight: KWeight.black, letterSpacing: -0.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: KButton(
                label: 'Copy code',
                variant: KButtonVariant.secondary,
                size: KButtonSize.md,
                iconLeft: 'card',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: account.code));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Referral code copied')),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KButton(
                label: 'Share',
                size: KButtonSize.md,
                iconLeft: 'send',
                onPressed: onShare,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Stats card — canvas rows are "Friends joined / Still verifying /
        // Explanations earned"; only the first has a real backend field
        // (referredCount). "Still verifying" has no backend split and
        // "Explanations earned" describes the AI-credit economy this
        // backend doesn't run (it pays cash — earningsTotalKobo), so this
        // shows "Friends joined" and the real cash total instead of
        // inventing the other two (2026-08-23 exactness pass).
        KCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KKeyValueRow(
                label: 'Friends joined',
                value: '${account.referredCount}',
                first: true,
              ),
              KKeyValueRow(label: "You've earned", value: account.earningsTotal),
            ],
          ),
        ),
        const SizedBox(height: 14),
        RichText(
          text: TextSpan(
            style: KType.data(color: KColor.ink3),
            children: [
              const TextSpan(
                text: 'We never pay for orders placed — only for a friend who gets verified. ',
              ),
              TextSpan(
                text: 'Referral terms',
                style:
                    KType.data(color: KColor.ink3).copyWith(decoration: TextDecoration.underline),
                recognizer: termsTap,
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        KButton(
          label: 'See how credits work',
          variant: KButtonVariant.ghost,
          onPressed: onSeeCredits,
        ),
      ],
    );
  }
}
