# Roadmap

Ideas for versions after 1.0.0. Nothing here is scheduled yet: each item gets its own plan before work starts.
Every feature must keep the addon's rule: every game action is a real key press, nothing reacts to the
bobber by itself.

## 1. Shared fishing database

What can be caught where, for every zone and fishing spot of the world. Planned in four releases in
[shared-db-plan.md](shared-db-plan.md); 1.1.0 (own data, the "What can be caught here" tab and a bundled
database refreshed by `npm run harvest`) is built in `specs/002-local-catch-db` and waits for the in-game checks
after the game launch. The notes below are the original idea.

- Built from the catches players record with the addon (the addon already stores caught items per zone and
  subzone in `OneKeyFishingCharDB.stats.zones`).
- An addon cannot send data out of the game, so the shared data travels as a data file bundled with new
  releases: players export their catches (a copy window, like the debug report), the data is merged outside
  the game and shipped in the next version.
- In game: a "What can be caught here" list for the current zone, merged from the bundled data and your own
  catches.
- Open questions: export format and privacy (no character names), how to merge and validate submissions,
  keeping the data file small, zones that differ between game versions.

## 2. Catch chances

The chance to catch each item at the current spot. Covered for the statistics window by 1.1.0 (see item 1);
the minimap and item tooltips follow in a later release of the plan.

- From your own statistics (catches per item / all catches in the zone) and from the shared database.
- Shown in the statistics window and, optionally, in the minimap tooltip.
- Depends on the skill and on lures, so the chances may need to be grouped by skill range.
- Small samples need care: show how many catches a number is based on.

## 3. Localization

Done in `specs/001-interface-language`: ten languages and a language setting, see [languages.md](languages.md).
What is left:

- Native-speaker review of the eight translations other than Ukrainian (CurseForge localization tool or pull
  requests), especially game names (ranks, places, the fishing book) that were kept in English where unsure.

## Ideas to discuss

- Fishing pools: notice and point out nearby pools.
- Skill-up forecast: how many catches until the next skill point or rank cap.
