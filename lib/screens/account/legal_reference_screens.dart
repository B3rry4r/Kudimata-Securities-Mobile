// Screens 94–97 — the legal-documents "one viewer pattern" cluster: Partner
// disclosures, Referral terms, Data notice (NDPA), Account closure terms.
// Reachable both from wherever it applies in the app and from Account →
// Legal, per the design canvas's own framing: "one viewer pattern · each one
// opens where it applies, and lives in Account → Legal."
//
// 2026-08-24: was a read-only `KDocumentSummary` — canvas's own component
// choice, but that's the AI/comprehension-layer treatment (purple tint,
// AIMark "In plain English" badge — the same visual family as the Explain
// screen), which reads as generated commentary, not a real legal document.
// Direct product feedback: "the new legal docs [should be] written like the
// others properly and not a shortcard looking like the ai explain." Rebuilt
// with `_PlainLegalCard` — the same plain, neutral white-card treatment
// `legal_screen.dart`'s own document viewer already uses for the other
// four (Terms/Privacy/Risk/Client Agreement) — so all eight documents in
// Account → Legal now look and read consistently, and none of them imply
// AI-generated content.
//
// CONTENT SOURCING — read before touching the summary/points literals below:
//   - #96 Data notice (NDPA) and #97 Account closure terms both wire a REAL
//     backing LegalDocument as the "original document" reveal
//     (`LegalDocumentsRepository.getContent('privacy_policy')` /
//     `getContent('client_agreement')`). The real Privacy Policy and Client
//     Agreement in LEGAL.zip substantially cover both topics (NDPA
//     rights/retention/DPO; "you can close your account at any time... we
//     retain records the SEC requires and delete the rest") — confirmed by
//     reading the actual .docx text, not assumed.
//   - #94 Partner disclosures also wires `getContent('client_agreement')` —
//     its "Our Role and Blue Marina's Role" section is exactly this
//     screen's topic (Kudimata is the Sub Broker; Blue Marina Securities
//     Limited is the sponsoring/executing broker). The design canvas's own
//     `PARTNERS` constant names "Blue Marina Securities" too, so this is a
//     genuine content match, not a guess.
//   - #95 Referral terms has NO backing document ANYWHERE: not in LEGAL.zip
//     (all 5 docs read — no mention of a referral programme at all) and not
//     publishable as a LegalDocument either (`LegalDocument.kind` is
//     risk_disclosure | client_agreement | privacy_policy |
//     terms_of_service | 'other' per legal_documents_repository.dart —
//     'other' documents are download-only with no `sections`, and that
//     presigned-download path is separately known-broken, see
//     legal_screen.dart's own header comment). This is a genuine DATA gap:
//     legal/product needs to draft and publish real referral terms. No
//     `original` is offered here — showing a broken/empty reveal button
//     would be worse than omitting it.
//   - REWARD TYPE, corrected 2026-08-24 on direct product instruction
//     ("Referral is not money but meant to be at least 1 ai point for
//     referring a friend"): the reward is ONE AI CREDIT per verified
//     friend, not cash. An earlier pass had gone the wrong way here — it
//     saw `ReferralCode.earningsTotalKobo` in the backend, concluded the
//     product paid naira, and rewrote the design canvas's own "credits,
//     never cash" framing to match. The canvas was right; the kobo field is
//     vestigial (no backend code path ever increments it — see
//     ReferralCodeService). Cash-for-referral is also the riskier design in
//     a securities context, reading as an inducement to open a trading
//     account in a way an AI credit does not. This copy is still NOT a
//     reviewed legal document — it is a best-effort draft pending the real
//     one legal needs to write.
//   - The 10-business-day closure SLA on #97 and the 14-day notice period
//     on #95 are the design canvas's own figures; neither is corroborated
//     anywhere in the real LEGAL.zip pack (which only says "you can close
//     your account at any time"). Kept as plausible product policy, but
//     unverified against a reviewed legal source — flagged here for
//     legal/compliance to confirm before treating as authoritative.
//
// 2026-08-24 (second pass) — each screen was expanded from a 2-sentence
// intro + 4 bullets into a real headed document body (`_PlainLegalCard.
// sections`), on direct product instruction ("generate properly for the new
// ones not those short things... legal would give the main things"). Every
// clause is drafted from the REAL signed pack where the pack covers the
// topic, so these read as extracts of Kudimata's own executed documents
// rather than newly invented policy:
//   - #94: Blue Marina's full registered identity (CAC 746044, SEC file
//     1507, 10 Keffi Street S.W. Ikoyi Lagos), the sub-broker/sponsoring-
//     broker split, the no-delegation-without-SEC-approval clause, the
//     third-party provider list and the liability carve-outs all come
//     verbatim-in-substance from Client Agreement §§ "Who We Are", "Our Role
//     and Blue Marina's Role", "Liability".
//   - #96: every clause maps to a Privacy Policy section (DPO under NDPA
//     s.32, the collection list, the on-device-only biometric-unlock
//     carve-out, legal bases, the six named processors, Nigeria hosting +
//     ss.41-43 transfers, the four retention periods, TLS 1.3/AES-256/field-
//     level encryption, the six NDPA rights + 30-day response, and the s.40
//     72-hour breach notification).
//   - #97: retention, suspension grounds and the complaints SLA come from
//     Client Agreement §§ "Statements and Records", "Account Restrictions or
//     Suspension", "Complaints"; the CHN-is-yours-for-life and DCS-payout
//     points are the app's own real mechanics.
//   - #95 remains the ONE screen with no backing document to draw on (see
//     above) — its 10 clauses are drafted from what the shipped referral
//     mechanic actually does (ReferralRepository/refer_earn_screen.dart),
//     NOT from any reviewed source. It needs real legal drafting most.
//
// TWO REAL CONFLICTS FOUND while grounding this pass, both now resolved in
// favour of the signed document, and both worth legal confirming:
//   1. #94 used to say your shares sit "not with us and not with them" —
//      the Client Agreement says plainly "Blue Marina holds client assets
//      and handles trade settlement". Both are true in NGX market structure
//      (registered under your own CHN at the CSCS, held through the dealing
//      member) but the old phrasing flatly contradicted the executed
//      agreement, so it now states both facts instead of denying one.
//   2. #96 used to say "we never share holdings with anyone but the CSCS
//      and your broker" — the real Privacy Policy names six processors
//      (LumiID/Smile Identity, Flutterwave, AWS SNS, Blue Marina, FiberOps
//      Tech, Cloudflare). The old line was simply untrue and is replaced by
//      the real list.
// A third, INTERNAL to the signed pack and NOT fixable here: Client
// Agreement lists SendGrid as the email provider while Privacy Policy names
// AWS SNS for transactional email and lists SendGrid only under
// processed-outside-Nigeria. This screen follows the Privacy Policy (it is
// the data-protection document) — legal should reconcile the two.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/legal_documents_repository.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

