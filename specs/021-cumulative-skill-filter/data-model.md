# Data Model: Cumulative Skill Filter

**Feature**: [spec.md](spec.md) | **Research**: [research.md](research.md)

Nothing stored changes: no saved field, no cell field, no record or seed field, no `DB_SCHEMA` bump. The model below
is the filter and the view as the code reads them.

## Skill range (unchanged)

A recorded place key `<mapID>:<range>:<cell>`; `range = min(MAX_RANGE, floor(rank / RANGE_STEP))`, `RANGE_STEP = 75`,
`MAX_RANGE = 4`: 0 = 0-74, 1 = 75-149, 2 = 150-224, 3 = 225-299, 4 = 300+.

## Skill filter value (`filter.range`)

| Value | Menu text | Button text | Lists sum ranges | Misses from range |
|---|---|---|---|---|
| `0` | Up to 74 | Skill: Up to 74 | 0 | 0 |
| `1` | Up to 149 | Skill: Up to 149 | 0, 1 | 1 |
| `2` | Up to 224 | Skill: Up to 224 | 0, 1, 2 | 2 |
| `3` | Up to 299 | Skill: Up to 299 | 0, 1, 2, 3 | 3 |
| `"all"` | All (300+) | Skill: All | 0 to 4 | 4 |

- The menu adds " (yours)" (whole texts `"Up to %d (yours)"`, `"All (%d+) (yours)"`) to the value
  `CatchDB.SkillFilter(CatchDB.RangeOf(rank))`, read from the Fishing rank (also where the game gives no map); no
  mark without Fishing.
- `4` is not a value: `CatchDB.SkillFilter(4)` is `"all"`; `Ranges` reads a stray `4` as `"all"`.

**Defaults**: "What can be caught here": `SkillFilter(ownRange)` until a value is picked by hand (kept until
`/reload`); the catalog: `"all"`; the minimap lines: `SkillFilter(ownRange)`; the item tooltips: `"all"`.

## View (`CatchDB.Query`), changed fields

| Field | Before | Now |
|---|---|---|
| `items`, `catches`, `players`, `littleData`, `scope`, `area`, `point`, bonus tags | sums of one range (or all) | sums of the cumulative ranges |
| `missRate` | the view's sum | the chosen range's sum at the same scope (`MissRange`: the range, or 4 for `"all"`); nil under a water filter |
| `missLittleData` | (new) | true when that sum's raw casts are below `LITTLE_DATA` (50) |

`CatchDB.QueryMap` and `CatchDB.QueryCells` views: the same cumulative sums; `missRate = nil` (no caller shows it).

## Validation

- `filter.range` is one of `0`..`3` or `"all"`; anything else is a programming error caught by the tests.
- The miss sum uses the same `sources` as the list (source, reset, water, bonus), so a miss rate never mixes another
  source or filter in.
