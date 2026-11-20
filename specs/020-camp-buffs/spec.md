# Feature Specification: Fishing Camp Buffs

**Feature Branch**: `020-camp-buffs`

**Created**: 2026-11-19

**Status**: Implemented (in-game checklist `docs/checklists/camp-buffs.md` open)

**Input**: User description: "Fishing Camp Buffs". Catches made under the camp fishing buffs (the Fishing Rack's
"Uncommon Fishing" and the Fishing Hut's "Rare Fishing") are told apart from ordinary catches: in the player's own
data, in the catch database shared between players, in the catalog and in the "what can be caught here" tab. The
research, the in-game session of 2026-11-19 and the agreed wording are in
[docs/fishing-investigation.md](../../docs/fishing-investigation.md) ("Checked in game", "What it means for the
catch database", "Wording for the feature"). Planned for release 1.5.0.

## Clarifications

### Decisions of the author, 2026-11-19

The design interview after the in-game session; the numbers are referred to below as "decision N".

1. **Goal**: the addon records the buff with every cast, marks the bonus items with a tag and shows their honest
   chance; a hand-kept item list alone is not enough, since it collects nothing.
2. **The Fishing Hut is included now**, on an assumption: it could not be checked in game (it needs Fishing 300).
   Its buff is recorded the same way as the Rack's, as a condition of its own.
3. **Camper's Lure** (the lure a placed Fishing Rack hands out) joins the lures the addon applies, in this feature.
4. **No indicator of the buff**; a notice about its end and rows in the statistics are wanted.
5. **Storage**: the casts under a camp bonus are kept as parts inside a place's counts, already counted in the
   place's totals (settled while planning: one part per combination of buffs, so no cast is in two parts). Players
   on 1.4.0 keep working; a record that passes through such a player loses the split, never the totals.
6. **Display**: both a tag and a filter.
7. **Percentages**: a fraction for small chances, never "0%" for something that was caught.
8. **Camper's Lure's place** among the lures: by strength, after the +75 lures and before the +50 ones.
9. **The filter** sits where the hidden "Water" button is, in both tabs, and shows only when there is data for it.
10. **The filter's default** is "All catches" in both tabs; it never switches by itself with the player's buff.
11. **The tag's rule**: the known Bloated fish get the Rack's tag from a list at once; any other item gets a tag
    from the data.
12. **Both buffs at once**: the cast counts for both conditions.
13. **The notice**: one 5 minutes before the buff ends and one when it has ended, only in fishing mode, with a
    setting of its own, on by default.
14. **Statistics**: "Casts with a camp bonus" and "Bonus catches" in all three columns of the statistics window
    (the session, the current zone, the total), Rack and Hut together.
15. **Little data**: a bonus item's chance needs 50 catches under its buff at the place, the same threshold as
    today; below it the row says "Little data" and still carries the tag.
16. **"No camp bonus"** is the filter value's short name; the button's tooltip says it also holds catches whose
    buff is not known.
17. **A doubtful cast counts for no condition**: when the buff's state is unknown, or changed between the cast and
    its end, the cast counts only in the ordinary totals.
18. **The tag also shows in the item tooltip** lines of the addon.
19. **The bundled catch database carries the split too**, so a new player sees chances with the bonus at once.
20. **Wording**: the player-facing terms are "camp bonus" and "bonus catch"; things are named after what the
    player places (Fishing Rack, Fishing Hut), the buff's own name only in explanations. The texts are the table
    in the investigation document; the Ukrainian ones were agreed with the author (Fishing Rack, Fishing Hut and
    "Uncommon Fishing" in his wording).

### Decisions of the author, 2026-11-20

The design interview after the first try of the feature in game: with the filter on "Fishing Rack" the list showed
every fish, which is by design (a part holds every catch of the casts under the buff) but not what the author wanted
to see; the filter row was hard to read, and the two tabs were laid out differently. The numbers go on from the
decisions above.

21. **The follow-up stays in this spec**: new requirements (FR-041 to FR-048) and tasks (T041 onwards), no new
    spec. The "Fishing Rack" value keeps its meaning (every catch of the casts under the buff).
22. **Two rows of filter buttons in both tabs.** "What can be caught here": row A Skill, Source; row B the one slot
    (Water or Camp bonus), then Kinds. Kinds leaves its top right corner, so the place's line has the full width.
    The catalog: the search box, the status line under it, row A Skill, Source, row B the slot, Kinds, Sort, then
    the list.
23. **The button shows its value**: "Camp bonus: <short value>", each a whole text of its own ("Camp bonus: All",
    "Camp bonus: No bonus", "Camp bonus: Bonus only", "Camp bonus: Rack", "Camp bonus: Hut"), so each language
    words it its own way; the menu keeps the full labels.
24. **A new filter value "Bonus catches only"**, after "No camp bonus": a list filter over "All catches" that keeps
    only the tagged items (the known Bloated fish always, and the items tagged from the data), like the kind filter.
25. **One value for every bonus**: "Bonus catches only" holds the tagged items of the Rack and of the Hut alike; the
    bonus values ("Fishing Rack", "Fishing Hut") are there for the full picture of one bonus.
26. **The numbers of "All catches"**: under "Bonus catches only" the counts line and the miss rate are those of "All
    catches", and each row shows its chance with the bonus, as it does under "All catches". An empty list says "No
    bonus catch has been recorded here yet." ("What can be caught here") or "No bonus catch has been recorded yet."
    (the catalog).
27. **"Per catch" without ".0"**: one decimal, written whole when the rounded value is whole, with the client's
    decimal separator: 1 reads "1", 1.04 "1", 1.25 "1.3", 1.5 "1.5" ("1,5" on a German client).
28. **The hints and the exchange line at the top** of "What can be caught here": under the place and the scope line,
    above the counts, in a room of up to three lines that is always kept, so nothing below moves.
29. **The list of "What can be caught here" scrolls**, with the catalog's scroll list (shared by both tabs); "and N
    more" stays only in the fallback list of a client without the scroll templates.
30. **The catalog's status line under the search box**; on an item's page it sits where the zones begin.
31. **An item's page under "Bonus catches only"** shows all the item's zones, as under "All catches".

### Decisions of the author, 2026-11-20, after the Hut session

The in-game session with a Fishing Hut (docs/fishing-investigation.md, "Checked in game", "The Fishing Hut") showed
that the Hut's extra item is a second loot slot from a mixed table (Bloated fish, Blindweed, Mithril Bar, Iron Ore,
Heavy Hide, Dream Dust), that the Hut gives Bloated fish too, and that "Bonus catches" stayed 0 under the Hut, whose
known list was empty. The addon's cyan lines in the catalog's item tooltips sometimes showed white. The numbers go
on from the decisions above (FR-049 to FR-052, tasks T048 onwards).

32. **Bloated fish belong to both bonuses.** The twelve Bloated fish are the known list of the Rack and of the Hut
    alike. In "All catches" such an item takes, among its bonuses, the one under which it has the most catches in
    the selection; with no catch under either, the Rack's (the cheapest way to get it), with "Little data". Its
    explanation names both camp features. The Hut's other extras (a herb, ore, a bar, a hide, enchanting dust) are
    not listed: they are ordinary items elsewhere and are tagged from the data by FR-017.
33. **A bonus catch in the statistics** is a catch under a buff that holds a known item of one of its bonuses, or
    that has two loot slots or more once the quest items fished beside an ordinary catch are left out (a list kept
    with the game data, and any item of the quest class). Without a buff a catch has one slot (the session of
    2026-11-19; pools, schools and wreckage give one item); only fished quest items come as a second slot without a
    buff, which the bundled database confirms (0.9 % extra slots, at the places of the quest fish). Old statistics
    are not recounted: the Hut session's 0 stays.
34. **The addon's coloured lines in item tooltips carry their colour as a code in the text too**, as the minimap
    tooltip's lines already do (spec 012 R5): another addon or the game may reset the line colours. The code wraps
    the translated text, never inside an `L[...]` string.
35. **"No camp bonus" lists no tagged item** (the author, 2026-11-20, during the in-game checks): the mirror of
    "Bonus catches only". A Bloated fish of older catches whose bonus is not known stays in the sums of "No camp
    bonus" but leaves the list in both tabs; the counts line and the other chances do not change.

### Facts from the game, 2026-11-19

They shape the requirements; the full session is in the investigation document.

- A Fishing Rack placed by a campfire gives the buff "Uncommon Fishing" for one hour, at once, to the player who
  places it and to a party member standing next to it. The buff outlives the Rack (15 minutes), a trip to another
  zone and a relog, and ends on death.
- The buff can be told by its ID out of combat; in a fight it cannot be read at all, though it is still there.
- Nothing else changes under the buff: the same cast, the same bobber, the same source of the loot.
- The bonus is an **extra item in the same catch**: twice the ordinary fish came with its Bloated form next to it
  (Bloated Mithril Head Trout with Raw Mithril Head Trout). It is rare: none in the first hour, two in the second.
- A placed Rack can be opened for 5 Camper's Lure: +60 Fishing for 5 minutes, needs Fishing 50, applied to the pole
  like any other lure.
- Not known: everything about the Fishing Hut's buff; whether a Bloated fish ever comes without the buff; whether
  both buffs can be held at once; whether a player outside the group gets the buff from someone else's Rack.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Catches under a camp bonus are recorded apart (Priority: P1)

A player places a Fishing Rack by a campfire, gets the one-hour fishing buff and fishes. The addon notes for every
cast whether a camp bonus was active, and keeps those casts, their misses and their items as a part of the place's
counts, next to the totals it has always kept. The player does nothing for it and sees nothing new yet: the data
simply stops losing the difference.

**Why this priority**: everything else in the feature reads this data, and catches recorded without it can never
be split afterwards; every week without it adds data that stays mixed for good.

**Independent Test**: fish with the Rack's buff and without it at one place, then look at the place's counts in
the debug report: the casts, misses and items under the buff are counted apart and are also inside the totals.

**Acceptance Scenarios**:

1. **Given** a player with the Fishing Rack's buff, **When** a cast ends with a catch, **Then** the place's totals
   grow as before and the place's "Fishing Rack" part grows by the same cast and items.
2. **Given** a player with the buff, **When** a cast ends with nothing caught, **Then** the miss is counted in the
   totals and in the "Fishing Rack" part.
3. **Given** a player without any camp buff, **When** a cast ends, **Then** only the totals grow.
4. **Given** a buff that ends while the line is out, **When** the cast ends, **Then** the cast counts only in the
   totals, for no condition.
5. **Given** a player whose buff could not be read (a fight started before the addon ever saw the buff's state),
   **When** a cast ends, **Then** the cast counts only in the totals.
6. **Given** a player who had the buff before a fight, **When** they fish after the fight, **Then** the casts count
   for the buff again without any action of the player.
7. **Given** a player with both the Rack's and the Hut's buff, **When** a cast ends, **Then** it counts for both
   conditions (it is there under the "Fishing Rack" filter and under the "Fishing Hut" filter) and once in the
   totals.

---

### User Story 2 - Bonus catches carry a tag and an honest chance (Priority: P1)

A player opens the "what can be caught here" tab or the catalog and sees a Bloated fish in the list. Its row carries
the Fishing Rack's icon, and its tooltip says "Fishing Rack bonus", so the player knows it is not an ordinary catch
of this water and what to do to get it. The
chance next to it is the chance among catches made with the bonus, not a number diluted by everyone who fished
there without one. The same words stand in the item's tooltip.

**Why this priority**: this is what the player asked for: not to have bonus fish mixed with ordinary fish without
a word, and a number that means something.

**Independent Test**: with data that holds catches under the Rack's buff, open both tabs and an item tooltip: the
Bloated fish carries the tag and a chance computed from the catches under the buff; ordinary fish look as before.

**Acceptance Scenarios**:

1. **Given** a place where a Bloated fish was caught, **When** the player looks at its row in either tab, **Then**
   the row carries the Fishing Rack's icon as its tag, and the row's tooltip names it "Fishing Rack bonus" and
   explains that the item comes only with the buff of a Fishing Rack.
2. **Given** a place with at least 50 catches under the Rack's buff, **When** the player looks at a tagged item,
   **Then** its chance is its catches under the buff divided by all catches under the buff; the tooltip calls it a
   chance "with the bonus".
3. **Given** a place with fewer than 50 catches under the buff, **When** the player looks at a tagged item,
   **Then** the row carries the tag and says "Little data" instead of a chance.
4. **Given** a Bloated fish that is in the data only from before this feature (the buff not known), **When** the
   player looks at it, **Then** it carries the tag and "Little data": the old catches give it no chance.
5. **Given** an item that is not on the known list and was caught only under the Hut's buff, by at least three
   players or in the bundled data, **When** the player looks at it, **Then** it carries the tag "Fishing Hut bonus".
   A Bloated fish caught only under the Hut's buff carries the Hut's tag, and its explanation names both the Rack
   and the Hut (decision 32).
6. **Given** an ordinary fish caught with and without a buff, **When** the player looks at it, **Then** it has no
   tag and its chance is computed as today.
7. **Given** a tagged item, **When** the player hovers it anywhere in the game, **Then** the addon's tooltip lines
   say it is a bonus catch of the Rack (or the Hut).

---

### User Story 3 - A filter by camp bonus (Priority: P2)

A player who wants to plan a fishing trip chooses "Fishing Rack" in the "Camp bonus" filter and sees what is
caught at a place with that bonus, with chances among those catches; "No camp bonus" shows the place without it;
"Bonus catches only" shows just the bonus catches, with the numbers of all catches. The button names the chosen
value ("Camp bonus: Rack"). The filter is there only when there is something to filter.

**Why this priority**: the tag already answers "what is this fish"; the filter adds the full picture per bonus and
is the only way to see misses and chances of everything under one bonus. It needs the data of story 1 first.

**Independent Test**: with data under the Rack's buff, switch the filter through its values in both tabs and
compare the lists and numbers with the counts of the place.

**Acceptance Scenarios**:

1. **Given** no catch under any camp buff in the data, **When** the player opens either tab, **Then** there is no
   "Camp bonus" filter.
2. **Given** data under the Rack's buff only, **When** the player opens the filter, **Then** it offers "All
   catches", "No camp bonus", "Bonus catches only" and "Fishing Rack", and no "Fishing Hut".
3. **Given** the filter on "Fishing Rack", **When** the list is shown, **Then** it holds only what was caught under
   that buff, the chances and the miss rate are computed among the casts under it, and the 50-catch threshold
   applies to those catches.
4. **Given** the filter on "No camp bonus", **When** the list is shown, **Then** it holds the totals minus the
   catches under a camp buff, and the button's tooltip says this also includes catches whose bonus is not known.
5. **Given** the filter on "All catches", **When** the list is shown, **Then** the numbers of ordinary items are
   the same as before this feature.
6. **Given** a player who gets or loses a camp buff, **When** they look at the tabs, **Then** the filter's value
   has not changed by itself.
7. **Given** any value of the filter, **When** the button is shown, **Then** it reads "Camp bonus: " with the
   value in short ("Camp bonus: All", "Camp bonus: No bonus", "Camp bonus: Bonus only", "Camp bonus: Rack",
   "Camp bonus: Hut"), and the menu names the values in full.
8. **Given** the filter on "Bonus catches only" at a place where a Bloated fish was caught, **When** the list is
   shown, **Then** it holds only the tagged items, the counts line and the miss rate are those of "All catches", and
   each row shows the same chance as under "All catches".
9. **Given** the filter on "Bonus catches only" at a place with catches but no tagged item, **When** the list is
   shown, **Then** "What can be caught here" says "No bonus catch has been recorded here yet." and the catalog,
   with no tagged item anywhere, "No bonus catch has been recorded yet.".
10. **Given** the catalog on "Bonus catches only", **When** the player opens a listed item, **Then** its page shows
    all its zones, as under "All catches".
11. **Given** either tab with the filter shown, **When** the player looks at the buttons, **Then** they stand in two
    rows: Skill and Source, then the Camp bonus button and Kinds (and Sort in the catalog).

---

### User Story 4 - Small chances are readable (Priority: P2)

A player looks at a rare catch and sees "0.47%" instead of "0%". Wherever the addon shows a chance or a share, a
small one is written with a fraction, and something that was caught at least once never reads as zero.

**Why this priority**: bonus catches are rare by nature, so without this the new honest chance would read "0%";
the same defect already hides every rare catch in the lists today.

**Independent Test**: open a place with a rare item and compare the shown chance with its counts.

**Acceptance Scenarios**:

1. **Given** a chance of 37.4 %, **When** it is shown, **Then** it reads "37%".
2. **Given** a chance of 3.44 %, **When** it is shown, **Then** it reads "3.4%".
3. **Given** a chance of 0.468 %, **When** it is shown, **Then** it reads "0.47%".
4. **Given** a chance that would round to 0.00 % (below 0.005 %) of an item that was caught, **When** it is shown,
   **Then** it reads "<0.01%".
5. **Given** a miss rate or any other share the addon shows as a percentage, **When** it is shown, **Then** it
   follows the same rule.

---

### User Story 5 - A notice before the camp bonus ends (Priority: P3)

A player fishing under a camp bonus gets a notice five minutes before it ends, in time to light a fire and place a
new Rack, and another when it has ended, also when it ended by death out of a fight. A player who does not want
them turns them off with one setting.

**Why this priority**: a convenience on top of the data; the buff's own icon already shows its time.

**Independent Test**: fish in fishing mode with a buff that has less than five minutes left and wait for it to
end.

**Acceptance Scenarios**:

1. **Given** fishing mode on and a camp buff with more than five minutes left, **When** five minutes are left,
   **Then** one notice says the Fishing Rack bonus (or the Fishing Hut bonus) ends in 5 minutes.
2. **Given** fishing mode on and a camp buff, **When** the buff ends out of a fight, by time or by death, **Then**
   one notice says the bonus has ended.
3. **Given** fishing mode off, **When** a camp buff runs low or ends, **Then** there is no notice.
4. **Given** the setting "Warn when a camp bonus is ending" off, **When** a buff runs low or ends, **Then** there
   is no notice.
5. **Given** catch notifications off and the setting on, **When** a buff ends in fishing mode, **Then** the notice
   is still shown.
6. **Given** a player who enters fishing mode with less than five minutes of the buff left, **When** the buff
   ends, **Then** only the "has ended" notice is shown.
7. **Given** a buff that is renewed by a new Rack, **When** five minutes of the new hour are left, **Then** the
   notice comes again.

---

### User Story 6 - Camp bonus rows in the statistics (Priority: P3)

A player who farms with a Rack sees in the statistics window how many casts of the session, of the current zone and in
total were made with a camp bonus and how many of them brought a bonus catch.

**Why this priority**: it lets the player judge whether a Rack is worth its reagents; it does not affect the
shared data.

**Independent Test**: fish with the buff until a bonus catch comes and read the two rows.

**Acceptance Scenarios**:

1. **Given** a player who never cast under a camp buff, **When** they open the statistics, **Then** the two rows
   are not shown.
2. **Given** casts under a camp buff, **When** the player opens the statistics, **Then** "Casts with a camp bonus"
   counts them for the session, the current zone and in total, Rack and Hut together.
3. **Given** a catch under a buff that held a known bonus item of that buff (a Bloated fish under the Rack's or
   the Hut's), or a second loot slot that is not a fished quest item (a herb or ore under the Hut's), **When** the
   player opens the statistics, **Then** "Bonus catches" grew by one, however many bonus items the catch held
   (decision 33).
4. **Given** a cast that counted for no condition (story 1, scenarios 4 and 5), **When** the statistics are shown,
   **Then** it is not among the casts with a camp bonus.

---

### User Story 7 - The Rack's lure is applied like any other (Priority: P3)

A player took Camper's Lure from a placed Fishing Rack. In fishing mode the fishing key offers it like the other
lures, by strength: before the +50 lures, after the +75 ones.

**Why this priority**: small and independent of the rest; without it the player applies the camp's free lure by
hand while the addon applies bought ones.

**Independent Test**: with Camper's Lure and a weaker lure in the bags and no lure on the pole, press the fishing
key.

**Acceptance Scenarios**:

1. **Given** Camper's Lure and Nightcrawlers in the bags and no lure on the pole, **When** the key offers a lure,
   **Then** it is Camper's Lure.
2. **Given** Camper's Lure and Bright Baubles in the bags, **When** the key offers a lure, **Then** it is Bright
   Baubles.
3. **Given** a Fishing skill below 50, **When** the key offers a lure, **Then** Camper's Lure is passed over.
4. **Given** Camper's Lure on the pole, **When** the player fishes, **Then** the addon treats the pole as lured for
   the lure's five minutes.

---

### User Story 8 - The split reaches other players (Priority: P1)

A player who never placed a Rack opens the catalog and still sees which items are bonus catches and what their
chance with the bonus is, because other players' records and the bundled catch database carry the split.

**Why this priority**: the shared database is the point of the addon's data; a split that stays on one machine
answers nobody's question.

**Independent Test**: exchange records between two clients of the new version, one of which fished under the
buff, and compare the other's lists; build the bundled database from records with a split and read it.

**Acceptance Scenarios**:

1. **Given** two players on the new version, **When** one's record with catches under a buff reaches the other,
   **Then** the other sees the tag, the chances with the bonus and the filter values for those places.
2. **Given** a player on 1.4.0, **When** a record with a split reaches them, **Then** it is accepted, its totals
   are counted as before, nothing is shown wrongly and the sender is not ignored.
3. **Given** a record that reached a new client through a 1.4.0 client, **When** it is counted, **Then** its totals
   are right and its catches count as "bonus not known".
4. **Given** a record whose condition part claims more casts, misses or items than the place's totals, **When** it
   arrives, **Then** it is refused like any other record that fails its checks.
5. **Given** records with a split, **When** the bundled catch database is built from them, **Then** it carries the
   summed split, and a fresh install shows chances with the bonus from it.

---

### Edge Cases

- The player logs in or reloads the interface during a fight: the buff's state is unknown until the fight ends, and
  casts until then count for no condition.
- The buff is granted while the line is out (a party member places a Rack): the cast counts for no condition; the
  next one counts for the buff.
- The player dies: the buff is gone and later casts count without a condition. Out of a fight the "has ended"
  notice is shown once, if fishing mode is on; a death in a fight follows FR-033.
- A bonus item is caught in a cast that counted for no condition (the buff ended in that cast): the item counts in
  the totals only. For an item of the known list the tag stays; for another item this one catch outside a
  condition means it is not "caught only under a buff" at that place.
- An item of the known list turns out to be caught without the buff too: its tag would mislead. This is the open
  assumption of decision 11; when the game disproves it, the item leaves the list and the data decide.
- An item was caught only under a buff once, by one player, because nobody fished that water without one yet: it would
  get a tag from the data. A tag from the data therefore needs the bundled database or three different players behind
  it (FR-017).
- Catches under both buffs: the cast counts for both conditions, so a place's catches under the Rack and under the
  Hut may add up to more than its catches under any buff; the stored parts themselves never overlap and never
  exceed the totals. "No camp bonus" leaves such a cast out once.
- An item caught only under buffs, but some catches under the Rack alone and others under the Hut alone: under
  neither condition lie all its catches, so it gets no tag from the data. Accepted: it shows as an ordinary item
  until the known list names it.
- A place whose every catch was made under a buff: "No camp bonus" is empty for it and says so like any empty list.
- The filter stands on "Fishing Hut" and the last Hut data disappear (a record was withdrawn): the filter falls
  back to "All catches".
- Old data and the bundled database from before this feature hold no split: the filter does not show until the
  first catch under a buff is in the data.
- The filter and the existing filters (skill range, source, kinds, search, sort) combine: each narrows the same
  list. Under the source "Only mine" no item is tagged from the data (one player), only the known items, so "Bonus
  catches only" then lists the known items alone.
- "Bonus catches only" at a place where only ordinary fish were caught under a buff: there is bonus data, so the
  filter shows, but nothing is tagged; the list is empty and says so (FR-045).
- An item tagged on one map and caught without a buff on another: the catalog's list and the item tooltip follow
  the item's best place; each zone and spot row shows its own tag.
- Pool data and camp bonus data both exist (a record from before spec 011 still carries a pool part): the one
  slot shows the "Camp bonus" filter and the "Water" filter stays hidden; the two cannot be combined, since the
  data do not say which pool catches were made under a buff.
- A chance of exactly 0 (an item listed for a place with no catches in the chosen selection) is not shown as
  "<0.01%": the item is simply not in that list.
- Camper's Lure is Unique (5) and conjured: the player may have none left mid-session; the key then offers the
  next lure as with any lure that ran out.

## Requirements *(mandatory)*

### Functional Requirements

**Recording**

- **FR-001**: The addon MUST know two camp fishing buffs, each a condition of its own: the Fishing Rack's ("Uncommon
  Fishing") and the Fishing Hut's ("Rare Fishing"). They MUST be recognised by their game IDs, never by name, and
  the set MUST be a list that can grow.
- **FR-002**: For every fishing cast the addon MUST determine, for each condition, whether the buff was active:
  once when the cast starts and once when the cast is settled (a catch or a miss).
- **FR-003**: While the game does not let the buff be read (a fight), the addon MUST use the state it last read,
  and MUST treat the state as unknown when it never read one in this session.
- **FR-004**: A cast MUST count for a condition only when that condition's buff was known to be active both at the
  cast's start and at its settling. A cast whose state for a condition is unknown or differs between the two
  moments MUST NOT count for that condition.
- **FR-005**: A cast that counts for a condition MUST add to that condition's part of the place: the cast, a miss
  when nothing was caught, and each item with its catches and pieces. The same cast MUST add to the place's totals
  exactly as before this feature.
- **FR-006**: A cast under both buffs MUST count for both conditions (in each condition's filter, tag and chance)
  and once in the totals; it MUST be stored once.
- **FR-007**: Recording MUST need no action of the player: every cast the addon records today (a cast made with
  its fishing key) is recorded with its condition, under the same rules and nothing more.
- **FR-008**: Nothing in this feature may cast, use an item, place a camp feature or react to the bobber for the
  player; the addon only reads the buff.

**Storage and sharing**

- **FR-009**: The stored parts MUST be inclusive and must not overlap: their casts, misses and item counts are
  already contained in the place's totals, a cast is in at most one part, and the parts together may not exceed
  the totals in any number.
- **FR-010**: The split MUST travel with the player's record through the catch exchange between clients of the new
  version, and be kept through relays between such clients.
- **FR-011**: A client of 1.4.0 MUST accept a record that carries a split, count its totals as before, and neither
  refuse the record nor ignore its sender. Losing the split on a path through such a client is accepted.
- **FR-012**: A received record whose condition part breaks FR-009, names an unknown condition in a broken form, or
  is otherwise malformed MUST be handled by the same rules as any record that fails its checks; an unknown but
  well-formed condition from a newer version MUST NOT make the record invalid.
- **FR-013**: Catches without a split (older data, the bundled database of earlier versions, records that lost the
  split on the way) MUST count as "bonus not known": in the totals, in "All catches" and in "No camp bonus", and in
  no condition.
- **FR-014**: The bundled catch database MUST carry the summed parts of the records it is built from, checked by
  the same rules, and a fresh install MUST read them like any other data.
- **FR-015**: Existing saved data MUST stay valid without conversion; a player who updates loses nothing.

**Tag**

- **FR-016**: The twelve known Bloated fish (items 6643, 6644, 6645, 6646, 6647, 8366, 13881, 13891, 21162, 21163,
  21164, 21243) MUST carry the tag of a camp bonus (the Rack's or the Hut's: FR-049) wherever they are listed, from
  a list kept with the game data,
  whatever the collected data say and whatever the filter's value. Under "No camp bonus" (where its older catches with
  the bonus not known are counted) and under the filter of another condition it keeps the tag and its chance is the
  plain one of that selection, not a chance "with the bonus"; under "No camp bonus" the lists leave it out (FR-053),
  so the plain tag shows only on the catalog item page's zone and spot rows.
- **FR-017**: Any other item MUST carry a condition's tag at a selection of places when all its counted catches there
  lie in that condition's part, and none outside it. A tag from the data MUST also need the bundled database to hold
  the item under that condition, or at least three different players' data (the own catch counts as one) to do so, the
  same number as the rule for an item new to a map; one player's catch alone gives no tag.
- **FR-018**: An item that qualifies for both conditions' tags MUST show the Fishing Hut's (the higher feature);
  an item of the known list takes its tag by FR-049.
- **FR-019**: The tag MUST show in the rows of the "what can be caught here" tab and of the catalog as a small icon
  of the camp feature (the Fishing Rack's or the Fishing Hut's own item icon) next to the item, since the columns
  have no room for its words. The row's tooltip MUST say the words: the tag's name, that the item comes only with
  the buff of a Fishing Rack (or a Fishing Hut) with the buff's name, and the chance "with the bonus" with the
  players behind it. These lines come from the row's own data and MUST show whatever the tooltip settings; the
  addon's lines of an item tooltip elsewhere in the game carry the tag's explanation too.

**Chance**

- **FR-020**: A tagged item's chance MUST be computed among the catches of its condition's part: its catches there
  divided by all catches there. The row's chance cell shows the number alone; the tooltip marks it as a chance
  "with the bonus". The catches and the players shown next to a tagged item's chance MUST be those under its
  condition, not those of the whole place.
- **FR-021**: A tagged item's chance MUST be shown only when its condition's part holds at least 50 catches in the
  selection; otherwise the row MUST say "Little data" and keep the tag.
- **FR-022**: Items without a tag MUST be computed and shown as before this feature when the filter is on "All
  catches". With a condition chosen in the filter, every item's chance, tagged or not, is the one among that
  condition's catches (FR-025), and a tagged item shows it as a chance "with the bonus".

**Filter**

- **FR-023**: Both tabs MUST offer a filter "Camp bonus" with the values "All catches", "No camp bonus", "Bonus
  catches only" (FR-043), "Fishing Rack" and "Fishing Hut", in the place of the hidden "Water" button.
- **FR-024**: The filter MUST be shown only when the addon's data (the bundled database, the own counts or a held
  record of another player, at any place) hold at least one cast under a condition; a condition's value MUST be
  offered only when those data hold casts under that condition. "All catches", "No camp bonus" and "Bonus catches
  only" are offered whenever the filter is shown.
- **FR-025**: With a condition chosen, the list, the chances, the miss rate, the counts and the 50-catch threshold
  MUST be computed from that condition's part only.
- **FR-026**: With "No camp bonus" chosen, they MUST be computed from the totals minus every cast that counted for
  at least one condition; the button's tooltip MUST say that this also holds catches whose bonus is not known.
- **FR-027**: The default MUST be "All catches". The filter MUST NOT change by itself when the player gains or
  loses a buff. A chosen value that is no longer offered MUST fall back to "All catches".
- **FR-028**: The filter MUST combine with the existing filters, search and sort of each tab.

**Percentages**

- **FR-029**: Every chance or share the addon shows as a percentage MUST be written with the precision of its size:
  a whole number from 10 % up; one decimal from 1 % to below 10 %; two decimals below 1 %; and "<0.01%" for a value
  above zero that would round to "0.00%". The edges are those of rounding, so a text like "10.0%" or "1.00%" never
  appears: 9.96 % reads "10%", 0.996 % reads "1.0%", 0.006 % reads "0.01%", 0.004 % reads "<0.01%".
- **FR-030**: A value above zero MUST never be shown as "0%". Sorting by chance MUST use the exact value, not the
  shown text.

**Notices**

- **FR-031**: While fishing mode is on, the addon MUST show one notice when a camp buff has five minutes left and
  one when it has ended, by time or by death out of a fight, each naming the Fishing Rack bonus or the Fishing Hut
  bonus. The five-minute notice comes only within 30 seconds of the threshold: one passed while it could
  not be shown (fishing mode off, the setting off, a fight) is passed, and no late "ends in 5 minutes" comes
  afterwards.
- **FR-032**: The notices MUST obey a setting "Warn when a camp bonus is ending", on by default, and MUST be shown
  when it is on even with catch notifications off. They MUST NOT be shown outside fishing mode.
- **FR-033**: A buff's "five minutes" notice MUST come at most once per granted hour; a renewed buff counts as a new
  one. While the buff cannot be read (a fight) no notice is shown from the clock alone; the end notice comes with the
  first reading after it, or not at all if the buff was renewed meanwhile or fishing mode is no longer on then (with
  "Leave fishing mode when attacked" on, the default, the mode has ended with the fight, so a buff lost in a fight
  gives no notice).

**Statistics**

- **FR-034**: The statistics MUST count, for the session, the current zone and in total, the casts that counted
  for at least one condition ("Casts with a camp bonus") and the catches under a condition that held at least one
  known bonus item of that condition (FR-016's list) or a second loot slot by FR-050 ("Bonus catches"), Rack and
  Hut together. An item tagged only from the data does not count by itself: the statistics are the player's own and
  must not change afterwards with what other players report.
- **FR-035**: Both rows MUST be hidden while the character's total of casts with a camp bonus is zero, and both
  shown from the first such cast on ("Bonus catches" then may read 0).

**Camper's Lure**

- **FR-036**: Camper's Lure (item 291005: +60 Fishing, 5 minutes, needs Fishing 50) MUST be one of the lures the
  fishing key offers, ranked by strength after Bright Baubles and before Aquadynamic Fish Lens, under every rule
  that applies to lures today (the skill it needs, cooldowns, the lure setting).

**Texts and documents**

- **FR-037**: Every new visible text MUST use the agreed wording (the table "Wording for the feature" of the
  investigation document), with its nine translations in the same change; the two terms "camp bonus" and "bonus
  catch" MUST be the only names of the concept in the interface, the manual and the changelog.
- **FR-038**: The debug report MUST show the conditions the addon knows, the buff state it last read for each
  (active, not active, unknown), and for the current place the counts of each condition's part.
- **FR-039**: The player manual and the changelog MUST describe the tag, the filter, the notices, the statistics
  rows, the new percentage format and Camper's Lure.
- **FR-040**: Everything the game has not confirmed MUST be marked in the code and listed in this feature's
  verification document (V60 to V69): all behaviour of the Fishing Hut's buff, that the known Bloated fish come only
  under the buff, that both buffs can be held at once, when the game decides a catch's bonus (at the cast or at the
  hook), the aura's clock, the aura events out of a fight, the camp features' icons, the size of a record with
  parts, and that a catch without a buff has one loot slot, quest items aside.

**After the first try in game (decisions 21 to 31)**

- **FR-041**: Both tabs MUST lay their filter buttons out in two rows. "What can be caught here": row A Skill and
  Source; row B the one slot (the Water or the Camp bonus button, FR-023), then Kinds; the Kinds button no longer
  sits at the top right, so the place's line has the tab's full width. The catalog, top to bottom: the search box,
  its status line (FR-048), row A Skill and Source, row B the slot, Kinds and Sort, then the list. In row B each
  button follows the one before it, so a longer text pushes the next one along; without pool or bonus data Kinds
  starts the row.
- **FR-042**: The Camp bonus button MUST read "Camp bonus: " with the chosen value in short, one whole text per value
  so that each language words it its own way: "Camp bonus: All", "Camp bonus: No bonus", "Camp bonus: Bonus only",
  "Camp bonus: Rack", "Camp bonus: Hut". The menu MUST name the values in full (FR-023); the button's tooltip keeps
  "Camp bonus" as its title.
- **FR-043**: The value "Bonus catches only" MUST come after "No camp bonus" in the menu. It is a filter of the list
  over "All catches", like the kind filter: it keeps the items that carry a tag (FR-016 to FR-018: the known Bloated
  fish always, and the items tagged from the data), one value for every condition. It needs no sums of its own: the
  catch database never sees it, and the catalog reads the index of "All catches" for it.
- **FR-044**: Under "Bonus catches only" every number MUST be the one of "All catches": the counts line and the miss
  rate are unchanged, and each row shows its chance with the bonus (or "Little data") as under "All catches". In the
  catalog, a listed item's page MUST show all the item's zones, as under "All catches".
- **FR-045**: Under "Bonus catches only" an empty list MUST say so: "No bonus catch has been recorded here yet." in
  "What can be caught here" (where the place has catches but no tagged item), "No bonus catch has been recorded
  yet." in the catalog's status line. The kind filter's messages stay as they are when it hides the tagged items.
- **FR-046**: The "Per catch" column MUST be rounded to one decimal and written whole when the rounded value is
  whole, with the client's decimal separator: 1 reads "1", 1.04 "1", 1.25 "1.3", 1.5 "1.5" ("1,5" on a German
  client).
