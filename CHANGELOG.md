# Changelog

All notable changes to OneKeyFishing are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [1.7.1] - 2026-11-27

### Fixed

- A raid marker could not be set from a unit's menu in a fight ("Interface action failed because of an AddOn" and the
  offer to disable OneKeyFishing) once the addon's minimap menu or a filter menu had been opened first in the session.
  The game's menus share their rows with every menu of the game, and rows first created for an addon's menu stay
  marked as the addon's. The addon's menus (the minimap button, the filters, the language, the Import and export
  choice) are now its own and no longer touch the game's menus.

### Changed

- `/okf debug` lists the actions the game blocked because of the addon ("Errors and blocked actions"), with where
  they came from, whether you were in a fight and the addon's last menu. A bug report then shows the cause without
  any preparation.

## [1.7.0] - 2026-11-26

### Added

- **Import and export** of catch data: a new settings page (also `/okf share export` and `/okf share import`)
  turns your catch data into one string to copy, and reads a string another player pasted in. Data then travels
  without both players being online, across the factions too. Every imported record passes the exchange's checks, a
  damaged or cut string is refused whole, and imported data counts even with the shared catch database off.

### Changed

- The bundled catch database now knows 1250 fishing places (121 new) and 30 more items, from the catches players
  shared on both factions of the PvE and PvP game modes.
- Best places: **Safe for me** also hides the zones and capitals of the other faction, on every game mode (an
  Alliance character sees Alliance and contested zones, a Horde character Horde and contested zones). With Safe for
  me off they are listed with their level in red.

### Fixed

- The minimap button's menu: **Statistics** opens the Statistics tab, like **Catalog** and **Best places** open
  theirs (it opened the tab used last). The settings' **Open statistics** button does the same, and no longer closes
  an open window.

## [1.6.1] - 2026-11-24

### Changed

- The bundled catch database now knows 1130 fishing places (109 new) and 18 more items, from the catches players
  shared on both factions of the PvE and PvP game modes.
- The manual says who the public channel reaches: the addon users of your own faction. The game keeps the channel
  and whispers inside a faction; catches cross to the other faction through Battle.net friends and the data
  bundled with each release.

## [1.6.0] - 2026-11-23

### Added

- **Best places**, a fourth tab of the statistics window: the ten zones that bring the most gold per hour of
  fishing for your skill, with their level (red when above yours), gold per hour and catches. Filters: Skill, Source,
  Safe for me (hides zones more than 3 levels above you), Water or Camp bonus, Kinds (hidden kinds do not count in
  the gold) and Continent. Each zone opens into its subzones and spots with map pins; hovering a place lists the
  items that bring its gold. `/okf best` opens it.
- The minimap button's menu has **Catalog** and **Best places** next to **Statistics**.

### Changed

- The catch catalog lists each subzone of a zone once: a zone opens into its subzones (their chance and catches
  summed over their spots, with a map pin on the best one), a subzone into its spots. Spots without a known subzone
  are grouped under "No subzone".
- The bundled catch database now knows 1021 fishing places (34 new) and 5 more items, from the catches players
  shared.

## [1.5.2] - 2026-11-23

### Added

- Two new kinds in the catch lists: **Trophies**, the 36 weighed fish such as "10 Pound Mud Snapper" or "52 Pound
  Redgill", and **Quest**, the items handed in for a quest or the Stranglethorn Fishing Extravaganza (Nat Pagle's
  fish, Speckled Tastyfish, Electropeller, Gaffer Jack). The kinds now come in the order Fish, Containers, Trophies,
  Potions & drinks, Reagents & herbs, Quest, Other. A kind you hid before stays hidden; the two new ones are shown,
  also when their items used to sit under a kind you hid.
- A trophy collection in the catch catalog: the Trophies header shows how many of the 36 your account has caught, and
  each trophy you caught, on any character, has a check mark on its icon.
- The first catch of a trophy on your account gives its own notification, "New trophy: ... (13/36)", also with catch
  notifications off, and the rare loot sound when the fishing sounds play (fishing mode on, no fight).

### Changed

- The bundled catch database now knows 987 fishing places (40 new) and 8 more items, from the catches players
  shared.

## [1.5.1] - 2026-11-22

### Changed

- The bundled catch database now knows 947 fishing places (122 new) and 20 more items, from the catches players
  shared.

### Fixed

- The addon's hidden chat channel could take chat channel number 1 when it was joined while you were not in
  General (a late General after a login or a `/reload`, a `/leave`): General then came back as the last channel and
  stayed there until "Chat Defaults" was pressed. The addon now waits for General before it joins, up to two
  minutes, and when a channel of the game still ends up behind the hidden channel, the two trade places by
  themselves; General left behind it by an earlier version is put back the same way. Your own channels and an order
  you set by hand in Chat Settings afterwards are not touched, except that General does not stay behind the hidden
  channel when that channel is joined anew. `/okf debug` now shows the hidden channel's chat number.

