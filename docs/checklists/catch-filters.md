# In-game checklist: the catch filters by item kind

**Feature**: the item kinds of "What can be caught here" and the catch catalog: the kind headers, the Kinds menu,
the remembered choice (`specs/014-catch-filters`).
**Closes**: no `VERIFY` marker (the feature has none); the author's look at the new UI (research R6, R11 of the spec):
the menu that stays open, the headers in both lists, the four filter buttons, SC-003.
**Needs**: one character with Fishing and the bundled data, water with several kinds of catch (fish and a chest or a
clam, as in the bundled data of The Barrens or Durotar); a second interface language with long words (`deDE`, `frFR`
or `ukUA`) for step 7.

## Setup

1. Install the build (`npm run install-addon`), or link the working folder once (`npm run link`); restart the game
   completely (a new file in the TOC: `GameData/ItemKinds.lua`).
2. Log in and go to a water whose "What can be caught here" lists more than one kind.

## Steps

1. [ ] **The headers** (FR-006, SC-002): open the statistics window, "What can be caught here". Expected: the items
   under gold headers in this order: Fish, Containers, Potions & drinks, Reagents & herbs, Other (a header only for a
   kind with items); hovering or clicking a header does nothing; an item row still shows its tooltip and opens the
   catalog. ____
2. [ ] **The buttons** (FR-007, FR-009): the filter row reads Skill, Source, and Water (only with pool data) as
   before; the Kinds button sits at the top right beside the place's name (in the catalog, since 1.3.1, in the third
   row after Sort: [catalog-sort.md](catalog-sort.md)), overlaps nothing and reads "Kinds: all". ____
3. [ ] **The menu stays open** (FR-007, research R6, SC-003): click Kinds and untick Containers, Potions & drinks,
   Reagents & herbs and Other one after another. Expected: the menu stays open between the clicks, the list follows
   each click at once, the button ends at "Kinds: 1 of 5", and only fish are listed; the chance and price of each
   fish are the same as before. Clicks used, the menu's included: ____ (at most five). ____
4. [ ] **Both tabs** (FR-007): open the "Catch catalog" tab. Expected: the list shows only the Fish header and fish, its
   Kinds button reads "Kinds: 1 of 5"; the scroll list scrolls with the header rows the same height as the items.
   Tick Containers back from the catalog's own button: containers come back in both tabs. ____
5. [ ] **Remembered** (FR-008, SC-003): with some kinds hidden, `/reload`; then log out and back in. Expected: the same
   kinds hidden both times, in both tabs. ____
6. [ ] **A hidden item on request** (FR-012): hide Containers. Shift-click a chest or a clam into chat and click the
   link, or type `/okf catalog` with that link. Expected: the catalog opens that item's zones and spots; Back shows the
   list without containers. Type the container's name into the catalog search: nothing is listed and the status reads
   "The kind filter hides the matches." ____
7. [ ] **Everything hidden** (FR-011): untick every kind. Expected: "The kind filter hides every item." in "What can be
   caught here" and in the catalog, not "Nothing has been caught here yet."; tick them all back. ____
8. [ ] **Another language** (FR-013, SC-005): switch the interface language (the language setting, then reload).
   Expected: the headers, the menu entries, the Kinds button and the two filter texts are translated; the four filter
   buttons still fit the window (a button may grow to its text: note any overlap). ____

## Results

- Date, build, client language: ____
- Problems found: ____

What happens next is in [release-plan.md](../release-plan.md).
