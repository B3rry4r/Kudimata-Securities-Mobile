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
//   - The referral copy below is ALSO corrected against the design canvas's
//     own authored text: the canvas describes the reward as "20 free
//     explanations" / "credits, never cash", but the shipped mechanic
//     (`ReferralRepository`/`ReferralAccount`, see refer_earn_screen.dart)
//     pays real cash — ₦1,000 per verified friend. Repeating "never cash"
//     here would be actively false legal copy, not just unreviewed, so the
//     wording is corrected to match what the product actually does. This
//     copy is still NOT a reviewed legal document — it is this pass's
//     best-effort, honest placeholder pending the real one product/legal
//     needs to draft.
//   - The 10-business-day closure SLA on #97 and the 14-day notice period
//     on #95 are the design canvas's own figures; neither is corroborated
//     anywhere in the real LEGAL.zip pack (which only says "you can close
//     your account at any time"). Kept as plausible product policy, but
//     unverified against a reviewed legal source — flagged here for
//     legal/compliance to confirm before treating as authoritative.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/legal_documents_repository.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

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
/// optional footnote, and one secondary "Back to X" button.
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
    return Scaffold(
      backgroundColor: KColor.bg,
      // English/Pidgin switch temporarily hidden (2026-08-24, direct
      // product instruction) — no real Pidgin translation of any legal
      // document exists anywhere in this app.
      appBar: KDetailHeader(title: title, onBack: onBack),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, 10, KSpace.gutter, 24),
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
        ),
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
    this.original,
  });

  final String title;
  final String intro;
  final List<String> points;

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
    'Blue Marina Securities is a dealing member of the NGX and executes your orders.',
    'Your shares are registered to your own CHN at the CSCS, in your name.',
    'Money from a sale or a dividend moves from the CSCS to your bank under your DCS mandate.',
    'If we add another executing broker, it appears on your receipts and as its own '
        'statement section.',
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
              intro: 'Kudimata Invest is the app. Your order reaches the NGX through a '
                  'dealing-member broker, and your shares sit in your own name at the CSCS — '
                  'not with us and not with them.',
              points: _points,
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
    'You both earn ₦1,000, paid into your wallet — nothing depends on how much either of '
        'you trades beyond that first order.',
    'Rewards are real money, not credits — see your balance any time in Refer & earn.',
    'Self-referral, one person with several accounts, or bought codes forfeit the reward.',
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
        intro: 'You and your friend each earn ₦1,000 once they finish verification and '
            'place a first order. Rewards are real cash paid into your wallet, never tied '
            'to how much anyone trades.',
        points: _points,
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
    'Identity, BVN, NIN and documents: kept 12 years after your account closes, as the SEC '
        'requires.',
    'Trading records and contract notes: kept 12 years; you can download them any time.',
    'Optional analytics and product email: your choice, changeable in Data & privacy.',
    'We never sell your data, and we never share holdings with anyone but the CSCS and '
        'your broker.',
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
          original: snapshot.data,
        ),
      ),
    );
  }
}
