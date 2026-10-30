# Roadmap

Features for versions after 1.0.0. Item 3 is built for release 1.1.0 and items 1 and 2 are planned for release
1.2.0; neither is released yet. The rest is not scheduled: each item gets its own plan before work starts.
Every feature must keep the addon's rule: every game action is a real key press, nothing reacts to the
bobber by itself.

## 1. Shared fishing database

What can be caught where, for every zone and fishing spot of the world. Planned in four parts that ship together
as release 1.2.0, in [shared-db-plan.md](shared-db-plan.md). Part 1 (own data, the "What can be caught here" tab
and a bundled database refreshed by `npm run harvest`) is built in `specs/002-local-catch-db`; part 2 (exchange
in the guild, the group and with friends) is built in
[specs/003-guild-group-sync](../specs/003-guild-group-sync/spec.md) (`Comm.lua`, `Share.lua`, `/okf share`). Both
wait for the in-game checks after the game launch. Parts 3 (a hidden public channel) and 4 (catch catalog,
tooltips, pools) are planned in the same file and have no spec yet.

How it works now:

- Every cast in fishing mode is counted per map, grid cell and skill range under a random account ID, with no
  character names.
- The counts travel between addon users in the guild, the group and the friends list (`Comm.lua`, `Share.lua`).
- Before a release, `npm run harvest` turns the saved catch data (the author's accounts, which also hold what the
  exchange brought in, and saved files players send) into the database bundled with the release.
- In game: the "What can be caught here" tab, from the bundled data, your own catches and what other players
  shared.

## 2. Catch chances

The chance to catch each item at the current spot. Covered for the statistics window by part 1 (see item 1);
the minimap and item tooltips follow in part 4 of the plan.

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
