# In-game checklist: the catch catalog

**Feature**: the catch catalog tab, the map pin, the subzones of casts and the catch chances in tooltips
(`specs/005-catch-catalog`, part 4 of the shared catch database).
**Closes**: V38, V39, V40 of `specs/005-catch-catalog/verification.md`, and the feature side of V30-V37 (their API
side is closed by [spike.md](spike.md), which runs first).
**Needs**: one client in English and one in another language with letter case and accents (deDE or frFR; ruRU for
Cyrillic) for steps 1 and 6; a fresh client folder (an empty item cache) for step 1; an hour of fishing with the
exchange on for step 8.

## Setup

1. Install the build (`npm run install-addon`), or link the working folder once (`npm run link`); restart the game
   completely (new files in the TOC).
2. Log in on a character that has learned Fishing.

## Steps

1. [ ] **The list** (V35, V36, V37): on the fresh client folder, open the statistics window (`/okf stats`), tab
   "Catch catalog". Expected: "Counting the catch..." for at most a moment, then the items of the bundled data,
   sorted by name, each with its icon and "Zones: N"; the list scrolls with the mouse wheel and the scroll bar. No
   grey item without a search. Type part of a name in lower case (on deDE or frFR also without its accent, e.g.
   "forelle" or "truite"): the list narrows with every letter; clearing the box brings the full list back. Items
   that had no name at first appear within a few seconds, without reopening the window.
   Partly 2026-11-07 (enUS, the old item cache, a test seed from the Statistics tab): "Counting the catch..." for
   about a second, the items sorted with icons and "Zones: N", no grey rows, the search narrows ("raw") and clearing
   brings the list back, no error. Open: a fresh item cache, a list long enough to scroll, deDE / frFR.
2. [x] **An item** (FR-007, FR-008): click an item. Expected: its zones, the highest chance first, zones with fewer
   than 50 catches last with "Little data"; the skill span and the zone's catches; hovering a zone says how many
   players the numbers come from. Click "+": its spots appear indented, each named "Subzone (45, 72)" or "45, 72",
   and "-" folds them. "Back" returns to the list with the search kept.
   In game 2026-11-07 (test seed): as expected; "181 catches from 2 players" on a zone; spots by coordinates only
   ("46, 58" at Stonebull Lake: V34 in `docs/tech-debt.md`); the seed's whole-map cells show as "No exact spot".
3. [x] **The pin** (V30, R14, SC-002; since spec 008 the same pin as the next rank's, `Core/MapPin.lua`): on a
   spot in the open world, press the pin button. Expected: the game's map pin on the world map and the minimap at
   that place, the navigation arrow on screen pointing to it, the toast "Map pin: <zone> - <spot>", and the world
   map opens at that zone. Count the actions from typing the name to the pin: at most five (type, click the item,
   "+", the pin button). In combat, press another pin button: the pin and the toast come, the map stays closed. Turn off
   "Show catch notifications" in the settings and press a pin button: the toast still comes. Note whether the arrow
   shows; if not, note the CVar line of the spike.
   Partly 2026-11-07: 4 actions to the pin; the pin on the world map and the minimap (edge arrow), the map opens at
   the zone, no error; no arrow on screen (`showInGameNavigation` 0, V31). Combat: the map taint of R14
   (`specs/001-interface-language/verification.md`, checked 2026-11-06). The toast shows above the indicator, also
   with catch notifications off, but the world map the pin opens covers it. Since spec 009 the pin no longer opens
   the map; checked through the next-rank pin (`interface-language.md` section 10), the same `MapPin.Set`.
4. [x] **The player's own pin** (FR-012): set a pin by hand on the world map, then press a pin button in the
   catalog. Expected: "Replace your map pin with this place?". "Cancel": your pin stays. Press again and "Replace":
   the catalog's pin. Press another pin button: no question (the addon's own pin is replaced). Press the pin
   button of the place the pin already marks: no question either. In game 2026-11-07: as expected.
