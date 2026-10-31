# Feature Specification: Catch Catalog, Map Pins and Catch Chances in Tooltips

**Feature Branch**: `002-shared-db` (all parts of the shared catch database are built on this branch)

**Created**: 2026-10-31

**Status**: Draft

**Release**: 1.2.0, together with parts 1, 2 and 3 of the shared catch database. Shared auction prices, optional in
the brief, are left out of this part and of 1.2.0. The pool split shows only where the game tells a pool from open
water (part 1's in-game check).

**Input**: User description: "Catch database, part 4 of 4 (release 1.2.0): a catalog of everything caught in the game,
and catch chances outside the current spot. Who and why: players want to find where a particular item is caught
without going there first, and they look at items and the minimap, not only at the statistics window. What the player
gets: a 'Catch catalog' tab in the statistics window: every item anyone with the addon has caught (bundled data, own
catch, other players), with a search by name in the player's language. Choosing an item lists the places it was
caught: zone, spot, chance, number of catches, skill range. Choosing a place sets a map pin there, and the game's
navigation arrow points to it. Places where the game does not allow pins (instances) are listed without the pin
button. Item tooltips: 'Caught in: Zone A 12%, Zone B 8%', the top 3 zones. The minimap button tooltip: the top 3
items of the current spot. If the game can tell them apart: pool catches separated from open water. Optional: shared
auction prices, so the catch value shows without a scan of one's own (the freshest scan wins; prices older than 3
days are not shared), only if the auction house scope in Forever allows it. Rules: the pin is the game's own user
waypoint, the same one a player sets by hand; nothing acts for the player. Searching and listing stay smooth with the
whole database loaded. Needs a spike check that map pins work in WoW Forever. Depends on parts 1 and 2 (part 3
optional). Design: docs/history/shared-db-plan.md (phase 6)."

## Clarifications

### Quiz on the gameplay, 2026-10-31

- Q: Shared auction prices (optional in the brief)? → A: Left out of 1.2.0 and moved to the roadmap. WoW Forever has no
  realms (game modes split by faction), and before the launch nobody can tell which auction house a player uses; a
  peer from another house would bring wrong prices.
