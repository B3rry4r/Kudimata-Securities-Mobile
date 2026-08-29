# Dispatcher addendum

The dispatching session does not overrule, soften or re-classify any auditor
finding (see `independence.md`). This file records only corroboration and
disagreements, both of which are additive.

## Corroboration: finding #1 has a second live site

The classifier located the hardcoded fee at
`lib/screens/markets/asset_detail_screen.dart:568` — `fee: '1.35% all-in'`.

There is a **second** site stating the same figure, not listed in findings.json:

`lib/data/glossary.dart:22`
> "What Kudimata and the exchange charge to place and settle your order —
> **1.35% all-in** on a buy or sell, already included in the total you see before
> you confirm. **No separate hidden charges.**"

This makes the defect worse than reported on two counts. The glossary is the
app's own explanation of what a fee *means*, so it is where a user goes when
they want to check the number — and it repeats the wrong one. And it does not
merely display a figure, it makes a **guarantee** ("no separate hidden charges")
on top of a rate the project's own `FACT-CONFLICTS.md:24` computes as
**1.4512%** of consideration once the 7.5% VAT is included.

The project's own record shows this is a repeat, not a first offence:
`trade_flows.dart:32-33` and `wallet_flows.dart:18` both document an earlier
incident in which the app displayed "Fees · 1.35%" while the backend charged
something else.

Severity is the classifier's to set. This entry only adds a site and notes that
the second one carries a promise as well as a number.

## Disagreement between two independent auditors — unresolved on purpose

- The **coverage** auditor recorded buy/sell capture as already addressed.
- The **classifier** could not substantiate that from the repo, and found
  `test/shots_all.dart` carries 76 route specs and none for the four sheets.

Both are independent; neither is overruled here. The capture pass settles it
empirically — whichever it turns out to be, the fact that two auditors read the
same repo and disagreed about whether the revenue path is covered is itself the
finding, and it is the same blind spot (`UNROUTED` surfaces) that hid this
journey from the denominator in the first place.
