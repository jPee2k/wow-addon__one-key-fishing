# Feature Specification: Auctionator Prices

**Feature Branch**: `019-auctionator-prices`

**Created**: 2026-11-18

**Status**: Implemented (in-game checklist `docs/checklists/auctionator-prices.md` open)

**Input**: User description: "auction integration". A player who also runs the Auctionator addon gets the auction
prices of the catch from Auctionator, and the addon's own scan buttons go away. The research and the author's
decisions of 2026-11-17 and 2026-11-18 (decisions 9 to 23) are in [docs/auction-plan.md](../../docs/auction-plan.md),
"Feature 2: Auctionator as a price source" and "Decisions". The addon's own scan is spec 018 and is not changed here.

## Clarifications

### Decisions of the author, 2026-11-17

- Which price: Auctionator's when it has one for the item, else the addon's own stored price, else the vendor price
  (decision 9).
- A switch "take prices from Auctionator", on by default, usable only when Auctionator is installed. Off: the
  addon's own scan and prices are back (decision 10).
- Auctionator's price is used at any age (decision 11) and without the "few lots" rule, as Auctionator's own
  tooltips show it; one lone overpriced lot of a rare item raising the catch value is an accepted risk (decision 12).
- With Auctionator's prices in use, the scan buttons above the auction house, in the statistics window and in the
  minimap menu are hidden, and the scan command answers that the prices come from Auctionator (decision 13).
- The statistics window's line about the values says the prices come from Auctionator and, when some of the
  player's catches have no price there, how many, with the advice to run Auctionator's scan. Nothing in chat
  (decision 14).

### Decisions of the author, 2026-11-18

- The vendor floor stays: a catch is worth the higher of its auction price and its vendor price, whatever the source
  of the auction price (decision 15).
- With Auctionator's prices in use, the addon's own auction price line in item tooltips is not shown; Auctionator's
  line is there (decision 16; for an item Auctionator has no price for, see the session below).
- A new settings page "Auction prices": the existing switch "Use scanned auction prices for catch value" moves there
  from the main page; below it, nested, the Auctionator switch, inactive while the first is off or Auctionator is not
  installed (decision 17).
- The page also shows the price source in use and the counts below; no scan button (opening the settings closes the
  auction house) and no reset buttons (decision 18).
- Auctionator counts as installed only when both its price query and its update notice are there; an Auctionator
  without either is treated as absent (decision 19).
- The age of Auctionator's prices is shown only in the debug report (decision 20); the debug report shows the source,
  the presence of the two functions, both switches, the counts and the oldest age (decision 21).
- The counts cover the player's own catches only: how many have Auctionator's price, the addon's own price, the
  vendor price only (and, settled in the session below, no price at all); the page, the statistics line and the
  debug report show the same counts (decision 22).
- The addon's own stored price used as a fallback keeps its "few lots" rule (decision 23).

### Session 2026-11-18

- Q: When Auctionator's prices are in use and Auctionator has no price for an item, is the addon's own tooltip line
  shown for the fallback price used in the sums? → A: Yes, only then: the addon's line shows its own stored price
  (with its "few lots" mark) when Auctionator has none; when Auctionator has a price, only Auctionator's line is
  there.
- Q: Do catches that cannot be sold at auction (bound items) count as "no Auctionator price"? → A: No: the counts
  and the statistics advice cover only own catches that can be sold at auction, the same rule as the addon's own
  scan (spec 018, FR-004).
- Q: How do catches with no price at all (no Auctionator price, no own price, no vendor price) count? → A: A fourth
  group "no price"; the four counts add up to the own catches that can be sold at auction.

### Settled while planning

- A failing call to Auctionator is not about one item (a lookup by a number fails only when its interface changed or
  broke), so after the first failure Auctionator counts as not installed for the rest of the session: the addon's
  own scan and prices come back, the failure is logged once and named in the debug report and on the settings page
  (plan, research R5).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Catch values from Auctionator's prices (Priority: P1)