- Q: How does the catalog show the places of an item? → A: One row per zone (the whole map's numbers); a zone
  expands into its grid cells, each with its own chance, catches and a pin button.
- Q: Which skill ranges count in the catalog and the item tooltip? → A: The catalog has the same skill filter as the
  "What can be caught here" tab, but "All" by default; the item tooltip always sums every range; a place row shows
  the span of skill the item was caught with there.
- Q: When does the item tooltip show "Caught in"? → A: Always, for every item in the database, with one checkbox in
  the settings to turn it off (on by default).
- Q: What is a cell called in an expanded zone? → A: The subzone name, for every player, plus the coordinates of the
  cell's average catch point. The game names the subzone at a position only for areas the player has explored, so the
  addon records the subzone while fishing (as a game number, not a name), shares it like the other counts, and every
  client shows the name in its own language.
- Q: What does the pin button do? → A: It sets the pin, turns on the navigation arrow, shows a short toast and opens
  the world map at that zone. If a pin that the addon did not set is already on the map, it asks first.
- Q: Places with fewer than 50 catches? → A: Listed with "little data" instead of a percentage, after the reliable
  ones. The item tooltip takes its top 3 from reliable zones and falls back to little-data zones, marked, only when
  there is no reliable one.
- Q: The order of the item list? → A: Alphabetical by name, without poor (grey) quality items.
- Q: Grey items: left out completely or only from the list? → A: Not in the list without a search, but a search
  finds them, and their tooltips keep the "Caught in" line. The "What can be caught here" tab keeps them, since they
  are part of the chances.
- Q: The minimap button tooltip? → A: The top 3 items of the current place, only in fishing mode, with the tab's
  defaults (own skill range, source "All", the 50-catch fallback); the same checkbox as the item tooltip turns it off.
- Q: Pools and open water, if the game tells them apart? → A: A "Water" filter, "Everywhere / Open water / Pools", in
  both tabs, "Everywhere" by default and shown only when there is pool data; the miss rate only under "Everywhere"
  (a miss has no loot, so no source); the tooltips use "Everywhere".
- Q: Where else does the catalog open on an item? → A: A click on an item row of "What can be caught here", and the
  command `/okf catalog` with a name or an item link.
- Q: The source mark (your catch / network / bundled data) planned for part 4 in the design? → A: Dropped. The
  "All / Only mine" source filter (in the catalog too) and "N catches from K players" already say where numbers come
  from.
- Q: What does the search look at? → A: The item name only: part of it, any letter case, in the client's language.
- Note: filters, the search text and the chosen item are not remembered, as in the other tab; only the last open tab
  is. Items the client does not know yet are hidden from the catalog until the game loads them, never refused (part
  3, FR-017a).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Find where an item is caught (Priority: P1)

A player wants a particular fish, say for a recipe, and does not know where it lives. They open the statistics
window on the "Catch catalog" tab and type part of its name in their own client language. The list narrows as they
type; they choose the fish and see the zones it was caught in, the best first: zone name, chance, how many catches the
numbers rest on, the skill it was fished with. Expanding a zone shows its fishing spots: the subzone and the
coordinates of each spot, with that spot's chance. The data comes from everything the addon knows: the bundled data,
the player's own fishing and, with sharing on, other players.

**Why this priority**: finding where an item is caught without going there first is the reason for this part;
everything else (the pin, the tooltips) builds on the same numbers.

**Independent Test**: with bundled data that holds several items in several zones, open the catalog, type part of an
item's name in a non-English client, choose the item and check that its zones are sorted by chance, that each zone
expands into its spots with subzone names in the client's language, and that the numbers match those the
"What can be caught here" tab shows when standing at that spot with the same filters.

**Acceptance Scenarios**:

1. **Given** the database holds items from the bundled data, the player's catch and other players, **When** the
   player opens the "Catch catalog" tab, **Then** every item is listed once, alphabetically by its name in the
   client's language, without poor (grey) quality items.
2. **Given** the catalog is open, **When** the player types part of an item name in any letter case, **Then** the
   list shows only the items whose name contains it, grey ones included, and updates with every typed letter.
3. **Given** the player chooses an item, **When** its places show, **Then** each zone it was caught in has one row
   with the zone name, the chance, the number of catches and the skill span of the data, sorted by chance, highest
   first, and zones with fewer than 50 catches come last with "little data" instead of a percentage.
4. **Given** a zone row, **When** the player expands it, **Then** its spots show, each with its subzone name in the
   client's language, the coordinates of the spot's average catch point, its chance and its catches, sorted the same
   way.
5. **Given** the skill filter "All" (the default) and the source filter "All", **When** the player picks one skill
   range or "Only mine", **Then** the zones, spots and numbers count only that data, and items without any such data
   leave the list.
6. **Given** the "What can be caught here" tab, **When** the player clicks an item row, **Then** the window switches
   to the catalog with that item chosen.
7. **Given** the player types `/okf catalog` with a name or an item link, **When** the command runs, **Then** the
   window opens on the catalog with that search, or with that item chosen.

---

### User Story 2 - Go to the spot (Priority: P2)

Having found the spot, the player presses its pin button. The game's own map pin, the same one a player sets by hand
on the world map, appears at the spot's average catch point; the game's navigation arrow points to it; a short toast
names the place; and the world map opens at that zone so the player sees where it is. The player walks or flies
there themselves. Spots on maps where the game allows no pins, such as instances, have no pin button.

**Why this priority**: knowing the zone is half the way; the pin turns the catalog into a route, but the catalog is
useful without it.

**Independent Test**: choose a spot in an open-world zone and press its pin button: the pin shows on the world map
and the minimap, the arrow points to it, the toast names the place and the map opens; put a pin by hand, press another
spot's pin button and check the confirmation; check that a spot inside an instance has no pin button.

**Acceptance Scenarios**:

1. **Given** a spot on a map the game allows pins on, **When** the player presses its pin button, **Then** the
   game's map pin is set at the spot's average catch point, the navigation arrow points to it, a toast names the
   place, and the world map opens at that zone.
2. **Given** the player is in combat, **When** they press a pin button, **Then** the pin, the arrow and the toast
   come as usual, and the world map does not open.
3. **Given** the player set a pin by hand (or another addon did), **When** they press a pin button, **Then** the
   addon asks whether to replace that pin; "Cancel" leaves the pin and everything else unchanged.
4. **Given** the pin on the map is the one the addon set last, **When** the player presses another pin button,
   **Then** the pin moves without a question.
5. **Given** a spot inside an instance, or a spot without a known position, **When** the zone is expanded, **Then**
   the spot is listed without a pin button.
6. **Given** a pin is set, **When** the player looks at their character, **Then** nothing moved or acted: the pin
   only marks the place.

---

### User Story 3 - Chances where the player already looks (Priority: P3)

The player hovers a fish in their bags, in the auction house or in a chat link and sees "Caught in:" with the three
best zones and their chances. While fishing, the minimap button's tooltip shows the three most likely catches of the
spot they stand at. A player who finds this noisy turns both off with one checkbox.

**Why this priority**: tooltips put the database in front of players who never open the statistics window; they
repeat what the catalog and the tab already know.

**Independent Test**: hover an item that is in the database and one that is not; check the lines, the order and
the "little data" mark; enter fishing mode and hover the minimap button; turn the checkbox off and check that both
lines are gone.

**Acceptance Scenarios**:

1. **Given** an item in the database, **When** the player hovers it anywhere the game shows an item tooltip,
   **Then** the tooltip shows "Caught in:" with up to three zones and their chances, highest first, counted over every
   skill range and source "All".
2. **Given** an item caught only in zones with fewer than 50 catches, **When** the player hovers it, **Then** the
   tooltip lists those zones marked "little data"; **Given** at least one zone with 50 catches or more, **Then**
   only such zones are listed.
3. **Given** an item that is not in the database, **When** the player hovers it, **Then** the tooltip has no new line.
4. **Given** the player is in fishing mode, **When** they hover the minimap button (or the addon's entry in the
   addon compartment), **Then** the tooltip adds the three most likely catches of the current place with their
   chances, by the player's own skill range, and how many catches from how many players they rest on.
5. **Given** the player is not in fishing mode, **When** they hover the minimap button, **Then** the tooltip is as
   before this part.
6. **Given** the checkbox "Show catch chances in tooltips" is off, **When** the player hovers an item or the minimap
   button, **Then** neither shows catch chances.

---

### User Story 4 - Pools apart from open water (Priority: P4)

Pools (visible spots on the water with their own catch) give different items than the open water around them. Mixed
together, a pool fish looks common where it is rare in open water, and the other way round. When the game tells the
two apart, both tabs offer a "Water" filter: "Everywhere" (the default, as now), "Open water" or "Pools".

**Why this priority**: it makes the numbers more honest for players who fish pools, but only if the game confirms
the difference, and everything else works without it.

**Independent Test**: with data that holds pool catches for a spot, check that the filter shows in both tabs, that
"Open water" and "Pools" split the catches of "Everywhere", and that the miss rate shows only under "Everywhere";
with no pool data at all, check that the filter is not there.

**Acceptance Scenarios**:

1. **Given** the database holds pool catches, **When** the player opens either tab, **Then** a "Water" filter offers
   "Everywhere", "Open water" and "Pools", with "Everywhere" chosen.
2. **Given** "Pools" is chosen, **When** the numbers show, **Then** they count only catches from pools, and the miss
   rate is not shown; **Given** "Open water", **Then** they count only the other catches.
3. **Given** the database holds no pool catches (or the game cannot tell pools apart), **When** the player opens
   either tab, **Then** there is no "Water" filter and everything works as before.

---

### Edge Cases

- **Empty database** (no bundled data, no catches): the catalog says that nothing has been caught yet, and how the
  data grows.
- **The search finds nothing**: the list says so; clearing the search brings the full list back.
- **An item the client does not know yet** (WoW Forever reveals some items only once someone finds them): it is not
  in the catalog list and no search finds it; once the game loads the item, it appears without reopening the
  window. The "What can be caught here" tab keeps its "Unknown item" row (part 3).
- **An item reported only by other players**: it shows only where part 3's rule allows it (at least three
  contributions on a map); a zone where fewer report it is left out of that item's places.
