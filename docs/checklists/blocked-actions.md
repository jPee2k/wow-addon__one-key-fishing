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
     one shows a filled radio, the others an empty one.
   - [ ] The Kinds menu: a checkbox click keeps the menu open and its mark changes.
   - [ ] The language choice and the Import and export choice mark the chosen entry and close on a click.

## Results

- Date: ____, client language: ____, build: ____
- Problems found: ____
