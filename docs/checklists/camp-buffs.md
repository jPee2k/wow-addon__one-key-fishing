# In-game checklist: camp buffs

**Feature**: catches made with a camp bonus (the fishing buff of a Fishing Rack or a Fishing Hut) recorded apart and
shared; the bonus tag and its chance with the bonus; the "Camp bonus" filter; the percentages with a fraction; the
notices before and at a buff's end; the statistics rows; Camper's Lure; after the first try in game (2026-11-20) the
value "Bonus catches only", the button that names its value, the two rows of buttons, the scrolling list of "What can
be caught here" with its hints at the top, "Per catch" without ".0" and the catalog's status line under the search
box; after the Hut session (2026-11-20) the Bloated fish under both bonuses, the bonus catches with a second loot slot
and the colour of the addon's tooltip lines (`specs/020-camp-buffs`).
**Closes**: `V60` to `V69` of [verification.md](../../specs/020-camp-buffs/verification.md); SC-001, SC-002, SC-004 to
SC-007 and SC-010 of the spec, which only the game can show; the fit and the look of FR-041 to FR-048 (steps 3 and 10
to 13); FR-049 to FR-052 (steps 14 to 16).
**Needs**: a character with Fishing 140 and a Fishing Rack (item 279965) to place, a campfire, a party member (who
can place the next Rack while the own camp cooldown of one hour runs), a mob for a fight, French and German as second
interface languages (step 11); for step 8 a second player on the new version and one on 1.4.0; for the size reading of
step 3 a character that never fished under a buff; for steps 9, 14 and 16 Fishing 300 and a Fishing Hut (item
279966).

**Already seen in game** on 2026-11-19 and not repeated here ([fishing-investigation.md](../fishing-investigation.md),
"Checked in game"): the Rack's aura 1280341 is granted in the second of the placing, also to a party member next to
the Rack, without sitting; it lasts one hour, outlives the Rack, a zone change and a relog, and drops on death; it
reads by ID out of combat and not in a fight, where the `UNIT_AURA` payload is secret; the cast, the bobber and the
loot source are the same under it; the bonus is a second loot slot next to the ordinary fish; an opened Rack hands out
5 Camper's Lure (291005, +60 for 5 minutes). The steps below check what the addon does with those facts.

**Rules for every step**: every camp feature shares a cooldown of one hour per character, and a death drops the buff,
so plan the buffs: a party member's Rack gives the buff to both of you. A `/okf debug` line to paste is written as
`____`. No `/run` line is needed.

## Setup

1. Install the build (`npm run install-addon`), or link the working folder once (`npm run link`). The TOC gained three
   files (`GameData\CampBonuses.lua`, `GameData\FishedQuestItems.lua`, `Fishing\Camp.lua`): **restart the game
   completely** (a `/reload` does not read a TOC change).
2. Log in on the character with Fishing 140 and the Rack; a key bound to "Fishing action"; water near a place where
   a campfire can be lit.
3. Before any buff: `/okf debug`, section `-- Camp bonus --`. Expected: `rack: aura 1280341, not active`,
   `hut: aura 1280342, not active`, `aura reads restricted: false`, `last cast mask: none`,
   `setting campBonusWarning: true` (FR-038, FR-032: on by default). Section "Catch database", after
   `current place ...`: `bonus parts here: none`. Pasted: ____
4. Options -> AddOns -> OneKeyFishing, the main page: the new checkbox "Warn when a camp bonus is ending" comes after
   "Remind me about the next Fishing rank"; the 16 checkboxes in two columns still fit the page, nothing overlaps
   or runs off its bottom (FR-032). [ ] Noted: ____

## Steps

### The buff and the recording

