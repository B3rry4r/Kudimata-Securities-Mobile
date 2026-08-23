// Corporate actions — static illustrative fixtures (2026-08-23, new feature
// area, "Soft Landing" screens 81-84). There is NO corporate-actions data
// model anywhere in this app or in Kudimata-Securities-Backend/.pipeline/
// registry.json: no rights-issue entity, no AGM/resolution/proxy-vote
// entity, no dividend ledger, no e-dividend-mandate/registrar entity — a
// `grep -i "rights|agm|dividend|resolution|vote"` over registry.json comes
// back completely empty. This whole cluster is a genuinely new feature the
// backend hasn't been asked to build yet.
//
// Per lib/screens/account/plans_screen.dart's established house convention
// ("UI-complete preview... no real backend exists yet... choosing a plan
// doesn't charge anything; it tells the investor plainly that this is a
// preview") this cluster ships as real, complete UI fed by local static
// fixtures rather than a FutureBuilder against a repository method that
// doesn't exist yet — there is nothing to retry or error-handle, because
// there is no endpoint at all, not a flaky one. The figures below are the
// SAME illustrative numbers the design canvas itself uses (GTCO 1-for-5
// rights, MTN AGM, Zenith bonus) — see s81-s84.html — kept in one place so
// the hub cards and the detail screens can't drift from each other.
//
// What a real backend would need before this becomes live data:
//   - A CorporateAction/RightsIssue entity: issuer, ratio, rights price,
//     entitlement per holding, close date, and a "take up" endpoint that
//     places a real subscription order against the CSCS.
//   - An AGM/Resolution/ProxyVote entity: meeting date/venue, resolution
//     text per company, and a "submit my proxy votes" endpoint.
//   - A dividend ledger entity (paid-this-year total, per-payment history)
//     and a distinct e-dividend-mandate entity for CLAIMING dividends that
//     predate any e-mandate — this is NOT the same thing as the existing
//     DCS mandate (see bank_accounts_screen.dart / dividends_screen.dart
//     header comments for why they're different mechanisms).
import 'package:flutter/foundation.dart';

@immutable
class RightsIssueFixture {
  const RightsIssueFixture({
    required this.ticker,
    required this.companyName,
    required this.ratioLabel,
    required this.entitlementShares,
    required this.rightsPriceLabel,
    required this.marketPriceLabel,
    required this.costToTakeAllLabel,
    required this.closesShortLabel,
    required this.closesLabel,
    required this.walletBalanceLabel,
    required this.rightsPricePerShare,
  });

  final String ticker;
  final String companyName;
  final String ratioLabel; // "1 for 5"
  final int entitlementShares; // 80
  final String rightsPriceLabel; // "₦42.00"
  final String marketPriceLabel; // "₦48.15"
  final String costToTakeAllLabel; // "₦3,360.00"
  final String closesShortLabel; // "27 Mar" — the hub card's deadline eyebrow
  final String closesLabel; // "27 Mar 2026 · 14:30" — the detail screen's fact row
  final String walletBalanceLabel; // "₦214,300.00"
  final double rightsPricePerShare; // 42.00 — used to recompute the button label
}

const kMockRightsIssue = RightsIssueFixture(
  ticker: 'GTCO',
  companyName: 'GTCO',
  ratioLabel: '1 for 5',
  entitlementShares: 80,
  rightsPriceLabel: '₦42.00',
  marketPriceLabel: '₦48.15',
  costToTakeAllLabel: '₦3,360.00',
  closesShortLabel: '27 Mar',
  closesLabel: '27 Mar 2026 · 14:30',
  walletBalanceLabel: '₦214,300.00',
  rightsPricePerShare: 42.00,
);

@immutable
class AgmResolutionFixture {
  const AgmResolutionFixture({required this.index, required this.title});
  final int index;
  final String title;
}

@immutable
class AgmFixture {
  const AgmFixture({
    required this.companyName,
    required this.sharesHeld,
    required this.votesCloseLabel,
    required this.meetingLabel,
    required this.resolutions,
  });

  final String companyName;
  final int sharesHeld;
  final String votesCloseLabel; // "04 Apr"
  final String meetingLabel; // "11 Apr in Lagos"
  final List<AgmResolutionFixture> resolutions;
}

// Only resolutions 1-2 appear in s83's markup verbatim; the design states
// "5 resolutions" on the hub card and "Three more resolutions below" under
// the first two, so 3-5 are standard NGX AGM order-of-business items filled
// in to match that count honestly rather than truncating the list.
const kMockAgm = AgmFixture(
  companyName: 'MTN Nigeria',
  sharesHeld: 120,
  votesCloseLabel: '04 Apr',
  meetingLabel: '11 Apr in Lagos',
  resolutions: [
    AgmResolutionFixture(index: 1, title: 'Approve the 2025 accounts'),
    AgmResolutionFixture(index: 2, title: 'Declare a final dividend of ₦20.00'),
    AgmResolutionFixture(index: 3, title: "Re-elect a director retiring by rotation"),
    AgmResolutionFixture(index: 4, title: "Fix the auditors' remuneration"),
    AgmResolutionFixture(index: 5, title: 'Elect the audit committee'),
  ],
);

@immutable
class DividendHistoryEntry {
  const DividendHistoryEntry({
    required this.companyName,
    required this.metaLabel,
    required this.amountLabel,
    required this.isCash,
  });

  final String companyName;
  final String metaLabel; // "28 Feb 2026 · net of 10% WHT"
  final String amountLabel; // "+₦4,120.00" or "Shares"
  final bool isCash;
}

const kDividendsPaidThisYearLabel = '₦4,120.00';
const kDcsAccountLabel = 'All by Direct Cash Settlement · GTB ••••6789';
const kUnclaimedEstimateLabel = '₦31,400 est.';

const kMockDividendHistory = [
  DividendHistoryEntry(
    companyName: 'MTN Nigeria',
    metaLabel: '28 Feb 2026 · net of 10% WHT',
    amountLabel: '+₦4,120.00',
    isCash: true,
  ),
  DividendHistoryEntry(
    companyName: 'Zenith Bank · scrip',
    metaLabel: '28 Feb 2026 · 40 bonus shares',
    amountLabel: 'Shares',
    isCash: false,
  ),
];
