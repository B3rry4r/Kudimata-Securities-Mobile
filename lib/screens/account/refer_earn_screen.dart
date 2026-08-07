// Stage 9 — Refer & earn (pushed). One ink BalancePanel (earnings) + referral
// code card with copy + numbered "how it works" + share. Mirrors `ReferEarn`
// in extra-screens.jsx.
//
// Wired to GET /referral-code/me via ReferralRepository (see
// lib/data/api/README.md for the FutureBuilder convention) — replaces the
// hardcoded code/earnings/friend-count literals. Share invite POSTs
// /referral-code/track-share fire-and-forget (see ReferralRepository.trackShare)
// alongside a real OS share sheet (share_plus — see _ReferEarnScreenState._share).
// Copy button copies the referral code to the clipboard (Clipboard.setData)
// and confirms via SnackBar.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/repositories/referral_repository.dart';
import 'package:kudimata_securities/screens/shared/state_views.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
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
        text: "Join me on Kudimata Securities! Use my referral code "
            "${account.code} when you sign up and we both earn ₦1,000.",
        subject: 'My Kudimata Securities referral code',
      ),
    );
  }
}

class _ReferEarnBody extends StatelessWidget {
  const _ReferEarnBody({required this.account, required this.onShare});

  final ReferralAccount account;
  final VoidCallback onShare;

  static const List<String> _steps = [
    'Share your code with a friend',
    'They sign up and fund their wallet',
    'You both earn ₦1,000',
  ];

  @override
  Widget build(BuildContext context) {
    final friendWord = account.referredCount == 1 ? 'friend' : 'friends';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KBalancePanel(
          label: "You've earned",
          balance: account.earningsTotal,
          chart: Text(
            'From ${account.referredCount} $friendWord who joined.',
            style: KType.body(color: KColor.featureInk2),
          ),
        ),
        const SizedBox(height: 16),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const KEyebrow('Your referral code'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      account.code,
                      style: KType.section()
                          .copyWith(letterSpacing: 0.04 * 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  KButton(
                    label: 'Copy',
                    variant: KButtonVariant.secondary,
                    size: KButtonSize.sm,
                    fullWidth: false,
                    iconLeft: 'transfer',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: account.code));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Referral code copied')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const KEyebrow('How it works'),
        const SizedBox(height: 12),
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KColor.feature,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: KType.micro(color: KColor.featureInk, w: KWeight.semibold)
                      .copyWith(fontSize: 12, letterSpacing: 0, height: 1.0)
                      .tnum,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_steps[i], style: KType.body(color: KColor.ink)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        // Opens the real OS share sheet (share_plus) with the referral code/
        // message; the referral-attribution ping fires alongside it,
        // fire-and-forget, so it never blocks/gates the share sheet — see
        // _ReferEarnScreenState._share.
        KButton(label: 'Share invite', iconLeft: 'send', onPressed: onShare),
      ],
    );
  }
}
