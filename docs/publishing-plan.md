# Plan: preparing 1.0.0 for publication

## Context

The addon was finished and tested in game, but it was written as a personal tool: documents and comments
mentioned that it was "for myself", a ruRU client, a beta and a friend; part of the text was not in English;
the TOC held an e-mail address. Code from the API spike (the old debug report) and a migration from
version 0.1 were still there.

Goal: a clean public release **1.0.0** for **WoW Forever (Interface 16001), any client language**, with an
English interface. It meets the CurseForge requirements and Blizzard's UI Add-On Policy, builds with one
command on Windows, macOS and Linux, and can be published from GitHub automatically. The addon's behavior
does not change: no new features and no regressions.

Decisions:
- Forever only.
- The debug report is reduced to what a bug report needs.
- MIT license, `## Author: jPee`.
- Node.js tools: `npm run check`, `npm run dev`, `npm run build`, `npm run install-addon`.
- `.pkgmeta` and a GitHub Actions workflow now.
- Interface strings move to `Locales/enUS.lua` now.
- The old Ukrainian `PLAN.md` is translated into `docs/history/mvp-plan.md`.
- Improvements: saved variables schema version, the addon version in the UI, `/fish` replaced by
  `/onekeyfishing`, CHANGELOG.
- `CLAUDE.md` stays in the repository but not in the package.

Layout (changed during the work at the author's request): the addon lives in its own `OneKeyFishing/`
folder, separate from the tools and docs in the repository root. `npm run link` links that folder into the
game for development without building; `.pkgmeta` uses `move-folders` to package it.

## Stage 1. Tools (first, so the later stages can be checked)

- `package.json` (private, `version` is the single source of the version), dev dependencies `luaparse` and
  `fflate` (pure JS zip).
- `tools/check.mjs`: Lua 5.1 syntax; undeclared globals and declared but unused ones against `.luacheckrc`;
  lines up to 120 characters; ASCII-only addon files and no Cyrillic anywhere; TOC files exist and every
  Lua file is listed; locale keys in sync; `package.json` version equals the newest `CHANGELOG.md` entry.
- `tools/build.mjs`: the package is the TOC, the files it lists, `Bindings.xml`, `LICENSE`, `README.md` and
  `CHANGELOG.md`. `--dev` packages the working folder as `x.y.z-dev+<commit>`; `--release` refuses
  uncommitted changes and packages `HEAD`. Output: `dist/OneKeyFishing/` and
  `dist/OneKeyFishing-<version>.zip` with one top-level folder. `@project-version@` in the TOC is filled in by
  this tool and by BigWigsMods/packager alike.
- `tools/install.mjs`: copies `dist/OneKeyFishing` into `WOW_ADDONS_DIR` (environment or a git-ignored
  `.env`, see `.env.example`), replaces only that folder, refuses paths that are not `.../Interface/AddOns`,
  that contain the repository, or that are a link.
- `tools/link.mjs` (`npm run link` / `npm run unlink`): a junction (Windows) or symbolic link from the game's
  AddOns folder to `OneKeyFishing/`; it never deletes a real folder.

## Stage 2. Personal details out, everything in English

- TOC: no e-mail; `## Author`, `## Version: @project-version@`, `## X-License: MIT`; `X-Website` and
  `X-Curse-Project-ID` once the GitHub and CurseForge projects exist.
- Code comments that named a specific client language now say "any language".
- `CLAUDE.md` describes a public project, the npm tools, `docs/`, locales and migrations.
- `PLAN.md` -> `docs/history/mvp-plan.md` (English, with the API spike results).
- `README.md`: installation (CurseForge app or zip), `/onekeyfishing`, reporting bugs, development, license.

## Stage 3. Dead code

- The 0.1 gear snapshot migration in `Gear.lua`.
- `Debug.lua` becomes a bug report: versions and locale, mode state and keys, Fishing spell and skill, gear,
  lure, pending restore, fished items in bags, game and addon settings. The API spike probes are gone.
- `.luacheckrc` lists only the globals the code uses (enforced by `npm run check`).

## Stage 4. Strings in `Locales/enUS.lua`

- `ns.L`, keyed by the English text, falling back to the key. Loaded first in the TOC.
- Every visible text goes through `L`: chat messages, notifications, indicator labels, settings, statistics,
  tooltips, menus, popups, key binding names, rank names. Colors stay outside the strings.
- The debug report stays English on purpose (it is read by the developer).

## Stage 5. Improvements without new features

- Saved variables schema version with an ordered migration list in `Core.lua`; data from a newer version is
  left alone with a warning.
- The addon version in `/okf`, the minimap tooltip, the settings title and the debug report.
- `/fish` replaced by `/onekeyfishing` (`/okf` stays).
- `CHANGELOG.md` (Keep a Changelog) and `LICENSE` (MIT).

## Stage 6. CurseForge, Blizzard policy and automatic publishing

- `.pkgmeta` and `.github/workflows/release.yml` (checks on every push; a version tag builds and uploads).
- `.gitattributes`: LF line endings, development files excluded from `git archive`.
- `docs/publishing.md`: the release steps, one-time setup and the policy and packaging checklists.

## Stage 7. `docs/`

- `docs/publishing-plan.md` (this plan), `docs/ROADMAP.md`, `docs/publishing.md`, `docs/history/mvp-plan.md`.

## Verification

- `npm run check` passes.
- `npm run dev` produces only the addon files, the zip has one top-level folder and the TOC has a version.
- `npm run build` refuses a dirty tree and packages `HEAD` when clean.
- `npm run install-addon` installs into the game.
- In game, a full regression run: mode and key (cast, hook, loot); gear (including leaving the mode during a
  cast), lures, containers (including full bags); statistics and timer, auction scan, minimap and menu,
  settings; `/reload` in the mode, combat; all texts look as before; the version is shown; `/fish` is gone and
  `/onekeyfishing` works; `/okf debug` shows the short report; no Lua errors.
