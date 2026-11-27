# Technical debt

Known issues that are not fixed yet, with the reason they matter and a suggested direction. Each item says where
it was found and how serious it is. Remove an item when it is fixed (with a test), or move it to the spec of the
feature that takes it on.

Severity: **high** loses data or cuts off honest players; **medium** wrong state or wasted traffic; **low**
cleanup, no wrong behaviour.

## Fix batches

The open items grouped into fixes that can be taken in one go (one spec or one patch each, `/speckit-specify` with
the batch as its description). Each batch says where it is built, what it closes and what the game still has to
show. Batches 3 and 4 were fixed by spec 009, batch 1 by spec 010, batches 2 and 6 with the pole item of batch 5 by
spec 011, and batches 5, 7, 8, 9 and 10 by spec 012, on `002-shared-db` (release 1.2.0); batches 11 and 12 by spec
015 (release 1.3.0). No batch is open.

## Open items

- **Escape closes the addon's menu and the window behind it at once** (low, spec 029 review). The addon's own menu
  (`ns.OpenMenu`, `UI/Widgets.lua`) is in `UISpecialFrames`, and the game hides every shown frame of that list on one
  Escape, the statistics window or the Settings panel included; the game's menus took the first Escape for
  themselves. Not fixable through the game's `RegisterGameMenuEscHandler`: it writes the handler into the game's own
  table, which taints every later Escape (the World handler's protected `ClearTarget`). Catching Escape on the menu
  needs `SetPropagateKeyboardInput`, which addon code may not call in combat. Direction: a check in game whether a
  keyboard-enabled menu that hides on ESCAPE and leaves propagation on (set once, out of combat) is enough.
- **A block recorded before the saved variables load keeps the saved entry's stack** (low, spec 029 review).
  `ns.RecordEntry` (`Core/Core.lua`) gives a repeated blocked action the latest stack and state line, but
  `AttachErrorLog` merges the entries recorded before `ADDON_LOADED` through `AddError`, which keeps the saved entry
  of the same version and adds only the count. It needs a block of the addon while its files load, where it makes no
  protected call, so no player sees it today. Not changed in 1.7.1: taking the newer stack in `AttachErrorLog` for
  every entry would also change which stack a repeated Lua error keeps (the first one). Direction: the newer stack only
  for the blocked-action contexts (`ADDON_ACTION_FORBIDDEN`, `ADDON_ACTION_BLOCKED`, `INTERFACE_ACTION_BLOCKED`), with
  a test in `tests/core/blocked_test.lua`.

Reviews of the faction rule of Safe for me (spec 026, three `/code-review high` rounds, 2026-11-24): the low items
left; the others were fixed with tests or ruled out (no contested map lies under a faction zone in the game's UiMap
data; the faction is known before the world loads).

- **The faction tests restore their state only at the end of their block** (low, test hygiene).
  `tests/catalog/best_places_test.lua` (the spec 026 block: `GameData.ZoneFactions[3010]`/`[3009]`, the test maps
  3991 and 3992, `player_faction`) and `tests/ui/best_tab_test.lua` (`ZoneFactions[3301]`/`[3302]`,
  `ZoneLevels[3301]`) put the tables back in their last test, so one failing assertion leaves them set and the later
  tests of the file fail for no reason of their own. Direction: restore in each test (a small `with(state, fn)`
  helper in `tests/wow.lua`).
- **A hostile zone without a level range would show no red Level** (low, guarded). `UI/BestPlacesTab.lua` colours
  the Level cell only for a zone with levels; `BestPlaces.Unsafe` is true for a hostile zone either way. Today
  `tests/gamedata/shape_test.lua` requires a `ZoneLevels` row for every `ZoneFactions` entry, so it cannot happen;
  a new faction zone must keep that rule (or the cell shows a red mark without levels).

Reviews of the channel number fix (spec 022, five `/code-review high` rounds and an independent review, 2026-11-22):
the low items left, none seen in game.

- **The hidden channel's number as a secret value** (low, the code of 1.3.0). `NumberOf` in `Exchange/Channel.lua`
  compares what `GetChannelName` returns without `ns.IsSecret`; it serves `Channel.GetNumber` (a channel send), the
  join's check and the `/reload` scan. If a chat lockdown ever hides that number, the comparison raises an error;
  returning nil instead makes the join's check lock all six names. Not known whether the game hides it. A fix needs
  "unknown" apart from "not in the channel" in those three callers.
- **The chat edit box after a number swap** (low, seen in game 2026-11-22). The edit box keeps its channel as a
  number (its `channelTarget` attribute), so after the addon's swap a box left on General's old number opened
  `[6. OneKeyFishingShare]`, and a line typed there goes to the hidden channel, where the addon's filters hide it
  from the sender. It happens only when the player wrote to General on its wrong number just before the swap; a
  drag in Chat Settings > Channels does the same. **Not fixed on purpose**: moving the box to the other number means
  the addon writes `SetAttribute("channelTarget", ...)` on Blizzard's edit box, and the box passes that value to
  `C_ChatInfo.SendChatMessage` (`HasRestrictions`, `SecretArguments = "AllowedWhenUntainted"` in the client's API
  documentation): the tainted value could make the player's own chat fail in a chat lockdown, a worse fault than
  this one. The player opens the right channel with `/1`.
- **A channel of the game that is not seen as new** (low). `FixOrder` takes a channel for known when its name or its
  number was listed at any look since the hidden channel's join (kept on purpose: a look that misses a channel must
  not make it new). So a channel of the game that takes a number another channel left, or one that left and came
  back behind the hidden channel (only when its old number was taken meanwhile), stays there until the next join of
  the hidden channel; "Chat Defaults" puts it back.
