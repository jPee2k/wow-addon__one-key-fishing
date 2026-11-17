# Contract: Module API of the Kind Filter

**Feature**: [../spec.md](../spec.md) | **Data model**: [../data-model.md](../data-model.md)

## `Catalog/Catalog.lua` (layer 2, `ns.Catalog`)

| Function | Returns | Rules |
|---|---|---|
| `Catalog.KINDS` | `{ "fish", "containers", "potions", "reagents", "other" }` | display order (FR-001); read only |
| `Catalog.ItemKind(itemID)` | a kind name | `GameData.ItemKinds.byItem`, then `byClass` by the instant info's class, then `"other"`; no quality, no name (FR-002, FR-004, FR-005) |
| `Catalog.KindText(kind)` | the translated text | `L["Fish"]` and so on; called when drawn |
| `Catalog.IsKindShown(kind)` | boolean | true unless `settings.hiddenKinds[kind]` |
| `Catalog.ShownKinds()` | `shown, total` | the number of shown kinds and 5, for the button (FR-009) |
| `Catalog.SetKindShown(kind, shown)` | none | writes `settings.hiddenKinds[kind] = (not shown) or nil` and fires `SETTINGS_CHANGED("hiddenKinds")`; an unknown kind is ignored; nothing fires when nothing changed |
| `Catalog.Group(items)` | `list, hiddenCount` | data-model "Grouped list"; does not change or copy the rows |

Unchanged: `Catalog.Items(filter, search)` keeps its rows and its present rules (known items, the Poor rule, the
search); `Catalog.Places`, `Catalog.Spots`, `Catalog.TooltipLines`, `Catalog.MinimapLines` ignore the kind choice
(FR-012, spec edge cases). `CatchDB.Query`, `QueryMap`, `QueryCells` and `CatchDB.FilterKey` are unchanged (FR-010,
research R2).

## `UI/Widgets.lua` (layer 3)

| Function | Rules |
|---|---|
| `ns.OpenCheckboxMenu(owner, choices, isChecked, toggle)` | `choices = { { value, text } }`; one `root:CreateCheckbox(text, isSelected, setSelected)` per choice, the menu staying open (Blizzard's checkbox response); without `CreateCheckbox`, buttons with the check mark like `ns.OpenRadioMenu`; without `MenuUtil`, nothing |

## `UI/CatchHere.lua` (layer 3)

- A separate button, `page.kindButton` (at least `CatchHere.KIND_WIDTH` = 120 wide), always shown at the top right
  of both tabs: beside the place's name here (the name is now 400 wide), beside the search box in the catalog. The
  filter row keeps Skill, Source and Water at 150, as before spec 014, so its width in long translations does not
  change. Its text is `L["Kinds: all"]` or
  `(L["Kinds: %d of %d"]):format(Catalog.ShownKinds())`; a click opens `ns.OpenCheckboxMenu` over `Catalog.KINDS`
  with `Catalog.KindText`, `Catalog.IsKindShown` and `Catalog.SetKindShown`; the toggle only saves the choice:
  each tab's `SETTINGS_CHANGED` handler redraws it at once for the key `"hiddenKinds"` (a hidden tab is marked dirty
  and redraws when shown), so the shown list follows the click at once (FR-007).
- `CatchHere.Refresh` passes `view.items` through `Catalog.Group` and fills the rows: a header row before each
  group, then its items. With items in the view and no group left, `page.message` is
  `L["The kind filter hides every item."]`.
- `CatchHere.OpenKindMenu(owner)` is exported for the catalog tab (like `OpenWaterMenu`).

## `UI/CatalogTab.lua` (layer 3)

- The same kind button in the list view's filter row, through `CatchHere.OpenKindMenu`.
- `ShowList` builds the elements from `Catalog.Group(Catalog.Items(filter, search))`: `{ header = kind }` before each
  group's rows. `InitItemRow` draws a header element without icon, zones, tooltip or click.
- `StatusText`: rows but none shown -> `L["The kind filter hides the matches."]` with a search, else
  `L["The kind filter hides every item."]`; the present texts keep their cases.
- `CatalogTab.Show(itemID)` is unchanged: a hidden kind's item still opens (FR-012).

## Messages

No new message. `SETTINGS_CHANGED` gets the key `"hiddenKinds"`; both tabs already mark themselves dirty on it.

## Saved variables

`OneKeyFishingDB.settings.hiddenKinds = {}` in the defaults of `Core/Core.lua`; listed in
`docs/architecture/core.md` with the other settings. Cross-module rule (for `CLAUDE.md`): the kind choice is written
only through `Catalog.SetKindShown`, never by a direct write of `settings.hiddenKinds`.

## Debug report

`Catalog.Describe` (read by `Core/Debug.lua`, which needs no change) adds the hidden kinds to the catalog's lines,
for example `kinds hidden: containers, other` or `kinds hidden: none`.
