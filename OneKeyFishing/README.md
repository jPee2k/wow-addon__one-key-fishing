# OneKeyFishing

Fish with one key in **WoW Forever**: the same key casts, hooks the bobber and loots. No mouse, no clicking on the
bobber.

Every action is a real key press. The addon never reacts to a bite by itself, does not listen to sounds and uses
no external tools, so it stays within Blizzard's add-on rules.

It works with a game client in any language. The addon itself speaks English, Deutsch, Español (EU), Español (AL),
Français, Українська, 한국어, Português, 繁體中文 and 简体中文: it follows your game client's language, or the one
you pick in the settings.

## Quick start

1. Install the addon into `World of Warcraft\_forever_\Interface\AddOns\OneKeyFishing` (the CurseForge app does
   this for you) and restart the game. A `/reload` does not pick up a newly installed addon.
2. Open **Options → Keybindings → AddOns → OneKeyFishing** and bind two keys:
   - **Fishing action (cast / hook)**: a letter key such as `R`, or a mouse side button;
   - **Toggle fishing mode**: for example `Shift+F`.
3. Go to the water and press **Toggle fishing mode**. Your pole goes on, the camera zooms in and the indicator
   appears.
4. Press the **fishing action** key: you cast.
5. Wait for the splash and press the **same key** again: you hook and loot the fish.
6. Press **Toggle fishing mode** again when you are done: your weapons, gear, camera and game settings come back.

One fishing round:

| You press | Indicator shows | What happens |
|---|---|---|
| Action key | `Cast` | Fishing is cast, the bobber lands |
| (wait for the splash) | `Hook!` | |
| Action key | `Hook!` | The bobber is hooked, the fish is looted |
| Action key | `Apply lure` | The pole had no lure: a lure from your bags is applied |
| Action key | `Open` | A clam you caught is opened |
| Action key | `Cast` | The next cast |

