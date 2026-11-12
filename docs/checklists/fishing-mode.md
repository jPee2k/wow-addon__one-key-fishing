# In-game checklist: fishing mode and the core features

**Feature**: everything released in 1.0.0: fishing mode, the one key, gear, lures and containers, the indicator,
statistics, auction prices, the rank cap warning, the minimap button and the settings. No spec (built before Spec
Kit); the behaviour is described in `OneKeyFishing/README.md` and `docs/architecture/`.
**Closes**: nothing marked `VERIFY`; this is the regression run before every release.
**Needs**: one character with the Fishing skill, a fishing pole, a lure and an empty bag slot; a place with
water where mobs can attack (for the combat steps); the auction house for the price steps.

## Setup

1. Install the build (`npm run install-addon`), or link the working folder once (`npm run link`).
2. Restart the game completely when a file was added to the TOC; otherwise `/reload` is enough.
3. Bind both keys: Options -> Keybindings -> AddOns -> OneKeyFishing.

## 0. The folder layout (once, after the files moved into one folder per area)

- [x] **Clean install.** Delete `Interface/AddOns/OneKeyFishing` and install the build (or link), then restart the
  game completely (the TOC changed). Expected: the addon is in the AddOn list, no error on login, `/okf` lists the
  commands, both keys are still bound (`Bindings.xml` stayed at the root). In game 2026-11-06 (`002-shared-db`,
  linked, version `dev`): in the list, no error, `/okf` lists the eight commands, both keys of each action bound.
- [x] **Reports.** `/okf debug` and `/okf spike` open the copy window with the report (now built by `Core/Debug.lua`
  and shown by `Core/Commands.lua`). In game 2026-11-06: both open it.
- [ ] **The views that moved.** Open the auction house: the "Scan fish prices" button is there and counts while
  scanning (`UI/AuctionButton.lua`). Enter fishing mode at a capped rank: the warning shows as a toast too
  (`SKILL_WARNING`). On a fresh account the one-time popup about the exchange shows and its Settings button opens
  the "Shared database" page (`UI/ShareNotice.lua`). Partly 2026-11-06: the scan button is there and counts. Open: the toast at
  a capped rank, the popup on a fresh account.
- [x] **Update over an old install.** Copy the build over the 1.0.0 folder without deleting it. Expected: the old
  root `*.lua` files stay but are not loaded (the TOC no longer lists them); everything above still works. Skipped 2026-11-06: the build is linked; run it with
  `npm run install-addon` before the release. 2026-11-11: release 1.1.0 from its tag in AddOns, the build
  `1.1.0-dev+fdda5a0` copied over it (the old root files `Core.lua`, `Data.lua`, `Skill.lua` and the rest stayed);
  after a game restart no error, `/okf` lists the commands, the mode turns on and off, `/okf stats` opens, `/okf
  debug` shows the new version and no new error: as expected.

## 1. Fishing mode

- [x] **On.** (re-run after spec 008) Press the toggle key at the water. Expected: the pole is equipped, the camera
  zooms to the set distance, the indicator appears with `Cast`, the minimap button lights up, the chat says the mode is
  on.
- [x] **Off.** (re-run after spec 008) Press it again. Expected: the previous weapons and gear are back, the camera zoom
  is back, auto loot and the soft-target CVars are back to their previous values (check Options -> Gameplay -> Controls,
  Interact Key and Auto Loot, before and after), the indicator is gone.
- [x] **`/reload` in the mode.** (re-run after spec 008) Turn the mode on, `/reload`. Expected: the mode is still on,
  the gear and the camera as they were in the mode.
- [x] **Relog in the mode.** (re-run after spec 008) Turn the mode on, log out to the character screen, log in.
  Expected: the mode is off, the gear and the CVars are restored; the camera stays as the game left it.
  The four steps above: 2026-11-11 (game 70888, after specs 009-011, level 23): as expected, no error.