## [1.5.0] - 2026-11-20

### Added

- Catches made with a camp bonus, the fishing buff of a Fishing Rack or a Fishing Hut placed by a campfire, are
  recorded apart from the others and shared with the rest of your catch data. A cast counts for the bonus when the
  buff was up both when it started and when it ended.
- Bonus catches (such as the Bloated fish, which both camp features give) are marked with the camp feature's icon in
  "What can be caught here" and in the catch catalog, and show their chance among the catches made with the bonus.
  Hover the row for the bonus's name, what to do to get it and its chance "with the bonus"; item tooltips elsewhere
  add the explanation under "Caught in:".
- A **Camp bonus** filter in both tabs, in the place of the Water filter, once a catch with a camp bonus is known:
  **All catches**, **No camp bonus**, **Bonus catches only**, **Fishing Rack**, **Fishing Hut**. The button names
  the chosen value ("Camp bonus: All", "Camp bonus: Rack"). **Bonus catches only** lists just the bonus catches,
  with the same numbers as **All catches**; **No camp bonus** leaves them out.
- A notice 5 minutes before a camp bonus ends and one when it has ended, in fishing mode, with the setting "Warn when
  a camp bonus is ending" (on by default).
- The statistics show "Casts with a camp bonus" and "Bonus catches" (casts with a camp bonus that brought an extra
  item: a Bloated fish or a second item in the loot, quest fish aside) once you fished with a camp bonus.
- Camper's Lure, from a placed Fishing Rack, is applied by the fishing key like the other lures (after the +75 lures,
  before the +50 ones; it needs Fishing 50).
- `/okf debug` has a section "Camp bonus", and the catch database section shows the current place's bonus counts.

### Changed

- The **Skill** filter of "What can be caught here" and of the catch catalog shows the catches of the chosen skill
  range and of every lower one, since more skill never undoes what less skill catches: a place where nobody has
  fished with your skill yet still lists what was caught there with less. Its values read **Up to 74**, **Up to
  149**, **Up to 224**, **Up to 299** and **All (300+)**, your own range marked "(yours)"; the button reads "Skill:
  Up to 224" or "Skill: All", and its tooltip says what the list holds. "All skill levels" is now **All (300+)**,
  and the hint to try it is gone.
- The filter buttons of both tabs write their value the same way in every language, with a capital letter after the
  colon ("Kinds: All", "Skill: All", "Camp bonus: All").
- The share of casts that catch nothing ("Nothing caught") comes from the chosen skill range alone, because less
  skill misses more; below 50 casts in that range it says "little data".
- Small chances are shown with a fraction ("3.4%", "0.47%", "<0.01%") instead of "0%"; from 10% on they stay whole
  numbers.
- The filter buttons of "What can be caught here" and of the catch catalog stand in two rows: Skill and Source, then
  Water or Camp bonus, Kinds and (in the catalog) Sort. The Kinds button of "What can be caught here" has left the
  top right corner.
- The list of "What can be caught here" scrolls and shows every item (no more "and N more"); its hints and the
  line about the shared catch database are now at the top, above the catch counts.
- The catch catalog's status line ("Counting the catch...", "No item matches the search.") stands under the search
  box.
- "Per catch" drops the ".0" of whole numbers: "1" instead of "1.0", "1.3" otherwise.
- The bundled catch database now knows 825 fishing places (300 new) and 44 more items, from the catches players
  shared, and holds the first catches made with a camp bonus.

### Fixed

- The addon's coloured lines in item tooltips ("Caught in:", the fishing gear lines, the grey auction price with
  "(few lots)") keep their colour when another addon or the game resets the tooltip's line colours; before, they
  could turn white.
- Four Bloated fish (Bloated Mackerel, Bloated Albacore, Bloated Bristle Whisker Catfish, Bloated Whitescale Salmon)
  are listed under the kind "Containers" like the other Bloated fish, not under "Other".

## [1.4.0] - 2026-11-18

### Added

- With the Auctionator addon installed, the catch values use its auction prices: scan with Auctionator as you do
  anyway, and the statistics, the catalog and the catch values follow, without a second scan. Your own stored prices
  fill in for items Auctionator has not seen, and a catch is never valued below its vendor price. The addon's own
  scan buttons are hidden while Auctionator's prices are in use, and `/okf scan` says so.
- A settings page "Auction prices": the switch "Use scanned auction prices for catch value" moved there from the
  main page; under it "Take prices from Auctionator" (on by default; turn it off to go back to the addon's own
  scan); which source is in use, and how many of your catches have a price from Auctionator, from the addon's scan,
  from a vendor only, or none.