/// Fetches a real LegalDocument's sections and joins them into one string
/// for `KDocumentSummary.original` — non-blocking and best-effort: a 404 (no
/// document published for [kind] yet) or any other failure just leaves the
/// "read the original document" affordance absent, never breaks the screen.
Future<String?> _fetchOriginal(BuildContext context, String kind) async {
  try {
    final repo = LegalDocumentsRepository(AppScope.read(context).apiClient);
    final doc = await repo.getContent(kind);
    if (doc.sections.isEmpty) return null;
    return doc.sections.map((s) => '${s.heading}\n${s.body}').join('\n\n');
  } on ApiException {
    return null;
  }
}

/// Shared layout for all four screens — back header, the document card, an
/// optional footnote, and one secondary "Back to X" button. Restyled
/// 2026-08-27 (ruling: restyle-only, see legal_screen.dart's own header —
/// "keep and restyle", no artboard of its own) onto `KAccountSubScaffold`,
/// the scaffold every other Account sub-screen already builds on
/// (account_widgets.dart) — this file was the one screen still hand-rolling
/// its own `Scaffold`/`KDetailHeader`/`SingleChildScrollView` plumbing.
/// Same arrangement as before (header, then card, then footnote, then one
/// secondary back button as the last scrolled item, matching
/// faq_screen.dart's `_SettlementArticle` — not `KAccountSubScaffold`'s
/// pinned `footer` slot, which is reserved for a margin-top:auto primary
/// action like Help & support's "File a complaint", not a plain "go back"
/// link) — only the header chrome and outer padding now come from the
/// shared scaffold instead of being redrawn here.
class _LegalDocScaffold extends StatelessWidget {
  const _LegalDocScaffold({
    required this.title,
    required this.summary,
    this.footnote,
    required this.backLabel,
    required this.onBack,
  });

