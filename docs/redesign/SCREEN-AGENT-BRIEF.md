# Screen agent brief

Every screen agent in the 2026-08 redesign follows this. Your task message names
your screen and its artboard; everything else is here.

Validated on the `s24` pilot before being used at scale.

---

## Read before you start

`docs/redesign/DECISIONS.md` — the authority declaration and all rulings. It
governs everything below. Note especially:

- **R-4** — the canvas is authoritative for the UI; the backend yields.
- **R-5** — artboard ids come from your task message, never from a code comment.
  Comments in this repo cite ids from the *old* 97-screen canvas which now point
  at unrelated screens. If your file has one, it is wrong: fix or delete it.
- **R-30** — the canvas designs no loading/error/empty states. You owe all three.
- **R-34** — a designed figure with no data source is omitted and filed, never
  invented.
- The `_ds/` bundle is the **admin dashboard's** design system, reconstructed from
  this app. Never take a mobile token from it.

## The eight rules

1. **Build what the artboard draws.** Layout, structure, copy, interaction.
2. **Never reshape the screen to fit available data.** If the design needs data the
   API does not serve, build the screen as designed and append the gap to
   `docs/redesign/BACKEND_GAPS.md`, naming the artboard and the field. Do not
   quietly drop a designed element. The one exception is R-34: a *figure* with no
   writer is omitted rather than faked — but the element around it still ships.
3. **Both themes.** Dark tokens exist (`KPalette.dark`). Take colours from tokens,
   never a literal — `hardcoded_signals` fails the build on a raw `Color(0xFF…)`
   outside `lib/theme/`.
4. **All three non-happy states**, using `lib/screens/shared/state_views.dart`.
   Report **the condition that enters each one**. A state nothing can enter is not
   implemented, it is decoration.
5. **Never fork a shared widget — and from wave 2 on, never edit one either.**

   Screen-local private widgets (`_Foo`) are the house pattern and are entirely
   yours. But **shared files are off-limits while a wave is running**:

   ```
   lib/widgets/**   lib/data/**   lib/theme/**   lib/router/**
   ```

   If your screen needs a prop on a `K*` widget, a new glyph, a model field or a
   repository change: **do not add it, and do not work around it with a local
   copy.** Write a SHARED-CHANGE REQUEST in your report — the file, the exact
   change, and why your screen needs it — and build everything else. A serial
   pre-step applies all requests between waves, then your screen is re-dispatched
   to finish.

   *Why:* wave 1 ran four agents concurrently and three of them edited shared
   files. Nothing broke, but only because their file sets happened not to overlap.
   Two agents adding a prop to the same widget would have silently clobbered each
   other, and the loser's work would look like it was never done. Forking is
   already banned; this closes the other half.

   A local copy is the worst of the three options: it compiles, it passes review,
   and it silently forks the truth. In the sibling backend that mistake produced
   `S3PresignerService` in four modules and `AuthenticatedRequest` in twenty-five.
6. **Stay in scope.** Your screen's files only. Never `lib/theme/**`,
   `lib/router/**`, `test/shots_all.dart`, or another agent's screen. If you
   believe you must change something outside your scope, HALT and report it.
   A local copy of shared code is the worst available option: it compiles, it
   passes review, and it silently forks the truth.
7. **No deferral comments.** "TODO", "for now", "out of scope" fail the
   `deferrals` gate. If you want to write one, it is a gap for
   `BACKEND_GAPS.md` or a line in your report — prose is not a resolution.
8. **Kill any process you start.**

## Gates — run all three before reporting

```bash
python3 scripts/gates/run.py     # baseline 72 fail / 28 warn — add ZERO new
flutter test                     # 11/11
bash scripts/design/shots.sh     # re-render all screens
```

If a gate fires on pre-existing code you did not write, leave it and note it.

## R-34 applies to CLAIMS, not just figures

R-34 says a designed **figure** with no data source is omitted and filed rather
than invented. The same holds for any **statement of fact** the artboard makes
about how the system behaves.

`s37` draws *"Changing it takes a 24-hour security hold."* The agent building it
grepped the backend, found **no such mechanism anywhere**, and omitted the line
rather than shipping it.

That is the right call, and it matters more than a wrong number would. A fee
that is too low is an error. **A security guarantee the system does not implement
is a promise to a customer that nothing keeps** — and unlike a wrong figure,
nobody discovers it until it is relied on.

So before rendering any line that asserts what the system does — a hold period, a
notification, a limit, a settlement window, an approval step — **confirm the
mechanism exists.** If it does not: omit the claim, keep the surrounding element,
file the gap, and say so in your report.

Two removals in this build came from exactly that check: the "24-hour security
hold" above, and `_kDailyLimit` — a ₦500,000 daily cap the app displayed and
enforced client-side, with **zero backend enforcement** behind it.

## The artboard depicts one situation; your code path may serve several

An artboard is a drawing of **one moment**. The widget you are building often
serves more cases than the designer drew. Building the artboard faithfully is
then exactly what introduces the bug.

Seen three times already:

- `s08p` drew a **returning user on a new phone**, so "Create an account" was
  removed as undrawn. But the same code path serves a **fresh install with no
  account** — who then reached a sign-in screen with no way out. (B-5)
- `s38` draws a **successful** transaction with a static checkmark. The same
  screen must also render **pending and failed** transactions, which the canvas
  never draws.
- `s23`'s KYC banner draws one example message; the real state can be pending,
  rejected, flagged or expired.

**So before deleting an element because the artboard omits it, ask what else this
code path serves.** If the answer is "more situations than the artboard depicts",
keep the element and say so in your report — that is a divergence with a reason,
not a failure to follow the design.

This is the mirror of R-34. There, the artboard shows a figure the system cannot
provide, so you omit it. Here, the system has a state the artboard does not show,
so you keep it. Both come from the same place: **the canvas is authoritative for
design, and reality is authoritative for what exists.**

## Evidence — the part that decides whether you are done

**Reporting done because the code reads correctly is not acceptable.** Required:

1. Re-render with `bash scripts/design/shots.sh`.
2. **Open your screen's light and dark PNGs and look at them.** Find their paths
   via `dartFile` in `build/shots/manifest.json`.
3. **Open your artboard's markup and compare element by element** — header,
   sections, order, spacing, copy, controls.
4. State each element and whether your render matches. **Where it does not match,
   say so plainly rather than rounding up to done.** An honest non-match is useful;
   a false "matches" costs a human the time to find it later.

## Report format

Max 15 lines:

- element-by-element match against your artboard
- the condition entering each of loading / error / empty
- any backend gaps filed
- any shared-widget prop you added, or why none was needed
- exact gate + test counts, before and after
- anything you could not match, and why
