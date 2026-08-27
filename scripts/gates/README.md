# Executable gates

**A law that is not an exit code is not a law.**

This directory is the enforcement layer for the rules this project already had
written down. Those rules were correct and were ignored anyway, because the only
thing enforcing them was a model deep in a long build that wanted to finish.
Prose cannot fail a build. This can.

```bash
python3 scripts/gates/run.py              # run everything
python3 scripts/gates/run.py --gate forks # run one
python3 scripts/gates/run.py --json       # machine-readable
python3 scripts/gates/run.py --accept     # baseline current findings (deliberate)
```

Exit `0` = clean. Exit `1` = at least one un-baselined failure. Exit `2` = the
harness itself is misconfigured.

No dependencies. Python 3.9+. Runs in CI (`.github/workflows/gates.yml`), in a
pre-commit hook, and by any agent working in this repo.

## The gates

| gate | what it refuses to let through | the bug it exists for |
|---|---|---|
| `deferrals` | a comment that names a gap and defers it | three of the worst shipped defects in the WAWU build were correctly described in a comment **by the agent that created them** |
| `fake_data` | production code importing or referencing a mock/demo/seed source | fixture data flowing through the real read path is what makes a disconnected app look connected |
| `wire_types` | a response shape declared outside the data layer | a client typed `{items}` against an endpoint returning a bare array; every test that mocked the client's own type passed |
| `forks` | one class/enum name declared in two files | a forked `ErrorState` made every 403 read as "check your connection" |
| `hardcoded_signals` | a constant standing in for a runtime source; raw colour outside the token layer | `bool get isOnline => true` — a beautifully designed offline state no user can ever reach |
| `dead_controls` | an empty or null handler on an interactive control | the user taps, nothing happens, they conclude the app is broken, and they are right |
| `pipeline_open_items` | unresolved `stubs.json` / open `ui-align-tasks.json` / non-empty `conflicts.json` | the skills already called these HALT CONDITIONS; 31 items were open and nothing halted |

## Adding a gate

One module in `checks/`, named to match its key in `gates.config.json`, exposing
`run(ctx) -> Iterable[Finding]`. `ctx` gives you `source_files()`, `lines()`,
`rel()` and `is_test()`; you do not touch paths or config directly.

Keep new gates **quiet**. A gate that cries wolf is a gate somebody switches off,
and a switched-off gate is worse than no gate because it looks like coverage.
When a pattern is ambiguous in ordinary code, require a second signal before
firing — see the two-tier structure in `checks/deferrals.py`, where "the real
implementation" only counts as a deferral if a temporal marker sits beside it.

## The baseline

`baseline.json` holds findings that have been explicitly accepted. A baselined
finding prints as ACCEPTED and does not fail the build.

This is what "deferred by the user" means here: **a line in a file, with an owner
and a reason, that a machine reads** — never a sentence in a report nobody
re-opens. `check_baseline.py` fails CI if any entry lacks either one.

Adopting a legacy repo: run `--accept` once, then delete entries as you fix them.
The ratchet only turns one way — new violations always fail.

## For agents working in this repo

Run the gates **before** you report any work as done. "Tests pass" is not done.
"It compiles" is not done. Green gates plus green tests plus an observed render
is done.

If a gate fires on something you believe is correct, you have exactly two legal
moves: fix the code, or add a baseline entry with your reasoning. Editing a gate
to stop it firing on your own change is not one of them.
