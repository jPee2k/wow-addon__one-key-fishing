# Changelog

All notable changes to OneKeyFishing are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- "What can be caught here", a second tab in the statistics window: the items of the spot you stand at, with
  their chance, pieces per catch and price, the number of catches behind them and the share of casts that catch
  nothing. Few catches at a spot: the whole map; few on the map too: "Little data". Filters for the skill range,
  for the source (all, or only your own catches) and, once there are catches from fish pools, for the water
  (everywhere, open water, pools).
- A catch database bundled with every release, so the tab has numbers from the first login. Your own catches
  are recorded for it per map, grid cell and skill range, under a random ID (no names; per cell only the average
  spot you fished from and the game's number of the subzone, so spots get a name in every client language).
- Shared catch database: catch counts travel under a random ID and in the background between addon users in your
  guild, group and friends list (Battle.net friends playing WoW Forever included), and what they got from others
  reaches you too. No character names are sent or saved (the players you exchange with directly can tell which
  ID is yours); it pauses in combat, in instances and on loading screens, stays within 50 KB per hour and never
  shows anything in chat. "What can be caught here" counts it under "All" and says how many players the numbers
  come from ("60 catches from 3 players"), with a quiet status line at the bottom.
- "Shared database" settings page: "Use the shared catch database" turns the exchange off (nothing sent or received;
  data received earlier is kept but not counted), with a short text on what is shared and the state. A popup at the
  first login says what is shared and where to turn it off.
- Protections for data from strangers: where five or more players reported a spot, none counts for more than a fifth
  of it; an item that is neither in the bundled data nor in your own catches shows once three players reported it on
  the map; each player's data carries a proof that only its owner can extend, so nobody can make up a newer version
  of it; a version holds at most as much fishing as its steps allow; the bundled data can block a contributor.
  Data that does not add up is refused, and its sender is ignored until the end of the session.
- Items your game client does not know yet show as "Unknown item" with their item ID in the tooltip, and get their
  name once the game knows them.
- "Catch catalog", a third tab in the statistics window: every item of the catch database with a search by its name
  in your client's language, the zones it is caught in with the chance there, and each zone's spots named after their
  subzone. A spot's pin button sets the game's own map pin there with the game's navigation, and asks first when you
  already have a pin of your own. `/okf catalog [name or item link]` opens it, and a click on an item of "What can be
  caught here" opens that item.
- Item tooltips show "Caught in:" with the item's three best zones and its chance; in fishing mode the minimap
  tooltip shows the three most likely catches of the place. "Show catch chances in tooltips" turns both off.
- `/okf share` shows the state of the shared catch database; `/okf debug` has sections for the catch database, the
  exchange and the catalog.
- `/okf debug` ends with the addon's recent errors ("Errors"): where each happened, how often and when, with a few
  lines of the code that failed. Errors still show as before in the game's error window or BugSack.

### Changed

- A lure your Fishing skill is too low for is no longer offered; it is used once your skill is high enough.
- Auction prices: the average of the cheapest fifth of the pieces on sale instead of the cheapest lot, so one
  lot far off the market no longer decides the price. With fewer than 5 pieces or fewer than 3 different
  offers (prices) on sale the price is marked "(few lots)" and the catch value uses the vendor price.
- Slash commands and the `/okf` help are always in English, whatever the interface language.
- When one part of the addon fails, the others keep working: an error in one part no longer stops the others from
  handling the same moment (a failure in the statistics no longer costs the catch database a catch).

### Fixed

- Items your game client does not know yet are counted in the statistics and in your catch data, and fished
  containers of that kind are remembered like the others, so the key opens them and the auction scan includes them.
- After setting a map pin, the world map no longer fails in a fight ("Interface action failed because of an
  AddOn"): the pin no longer opens the map, and its message says to open it.
- Leaving fishing mode in a fight no longer raises "Interface action failed"; the gear comes back when the fight
  ends.
- In a fight the fishing key now pauses and says so, instead of trying to cast, and the indicator shows "Paused in
  combat". The pause also covers the hook: a bobber still out when a fight starts can no longer be hooked until it
  ends.
- An attack in fishing mode (with "Leave fishing mode when attacked" on) now says that the mode ends after the
  fight.
- The manual no longer promises a navigation arrow on screen for the next-rank pin.
- One catch reads "1 catch" instead of "1 catches" in the zone list of the statistics window and the session line
  of the minimap tooltip.

## [1.1.0] - 2026-11-05

### Added

- The addon speaks your language: English, Deutsch, Español (EU), Español (AL), Français, Українська, 한국어,
  Português, 繁體中文 and 简体中文. It follows the game client's language (English when there is no translation,
  also on a Russian client).
- Language setting at the top right of the settings page: pick a language by its own name, or "Game client
  language". Українська is available this way. A change applies after a reload, which the addon offers.
  Korean and Chinese read best on a Korean or Chinese game client: on a client in another language some
  tooltips are a little too narrow for them.
- On a client without a translation (a Russian one, for example) the addon says once in the chat that other
  languages can be picked in the settings. Nothing is switched for you.
- The description in the game's addon list is in the client's language, and the addon sits in the Professions
  category there.
- Decimal numbers in the statistics use the game client's decimal separator (2,5 on a German client), whatever
  the interface language.
- The next Fishing rank in the statistics window and the minimap tooltip: what it waits for (skill or character
  level) and where it is learned.
- A map pin with the game's navigation arrow for the Expert book seller and the Artisan quest giver: a Pin button
  in the statistics window, an entry in the minimap menu and a map link in the chat. A pin you set yourself is
  replaced only after you confirm.

### Changed

- The rank reminder follows the game's rules: a short notice once per session when the next rank can be learned
  (skill 50, 125, 225 with character level 10, 20, 35; it waits for the level), and the large on-screen message at
  the cap only the first time in a session (later entries into fishing mode repeat it in the chat). These notices
  show even with catch notifications off. The setting is now called "Remind me about the next Fishing rank".
- The names in the rank advice (the book, the quest, the places, the ranks, the NPCs) are the ones your game client
  shows, in its language, so they match the map and the quest log whatever language the addon is in.
- Buttons grow to fit longer texts, and the statistics window puts its buttons on two rows when they do not fit
  in one; long statistics labels are cut at the first column (the tooltip shows them in full).
- `/okf debug` shows the language setting, the language in use and the client language.
- The player manual ships inside the addon folder as `README.md`, next to `CHANGELOG.md`.

### Fixed

- The Fishing gear settings page no longer shows empty rows with Remove buttons, or an error when you hover them,
  the first time you open it in a session.
- `/okf debug` shows the whole Gear section when you have no lure in your bags.
- The minimap tooltip, the settings page and the indicator show both keys when you bound two keys to an action
  (for example one per keyboard language), in the order of the game's Keybindings window; the indicator puts them
  on two lines.

## [1.0.0] - 2026-10-23

First public release, for WoW Forever.

### Added

- One key for the whole fishing loop: cast, hook the bobber and loot. The same key also applies a lure
  (the best one in your bags that is not on cooldown) and opens fished clams and containers.
- Fishing mode: one toggle that sets up auto loot, soft-target interact, the camera and your fishing gear,
  and puts everything back when you leave it, after a `/reload`, a disconnect or a crash.
- Gear swap: the best pole in your bags (or the one you chose) plus your extra fishing items. Only the slots
  that were changed are restored. Alt+Click items in your bags to add or remove them.
- Action indicator with the next action, a cast bar, a "No bobber" warning and the session timer.
- Catch notifications.
- Statistics per session, per zone and in total: casts, catches, misses, fishing time (paused while AFK),
  catch value, catches per hour and gold per hour. The window explains every row, updates when something
  happens (only the time ticks while you fish), has a Refresh button and shows the date of the last
  auction scan.
- Auction house scan of everything you have caught; the catch value uses the higher of the vendor and the
  auction price.
- Fishing rank cap warning with where to learn the next rank.
- Minimap button and Addon Compartment entry with a menu for every action; a settings panel for every feature.
- `/okf debug`: a report to copy into bug reports.
- Works with a game client in any language. The interface is in English for now.
