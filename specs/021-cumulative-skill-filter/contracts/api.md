# Contracts: Cumulative Skill Filter

**Feature**: [../spec.md](../spec.md) | **Data model**: [../data-model.md](../data-model.md)

Module functions only: no new message, no command, no saved field. Layers as in `CLAUDE.md`.

## `ns.CatchDB` (layer 2)

### `CatchDB.SkillFilter(range) -> 0..3 | "all"` (new)

A skill range (`0`..`4` or `nil`) as a filter value: `nil` and `MAX_RANGE` give `"all"`, `0`..`3` themselves.

### `CatchDB.RangeOf(rank) -> 0..4 | nil` (new)

The skill range of a Fishing rank: `min(MAX_RANGE, floor(rank / RANGE_STEP))`; nil for a nil rank.
`CatchDB.GetCurrentPlace` uses it for the place key.

### `CatchDB.Query(mapID, cell, filter) -> view` (changed)

- `filter.range` `r` (a number) sums ranges `0..r`; `"all"` sums every range.
- `view.missRate`: from range `r` alone (`MAX_RANGE` for `"all"`) at the view's scope, weighted as before; nil under a
  water filter.
- `view.missLittleData` (new): the raw casts behind `missRate` are below `CatchDB.LITTLE_DATA`.
- Every other field as before, over the cumulative sums. Cached under the same key (`FilterKey` unchanged).

### `CatchDB.QueryMap(mapID, filter)`, `CatchDB.QueryCells(mapID, filter)` (changed)

Cumulative sums like `Query`; `missRate` is nil.

### `CatchDB.Maps(filter)`

Maps with data in the cumulative ranges.

## `ns.Catalog` (layer 2)

- `Catalog.DefaultFilter()`: `range = "all"`, unchanged.
- `Catalog.MinimapLines()`: queries with `CatchDB.SkillFilter(ownRange)`.
- `Catalog.TooltipLines(itemID)`: unchanged (`"all"`).

## `UI` (layer 3)

### `ns.SkillFilterLabel(value) -> text` (new, `UI/Widgets.lua`)

The button's text: `L["Skill: Up to %d"]` with the range's top (74, 149, 224, 299) or `L["Skill: All"]`.

### `ns.SkillMenuText(value, own) -> text` (new, `UI/Widgets.lua`)

A menu value's text: `L["Up to %d"]` or `L["All (%d+)"]` (300), or their `"(yours)"` forms when `value == own`.

### `ns.ShowSkillTooltip(button, value)` (new, `UI/Widgets.lua`)

Title `L["Skill"]`; line 1 `L["Catches with skill up to %d."]` or `L["Catches with any skill."]`; line 2
`L["Misses only with skill %s."]` with `ns.RangeLabel(MissRange)` ("150-224", "300+"). Both tabs' Skill buttons call it
on enter with their current value.

### `CatchHere.OpenSkillMenu(owner, current, choose)` (changed)

Five radio values in order `0`, `1`, `2`, `3`, `"all"`; texts `L["Up to %d"]` / `L["All (%d+)"]`, or their
`"(yours)"` forms for `CatchDB.SkillFilter(CatchDB.RangeOf(ns.Skill.Get()))` (from the rank, so also where the game
gives no map; none without Fishing).

### `ns.RangeLabel(min, max)` (changed)

Its `"all"` branch is removed; it labels real ranges only (the catalog's Skill column, the tooltip's miss range).

### "What can be caught here" counts line

`catches .. "    " .. L["Nothing caught: %s"]:format(Percent(missRate))` as before, or
`catches .. "    " .. L["Nothing caught: little data"]` when `missLittleData`; nothing when `missRate` is nil.

## Texts

Added (with nine translations): `"Skill: Up to %d"`, `"Skill: All"`, `"Up to %d"`, `"Up to %d (yours)"`,
`"All (%d+)"`, `"All (%d+) (yours)"`, `"Catches with skill up to %d."`, `"Catches with any skill."`,
`"Misses only with skill %s."`, `"Nothing caught: little data"`.

Removed (from all ten files): `"All skill levels"`, `"Skill: %s"`,
`"Try \"All skill levels\": little data for your skill."`.
