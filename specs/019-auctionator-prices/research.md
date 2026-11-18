# Research: Auctionator Prices

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

The sources: Auctionator 347 (`static/examples/Auctionator`, read for its public API, not copied; licence "All
Rights Reserved"), the in-game measurements of 2026-11-17 in [docs/forever-api.md](../../docs/forever-api.md) ("The
auction house's request system": the API is there, a price for item 6291, an age of 0, the callback after a search
and at the end of a scan, `CurrentRealm` is `PvP`), and the addon's code of 1.3.2.

## R1. Where the source lives

- **Decision**: `Catch/Prices.lua` (layer 1) owns the source: it knows whether Auctionator is usable, reads its
  prices, owns the new setting and its setter, counts the sources and turns Auctionator's update notice into
  `PRICES_CHANGED`. No new file, module or message.
- **Rationale**: every value already goes through `Prices.GetAuction` / `Prices.Get` (statistics, catalog, the
  catalog's order, the "catch here" tab, the row tooltips); changing the answer there changes every view at once.
  `Prices` comes before `Auction` and `Stats` in the TOC and both are layer 1, so `Auction` may ask it and it may
  read `Stats` at runtime.
- **Alternatives**: a new `Catch/Auctionator.lua` module (a second place that decides prices, for about 100 lines);
  the source in `Auction` (it would mix the scan with a source that has no scan).

## R2. When Auctionator counts as usable

- **Decision**: `Prices.HasAuctionator()` is true when `Auctionator`, `Auctionator.API`, `Auctionator.API.v1` are
  tables and both `GetAuctionPriceByItemID` and `RegisterForDBUpdate` are functions, and no call failed this session
  (R5). Checked on each call at runtime, never at file load. `## OptionalDeps: Auctionator` in the TOC makes the game
  load Auctionator first when it is enabled, so its table is there from the addon's own `ADDON_LOADED` on.
- `Prices.UsesAuctionator()` = `settings.auctionPrices` and `settings.auctionatorPrices` and `HasAuctionator()`.
- **Rationale**: decision 19; `RegisterForDBUpdate` exists only in its `ModernAH` / `LegacyAH` sources; a character
  that has Auctionator disabled has no `Auctionator` global (the game does not load it), so the check is per
  character by itself.
- **Alternatives**: `C_AddOns.IsAddOnLoaded("Auctionator")` (a name check that says nothing about the API's shape).

## R3. Reading a price

- **Decision**: `GetAuctionPriceByItemID("OneKeyFishing", itemID)` per item when a value is needed, inside `pcall`;
  a result that is not a positive number counts as "no price". Nothing is cached: the call is a table lookup in
  Auctionator (`Database:GetPrice(tostring(itemID))`), cheap enough for the catalog's sort of a few hundred rows.
  Before Auctionator's `PLAYER_LOGIN` its database is nil and the answer is nil, which the fallbacks cover.
- **Rationale**: FR-005 (keep none of Auctionator's data); its database object is replaced by its reset and by
  `nopricedb`, so a held reference would go stale.
- **Alternatives**: a cache cleared on its update notice (stale after its reset, which sends no notice).

## R4. The update notice

- **Decision**: one `RegisterForDBUpdate("OneKeyFishing", fn)` at the addon's `PLAYER_LOGIN`, when Auctionator is
  usable then (the registration cannot be undone, so it is made once per session). `fn` does nothing unless
  `UsesAuctionator()`; otherwise it starts one timer of 0.5 s if none is running, and the timer fires one
  `PRICES_CHANGED`. One more `PRICES_CHANGED` 1 s after the login refreshes anything that read prices before
  Auctionator's database was ready.
- **Rationale**: FR-006 and SC-001 (within one second); its notice comes after each search and at the end of a scan,
  also for searches the player makes in its own tabs, so a burst must give one refresh. The windows already redraw on
  `PRICES_CHANGED`.
- **Alternatives**: a `PRICES_CHANGED` per notice (a redraw storm during its scan); polling (needless work).

## R5. A failing call

- **Decision**: every call to Auctionator goes through `pcall`. The first failure in a session is recorded once in
  the error log (through `ns.Safe` around an `error` with the message, so it is logged like any addon error), the
  reason is kept for the debug report, and `HasAuctionator()` is false for the rest of the session: the addon's own
  scan and prices come back. The failing call answers "no price"; its `PRICES_CHANGED` is sent on the next frame
  (`C_Timer.After(0, ...)`), since a price is often read in the middle of a redraw.
- **Rationale**: FR-007. A failure of a lookup by a number is not about one item: it means Auctionator's API changed
  or broke, and every following call would fail too. `ns.Safe` per call would show the game's error popup and log
  per item; one entry and the working own scan are better than vendor prices everywhere.
- **Settled while planning** (spec): FR-007 gains "after the first failure Auctionator counts as not installed for
  the session". The settings page then says so in its own words (R10), and `Prices.GetAuctionatorFailure()` gives
  the message. The failure fires `PRICES_CHANGED` only: no setting changed, so no `SETTINGS_CHANGED`; every view
  that depends on the source follows `PRICES_CHANGED` too.
- **Alternatives**: keep trying per item (an error per value, every redraw); `ns.Safe` per call (the popup).

## R6. The price rule with two sources

- **Decision**: `Prices.GetAuction(itemID)` returns `price, fewLots, source`: with `UsesAuctionator()` and a price
  from Auctionator, that price, `false`, `"auctionator"`; else the own stored price with its few-lots flag and
  `"own"` (as today, only while `settings.auctionPrices` is on); else nil. `Prices.Get` stays
  `max(auction, vendor)` unless `fewLots` (decisions 15 and 23). `FormatValue`'s mark keeps reading `fewLots`.
- **Rationale**: one place for the rule; every caller keeps its call.

## R7. The tooltip line

- **Decision**: `Prices.AddTooltipLine` adds nothing when the source is `"auctionator"`; for an own price it adds
  the present line (with the few-lots grey). The line is used only on the addon's own rows (`ns.ShowItemTooltip`
  with `withPrice`), which call `GameTooltip:SetItemByID`; Auctionator hooks `SetItemByID` (its
  `Source/Tooltips/Hooks.lua`), so its own line is on those tooltips.
- **VERIFY(V59)**: Auctionator's price line shows on the addon's row tooltips (read in its code, not seen in game).
  If wrong, an item priced by Auctionator shows no auction line in the addon's rows; the fix is the addon's line
  with "(Auctionator)".

## R8. Counting the sources

- **Decision**: `Prices.CountSources()` walks `ns.Stats.GetTotal().items` (the character's own catches), leaves out
  the items that cannot be sold at auction, and counts `auctionator`, `own`, `vendor` (no auction price, a vendor
  price above 0) and `none`. The "cannot be sold" rule moves from `Auction`'s local `Unsellable` to
  `Prices.CanAuction(itemID)` and `Auction` calls it (one rule, decision of the clarify session). An item the
  client has not loaded counts as sellable, as in the scan. Computed when shown (page, statistics line, debug), not
  stored; at most a few hundred items.
- With Auctionator not in use the `auctionator` count is 0 and the other three still tell the own price coverage.

## R9. The scan's entries and the command

- **Decision**: `Auction.WhyNot()` answers `L["Prices come from Auctionator."]` first when
  `Prices.UsesAuctionator()`; so `CanScan()` is false, `Auction.Scan()` prints that line and sends nothing (FR-012),
  and no request is ever sent while Auctionator is in use (a scan only starts from `Scan`). The three entries hide:
  `UI/AuctionButton.lua` hides the button (and shows it again on `SETTINGS_CHANGED` and `AUCTION_HOUSE_SHOW`),
  `UI/StatsFrame.lua` hides `frame.scan` in its refresh, `UI/Minimap.lua` builds no scan entry. They read
  `Prices.UsesAuctionator()`; `Auction.GetState()` keeps its four states.
- FR-013: the switches are only on the settings page, which closes the auction house, so a running scan has
  already stopped (spec 018); nothing more to build.

## R10. The settings

- **Decision**: a new account-wide key `settings.auctionatorPrices = true` (decision 10), filled by `ApplyDefaults`;
  no `DB_SCHEMA` bump. `settings.auctionPrices` keeps its key. Both are written only by `Prices.SetAuctionPrices(on)`
  and `Prices.SetAuctionator(on)`, which fire `SETTINGS_CHANGED` with the key (FR-025, the `CLAUDE.md` rule; the
  generic checkbox writer of `UI/Settings.lua` is not used for them).
- A new page `CreateAuctionPage` in `UI/Settings.lua`, registered after "Sound effects" as "Auction prices": the
  title, the main checkbox, the nested checkbox (indented; disabled with its label grey while the main one is off or
  Auctionator is not usable, then a grey note: "Auctionator is not installed.", or after a failing call (R5)
  "Auctionator failed this session: the addon's own scan is in use."), the status line and the counts line.
  It refreshes on `OnShow`, `SETTINGS_CHANGED` and `PRICES_CHANGED`. `auctionPrices` leaves the main page's toggle
  list (14 toggles, still two columns).

## R11. The statistics line

- **Decision**: with `UsesAuctionator()` the line reads `L["Values: higher of vendor and Auctionator price"]`, and
  when `own + vendor + none > 0` a second sentence `L["%d of your catches have no Auctionator price: run its scan."]`.
  Otherwise the present two lines. Nothing to chat (FR-021).

## R12. The debug report

- **Decision**: a section "Auction prices" before "Auction scan", from `Prices.Describe()` (English): the source
  (`auctionator`, `own scan`, `off`), both settings, `GetAuctionPriceByItemID` and `RegisterForDBUpdate` present or
  missing, the failure reason of R5 if any, the four counts, and the oldest age among the own catches with an
  Auctionator price (`GetAuctionAgeByItemID` through `pcall`; "unknown" when every age is nil).

## R13. Texts

New keys (nine translations each): "Auction prices" (page title), "Take prices from Auctionator", "Auctionator is not
installed.", "Auctionator failed this session: the addon's own scan is in use.", "Prices come from Auctionator.", "Prices come from the addon's own scan (last scan %s).", "Prices come
from the addon's own scan (no scan yet).", "Auction prices are off: catch values use vendor prices.", "Your
catches: %d priced by Auctionator, %d by the addon's scan, %d at vendor price, %d without a price.", "Values:
higher of vendor and Auctionator price", "%d of your catches have no Auctionator price: run its scan." Eleven keys,
looked up at runtime.

## R14. Tests

The stub `Auctionator.API.v1` lives in the tests that need it (a table set on the global and cleared after), not in
`tests/wow.lua`, which stays "no Auctionator" by default. New: `tests/catch/prices_auctionator_test.lua` (R2, R3, R5,
R6), `tests/catch/prices_counts_test.lua` (R8), `tests/catch/prices_update_test.lua` (R4),
`tests/ui/auction_page_test.lua` (R10). Extended: `tests/ui/scan_buttons_test.lua` (R9),
`tests/ui/stats_window_test.lua` (R11), `tests/ui/tooltips_test.lua` (R7), `tests/core/report_sections_test.lua`
(R12), `tests/core/migrations_test.lua` (the default). `tests/catch/auction_list_test.lua` is not changed: it keeps
proving the "cannot be sold" rule after its move to `Prices.CanAuction`.

In the tests every global that `tests/wow.lua` does not define is a permissive stub (it can be indexed and called),
so "no Auctionator" there is such a stub, not nil: the presence check of R2 must rest on `type(...) == "function"`
for the two functions, and a test covers it. An error handed on through `ns.Safe` is collected by the harness: a
test that expects one takes it with `take_errors()`.
