// Stage 9 — Article & Glossary (screen 57) / FAQ fallback (pushed).
//
// Design canvas screen 57 ("Article & Glossary") is a single-article reader:
// a category label + LanguageSwitch in the header, the question as a large
// title, a body paragraph with inline tappable glossary terms, a Glossary
// card defining every term used, two quick-nav pill chips, and a "This
// didn't answer it" button back to Help & support. The canvas gives full,
// real content for exactly ONE article — "When does money from a sale
// arrive?" (header category "Settlement", terms T+3 / Direct Cash
// Settlement / CSCS) — reached from help_support_screen.dart's matching FAQ
// row. This screen renders that real article when it's the one tapped.
//
// Routing constraint: this app has exactly one route for FAQ content
// (Routes.acctFaq -> FaqScreen, app_router.dart) and per-screen agents may
// not touch router files. help_support_screen.dart's rows all push that one
// route, differentiated by `extra` (the question text) — read here via
// GoRouterState.of(context).extra, the same no-new-route pattern already
// used by reset_passcode_screen.dart / log_in_screen.dart / otp_screen.dart.
// The other 3 FAQ rows (and any other real screen 57 article the canvas
// doesn't specify content for) fall back to the general static Q&A list
// below — a real, honest resource, just not the canvas's per-article
// glossary format, since inventing glossary terms/definitions for those
// questions wouldn't be grounded in anything.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/screens/shared/glossary_sheet.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

/// The one FAQ question help_support_screen.dart wires to the real,
/// canvas-specified Article & Glossary content.
const kSettlementArticleQuestion = 'When does money from a sale arrive?';

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

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    if (extra == kSettlementArticleQuestion) {
      return const _SettlementArticle();
    }
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

/// Design canvas screen 57, rendered for real: header category "Settlement"
/// + LanguageSwitch, the question as the article title, a body paragraph
/// with two inline glossary terms, a Glossary definitions card, two quick
/// pill chips (canvas gives them no onClick — left inert rather than
/// invented), and "This didn't answer it" back to Help & support.
class _SettlementArticle extends StatefulWidget {
  const _SettlementArticle();

  @override
  State<_SettlementArticle> createState() => _SettlementArticleState();
}

class _SettlementArticleState extends State<_SettlementArticle> {
  // _pidginNotReady (the LanguageSwitch's onChanged) is unused while the
  // switch itself is hidden — see the header-trailing comment below.

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Settlement',
      // English/Pidgin switch temporarily hidden (2026-08-24, direct
      // product instruction) — no real Pidgin translation exists anywhere
      // in the app yet.
      // headerTrailing: KLanguageSwitch(onChanged: _pidginNotReady),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kSettlementArticleQuestion, style: KType.title()),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: KType.body(color: KColor.ink2),
              children: [
                const TextSpan(text: 'Three business days after your sale fills. The NGX calls this '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: KGlossaryTerm(
                    text: 'T+3',
                    style: KType.body(color: KColor.ink2),
                    onTap: () => showGlossaryExplainSheet(context, 'T+3'),
                  ),
                ),
                const TextSpan(
                  text: ' — trade day plus three. On that day the money moves from the CSCS to your '
                      'bank account by ',
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: KGlossaryTerm(
                    text: 'Direct Cash Settlement',
                    style: KType.body(color: KColor.ink2),
                    onTap: () => showGlossaryExplainSheet(context, 'Direct Cash Settlement'),
                  ),
                ),
                const TextSpan(text: ', so it never sits with us.'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: KColor.paper,
              border: Border.all(color: KColor.hairline, width: 1),
              borderRadius: KRadii.cardR,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Glossary · free on every plan'.upper, style: KType.micro(color: KColor.ink3)),
                const SizedBox(height: 12),
                const _GlossaryEntry(
                  term: 'T+3',
                  definition:
                      'The three business days between a trade and the money or shares actually changing hands.',
                ),
                const SizedBox(height: 10),
                const _GlossaryEntry(
                  term: 'Direct Cash Settlement',
                  definition:
                      'Money from sales and dividends goes straight from the CSCS to your own bank account.',
                ),
                const SizedBox(height: 10),
                const _GlossaryEntry(
                  term: 'CSCS',
                  definition: 'The register that records which Nigerian shares you own, under your CHN.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Canvas gives these two chips no onClick — quick-nav affordances
          // with no real destination modelled yet, left inert rather than
          // wired to a guess.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              KPillChip(label: 'Read in Pidgin'),
              KPillChip(label: 'Fees, in full'),
            ],
          ),
          const SizedBox(height: 28),
          KButton(
            label: "This didn't answer it",
            variant: KButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _GlossaryEntry extends StatelessWidget {
  const _GlossaryEntry({required this.term, required this.definition});
  final String term;
  final String definition;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(term, style: KType.cardTitle()),
        const SizedBox(height: 2),
        Text(definition, style: KType.body(color: KColor.ink2)),
      ],
    );
  }
}
