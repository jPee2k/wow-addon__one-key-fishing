# OneKeyFishing Constitution

## Core Principles

### I. Blizzard Policy Compliance (NON-NEGOTIABLE)

The addon MUST stay within Blizzard's UI Add-On Development Policy at all times.

- Every game action (cast, hook, apply lure, use or open an item, equip) MUST happen on a real
  key press, through secure action buttons and override bindings.
- The addon MUST NOT react by itself to game events that would replace a player decision: no
  automatic hook on the bobber splash, no sound monitoring, no timed or chained actions.
- No external tools, no traffic outside the game, no collection of personal data, no
  advertising, no paid or locked features, no obfuscated code.
- Server-facing work (auction searches) MUST run one request at a time, respect the throttle
  and time out.

Rationale: a policy breach can get the addon removed or players banned; no feature is worth it.

### II. Language-Independent Game Data

The game client can run in any language, so the addon MUST NOT depend on localized names.

- Spells, items, skill lines, game objects and zones MUST be matched by ID, never by name.
- Where only localized text exists (tooltips), parsing MUST derive the needle from the client's
  own localized data and MUST tolerate case changes in non-ASCII text.
- Every visible string MUST go through `ns.L` with a literal English key; color codes stay
  outside the strings; enUS keys and code usage MUST stay in sync. The only deliberate
  exceptions are shown as they are, without `ns.L`: the debug report, language names written in
  their own language (the language setting), and the addon name "OneKeyFishing" with its
  version string.
- English is the development language: code, comments, docs, specs, commit messages, branch
  names and pull requests are written in English, whatever language the conversation is in.
  The only exceptions are the translations and language names written in their own language
  (`docs/languages.md`).

Rationale: a fishing addon that works only on English clients fails most of its audience silently.

### III. Safe, Restorable State

Fishing mode changes the player's settings, gear and camera; the player MUST always get them back.

- Every change (CVar, equipped slot, camera, mode flag) MUST be recorded in saved variables
  *before* it is applied, so exit, logout, `/reload`, disconnects and crashes all restore it.
- Only what the addon changed is restored, and only while it still holds what the addon put
  there.
- Combat rules MUST be honoured: protected changes wait until combat ends; weapons return at once.
- A renamed, moved or reshaped saved field MUST bump `DB_SCHEMA` with a migration; defaults fill
  missing keys without overwriting player data.

Rationale: leaving a player with a fishing pole in hand or a changed CVar after a crash is a
worse bug than any missing feature.

### IV. Verified Forever API

The target is WoW Forever (Interface `16001`), which runs the Mainline API.

- Only API calls known to exist on Forever may be relied on; facts verified in game are recorded
  in `CLAUDE.md` ("Known API facts") and MUST be updated when a new one is learned.
- Calls with uncertain behaviour MUST be guarded and degrade gracefully, never error at load.
- Every new WoW API global MUST be added to `.luacheckrc` `read_globals`.
- Behaviour that only the game can show MUST be handed to the user with an in-game test
  checklist; it is not called verified until the user confirms it.

Rationale: Forever mixes classic content with the modern client; guessing the API leads to
silent failures that tests cannot catch.

### V. Checked and Tested Changes

- `npm run check` and `npm test` MUST pass after every change and before every commit.
- Logic that can run without the game (Core, Bags, Catch, Stats, Prices, statistics window
  logic) MUST get a new or extended test in `tests/` when it changes; stubs live in
  `tests/wow.lua`.
- Addon code MUST stay Lua 5.1 compatible and free of 5.1/5.3 differences; a failure caused only
  by fengari's Lua 5.3 is fixed in the test or the stub, not by bending the addon.

Rationale: the game cannot be run in CI, so the automated checks are the only gate before a
player sees the code.

### VI. Simple Module Boundaries

- All files share the addon namespace (`local _, ns = ...`); the TOC order is the load order,
  and a module MAY call a later module only at runtime.
- Modules communicate through `ns.On` / `ns.Fire` messages and documented functions; a new
  message MUST be listed in `CLAUDE.md`.
- Prefer the smallest change that solves the problem; new settings, frames or abstractions need
  a concrete player need, not a hypothetical one.

Rationale: a small addon stays maintainable only while each module has one clear job.

## Technical Constraints

- Shipped files live in `OneKeyFishing/` and are exactly the TOC, the files it lists and
  `Bindings.xml`; the package adds only `LICENSE`, `README.md` and `CHANGELOG.md`.
- Lua, TOC and XML files are ASCII-only and lines are at most 120 characters. Translation
  files (`Locales/<code>.lua` other than `enUS.lua`) are the exception: UTF-8 text in its own
  language.
- Addon Lua and XML MUST NOT contain packager keywords (`@project-version@`, `--@debug@` blocks).
- Every repository root entry is either packaged or listed in the `.pkgmeta` `ignore` list.
- Tooling requires Node.js 18+; `npm run check` enforces the rules above.

## Development Workflow

- Work happens on `develop`; `main` changes only by merging `develop` through a pull request
  with a green `check` job. Nothing is pushed directly to `main`.
- `package.json` version MUST equal the newest `CHANGELOG.md` entry; unreleased changes are
  collected under `## [Unreleased]`, which MUST be removed before a release.
- A release is a bare version tag (`1.0.0`) on a `main` commit; the release workflow builds and
  publishes it. Steps and the policy checklist live in `docs/publishing.md`.
- Player-facing changes update `README.md` and `CHANGELOG.md`; architecture changes update
  `CLAUDE.md`; planned features go into `docs/ROADMAP.md`, finished plans into `docs/history/`.

## Governance

This constitution supersedes other practices where they conflict; `CLAUDE.md` holds the runtime
development guidance and MUST stay consistent with it.

- Amendments are made through `/speckit-constitution`, reviewed by the project author and
  committed together with any guidance files they affect.
- Versioning follows semantic versioning: MAJOR for removing or redefining a principle, MINOR
  for a new principle or section or materially expanded guidance, PATCH for clarifications.
- Every spec, plan and review MUST check compliance with the principles above; a deviation
  MUST be justified in the plan's complexity tracking, and Principle I allows no deviation.

**Version**: 1.2.1 | **Ratified**: 2026-10-24 | **Last Amended**: 2026-10-24
