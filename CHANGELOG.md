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

### Changed

- Buttons grow to fit longer texts; long statistics labels are cut at the first column (the tooltip shows them
  in full).
- `/okf debug` shows the language setting, the language in use and the client language.

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
