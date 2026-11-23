# In-game checklist: the item kinds Trophies and Quest, the trophy collection

**Feature**: two new kinds in the catch lists (Trophies: the 36 weighed "N Pound" fish; Quest: the quest items), the
order Fish, Containers, Trophies, Potions & drinks, Reagents & herbs, Quest, Other; the trophy collection in the
catalog (the count on the Trophies header, the check mark on a caught trophy); the notice and the rare sound for a
trophy new to the account (`specs/023-item-kinds`).
**Closes**: no `VERIFY` marker (the kinds come from the game's item tables; the lists, the count, the first catch, the
notice and the sound are covered by the tests). This checklist is the look in game: the check mark's atlas, the
texts' width.
**Needs**: one character with Fishing and the bundled data; a water where a weighed fish can bite (any starting zone:
the 10-15 Pound Mud Snapper); "Play fishing sounds" on for step 5.

## Setup

1. Install the build (`npm run install-addon`), or link the working folder once (`npm run link`). No new file in the
   TOC: a `/reload` is enough after an update.
2. Log in on the character with Fishing.

## Steps

### The kinds

1. [x] `/okf catalog`, then **Kinds**: seven checkboxes in the order Fish, Containers, Trophies, Potions & drinks,
   Reagents & herbs, Quest, Other, all ticked; the button reads "Kinds: All" (FR-001).
2. [x] The list shows weighed fish ("17 Pound Catfish" and the like) under **Trophies** and Speckled Tastyfish or
   Nat Pagle's fish under **Quest**, none of them under **Fish** (FR-002, FR-003).
3. [x] Untick Trophies: the button reads "Kinds: 6 of 7", the weighed fish leave both tabs; tick it again.

### The collection

4. [x] The **Trophies** header reads "Trophies (n/36)"; every trophy your account has caught shows a small check mark
   at the bottom right corner of its icon, the others none; the mark does not cover the name (FR-006). n = 6
   (2026-11-23).

### A new trophy

Steps 5 to 7: accepted without a check on 2026-11-23 (no new trophy bit yet; the tests cover the notice, the sound
and the count). Tick them when a weighed fish new to the account bites.

5. [ ] Fish until a weighed fish your account has never caught bites: a gold notice "New trophy: [...] (n+1/36)"
   rises above the indicator, the catch line does not name it again, and the rare loot sound plays (FR-008). Turn
   "Show catch notifications" off and it still shows.
6. [ ] Catch the same weighed fish again: only the ordinary catch line, no gold notice, no rare sound (FR-009).
7. [ ] Open the catalog again: the count went up by one and the new trophy has its mark.

## Results

- Date: 2026-11-23 Client language: ukUA Build: 1.5.1 + spec 023 (branch `023-item-kinds`)
- Problems found: none. Steps 5-7 accepted, open until a new trophy bites.