  final String title;
  final Widget summary;
  final String? footnote;
  final String backLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    // English/Pidgin switch temporarily hidden (2026-08-24, direct product
    // instruction) — no real Pidgin translation of any legal document
    // exists anywhere in this app, so `KAccountSubScaffold.headerTrailing`
    // is left unset rather than passed a switch with nothing to switch to.
    return KAccountSubScaffold(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          summary,
          if (footnote != null) ...[
            const SizedBox(height: 14),
            Text(footnote!, style: KType.data(color: KColor.ink3)),
          ],
          const SizedBox(height: 20),
          KButton(label: backLabel, variant: KButtonVariant.secondary, onPressed: onBack),
        ],
      ),
    );
  }
}

/// The plain, neutral document card these four screens now share with
/// `legal_screen.dart`'s own document viewer (`_LegalDocumentViewerScreen`)
/// — white `KCard`, a section title, an intro paragraph, plain bulleted key
/// points, and (when a real backing document exists) a "Read the original
/// document" reveal. No purple tint, no AIMark badge — see this file's
/// header for why that AI-comprehension treatment was replaced.
class _PlainLegalCard extends StatefulWidget {
  const _PlainLegalCard({
    required this.title,
    required this.intro,
    this.points = const [],
    this.sections = const [],
    this.original,
  });

  final String title;
  final String intro;
  final List<String> points;

  /// The document body proper — real headed clauses, rendered below the
  /// intro/key-points summary (2026-08-24, direct product instruction:
  /// "generate properly for the new ones not those short things"). These
  /// four screens previously stopped at a 2-sentence intro plus 4 bullets,
  /// which reads as a summary of a document that doesn't exist rather than
  /// as the document itself. Grounded clause-by-clause in the real signed
  /// pack (LEGAL.zip) wherever the pack covers the topic — see this file's
  /// CONTENT SOURCING header for what is corroborated and what is not.
  final List<(String heading, String body)> sections;

  /// The real backing document's full text, or null when none exists (see
  /// this file's per-screen CONTENT SOURCING notes) — the reveal row below
  /// simply doesn't render when this is null, rather than showing a button
  /// to nothing.
  final String? original;

  @override
  State<_PlainLegalCard> createState() => _PlainLegalCardState();
}

class _PlainLegalCardState extends State<_PlainLegalCard> {
  bool _showOriginal = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title, style: KType.section()),
              const SizedBox(height: 10),
              Text(widget.intro, style: KType.body(color: KColor.ink2)),
              if (widget.points.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final p in widget.points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(top: 8, right: 10),
                          decoration: BoxDecoration(color: KColor.ink3, shape: BoxShape.circle),
                        ),
                        Expanded(child: Text(p, style: KType.body(color: KColor.ink2))),
                      ],
                    ),
                  ),
              ],
              if (widget.sections.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(height: 1, color: KColor.hairline),
                for (final (heading, body) in widget.sections) ...[
                  const SizedBox(height: 16),
                  Text(heading, style: KType.cardTitle(w: KWeight.semibold)),
                  const SizedBox(height: 6),
                  Text(body, style: KType.body(color: KColor.ink2)),
                ],
              ],
            ],
          ),
        ),
        if (widget.original != null) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _showOriginal = !_showOriginal),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: KColor.paper,
                border: Border.all(color: KColor.hairline),
                borderRadius: KRadii.cardR,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_showOriginal ? 'Hide the original document' : 'Read the original document',
                      style: KType.cardTitle(w: KWeight.semibold)),
                  KIcon('chevronRight', size: 16, color: KColor.ink3),
                ],
              ),
            ),
          ),
          if (_showOriginal) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: KColor.paper,
                border: Border.all(color: KColor.hairline),
                borderRadius: KRadii.cardR,
              ),
              child: Text(widget.original!, style: KType.body(color: KColor.ink2)),
            ),
          ],
        ],
      ],
    );
  }
}

