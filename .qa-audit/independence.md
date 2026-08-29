# Independence statement

**Date:** 2026-08-29
**Audit target:** Kudimata Securities Mobile @ `467f343` (main)

## The compromise, stated plainly

The session dispatching this audit **coordinated the 2026-08 redesign that built
the screens under audit.** Under law 1 it is therefore disqualified from
producing findings, and it does not produce any.

## How independence is preserved

- Every finding in this audit is produced by a **fresh agent** carrying none of
  the dispatching session's context, which authored **no** in-scope file. None
  is a context fork.
- The dispatching session acts only as dispatcher and assembler: it routes work,
  and it does **not** overrule, soften, or re-classify a finding an auditing
  agent returns. Where it disagrees, the disagreement is recorded next to the
  finding rather than resolved in the build's favour.
- Coverage is enumerated from sources outside the code (canvas artboards,
  rulings sheet) by an agent that did not build the code.

## Residual risk this does not remove

A dispatcher chooses what to look at. Scope selection is a judgement this
session is not neutral about, so the scope is taken from the **canvas and the
rulings sheet**, not from what the build knows it implemented. Where the
dispatching session's framing could still have narrowed an auditor's attention,
that is an unremoved risk and is stated here rather than papered over.

**Prior art deliberately withheld from auditors:** `docs/redesign/
AUDIT-2026-08-29.md` and `AUDIT-FINDINGS-conformance.md` record earlier findings.
Auditors are not given these, so a re-discovery is genuine corroboration rather
than an echo. They are used only at assembly, to mark which findings are repeats.
