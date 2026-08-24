// Kudimata Securities — the static glossary. 2026-08-24, direct product
// instruction: glossary terms should be "self-explained... so when they
// click they see it" — real, pre-written plain-English definitions, not an
// AI call. Instant and free (no network round-trip, no credit) for the
// first read; lib/screens/shared/glossary_sheet.dart layers an optional
// "Explain further" AI follow-up on top of whatever's shown here, which
// DOES cost a credit (see that file's header comment).
//
// Keys are matched case-insensitively (see [glossaryDefinition]) against
// whatever label a KGlossaryTerm/KProductCard stat cell uses, so this one
// map covers every current call site (faq_screen.dart's "T+3"/"Direct Cash
// Settlement", asset_detail_screen.dart's Risk/Fees/Liquidity/Minimum stat
// cells, trade_flows.dart's "T+3").
const Map<String, String> kGlossary = {
  'T+3':
      'Trade day plus three business days — how long it takes for money from a sale to reach your wallet, or for shares from a buy to show up as yours. It\'s not a Kudimata rule: every trade on the NGX settles this way.',
  'Direct Cash Settlement':
      'DCS for short. It\'s the bank mandate that lets money from a sale go straight to your own bank account, in your own name, without passing through anyone else\'s hands first — the NGX requires it before your account can trade.',
  'Risk':
      'How much a share\'s price can realistically move, up or down, compared to safer places to keep money. Shares are never risk-free — the price you see today isn\'t guaranteed tomorrow.',
  'Fees':
      'What Kudimata and the exchange charge to place and settle your order — 1.35% all-in on a buy or sell, already included in the total you see before you confirm. No separate hidden charges.',
  'Liquidity':
      'How easily you can turn a holding back into cash. "Daily · T+3" means you can place a sell order any trading day, and the proceeds land in your wallet three business days after it fills.',
  'Minimum':
      'The smallest amount you can put into a single order — ₦5,000. Below that, the order can\'t be placed.',
};

/// Case-insensitive lookup — [term] is matched by lowercasing and trimming
/// both sides, so 'liquidity', 'Liquidity', and 'LIQUIDITY ' all resolve
/// the same entry. Returns null for a term with no static definition yet
/// (the calling sheet falls back to asking the AI directly in that case).
String? glossaryDefinition(String term) {
  final normalized = term.trim().toLowerCase();
  for (final entry in kGlossary.entries) {
    if (entry.key.toLowerCase() == normalized) return entry.value;
  }
  return null;
}