- **Item names that load late**: an item whose name the client has not loaded yet is listed as soon as the name
  arrives; a search typed before that finds it then.
- **A spot without a position** (the game gave none, for example in some instances): listed as "No exact spot" with
  its numbers, without coordinates or pin button.
- **A spot that lies across two subzones**: named after the subzone most of its casts were made in.
- **No subzone known for a spot** (data collected before this part, or the game named none): coordinates only.
- **A map inside a zone** (a cave or a building with its own map): the zone row names the enclosing zone and the
  inner map; where the inner map allows no pin but the enclosing zone does, the pin goes to the same spot on the
  zone's map.
- **The game turns map pins off** (a game rule, or a map that never allows them): no pin buttons there; nothing else
  changes.
- **The navigation arrow does not show** (WoW Forever has no setting for it in its interface): the pin is still set
  and shows on the map; the addon does not change the game's setting.
- **The player declines the replace question**: their pin stays; no toast, no map.
- **The game refuses the pin** (it does not take the point): a toast says the game did not accept the map pin; the
  addon remembers nothing, so the next press starts over.
- **The player removes the addon's pin by hand**: nothing happens; the next pin button press sets a new one without a
  question.
- **Data changes while the catalog is open** (a catch, data from other players, a new release's data): the list and
  the chosen item's places update without losing the search, the chosen item or the expanded zones.
- **Sharing is off**: the catalog and the tooltips count only the bundled data and the player's own catch, like the
  tab.
- **"Only mine" with no own catches**: the catalog says that the player has not caught anything yet.
- **The minimap tooltip at a place without data**: one line says that nothing has been caught here yet.
- **The minimap tooltip's top 3 holds an unknown or grey item**: such items are skipped and the next ones shown.
- **`/okf catalog` with an item link that is not in the database**: the catalog opens with the item's name in the
  search and says nothing was found.
- **`/okf catalog` with text that matches exactly one item**: that item is chosen at once.
- **The "Water" filter with few pool catches**: the 50-catch rule counts the filtered catches, so pools often show
  "little data" or fall back to the whole map, as the tab already does.
- **A zone name the game does not give** (an unknown map): the row says "Unknown zone" with the map number.

## Requirements *(mandatory)*

### Functional Requirements

**The catalog**

- **FR-001**: The statistics window MUST have a third tab, "Catch catalog". The window keeps remembering only the last
  open tab.
- **FR-002**: The catalog MUST list every item of the database under the current filters, once: the bundled data, the
  player's own catch and, with sharing on, other players' contributions. A row MUST show the item's icon and name and
  the number of zones it was caught in. The list MUST be sorted alphabetically by the item name in the client's
  language.
- **FR-003**: A search box MUST narrow the list to the items whose name contains the typed text, in any letter case
  (non-English letters included), by the item name in the client's language. The list MUST update while typing.
- **FR-004**: Without search text, the list MUST leave out items of poor (grey) quality; a search MUST find them.
- **FR-005**: Items the client does not know yet MUST be left out of the list and the search until the game loads
  them, and MUST then appear without the window being reopened. They MUST NOT be removed from the data (part 3,
  FR-017a). An item that is neither in the bundled data nor in the player's own catch MUST show for a map only under
  part 3's rule (FR-014: three different contributions on that map).
- **FR-006**: The catalog MUST offer a skill filter (each skill range and "All", "All" by default), a source filter
  ("All" and "Only mine", "All" by default) and, under FR-021, a water filter. Filters, the search text, the chosen
  item and the expanded zones MUST return to their defaults on the next login.
- **FR-007**: Choosing an item MUST list the zones it was caught in. A zone row MUST show the zone name, the item's
  chance in that zone, the zone's number of catches and the span of skill the item was caught with in that zone.
  Zones MUST be sorted by chance, highest first; zones with fewer than 50 catches MUST come after the others, by the
  item's catches there, with "little data" instead of a percentage.
- **FR-008**: A zone row MUST expand into the spots (grid cells) of that zone where the item was caught. A spot row
  MUST show the subzone name (FR-015), the coordinates of the spot's average catch point, the item's chance there,
  the spot's catches, the span of skill the item was caught with there and a pin button (FR-010). Spots MUST be
  sorted like zones, with the same "little data" rule.
- **FR-009**: Chances MUST be counted as everywhere else in the addon: catches that contained the item divided by
  all catches of the zone or spot, misses left out, with part 3's weights (FR-013 there). The zone and spot rows MUST
  say how many players the numbers come from, from 2 players on (part 3, FR-025).

**The map pin**

- **FR-010**: A spot row MUST have a pin button only when the spot has an average catch point and the game allows a
  map pin on its map. Where the spot's own map allows none but the enclosing zone's map does, the pin MUST go to the
  same spot on the zone's map. Instances, spots without a position and maps where the game turns pins off MUST have
  no button.
- **FR-011**: Pressing a pin button MUST set the game's own map pin (the one a player sets by hand on the world map)
  at the spot's average catch point, turn on the game's navigation to it, show a short toast naming the place, and
  open the world map at that zone. In combat the world map MUST NOT open; the pin, the navigation and the toast come
  as usual.
- **FR-012**: When a map pin that the addon did not set is on the map, the addon MUST ask before replacing it;
  "Cancel" MUST leave everything unchanged. A pin the addon set earlier MUST be replaced without asking.
- **FR-013**: The pin MUST only mark a place: setting it MUST NOT move the character or start any game action, and
  the player removes or replaces it the game's usual way (constitution Principle I).

**Subzone names**

- **FR-014**: While fishing, the addon MUST record, for each cast, which subzone of the map it was made in, as the
  game's number for the area (never a name), next to the other counts of the place. It MUST be shared with other
  players and carried in the bundled data like the other counts, and MUST be checked on receipt and by the release
  command (a spot's subzone counts never exceed its casts).
- **FR-015**: A spot row MUST be named after the subzone most of its casts were made in, in the client's language,
  for every player, whether or not that player has been there. Without a known subzone it MUST show the coordinates
  only.
- **FR-016**: A zone row MUST show the map's name in the client's language; for a map inside a zone (a cave, a
  building) it MUST show the enclosing zone's name and the inner map's name.

**Tooltips**

- **FR-017**: For every item in the database, item tooltips MUST add "Caught in:" with up to three zones and the
  item's chance in each, highest first, counted over every skill range, source "All" and water "Everywhere". Zones
  with 50 catches or more MUST be preferred; only when the item has none MUST zones with fewer be listed, marked
  "little data". Each zone line MUST say how many players its numbers come from, from 2 players on (part 3, FR-025).
  Items not in the database MUST get no line. Grey items MUST get the line too.
- **FR-018**: In fishing mode, the tooltip of the minimap button and of the addon's compartment entry MUST add the
  three most likely catches of the current place with their chances, counted like the "What can be caught here" tab
  with its defaults (the player's own skill range, source "All", water "Everywhere", the spot or, under 50 catches,
  the whole map, or "little data"), leaving out grey items and items the client does not know, plus one line "N
  catches from K players" (from 2 players on). At a place without data one line MUST say that nothing has been caught
  here yet. Outside fishing mode the tooltip MUST stay as it is.
- **FR-019**: One account-wide checkbox, "Show catch chances in tooltips", on by default, MUST turn the lines of
  FR-017 and FR-018 on and off together.
- **FR-020**: Tooltips MUST open without a noticeable delay, also while the player moves the mouse quickly over full
  bags.

**Pools and open water**

- **FR-021**: When the database holds any pool catches, both tabs ("What can be caught here" and the catalog) MUST
  offer a "Water" filter: "Everywhere" (the default), "Open water" (catches not from a pool) and "Pools" (catches from
  a pool only). Without any pool catches the filter MUST NOT show.
- **FR-022**: Under "Open water" and "Pools" the miss rate MUST NOT show, since a miss has no source; the 50-catch
  rule MUST count the filtered catches. The tooltips MUST always use "Everywhere".
- **FR-023**: The filter returns to "Everywhere" on the next login, like the other filters.

**Ways to the catalog**

- **FR-024**: A click on an item row of the "What can be caught here" tab MUST open the catalog with that item
  chosen. The catalog's filters stay its own.
- **FR-025**: `/okf catalog` MUST open the statistics window on the catalog. With text after it, the search MUST be
  filled with that text, and when exactly one item matches it MUST be chosen; with an item link, that item MUST be
  chosen, or, when it is not in the database, its name goes into the search. The command and its English description
  MUST be listed with the other commands (constitution Principle II, VI).

**Shared rules**

- **FR-026**: Every new visible text (the tab, the search box, the filters, the rows, "little data", the pin button,
  the toast, the replace question, the tooltip lines, the checkbox, the empty states) MUST go through the addon's
  translation system with all its languages.
- **FR-027**: The catalog, the search, choosing an item, expanding a zone and the tooltips MUST stay smooth with the
  largest database the addon allows (the bundled data at its size limit, 20,000 places of other players'
  contributions and the player's own catch): no stutter or frame rate drop the player notices.
- **FR-028**: The catalog and the tooltips MUST follow new data (a catch, data from other players, sharing switched
  on or off) without the window being reopened, keeping the search, the chosen item and the expanded zones.
- **FR-029**: With sharing off, the catalog and the tooltips MUST count only the bundled data and the player's own
  catch, as the tab does.
- **FR-030**: Before the release, an in-game check MUST confirm: that the map pin can be set on open-world maps and
  is refused on instance maps, that the navigation arrow points to it, what happens on maps inside a zone, whether a
  game rule turns pins off; which subzone the game reports while fishing; that item names load for the search; and,
  from part 1, whether pools can be told apart. The answers go into the project's record of verified game facts.

### Key Entities

- **Catalog item**: an item of the database under the current filters: its item number, its name and quality in the
  client's language, the zones it was caught in. Built from the data, never saved.
- **Zone entry**: one map an item was caught on: the map, the item's chance, the catches, the skill span, the
  players behind the numbers, whether it has little data, and its spots.
- **Spot entry**: one grid cell of a zone: the cell, its average catch point, its main subzone, the item's chance,
  the catches, the skill span, the players, and whether a pin can be set there.
- **Subzone counts** (new in the place data): per grid cell, the game's area numbers with how many casts were made in
  each. Shared and bundled like the other counts; holds numbers only.
- **The addon's map pin**: the game's own map pin as the addon last set it, remembered so that a pin the player set
  is told apart from the addon's (FR-012).
- **Tooltip setting**: one account-wide on/off value, on by default.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every item in the bundled data is found by a search for part of its name, in every game client
  language (enUS, deDE, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW: item names come from the client, not
  from the addon's interface language), tested with item names in each of their scripts, including letter case
  changes in non-English text.
- **SC-002**: From an open statistics window, a player gets from typing an item name to a pin on the map in five
  actions or fewer (type, choose the item, expand a zone, press the pin button, confirm if asked).
- **SC-003**: With the largest database the addon allows, typing a letter in the search, choosing an item, expanding a
  zone and opening an item tooltip each finish within the frame-time goal the addon already uses for its data work
  (under 5 ms per frame), and players notice no stutter.
- **SC-004**: In game, a pressed pin button puts the game's map pin on the chosen spot and the navigation arrow
  points to it, on every map the game allows pins on; no spot on an instance map has a pin button.
- **SC-005**: Two players with different client languages see the same zones, spots, chances and catch counts for
  the same item and filters, each with zone and subzone names in their own language.
- **SC-006**: 100% of items in the database get the "Caught in" line in their tooltips, no item outside it gets one,
  and with the checkbox off no tooltip shows catch chances.
- **SC-007**: With pool data, the catches under "Open water" and "Pools" add up to the catches under "Everywhere" for
  every spot and zone.
- **SC-008**: Nothing in this part acts in the game for the player: the only change it makes to the game is the map
  pin, and only when the player pressed a pin button.

## Assumptions

- Parts 1 to 3 (`specs/002-local-catch-db`, `specs/003-guild-group-sync`, `specs/004-public-channel-sync`) are in
  place: the place key, the bundled data, the exchange, the "What can be caught here" tab with its filters and the
  50-catch rule, the weights, the three-contributions rule and the "Unknown item" rows.
- The game cannot be played before 2026-11-04. The map pin, the navigation arrow, the subzone reported while fishing,
  the loading of item names and the pool split are assumed from the client's own interface export and checked in
  game before the release (FR-030).
- Shared auction prices are out of 1.2.0 (the author's choice): no client can tell which auction house its peers use
  before the launch, and wrong prices would mislead. The idea moves to the roadmap with this open question.
- The source mark the design planned for part 4 is dropped (the author's choice); the design and the roadmap are
  updated.
- The subzone counts are a new part of the place data. Nothing of the shared database is released yet, so data
  collected before this part simply has no subzone, and its spots show coordinates until new catches arrive; no saved
  data migration is needed.
- Subzone numbers are the game's own area numbers: no names travel, so every client shows the name in its own
  language, and an area is coarser than the average catch point a cell already carries, so privacy does not change.
- The coordinates of a spot are its average catch point on the map, in whole percent ("45, 72"), as the game's map
  shows positions; they are an average, not an exact fishing position.
- WoW Forever hides the setting for the navigation arrow from its interface; if the arrow is off by default, the pin
  still works, and the addon does not change the game's setting. The in-game check shows the default.
- The catalog's filters are its own: a click from the "What can be caught here" tab does not copy that tab's filters.
- The catalog hides items the client does not know, while the "What can be caught here" tab shows them as "Unknown
  item" rows: a name search cannot match an item without a name, and the tab is about the spot the player stands at.
- The players count on the item tooltip's zone lines follows part 3's FR-025 (every place that shows catch chances
  says how many players they come from).
- The tooltip checkbox lives on the addon's main settings page, since it covers the player's own data too, not only
  shared data.
- Grey means the item's quality as the client reports it.
- Out of scope: shared auction prices; a search by zone name (browsing another zone's catch); a source mark; prices
  in the catalog; noticing or pointing out nearby pools (a roadmap idea).