A player runs both OneKeyFishing and Auctionator and scans the auction house with Auctionator, as they do anyway.
Without pressing any scan of OneKeyFishing, the statistics window, the catch catalog and the catch values show
auction prices: Auctionator's where it has one, the addon's own stored price where it has none, else the vendor
price.

**Why this priority**: this is the feature: one scan for both addons, and the catch values follow the prices the
player already sees in Auctionator's tooltips.

**Independent Test**: with Auctionator installed and the switches on, run Auctionator's full scan; open the
statistics window: the value of a catch Auctionator priced equals the higher of Auctionator's price and the vendor
price, and an item it never saw shows the addon's own price or the vendor price.

**Acceptance Scenarios**:

1. **Given** Auctionator has a price for a caught item above its vendor price, **When** the player opens the
   statistics window, **Then** the item's value uses Auctionator's price.
2. **Given** Auctionator's price for an item is below its vendor price, **When** the value is shown, **Then** the
   vendor price is used.
3. **Given** Auctionator has no price for an item and the addon has a stored price of its own, **When** the value is
   shown, **Then** the addon's own price is used with its "few lots" rule (the mark, and the vendor price in sums
   when it rests on few lots).
4. **Given** neither has a price, **When** the value is shown, **Then** the vendor price is used, else "No price".
5. **Given** the statistics window is open, **When** Auctionator finishes a scan or a search, **Then** the values
   update without a reload and without the player doing anything.
6. **Given** Auctionator's price for an item is many weeks old, **When** the value is shown, **Then** that price is
   still used.

---

### User Story 2 - No second scan button (Priority: P1)

While the catch values come from Auctionator, the player sees no OneKeyFishing scan entry: not above the auction
house, not in the statistics window, not in the minimap menu. The scan command tells the player that the prices
come from Auctionator instead of scanning.

**Why this priority**: two scan buttons for the same prices confuse players, and every request the addon does not
send is one that cannot jam the auction house.

**Independent Test**: with Auctionator in use, open the auction house, the statistics window and the minimap menu:
no scan entry of the addon; type the scan command: one line says the prices come from Auctionator and no request is
sent.

**Acceptance Scenarios**:

1. **Given** Auctionator's prices are in use, **When** the auction house opens, **Then** the addon's scan button is
   not shown.
2. **Given** Auctionator's prices are in use, **When** the statistics window or the minimap menu is shown, **Then**
   neither has a scan entry.
3. **Given** Auctionator's prices are in use, **When** the player types the scan command, **Then** one chat line
   says the prices come from Auctionator, and no auction request is sent.
4. **Given** the player turns the Auctionator switch off on the settings page (which closed the auction house),
   **When** the switch changes, **Then** the scan entries of the statistics window and the minimap menu are back at
   once, and the button above the auction house is there the next time it opens, all without a reload.

---

### User Story 3 - A settings page for auction prices (Priority: P2)

The settings get a page "Auction prices" with the switch for auction prices (moved from the main page) and, nested
below it, the switch "take prices from Auctionator". The page tells which source is in use and how many of the
player's catches have a price from each source.

**Why this priority**: the player must be able to go back to the addon's own scan and to see why a value is what it
is; the counts also tell whether an Auctionator scan is due.

**Independent Test**: open the page with and without Auctionator installed; flip each switch and check the status
line, the counts and the scan buttons follow at once.

**Acceptance Scenarios**:

1. **Given** Auctionator is installed, **When** the page opens, **Then** both switches are usable, the status line
   names Auctionator as the source, and the counts show how many own catches have Auctionator's price, the addon's
   own price, the vendor price only and no price at all.
2. **Given** Auctionator is not installed, **When** the page opens, **Then** the Auctionator switch is inactive with
   a note that Auctionator is not installed, and the status line names the addon's own scan with the time of its
   last scan.
