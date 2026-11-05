# Changelog

All notable changes to OneKeyFishing are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

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
