# Changelog

All notable changes to OneKeyFishing are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-11-04

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