// ── #94 · Partner disclosures ───────────────────────────────────────────

class PartnerDisclosuresScreen extends StatefulWidget {
  const PartnerDisclosuresScreen({super.key});

  @override
  State<PartnerDisclosuresScreen> createState() => _PartnerDisclosuresScreenState();
}

class _PartnerDisclosuresScreenState extends State<PartnerDisclosuresScreen> {
  late final Future<String?> _original = _fetchOriginal(context, 'client_agreement');

  static const _points = [
    'Kudimata Securities Ltd is a sub-broker. We operate the app, hold your wallet and route '
        'your orders — we do not execute trades on the exchange ourselves.',
    'Blue Marina Securities Limited is our sponsoring broker. It executes your orders on the '
        'NGX, holds client assets and handles settlement.',
    'Your shares are registered under your own Clearing House Number (CHN) at the CSCS.',
    'Money from a sale or a dividend reaches your own bank account under your Direct Cash '
        'Settlement (DCS) mandate.',
  ];

  static const _sections = [
    (
      '1. Who we are',
      'Kudimata Securities Ltd is a Nigerian company registered with the Corporate Affairs '
          'Commission. We operate the digital investment app called Kudimata Invest. We act as '
          'a sub-broker.',
    ),
    (
      '2. Who executes your trades',
      'Our sponsoring broker is Blue Marina Securities Limited (CAC 746044, SEC file 1507, '
          '10 Keffi Street, S.W., Ikoyi, Lagos). Blue Marina is a licensed broker-dealer '
          'registered with the Securities and Exchange Commission of Nigeria and a dealing '
          'member of the Nigerian Exchange Group (NGX). We route all trade orders through Blue '
          'Marina for execution.',
    ),
    (
      '3. What each of us does',
      'Kudimata operates the app, manages your account, verifies your identity, handles your '
          'wallet and routes your orders. We do not execute trades directly on the exchange. '
          'Blue Marina receives your orders from us, executes them on the NGX and returns the '
          'results. Blue Marina holds client assets and handles trade settlement.',
    ),
    (
      '4. How your shares and money are held',
      'Shares you buy are registered under your own Clearing House Number (CHN) at the Central '
          'Securities Clearing System (CSCS). Your CHN belongs to you, not to Kudimata and not '
          'to Blue Marina — closing your Kudimata account does not close your CHN. Proceeds '
          'from a sale, and any dividend, reach the bank account in your own name under your '
          'Direct Cash Settlement (DCS) mandate.',
    ),
    (
      '5. Execution-only service',
      'This platform provides execution-only services through our sponsoring broker. We do not '
          'provide personal investment advice unless expressly stated in writing. Any '
          'automated portfolios, market insights, explanations or data visualisations shown in '
          'this app are for information only and are not personalised financial, tax or legal '
          'advice.',
    ),
    (
      '6. Delegation and change of partner',
      'We do not delegate our registered functions to any third party without the prior '
          'approval of the Securities and Exchange Commission. If we add or change an executing '
          'broker, that broker is named on your contract notes and appears as its own section '
          'in your statements, and this disclosure is republished with a new version number.',
    ),
    (
      '7. Other providers involved in your account',
      'Running your account also involves: LumiID (and Smile Identity as an alternate) for '
          'identity verification, Flutterwave for wallet funding and withdrawals, FiberOps Tech '
          'for data hosting in Nigeria, and Cloudflare for security and delivery. What each one '
          'receives is set out in the Privacy Policy.',
    ),
    (
      '8. Limits of our responsibility',
      'We are not liable for losses caused by outages or failures at third-party providers, '
          'including Blue Marina, the NGX, Flutterwave, LumiID or our hosting and network '
          'providers, nor for market movements or the performance of any investment. This does '
          'not limit any liability that cannot be excluded under Nigerian law.',
    ),
    (
      '9. Questions and complaints',
      'Contact us at support@kudimata.securities. We acknowledge complaints within 1 business '
          'day and give a substantive response within 10 business days. If you are not '
          'satisfied, you may escalate to the Securities and Exchange Commission of Nigeria.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _LegalDocScaffold(
      title: 'Who executes your trades',
      backLabel: 'Back to the receipt',
      onBack: () => Navigator.of(context).maybePop(),
      summary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Canvas #94's own partner-logos row (Kudimata mark · divider ·
          // executing-broker logo) — was missing entirely; the real
          // Blue Marina lockup asset lives in the design bundle
          // (assets/partners/blue-marina.png) and is now imported into
          // this app the same way the illustration/brand assets already
          // were, rather than left out or faked with text.
          const _PartnerLogoRow(),
          const SizedBox(height: 12),
          FutureBuilder<String?>(
            future: _original,
            builder: (context, snapshot) => _PlainLegalCard(
              title: 'Kudimata places the order, a licensed broker executes it',
              intro: 'Kudimata Invest is the app. Your order reaches the NGX through Blue '
                  'Marina Securities Limited, our sponsoring broker, and your shares are '
                  'registered under your own CHN at the CSCS.',
              points: _points,
              sections: _sections,
              original: snapshot.data,
            ),
          ),
        ],
      ),
    );
  }
}