1. [ ] **Rack placed, casts recorded** (FR-002, FR-004, FR-005, FR-007, FR-038, SC-001, V64): light a campfire,
   place the Rack, enter fishing mode. `/okf debug`: `rack: aura 1280341, active, N s left` with N about 3600; compare
   N with the minutes on the buff's icon: ____ s against ____ min (V64: the same clock). Fish ten casts, misses
   included, and read `/okf debug` after every few: `last cast mask: 1`, and `bonus parts here: 1 = A catches / B
   misses` grows by one catch or one miss with every cast. Readings: ____ / ____ / ____. Start a fight with a mob and
   read `/okf debug` in it: `aura reads restricted: true` and the rack line still `active` (the kept state, FR-003).
   After the fight: `restricted: false` again, and the rack line still `active` at once, without a cast (V69: the
   read at the fight's end ran). Pasted: ____
   A party member on the new version who got the buff from the same Rack: their `/okf debug` shows `rack: ...
   active` too and their casts grow their own part of mask 1. [ ] Noted: ____

### The tag

2. [ ] **A Bloated fish's tag** (FR-016, FR-019, FR-020, FR-021, SC-002, V66): fish under the buff until a Bloated
   fish comes (about 40 minutes for one on 2026-11-19; Bloated Mithril Head Trout 8366 at Booty Bay), or use a place
   where one was caught. Then log out to the character screen and log in again (a fresh login, V66). Expected
   without hovering anything first: in "What can be caught here" the row of the Bloated fish shows the Fishing
   Rack's item icon at the right end of its name; the same icon in the catalog's list and in the item's zone and spot
   rows; the chance cell shows the chance among the casts under the Rack, or "Little data" below 50 catches under the
   Rack (FR-021). Icon seen after the fresh login: ____ (V66; a missing icon means the fallback of
   `GameData/Icons.lua` is needed).
   Hover the row: the lines "Fishing Rack bonus", "Bonus catch: comes only with the buff of a Fishing Rack (Uncommon
   Fishing).", and the chance "... with the bonus (N players)" where a chance is shown. An item tooltip elsewhere
   (the fish in the bags, a chat link) shows the explanation line under "Caught in:". Noted: ____
   **First hover after loading**: on the first hover of a tagged item the client was still loading after the login
   (as the price line sometimes is), are the bonus lines there at once, or only after the game rebuilds the tooltip
   (move away and back)? ____ (the same behaviour as the price line is accepted).

### The filter and the size

3. [ ] **The "Camp bonus" button** (FR-023 to FR-028, FR-042, V67): on a character that has not fished under a buff
   and holds no bonus data the button is missing in both tabs: row B starts with Kinds. On the buffed character,
   after the first recorded cast under the buff, it starts row B in both tabs (where the Water button was) and reads
   "Camp bonus: All". Its menu, in full words: "All catches", "No camp bonus", "Bonus catches only", "Fishing Rack"
   ("Fishing Hut" only with Hut data, step 9); its tooltip, titled "Camp bonus", says "No camp bonus" also holds
   older catches whose bonus is not known (FR-026).
   Choose "Fishing Rack": the button reads "Camp bonus: Rack", the list holds only the catches under the Rack, with
   their chances, misses and counts (FR-025); it combines with the Skill and Source buttons, the search and the
   catalog's sort (FR-028). Choose "No camp bonus": the button reads "Camp bonus: No bonus", the counts are the totals
   minus the Rack's part, and no row has the camp feature's icon (FR-053: a Bloated fish of older catches is left
   out of the list). "Bonus catches only" reads "Camp bonus: Bonus only" (step 10). Gain or lose the buff
   meanwhile: the choice stays (FR-027). `/reload`, then log out and in: every login starts at "Camp bonus: All".
   Button texts seen: ____
   **Size of the own record** (V67): after fishing under the buff at several places, `/okf debug`, section "Shared
   database": `own record offered: yes, N bytes encoded for M places` here: ____ (bytes per place ____), and on the
   character that never fished under a buff: ____ (bytes per place ____). Expected: a place with a part costs less
   than twice a place without; the number of places with a part: ____.

### The percentages

4. [ ] **Fractions, never "0%"** (FR-029, FR-030, SC-004): in "What can be caught here" and in the catalog (sort by
   chance), find a rare item: it reads with a fraction ("3.4%", "0.47%") or "<0.01%", never "0%"; chances from 10 %
   up are whole numbers ("37%"); no "10.0%" or "1.00%" anywhere; the sort by chance keeps items with the same text in
   their exact order. Examples seen: ____

### The notices

