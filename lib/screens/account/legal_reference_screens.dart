// Screens 94–97 — the legal-documents "one viewer pattern" cluster: Partner
// disclosures, Referral terms, Data notice (NDPA), Account closure terms.
// Each is a read-only `KDocumentSummary` — "plain English above the raw
// filing, original always one tap away" (readme.md's own description of
// this component, and the audit section it answers) — reachable both from
// wherever it applies in the app and from Account → Legal, per the design
// canvas's own framing: "one viewer pattern · each one opens where it
// applies, and lives in Account → Legal."
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

/// Shared layout for all four screens — back header (+ a display-only
/// `KLanguageSwitch`), the `KDocumentSummary`, an optional footnote, and one
/// secondary "Back to X" button.
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
      appBar: KDetailHeader(
        title: title,
        onBack: onBack,
        // Display-only: the canvas shows a LanguageSwitch on every legal
        // viewer (English/Pidgin), but readme.md is explicit that "legal
        // text stays authoritative in English" — no Pidgin translation of
        // any legal document exists anywhere in this app, so wiring this to
        // actually switch the rendered language would mean fabricating a
        // translated document that doesn't exist. Shown inert (no
        // `onChanged`) so its presence still matches the canvas, rather than
        // silently dropping it.
        trailing: const KLanguageSwitch(),
      ),
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
            builder: (context, snapshot) => KDocumentSummary(
              kind: 'Third-party disclosure',
              title: 'Kudimata places the order, a licensed broker executes it',
              summary: 'Kudimata Invest is the app. Your order reaches the NGX through a '
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
      summary: const KDocumentSummary(
        kind: 'Referral terms',
        title: "What you get, and what we won't do",
        summary: 'You and your friend each earn ₦1,000 once they finish verification and '
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
    'Identity, BVN, NIN and documents: kept 6 years after your account closes, as the SEC '
        'requires.',
    'Trading records and contract notes: kept 6 years; you can download them any time.',
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
        builder: (context, snapshot) => KDocumentSummary(
          kind: 'Nigeria Data Protection Act',
          title: 'What we keep, why, and for how long',
          summary: 'We hold what the SEC requires us to hold, and nothing more. You can see '
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
    'Documents stay downloadable for 6 years, so tax filings are not affected.',
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
        builder: (context, snapshot) => KDocumentSummary(
          kind: 'Account closure terms',
          title: 'How closing works, step by step',
          summary: 'You can leave whenever you like. Shares must be sold or moved to '
              'another broker first, your wallet is paid to your DCS account, and your CHN '
              'stays yours for life.',
          points: _points,
          original: snapshot.data,
        ),
      ),
    );
  }
}