- **General kept behind a free lower number on purpose** (low, spec 022 FR-005): each new join of the hidden channel
  takes that lower number and puts General before it; a broken order cannot be told from it.

Review of the window fixes (`/code-review high`, 2026-11-18): the low items left.

- **The statistics window's fallback has no background** (low, found by review, not seen in game). Without
  `BasicFrameTemplateWithInset` (`UI/StatsFrame.lua`, `Create`) the window is a `BackdropTemplate` frame that never
  calls `SetBackdrop`, so its text, tabs and close button float over the world; the copy window's fallback sets
  one. Forever has the template (both windows use it in game), so no player sees this today. Direction: the same
  backdrop as the copy window, shared through `ns.SetupWindow` or a helper next to it; extend
  `windows_fallback_test.lua`.
Review of the Auctionator prices (spec 019, `/code-review high`, three rounds and an independent tester,
2026-11-18): the low items left.

- **Repeated price lookups while Auctionator is in use** (low, found by review). `Prices.FormatValue` calls
  `Prices.Get` and then `GetAuction` again (two `pcall`s into Auctionator per row); `StatsFrame.Refresh` runs
  `Prices.CountSources` after `Stats.GetValue` has read the same items; `Prices.Describe` walks the catches a second
  time for the oldest age. Each lookup is a table read in Auctionator, and a few hundred catches redraw once a
  second at most, so nothing is slow today. Direction: a `Prices.Get` that also returns `fewLots`, and one pass that
  gives the counts with the oldest age.
- **Items not loaded yet count as "without a price"** (low, found by review). Right after a login an item the
  client has not loaded counts as sellable with no vendor price, so the settings page's counts and the statistics
  line's number can be a little high until the item arrives (the statistics window redraws on a caught item's info,
  the settings page only when shown again or on `PRICES_CHANGED`). Direction: count such items apart, or redraw the
  page on `GET_ITEM_INFO_RECEIVED` of a catch.
- **"Auctionator is not installed" for an Auctionator without the update notice** (low, found by review). An
  Auctionator build whose `API.v1` lacks `RegisterForDBUpdate` counts as absent (decision 19), and the settings page
  then says it is not installed; only `/okf debug` names the missing function. The Auctionator of WoW Forever has
  both. Direction: a third note, "This version of Auctionator is not supported."
- **The "Auction prices" page does not follow new catches while it is shown** (low, found by review). Its counts
  redraw on showing, on `PRICES_CHANGED` and on the two switches, not on `Stats` changes; a catch or a statistics
  reset while the page stays open leaves the numbers one step behind until it is shown again. Direction: redraw on
  the window tick, or on the `Stats` version.
- **An empty strip under the statistics window's buttons** (low, found by review). The window works out whether the
  scan button wraps to a row of its own once, at creation; with a translation where it wraps, the window keeps that
  row while the button is hidden for Auctionator. Direction: lay the bottom row out again when the button is shown
  or hidden.
- **"Use scanned auction prices for catch value" also switches Auctionator's prices off** (low, found by review).
  The label predates spec 019; turned off, every value is the vendor price, whichever the source. Direction: a
  label such as "Use auction prices for catch value", with its translations.
- **The next-rank line keeps two lines whenever the advice is shown** (low, found by review). The statistics window
  gives the values line room for two lines while it counts the catches without an Auctionator price, so the
  next-rank line is cut to two lines even when the values line fits on one (a short translation). Direction: follow
  `FontString:GetNumLines()` of the values line, once the game shows it is right after `SetText`.
- **Small repetitions in the scan entries and the scan time** (low, found by review). "No scan while Auctionator is
  in use" is asked in `Auction.CanScan` / `WhyNot`, `ns.UpdateScanButton` and the minimap menu; the last scan's
  date format is written in `UI/Settings.lua` and `UI/StatsFrame.lua`. Direction: one helper for each.

## History

Every review of the shared catch database was closed with tests the same or the next day; the details are in the
commit history of `002-shared-db` (commits "Fix ..." between 2026-10-29 and 2026-10-31).

- 2026-10-29, the local catch database: thirteen items fixed; the forged-record part moved to the design and was
  closed by the public channel's version chain.
- 2026-10-30, the catch exchange (three independent reviews): four high and six medium items fixed; the flood of
  message parts was closed by the public channel.
- 2026-10-31, the public channel (three review-and-fix cycles): every blocker, high and medium finding fixed.
- 2026-10-31, the low items of all reviews: the real ones fixed (channel, exchange and harvest), the rest recorded
  as accepted limits in `specs/004-public-channel-sync` (spec edge cases, data-model.md) or left as style.
