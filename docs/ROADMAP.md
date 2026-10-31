# Roadmap

What is not built yet. Built features are listed in `CHANGELOG.md` (released and `[Unreleased]`); the two pending
releases are in [release-plan.md](release-plan.md). Nothing here is scheduled: each item gets its own spec before
work starts, and every feature must keep the addon's rule: every game action is a real key press, nothing reacts
to the bobber by itself.

## Open work on built features

- **Native-speaker review** of the eight translations other than Ukrainian (CurseForge localization tool or pull
  requests), especially game names (ranks, places, the fishing book) that were kept in English where unsure
  ([languages.md](languages.md)).
- **A harvest report after a game patch**: compare item shares before and after the patch in every zone and print
  the zones with a notable difference or new items, so the author knows where `npm run harvest -- --reset <mapID>`
  is due. Today the reset is a manual judgement.
- **A collection mode for the author** (`/okf share collect`): exchange sessions more often within the same
  traffic budget on the day before a release, so the harvest sees more of the network. An idea from the design of
  the shared database, not built.

## Ideas to discuss

- **Shared auction prices**: the catch value without a scan of one's own (the freshest scan wins, prices older
  than 3 days are not shared). Left out of the shared catch database: it waits for the in-game answer to which
  auction house a player uses in WoW Forever (game modes split by faction, no realms), since a peer from another
  house would bring wrong prices.
- **Fishing pools**: notice and point out nearby pools. The catch database already tells pool catches apart when
  the game does (the "Water" filter).
- **Skill-up forecast**: how many catches until the next skill point or rank cap.
- **Other game versions** (Classic, Anniversary, Season of Discovery): the map IDs differ, so the catch database
  would need a seed per game version and `WOW_PROJECT_ID` in its records; addon messages in custom channels are
  disabled there.