5. [ ] **Five minutes left and the end** (FR-031 to FR-033, SC-007, V64, V65, V63): fishing mode on, the setting on,
   with catch notifications off in the settings. With about six minutes of the buff left, keep fishing or wait.
   Expected: one toast "The Fishing Rack bonus ends in 5 minutes." when the buff's icon reads 5 minutes (time
   ____ against the icon ____, V64), and one "The Fishing Rack bonus has ended." when the buff leaves the bar, out of a
   fight (V65); none twice. `/okf debug` afterwards: `rack: aura 1280341, not active`. The cast the buff ended in
   (V63): did it bring a Bloated fish? ____ (that cast counts in the totals only).
   - [ ] **Death out of a fight** (FR-031): with a new buff in fishing mode, die without a fight (a fall, or
     drowning): the end notice comes. Noted: ____
   - [ ] **Death in a fight, "Leave fishing mode when attacked" off** (FR-033, V65): untick it, enter fishing mode
     with a buff, let a mob kill you: after the fight (on the first read after it) the end notice comes once.
     Noted: ____
   - [ ] **The same with "Leave fishing mode when attacked" on** (the default): the mode leaves with the fight, so no
     notice is expected. Noted: ____
   - [ ] **The setting off** (SC-007, if a buff is at hand): untick "Warn when a camp bonus is ending": no notice at
     five minutes and none at the end; outside fishing mode no notice either (FR-032). Noted: ____

### The statistics

6. [ ] **The statistics rows** (FR-034, FR-035): open the statistics window. On the buffed character, at the end of
   "Results", the rows "Casts with a camp bonus" and "Bonus catches" in all three columns (session, zone, total);
   "Casts with a camp bonus" counts the casts of step 1, "Bonus catches" the catches under the buff that held a
   Bloated fish or a second loot slot, fished quest items aside (0 before the first one; under the Hut: step 14).
   The window is a little taller and nothing overlaps its bottom buttons. On the character that never fished under a
   buff, both rows are missing. Values: ____

### The lure

7. [ ] **Camper's Lure** (FR-036, SC-010): take Camper's Lure from the placed Rack, as on 2026-11-19 (open it); with
   no lure on the pole and Camper's Lure and Nightcrawlers (or Aquadynamic Fish Lens) in the bags, the fishing key
   offers Camper's Lure; with Bright Baubles (+75) in the bags too, it offers Bright Baubles first. The lure lasts 5
   minutes, then the key offers the next one. Noted: ____

### The exchange

8. [ ] **Another player's record** (FR-010, FR-011, SC-005, SC-006): the second player on the new version receives the
   own record (`/okf share`: the record held). At a place where the own record has a part, their "What can be caught
   here" shows the "Camp bonus" button and the Bloated fish with the Rack's icon and the same chance with the bonus
   (or "Little data"). Noted: ____
   The player on 1.4.0: `/okf share` shows the record held, the place's totals are counted as from a record without
   a split, no Lua error, the sender not refused or ignored. Noted: ____
   **Optional, V61 and V68**: a few hundred casts without a buff at a water where a Bloated fish came with it (check
   H9 of [fishing-investigation.md](../fishing-investigation.md), with the loot listener): did a Bloated fish come
   without the buff? ____ Any second loot slot without the buff, and its item: ____ (casts: ____)

### The Fishing Hut

9. [ ] **Later, with Fishing 300** (FR-001, FR-006, FR-018, V60, V62): place a Fishing Hut. `/okf debug`:
   `hut: aura 1280342, active, N s left` (V60); fish: `last cast mask: 2` and `bonus parts here: 2 = ...` grows; the
   filter offers "Fishing Hut" and then reads "Camp bonus: Hut"; the notices name "the Fishing Hut bonus". Items only
   caught under the Hut by three players or more get the Hut's icon. Pasted: ____
   **Both buffs at once** (V62): with a Rack's buff, get a Hut's (or the reverse, a party member placing one of
   them): both lines `active`, `last cast mask: 3`, and `bonus parts here: 3 = ...` grows. Pasted: ____ (if the game
   lets only one buff stand, note which one stays: ____).

### After the first try in game (2026-11-20)

Steps 10 to 13 check the follow-up of decisions 21 to 31 of the spec; they need no Fishing 300, so do them with
step 3, on the buffed character at a place where a Bloated fish was caught (step 2).

