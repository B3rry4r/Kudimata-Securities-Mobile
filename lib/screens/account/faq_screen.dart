// Stage 9 — FAQ (pushed). Replaces help_support_screen.dart's old "Browse
// FAQs" row, which used to launch an external URL that doesn't correspond
// to any real page (https://kudimatasecurities.com/help — a placeholder,
// per that screen's header note that no backend resource exists for this
// content). A simple static in-app Q&A list instead — no backend resource
// for this either, same "Phase-0 keep local" status, just actually
// reachable and real instead of a dead external link.
import 'package:flutter/material.dart';

import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

class _Faq {
  const _Faq(this.question, this.answer);
  final String question;
  final String answer;
}

const List<_Faq> _kFaqs = [
  _Faq(
    'Do I need to complete KYC before I can use the app?',
    "No — you can sign up and browse markets, prices, and your portfolio "
        "right away. You'll only need to complete KYC and the risk "
        "questionnaire before your first trade or wallet funding/withdrawal.",
  ),
  _Faq(
    'What do I need for KYC verification?',
    'Your BVN and NIN, a valid ID document, a quick liveness selfie, and '
        "your next of kin's details. Verification is handled by our "
        'identity partner and usually completes quickly.',
  ),
  _Faq(
    'How do I fund my wallet?',
    "Tap Add money from Home or the Wallet tab and enter an amount. You'll "
        'be taken to a secure checkout page (card or bank transfer) hosted '
        'by our payment partner, Flutterwave — we never see or store your '
        'card details.',
  ),
  _Faq(
    'How long do withdrawals take?',
    'Withdrawals go out to your saved bank account and are typically '
        'processed within one business day. Large withdrawals may be held '
        'briefly for a compliance check.',
  ),
  _Faq(
    'What can I invest in?',
    'Nigerian Exchange (NGX) listed equities. Other asset classes may be '
        'added later.',
  ),
  _Faq(
    "I forgot my passcode — what's the difference between that and my password?",
    "Your passcode unlocks the app on this device only. Your password is "
        "your account login. On the passcode screen, tap Forgot password to "
        "reset your password by email — that also clears the old passcode "
        "so you can set a new one.",
  ),
  _Faq(
    'How do I reach support?',
    'Use Message support or Call us on the Help & support screen, or email '
        'support@kudimata.com directly.',
  ),
];

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'FAQs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _kFaqs.length; i++) ...[
            if (i != 0) const SizedBox(height: 12),
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_kFaqs[i].question, style: KType.cardTitle(w: KWeight.semibold)),
                  const SizedBox(height: 6),
                  Text(_kFaqs[i].answer, style: KType.body(color: KColor.ink2)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
