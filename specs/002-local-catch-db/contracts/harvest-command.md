# Contract: `npm run harvest`

Run by the author before a release, on their PC.

```text
npm run harvest                                   all accounts found under WOW_ADDONS_DIR
npm run harvest -- friend1.lua D:/x/friend2.lua   plus friends' saved files
npm run harvest -- --reset 1415                   also reset map 1415 to the newest game version
```

## Inputs

- `WTF/Account/*/SavedVariables/OneKeyFishing.lua`, two levels above `WOW_ADDONS_DIR` (`.env` or environment, as
  for `npm run link`). No accounts found is not an error when files are given.
- Extra file paths as arguments.
- `seed/contributions.json` (created when missing) and the current `OneKeyFishing/SeedData.lua` epoch.

Files are parsed, never executed; only `OneKeyFishingDB.shared.records` is read.

## Validation (per record)

Rejected, with the reason in the report, when: the file does not parse; the ID is not 8 base32 characters; `epoch`
or `seq` is not a non-negative integer; a build is not `digits.digits.digits`; a place key does not match
`^%d+:[0-4]:(%d%d|x)$`; a cell breaks a rule from data-model.md ("Validation"); a record has more than 2,000 cells.
A rejected record is left out whole; the other records of the file are still used.

## Merge

- Key `id@epoch`; an incoming record replaces the stored one only when its `seq` is higher.
- `--reset <mapID>` stores `resets[mapID] = newest build`; from then on cells of that map from older builds are left
  out of the sums.
- Sums: every stored contribution, every build except reset ones, cell by cell; `k` counts the contributions in a
  cell. `absorbed[id]` = the highest stored epoch of that ID.

## Output

- `OneKeyFishing/SeedData.lua` (contracts/seed-data.md) with `epoch + 1`, and the updated
  `seed/contributions.json`. Nothing is written when the seed would exceed 1 MB (exit code 1).
- Report on stdout:

```text
Harvest: 3 file(s), 4 record(s) read, 1 rejected
  rejected  friend2.lua k3m9... cell 1415:3:47: 900 catches in 120 s of casting
New places: 37   New items: 5   Places in total: 412
Reset: map 1415 (data before 1.60.2 left out)
Wrote OneKeyFishing/SeedData.lua: epoch 4, 212 KB
```

Exit code 0 when the files were written, 1 on a configuration error or when the size limit is exceeded.
