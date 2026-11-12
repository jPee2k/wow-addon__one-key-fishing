# Research: Release Fixes for 1.2.0

The facts behind each decision are in `docs/forever-api.md` "Verified in game" (the dungeon of 2026-11-11, the
minimap tooltip of 2026-11-08) and in `docs/tech-debt.md` "Open items".

## R1. A secret bobber identity in an instance (batch 10)

- **Decision**:
  - A helper `ns.IsSecret(value)` in `Core/Data.lua`: `issecretvalue and issecretvalue(value)`; false when the game
    has no `issecretvalue`.
  - `ns.GameObjectID(guid)` returns nil for a secret value, before `strsplit`.
  - `ns.IsBobberTargeted()` returns two values: `targeted, known`. A secret GUID gives `false, false`; a readable one
    `targeted, true`; no soft target `false, true` (nothing is targeted, as today).
  - `ShowNoBobber` in `UI/Indicator.lua` returns false when `known` is false: no "No bobber" warning, the label stays
    "Hook!". The grace timer and `bobberSeenCast` are not touched by an unknown answer.
  - `IsFromLastOpen` in `Fishing/Bags.lua` skips a secret loot source: it neither matches nor counts as a known
    other source, so the timing fallback decides (loot right after the open attempt is its loot).
- **Rationale**: the error came from `strsplit` on a secret string (2026-11-11). The key needs no answer: while
  channeling it binds `INTERACTTARGET`, which interacts with the soft target whatever it is, and hooking worked in
  the dungeon. Only the indicator's warning depends on the answer, and a wrong "No bobber" on every cast would be as
  bad as the error. The loot source is guarded because it is the same kind of identity; it was not seen secret.
- **Alternatives considered**: `pcall` around `strsplit` (hides other errors, and the warning would still show);
  reading `UnitName("softinteract")` instead (the name may be secret too, and names are not compared by language,
  Principle II); dropping the warning in instances by `IsInInstance()` (a guess about where secrets happen, not the
  value itself).
- **Every reader**: `UnitGUID("softinteract")` is read only in `ns.IsBobberTargeted`; `GetLootSourceInfo` only in
  `Fishing/Bags.lua`. No other code reads a soft target or a loot source.

## R2. The bundled-data hint (batch 9)

- **Decision**: `UI/CatchHere.lua` adds, with no seed and the "All" source, "No bundled data in this version." when
  the view on screen has another player's catch in its numbers (a new view field `others`, set by `BuildView`
  when an ID with a catch has a part, which only other players' records have), else "No bundled data in this
  version: only your own catches are shown." The page refreshes on `SHARED_DATA_CHANGED` and on a place change, as
  today.
- **Rationale**: the claim is about the numbers on the page, and `CatchDB.Query` already says who is behind them:
  sharing off, records of other places, records the view does not count (another build before a reset) and own
  rolled records all leave no other player. Corrected by the code review of 2026-11-12: the first version,
  `CatchDB.HasOthers()`, scanned the whole store and dropped the claim on a page of own catches only.
- **Alternatives considered**: a store-wide `CatchDB.HasOthers()` (the first version: a second source of truth
  beside the view, and wrong per place); `view.players >= 2` (one other player alone, at a place the player never
  fished, counts 1 and kept the false claim).

## R3. One player in the exchange status (batch 9)

- **Decision**: `Share.StatusLine` uses a new key `L["Exchange: 1 player, %s ago"]` when `status.exchanged == 1`,
  the existing plural otherwise, as spec 010 did for "1 catch". The status line feeds the tab, the settings page
  and `/okf share`, so one change covers all three.
- **Rationale**: the nine languages have one plural form for 2+ in this sentence; a separate singular is the
  pattern the addon already uses (`"Session: 1 catch, %s"`). Korean and Chinese write the same shape with 1.
- **Alternatives considered**: a plural function per language (no other text needs it).

## R4. A refused lure after a skill-up (batch 5)

- **Decision**: `skippedLures[itemID]` keeps the Fishing skill at the refusal (`ns.Skill.Get()`, or 0 when not
  known) instead of `true`. On `SKILL_LINES_CHANGED` a skipped lure is cleared when its requirement was not met by
  the skill of the refusal and is met now (`SkillAllows`). The indicator is told (`LURE_READY`) when one is
  cleared. A new mode session still clears all (as today).
