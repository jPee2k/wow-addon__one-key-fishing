# Changelog

All notable changes to OneKeyFishing are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- The addon speaks your language: English, Deutsch, Español (EU), Español (AL), Français, Українська, 한국어,
  Português, 繁體中文 and 简体中文. It follows the game client's language (English when there is no translation,
  also on a Russian client).
- Language setting at the top right of the settings page: pick a language by its own name, or "Game client
  language". Українська is available this way. A change applies after a reload, which the addon offers.
- "What can be caught here", a second tab in the statistics window: the items of the spot you stand at, with
  their chance, pieces per catch and price, the number of catches behind them and the share of casts that catch
  nothing. Few catches at a spot: the whole map; few on the map too: "Little data". Filters for the skill range
  and for the source (all, or only your own catches).
- A catch database bundled with every release, so the tab has numbers from the first login. Your own catches
  are recorded for it per map, grid cell and skill range, under a random ID (no names; per cell only the average
  spot you fished from).
- Shared catch database: catch counts travel under a random ID and in the background between addon users in your
  guild, group and friends list (Battle.net friends playing WoW Forever included), and what they got from others
  reaches you too. No character names are sent or saved (the players you exchange with directly can tell which
  ID is yours); it pauses in combat, in instances and on loading
  screens, stays within 50 KB per hour and never shows anything in chat. "What can be caught here" counts it
  under "All" and says how many players the numbers come from ("60 catches from 3 players"), with a quiet status
  line at the bottom.
- "Shared database" settings page: one setting turns the exchange off (nothing sent or received; data received
  earlier is kept but not counted), with a short text on what is shared and the state. A popup at the first
  login says what is shared and where to turn it off.
- `/okf share` shows the state of the shared catch database; `/okf debug` has a section for it.
- The public channel: the shared catch database also reaches every other addon user through a hidden chat channel,
  `OneKeyFishingShare`. It is listed in the Chat Channels window but shows in no chat window, leaves General, Trade
  and your own channels on their numbers, keeps a chat channel slot free for you (and gives its own up with one chat
  line when you hit the limit), and moves to a fallback channel when somebody locks it. A setting under the first one,
  "Use the public channel", turns only the channel off; its state shows on the page and in `/okf share`. The popup
  that says what is shared names the channel and shows once more after this update.
- Protections for data from strangers: where five or more players reported a spot, none counts for more than a fifth
  of it; an item that is neither in the bundled data nor in your own catches shows once three players reported it on
  the map; each player's data carries a proof that only its owner can extend, so nobody can make up a newer version
  of it; a version holds at most as much fishing as its steps allow; the bundled data can block a contributor.
- Items your game client does not know yet show as "Unknown item" with their item ID in the tooltip, and get their
  name once the game knows them.
- "Catch catalog", a third tab in the statistics window: every item of the catch database with a search by its name
  in your client's language, the zones it is caught in with the chance there, and each zone's spots named after their
  subzone. A spot's pin button sets the game's own map pin there with the game's navigation, and asks first when you
  already have a pin of your own. `/okf catalog [name or item link]` opens it, and a click on an item of "What can be
  caught here" opens that item.
- Item tooltips show "Caught in:" with the item's three best zones and its chance; in fishing mode the minimap
  tooltip shows the three most likely catches of the place. "Show catch chances in tooltips" turns both off.
- Casts record the game's number of their subzone, so spots get a name in every client language.
- A "Water" filter (Everywhere, Open water, Pools) on both tabs once the database holds catches from fish pools.

### Changed

- Buttons grow to fit longer texts; long statistics labels are cut at the first column (the tooltip shows them
  in full).
- `/okf debug` shows the language setting, the language in use and the client language, a catch database
  section and a catch catalog section.
- Auction prices: the average of the cheapest fifth of the pieces on sale instead of the cheapest lot, so one
  lot far off the market no longer decides the price. With fewer than 5 pieces or fewer than 3 different
  offers (prices) on sale the price is marked "(few lots)" and the catch value uses the vendor price.
- Slash commands and the `/okf` help are always in English, whatever the interface language.
- The player manual ships inside the addon folder as `README.md`, next to `CHANGELOG.md`.

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