- [x] **Out of combat only.** (re-run after spec 009) Only what spec 009 changed; confirmed 2026-11-06 and not
  repeated: with the setting on, the weapons come back at once on an attack and the rest of the gear and the mode
  off follow after the fight; with the setting off, fishing goes on after the fight. Three sub-steps, in this order:
  1. The setting "Leave fishing mode when attacked" off, the mode on, a fight. Run
     `/run print(GetBindingAction("<key>", true))` with your fishing key (for example `` ` ``): it prints
     `ONEKEYFISHING_ACTION` (V45). The fishing key gives "The fishing key is paused in combat.", not the game's
     "can't do that in combat"; the indicator shows "Paused in combat" and, after the fight, "Cast" again: as
     expected (2026-11-07, `ONEKEYFISHING_ACTION`, the indicator label in Ukrainian)
  2. The setting on, the mode on, let a mob attack: "Leaving fishing mode after combat." exactly once: as
     expected (2026-11-07)
  3. The setting off, `/console taintLog 1`, the mode on, the toggle key in a fight: that line once and no
     "Interface action failed"; `Logs/taint.log` has no `EquipItemByName`. After the fight the mode is off and the
     gear is back: as expected (2026-11-07)

  History, in game 2026-11-06 (release 1.1.0), three findings, fixed by spec 009:
  - attacked with the setting on: the weapons at once, the rest and the mode off after the fight, as expected; but
    no chat line at all (the addon prints none on an attack, only when a key is pressed);
  - with the setting off, the fishing key pressed in a fight: the game's "can't do that in combat", no line from
    the addon, so the key still clicks the cast button (the overrides were not dropped); after the fight fishing
    goes on, as expected;
  - the toggle key pressed in a fight: "Interface action failed because of an AddOn" (`taint.log`: `EquipItemByName()`
    blocked, from `Gear.RestoreWeapons`), the chat line "Leaving fishing mode after combat."; after the fight the
    mode is off and the gear is back.

## 2. The key

- [x] **Cast.** In the mode press the action key. Expected: Fishing is cast, the indicator shows the cast bar and
  `Hook!` once the bobber is out.
- [x] **Hook and loot.** After the splash press the same key. Expected: the bobber is hooked and the loot is taken
  (auto loot on); a catch notification shows above the indicator.
- [x] **Miss.** Let a cast run out without hooking. Expected: a "nothing caught" notification about a second later;
  the statistics count a miss.
- [x] **No bobber.** Cast, then turn the camera away from the bobber. Expected: the indicator shows "No bobber"
  after about 3 seconds; turning back clears it.
- [x] **Outside the mode.** Turn the mode off and press the action key. Expected: a chat line that the mode is off,
  nothing else happens.
- [x] **Unbound.** Unbind the action key and turn the mode on. Expected: a chat line that no key is bound.

## 3. Gear

- [x] **Gear page, first view (spec 007).** (re-run after spec 008) `/reload`, open Options -> AddOns -> OneKeyFishing
  -> Fishing gear first thing and hover the whole list area. Expected: only your items (or "No items yet."), no Remove
  button without an item, no Lua error. Close the panel, Alt+Click an item in the bags, open the page again: its row is
  there.

- [ ] **Best pole.** With two poles in the bags and no chosen pole, enter the mode. Expected: the pole with the
  higher fishing bonus (then the higher item level) is equipped.
- [x] **Chosen pole and extra items.** (re-run after spec 008) Alt+Click a pole and a hat in the bags. Expected: the
  settings page "Fishing gear" lists them; entering the mode equips both; leaving puts back the previous weapons and
  helmet. With no previous helmet, the hat goes back to the bags.
- [x] **Remove.** (re-run after spec 008) Alt+Click the hat again. Expected: it leaves the list; the next mode entry
  does not equip it.
- [ ] **Find fishing items.** (re-run after spec 008) Press the button on the gear page with a fishing-bonus item in the
  bags. Expected: the item is added; pressing again adds nothing new.
- [x] **Leaving during a cast.** (re-run after spec 008) Cast, then press the toggle key while the bobber is out.
  Expected: the mode ends and the gear is restored once the cast ends.
  2026-11-11 (game 70888, after specs 009-011): first view, chosen items, remove and leaving during a cast as
  expected, no error. Open: "Find fishing items" (no fishing-bonus item in the bags yet), the best of two poles, full bags.
- [ ] **Full bags.** (re-run after spec 008) Fill the bags and leave the mode. Expected: a chat line that there is no
  free bag space to take off the gear; freeing a slot and leaving again restores it.

## 4. Lures and containers

- [x] **Lure.** (re-run after spec 008) With a lure in the bags and none on the pole, press the action key. Expected:
  the indicator shows `Apply lure`, the key applies it (a 5 second cast), the next press casts.
  2026-11-11 (game 70888, after specs 009-011, skill 154): as expected, no error.
- [ ] **Lure on cooldown.** Right after a lure was applied and removed (or with a second lure type), check the
  indicator. Expected: a lure on cooldown is skipped; the next one is offered, or a cast. In game 2026-11-06
  (release 1.1.0): Nightcrawlers (6530) and Shiny Bauble (6529) have no item cooldown (`cooldown: 0 s` for both
  right after a 6530 was applied), so they are never skipped; the other lures are not checked yet. While a lure
  is on the pole no new one is offered, as expected.
- [ ] **Lure too high.** (re-run after spec 008) With only a lure above your skill, press the key. Expected (spec 008):
  a lure above your Fishing skill is never offered: the indicator and the key pass it over, no "Cannot apply ..."
  message. Once your skill reaches the lure's requirement (Nightcrawlers and Aquadynamic Fish Lens 50, Bright Baubles,
  Flesh Eating Worm and Aquadynamic Fish Attractor 100), the key offers it. Report a lure the game still refuses, with
  your skill (V43, V44). 2026-11-11: the six requirements match the items' tooltips in game (V43 closed); the
  behaviour below a threshold waits for a character under 100 with such a lure (V44).
- [ ] **Clam.** (re-run after spec 008) Catch or carry a clam. Expected: the indicator shows `Open`, the key opens it,
  the loot is taken. In game 2026-11-06 (release 1.1.0): a fished chest opened this way.
- [ ] **Unknown container** (V27). If you fish up a container the game showed nothing about before (a new Forever item).
  Expected: the key opens it like a clam, and the auction scan includes it.
- [ ] **Locked container.** With a locked box in the bags. Expected: "Cannot open ..." once, then it is skipped.
- [ ] **No bag space.** With full bags and a clam. Expected: "Not enough bag space to loot ..."; after freeing a slot
  the key opens it again.

## 5. Indicator and notifications

- [x] **Drag.** With "Lock the indicator position" off, drag the indicator. Expected: it moves; `/reload` keeps the
  place; "Reset indicator position" puts it back to the centre.
- [x] **Locked.** Turn the lock on. Expected: the indicator cannot be dragged.
- [x] **Session timer.** Turn "Show session fishing time under the indicator" on. Expected: the time counts while
  the mode is on, stops while off, pauses while AFK (with "Pause the fishing timer while AFK" on).
- [x] **Notifications off.** Turn "Show catch notifications" off and catch a fish. Expected: no notification.
- [ ] **In a dungeon** (spec 012, tech-debt batch 10 of 2026-11-11). Fish ten casts at water inside a dungeon.
  Expected: no error window (before the fix: "attempt to perform string conversion on a secret string value"); the
  indicator shows "Hook!" while the bobber is out, never "No bobber"; the catches are looted; `/okf debug` Errors has
  no new entry. Then in the open world, a cast while facing away from the bobber still shows "No bobber" after 3 s.

## 6. Statistics

- [x] **Counts.** `/okf stats` (or Shift+Click on the minimap button). Fish 5 casts. Expected: casts, catches and
  misses add up to 5 in the Session column; This zone and All time grow by the same numbers.
- [x] **Time.** Expected: "Time fishing" counts while the mode is on, "Time casting" only while the bobber is out.
- [x] **Survives `/reload` and relog.** Expected: Session is kept across `/reload`, All time across a relog; a cast
  running across a `/reload` is counted once.
- [ ] **Unknown item** (V27). If you fish up an item the game did not know before (a new Forever item). Expected: it is
  counted in Top catches (by its number until the game knows it) and in "What can be caught here" under "Only mine".
- [x] **Zones.** Fish in two zones. Expected: both in the zones list, with the current zone marked.
- [x] **Row tooltips and Refresh.** Hover the row names and press Refresh. Expected: an explanation per row; the
  numbers do not change on Refresh unless something happened.
- [x] **Reset.** Reset session and Reset all. Expected: a confirmation popup first; Cancel changes nothing.

## 7. Auction prices

- [x] **Scan.** At the auction house press "Scan fish prices". Expected: the items you caught are looked up one at
  a time; the statistics show the scan date and the catch value uses auction prices.
- [x] **Closed auction house.** `/okf scan` away from the auction house. Expected: a chat line that it must be open;
  the scan button in the settings and the minimap menu is disabled.
- [x] **Vendor only.** Turn "Use scanned auction prices for catch value" off. Expected: the value falls back to
  vendor prices.

## 8. Next rank reminder

The full check (names, places, pins) is the "Next rank" section of
[interface-language.md](interface-language.md); here only the behaviour.

- [ ] **Can learn.** (re-run after spec 008) At skill 50 (or 125 / 225) with the character level 10 (20 / 35). Expected:
  one chat line and a notification that the next rank can be learned and where; not again in this session. In game
  2026-11-06 at level 10, also with catch notifications off.
- [ ] **At the cap.** (re-run after spec 008) On a character whose Fishing rank is at its cap (75, 150 or 225).
  Expected: a large on-screen message the first time in a session; entering fishing mode again prints only a chat line;
  it stops after the next rank is learned. In game 2026-11-05 (cap 75 at level 6): the message and the chat line as
  expected; after Journeyman was learned (2026-11-06) the notices stopped and the advice moved to Expert.
- [x] **Off.** (re-run after spec 008) Turn "Remind me about the next Fishing rank" off. Expected: no notices; the "Next
  rank" line in the statistics window stays.
  2026-11-11 (skill 154/225, Artisan advice, addon in Ukrainian): the line and its Pin button stay, no notice on
  entering or leaving the mode: as expected.

## 9. Minimap button and settings

- [ ] **Tooltip colours** (spec 012). Over a session, hover item rows of the statistics window, then the minimap
  button, many times. Expected: the gold, grey and green lines keep their colours (once every line was white,
  2026-11-08); not decided by one hover.

- [x] **Two keys (spec 007).** Bind two keys to each action (`` ` `` and `'`, `SHIFT-`` and `SHIFT-'`). Expected:
  the minimap tooltip, the key line of the settings page and the indicator show both keys of each action, in the
  same order (the indicator puts them on two lines). With one key unbound: that action
  shows one key.

- [x] **Button.** Left-click toggles the mode, Shift+Left-click opens the statistics, Right-click opens the menu
  (mode, statistics, settings, scan, reset indicator, debug report), drag moves it around the minimap; the
  tooltip shows the mode, the skill, the session time and the keys; it is grey while the mode is off.
- [x] **Addon Compartment.** The addons button next to the minimap lists OneKeyFishing with the same actions.
- [x] **Hide it.** Turn "Show the minimap button" off. Expected: the button is gone, the compartment entry stays.
- [x] **Settings page.** (re-run after spec 008) Options -> AddOns -> OneKeyFishing. Expected: the Keys section shows
  both bindings; every checkbox of the manual's Settings list is there and takes effect (auto loot, bobber icon and gear
  on the next mode entry); the camera distance buttons change the zoom on the next entry; every Actions button works.
  Button and settings page: 2026-11-11 (game 70888, after specs 009-011): as expected, no error.