- The statistics window's line about the values names Auctionator as the source and says how many of your catches
  it has no price for.
- `/okf debug` has a section "Auction prices".

### Fixed

- The debug report window closes by its close button in a fight; before, the button did nothing until the fight
  ended.
- Opening the minimap button's menu in a fight no longer shows the game's "Interface action failed because of an
  AddOn" line; in a fight the menu has no title.
- The statistics window and the debug report window no longer show through each other when they overlap, and a
  click on one brings it to the front.

## [1.3.2] - 2026-11-18

### Changed

- **The auction scan** covers every item of the catch catalog, not only your own catches, so the catalog and "What
  can be caught here" show auction prices for fish you never caught. Your own catches are scanned first, then the
  addon's bundled data, then items known from other players. The first scan of a visit takes about a minute.
- The scan is several times faster right after a login and no longer loses prices: it waits for the game's item
  data before asking, sends the next request as soon as the auction house takes one, and loads further pages only
  while the price is still open. Bound items, which cannot be sold, are not searched.
- A press within 15 minutes of a scan searches only what was not scanned yet (a scan cut short by closing the
  window goes on where it stopped); when everything is fresh, the press scans everything again.
- When the auction house stops answering (it then shows nothing until you log out and in), the scan stops within
  10 seconds, keeps the prices found and says so once in chat; until it answers again the button above the auction
  window and the minimap menu say "Auction house not answering", the other scan buttons say why on hover. The item
  it was waiting for is not searched again until the next version of the addon; when it was an item known only
  from other players, none of those are.

- The item tooltips of the statistics window's lists show the addon's auction price as "Auction price
  (OneKeyFishing)", so it is told apart from an auction addon's line (which shows the cheapest auction, not the
  average the addon uses).
- The bundled catch database now knows 446 fishing places (139 new) and 31 more items, from the catches players
  shared.

### Removed

- The **Scan auction prices** button of the settings page: opening the settings closes the auction window, so it
  could never be pressed. Use the button above the auction window, the statistics window's or the minimap menu.

### Fixed

- Auction prices of items that do not stack (the "Pound" fish, for example) were divided by the number of equal
  auctions, so they came out far too low and the vendor price was used instead. The saved auction prices are
  forgotten once with this update; the next scan brings them back.

## [1.3.1] - 2026-11-17

### Added