- **Rationale**: `FindLure` offers a lure only at its requirement, or while the skill is unknown. A lure refused
  with its requirement met (the values are confirmed in game, V43) was refused for another reason; clearing it on a
  skill-up would retry it on every skill point (below 150 nearly every catch) and print "Cannot apply ..." each
  time. Corrected by the code review of 2026-11-12: the first version cleared on any rise of the Fishing skill.
  The skill event fires for every skill line, so the check reads the Fishing skill once per event, only when a lure
  is skipped.
- **Alternatives considered**: clearing on every skill event or on any rise of the skill (the repeat above); a
  timer (no reason to retry without a change).

## R5. The minimap tooltip's colours (batch 7)

- **Decision**: `UI/Minimap.lua` `ShowTooltip` calls `GameTooltip:ClearLines()` after `SetOwner`, and every line
  with a colour gets it as a colour code around its text (a local `Colored(text, r, g, b)`), with the same colour
  arguments kept. Double lines colour both sides the same way. Lines whose text already holds a colour code (the
  mode's "ON" / "OFF", the grey version) keep it; the outer code wraps the whole line.
- **Rationale**: on 2026-11-08 every line's colour argument was lost on one hover while codes inside the text
  survived; so text codes fix what is seen without knowing the cause. `ClearLines` drops lines left by an earlier
  owner (the statistics window's item rows) in case the reset comes from them. The tall-glyph wrap flag stays.
- **Nesting**: an inner `|r` ends the inner colour; in the mode line the inner code is the last thing, so nothing
  after it loses colour. No other line has an inner code.
- **Alternatives considered**: waiting for a reproduction (the item has waited since spec 007); a tooltip of the
  addon's own (more code for a cosmetic issue).

## R6. The private-table check (batch 8)

- **Decision**: `privateProblems(text, folder, folderOf)` in `tools/addon.mjs` parses the file with luaparse
  (Lua 5.1, scopes, no comments) and walks the tree:
  - a member `.private` whose base is an identifier naming a module (`CatchDB.private`), a member of `ns`
    (`ns.CatchDB.private`), an index of `ns` by a string (`ns["CatchDB"].private`), or a local bound to one of
    those (`local C = ns.CatchDB` ... `C.private`);
  - the module name maps to its folder through `folderOf`, and a folder other than the file's own is reported with
    the line number, as today.
  - A file that does not parse returns no problems (the check's own parse step reports the syntax error).
- **Rationale**: the parser sees strings and comments as such, so `--` inside a string no longer hides the rest of
  the line; aliases are found through local declarations. luaparse is already used by `tools/check.mjs` and
  `tools/harvest.mjs`; without an encoding mode a string's value is empty, so the name is read from its `raw`.
- **Alternatives considered**: a longer regex (cannot follow aliases or tell strings apart).

## R7. Documents (FR-015)

- `CHANGELOG.md` `[Unreleased]` "Fixed": the error window while fishing in a dungeon (in 1.1.0); the minimap
  tooltip losing its colours (in 1.1.0). The status texts and the lure are unreleased or not seen: no line.
- The manual: nothing a player reads changes (the hint and the status line are not quoted there; checked by grep
  during the implementation).
- `docs/forever-api.md` and `CLAUDE.md` Forever API: the secret soft-target GUID is already written (2026-11-11);
  add that the addon treats it as "unknown".
- Architecture: `core.md` (`ns.IsSecret`, the bobber answer), `fishing-mode.md` (skipped lures), `ui.md` (the
  indicator's unknown state, the tooltip colours), `exchange.md` (the status line),
  `docs/development.md` (what the private check finds).
- `docs/tech-debt.md`: every item of batches 5, 7, 8, 9 and 10 removed, the "Fix batches" section says none are
  open, a history line for spec 012.
- `docs/release-plan.md` step 3, the checklists (`fishing-mode.md` dungeon step, `catch-exchange.md` step 4) and
  the 1.2.0 test page (phase "After spec 012").
