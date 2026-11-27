# Checklist: the addon's own menus and the blocked actions

**Feature**: the addon's own menu (the minimap button and the Addon Compartment, the filters, the language, the
Import and export choice) and the blocked actions in `/okf debug`
([specs/029-blocked-actions](../../specs/029-blocked-actions/spec.md)).

**Closes**: SC-004 (a raid marker from a unit's menu in a fight works after the addon's menus), V81 (a second click on
a menu's owner closes it), V82 (the radio marks), and FR-007 in game.

**Needs**: one character, a mob to fight, the Auctionator addon disabled (for the scan entry in step 3). Already seen
in game and not repeated here: the recorded `SetRaidTarget` entry and the A/B test before the change (2026-11-26,
[docs/forever-api.md](../forever-api.md), "Verified in game").

## Setup

- [ ] `npm run install-addon` (or `npm run link` once), then `/reload` (no file was added to the TOC).
- [ ] Log in on the character, away from an auction house.

## Steps

1. **The raid marker after the addon's menus** (SC-004)
   - [ ] `/reload`. Open the minimap button's menu first (no game menu before it), close it, start a fight, then set a
     raid marker on the target from the target frame's menu (Target Marker Icon). The marker is set, there is no
     "Interface action failed because of an AddOn", and `/okf debug` lists no new blocked action.
   - [ ] The same after `/reload` with a filter menu of the statistics window first (the water filter or Kinds).
   - [ ] The same after `/reload` with the Import and export choice first (Options → AddOns → OneKeyFishing → Import and
     export).
2. **The diagnostic**
   - [ ] `/run DisplayInterfaceActionBlockedMessage()`, then `/okf debug`: "Errors and blocked actions" lists nothing
     new (a call from outside the addon is not its block).
3. **The minimap menu**
   - [ ] A right-click on the minimap button opens it below the button, or above it near the screen's bottom, with no
     title; every entry works.
   - [ ] **Scan auction prices** is grey away from an auction house; on hover it lights up only faintly, and a click
     does nothing and leaves the menu open.
   - [ ] A right-click on the Addon Compartment's entry opens the same menu.
4. **Open and close** (V81)
   - [ ] Right-click the minimap button (the menu opens), right-click it again: the menu closes; again: it opens.
   - [ ] The same with left clicks on a filter button of the statistics window.
   - [ ] A click elsewhere closes a menu; Escape closes it (with the window behind it, known).
   - [ ] Hide the statistics window with `/okf stats` while a filter menu is open: the menu closes too.
5. **The marks** (V82)
   - [ ] A filter menu with choices (the water filter: Everywhere, Open water, Pools; the Skill filter): the chosen
     one shows a ring with a dot, the others an empty ring; the texts start at the same place.
   - [ ] The Kinds menu: a shown kind is a box with a check, a hidden one an empty box; a click keeps the menu open
     and its mark changes.
   - [ ] The language choice and the Import and export choice mark the chosen entry and close on a click.

## Results

- Date: 2026-11-27, client language: enUS (the addon in Ukrainian), build: 1.60.1.71139
- Step 1 passed: after `/reload` and first the minimap menu, a filter menu or the Import and export choice, a raid
  marker in a fight was set; `/okf debug` listed no new entry (only the one of 2026-11-26, before the change).
  SC-004 confirmed.
- Step 2 passed: the game's line showed, nothing was recorded.
- Steps 3 and 4 passed: the menu below the button with no title, the grey scan entry lit faintly and stayed open on
  a click, the Addon Compartment, the toggle on the owner (V81 confirmed), a click elsewhere, Escape, the menu closing
  with the window.
- Step 5 passed in function (V82 confirmed: the right states, no other part of the texture), the checkbox kept the
  menu open, the language and Import and export choices worked. Problem found and fixed in the same session: a
  selected radio showed only a dot without its ring, a checked checkbox only a check without its box. The marks are
  now drawn in two layers, as the game's own radio and check buttons. Step 5 again after the fix passed: the camp
  bonus menu showed a ring with a dot on the chosen choice and empty rings on the others, the Kinds menu boxes with a
  check on the shown kinds and empty boxes on the hidden ones, every text starting at the same place.
