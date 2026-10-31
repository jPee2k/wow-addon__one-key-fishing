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
> The minimap tooltip, the settings page and the indicator show both keys of each binding.

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
- **What can be caught here**: the items of the spot you stand at, with their chance, pieces per catch and price,
  from your own catches, the catch database that comes with the addon and the catches of the addon users you play
  with.
- **Shared catch database**: catch counts travel under a random ID between addon users in your guild, group and
  friends list, and through a hidden chat channel to every other addon user, in the background. Two settings turn it
  off.
- **Auction scan**: prices of everything you have ever caught, used for the catch value.
- **Next rank reminder**: when the next Fishing rank can be learned, where, and a map pin to the place.
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

Open them with `/okf stats`, Shift+Click on the minimap button or from its menu. The window has two tabs at the
bottom, **Statistics** and **What can be caught here**; it opens on the one you used last.

- **Session**, **This zone** and **All time** columns in three sections: **Time** (time fishing, time casting),
  **Results** (casts, catches, nothing caught, catches per hour) and **Money** (value, gold per hour). Hover a row
  name to see how it is counted. Decimal numbers use your game client's separator (2,5 on a German client),
  whatever the interface language.
- **Top catches** and **zones** of all time.
- **Refresh** recomputes everything now. Otherwise the numbers change only when something happens (a cast, a
  catch, a miss, a zone change, an auction scan); only the time rows tick while you fish. The session shows
  `H:MM:SS`, the zone and all-time columns `1h 23m`.
- The line under the skill shows when auction prices were last scanned; the next line says what the next Fishing
  rank waits for and where it is learned, with a **Pin** button for the book seller and the quest giver.
- **Reset session** and **Reset all** ask for confirmation first.

The timer runs only while fishing mode is on. It pauses while you are AFK (you can turn that off).

## What can be caught here

The second tab of the statistics window lists what the spot you stand at gives:

- every item caught there, with its **chance** (how many catches contained it), the **pieces per catch** and its
  **price**, plus how many catches the numbers are based on and how often a cast there catches nothing;
- a spot is a part of the map (the map is split into a 10 by 10 grid). When a spot has fewer than 50 catches, the
  tab shows the whole map and says so; with fewer than 50 there too, it shows **Little data** instead of
  percentages;
- **Skill**: your own skill range by default (0-74, 75-149, 150-224, 225-299, 300+), or any other range, or all
  of them;