- **Sort** in the catch catalog: by name, by price (the dearest first, with the price of each item in its row;
  "No price" for items without one) or by chance (the chance in the item's best zone). The order applies inside each
  kind and is kept between sessions. The catalog's buttons are now in three rows: the search; Skill, Source and Water;
  Sort and Kinds.

### Changed

- The bundled catch database now knows 307 fishing places (235 new) and 29 more items, from the catches players
  shared.
- `/okf debug` has a section "Seed items without a kind" (empty in a release; it helps prepare the bundled data).

## [1.3.0] - 2026-11-17

### Added

- "Sound effects" settings page (also `/okf sound`), every option off until you turn it on:
  - **Play fishing sounds**: a bell when you cast, a sound when you hook, and a notification when the loot
    holds an Uncommon or better item; a "Turn fishing sounds on / off" entry in the minimap button's menu too.
  - **Volume** of these sounds, 0 to 100 % in steps of 10, without touching the game's volumes.
  - **Fishing sound in the background**: the game's "Sound in Background" for the time of fishing mode.
  - **Splash focus while fishing**: music, ambience and dialog silenced and effects raised, so the splash stands out.
  - In a fight the sounds are silent and the focus is lifted; everything the page changes comes back when fishing
    mode ends.
- Catch kinds in **What can be caught here** and the **catch catalog**: the items are grouped under Fish,
  Containers, Potions & drinks, Reagents & herbs and Other, and the **Kinds** button hides the kinds you do not want
  to see. The choice is shared by both tabs and kept between sessions; hiding a kind does not change the numbers of
  the others.
- The public channel is back: addon users who share no guild, group or friends list exchange catch data through a
  hidden chat channel again, now that WoW Forever carries addon data in chat channels again. **Use the public
  channel** on the Shared database page turns it off; a popup says so once. If the game stops carrying the data
  again, the addon stops using the channel until the next login.

### Changed

- Fishing mode puts a game setting back only while it still holds the addon's value: a setting you changed
  yourself while fishing (in the game's options) keeps your value.
- The catch database that comes with the addon holds 72 places (26 before), from the catches shared so far.

### Fixed

- A partner who logs in again no longer counts twice in the exchange's player count for an hour.

## [1.2.0] - 2026-11-12

### Added

- "What can be caught here", a second tab in the statistics window: the items of the spot you stand at, with
  their chance, pieces per catch and price, the number of catches behind them and the share of casts that catch
  nothing. Few catches at a spot: the whole map; few on the map too: "Little data". Filters for the skill range
  and for the source (all, or only your own catches). Catches in a cave count for the zone around it.
- A catch database bundled with every release, so the tab has numbers from the first login. Your own catches
  are recorded for it per map, grid cell and skill range, under a random ID (no names; per cell only the average
  spot you fished from and the game's number of the subzone, so spots get a name in every client language).
- Shared catch database: catch counts travel under a random ID and in the background between addon users in your
  guild, group and friends list (Battle.net friends playing WoW Forever included), and what they got from others
  reaches you too. No character names are sent or saved (the players you exchange with directly can tell which
  ID is yours); it pauses in combat, in instances and on loading screens, stays within 50 KB per hour and never
  shows anything in chat. "What can be caught here" counts it under "All" and says how many players the numbers
  come from ("60 catches from 3 players"), with a quiet status line at the bottom.
- "Shared database" settings page: "Use the shared catch database" turns the exchange off (nothing sent or received;
  data received earlier is kept but not counted), with a short text on what is shared and the state. A popup at the
  first login says what is shared and where to turn it off.
- Protections for data from strangers: where five or more players reported a spot, none counts for more than a fifth
  of it; an item that is neither in the bundled data nor in your own catches shows once three players reported it on
  the map; each player's data carries a proof that only its owner can extend, so nobody can make up a newer version
  of it; a version holds at most as much fishing as its steps allow; the bundled data can block a contributor.
  Data that does not add up is refused, and its sender is ignored until the end of the session.
- Items your game client does not know yet show as "Unknown item" with their item ID in the tooltip, and get their
  name once the game knows them.
- "Catch catalog", a third tab in the statistics window: every item of the catch database with a search by its name
  in your client's language, the zones it is caught in with the chance there, and each zone's spots named after their
  subzone. A spot's pin button sets the game's own map pin there with the game's navigation, and asks first when you
  already have a pin of your own. `/okf catalog [name or item link]` opens it, and a click on an item of "What can be
  caught here" opens that item.
- Item tooltips show "Caught in:" with the item's three best zones and its chance; in fishing mode the minimap
  tooltip shows the three most likely catches of the place. "Show catch chances in tooltips" turns both off.
- `/okf share` shows the state of the shared catch database; `/okf debug` has sections for the catch database, the
  exchange and the catalog.
- `/okf debug` ends with the addon's recent errors ("Errors"): where each happened, how often and when, with a few
  lines of the code that failed. Errors still show as before in the game's error window or BugSack.

### Changed

- A lure your Fishing skill is too low for is no longer offered; it is used once your skill is high enough.
- Auction prices: the average of the cheapest fifth of the pieces on sale instead of the cheapest lot, so one
  lot far off the market no longer decides the price. With fewer than 5 pieces or fewer than 3 different
  offers (prices) on sale the price is marked "(few lots)" and the catch value uses the vendor price.
- Slash commands and the `/okf` help are always in English, whatever the interface language.
- When one part of the addon fails, the others keep working: an error in one part no longer stops the others from
  handling the same moment (a failure in the statistics no longer costs the catch database a catch).

### Fixed

- Items your game client does not know yet are counted in the statistics and in your catch data, and fished
  containers of that kind are remembered like the others, so the key opens them and the auction scan includes them.
- After setting a map pin, the world map no longer fails in a fight ("Interface action failed because of an
  AddOn"): the pin no longer opens the map, and its message says to open it.
- Leaving fishing mode in a fight no longer raises "Interface action failed"; the gear comes back when the fight
  ends.
- In a fight the fishing key now pauses and says so, instead of trying to cast, and the indicator shows "Paused in
  combat". The pause also covers the hook: a bobber still out when a fight starts can no longer be hooked until it
  ends.
- An attack in fishing mode (with "Leave fishing mode when attacked" on) now says that the mode ends after the
  fight.
- No more Lua error in dungeon fights ("attempt to compare ... a secret string value") from the next Fishing rank
  advice; its "can learn" notice now waits for the end of a fight.
- Fishing mode no longer picks a pole your Fishing skill is too low for; it takes the best one you can use.
- The manual no longer promises a navigation arrow on screen for the next-rank pin.
- One catch reads "1 catch" instead of "1 catches" in the zone list of the statistics window and the session line
  of the minimap tooltip.
- No more Lua error window while fishing in a dungeon ("attempt to perform string conversion on a secret string
  value"); there the indicator shows "Hook!" while the bobber is out, since the game hides which object you face.
- The minimap button's tooltip no longer loses its colours (every line white) now and then.

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