5. [ ] **Caves and instances** (V33): expand a zone with a spot inside a cave (a zone name "Zone - Cave"): its pin
   lands on the zone map where the cave is (carried through the world position, `MapPin.Target`), or the spot has
   no pin button. A spot in an instance has no pin button. Partly 2026-11-07: the cave before Wailing Caverns has
   no map of its own, so its spot "52, 55" sits under the zone "Kalimdor" (the continent) with a pin button there
   (`docs/tech-debt.md`, caves); inside the instance no place is written, so no spot. Since spec 011 a cast there
   is recorded on the zone under the point: after a few new casts in that cave the spot shows under "The Barrens",
   in the cave's point, with its pin on The Barrens; no "Kalimdor" zone for new casts.
6. [ ] **Another client language** (V34, SC-005): on the second client, after fishing a few casts at a named subzone
   on the first: the same zones, chances and catches; zone and subzone names in the second client's language. A
   spot fished only by the other client is named too. Since spec 011 the subzone is found by its name among the
   game's areas: a few casts at Stonebull Lake and at Ratchet give the spots "Stonebull Lake (x, y)" and
   "Ratchet (x, y)"; at the Thunder Bluff pond (no subzone text) coordinates only.
7. [x] **Tooltips** (V38, FR-017, FR-018, FR-019): hover a fish in the bags, at the auction house and in a chat
   link: "Caught in:" with up to three zones and the chance, "(N players)" from 2 on. An item outside the database
   (a sword): no line. Enter fishing mode and hover the minimap button and the addon's compartment entry: "Likely
   catch here:" with three items and the catches line; outside fishing mode: no such lines. Turn off **Show catch
   chances in tooltips**: both are gone.
   In game 2026-11-07: as expected (the bag tooltip seen 2026-11-06).
8. [ ] **Smooth** (V39, SC-003): after an hour of fishing with the exchange on, open the catalog, type a letter,
   choose an item, expand its largest zone, and move the mouse quickly over full bags. Expected: no stutter. Then
   `/okf debug`, section "Catch catalog": the longest step under 5 ms. Value: ____
9. [x] **Pools** (V3 of part 1): only when the spike showed that pool catches are told apart: both tabs show
   "Water: Everywhere"; the catches under "Open water" and "Pools" add up to those under "Everywhere", and the line
   "Nothing caught" is gone under the two. Without pool data the button does not show. In game 2026-11-07: V3
   failed (no pool data), and neither tab shows the button; pool catches count as open water. Spec 011 keeps it so:
   no catch is split by water, and the button stays hidden.
10. [ ] **The ways in** (FR-024, FR-025): on "What can be caught here" click a known item: the catalog on that item.
    `/okf catalog trout` fills the search; `/okf catalog` with a shift-clicked item link opens that item. Right after
    a login, while the catalog still says "Counting the catch...", click a known item on "What can be caught here":
    the catalog opens on that item once the counting ends. Partly 2026-11-07: the click on "What can be caught here",
    `/okf catalog raw` and `/okf catalog` with a shift-clicked link (the chat box open) work; the click during
    "Counting the catch..." could not be timed by hand (about a second), so it stays open.
11. [ ] **The whole** (V40): every step above passes on both client languages.

## Results

- Date, build, client languages: 2026-11-07, game 1.60.1 (70790), enUS only, `002-shared-db` linked, a test seed
  made from the Statistics tab (not committed).
- Problems found: the map pin's map and toast (fixed by spec 009, confirmed 2026-11-07); spots without subzone
  names and a cave under the continent (fixed by spec 011, waiting for the in-game check); no arrow on screen (the
  V31 fallback: the arrow depends on the game's navigation setting). Open: steps 1 (fresh cache, scrolling), 5, 6, 8, 10 (the click
  while counting), 11 (a second client language).

What happens next is in [release-plan.md](../release-plan.md).