3. **Given** the auction price switch is off, **When** the page is shown, **Then** the Auctionator switch is
   inactive and every value is the vendor price.
4. **Given** the player turns the Auctionator switch off, **When** the values are shown next, **Then** they use the
   addon's own stored prices, which were kept untouched while Auctionator was in use.
5. **Given** the main settings page, **When** it opens, **Then** the auction price switch is no longer among its
   features.

---

### User Story 4 - Knowing which prices are missing (Priority: P2)

The statistics window's line about the values says that the prices come from Auctionator and, when some of the
player's catches have no price there, how many, with the advice to run Auctionator's scan.

**Why this priority**: an item Auctionator never saw falls back silently; the player should know when the values
rest on older or vendor prices.

**Independent Test**: with some catches Auctionator never saw, open the statistics window: the line names the number
of catches without an Auctionator price and advises its scan; after a full Auctionator scan that finds them, the
advice goes away.

**Acceptance Scenarios**:

1. **Given** every own catch has an Auctionator price, **When** the statistics window is shown, **Then** the line
   says the values come from Auctionator, with no count.
2. **Given** some own catches have no Auctionator price, **When** the statistics window is shown, **Then** the line
   gives their number and advises running Auctionator's scan.
3. **Given** any state, **When** prices change, **Then** nothing is written to chat about it.

---

### User Story 5 - A debug report that explains the values (Priority: P3)

The debug report has a section on prices: the source in use, whether each of Auctionator's two functions is there,
both switches, the counts, and the age of the oldest Auctionator price among the player's catches.

**Why this priority**: a player reporting "my values are wrong" sends this report; it must show where the values
came from.

**Independent Test**: open the debug report with Auctionator in use and without it; the section names the source and
the counts match the settings page.

**Acceptance Scenarios**:

1. **Given** Auctionator is in use, **When** the debug report is opened, **Then** it shows the source, both functions
   present, both switches, the four counts and the oldest age in days (or that the age is not known).
2. **Given** Auctionator is installed without one of the two functions, **When** the debug report is opened,
   **Then** it shows which one is missing and that the addon's own scan is in use.

---

### Edge Cases

- Auctionator is installed but disabled for this character: it counts as not installed for this character; the
  saved Auctionator switch keeps its value for other characters.
- Auctionator has no price data yet right after the login: the values use the fallbacks and update when Auctionator
  is ready, without a reload.
- Auctionator's price database is empty (its option not to record prices, or after its reset): every catch counts as
  "no Auctionator price", the values use the fallbacks, and the statistics line advises its scan.
- A call to Auctionator fails with an error: that item is treated as having no Auctionator price, the error goes to
  the addon's error log once, and Auctionator counts as not installed until the next login (the addon's own scan
  and prices are back); nothing else breaks. The settings page says that Auctionator failed this session, not that
  it is not installed.
- An own catch whose own stored price rests on few lots counts as "the addon's own price" in the counts, although
  its value is the vendor price.
- Auctionator reports an update many times in a row (during its own scan or any search at the auction house): the
  windows update at most once per moment, not once per report.
- Auctionator's update notices keep coming after the player turned its switch off: they change nothing.
- The auction price switch is off: no auction price at all (vendor prices only), Auctionator's switch is inactive,
  and the scan entries follow today's rules (they are shown).
- An item with an Auctionator price below its vendor price counts as "Auctionator's price" in the counts; its value
  is the vendor price.
- Auctionator's tooltips are turned off in Auctionator: the item tooltip shows no auction price line at all; this is
  accepted.
- A character of another game mode: Auctionator answers with the prices of that character's own auction house; the
  addon's stored prices stay one table for the account (unchanged).
- The catalog's order by price uses the same values as the statistics, so it follows Auctionator's prices.
- The switches change while the addon's own scan runs: this cannot happen, since the switches are on the settings
  page and opening the settings closes the auction house, which stops the scan (spec 018, seen in game
  2026-11-18).