- **Source**: **All** (your catches, the catch database bundled with the addon and what other players shared with
  you) or **Only mine**. Under **All** the tab says how many players the numbers come from ("60 catches from 3
  players");
- **Water**: once the database holds catches from fish pools, a third button splits them into **Everywhere**,
  **Open water** and **Pools**. Under the last two the share of casts that catch nothing is not shown, since a
  cast that catches nothing comes from no pool;
- an item your game client does not know yet (some items in WoW Forever stay unknown until you find one) shows as
  **Unknown item** with a question mark icon; its tooltip says how many players reported it on this map, whether the
  bundled data has it, and its item ID. Once the game knows the item, its name and icon appear;
- a quiet line at the bottom shows the state of the [shared catch database](#shared-catch-database);
- click an item to see where else it is caught, in the [catch catalog](#catch-catalog).

The numbers come from casts in fishing mode. Every release of the addon brings the catch database gathered so far,
so the tab has numbers from your first login; your own catches are added to them, nothing is counted twice.

What is stored: per place only counts (catches, misses, casting time, items) and the average spot you fished from
inside the grid cell, under a random ID of your account. No character names, guild, times or gear. With the [shared
catch database](#shared-catch-database) on, the same counts go to the addon users you play with; they also reach the
bundled database through the author's own client.

## Catch catalog

The third tab of the statistics window lists every item of the catch database: your own catches, the bundled data
and, with the shared catch database on, what other players reported.

- **Search**: type part of an item name, in your game client's language and in any letter case; the list narrows
  with every letter. Grey items only show when you search for them. An item your game client does not know yet
  stays out of the list until the game loads it.
- **Filters**: **Skill** (all ranges by default), **Source** (**All** or **Only mine**) and, when there is pool
  data, **Water**, as on the "What can be caught here" tab.
- **An item**: click it to see the zones it was caught in, with its chance there, the zone's catches and the span
  of skill it was caught with, the best zones first; zones with fewer than 50 catches come last with **Little
  data**. Hover a zone for how many players the numbers come from. Click a zone's **+** to see its spots: each is
  named after its subzone in your language (or shows its coordinates), with its own chance and catches.
- **Map pin**: the pin button of a spot sets the game's own map pin there, turns on the game's navigation to it,
  says so in a short message and opens the world map at that zone (not in combat). If you already have a pin that
  the addon did not set, it asks before replacing it. The arrow on screen depends on the game's navigation
  setting. Instances and spots without a position have no pin button.
- The tab follows new catches and new data from other players while it is open, keeping your search, the chosen
  item and the open zones. `/okf catalog` opens it; `/okf catalog <name>` searches, and an item link (shift-click an
  item into the line) opens that item.

**Catch chances in tooltips**: the tooltip of any item in the database adds **Caught in:** with its three best
zones and its chance there, also for chat links. In fishing mode, the minimap button's tooltip adds the three most
likely catches of the place you stand at. **Show catch chances in tooltips** in the settings turns both off.

## Shared catch database

Players who fish together see each other's catches right away, without waiting for the next release:

- **With whom**: addon users in your guild, your party or raid, and your online friends (character friends and
  Battle.net friends playing WoW Forever), and every other addon user the game lets you meet in the public channel
  (below). Data also travels further: what a guild mate got from their friends reaches you too.
- **The public channel**: about a minute after you log in, the addon joins a hidden chat channel,
  `OneKeyFishingShare`, shared by every addon user, and announces itself there now and then; strangers who run the
  addon then exchange with you by whisper, unseen. The channel is listed in the **Chat Channels** window and in
  **Chat Settings**, but it is taken out of every chat window: none of its lines show, and General, Trade and your
  own channels keep their numbers. Anyone who joins that channel by its name can see which characters in it use the
  addon. The game allows 20 chat channels: the addon only joins with two slots free, and when you hit the limit
  while it is in its channel, it leaves at once and says so in one line, so your next try works. If somebody locks
  the channel, every addon client moves to the same fallback channel (`OneKeyFishingShare2` and so on).
- **What**: the catch counts described above, with the average spot you fished from in each grid cell, under the
  random ID of your account. **No character names** are sent with them, and the names of the players you exchange
  with are never saved. The players you exchange with directly can still tell which ID is yours, since your client
  sends your own data itself; players who get it through others see only who passed it on.
- **When**: in the background whenever you are online, also outside fishing mode. It pauses in combat, in
  instances, on loading screens and where the game restricts addon messages, and stays within a small traffic
  budget (at most 50 KB per hour). Nothing appears in chat.
- **Off**: **Options → AddOns → OneKeyFishing → Shared database**, **Use the shared catch database**. Off means
  nothing is sent and nothing is received; data received earlier is kept but not counted, and counts again as soon
  as you turn it back on. **Use the public channel** below it leaves the channel and keeps the guild, group and
  friends exchange; what came through the channel before still counts. A popup at the first login says the same once
  (and once more after the update that brings the public channel).
- **State**: the line at the bottom of **What can be caught here**, the settings page and `/okf share` (the bundled
  data and its version, the contributions you hold, the players seen in the last hour, the last exchange, the
  traffic, and whether the public channel is in use or why not). `/okf debug` has the same numbers for bug reports,
  without your ID or anybody's name.
- Data that does not add up (more catches than the casting time allows, impossible item counts) is refused, and the
  player who sent it is ignored until the end of the session. Nothing is ever counted twice, also not after a
  release bundles data you already got from other players.
- **No single player can skew the numbers**: where five or more players reported a spot, no one of them counts for
  more than a fifth of it; the bundled data and your own catches count in full. An item that is neither in the
  bundled data nor in your own catches shows only once three players reported it on that map. Each player's data is
  bound to its owner: nobody else can make up a newer version of it. The author can block a contributor in the
  bundled data, and every client with that release drops it.
- **Trial and Veteran accounts** cannot send addon data; the state then says the exchange is unavailable.

## The next Fishing rank

| Next rank | Can be learned from | Where |
|---|---|---|
| Journeyman | skill 50, character level 10 | any fishing trainer (capitals and many towns) |
| Expert | skill 125, character level 20 | the book "Expert Fishing - The Bass and You", sold by Old Man Heming in Booty Bay |
| Artisan | skill 225, character level 35 | the quest "Nat Pagle, Angler Extreme" from Nat Pagle in Dustwallow Marsh |

- When the next rank can be learned, a chat line and a notification say so once per session (also with catch
  notifications off: the reminders have their own setting). Until your character
  has the level, the addon waits and says it once the level is reached.
- When your skill is at the cap (75, 150, 225), a large on-screen message says so the first time in a session;
  every time you enter fishing mode afterwards, a chat line repeats it.
- The names of the book, the quest, the places and the ranks are the ones your game client shows, in its language,
  whatever language the addon is in.
- For the book and the quest, the chat line ends with a map link, and the statistics window and the minimap menu
  have a pin button: the game's map pin and navigation arrow point at the seller or the quest giver. A pin you set
  yourself is replaced only after you confirm (the chat link works like any map link and sets the pin at once).
- Turn the reminders off with "Remind me about the next Fishing rank"; the line in the statistics window stays.

## Auction prices

1. Open the auction house.
2. Press **Scan fish prices** above the auction window (or use the minimap menu, the settings page or `/okf scan`).
3. The addon looks up every item you have ever caught, one at a time.

The auction price of an item is the average price of the cheapest fifth of all pieces on sale, so a single lot far
below or far above the market does not decide it. When fewer than 5 pieces or fewer than 3 different offers are on
sale (the auction house shows sellers at the same price as one offer; one seller's stack is not a market), the price
is shown with **(few lots)** and the catch value uses the vendor price instead.

The catch value uses the higher of the vendor and the auction price. To use vendor prices only, turn off **Use
scanned auction prices for catch value**.

## Minimap button

- **Left-click**: toggle fishing mode.
- **Shift+Left-click**: statistics.
- **Right-click**: a menu with every action (mode, statistics, settings, auction scan, a map pin for the next
  Fishing rank when it has a place, reset indicator position, debug report).
- **Drag**: move the button around the minimap.
- The tooltip shows the mode, your Fishing skill and the next rank, the session time, your key bindings and short
  instructions; in fishing mode also the most likely catches of the place you stand at. The button is grey while
  fishing mode is off.

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
  - Remind me about the next Fishing rank
  - Use scanned auction prices for catch value
  - Zoom the camera while fishing (set the distance with **−** and **+**)
  - Show the minimap button
  - Show catch chances in tooltips (the zones in item tooltips, the likely catches in the minimap tooltip)
- **Actions**: Toggle fishing mode, Debug report, Open statistics, Reset indicator position, Scan auction prices
  (with the auction house open).
- **Language** (top right): **Game client language** follows your client and uses English when there is no
  translation for it (a Russian client gets English, and the addon says once in the chat where to change it). Pick
  a language from the menu to use it instead; Українська is only available this way, because the game has no
  Ukrainian client. The description in the game's addon list always follows the client language, because the game
  shows it before the addon loads. The new language shows after a reload: the addon asks **Reload now** or
  **Later**. Korean and Chinese may show as squares on a client in another language; pick **English** to get a
  readable interface back.
- **Fishing gear**: a page of its own, see [Fishing gear](#fishing-gear).
- **Shared database**: a page of its own: **Use the shared catch database**, **Use the public channel** (greyed out
  while the first is off) with the channel's state, what is shared and the current state; see [Shared catch
  database](#shared-catch-database).

## Commands

Typing commands is optional: everything is also available from the menus. `/onekeyfishing` works the same as
`/okf`.

| Command | What it does |
|---|---|
| `/okf` | list all commands |
| `/okf toggle` | enter or leave fishing mode |
| `/okf stats` | show the statistics |
| `/okf config` | open the settings |
| `/okf catalog` | open the catch catalog; `/okf catalog <name or item link>` searches or opens that item |
| `/okf scan` | scan auction prices (the auction house must be open) |
| `/okf share` | show the state of the shared catch database |
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
