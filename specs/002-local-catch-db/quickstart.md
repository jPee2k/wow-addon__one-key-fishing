# Quickstart: validating the Local Catch Database

## Automated

```text
npm install
npm run check      # also: SeedData.lua parses, has the seed fields, is at most 1 MB; seed/ is in .pkgmeta ignore
npm test           # catchdb, prices, catchhere, harvest tests plus the existing ones
npm test -- catchdb
```

Expected: both pass. The tests cover the place key (FR-001 to FR-003), recording and the pool part (FR-004,
FR-007), counting once with the seed and the epoch reset (FR-019), the fallback and filters (FR-012 to FR-015), the
robust price (FR-025 to FR-027) and the harvest merge, validation, reset and size limit (FR-021 to FR-024).

## Harvest dry run

`tests/harvest_test.mjs` builds its fixtures in a temporary folder (a fake `WTF` tree with two accounts, a friend's
file and a broken file; a broken `.lua` file cannot live in `tests/`, where `npm run check` parses every Lua file)
and runs the harvest with an output folder in that temporary folder. Expected: the report lists the broken file as
rejected; the seed is written with `epoch + 1`; a second run with the same files gives the same sums.

Against real data: `npm run harvest` with `WOW_ADDONS_DIR` set; check the report and `git diff
OneKeyFishing/SeedData.lua`.

## In game

The in-game steps live in `docs/checklists/`: [spike.md](../../docs/checklists/spike.md) prints the game facts
(V1-V7) with `/okf spike`, then [catch-database.md](../../docs/checklists/catch-database.md) checks the feature; the order of everything is
`docs/release-plan.md`.