## Requirements *(mandatory)*

### Functional Requirements

Prices:

- **FR-001**: When Auctionator's prices are in use, the auction price of an item MUST be Auctionator's price when
  Auctionator has one, else the addon's own stored price, else none.
- **FR-002**: The value of a catch MUST be the higher of its auction price and its vendor price, whatever the source;
  with no auction price, the vendor price; with neither, "No price" where it is shown.
- **FR-003**: Auctionator's price MUST be used at any age and without the "few lots" rule.
- **FR-004**: The addon's own stored price used as a fallback MUST keep the "few lots" rule (the mark, and the vendor
  price in sums when it rests on few lots).
- **FR-005**: The addon MUST read Auctionator's prices when it needs them and keep none of them; its own stored
  prices MUST stay untouched while Auctionator's are in use.
- **FR-006**: When Auctionator reports that its prices changed, every open window that shows values MUST update
  without a reload, at most once per moment however many reports arrive.
- **FR-007**: A failing call to Auctionator MUST count as "no price" for that item, MUST be recorded in the error log
  once, and MUST NOT stop other values from showing; after it, Auctionator MUST count as not installed for the rest
  of the session.

The source:

- **FR-008**: Auctionator MUST count as installed only when both its price query and its update notice are
  available for the character, checked while the game runs (not while the addon's files load).
- **FR-009**: Auctionator's prices MUST be in use only when Auctionator is installed, the auction price switch is on
  and the Auctionator switch is on; otherwise the addon's own scan and prices work as in 1.3.2.
- **FR-010**: Changing either switch MUST take effect at once, without a reload, in every window, button and tooltip.

The scan's entries:

- **FR-011**: While Auctionator's prices are in use, the addon's scan entries above the auction house, in the
  statistics window and in the minimap menu MUST be hidden, and the addon MUST send no auction request.
- **FR-012**: While Auctionator's prices are in use, the scan command MUST answer with one line that the prices come
  from Auctionator, and start no scan.
- **FR-013**: The switches MUST be changed only on the settings page (no command changes them); so no scan of the
  addon's own runs when Auctionator's prices come into use.

Tooltips:

- **FR-014**: While Auctionator's prices are in use, the addon's own auction price line MUST NOT be added to the
  tooltip of an item Auctionator has a price for; for an item it has none for, the line MUST show the addon's own
  stored price used as the fallback, as today (with its "few lots" mark). The other tooltip lines of the addon
  (catch chances) stay.

Settings:

- **FR-015**: The settings MUST have a page "Auction prices" holding the auction price switch (removed from the main
  page's features) and, nested below it, the switch "take prices from Auctionator", on by default.
- **FR-016**: The Auctionator switch MUST be inactive while the auction price switch is off or Auctionator is not
  installed; when Auctionator is not installed, the page MUST say so; when it counts as not installed after a
  failing call (FR-007), the page MUST say instead that Auctionator failed this session and the addon's own scan is
  in use.
- **FR-017**: The page MUST show the source in use (Auctionator; the addon's own scan with the time of its last
  scan, or that there was none yet; or that auction prices are off and values are vendor prices) and the counts of
  FR-019, updated while the page is shown. That Auctionator is not installed, or failed, is the note of FR-016.
- **FR-018**: The page MUST NOT have a scan button or a reset button.

Counts and hints:

- **FR-019**: The addon MUST count the player's own catches that can be sold at auction (bound items left out, as in
  the addon's own scan) by the source of their auction price: Auctionator's price, the addon's own price, the vendor
  price only, no price at all. The settings page, the statistics line and the debug report MUST show the same
  counts.
- **FR-020**: While Auctionator's prices are in use, the statistics window's line about the values MUST say they come
  from Auctionator and, when some own catches have no Auctionator price, give their number with the advice to run
  Auctionator's scan; poor quality (grey) catches are left out of that number, since nobody lists them and the
  advice would never go (settled in the final code review).
- **FR-021**: Nothing about Auctionator's prices MUST be written to chat, except the scan command's answer of FR-012.
- **FR-022**: The debug report MUST show the source in use, whether each of Auctionator's two functions is there,
  both switches, the counts of FR-019 and the age in days of the oldest Auctionator price among the own catches (or
  that it is not known).

Rules of the project:

- **FR-023**: Every new visible text MUST exist in all nine translated languages.
- **FR-024**: The addon MUST use only Auctionator's public interface, copy none of its code, and work unchanged
  without Auctionator.
- **FR-025**: The settings MUST be switched only through the module that owns them, which tells the windows of the
  change (the project's rule for settings with an effect).

### Key Entities

- **Price source**: where auction prices come from right now: the addon's own scan, or Auctionator. Derived from
  whether Auctionator is installed and the two switches; never stored.
- **Auction price switch**: the existing account-wide setting "use auction prices for catch value", on by default;
  moves to the new page, keeps its saved value.
- **Auctionator switch**: a new account-wide setting "take prices from Auctionator", on by default; has an effect
  only with the auction price switch on and Auctionator installed.
- **Auctionator's price**: the cheapest unit price Auctionator saw for an item at its last scan or search, for the
  character's own auction house; read on demand, never kept by the addon; has an age in days that Auctionator forgets
  after its own history limit while the price stays.
- **Price counts**: the player's own catches that can be sold at auction, split by the source of their auction price
  (Auctionator's, the addon's own, vendor only, none); computed when shown.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After an Auctionator scan, every own catch it priced shows a value from its price within one second of
  the scan's end, with no press in OneKeyFishing and no reload.
- **SC-002**: While Auctionator's prices are in use, the player finds 0 scan entries of the addon in the auction
  house, the statistics window and the minimap menu, and the addon sends 0 auction requests.
- **SC-003**: Turning the Auctionator switch off brings back the addon's own prices and the scan entries of the
  statistics window and the minimap menu within one second, and the button above the auction house the next time it
  opens (the settings page closed it), with every price stored before still there.
- **SC-004**: No catch value is below the item's vendor price.
- **SC-005**: The counts on the settings page, in the statistics line and in the debug report are equal at any
  moment, and add up to the number of distinct own catches that can be sold at auction; after an Auctionator scan
  that priced every such catch, the statistics line gives no advice.
- **SC-006**: Without Auctionator, every value, button and command behaves as in 1.3.2, apart from the moved switch.
- **SC-007**: Every new visible text exists in all nine translated languages.

## Assumptions

- Auctionator version 347 is the reference; its public interface (the price, the age and the update notice by item)
  is documented by Auctionator as stable. It was seen working in WoW Forever.
- Auctionator keeps one price database per auction house as it sees them (per ruleset where names are unique across
  the region, as in Forever), so its answers fit the character's own auction house; the addon's own stored prices
  stay one table for the account (prices per game mode stay on the roadmap).
- Auctionator's price is the cheapest lot, the addon's own is the average of the cheapest fifth of the pieces; the
  two differ, and with Auctionator in use the values follow Auctionator, as the author decided.
- Auctionator has its price data only after the login; before that it answers "no price".
- The player's own catches are the items of the character's statistics (the total of all sessions of that
  character). Bound items cannot be sold at auction in WoW Forever (accepted in spec 018, V54).
- The switches are account-wide settings; Auctionator being installed is checked per character, since a player can
  enable it for some characters only.
- Out of scope: having Auctionator search the catches (its shopping lists or searches: they work by item name and
  their requests are outside the addon's guard; an idea in the roadmap); prices per game mode; sharing prices between
  players; other price addons; a scan button on the settings page.
- Release 1.4.0 (a minor version: a new settings page and a new price source).
