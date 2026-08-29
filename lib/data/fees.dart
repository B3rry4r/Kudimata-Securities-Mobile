// Kudimata Securities — the confirmed trading fee rate.
//
// Ruled 2026-08-29 (docs/redesign/FACT-CONFLICTS.md C-1): the product owner
// confirmed the BACKEND rate card
// (`Kudimata-Securities-Backend/src/orders/fees.ts`) as the real trading fee
// — commission 0.90% of consideration + NGX/SEC/CSCS 0.45%, plus 7.5% VAT on
// those, an effective 1.4512% of consideration, all-in. The new canvas's
// drawn figures on the buy/sell review and receipt artboards (~0.361%–0.375%)
// are a design error per that ruling, not a competing truth — filed in
// FACT-CONFLICTS.md for the design pass to redraw; no screen renders them.
//
// This constant is the single place that confirmed rate lives on the mobile
// side. It backs informational "what do you charge" copy only — things like
// asset_detail_screen.dart's KProductCard stat cell and glossary.dart's
// "Fees" definition. It is NOT a per-order fee computation: a real order's
// own commission/VAT/total in kobo is calculated and charged server-side, but
// `POST /orders`'s response type carries no such field for a client to read
// (see docs/redesign/BACKEND_GAPS.md's "buy/sell fees are unreachable
// anywhere in this flow" entry, which spells out the exact missing fields) —
// so trade_flows.dart deliberately carries no fee constant of its own
// (R-34/C-1); that gap is a backend response-shape change, tracked there, not
// solved by this rate constant. If `fees.ts`'s rate card changes, this is the
// one place on the mobile side to update.
//
// `fees.ts` on the backend still carries its own "!! BEFORE GO-LIVE !!"
// self-warning that this rate is design-derived and unconfirmed. That
// warning text is now stale for the RATE itself (the owner confirmed it
// 2026-08-29) — updating that backend comment has been handed to whoever
// owns `Kudimata-Securities-Backend/src/orders/fees.ts`, a file this pass
// does not touch.

/// The confirmed effective all-in trading fee rate: commission + exchange
/// levies + VAT, as a fraction of consideration (0.014512 == 1.4512%).
const double kTradingFeeRate = 0.014512;

/// [kTradingFeeRate] formatted for display, e.g. KProductCard's "Fees" cell.
const String kTradingFeeDisplay = '1.4512% all-in';
