# Feature Specification: Auction Scan

**Feature Branch**: `018-auction-scan`

**Created**: 2026-11-17

**Status**: Implemented (in-game checklist `docs/checklists/auction-scan.md` open)

**Input**: User description: "We start working on our own auction scan in this spec. We keep to the project's
architecture, use Auctionator's best practices while developing, and must use our own research in the game. We
optimise where we can." (translated). The addon's price scan is slow on a fresh login, loses prices, covers only the
player's own catches and does not notice an auction house that stopped answering. The research, the measurements in
the game and the author's decisions of 2026-11-17 are in [docs/auction-plan.md](../../docs/auction-plan.md); the
measured facts are in [docs/forever-api.md](../../docs/forever-api.md), "The auction house's request system".

## Clarifications

### Decisions of the author, 2026-11-17

- This spec is the addon's own scan only, released as 1.3.2. Auctionator as a price source is the next spec (019,
  release 1.4.0) and is not part of this one.
- The scan becomes faster by never asking about an item before the game knows it, by sending the next request the
  moment the auction house is ready for one, by not loading result pages the price does not need, and by leaving out
  items that cannot be sold at auction.
- A price is fresh for 15 minutes. A press scans what is not fresh, the oldest first; when every price is fresh, the
  press scans everything again.
- The scan covers everything the catch catalog shows, not only what the player caught. What is shown does not
  change: the auction price when the scan found one, else the vendor price, else "No price".
- The auction house can stop answering (it then shows nothing until the character logs out and in). The scan notices
  it within 10 seconds, stops and keeps the prices found; one chat line explains it, and the scan cannot be started
  while the auction house does not answer. The scan itself must not cause that state.
- Other players' records may be forged and name an item the game does not have, and asking about such an item is one
  of the things that stop the auction house. So the scan takes the player's own catches first, then the items of the
  catch database that ships with the addon, then the items known only from other players' records; an item the
  auction house did not answer for is remembered and not asked about again; after one such item from other players'
  records, the items known only from those records are left out.
- No scan starts by itself: only a press of a scan button or the scan command.
- Prices stay one table for the account (not split by game mode); that waits for an answer from the game.

### Settled while writing the spec

- The two orders above combine as: the three groups in their order (own catches, bundled database, other players'
  records), and inside a group the items with the oldest price first, an item never scanned before all others.
- What the scan remembers for protection (the items the auction house did not answer for, and that other players'
  items are left out) lasts until the addon's next version. A new version has a new bundled database and may have
  new rules, and an item remembered by mistake (a lost connection in the middle of a scan) gets its price back then.
- An item is not remembered when its answer does arrive later in the same session: the auction house was slow, not
  stopped.

### Settled while planning

- The scan keeps inside the game's documented limit of 100 search requests a minute: the next request goes out when
  the auction house is ready, but not sooner than 0.6 seconds after the previous one (plan, research R2). What the
  server does above its limit is not known, and an unanswered request costs a relog.
- An item a scan finds not on sale keeps the price of an earlier scan, as today; only the time of its last scan is
  new (plan, research R7).
- The scan's own request that is still unanswered when the player closes the auction window is remembered when the
  window is opened again and the auction house stays not ready for 10 seconds (plan, research R3).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A fast scan that loses no prices (Priority: P1)

A player logs in, goes to the auction house and presses "Scan fish prices". The scan runs at the pace the auction
house allows, without long pauses, and finds the same prices whether it is the first scan after a login or the tenth.

**Why this priority**: this is the defect every player has today: measured in the game, the same 40 items took 162
seconds and found 31 prices on a first scan, 28 seconds and 32 prices on the next one.

**Independent Test**: right after a login, scan a list of at least 30 items, note the time and the number of prices;
scan again at once (every price is fresh, so everything is scanned again): the two times are close and the number of
prices is the same.

**Acceptance Scenarios**:

1. **Given** a first scan after a login, **When** the scan runs, **Then** it takes no more than one second per
   searched item on average, and no item waits several seconds for an answer that does not come.
2. **Given** two scans of the same items a minute apart with the same items on sale, **When** both finish,
   **Then** both report the same number of prices found.
3. **Given** an item with many auctions, **When** the scan has loaded enough of them to know the price, **Then** it
   goes to the next item without loading the rest, and the price and its "few lots" mark are the same as with every
   auction loaded.
4. **Given** an item that cannot be sold at auction (an item bound to the player), **When** a scan
   runs, **Then** the item is not searched.
5. **Given** a running scan, **When** the player looks at the scan button, **Then** it shows the progress as today
   (items done and items in all).

---

### User Story 2 - Auction prices in the whole catalog (Priority: P1)

