# Kudimata Securities — mobile

Flutter investment app for the Nigerian market (NGX). Talks to
`../Kudimata-Securities-Backend` (NestJS + Prisma + Postgres).

## Before you report anything as done

```bash
python3 scripts/gates/run.py
flutter test
```

**Both green, or it is not done.** These are not style checks — each gate is a
production defect this project has actually shipped, turned into an exit code.
Read `scripts/gates/README.md` for what each one refuses to let through.

If a gate fires on your change you have two legal moves: fix the code, or add an
entry to `scripts/gates/baseline.json` with your name and your reasoning. Editing
a gate so it stops firing on your own change is not one of them.

## What "done" means here

In order, weakest evidence to strongest:

1. It compiles — **not done**
2. Unit tests pass against mocks — **not done**
3. Gates green — necessary, still not done
4. The screen renders with real data from the real backend, reached through the
   real login flow, and a value that exists *only* on the server is visible —
   **done**

Level 2 is where this project has repeatedly declared victory and shipped
broken software. `test/fixtures/mock_api_adapter.dart` means the whole suite can
be green while the app cannot reach its backend at all.

## Layout

```
lib/
  app/         app_state.dart — session, hydration, top-level state
  data/
    api/       api_client.dart, auth_token_store.dart, passcode_store.dart
    repositories/  one per resource; the ONLY place wire shapes are parsed
  router/      go_router config
  screens/     one directory per feature area
  theme/       tokens.dart — the only place raw colours may appear
  widgets/     shared component library; never fork one, add a prop
test/          unit + render tests (mocked backend)
scripts/gates/ executable build laws
```

## Rules with teeth

Each of these is enforced by a gate, so it does not depend on anyone remembering it:

- **Wire shapes live in `lib/data/`.** A screen never writes `fromJson`.
- **Never fork a widget.** A variant is a prop. Two copies is two truths that drift.
- **No mock/demo data outside `test/`.** Fixture data on a real read path is how a
  disconnected app looks connected — the hardest defect for a human to catch by eye.
- **No raw `Color(0xFF…)` outside `lib/theme/`.** The token layer is the source.
- **No comment that names a gap and defers it.** If you found it, it is a task,
  not a note. Prose is not a resolution.
- **No empty handlers.** A control that does nothing is worse than an absent one.

## Design source of truth

The design canvas is committed at `docs/design/` and **it wins**. When the design
implies data the backend does not serve, the backend changes — the screen does
not get quietly reshaped to fit what the API happens to return. File the gap;
do not compromise the design on your own authority.

## Housekeeping

- Version lives in `pubspec.yaml`; CI bumps the build number on push to main.
- Release APK/AAB via a `v*` tag (`.github/workflows/release-apk.yml`).
- iOS ships via `ios.yml` (Fastlane + Match). Web is built locally, not in CI.