/// Canvas #94's bordered "who executes your trades" logo strip: the
/// Kudimata mark, a hairline divider, then each executing broker's real
/// logo. Only Blue Marina today — a second broker would add a second
/// image here, per the canvas's own footer note ("a second partner simply
/// adds a second image").
class _PartnerLogoRow extends StatelessWidget {
  const _PartnerLogoRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border.all(color: KColor.hairline, width: 1),
        borderRadius: KRadii.cardR,
      ),
      child: Row(
        children: [
          const KMark(size: 16), // width 16 -> height ~26, matching canvas's size=26 (height-set) mark
          const SizedBox(width: 14),
          Container(width: 1, height: 24, color: KColor.hairline),
          const SizedBox(width: 14),
          Image.asset('assets/partners/blue-marina.png', height: 18, fit: BoxFit.contain),
        ],
      ),
    );
  }
}

// ── #95 · Referral terms ────────────────────────────────────────────────

class ReferralTermsScreen extends StatelessWidget {
  const ReferralTermsScreen({super.key});

  static const _points = [
    'Your friend enters your code at sign-up; the reward lands once they finish '
        'verification and place their first order.',
    'You both earn 1 AI credit — nothing depends on how much either of you trades beyond '
        'that first order.',
    'Rewards are AI credits, never cash. They have no cash value and cannot be withdrawn.',
    'Self-referral, one person with several accounts, or bought codes forfeit the reward.',
  ];