A player opens the catch catalog to see what is worth catching in zones they have not fished yet. After a scan every
item of the catalog that is on sale shows its auction price, not only the items the player caught.

**Why this priority**: the catalog's order by price (1.3.1) is of little use while most of its items show the vendor
price; the author asked for it.

**Independent Test**: on a character that caught only a few kinds of fish, run a scan and open the catalog ordered
by price: items the character never caught, but which are on sale, show their auction price.

**Acceptance Scenarios**:

1. **Given** an item of the catalog the player never caught and which is on sale, **When** a scan finishes,
   **Then** the catalog, "What can be caught here" and the item's tooltip use its auction price, by the same rules as
   for a caught item.
2. **Given** an item of the catalog that is not on sale and never had a scanned price, **When** a scan finishes,
   **Then** it shows its vendor price, or "No price" when it has none; an item with a price from an earlier scan
   keeps that price, as today.
3. **Given** a scan, **When** it starts, **Then** the player's own catches are searched first, then the items of the
   catch database that came with the addon, then the items known only from other players' records.
4. **Given** the catalog's filters (kinds, skill, source, water, search) hide some items, **When** a scan runs,
   **Then** the hidden items are scanned too: the filters are a view, not the scan's list.
5. **Given** an item the game does not know yet (it has no name in the catalog), **When** a scan runs, **Then** it
   is not searched.

---

### User Story 3 - The scan stops when the auction house stops answering (Priority: P1)

The auction house stops answering in the middle of a scan, or had stopped before the player pressed the button.
Instead of running on for minutes and reporting "0 prices found", the scan stops within seconds, keeps what it
found and tells the player what to do.

**Why this priority**: in that state the auction house shows nothing until a relog; a player who is not told thinks
the addon or the game is broken. The scan must also never be the cause.

**Independent Test**: without the game: a stand-in auction house that never answers a chosen item; the scan stops
at that item, keeps the earlier prices, reports once, and does not send another request.

**Acceptance Scenarios**:

1. **Given** a running scan, **When** a request gets no answer for 10 seconds, **Then** the scan stops, sends no
   further request, keeps every price found so far, and one chat line says that the auction house does not answer
   and that logging out and in brings it back.
2. **Given** an auction house that already does not answer, **When** the player looks at a scan button, **Then**
   the button cannot be pressed and says that the auction house does not answer; the scan command answers the same.
3. **Given** the auction house answers again (after a relog, or by itself), **When** the player looks at a scan
   button, **Then** it can be pressed as usual.
4. **Given** any scan, **When** it runs, **Then** it sends one request at a time, and only while the auction house
   is ready to take one.
5. **Given** the player closes the auction window during a scan, **When** it closes, **Then** the scan stops as
   today (the prices found are kept), and it is not counted as an auction house that does not answer.

---

### User Story 4 - A repeated scan is short (Priority: P2)

A player scans, buys something, and presses the button again a few minutes later, or the scan was cut short when the
window closed. The next press searches only what still needs it.

**Why this priority**: with the whole catalog in the list a full scan takes about a minute; a player should pay
that once per visit, not on every press.

**Independent Test**: scan, close the auction window halfway, open it and scan again: only the items not scanned in
the first run are searched. Scan once more right after it finished: everything is scanned again.

**Acceptance Scenarios**:

1. **Given** some items scanned less than 15 minutes ago and some not, **When** the player starts a scan, **Then**
   only the others are searched, and the chat line names that number.
2. **Given** every item scanned less than 15 minutes ago, **When** the player starts a scan, **Then** every item is
   searched again.
3. **Given** a scan stopped by closing the window, **When** the player starts a scan within 15 minutes, **Then** it
   continues with the items the stopped scan did not reach.
4. **Given** items never scanned and items with an old price in one group, **When** a scan runs, **Then** the never
   scanned ones go first, then the others from the oldest price to the newest.

---

### User Story 5 - A forged record cannot keep the auction house stopped (Priority: P2)

Another player's addon sends a record with an item that the game does not have. The first scan that asks about it
stops the auction house once; the addon makes sure it does not happen a second time.

**Why this priority**: scanning the whole catalog (User Story 2) opens this door; without the protection one bad
record would stop the auction house of every player on every scan.

**Independent Test**: without the game: a catalog with one item of another player's record that the stand-in auction
house never answers. The first scan stops at it with every own and bundled item already scanned; the second scan
does not ask about it, nor about any item known only from other players' records.

**Acceptance Scenarios**:

1. **Given** a request for an item got no answer, **When** the scan stops, **Then** the item is remembered and no
   later scan asks about it.
2. **Given** the unanswered item was known only from other players' records, **When** later scans run, **Then**
   they leave out every item known only from other players' records.
3. **Given** the unanswered item's answer arrives later in the same session, **When** it arrives, **Then** the item
   is not remembered and nothing is left out because of it.
