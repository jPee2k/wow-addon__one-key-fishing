# Publishing

How a release is built and published, and what it is checked against.

## Branches

- `develop`: all work happens here. Every push is checked and tested by GitHub Actions.
- `main`: released code only. It changes only by merging `develop` (a pull request that needs the green
  `check` job), and release tags go on `main` commits only; the release workflow refuses a tag that is not
  on `main`.

## Releasing a version

1. On `develop`, update `version` in `package.json` and add a matching `## [x.y.z] - date` entry at the top of
   `CHANGELOG.md`. Changes waiting for a release are collected under `## [Unreleased]`; move them into the
   version entry and remove that heading, because the packager shows the whole file on the CurseForge file
   page and the release workflow stops while the heading is there.
2. `npm run check` and `npm test`, test in game (`npm run install-addon`), commit and push `develop`.
3. Open a pull request `develop` -> `main` and merge it once the `check` job is green.
4. On the updated `main`, tag the merge commit with the bare version (`git tag 1.0.0`, no `v`) and push the
   tag (`git push origin 1.0.0`). GitHub Actions (`.github/workflows/release.yml`) runs the checks and tests,
   checks that the tag is on `main`, matches `package.json` and the changelog has no `Unreleased` section,
   then BigWigsMods/packager builds the zip with `.pkgmeta`, creates a GitHub release and uploads to
   CurseForge. The packager replaces keywords such as `@project-version@` in every packaged file, not only in
   the TOC; `npm run check` keeps them out of the addon's Lua and XML files, and the local build fills in the
   version the same way. Without `## X-Curse-Project-ID` in the TOC or the `CF_API_KEY` secret, only the
   GitHub release is made.
5. Without the workflow: `npm run build` refuses uncommitted changes, runs the checks and tests, and packages
   the commit into `dist/OneKeyFishing/` and `dist/OneKeyFishing-x.y.z.zip`, which can be uploaded to
   CurseForge by hand.

## One-time setup (author)

- [x] Create the GitHub repository and push `develop`.
- [x] Create `main` from `develop`, make it the default branch and protect it (pull requests only, the
      `check` job required, no force pushes or deletion).
- [x] Create the CurseForge project "OneKeyFishing" (ID 1761796, https://www.curseforge.com/wow/addons/onekeyfishing),
      category Professions, license MIT, description from `README.md`.
- [ ] Add a few screenshots to the CurseForge project (indicator, statistics, settings, minimap menu).
- [x] Add `## X-Curse-Project-ID: <id>` and `## X-Website: <CurseForge project page URL>` to
      `OneKeyFishing/OneKeyFishing.toc` (the website is the page players install from, not the repository).
- [x] Create a CurseForge API token and add it as the `CF_API_KEY` secret of the GitHub repository.
      `GITHUB_TOKEN` is provided by GitHub Actions automatically.
- [x] Game version: CurseForge lists WoW Forever (game version type 88568; other Forever addons use the beta
      version 1.60.1). BigWigsMods/packager v2.6.1 maps `## Interface: 16???` to Forever and 16001 to
      `1.60.1`; without an exact match it takes the closest lower Forever version and warns. Check the game
      version on the first uploaded file; if the upload fails, upload the zip from `npm run build` by hand and
      pick the game version on the website.

## Blizzard UI Add-On Development Policy

| Requirement | OneKeyFishing |
|---|---|
| Free of charge, no paid features | Yes, MIT licensed, nothing is locked |
| Code is not obfuscated | Plain, readable Lua |
| No in-game advertising or donation requests | None |
| No collection of personal data, no traffic outside the game | None; saved variables stay on the player's computer |
| No automation: every action needs a hardware event | Cast, hook, lure and open happen only on a key press, through a secure action button and override bindings. Nothing reacts to the bobber splash by itself, no sounds are monitored |
| Must not hurt realm performance | Auction searches run one at a time, wait for the throttle and time out |

## CurseForge packaging requirements

| Requirement | How it is met |
|---|---|
| A zip with one top-level folder named like the TOC | `OneKeyFishing/OneKeyFishing.toc` (`tools/build.mjs`, `.pkgmeta`) |
| No executables or unrelated files | Only the TOC, the files it lists, `Bindings.xml`, `LICENSE`, `README.md`, `CHANGELOG.md` (`tools/addon.mjs`; the `ignore` list in `.pkgmeta`, kept complete by `npm run check`) |
| TOC metadata | `Interface`, `Title`, `Notes`, `Author`, `Version` (filled in at build time), `X-License`, `IconTexture`, Addon Compartment functions |
| A license | `LICENSE` (MIT) |
| A changelog for the file page | `CHANGELOG.md` (packager `manual-changelog`) |