  static const _sections = [
    (
      '1. Who can take part',
      'The programme is open to Kudimata Invest account holders whose identity verification '
          '(KYC) has been approved and whose account is not suspended or restricted. You must '
          'be at least 18 years old and resident in Nigeria, on the same terms as account '
          'opening under the Client Agreement.',
    ),
    (
      '2. How a referral is counted',
      'Each account has one referral code. A referral is counted when a new investor enters '
          'your code during sign-up, before their account is created. A code cannot be applied '
          'to an account that already exists, and only one code can be applied per account.',
    ),
    (
      '3. When the reward is earned',
      'The reward is earned once the referred investor has completed identity verification '
          'and placed their first order. Both conditions must be met. Until then the referral '
          'shows as pending in Refer & earn, and a pending referral carries no entitlement.',
    ),
    (
      '4. What the reward is',
      'You and the referred investor each receive 1 AI credit, added to your credit balance. '
          'The reward is not cash, is not paid into your wallet, and is not withdrawable. It '
          'does not vary with how much either of you deposits or trades beyond that first '
          'order, and it is not a share of any fee, commission or spread on any trade.',
    ),
    (
      '5. Using the reward',
      'A referral credit is an ordinary AI credit and behaves exactly like the credits you '
          'start with or buy: one credit funds one AI explanation, portfolio digest or '
          'glossary "explain further" request. Credits have no cash value, cannot be '
          'transferred between accounts, and cannot be exchanged for money.',
    ),
    (
      '6. Conduct that forfeits a reward',
      'No reward is payable, and a credited reward may be reversed, where we reasonably '
          'determine that a referral involved: referring yourself; opening or controlling more '
          'than one account to claim rewards; buying, selling or publicly advertising codes; '
          'entering a code on behalf of someone else; or any use of the programme that is '
          'fraudulent, automated or misrepresents Kudimata. Where we reverse a reward we will '
          'tell you the reason.',
    ),
    (
      '7. Tax',
      'You are responsible for any tax that applies to you on a reward you receive. We do not '
          'give tax advice.',
    ),
    (
      '8. Changing or ending the programme',
      'We may change or end this programme, or change the reward amount, on 14 days\' notice '
          'given in the app. Rewards already earned before the change takes effect remain '
          'yours. Referrals that are still pending when the programme ends are honoured if '
          'their conditions are met within 30 days of the end date.',
    ),
    (
      '9. Relationship to your other agreements',
      'These terms sit alongside the Client Agreement, the Terms of Service and the Privacy '
          'Policy. Where they conflict on anything other than the referral programme itself, '
          'those documents take precedence. Nigerian law governs these terms.',
    ),
    (
      '10. Questions and disputes about a referral',
      'Contact us at support@kudimata.securities. Referral disputes follow the same complaints '
          'route as everything else: acknowledgement within 1 business day, a substantive '
          'response within 10 business days, and escalation to the Securities and Exchange '
          'Commission of Nigeria if you are not satisfied.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _LegalDocScaffold(
      title: 'Referral terms',
      backLabel: 'Back to refer & earn',
      onBack: () => Navigator.of(context).maybePop(),
      footnote: "Kudimata Securities Ltd may end or change the programme with 14 days' "
          'notice. Rewards already earned stay yours.',
      summary: const _PlainLegalCard(
        title: "What you get, and what we won't do",
        intro: 'You and your friend each earn 1 AI credit once they finish verification '
            'and place a first order. Rewards are credits, never cash, and never tied to '
            'how much anyone trades.',
        points: _points,
        sections: _sections,
        // No `original` — see file header: no referral-terms LegalDocument
        // exists anywhere (LEGAL.zip or the backend), so there is nothing
        // real to link to.
      ),
    );
  }
}

// ── #96 · Data notice · NDPA ────────────────────────────────────────────

class DataNoticeScreen extends StatefulWidget {
  const DataNoticeScreen({super.key});

  @override
  State<DataNoticeScreen> createState() => _DataNoticeScreenState();
}

class _DataNoticeScreenState extends State<DataNoticeScreen> {
  late final Future<String?> _original = _fetchOriginal(context, 'privacy_policy');

  static const _points = [
    'Trade orders and transactions: kept 12 years. Audit trail: 12 years. Client '
        'communications: 7 years. KYC records: the life of the account plus the period SEC '
        'rules require.',
    'Your face or fingerprint for unlocking the app never leaves your phone — we never '
        'receive it.',
    'Optional analytics and product email: your choice, changeable in Data & privacy.',
    'We never sell your data. We share it only with the providers that run the platform, and '
        'with regulators where the law requires.',
  ];