> **Keyboard language.** Punctuation keys (`'` `;` `[` `]` `,` `.` `/` `` ` ``) are named by the character the
> current Windows keyboard language types, so a `'` bound on English is a different key for the game on another
> language and the binding stops working after you switch. Every binding has two slots: bind the key once per
> language. Letters, numbers, F-keys and mouse buttons work on every language. This is how WoW works, not the addon.

## What the addon does

- **One key** for everything: cast, hook, loot. The same key applies a lure (the best one that is not on
  cooldown) and opens fished clams when needed.
- **Fishing mode**: one toggle that sets everything up (auto loot, the interact icon over the bobber, gear,
  camera) and puts it all back afterwards, also after a `/reload`, a disconnect or a crash.
- **Gear swap**: the best pole in your bags (or the one you chose) plus your fishing items. On exit only the slots
  it changed are restored.
- **Indicator**: what the key will do next (`Cast`, `Hook!`, `Apply lure`, `Open`), a cast bar, the session timer
  and a warning when the bobber is in the water but not targeted.
- **Catch notifications** for every catch and every miss.
- **Statistics**: casts, catches, misses, fishing time and the value of the catch, per session, per zone and in
  total.
- **Auction scan**: prices of everything you have ever caught, used for the catch value.
- **Rank cap warning**: when your Fishing rank is full, and where to learn the next one.
- **Safe in combat**: when attacked, the weapons come back at once and fishing mode ends after the fight.
- **Minimap button** with a menu: every action is available without typing a command.

## Fishing gear

By default the addon equips the **best pole in your bags** (by fishing bonus, then by item level).

To choose your own items:

- **Alt+Click** an item in your bags or on the character panel to add it to your fishing gear. Alt+Click it again
  to remove it. A fishing pole becomes your chosen pole; any other item (hat, boots, gloves, ring...) is added to
  the list of extra items.
- Or open **Options → AddOns → OneKeyFishing → Fishing gear**: **Use the best pole automatically** clears the
  chosen pole; type an item name or paste a link and press **Add**; **Find fishing items** adds every item with a
  Fishing bonus that you wear or carry.

Example: you add *Nat Pagle's Extreme Anglin' Boots* and *Lucky Fishing Hat*. When fishing mode starts, the addon
puts on the pole, the boots and the hat. On exit it puts back your weapons, your normal boots and your normal
helmet. If you had no helmet, the hat goes to your bags. Slots it did not touch stay as they are.

The previous items are saved right away, so a `/reload`, a disconnect or a crash will not leave you in fishing gear.

## Statistics

Open them with `/okf stats`, Shift+Click on the minimap button or from its menu.

- **Session**, **This zone** and **All time** columns in three sections: **Time** (time fishing, time casting),
  **Results** (casts, catches, nothing caught, catches per hour) and **Money** (value, gold per hour). Hover a row
  name to see how it is counted.
- **Top catches** and **zones** of all time.
- **Refresh** recomputes everything now. Otherwise the numbers change only when something happens (a cast, a
  catch, a miss, a zone change, an auction scan); only the time rows tick while you fish. The session shows
  `H:MM:SS`, the zone and all-time columns `1h 23m`.
- The line under the skill shows when auction prices were last scanned.
- **Reset session** and **Reset all** ask for confirmation first.

The timer runs only while fishing mode is on. It pauses while you are AFK (you can turn that off).

## Auction prices

1. Open the auction house.
2. Press **Scan fish prices** above the auction window (or use the minimap menu, the settings page or `/okf scan`).
3. The addon looks up every item you have ever caught, one at a time.

The catch value uses the higher of the vendor and the auction price. To use vendor prices only, turn off **Use
scanned auction prices for catch value**.

## Minimap button

- **Left-click**: toggle fishing mode.
- **Shift+Left-click**: statistics.
- **Right-click**: a menu with every action (mode, statistics, settings, auction scan, reset indicator position,
  debug report).
- **Drag**: move the button around the minimap.
- The tooltip shows the mode, your Fishing skill, the session time, your key bindings and short instructions. The
  button is grey while fishing mode is off.

The same entry is in the Addon Compartment (the addons button next to the minimap).

## Settings

**Options → AddOns → OneKeyFishing**.

- **Keys**: the two bindings and where to change them.
- **Features**, each with a checkbox:
  - Auto loot while fishing
  - Show the interact icon over the bobber
  - Leave fishing mode when attacked
  - Equip fishing pole and fishing gear
  - Apply lures automatically
  - Open clams and fished containers
  - Show the action indicator and cast timer
  - Lock the indicator position (drag the indicator to move it while unlocked)
  - Show catch notifications
  - Show session fishing time under the indicator
  - Pause the fishing timer while AFK
  - Warn when the Fishing rank is capped
  - Use scanned auction prices for catch value
  - Zoom the camera while fishing (set the distance with **−** and **+**)
  - Show the minimap button
- **Actions**: Toggle fishing mode, Debug report, Open statistics, Reset indicator position, Scan auction prices
  (with the auction house open).
- **Language** (top right): **Game client language** follows your client and uses English when there is no
  translation for it (a Russian client gets English). Pick a language from the menu to use it instead; Українська
  is only available this way, because the game has no Ukrainian client. The new language shows after a reload: the
  addon asks **Reload now** or **Later**. Korean and Chinese may show as squares on a client in another language;
  pick **English** to get a readable interface back.
- **Fishing gear**: a page of its own, see [Fishing gear](#fishing-gear).

## Commands

Typing commands is optional: everything is also available from the menus. `/onekeyfishing` works the same as
`/okf`.

| Command | What it does |
|---|---|
| `/okf` | list all commands |
| `/okf toggle` | enter or leave fishing mode |
| `/okf stats` | show the statistics |
| `/okf config` | open the settings |
| `/okf scan` | scan auction prices (the auction house must be open) |
| `/okf debug` | show a report to copy into a bug report |

## Troubleshooting

- **"No key is bound to 'Fishing action'"**: bind it in Options → Keybindings → AddOns → OneKeyFishing.
- **"Fishing mode is off"**: the action key only works in fishing mode. Press your toggle key first.
- **"The fishing key is paused in combat"**: the mode is on, but the game does not let addons keep the key bound
  in combat. It works again when the fight ends.
- **The key stops working after switching the keyboard language**: it is a punctuation key, which WoW names by
  the current language. Bind it in the second slot of the same binding while the other language is on, or use a
  letter, number, F-key or mouse button (see [Quick start](#quick-start)).
- **The indicator shows "No bobber"**: the bobber is in the water but not soft-targeted (or still not after
  3 seconds). Turn the camera towards the bobber.
- **"Cannot apply ..."**: the lure needs a higher Fishing skill. The addon skips it until you turn fishing mode on
  again. A lure on cooldown is not skipped: the next ready lure is used instead (or none), and the lure is offered
  again when its cooldown ends.
- **"Cannot open ..."**: the container is locked. The addon skips it for the rest of the session.
- **"Not enough bag space to loot ..."**: a container was opened but its loot did not fit. Free a bag slot and the
  key opens it again.
- **"No free bag space to take off ..."**: free a bag slot, then leave fishing mode again.
- **Something else**: see [Reporting bugs](#reporting-bugs).

## Reporting bugs

1. Type `/okf debug` (or use **Debug report** in the minimap menu or the settings).
2. Click the text in the window, press Ctrl+A and Ctrl+C.
3. Open an issue at https://github.com/jPee2k/wow-addon__one-key-fishing/issues (or a comment on the CurseForge
   page) with the report, what you did and what happened. Copy any Lua error text as well.

## Requirements

- WoW Forever (Interface 16001), any client language.
- The Fishing skill.
- No other addons or libraries.

OneKeyFishing is free and open source (MIT license): https://github.com/jPee2k/wow-addon__one-key-fishing.
Changes are listed in `CHANGELOG.md` next to this file.