- [x] **`/okf`.** Expected: the command list with every command of the manual; `/onekeyfishing` does the same.

## 10. Debug report

- [x] `/okf debug` (re-run after spec 008) opens the copy window with the versions, the locale, the line `early L
  lookups: none`, the mode state and keys, the Fishing spell and skill, gear, lure (each lure line with `needs: N`),
  pending restore, fished items and settings; Ctrl+A, Ctrl+C copies it. No Lua errors during the whole run. In game
  2026-11-06 (`002-shared-db`, enUS): every section there, also Catch database, Catch catalog, Shared database and
  Errors (`none`); no lure in the bags, so no lure lines.
- [x] **Debug report from the menu and the settings.** The minimap right-click menu and the "Debug report" button on
  the settings page open the same copy window as `/okf debug` (a dangling call there was fixed in the simplify pass).
  In game 2026-11-06 (`002-shared-db`): both open it, no error.
- [x] **Catch pages after the shared-menu change.** On "What can be caught here" and on the catalog tab the "Skill" and
  "Source" menus open, mark the chosen entry and change the list; the chance column and the spot tooltip read as
  before; the catalog list does not flicker while a fishing session adds catches. In game 2026-11-07: as expected, no
  flicker while catches came in, no error.

## Results

- Date, build, client language: 2026-11-05, game 1.60.1 (70790), EU realm, client ruRU, addon
  1.0.0-dev+1dbac37, then 1.0.0-dev+212927b with the addon in Ukrainian; a new character, Fishing learned at
  level 5, skill 52/75 at level 6. 2026-11-06, release 1.1.0: level 10, Journeyman learned, the rank steps of
  level 10 done. Open: combat, two poles, lure cooldown, containers.
- 2026-11-11, game 1.60.1 (70888), client enUS, `002-shared-db` linked after specs 009-011, level 23, skill 154/225
  (Expert): the re-runs after spec 008 of sections 1, 3 (but finding fishing items), 4 (the lure), 8 (off) and 9
  pass, also with the addon in Ukrainian; no new error. Open: section 0 (the cap toast, the popup on a fresh account,
  an update over an old install), two poles, full bags, a lure above the skill, the lure cooldown, containers, the
  rank notices at 225.
- Problems found: see the Results of [interface-language.md](interface-language.md) (gear page, debug report,
  popups, minimap key text).