4. **Given** remembered items, **When** the addon is updated to another version, **Then** nothing is remembered any
   more and the items of other players' records are scanned again.
5. **Given** remembered items, **When** the player opens the debug report, **Then** it lists them and says whether
   other players' items are left out.
6. **Given** an item that is both in the player's own catches (or the bundled database) and in other players'
   records, **When** scans run, **Then** it counts as an own (or bundled) item.

---

### Edge Cases

- Nothing to scan (no catch yet and an empty catalog): the present message "catch some fish first" stays.
- The auction house was not ready when the scan started (another addon's request is on its way): the scan waits for
  it to be ready. The 10 seconds count from the moment the auction house was first seen not ready, and start again at
  the scan's own request and at every answer the auction house sends (steady answered traffic of another addon is not
  a stop); when it does not become ready in that time, the scan reports the auction house as not
  answering and remembers no item.
- A connection lost during a scan: the item waiting for its answer may be remembered by mistake; it is forgotten
  with the next version, and its price until then is the last one scanned or the vendor price.
- The game's information about an item does not arrive (the item is not searched in this scan, is not remembered, and
  is tried again in the next scan).
- Auction prices turned off in the settings: the scan can still be run, as today; the prices are not used.
- An item caught for the first time during the visit joins the next scan as an own catch.
- The scan command and the scan buttons of the statistics window and the minimap menu follow the same rules as the
  button above the auction window: one "can scan now" rule for all. (The settings page's scan button was removed
  on 2026-11-18: opening the settings closes the auction house window, so it could never be pressed.)
- An item whose only auctions have no buyout price still has no auction price, as today.
- A price found by an earlier version stays valid; it has an age and is scanned by the freshness rule.
- The auction house's own search by the player during a scan uses the same request line; the scan waits its turn and
  does not treat the wait as an auction house that does not answer.

## Requirements *(mandatory)*

### Functional Requirements

Speed and completeness:

- **FR-001**: Before the scan asks the auction house about an item, the game MUST already hold that item's
  information; the scan MUST ask the game for the information of every item of its list when it starts and search an
  item only once the information is there.
- **FR-002**: The scan MUST send its next request when the auction house reports that it is ready, without a fixed
  pause per item, one request at a time and never above the game's documented limit of 100 search requests a minute
  (constitution, Principle I).
- **FR-003**: The scan MUST stop loading further auctions of an item once the loaded ones decide its price; the price
  and the "few lots" mark MUST equal the ones every auction of the item would give.
- **FR-004**: The scan MUST NOT search an item that cannot be sold at auction: an item bound to the player. (A poor quality
  item was first left out too; the game lists it, measured 2026-11-18, so it is searched.)
- **FR-005**: The price rule MUST NOT change: the average unit price of the cheapest fifth of the pieces on sale, the
  "few lots" mark, the higher of the vendor and the auction price for values.

The scan's list:

- **FR-006**: The scan's list MUST be: the items the player caught (as today), the items of the catch database that
  ships with the addon, and the items of other players' records (while the catch exchange is on, as in the catalog), each item once, in
  the first group it belongs to in that order.
- **FR-007**: The scan MUST go through the groups in that order; inside a group, an item never scanned comes first,
  then the others from the oldest price to the newest.
- **FR-008**: The catalog's filters and the kind choice MUST NOT change the scan's list. An item the game has no
  information about MUST NOT be searched.
- **FR-009**: Every place that shows an item's value (the catalog, "What can be caught here", the statistics, the
  tooltips) MUST use a price found for an item the player never caught by the same rules as for a caught one.

Fresh prices:

- **FR-010**: A price MUST count as fresh for 15 minutes after its item was scanned, whether the scan found a price
  or found the item not on sale.
- **FR-011**: A scan MUST search only the items that are not fresh; when every item of the list is fresh, it MUST
  search all of them.
- **FR-012**: The chat line at the start of a scan MUST name the number of items it will search, and the line at its
  end the number of prices found among them, as today.

The auction house that does not answer:

- **FR-013**: When a request of the scan gets no answer for 10 seconds, the scan MUST stop, send no further request,
  keep the prices found, and say in one chat line that the auction house does not answer and that logging the
  character out and in brings it back.
- **FR-014**: While the auction house is not ready to take a request for 10 seconds or more, a scan MUST NOT start:
  every scan button MUST be disabled and say why, and the scan command MUST answer with the same reason. When the
  auction house is ready again, the buttons MUST work again without a reload.
- **FR-015**: The scan MUST NOT send a request while the auction house is not ready for one, and MUST NOT use any
  request that is known to get no answer in WoW Forever ([docs/forever-api.md](../../docs/forever-api.md)).
