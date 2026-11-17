# In-game checklist: the catalog's sort order

**Feature**: the Sort button of the catch catalog: by name, by price, by chance, the right column, the remembered
choice, the three rows of buttons (`specs/017-catalog-sort`).
**Closes**: no `VERIFY` marker (the feature has none); the author's look at the new UI (research R6, R11 of the spec).
This checklist is the only check that no button covers another (FR-011, SC-006): the tests see the anchors, not the
drawn widths.
**Needs**: one character with Fishing and the bundled data; an auction scan (the auction house) for step 3; a second
character of the same account for step 6; French as the interface language for step 7 (the longest labels).

## Setup

1. Install the build (`npm run install-addon`), or link the working folder once (`npm run link`). No new file in the
   TOC: a `/reload` is enough after an update.
2. Log in; for step 3, scan the auction house once with the addon's scan button.

## Steps

1. [x] **The layout** (FR-011): open the statistics window, "Catch catalog". Expected: row 1 the search box alone;
   row 2 Skill, Source and (with pool data) Water; row 3 Sort, then Kinds; the list starts below row 3; no button
   covers another. ____
2. [x] **The default** (FR-001, FR-003, SC-005): the button reads "Sort: Name"; the list is alphabetical inside each
   kind header and each row ends with "Zones: N", as before 1.3.1. ____
3. [x] **By price** (FR-004, FR-008, SC-001): click Sort, choose Price (two clicks). Expected: the menu marks the
   chosen order; inside each kind the dearest item first; each row ends with its price per piece (the same value as
   the item's value in the statistics); items without a price come last with "No price" in grey; the list is shown
   from its top. Dearest fish: ____ ____
4. [x] **By chance** (FR-005): choose Chance. Expected: inside each kind the highest chance first, each row with a
   percentage; items with "Little data" last. Click an item: the chance of its first zone equals the chance in its
   row; Back. ____
5. [x] **The item page keeps its order** (spec edge case): with Sort: Price, open an item caught in several zones:
   its zones are still listed by chance. ____
6. [x] **Remembered** (FR-010, SC-004): choose Price, `/reload`: still "Sort: Price"; log in on another character of
   the same account: still "Sort: Price". Choose Name again. ____
7. [x] **French** (SC-006): set the addon's language to French in its settings, `/reload`, open the
   catalog with pool data shown (Water button visible). Expected: the three filter buttons fit row 2, Sort and Kinds
   fit row 3, nothing overlaps, the texts are French. Set the language back. ____
8. [ ] **While counting** (spec edge case): right after a login, before the catalog has finished counting ("Counting
   the catch..."), choose Price. Expected: once the list shows, it is ordered by price. Skipped: the catalog was
   ready before the author could open it (covered by the tests: the order applies to any list once it shows).
9. [x] **The other tab** (FR-011): "What can be caught here" is unchanged: its Kinds button stays at the top right.
   ____

## Results

- Date, build, client language: 2026-11-17, the 017-catalog-sort working tree (1.3.0 + spec 017), French checked in
  step 7.
- Problems found: none. Steps 1 to 7 and 9 passed; step 8 skipped (see above).

What happens next is in [release-plan.md](../release-plan.md).
