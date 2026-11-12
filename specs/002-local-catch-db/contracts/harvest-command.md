# Contract: `npm run harvest`

Run by the author before a release, on their PC.

```text
npm run harvest                                   all accounts found under WOW_ADDONS_DIR
npm run harvest -- friend1.lua D:/x/friend2.lua   plus friends' saved files
npm run harvest -- --reset 1415                   also reset map 1415 to the newest game version
npm run harvest -- --synthetic 3000               a random seed of 3000 places for a load test (never commit it)
```

`--synthetic <places>` reads no saved files and leaves `seed/contributions.json` alone: it writes a random
`SeedData.lua` (epoch 0) for the load test of verification.md V8, to be restored with `git checkout
OneKeyFishing/SeedData.lua`.

## Inputs

- `WTF/Account/*/SavedVariables/OneKeyFishing.lua`, two levels above `WOW_ADDONS_DIR` (`.env` or environment, as
  for `npm run link`). No accounts found is not an error when files are given.
- Extra file paths as arguments.
- `seed/contributions.json` (created when missing) and the current `OneKeyFishing/SeedData.lua` epoch.

Files are parsed, never executed; only `OneKeyFishingDB.shared.records` is read.

## Validation (per record)

Rejected, with the reason in the report, when: the file does not parse; the ID is not 8 base32 characters; `epoch`
or `seq` is not a non-negative integer; `seq` is above the record's casts (`c + m` over every cell whose counts are
counts, before any cell is skipped: the addon bumps `seq` only after a settled cast, so a higher one is made up and,
as the newest seq, would replace the owner's real record); a record has more than 20,000 distinct places (far above the world's
size; a real account only grows, so a reachable cap would keep it out for good). A rejected record is left out
whole; the other records of the file are still used. A cell whose place key does not match
`^%d+:[0-4]:(%d%d|x)$` or that breaks a rule from data-model.md ("Validation") is skipped with a note: cells only
grow, so rejecting the record would keep the whole account out of every later seed. A build that is not
`digits.digits.digits` (the addon records `"unknown"` when the game gives no version) is skipped with a note in
the report; the record's other builds are used.

## Merge

- Key `id@epoch`; an incoming record replaces the stored one only when its `seq` is higher.
- `--reset <mapID>` stores `resets[mapID] = newest build`; from then on cells of that map from older builds are left
  out of the sums.
- Sums: every stored contribution, every build except reset ones, cell by cell; `k` counts the contributor IDs
  that caught something in a cell (records of several epochs of one ID count once). A stored cell keeps only the
  fields the client reads (`c`, `m`, `t`, `px`, `py`, `i`, `p`); the casting limit counts the seconds of game
  versions only. `absorbed[id][epoch]` = the stored seq of every unit
  `id@epoch`: a client keeps a newer seq of a unit (a copy the author's client got before the owner's newest one)
  and passes it on, so the rest reaches the next harvest instead of being deleted.

## Output

- `OneKeyFishing/SeedData.lua` (contracts/seed-data.md) with the epoch one above the higher of the store's and
  the current seed's (it never repeats or goes back), and the updated
  `seed/contributions.json`. Nothing is written when the seed would exceed 1 MB (exit code 1). When the sums,
  `absorbed` and `resets` come out as in the current seed, `SeedData.lua` and its epoch stay as they are ("Nothing
  new"); only the contributions file is updated.
- `--reset <mapID>` with no contribution that has a game version yet is an error (exit code 1).
- Report on stdout:

```text
Harvest: 3 file(s), 5 record(s) read, 1 rejected
  skipped   k3m9q2xa cell 1415:3:47: 900 casts in 120 s of casting
  rejected  friend2.lua p7d2...: seq 4000 is above the record's 310 casts
Contributions: 4 (each <id>@<epoch> once, its newest seq)
New places: 37   New items: 5   Places in total: 412
Reset: map 1415 (data before 1.60.2 left out)
Wrote OneKeyFishing/SeedData.lua: epoch 4, 212 KB
```

A run whose sums come out unchanged ends with `Nothing new: OneKeyFishing/SeedData.lua stays at epoch 4` instead
of the `Wrote` line.

Exit code 0 when the files were written, 1 on a configuration error or when the size limit is exceeded.

## Part 3 additions (`specs/004-public-channel-sync`)

```text
npm run harvest -- --block <id> "why"             leave contribution ID <id> out of the seed (FR-019)
npm run harvest -- --unblock <id>                 take it back
```

- **Validation**: a record also needs a `proof` of 16 base32 characters, and holds at most 180 s of casting per step
  of its seq. A newer version of a stored unit must continue the stored one's chain (its proof, stepped down to the
  stored seq, is the stored proof); a version that does not is rejected and reported, and the stored one stays.
  Two versions of a unit that are not on one chain, whichever seq is higher (also a lower one met after a higher
  one), make the unit disputed, since the one met first may be the made-up one: `seed/contributions.json` keeps it
  in `disputed` (unit -> the file that showed it), every report has a `Disputed: <id>@<epoch>` line, and the unit
  is left out of the seed (no sums, not in `absorbed`, no proof) for good, since the version stored may be the
  made-up one (the owner's next epoch is a new unit). The seed's `build`, and the version a `--reset` cuts a map
  off at, come only from the contributions that reach the seed (not blocked, not disputed).
- **Merge**: `seed/contributions.json` keeps `blocked` (ID -> the author's note). A blocked ID is in no sum and not
  in `absorbed`; the seed carries `blocked` and the `proofs` of the absorbed versions.
- **Weights**: from five contributors at a cell on, no contribution carries more than a fifth of the cell; its counts
  are scaled down and rounded within the cell rules (research R7 of part 3): catches and items by catches, misses by
  casts, and the catches weighted by casts as the cell's `x` when they differ from `c`.
- **Report**: an `outlier` line per contribution whose numbers look odd next to the others' (research R11 of part
  3), and the `--block` command to use. The author decides; nothing is blocked by itself.