- **FR-016**: Closing the auction window during a scan MUST stop the scan as today and MUST NOT count as an auction
  house that does not answer.

Protection:

- **FR-017**: An item whose request got no answer MUST be remembered for the account, and no scan MUST ask about a
  remembered item. When the answer arrives later in the same session, the item MUST be forgotten again.
- **FR-018**: After a remembered item that was known only from other players' records, scans MUST leave out every
  item known only from other players' records.
- **FR-019**: What FR-017 and FR-018 remember MUST be dropped when the addon runs as another version than the one
  that remembered it.
- **FR-020**: The debug report MUST list the remembered items and say whether other players' items are left out.

No new automation:

- **FR-021**: A scan MUST start only on the player's press of a scan button or the scan command, never by itself.

Texts and documents:

- **FR-022**: Every new visible text MUST be shown in the addon's language, with a translation for each of its nine
  translated languages.
- **FR-023**: The change MUST be recorded in the changelog under "Unreleased" and described in the player manual
  (what is scanned, the fresh prices, the auction house that does not answer); the new saved fields and the scan's
  rules MUST be described in the developer documents.
- **FR-024**: The behaviour only the game can show MUST be handed to the author as an in-game checklist, and every
  assumption of that kind MUST be marked in the code until the author confirms it.

### Key Entities

- **Scan list**: the items one scan may search: own catches, bundled catch database, other players' records, in that
  order; without the items that cannot be sold, the items the game has no information about, the remembered items
  and (after FR-018) the items of other players' records.
- **Item price**: what a scan found for an item: the price, the pieces and price points it rests on, and when it was
  scanned. Account-wide, kept between sessions. An item found not on sale gets no new price (an earlier one stays) but
  still a time of its last scan.
- **Fresh price**: an item scanned less than 15 minutes ago.
- **Remembered item**: an item the auction house did not answer for; account-wide; with the version of the addon
  that remembered it.
- **Left-out mark**: whether items known only from other players' records are left out of scans; account-wide; with
  the same version.
- **Auction house state**: closed, open and ready, open and busy, or not answering (not ready for 10 seconds or
  more); decides whether a scan can start.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A first scan after a login takes no more than one second per searched item on average (measured before:
  four seconds per item).
- **SC-002**: A first scan after a login and a scan repeated right after it find the same number of prices (measured
  before: 31 and 32 of 40).
- **SC-003**: After a full scan, every item of the catalog that is on sale and can be sold shows its auction price,
  also on a character that caught none of them.
- **SC-004**: A scan started again within 15 minutes of a stopped one searches only the items the stopped one did
  not reach.
- **SC-005**: When the auction house stops answering, the player is told within 15 seconds, no further request is
  sent, and every price found before is kept.
- **SC-006**: One item the auction house does not answer for stops a player's auction house at most once per
  version of the addon. One exception is accepted: a player who closes the auction window within 10 seconds of the
  stop and logs out without opening it again is stopped a second time, and the item is remembered then.
- **SC-007**: No scan starts without a press by the player.
- **SC-008**: Every new visible text exists in all nine translated languages.

## Assumptions

- A full scan of the whole catalog is about a minute at the auction house's pace (0.7 seconds per item, 80 items in
  the bundled database of 1.3.1 plus the player's own); that is accepted because the next presses are short.
- Bound items cannot be sold at auction in WoW Forever (accepted without a check, V54); an item wrongly left out
  would only lack an auction price. Poor quality items can be sold (measured 2026-11-18) and are searched.
- An item of the bundled catch database is answered by the auction house. Winter Squid (13755), in the bundled
  database, was measured unanswered on 2026-11-17 and answered with a price by this scan on 2026-11-18
  (docs/forever-api.md). An item measured never to be answered is listed in the game data
  (`GameData.AuctionUnanswered`, empty today) and never searched; every other item is protected by FR-017.
- The auction house stops answering only until the character logs out and in; whether it ever recovers by itself is
  not known, so the state is read from the game each time and never stored.
- The 15 minutes, the 10 seconds and the three groups are fixed values, not settings.
- Out of scope: Auctionator as a price source (spec 019); prices per game mode; a scan that starts by itself; asking
  again when an answer is empty although the item is on sale (not seen in the game); a command to forget the
  remembered items; sharing prices between players.
- The knowledge about how the game's auction requests behave comes from the author's measurements in the game and
  from reading Auctionator (its way of waiting for an item's information, of sending on the game's ready signal and
  of paging); none of its code is used, and it is not required for this feature.
- New saved data is added without changing the shape of the stored prices, so prices found by earlier versions
  stay.
- Release 1.3.2 as a patch, by the author's decision, although the scan's behaviour changes; the changelog says what
  changes for the player.
