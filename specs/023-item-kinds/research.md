# Research: New Item Kinds and the Trophy Collection

Decisions for the plan of spec 023. The game facts are in
[docs/extravaganza-research.md](../../docs/extravaganza-research.md), section 9.

## R1. The lists by ID, no in-game check

- **Decision**: list all 36 trophies and the 12 quest items by ID in `GameData/ItemKinds.lua`; add the class rule
  `["12"] = "quest"`. No `VERIFY` marker.
- **Rationale**: the IDs, names and classes come from the client's own item tables (`ItemSparse` / `Item`, build
  1.60.1.71037). 15 / 0 is shared with chests and the contest's rare fish, so the class alone cannot tell a trophy
  (spec 014's finding). A wrong kind is harmless and fixed by the list, as spec 014 accepted.
- **Alternatives**: the `InventoryType` 23 (held in the off hand) as the rule: rejected, it leaves out 12 trophies the
  author wants in the kind, and the instant info is not loaded for every item. The name ("N Pound"): forbidden
  (Principle II).

## R2. Which items move

- **Decision**: the trophies listed today as "fish" (6292, 6294, 6295, 6309, 6310, 6311, 6363, 13876-13879,
  13882, 13883, 13885, 13886, 13901, 13907-13910, 13914, 13915) become "trophies"; the 14 not yet listed
  (6364, 13880, 13884, 13887, 13902-13906, 13911-13913, 13916, 13917) are added. The quest items 1467, 16967-16970,
  19805, 19806, 19807 move from "fish" to "quest"; 6718, 19803, 19804 are added and 6717 moves from "other" (6718 and 6717 are quest items of Darkshore).
- **Rationale**: the author's decisions; spec 014's choice "a junk-named fish is Fish" is replaced for these items.
- **Alternatives**: none.

## R3. "Caught by the account"

- **Decision**: a trophy is caught when it is in the own-items set that `CatchDB` already builds for its views
  (`P.OwnItems`: `shared.mine` and the records of the own ID, every game version). A public `CatchDB.IsOwnItem(itemID)`
  reads it.
- **Rationale**: it is account-wide (the author's choice), exists, is grown by `Settle`, and is what the catalog
  already treats as "own". The per-character statistics are not account-wide.
- **Alternatives**: a new saved list of trophies: rejected, it duplicates data that exists; the statistics' items:
  per character.
- **Limit**: a catch the database does not record (a cast without a place: an instance, no position) is not in the
  set; it counts when the trophy is caught again where a place is known. Catches before 1.2.0 are not in the own data.

## R4. Seeing the first catch

- **Decision**: in `Settle` (`CatchDB/CatchDB.lua`), build the own-items set before the cast is written
  (`P.OwnItems()`), then, for each caught item not in it, add it and fire `ITEM_FIRST_CAUGHT(itemID, castID)` after
  the write. The message is general (any item new to the account's own catch); listeners decide what it means.
- **Rationale**: today `Settle` grows the set only when it was built (`if P.ownItems`), so a first catch before any
  view was drawn would be missed; building first makes the answer the same every time. The handler runs inside
  `FISH_CAUGHT` (TOC order: `CatchDB/Events.lua` before `UI/Toast.lua`, `ns.Fire` calls listeners at once), so the
  toast knows the item is new when its own `FISH_CAUGHT` handler runs.
- **Alternatives**: the toast compares before and after itself: it cannot, `CatchDB` writes first. A
  `TROPHY_CAUGHT` message: rejected, the kind is the Catalog's, and a general message serves spec 024 too.

## R5. The count

- **Decision**: `Catalog.TrophyIDs()` lists the IDs whose listed kind is "trophies" (from `GameData.ItemKinds`, built
  once); `Catalog.TrophyCount()` returns `caught, total` with `CatchDB.IsOwnItem`. The total is the list's size (36).
- **Rationale**: one source for the list (the kind table); the count counts the collection, not the rows shown, so
  search, filters and hidden kinds do not change it (spec US2 scenario 4).
- **Alternatives**: a constant 36: rejected, it would drift from the list.

## R6. The catalog: header and mark

- **Decision**: the Trophies header reads `L["%s (%d/%d)"]` with the kind's text, caught and total; a caught trophy's
  row shows the atlas `common-icon-checkmark` (12 px) over the bottom right corner of its icon. Only the catalog
  (the author's choice), not "What can be caught here".
- **Rationale**: the row has no free width (name, camp bonus tag, right column); an overlay on the icon costs none.
  The atlas exists in the Forever client export (`Blizzard_CharacterCreate/Camelot`).
- **Alternatives**: a text mark after the name: takes width and is truncated with long names; a separate column:
  no room in 580 px.

## R7. The notice and the sound

- **Decision**:
  - `UI/Toast.lua` listens to `ITEM_FIRST_CAUGHT`: when `Catalog.ItemKind(itemID) == "trophies"`, it shows
    `L["New trophy: %s (%d/%d)"]` (the item link, the count after the catch) with `always = true`, in gold, and
    remembers the item for that cast; its `FISH_CAUGHT` handler leaves remembered items out of the ordinary toast
    (and shows none when nothing is left).
  - `Fishing/Sound.lua` listens to `ITEM_FIRST_CAUGHT` and, for an ID whose `GameData.ItemKinds.byItem` value is
    "trophies", plays the rare sound under its usual rules (sounds on, fishing mode, no fight), at most once per cast:
    the cast's rare sound is already scheduled when the loot had a green item.
- **Rationale**: the author's choice (loud for the first, ordinary for a repeat); Sound is layer 1 and may read only
  GameData; one rare sound per cast avoids a double sound.
- **Alternatives**: a new sound file: not asked for; the toast in Catch or CatchDB: no frames below layer 3.

## R8. The saved choice and translations

- **Decision**: no migration; `KNOWN_KIND` grows with the new kinds; a player's hidden kinds stay. Four new texts in
  nine languages: "Trophies", "Quest", "%s (%d/%d)", "New trophy: %s (%d/%d)".
- **Rationale**: spec 014's rule "a kind the saved choice does not name is shown" already covers new kinds.
