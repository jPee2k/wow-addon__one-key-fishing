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

## 1. Fishing mode

- [ ] **On.** Press the toggle key at the water. Expected: the pole is equipped, the camera zooms to the set
  distance, the indicator appears with `Cast`, the minimap button lights up, the chat says the mode is on.
- [ ] **Off.** Press it again. Expected: the previous weapons and gear are back, the camera zoom is back, auto loot
  and the soft-target CVars are back to their previous values (check Options -> Gameplay -> Controls, Interact
  Key and Auto Loot, before and after), the indicator is gone.
- [ ] **`/reload` in the mode.** Turn the mode on, `/reload`. Expected: the mode is still on, the gear and the camera
  as they were in the mode.
- [ ] **Relog in the mode.** Turn the mode on, log out to the character screen, log in. Expected: the mode is off,
  the gear and the CVars are restored; the camera stays as the game left it.
- [ ] **Out of combat only.** Turn the mode on, let a mob attack you. Expected: the weapons come back at once, the
  chat says the key is paused; after the fight the rest of the gear comes back and the mode is off (with "Leave
  fishing mode when attacked" on).

## 2. The key

- [ ] **Cast.** In the mode press the action key. Expected: Fishing is cast, the indicator shows the cast bar and
  `Hook!` once the bobber is out.
- [ ] **Hook and loot.** After the splash press the same key. Expected: the bobber is hooked and the loot is taken
  (auto loot on); a catch notification shows above the indicator.
- [ ] **Miss.** Let a cast run out without hooking. Expected: a "nothing caught" notification about a second later;
  the statistics count a miss.
- [ ] **No bobber.** Cast, then turn the camera away from the bobber. Expected: the indicator shows "No bobber"
  after about 3 seconds; turning back clears it.
- [ ] **Outside the mode.** Turn the mode off and press the action key. Expected: a chat line that the mode is off,
  nothing else happens.
- [ ] **Unbound.** Unbind the action key and turn the mode on. Expected: a chat line that no key is bound.

## 3. Gear

- [ ] **Best pole.** With two poles in the bags and no chosen pole, enter the mode. Expected: the pole with the
  higher fishing bonus (then the higher item level) is equipped.
- [ ] **Chosen pole and extra items.** Alt+Click a pole and a hat in the bags. Expected: the settings page "Fishing
  gear" lists them; entering the mode equips both; leaving puts back the previous weapons and helmet. With no
  previous helmet, the hat goes back to the bags.
- [ ] **Remove.** Alt+Click the hat again. Expected: it leaves the list; the next mode entry does not equip it.
- [ ] **Find fishing items.** Press the button on the gear page with a fishing-bonus item in the bags. Expected: the
  item is added; pressing again adds nothing new.
- [ ] **Leaving during a cast.** Cast, then press the toggle key while the bobber is out. Expected: the mode ends and
  the gear is restored once the cast ends.
- [ ] **Full bags.** Fill the bags and leave the mode. Expected: a chat line that there is no free bag space to take
  off the gear; freeing a slot and leaving again restores it.

## 4. Lures and containers

- [ ] **Lure.** With a lure in the bags and none on the pole, press the action key. Expected: the indicator shows
  `Apply lure`, the key applies it (a 5 second cast), the next press casts.
- [ ] **Lure on cooldown.** Right after a lure was applied and removed (or with a second lure type), check the
  indicator. Expected: a lure on cooldown is skipped; the next one is offered, or a cast.
- [ ] **Lure too high.** With only a lure above your skill, press the key. Expected: "Cannot apply ..." once; the
  lure is skipped until the mode is entered again.
- [ ] **Clam.** Catch or carry a clam. Expected: the indicator shows `Open`, the key opens it, the loot is taken.
- [ ] **Locked container.** With a locked box in the bags. Expected: "Cannot open ..." once, then it is skipped.
- [ ] **No bag space.** With full bags and a clam. Expected: "Not enough bag space to loot ..."; after freeing a slot
  the key opens it again.

## 5. Indicator and notifications

- [ ] **Drag.** With "Lock the indicator position" off, drag the indicator. Expected: it moves; `/reload` keeps the
  place; "Reset indicator position" puts it back to the centre.
- [ ] **Locked.** Turn the lock on. Expected: the indicator cannot be dragged.
- [ ] **Session timer.** Turn "Show session fishing time under the indicator" on. Expected: the time counts while
  the mode is on, stops while off, pauses while AFK (with "Pause the fishing timer while AFK" on).
- [ ] **Notifications off.** Turn "Show catch notifications" off and catch a fish. Expected: no notification.

## 6. Statistics

- [ ] **Counts.** `/okf stats` (or Shift+Click on the minimap button). Fish 5 casts. Expected: casts, catches and
  misses add up to 5 in the Session column; This zone and All time grow by the same numbers.
- [ ] **Time.** Expected: "Time fishing" counts while the mode is on, "Time casting" only while the bobber is out.
- [ ] **Survives `/reload` and relog.** Expected: Session is kept across `/reload`, All time across a relog; a cast
  running across a `/reload` is counted once.
- [ ] **Zones.** Fish in two zones. Expected: both in the zones list, with the current zone marked.
- [ ] **Row tooltips and Refresh.** Hover the row names and press Refresh. Expected: an explanation per row; the
  numbers do not change on Refresh unless something happened.
- [ ] **Reset.** Reset session and Reset all. Expected: a confirmation popup first; Cancel changes nothing.

## 7. Auction prices

- [ ] **Scan.** At the auction house press "Scan fish prices". Expected: the items you caught are looked up one at
  a time; the statistics show the scan date and the catch value uses auction prices.
- [ ] **Closed auction house.** `/okf scan` away from the auction house. Expected: a chat line that it must be open;
  the scan button in the settings and the minimap menu is disabled.
- [ ] **Vendor only.** Turn "Use scanned auction prices for catch value" off. Expected: the value falls back to
  vendor prices.

## 8. Next rank reminder

The full check (names, places, pins) is the "Next rank" section of
[interface-language.md](interface-language.md); here only the behaviour.

- [ ] **Can learn.** At skill 50 (or 125 / 225) with the character level 10 (20 / 35). Expected: one chat line and
  a notification that the next rank can be learned and where; not again in this session.
- [ ] **At the cap.** On a character whose Fishing rank is at its cap (75, 150 or 225). Expected: a large
  on-screen message the first time in a session; entering fishing mode again prints only a chat line; it stops
  after the next rank is learned.
- [ ] **Off.** Turn "Remind me about the next Fishing rank" off. Expected: no notices; the "Next rank" line in the
  statistics window stays.

## 9. Minimap button and settings

- [ ] **Button.** Left-click toggles the mode, Shift+Left-click opens the statistics, Right-click opens the menu
  (mode, statistics, settings, scan, reset indicator, debug report), drag moves it around the minimap; the
  tooltip shows the mode, the skill, the session time and the keys; it is grey while the mode is off.
- [ ] **Addon Compartment.** The addons button next to the minimap lists OneKeyFishing with the same actions.
- [ ] **Hide it.** Turn "Show the minimap button" off. Expected: the button is gone, the compartment entry stays.
- [ ] **Settings page.** Options -> AddOns -> OneKeyFishing. Expected: the Keys section shows both bindings; every
  checkbox of the manual's Settings list is there and takes effect (auto loot, bobber icon and gear on the next
  mode entry); the camera distance buttons change the zoom on the next entry; every Actions button works.
- [ ] **`/okf`.** Expected: the command list with every command of the manual; `/onekeyfishing` does the same.

## 10. Debug report

- [ ] `/okf debug` opens the copy window with the versions, the locale, the mode state and keys, the Fishing spell
  and skill, gear, lure, pending restore, fished items and settings; Ctrl+A, Ctrl+C copies it. No Lua errors
  during the whole run.

## Results

- Date, build, client language:
- Problems found:
