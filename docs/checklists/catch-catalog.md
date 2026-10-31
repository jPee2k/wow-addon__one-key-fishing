# In-game checklist: the catch catalog (part 4)

What to check in the game for the catch catalog, the map pin, the subzones and the catch chances in tooltips
(`specs/005-catch-catalog`), on and after the game launch on 2026-11-04. The feature was built before the game could
be played, on the assumptions V30-V40 of `specs/005-catch-catalog/verification.md`; each step below says which ones
it closes. Tick each box, note anything that looks wrong, and paste the `/okf spike` reports back: the answers go into
`docs/forever-api.md`, and the `VERIFY` markers in the code are removed only after that.

**Clients**: one in English and one in another language with letter case and accents (deDE or frFR; ruRU for
Cyrillic) for steps 1 and 6. Step 1 also wants a fresh client folder (an empty item cache).

## Setup

1. Install the build into the game (or link the working folder once with `npm run link`):

   ```bash
   npm run install-addon
   ```

2. Restart the game completely. New files were added to the TOC (`Catalog.lua`, `UI/CatalogTab.lua`), so `/reload`
   is not enough.
3. Run `/okf spike` and copy the section "Map pins and areas (V30-V36)" at three waters: an open zone, a named
   subzone (a lake with its own name), and a city. Once more inside a cave (a map of type 5, Micro). Run the report
   twice at the first place: the items part shows the names before and after the game was asked for them.

## The catalog

1. [ ] **The list (V35, V36, V37).** On the fresh client folder, open the statistics window (`/okf stats`), tab
   "Catch catalog". Expected: "Counting the catch..." for at most a moment, then the items of the bundled data,
   sorted by name, each with its icon and "Zones: N"; the list scrolls with the mouse wheel and the scroll bar. No
   grey item without a search. Type part of a name in lower case (on deDE or frFR also without its accent, e.g.
   "forelle" or "truite"): the list narrows with every letter; clearing the box brings the full list back. Items
   that had no name at first appear within a few seconds, without reopening the window.
2. [ ] **An item (FR-007, FR-008).** Click an item. Expected: its zones, the highest chance first, zones with fewer
   than 50 catches last with "Little data"; the skill span and the zone's catches; hovering a zone says how many
   players the numbers come from. Click "+": its spots appear indented, each named "Subzone (45, 72)" or "45, 72",
   and "-" folds them. "Back" returns to the list with the search kept.
3. [ ] **The pin (V30, V31, V32, SC-002).** On a spot in the open world, press the pin button. Expected: the game's
   map pin on the world map and the minimap at that place, the navigation arrow on screen pointing to it, the toast
   "Map pin: <zone> - <spot>", and the world map opens at that zone. Count the actions from typing the name to the
   pin: at most five (type, click the item, "+", the pin button). In combat, press another pin button: the pin and
   the toast come, the map stays closed. Note whether the arrow shows; if not, note the CVar line of the spike.
4. [ ] **The player's own pin (FR-012).** Set a pin by hand on the world map, then press a pin button in the
   catalog. Expected: "Replace your map pin with this place?". "Cancel": your pin stays. Press again and "Replace":
   the catalog's pin. Press another pin button: no question (the addon's own pin is replaced).
5. [ ] **Caves and instances (V33).** Expand a zone with a spot inside a cave (a zone name "Zone - Cave"): its pin
   lands on the zone map where the cave is, or the spot has no pin button. A spot in an instance has no pin button.
6. [ ] **Another client language (V34, SC-005).** On the second client, after fishing a few casts at a named
   subzone on the first: the same zones, chances and catches; zone and subzone names in the second client's
   language. A spot fished only by the other client is named too.
7. [ ] **Tooltips (V38, FR-017, FR-018, FR-019).** Hover a fish in the bags, at the auction house and in a chat
   link: "Caught in:" with up to three zones and the chance, "(N players)" from 2 on. An item outside the database
   (a sword): no line. Enter fishing mode and hover the minimap button and the addon's compartment entry: "Likely
   catch here:" with three items and the catches line; outside fishing mode: no such lines. Turn off **Show catch
   chances in tooltips**: both are gone.
8. [ ] **Smooth (V39, SC-003).** After an hour of fishing with the exchange on, open the catalog, type a letter,
   choose an item, expand its largest zone, and move the mouse quickly over full bags. Expected: no stutter. Then
   `/okf debug`, section "Catch catalog": the longest step under 5 ms.
9. [ ] **Pools (V3 of part 1).** Only when the spike of part 1 showed that pool catches are told apart: both tabs
   show "Water: Everywhere"; the catches under "Open water" and "Pools" add up to those under "Everywhere", and the
   line "Nothing caught" is gone under the two. Without pool data the button does not show.
10. [ ] **The ways in (FR-024, FR-025).** On "What can be caught here" click a known item: the catalog on that item.
    `/okf catalog trout` fills the search; `/okf catalog` with a shift-clicked item link opens that item.

## The whole (V40)

- [ ] Every step above passes on both client languages. Note the results and the spike reports for
  `docs/forever-api.md`, then the markers V30-V40 can go.