- 2026-10-31, a review of the whole branch against `develop` (five areas): one high, two medium and six low items,
  recorded as batches A to E. SHA-256, the codec, the merges and the session states held up. Batch A (item IDs
  from the loot link) and batch B (the pool part of a cell must fit the cell) were fixed the same day, and batch C
  (each of the addon's own channel leaves owes one `YOU_LEFT` of its name, used up when it comes) after them; batch D
  (a remembered peer's new tag replaces its old one in `byTag`, so the table stays within the peer bound) next.
- 2026-10-31, a triage of the open items: kept only the three confirmed in play. Dropped as cases that do not come
  up: a nil player count no caller passes, the "Only mine" guard that holds today, the repeated ready rule, the
  spot cache (a few hundred entries) and the pin rule changing mid-session; the pool-data scan (unmeasured; the
  step time is checked in game by V28 and V39); and the channel's notice-order cases of the batch C reviews (the
  order is V41, the delays are milliseconds, and nobody joins a fallback name or gets `YOU_CHANGED` by hand).
- 2026-11-01, batch E (the catalog): a `CatalogTab.Show` while the index is still building waits for it and
  `Tick` makes the choice once it is ready; the map pin's answers show with catch notifications off.
- 2026-11-06, spec 008 (architecture alignment), three review-and-fix rounds of the working tree. Fixed with tests:
  - the login check of the own record follows `CatchDB.OwnRecord`;
  - the indicator redraws on a skill change;
  - the catch database's range constants stay literals, held equal to the ranks by a test;
  - the CVars of fishing mode come from one table;
  - the GameData check finds calls, also without brackets;
  - the cave fallback of the map pin uses only the point's own map.

  Also cleaned: dead locals, a dead branch, a dead stub, stale names in docs and comments. Two low items stay
  above. Dropped as cases that do not come up:
  - a fifth Fishing rank (Forever has none above 300);
  - a record whose `id` differs from its key;
  - an own record damaged during a session;
  - the per-row pin lookups of a spot list (cached with the rows);
  - the lure `order` field, held 1..n by the shape test.
- 2026-11-07, spec 009: batches 3 and 4 fixed with tests (the map pin no longer opens the map; no equip call in
  the combat lockdown; the attack line; the combat state handler compares the number the driver sends); R14 and
  V45 confirmed in game the same day.
- 2026-11-07, spec 010: batch 1 and "1 catches" fixed with tests (names as the game gives them, the public channel
  off, the proof step budget, the hidden "No player named" line as the offline signal, the singular texts; the
  spike trimmed); V11 (friends list, other realm), V12 and V26 wait for the game.
- 2026-11-08, spec 011: batch 2, batch 6 and the pole item of batch 5 fixed with tests (a cave's continent map
  becomes the zone under the point; the subzone found by its name among the game's area names, walked over frames;
  the loot source of a catch is unknown, no pool part written; a secret name in a fight counts as missing and the
  skill check waits for the fight's end; the best pole within the Fishing skill). The `/run` checks before the code
  confirmed the zone under the cave and the area names (`docs/forever-api.md`).
- 2026-11-12, spec 012: every open item fixed with tests (batch 10: the bobber's secret GUID in an instance answers
  "unknown", no error and no "No bobber", a secret loot source is skipped; batch 9: the no-bundled-data hint drops
  "only your own catches" with another player's record, "Exchange: 1 player"; batch 5: a refused lure comes back
  after a Fishing skill-up; batch 7: the minimap tooltip carries its colours as codes in the text; batch 8: the
  private-table check parses the file). The dungeon is re-checked in game.
- 2026-11-16, spec 015: batches 11 and 12 closed. Fixed with tests: the "Sound effects" rows the player changed by
  hand kept across a `/reload`; the exchange's activity counts per client through `Node:ClientKey`, the one
  definition of the same client, and a relogged client's other addresses take its new tag at once. Dropped: "A crash
  leaves the game's sound settings to the character who fished" (medium), found wrong by review 4: the game writes
  saved variables only at a logout, a `/reload` or the exit, never at a crash, and the logout restores the CVars
  before that write, so no record of a crash reaches the disk on any character (an account-wide record was built and
  reverted). The export's CVar table shows none of the rows is per character (auto loot and soft target per
  account, the sound rows per installation).
- 2026-11-18, the addon's windows (checked in game the same day, before the fix and after it). Fixed with tests:
  the debug report window's close button did nothing in a fight (the template's script goes through
  `HideUIPanel`, which refuses addon code in combat; both windows now hide by their own script,
  `ns.SetupWindow`); the statistics window and the debug window drew through each other (both are top-level and
  raised when shown); the minimap button's menu showed "Interface action failed because of an AddOn" in a fight
  (its title element sets a secure value; in combat the menu has no title), found by the stack of
  `DisplayInterfaceActionBlockedMessage` (the steps are in `docs/forever-api.md`, "Finding what the game
  blocked"). Not explained: before the fix the statistics window's close button did close it in a fight.