10. [ ] **Bonus catches only** (FR-043 to FR-045): in "What can be caught here" note the counts line under "Camp
    bonus: All": ____. Choose "Bonus catches only": the list holds only the Bloated fish (and any item with the
    Hut's or the Rack's icon), no ordinary fish; the counts line is the same as under "All catches", and each row's
    chance is the one it had there. Move to a water where nothing tagged was caught (with the same choice): the tab
    says "No bonus catch has been recorded here yet." and lists nothing. In the catalog under "Bonus catches only":
    only the tagged items; open a Bloated fish: its page shows all its zones, as under "All catches". Noted: ____
11. [ ] **Two rows of buttons that fit** (FR-041, FR-042, research R8): in English, then in French and in German (the
    language setting, then `/reload`), with the Camp bonus button shown, look at both tabs and choose each value of
    the filter in turn. "What can be caught here": row A Skill and Source, row B the Camp bonus button and Kinds, the
    place's line over the full width (Kinds no longer at its right). The catalog: the search box, the status line,
    row A Skill and Source, row B the Camp bonus button, Kinds and Sort. Expected for every value ("Camp bonus: All",
    "No bonus", "Bonus only", "Rack"): the text is not cut, no button covers the next one, and row B ends inside
    the window (the longest: French "Bonus de camp : bonus seul" before Kinds and Sort). Language and result:
    English ____, French ____, German ____
12. [ ] **The list of "What can be caught here"** (FR-046, FR-047): under the place and the scope line, the hints
    (such as "Click an item to see where else it is caught.") and the exchange line come before the counts; the
    counts, the buttons and the column headers stay where they are when a hint comes or goes (a skill range with
    little data adds one). At a place with many items (or with "Skill: All skill levels"), the list scrolls with the
    mouse wheel and its scroll bar, down to the last item; there is no line "and N more". The "Per catch" column
    reads "1" for one piece per catch, never "1.0", and a fraction with one decimal otherwise ("1.3"; "1,3" in
    German). Noted: ____
13. [ ] **The catalog's status line** (FR-048): type a search that matches nothing: "No item matches the search."
    stands right under the search box, above the two rows of buttons (open the catalog at once after a `/reload`:
    "Counting the catch..." stands there too). On an item's page a status line, such as "No data for this item
    under these filters.", stands where the zones begin. Noted: ____

### After the Hut session (2026-11-20)

Steps 14 to 16 check decisions 32 to 34 of the spec. Steps 14 and 16 need the Fishing Hut (Fishing 300); step 15
needs any tagged item.

14. [ ] **Bonus catches under the Hut** (FR-034, FR-050): with the Hut's buff, the loot listener of
    [fishing-investigation.md](../fishing-investigation.md) ("The Fishing Hut: checks left") on, and the statistics
    window open, fish until a catch brings a second item (a herb, ore, a bar, a hide, dust or a Bloated fish). After
    that catch "Bonus catches" grew by one in all three columns; after a catch of one item it did not. Second slots
    seen and "Bonus catches" before and after: ____
15. [ ] **The colour of the tooltip lines** (FR-052): in the catalog choose "Camp bonus: Bonus only" and hover
    several tagged items one after another, back and forth, ten times or more; then an item in the bags and a fishing
    pole. "Caught in:", the tag's name ("Fishing Rack bonus" / "Fishing Hut bonus") and the fishing gear line stay
    cyan every time; an auction price with "(few lots)" stays grey; the minimap button's tooltip keeps its colours.
    Any white line, and what was hovered before it: ____
16. [ ] **A Bloated fish under the Hut** (FR-049, FR-051): at a water where a Bloated fish was caught only under the
    Hut (none under the Rack there), its row in "What can be caught here" shows the Fishing Hut's icon, with the
    chance among the Hut's catches (or "Little data"); its tooltip reads "Fishing Hut bonus" and "Bonus catch: comes
    only with the buff of a Fishing Rack or a Fishing Hut."; the same explanation under "Caught in:" in the fish's
    bag tooltip. Noted: ____

## Results

- Date, build, client language: ____
- Problems found: ____

What the checklist confirms goes into `docs/forever-api.md` and `docs/fishing-investigation.md`; each `V` it closes
is marked in [verification.md](../../specs/020-camp-buffs/verification.md) and its marker removed from the code.
What stays open is listed in [release-plan.md](../release-plan.md).
