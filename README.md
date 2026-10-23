# OneKeyFishing

Fish with one key in **WoW Forever**: the same key casts, hooks the bobber and loots. No mouse, no clicking on the bobber.

Every action in the game is a real key press. The addon never reacts to a bite by itself, does not listen to sounds and uses no external tools, so it stays within Blizzard's add-on rules.

## Features

- **One key** for everything: cast → hook → loot. The same key also applies a lure and opens fished clams when needed.
- **Fishing mode**: one toggle that sets everything up and puts it all back afterwards.
- **Gear swap**: equips the best pole in your bags (or the one you chose) plus your fishing items. On exit it restores only the slots it changed.
- **Auto loot** while fishing, and the soft-target icon over the bobber.
- **Indicator**: shows what the key will do next (`Cast`, `Hook!`, `Apply lure`, `Open`), a cast bar and a warning when no bobber is targeted.
- **Catch notifications** for every catch and every miss.
- **Statistics**: casts, catches, misses, fishing time and value of the catch. Kept per session, per zone and in total.
- **Auction scan**: prices of everything you have ever caught, used for the catch value.
- **Rank cap warning**: tells you when your Fishing rank is full and where to learn the next one.
- **Camera** zooms in while fishing and back afterwards.
- **Safe in combat**: when attacked, the weapons come back at once and fishing mode ends after the fight.
- **Minimap button** with a menu: every action is available without typing a command.

## Installation

1. Unpack `OneKeyFishing.zip` into `World of Warcraft\_forever_\Interface\AddOns`.
   You should get `Interface\AddOns\OneKeyFishing\OneKeyFishing.toc`.
2. Start the game or type `/reload`.

## Quick start

1. Open **Options → Keybindings → AddOns → OneKeyFishing** and bind two keys:
   - **Fishing action (cast / hook)**, for example `` ` `` or a mouse side button;
   - **Toggle fishing mode**, for example `Shift+F`.
2. Go to the water and press **Toggle fishing mode**. Your pole goes on, the camera zooms in and the indicator appears.
3. Press the **fishing action** key: you cast.
4. Wait for the splash and press the **same key** again: you hook and loot the fish.
5. Press **Toggle fishing mode** again when you are done: your weapons, gear, camera and game settings come back.

Example of one fishing round:

| You press | Indicator shows | What happens |
|---|---|---|
| Action key | `Cast` | Fishing is cast, the bobber lands |
| (wait for the splash) | `Hook!` | — |
| Action key | `Hook!` | The bobber is hooked, the fish is looted |
| Action key | `Apply lure` | The pole had no lure: a lure from your bags is applied |
| Action key | `Open` | A clam you caught is opened |
| Action key | `Cast` | The next cast |

## Fishing gear

By default the addon equips the **best pole in your bags** (by fishing bonus, then by item level).

To choose your own items:

- **Alt+Click** an item in your bags or on the character panel to add it to your fishing gear. Alt+Click it again to remove it.
  - A fishing pole becomes your chosen pole.
  - Any other item (hat, boots, gloves, ring...) is added to the list of extra items.
- Or open **Options → AddOns → OneKeyFishing → Fishing gear**:
  - **Use the best pole automatically** clears the chosen pole;
  - type an item name or paste a link and press **Add**;
  - **Find fishing items** adds every item with a Fishing bonus that you wear or carry.

Example: you add *Nat Pagle's Extreme Anglin' Boots* and *Lucky Fishing Hat*. When fishing mode starts, the addon puts on the pole, the boots and the hat. On exit it puts back your weapons, your normal boots and your normal helmet. If you had no helmet, the hat goes to your bags. Slots it did not touch stay as they are.

The previous items are saved right away, so a `/reload`, a disconnect or a crash will not leave you in fishing gear.

## Statistics

Open them with `/okf stats`, Shift+Click on the minimap button or from its menu.

- **Session**, **This zone** and **All time** columns: time fishing, time casting, casts, catches, nothing caught, catches per hour, value and gold per hour.
- **Top items** and **top zones**.
- **Reset session** and **Reset all** ask for confirmation first.

The timer runs only while fishing mode is on. It pauses while you are AFK (you can turn that off).

## Auction prices

1. Open the auction house.
2. Press **Scan fish prices** above the auction window (or use the minimap menu, the settings page or `/okf scan`).
3. The addon looks up every item you have ever caught, one at a time.

The catch value uses the higher of the vendor and the auction price. To use vendor prices only, turn off **Use scanned auction prices for catch value**.

## Minimap button

- **Left-click**: toggle fishing mode.
- **Shift+Left-click**: statistics.
- **Right-click**: menu with all actions (mode, statistics, settings, auction scan, reset indicator position, API check).
- **Drag**: move the button around the minimap.
- The tooltip shows the mode, your Fishing skill, the session time, your key bindings and short instructions.
- The button is grey while fishing mode is off.

The same entry is in the Addon Compartment (the addons button next to the minimap).

## Settings

**Options → AddOns → OneKeyFishing**. Every feature can be turned on or off:

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

## Commands

Typing commands is optional: everything is also available from the menus. `/fish` works the same as `/okf`.

| Command | What it does |
|---|---|
| `/okf` | list all commands |
| `/okf toggle` | enter or leave fishing mode |
| `/okf stats` | show the statistics |
| `/okf config` | open the settings |
| `/okf scan` | scan auction prices (auction house must be open) |
| `/okf debug` | show the API check report (useful for bug reports) |

## Troubleshooting

- **"No key is bound to 'Fishing action'"**: bind it in Options → Keybindings → AddOns → OneKeyFishing.
- **"Fishing mode is off"**: the action key only works in fishing mode. Press your toggle key first.
- **The indicator shows "No bobber"**: the bobber is not soft-targeted. Turn the camera towards the bobber.
- **"Cannot apply ..." / "Cannot open ..."**: the lure needs a higher Fishing skill, or the container is locked. The addon skips that item for the rest of the session.
- **"Not enough bag space to loot ..."**: a container was opened but its loot did not fit. Free a bag slot and the key opens it again.
- **"No free bag space to take off ..."**: free a bag slot, then leave fishing mode again.
- **Something else**: run `/okf debug` and copy the report from the window.

## Requirements

- WoW Forever (Interface 16001).
- The Fishing skill.
- No other addons or libraries.
