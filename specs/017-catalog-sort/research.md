# Research: Catalog Sorting

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

Every question was settled by the author's question round of 2026-11-17 (spec "Clarifications") or by reading the
code; nothing needs the game except the layout's look (R6), which the checklist covers.

## R1. Where the order is applied

- **Decision**: in `Catalog.Items` (layer 2), after the search and the Poor rule, on the copy it returns: a
  `SortRows(list)` step reads `Catalog.GetSort()`. `Catalog.Group` keeps the input order inside each kind, so the
  grouping (FR-007) needs no change. `Catalog.Find` (the single-match rule of `/okf catalog <name>`) stays by name.
- **Rationale**: the catalog already owns the list's rules (known items, Poor, search) and the order by name; the tab
  only draws. A test reaches the order without frames (Principle V).
- **Alternatives**: sorting in `UI/CatalogTab.lua` (logic in the view layer, harder to test); sorting inside
  `SortedItems` (its cache follows the catalog's version, which a price scan does not move, R3).

## R2. The price

- **Decision**: `ns.Prices.Get(itemID)` (`Catch/Prices.lua`, layer 1): the higher of the vendor price and the
  auction price, an auction price on few lots not counted, no auction price while `settings.auctionPrices` is off.
  0 means "no price".
- **Rationale**: FR-004 asks for the statistics' value; this is the function the statistics use
  (`Catch/Stats.lua`). Layer 2 may use layer 1.
- **Alternatives**: `Prices.GetAuction` first (author chose the statistics' value, Q3).

## R3. Keeping the order current

- **Decision**: prices are read on every `Catalog.Items` call (one `Prices.Get` per listed row, computed once per
  call into a key table, not inside the comparator). The tab already marks itself dirty on `PRICES_CHANGED` and on
  any `SETTINGS_CHANGED` (the auction price checkbox), and its tick then redraws (FR-009).
- **Rationale**: a scan changes prices without moving `Catalog.GetVersion()`; a cache keyed on the version would
  show old prices. A few hundred rows cost well under a millisecond per draw, and the list is drawn only on change.
- **Alternatives**: a price cache dropped on `PRICES_CHANGED` (a second invalidation path for no measurable gain).

## R4. The chance of an item

- **Decision**: `SortedItems` adds to each row `chance` and `littleData` of `places[1]`, the item's best place in
  `PlaceBefore` order (zones with enough data first, by chance; then little-data ones by the item's catches). The
  order by chance puts rows with `littleData` after the others, then by `chance` descending, then by name.
- **Rationale**: FR-005 asks for the zone the item's page lists first, and `places` is that list for the same
  filter (the index is per filter). An item with any zone with enough data is therefore never "little data".
- **Alternatives**: the highest chance over all places (a 1-of-1 little-data zone at 100 % would lead, Q4);
  the mean (meaningless for farming, Q4).

## R5. The saved order

- **Decision**: `settings.catalogSort` (account-wide, `OneKeyFishingDB`), default `"name"` in `Core/Core.lua`'s
  defaults; read by `Catalog.GetSort()` (an unknown value reads `"name"`), written only by `Catalog.SetSort(sort)`,
  which fires `SETTINGS_CHANGED("catalogSort")` when the value changed. No `DB_SCHEMA` bump: a new key, filled by
  `ApplyDefaults`.
- **Rationale**: the same shape as the kind choice (`hiddenKinds`, spec 014), FR-010, Q13; the debug report lists
  the setting by itself (its "Addon settings" section prints every key).
- **Alternatives**: the character DB (author chose per account, Q13).

## R6. The layout

- **Decision**: in `UI/CatalogTab.lua`, three rows: the search box at `TOP` alone; Skill, Source and Water at
  `TOP - 28` (Water after Source, shown only with pool data, as today); the Sort button (min width 150) at
  `TOP - 54`, the Kinds button (`CatchHere.KIND_WIDTH`, 120) to its right; the item list starts at `TOP - 88`
  (one row of the list less than today). `UI/CatchHere.lua` keeps its layout.
- **Rationale**: Q1 and Q1a. Row 2 now has the full width (560 px): the longest labels (French, "Source : Seulement
  les miennes") take about 551 px with Water, as they do today without anything on their right; row 3 holds two
  short buttons in every language.
- **Alternatives**: Sort and Water in row 3 with Kinds at the top right (the draft, replaced by Q1); a narrower search
  box with Sort in row 1 (rejected in the first layout question).
- **Check**: the look in English and French is a step of the checklist (no `VERIFY` marker: an overlap is seen at
  once and fixed by a width, it is no API assumption).

## R7. The right column

- **Decision**: the item row's right text (`row.zones`, right aligned; widened from 110 to 140 px in the code
  review so a price of three coins fits, the name from 380 to 350) shows: by price, `ns.FormatMoney` of the price, or `L["No price"]` drawn grey (`SetTextColor`, the color outside the string) when it is 0; by
  chance, `Catalog.ChanceText(chance, littleData)` (the same call the item page uses for its zones); by name,
  `L["Zones: %d"]`. The color is set on every draw, so a reused row never keeps the grey.
- **Rationale**: FR-008, Q6, Q7, Q10. The price per piece without the "few lots" mark: the mark is
  `Prices.FormatValue`'s and would not fit the column; the tooltip already says it.
- **Alternatives**: a second column (narrower names, Q6).

## R8. Redraw and scroll

- **Decision**: the tab's `SETTINGS_CHANGED` handler calls `CatalogTab.Refresh()` (no `retain`) for
  `"catalogSort"`, so the scroll box gets a new data provider from its top (FR-002, Q8); `"hiddenKinds"` keeps
  `Refresh(true)`. The fixed-row fallback has no scroll and simply redraws.
- **Rationale**: the existing pattern of the kind choice, with the scroll rule the author asked for.

## R9. Texts

- **Decision**: three new keys: `"Sort: %s"`, `"Name"`, `"No price"`; `"Price"` and `"Chance"` exist. Nine
  translations each in the same change (FR-012). `Catalog.SortText(sort)` looks them up when drawn.
- **Translations**: written into `Locales/<code>.lua` with the change (the Markdown files stay free of the
  translated texts); the button labels stay short in every language ("Sort: %s" with a one-word order), so row 3
  holds both buttons.

## R10. Tests

- **Decision**:
  - new `tests/catalog/sort_test.lua`: the three orders on `Catalog.Items` (price with a vendor price, a trusted
    auction price, a few-lots auction price, no price; chance with little-data items last and an item whose best
    zone has enough data; ties by name; search keeps the order), `GetSort` / `SetSort` (default, unknown value,
    `SETTINGS_CHANGED` once, no message for the same value), `Group` keeps the order inside kinds;
  - new `tests/ui/catalog_sort_test.lua`: the button text, the menu's three radio entries with the chosen one
    marked, a choice reorders the list and resets the scroll, the right column per order with "No price" grey and a
    reused row back to white, a `PRICES_CHANGED` reorders at the next tick, the three-row layout (anchors);
  - new `tests/ui/catalog_sort_saved_test.lua`: a saved `"price"` is used at the first draw;
  - new `tests/ui/catalog_sort_saved_unknown_test.lua`: a saved unknown value draws by name and is not rewritten (one
    load per file);
  - extended `tests/ui/catalog_kinds_test.lua`: the Kinds button now anchors to the Sort button;
  - extended `tests/ui/here_kinds_test.lua`: the catch tab's Kinds button keeps its `TOPRIGHT` anchor;
  - `tests/wow.lua`: frames record `SetPoint` / `ClearAllPoints` (the anchors) and font strings `SetTextColor`, so
    the layout and the grey can be asserted.
- **Rationale**: Principle V; each test fails without its change.

## R11. In-game check

- **Decision**: a new `docs/checklists/catalog-sort.md` and its row in `docs/checklists/README.md`; no
  `verification.md` (no `VERIFY` marker: the feature uses no game API that is not already confirmed: `Prices.Get`,
  the radio menu and the scroll list are in use since 1.0.0 to 1.3.0).