  static const _sections = [
    (
      '1. Who is responsible for your data',
      'Kudimata Securities Ltd operates the Kudimata Invest app and is responsible for looking '
          'after your personal data. We have appointed a Data Protection Officer under Section '
          '32 of the Nigeria Data Protection Act 2023 (NDPA). You can reach the Data Protection '
          'Officer at support@kudimata.securities.',
    ),
    (
      '2. What we collect',
      'Identity data (name, email, phone, BVN, and government ID details — NIN, international '
          'passport or driver\'s licence). Biometric and liveness data (a live selfie taken in '
          'the app, used only for identity verification). Financial data (your bank account '
          'details for withdrawals, and your transaction history). Transaction data (orders, '
          'fills, cancellations, wallet funding and withdrawals). Device data (device type, app '
          'version, IP address and usage logs).',
    ),
    (
      '3. Face ID and fingerprint',
      'If you turn on biometric unlock, your face or fingerprint data is stored only on your '
          'device by the operating system. We never receive, access or store it. It never '
          'leaves your phone.',
    ),
    (
      '4. Why we collect it, and on what legal basis',
      'To verify your identity as law and SEC rules require; to open and manage your account; '
          'to process wallet funding and withdrawals; to route your orders to our sponsoring '
          'broker; to send trade confirmations and service notifications; to meet SEC '
          'record-keeping rules; and to keep the app secure. Our legal bases under the NDPA are '
          'contract, legal obligation, and — for anything optional — your consent, which you '
          'can withdraw at any time.',
    ),
    (
      '5. Who we share it with',
      'LumiID (and Smile Identity as an alternate) receives your BVN, NIN, ID document images '
          'and liveness selfie for verification. Flutterwave receives your payment details for '
          'funding and withdrawals. Blue Marina Securities Limited receives your order details '
          'to execute trades on the NGX. AWS SNS receives your email address to send '
          'transactional email. FiberOps Tech hosts your data and does not access it directly. '
          'Cloudflare provides security and delivery and may see your IP address. We never sell '
          'your personal data, and we share it with regulators only where the law requires.',
    ),
    (
      '6. Where your data is held',
      'All your primary data is hosted within Nigeria, in FiberOps Tech data centres in Lagos '
          '(primary) and Abuja (disaster recovery). Some providers may process data outside '
          'Nigeria as part of their service; where that happens we hold written agreements '
          'containing data-protection clauses that follow sections 41 to 43 of the NDPA, and we '
          'have carried out a transfer impact assessment for each provider.',
    ),
    (
      '7. How long we keep it',
      'Trade orders and transactions: 12 years. Audit trail: 12 years. Client communications: '
          '7 years. KYC records: for the life of the account plus the period required by SEC '
          'rules. When a retention period ends, the data is securely deleted or anonymised.',
    ),
    (
      '8. How it is protected',
      'Data is encrypted in transit (TLS 1.3) and at rest (AES-256). The most sensitive fields '
          '— BVN, NIN, date of birth and bank account numbers — carry an additional layer of '
          'encryption, so that even our database administrators cannot read them. Personally '
          'identifiable information is stripped from logs before storage. Access is restricted '
          'to authorised staff, and every staff action is written to an audit trail that cannot '
          'be edited or deleted.',
    ),
    (
      '9. Your rights under the NDPA',
      'You have the right to access your data, to have it corrected, to have it erased '
          '(subject to our legal obligation to keep records), to receive a portable copy, to '
          'object to certain processing, and to withdraw consent. Contact '
          'support@kudimata.securities and we will respond within 30 days. You can also file a '
          'complaint with the Nigeria Data Protection Commission.',
    ),
    (
      '10. If something goes wrong',
      'If a data breach is likely to harm you, we will notify the Nigeria Data Protection '
          'Commission within 72 hours, as Section 40 of the NDPA requires, and we will tell you '
          'directly where the breach is likely to affect your rights or freedoms.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _LegalDocScaffold(
      title: 'Your data',
      backLabel: 'Back to my choices',
      onBack: () => Navigator.of(context).maybePop(),
      footnote: 'Data controller: Kudimata Securities Ltd, Lagos. Complaints about data can '
          'also go to the Nigeria Data Protection Commission.',
      summary: FutureBuilder<String?>(
        future: _original,
        builder: (context, snapshot) => _PlainLegalCard(
          title: 'What we keep, why, and for how long',
          intro: 'We hold what the SEC requires us to hold, and nothing more. You can see '
              'it, correct it, export it, and delete whatever the law lets us delete.',
          points: _points,
          sections: _sections,
          original: snapshot.data,
        ),
      ),
    );
  }
}

// ── #97 · Account closure terms ─────────────────────────────────────────

class AccountClosureTermsScreen extends StatefulWidget {
  const AccountClosureTermsScreen({super.key});

  @override
  State<AccountClosureTermsScreen> createState() => _AccountClosureTermsScreenState();
}

