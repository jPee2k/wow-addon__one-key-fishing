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

## Planned

- **A helper for the Stranglethorn Fishing Extravaganza** (spec 025, after 024): notices before and during the
  contest, the Tastyfish counter, rare fish notices, a settings page, its own tab and minimap menu entry (the
  window's fourth tab and the "Catalog" entry come with spec 024), `/okf event`. Research and the agreed decisions:
  [extravaganza-research.md](extravaganza-research.md), section 11.

The ideas below are not decided.

## Ideas to discuss

- **Problem reports through the catch exchange**: players rarely write bug reports by hand, and the addon cannot send
  anything outside the game, so the shared catch record carries a small report the author's harvest collects.
  - *Auction items that jam the house*: the items of the player's `scanGuard` with the addon version. The harvest
    (`npm run harvest`) prints each item with the number of distinct players who reported it; the author adds one
    reported by several players to `GameData/AuctionUnanswered.lua` before the next release (a person decides, the
    threshold of distinct players keeps one broken or forged record from banning an item, as the catalog's rule
    of 3 players does).
  - *Error log*: the entries of `db.errors` (the `ns.Safe` log: context, message, stack, version), deduplicated by
    their message and place, a count per entry, a cap per record, only entries of recent addon versions. The
    harvest groups them by version and place across players, so a bug shows up with how many players hit it.
  - Open questions for its spec: the size and traffic budget (the record's limits in
    [exchange.md](architecture/exchange.md)); what a stack may hold (addon file paths only, no character or chat
    data); whether reports follow the sharing switch or have their own; how long an entry is kept after it was
    sent; a format version so older clients ignore the field.

- **Shared auction prices**: the catch value without a scan of one's own (the freshest scan wins, prices older
  than 3 days are not shared). Left out of the shared catch database: it waits for the in-game answer to which
  auction house a player uses in WoW Forever (game modes split by faction, no realms), since a peer from another
  house would bring wrong prices.
- **Auctionator searches the catches**: with Auctionator in use, a button that has it search the player's catches
  (its API `CreateShoppingList` or `MultiSearchExact`, auction house open), so their prices fill without its full
  scan. Left out of 1.4.0: its searches take item names, not IDs (the names would come from the client's own item
  data, in the client's language), and the requests are then Auctionator's, outside the addon's guard against an
  unanswered request ([auction-plan.md](history/auction-plan.md), "Rules that follow").
- **Auction prices per game mode**: `db.prices` is one table for the account, so a character of another game mode
  sees the prices of an auction house that is not its own (Auctionator keeps its prices per mode). Waits for the
  same in-game answer ([auction-plan.md](history/auction-plan.md), decision 8).
- **A map pin on the nearest fishing trainer** for Journeyman (spec 001 research R16): needs the trainers' Forever
  map IDs and points, checked in game; until then the minimap's trainer tracking finds them.
- **Fishing pools**: notice and point out nearby pools. The catch database already tells pool catches apart when
  the game does (the "Water" filter).
- **Skill-up forecast**: how many catches until the next skill point or rank cap.
- **Controller support**: fish with a gamepad, the two bindings on its buttons. Other fishing addons for WoW Forever
  offer it (seen on their CurseForge pages, 2026-11-20). To check in game before a spec: whether the game's gamepad
  mode (`GamePadEnable`) lets the addon's two bindings take a pad button; whether the override binding of the fishing
  key and `INTERACTTARGET` work on one ([fishing-mode.md](architecture/fishing-mode.md)); how the indicator, the
  minimap tooltip and the settings name a pad button (`ns.KeyText`). The rule stays: every action is a real button
  press.
- **TradeSkillMaster prices**: TSM as a price source next to Auctionator, for players who use it instead. By the
  rules of spec 019 ([auction-plan.md](history/auction-plan.md)): optional, only through its public API, every call
  in `pcall`, its presence read at runtime, nothing of its data kept, and no auction request of the addon's own
  while its prices are in use. To decide in its spec: whether TSM runs on WoW Forever and what its API gives there;
  which of its prices stands for an item's value (the market value or the lowest buyout); the order of the sources
  when both addons are installed; the settings page's second switch becoming a choice of three.
- **What fished containers hold**: record what players take out of the containers they caught (chests, crates,
  trunks, clams, Bloated fish) and show it in a window of its own: per container, the items with their counts and
  chances. Nobody publishes these contents for WoW Forever, and they decide what a container is worth. The loot
  of an opened container has the source `Item-...`, not the bobber
  ([fishing-investigation.md](fishing-investigation.md), "Checked in game"). To decide in its spec: own data only
  or shared through the catch exchange too; how a container opened later, or one that was not fished, is told
  apart; where the value of a container in the catch lists comes from.

