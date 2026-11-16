# Roadmap

What is not built yet. Built features are listed in `CHANGELOG.md` (released and `[Unreleased]`); what is left after
1.2.0 is in [release-plan.md](release-plan.md). Nothing here is scheduled: each item gets its own spec before
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

- **Sounds**: a Sounds settings page with the addon's own sound (on catch, on a missed fish), its volume, and the
  game's sound kept while WoW is in the background during fishing. Research and design in
  [sounds-plan.md](sounds-plan.md); spec [013-fishing-sounds](../specs/013-fishing-sounds/spec.md).
- **Shared auction prices**: the catch value without a scan of one's own (the freshest scan wins, prices older
  than 3 days are not shared). Left out of the shared catch database: it waits for the in-game answer to which
  auction house a player uses in WoW Forever (game modes split by faction, no realms), since a peer from another
  house would bring wrong prices.
- **A map pin on the nearest fishing trainer** for Journeyman (spec 001 research R16): needs the trainers' Forever
  map IDs and points, checked in game; until then the minimap's trainer tracking finds them.
- **Fishing pools**: notice and point out nearby pools. The catch database already tells pool catches apart when
  the game does (the "Water" filter).
- **Skill-up forecast**: how many catches until the next skill point or rank cap.

