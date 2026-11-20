# In-game checklist: the cumulative skill filter

**Feature**: the Skill filter of "What can be caught here" and of the catch catalog sums the catches of the chosen
skill range and of every lower one; the miss rate comes from the chosen range alone; the labels "Up to N" and "All
(300+)" with the own range marked "(yours)"; the button's tooltip (`specs/021-cumulative-skill-filter`).
**Closes**: no `VERIFY` marker (the feature has none: the sums, the miss rate and the menu are covered by the tests).
This checklist is the only check that the new texts fit the 150 px button and the menu in every language (FR-017,
SC-005): the tests see the texts, not their drawn width.
**Needs**: one character with Fishing between 75 and 299 and the bundled data; a place where catches exist only with
less skill than the character's (any low-level zone for a character of 150 or more); an instance or a cave for step
3; a character without Fishing for step 4; the addon's interface language switched through all ten languages for
steps 6 and 7.

## Setup

1. Install the build (`npm run install-addon`), or link the working folder once (`npm run link`). No new file in the
   TOC: a `/reload` is enough after an update.
2. Log in on the character with Fishing.

## Steps

1. [ ] **A place with only lower-skill data** (US1, SC-001): stand at the place, open the statistics window, "What
   can be caught here". Expected: the button reads "Skill: Up to N" for the character's range (for example "Skill:
   Up to 224" at 180); the list is not empty and shows what was caught there with less skill. Place and button:
   ____
2. [ ] **The menu** (FR-009, FR-010): click Skill. Expected: five values, "Up to 74", "Up to 149", "Up to 224", "Up
   to 299", "All (300+)", the character's range with "(yours)" and checked. Choose "All (300+)": the button reads
   "Skill: All". `/reload`: back to the own range. ____
3. [ ] **"(yours)" without a map** (FR-010): in an instance or a cave where the tab says the game does not show the
   place, open the catalog's Skill menu. Expected: the own range still carries "(yours)". ____
4. [ ] **No Fishing** (FR-010): on a character without Fishing, open the catalog's Skill menu. Expected: no value
   carries "(yours)". ____
5. [ ] **The miss rate** (US2, FR-005, FR-006): on the character with Fishing, at a place you fished a lot with your
   current range, the counts line ends with "Nothing caught: N%". Choose a range you never fished at this place:
   "Nothing caught: little data", while the list still shows items. Hover the Skill button: two lines, "Catches with
   skill up to N." and "Misses only with skill A-B." ____
6. [ ] **German and French** (FR-017): set the addon's language to German, `/reload`, open both tabs at "Skill: Up
   to 224" (pick it by hand if needed) and open its menu; then French. Expected: the button's text is not cut, the
   menu's "(yours)" line fits, the tooltip wraps cleanly. ____
7. [ ] **The other seven languages** (FR-017, SC-005): Spanish (Spain and Mexico), Portuguese, Ukrainian, Korean,
   Simplified and Traditional Chinese, one after another, as in step 6. Expected: "Skill: Up to 224" on the button
   and "Up to 224 (yours)" in the menu fit without being cut. A language where a text is cut: ____. Set the
   language back.
8. [ ] **The catalog** (US4, FR-013): open "Catch catalog". Expected: the button reads "Skill: All"; choose "Up to
   149": the list loses the items only caught with more skill; open an item: its zones count the catches up to 149;
   its Skill column still shows where it was caught ("75-224", "300+"). Choose "All (300+)" again. ____
9. [ ] **The minimap button** (FR-002): turn fishing mode on at the place of step 1 and hover the minimap button.
   Expected: the likely catches list what was caught there with less skill, not "Nothing has been caught here yet."
   ____

## Results

- Date, build, client language: ____
- Problems found: ____

What happens next is in [release-plan.md](../release-plan.md).
