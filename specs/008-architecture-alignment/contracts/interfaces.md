# Contracts: Architecture Alignment

The interfaces other modules and the tools rely on after the alignment. The data shapes are in
[data-model.md](../data-model.md).

## C1. `ns.GameData` (layer 0)

- Every module of every layer MAY read `ns.GameData.<Entity>`. No module writes it, including the tests: a test that
  needs other data sets it up in its own copy, or restores the original value.
- The tables exist once the TOC has loaded `GameData/`, before `Core/Core.lua`. So a module MAY read them at file
  load time.
- The code of a `GameData/` file names no other `ns.<Name>` and contains no `function`, no call, no `L[` and no `ns.L`.
  The check ignores string literals and comments.
  `npm run check` reports:

  ```text
  OneKeyFishing/GameData/<File>.lua:<line>: GameData/ holds data only (no function, no call, no ns.L, no other module)
  ```

- Non-ASCII is allowed only inside string literals (unchanged).

## C2. `ns.MapPin` (layer 0, `Core/MapPin.lua`)

| Function | Contract |
|---|---|
| `MapPin.Target(maps, x, y)` | `maps`: candidate uiMapIDs, in order; `x`, `y`: the point on the first candidate. Returns `{ mapID, x, y }` or nil. The result is nil when the waypoint API is missing or the game rule turns pins off. Otherwise it is the first candidate the client knows and allows pins on. Failing that, the point is converted through the world position to the parent of the first candidate (the point's own map), if the client knows it, it is a Micro map and that parent allows pins (V33) |
| `MapPin.Set(target, placeName)` | On the player's click only. If the player set a pin of their own elsewhere, it asks first; the addon's own pin, or a pin at the target, is replaced without asking. Then it sets the waypoint and the navigation arrow, saves `charDB.pin`, fires `MAP_PIN_SET(placeName)` (nil when refused) and, out of combat, opens the map (R14) |
| `MapPin.Link(target, text)` | Unchanged |

The catalog uses `Target` (through `Catalog.Spots`) and `Set` (through `CatalogTab.Pin`). The rank advice uses the
same pair. The toast is `UI/Toast.lua`'s answer to `MAP_PIN_SET`, never a direct call.

## C3. `Bags.FindLure()` (layer 1)

- It returns the best lure that meets all of these:
  - it is in the bags;
  - it is not skipped after a failed attempt;
  - it is usable (`C_Item.IsUsableItem` when present);
  - it is off cooldown;
  - for a lure in `GameData.Lures`, its `skill` is at most `Skill.Get()`.
- "Best" means the lowest `order`. If no lure meets these, it returns nil and the soonest cooldown.
- When `Skill.Get()` is nil (the skill is not known yet), the skill rule is not applied.
- A lure not in `GameData.Lures` is never found by `FindLure`: the list is the lures the addon knows, as today
  (spec FR-009). The failure path (skip after the game refuses) stays for a known lure whose `skill` value is too
  low.

## C4. Private tables

- `<Module>.private` holds what the files of one module share, and what only the tests read. It is not an API: no
  other module reads it, and `npm run check` reports `ns.<Other>.private` used outside its own folder or `tests/`.
- New: `Comm.private`. Extended: `CatchDB.private` (see data-model.md).

## C5. Test layout (for `npm test` and `docs/development.md`)

- `tests/<area>/` per architecture document, plus `tests/gamedata/`.
- File names name the subject (`fishing/lure_skill_test.lua`), never `<module>_test.lua`.
- `npm run check` reports a test file `tests/<folder>[/<sub>]/<name>_test.lua` whose `<name>` equals, case-folded,
  the base name of a `.lua` file in its folder's addon folder. The folders map as follows: `core` to `Core/`,
  `fishing` to `Fishing/`, `catch` to `Catch/`, `catchdb` to `CatchDB/`, `catalog` to `Catalog/`, `exchange` to
  `Exchange/`, `ui` to `UI/`, `gamedata` to `GameData/`. There is no exception list.