- **FR-047**: "What can be caught here" MUST show, from the top: the place, the scope line, the hints (up to three
  lines, their room always kept, so nothing below moves), the exchange line, the counts, the two rows of buttons,
  the column headers and the list. The list MUST scroll (the catalog's scroll list, shared by both tabs); the line
  "and N more" MUST appear only in the fallback list of a client without the scroll templates.
- **FR-048**: The catalog's status line (the index being counted, the empty states) MUST sit under the search box on
  the list, and where the zones begin on an item's page.

**After the Hut session (decisions 32 to 34)**

- **FR-049**: The twelve Bloated fish MUST be known bonus items of the Rack and of the Hut alike (one list named by
  both). Under "All catches" such an item MUST carry the tag of the bonus under which it has the most catches in the
  selection, with that bonus's chance and players (FR-020, FR-021); with no catch under either, the Rack's tag (the
  lower-ranked bonus, the cheapest way to get it) with "Little data". Under a bonus's value it carries that bonus's
  tag with the selection's own numbers; under "No camp bonus" it keeps the Rack's tag with the plain chance
  (FR-016) where it is shown, and the lists leave it out (FR-053). The Hut's other extras are not listed; FR-017
  tags them from the data.
- **FR-050**: A catch under a condition MUST count as a bonus catch (FR-034) when it holds a known item of one of its
  conditions, or when it has two loot slots or more once the quest items fished beside an ordinary catch are left
  out: the items of a list kept with the game data (Electropeller, Nat Pagle's four fish, the two fish of the
  Stranglethorn Fishing Extravaganza) and any item of the quest class. Old statistics MUST NOT be recounted.
- **FR-051**: An item known to more than one condition MUST be explained by one text naming both camp features:
  "Bonus catch: comes only with the buff of a Fishing Rack or a Fishing Hut.", wherever the tag's explanation shows
  (the row's tooltip and the addon's lines of an item tooltip); its tag's name stays that of the chosen bonus.
- **FR-052**: Every coloured line the addon adds to an item tooltip or to the minimap button's tooltip ("Caught
  in:", the tag's name, the fishing gear lines, the grey "(few lots)" price line) MUST carry its colour as a code
  around the translated text as well as in the line's colour, so a reset of the tooltip's line colours leaves it
  coloured.
- **FR-053**: Under "No camp bonus" the list of "What can be caught here" and of the catalog MUST leave out every
  item with a camp bonus tag, plain ones too (decision 35); the counts line and the other items' numbers stay those
  of "No camp bonus".

### Key Entities

- **Condition**: a camp fishing buff a cast can be made under (the plan, the code and the interface call it a
  "bonus"; a combination of active conditions is a "mask" there). Today two: Fishing Rack ("Uncommon Fishing") and
  Fishing Hut ("Rare Fishing"). It has a game ID, a name for the player and a rank (the Hut above the Rack).
- **Buff state**: what the addon knows about a condition right now: active, not active or unknown, and when an
  active one ends.
- **Condition part of a place**: the casts, misses and items made at a place under one combination of conditions,
  contained in the place's totals; what was made under one condition is the sum of the parts that include it. Shared
  with the player's record and summed across players like the totals.
- **Known bonus item**: an item tied to a condition by the game data list (the twelve Bloated fish, tied to both
  the Fishing Rack and the Fishing Hut since decision 32).
- **Tag**: the mark "Fishing Rack bonus" or "Fishing Hut bonus" on an item in a list or a tooltip, from the known
  list or derived from the data.
- **Camp bonus filter**: the player's choice of which casts a tab counts: all, those under no condition, or those
  under one condition; or, as a filter of the list over all casts, only the tagged items ("Bonus catches only").
- **Camp bonus counts**: the statistics' two numbers per period: casts with a camp bonus, bonus catches.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After an hour of fishing with a Fishing Rack's buff, every cast of that hour, except those in which
  the buff began or ended, is counted under the Rack at its place, and the place's totals equal what they would be
  without this feature.
- **SC-002**: A player looking at a Bloated fish in either tab or in its tooltip can tell, without leaving the
  list, that it is a bonus catch and which camp feature gives it.
- **SC-003**: At a place with at least 50 catches under the Rack's buff, the shown chance of a bonus item equals
  its share among those catches, to the shown precision.
- **SC-004**: No item that was caught at least once is shown with "0%" anywhere in the addon.
- **SC-005**: Two players on the new version who exchange records directly, or through players on the new version
  only, see the same tags and the same chances with the bonus for the same places. A record that first arrived
  through a 1.4.0 player stays without its split until its owner fishes again.
- **SC-006**: A player on 1.4.0 who receives records with a split sees the same totals as from records without one,
  no error and no refused sender.
- **SC-007**: A player in fishing mode whose camp buff runs out gets exactly one notice five minutes before and
  exactly one at the end, and none with the setting off.
- **SC-008**: With "All catches" chosen, every number shown for an untagged item equals the number shown by 1.4.0
  for the same data, apart from the new percentage format.
- **SC-009**: A fresh install of the version whose bundled database was built from records with a split shows a
  bonus item's tag and, where 50 catches under the buff exist, its chance, before any exchange with other players.
- **SC-010**: A player with Camper's Lure in the bags never has to apply it by hand while the addon's lure setting
  is on.

## Assumptions

- The Fishing Hut's buff behaves like the Fishing Rack's: a readable player buff of one hour that outlives the
  placed Hut. It was not checked in game (it needs Fishing 300). If it behaves differently, the Hut's condition
  records nothing or wrongly until fixed; the Rack is not affected.
- The twelve Bloated fish are caught only under a camp buff. Seven catches of them in the bundled database predate
  this feature with the buff unknown, so the game has not proven it. If one is caught without a buff, its tag is
  wrong until the item leaves the list.
- The server decides a catch's bonus by the buff the player has during the cast; which moment exactly is not known.
  Requiring the same state at the cast's start and at its end keeps the doubtful casts out, at the cost of one cast
  per hour.
- A bonus is an extra item next to the ordinary fish (seen twice in game), so the chances of ordinary items are not
  distorted by counting casts with and without a buff together, and "All catches" stays the right default.
- Without a camp buff a catch has one loot slot, apart from the quest items fished beside an ordinary catch
  (decision 33; seen in open water and a pool, and in the bundled database). If another item comes as a second slot
  without a buff, a catch under a buff that holds it counts as a bonus catch and "Bonus catches" reads too high
  until the item joins the quest list.
- Both buffs may be held at once. If the game never allows it, the "both" case simply never occurs.
- A 1.4.0 client drops the part of a record it does not know and passes the record on without it (read from its
  code). The loss shrinks as players update; its size cannot be measured, since the exchange carries no version.
- The threshold of 50 catches is as good for a condition's part as for a place. Bonus catches are rare (two in an
  hour of fishing at best), so most places will say "Little data" for a long time; this is preferred to chances
  from a handful of casts.
- A camp buff's remaining time can be read with the buff, so the five-minute notice needs no timer started at the
  placing.
- Camper's Lure needs Fishing 50 by its tooltip; like the other lures, the game is assumed to compare the base
  skill.
- The agreed English texts are final; the Ukrainian ones were agreed with the author, the other seven translations
  follow the game's own names of the camp features in each language where the client has them.
- Out of scope: statistics of what fished containers hold (in the roadmap); an indicator of the buff; a filter that
  follows the player's buff; conditions other than the two camp buffs (season, quest, tournament), though the list
  of conditions is built so that they can join later; placing or using a camp feature for the player.
- Depends on: the catch database and its exchange (specs 002 to 005, 016), the catalog and its filters (specs 005,
  014, 017), the toast and the statistics window, the lure handling of fishing mode.
