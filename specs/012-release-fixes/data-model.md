# Data Model: Release Fixes for 1.2.0

No saved field changes shape: no `DB_SCHEMA` bump, no migration. Every state below lives for the session.

## Bobber answer (`Core/Data.lua`, read by `UI/Indicator.lua`)

| Soft target | `targeted` | `known` |
|---|---|---|
| none | false | true |
| a readable GUID of the bobber object | true | true |
| a readable GUID of anything else | false | true |
| a secret GUID | false | false |

Rule: the indicator warns "No bobber" only when `known` is true (R1).

## Skipped lure (`Fishing/Bags.lua` `skippedLures`)

| Field | Before | After |
|---|---|---|
| `skippedLures[itemID]` | `true` | the Fishing skill when the game refused it (0 when not known) |

Transitions:
- Refused: set to the current skill.
- `SKILL_LINES_CHANGED`: cleared when the stored value is below `GameData.Lures[itemID].skill` and the skill now
  meets it.
- `MODE_CHANGED` (on): every entry cleared, as today.

## Other players' data (`UI/CatchHere.lua`)

- A view of `CatchDB.Query` gains `others`: true when an ID with a catch in the sum has a part, which only other
  players' records have.

## Texts (`Locales/*.lua`, nine translations each)

| Key | Where |
|---|---|
| `"No bundled data in this version."` (new) | "What can be caught here", with other players' data held |
| `"Exchange: 1 player, %s ago"` (new) | the exchange status line for one player |
