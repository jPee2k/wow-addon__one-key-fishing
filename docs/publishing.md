# Publishing

How a release is built and published, and what it is checked against.

## Releasing a version

1. Update `version` in `package.json` and add a matching `## [x.y.z] - date` entry at the top of
   `CHANGELOG.md`. Changes waiting for a release are collected under `## [Unreleased]`; move them into the
   version entry and remove that heading, because the packager shows the whole file on the CurseForge file
   page and the release workflow stops while the heading is there.
2. `npm run check` and `npm test`, test in game (`npm run install-addon`), commit.
3. `npm run build` refuses uncommitted changes, runs the checks and tests, and packages the commit into
   `dist/OneKeyFishing/` and `dist/OneKeyFishing-x.y.z.zip`. This zip can be uploaded to CurseForge by hand.
4. Or tag the commit with the bare version (`git tag 1.0.0`, no `v`) and push the tag. GitHub Actions
   (`.github/workflows/release.yml`) runs the checks and tests, checks that the tag matches `package.json`,
   then BigWigsMods/packager builds the zip with `.pkgmeta`, creates a GitHub release and uploads to
   CurseForge. The packager replaces keywords such as `@project-version@` in every packaged file, not only in
   the TOC; `npm run check` keeps them out of the addon's Lua and XML files, and the local build fills in the
   version the same way.

## One-time setup (author)

- [ ] Create the GitHub repository and push `main`.
- [ ] Create the CurseForge project "OneKeyFishing" (check that the name is free), category Professions,
      license MIT, description from `README.md`, a few screenshots (indicator, statistics, settings, minimap menu).
- [ ] Add `## X-Curse-Project-ID: <id>` and `## X-Website: <GitHub URL>` to `OneKeyFishing/OneKeyFishing.toc`.
- [ ] Create a CurseForge API token and add it as the `CF_API_KEY` secret of the GitHub repository.
      `GITHUB_TOKEN` is provided by GitHub Actions automatically.
- [ ] **Risk**: the addon sits in a subfolder (`move-folders` in `.pkgmeta`, the same layout DBM uses), and
      CurseForge and the packager must know WoW Forever as a game version and map
      `## Interface: 16001` to it. Check after the game launches (November 4, 2026). If the automatic upload
      fails, upload the zip from `npm run build` by hand and pick the game version on the website.

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