class _AccountClosureTermsScreenState extends State<AccountClosureTermsScreen> {
  late final Future<String?> _original = _fetchOriginal(context, 'client_agreement');

  static const _points = [
    'Sell your shares, or instruct the CSCS to move them to another broker.',
    'Your wallet balance is paid to the DCS account in your name.',
    'Documents stay downloadable for 12 years, so tax filings are not affected.',
    'Your CHN belongs to you for life — closing here does not close it at the CSCS.',
  ];

  static const _sections = [
    (
      '1. You can close at any time',
      'You can ask us to close your Kudimata Invest account at any time, from Account → Data & '
          'privacy → Close my account, or by contacting support@kudimata.securities. You do not '
          'have to give a reason.',
    ),
    (
      '2. Your shares must be dealt with first',
      'We cannot close an account that still holds stock. Before closure you must either sell '
          'your holdings through the app, or instruct the CSCS to transfer them to another '
          'dealing-member broker. Your shares are registered under your own CHN, so a transfer '
          'moves the broker relationship, not the ownership.',
    ),
    (
      '3. Your CHN stays yours',
      'Your Clearing House Number belongs to you for life. Closing your Kudimata account does '
          'not close your CHN at the CSCS, and does not affect any holding you move to another '
          'broker.',
    ),
    (
      '4. Your money',
      'Any remaining wallet balance is paid out to the bank account in your own name under '
          'your Direct Cash Settlement mandate. We cannot pay a closing balance to a third '
          'party\'s account. If a deposit, withdrawal or trade is still settling, closure '
          'completes after it settles.',
    ),
    (
      '5. What we must keep, and for how long',
      'Closing your account does not delete everything, because SEC rules require us to retain '
          'records. Trade orders and transactions are kept 12 years, the audit trail 12 years, '
          'client communications 7 years, and KYC records for the life of the account plus the '
          'period SEC rules require. Anything we are not required to keep is securely deleted '
          'or anonymised when its retention period ends. This is the same retention set out in '
          'the Privacy Policy and is a legal obligation, not a choice.',
    ),
    (
      '6. Your documents stay available',
      'Statements, contract notes and tax documents remain downloadable for the 12-year '
          'retention period, so closing your account does not affect your ability to file tax '
          'returns or evidence past trades. Download anything you want to keep locally before '
          'you close, so you are not relying on regaining access.',
    ),
    (
      '7. Your data rights still apply',
      'After closure you keep your NDPA rights over the data we still hold — access, '
          'rectification, erasure of anything not subject to a retention obligation, '
          'portability, objection and withdrawal of consent. Contact '
          'support@kudimata.securities; we respond within 30 days.',
    ),
    (
      '8. Reopening',
      'Closure is not reversible. If you want to invest with us again later you will need to '
          'open a new account and complete identity verification again. Your CHN can be reused.',
    ),
    (
      '9. If we close or restrict an account',
      'Separately from closure you request, we may suspend or restrict an account where we '
          'suspect fraudulent or unauthorised activity, where the law or a regulator requires '
          'it, where you breach the Client Agreement or Terms of Service, or where we need to '
          'verify information. We will tell you the reason, and our staff must record that '
          'reason permanently in the audit trail.',
    ),
    (
      '10. Questions and complaints about a closure',
      'Contact support@kudimata.securities. We acknowledge within 1 business day and give a '
          'substantive response within 10 business days. If you are not satisfied you may '
          'escalate to the Securities and Exchange Commission of Nigeria.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _LegalDocScaffold(
      title: 'Closing your account',
      backLabel: 'Back to close account',
      onBack: () => Navigator.of(context).maybePop(),
      footnote: 'A closure request is answered within 10 business days. An unresolved one '
          'can be escalated like any other complaint.',
      summary: FutureBuilder<String?>(
        future: _original,
        builder: (context, snapshot) => _PlainLegalCard(
          title: 'How closing works, step by step',
          intro: 'You can leave whenever you like. Shares must be sold or moved to '
              'another broker first, your wallet is paid to your DCS account, and your CHN '
              'stays yours for life.',
          points: _points,
          sections: _sections,
          original: snapshot.data,
        ),
      ),
    );
  }
}
