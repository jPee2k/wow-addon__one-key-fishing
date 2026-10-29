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
or `seq` is not a non-negative integer; a record has more than 20,000 distinct places (far above the world's
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
- Sums: every stored contribution, every build except reset ones, cell by cell; `k` counts the contributor IDs in
  a cell (records of several epochs of one ID count once). `absorbed[id]` = the highest stored epoch of that ID.

## Output

- `OneKeyFishing/SeedData.lua` (contracts/seed-data.md) with the epoch one above the higher of the store's and
  the current seed's (it never repeats or goes back), and the updated
  `seed/contributions.json`. Nothing is written when the seed would exceed 1 MB (exit code 1). When the sums,
  `absorbed` and `resets` come out as in the current seed, `SeedData.lua` and its epoch stay as they are ("Nothing
  new"); only the contributions file is updated.
- `--reset <mapID>` with no contribution that has a game version yet is an error (exit code 1).
- Report on stdout:

```text
Harvest: 3 file(s), 4 record(s) read, 1 rejected
  rejected  friend2.lua k3m9... cell 1415:3:47: 900 catches in 120 s of casting
New places: 37   New items: 5   Places in total: 412
Reset: map 1415 (data before 1.60.2 left out)
Wrote OneKeyFishing/SeedData.lua: epoch 4, 212 KB
```

Exit code 0 when the files were written, 1 on a configuration error or when the size limit is exceeded.
