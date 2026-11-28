# In-game checklists

The addon cannot be run outside the game, so every feature has a checklist the author walks through in game.
Claude writes the code and the checklist; the author ticks the boxes and reports back; a behaviour counts as
verified only after that (constitution, Principle IV).

## The checklists

| Checklist | Feature | Spec | Needs |
|---|---|---|---|
| [fishing-mode.md](fishing-mode.md) | the 1.0.0 core: fishing mode, the key, gear, lures, containers, statistics, auction prices, the minimap button, settings | none (built before Spec Kit) | one character with Fishing |
| [interface-language.md](interface-language.md) | the interface languages and the language setting | `specs/001-interface-language` | one client |
| [spike.md](spike.md) | the game facts the shared catch database was built on (`/okf spike`), run once before the four below | 002 to 006, their `verification.md` (006: the error log, V42) | a second player, several waters, the auction house |
| [catch-database.md](catch-database.md) | "What can be caught here", the bundled data, robust prices | `specs/002-local-catch-db` | one character, a real seed |
| [catch-exchange.md](catch-exchange.md) | the exchange with guild, group and friends | `specs/003-guild-group-sync` | a second player (and a third) |
| [public-channel.md](public-channel.md) | the hidden public channel and the protections; its chat channel number (step 12) | `specs/004-public-channel-sync`, `specs/022-channel-order` | three accounts sharing nothing |
| [catch-catalog.md](catch-catalog.md) | the catalog tab, map pins, subzones, tooltips | `specs/005-catch-catalog` | two client languages, a fresh item cache |
| [sounds.md](sounds.md) | the "Sound effects" page: the fishing sounds, their volume, background sound, splash focus | `specs/013-fishing-sounds` | one character, a mob for a fight, a second window |
| [catch-filters.md](catch-filters.md) | the item kinds of "What can be caught here" and the catalog: the kind headers, the Kinds menu, the remembered choice | `specs/014-catch-filters` | one character, the bundled data, a second interface language |
| [catalog-sort.md](catalog-sort.md) | the catalog's Sort button: by name, price and chance, the right column, the remembered order, the three rows of buttons | `specs/017-catalog-sort` | one character, the bundled data, an auction scan, a second character, French |
| [auction-scan.md](auction-scan.md) | the rebuilt auction scan: its pace, the catalog's items, fresh prices, the auction house that does not answer, the scan buttons | `specs/018-auction-scan`, its `verification.md` (V54 to V57) | one character at an auction house, a character with few catches, a grey item |
| [auctionator-prices.md](auctionator-prices.md) | Auctionator as the price source: catch values from its prices, the hidden scan entries, the "Auction prices" settings page, the statistics line, the debug section | `specs/019-auctionator-prices`, its `verification.md` (V59) | Auctionator 347 or later, one character at an auction house, a character with Auctionator disabled |
| [camp-buffs.md](camp-buffs.md) | catches with a camp bonus (the buff of a Fishing Rack or a Fishing Hut): the recording, the bonus tag and its chance, the "Camp bonus" filter with "Bonus catches only" and the two rows of buttons, the scrolling list of "What can be caught here", the percentages, the notices, the statistics rows and the bonus catches under the Hut, the colour of the tooltip lines, Camper's Lure, the exchange | `specs/020-camp-buffs`, its `verification.md` (V60 to V69) | Fishing 140 and a Fishing Rack, a campfire, a party member, a mob, French and German, a second player on the new version and one on 1.4.0, a character never buffed, Fishing 300 and a Fishing Hut |
| [skill-filter.md](skill-filter.md) | the cumulative Skill filter of both catch pages: the lists up to the chosen range, the miss rate of that range alone, the "Up to N" menu with "(yours)", the button's tooltip, the texts' width in all ten languages | `specs/021-cumulative-skill-filter` | Fishing 75 to 299, a place with only lower-skill data, an instance or a cave, a character without Fishing, every interface language |
| [item-kinds.md](item-kinds.md) | the item kinds Trophies and Quest and their order, the trophy collection in the catalog (count and check mark), the notice and the rare sound for a new trophy | `specs/023-item-kinds` | one character with Fishing, a water with weighed fish, the fishing sounds on |
| [best-places.md](best-places.md) | the best places tab: the top zones by gold per hour, Safe for me, Continent, the subzones and spots with pins, the tooltip; the catalog's three levels; the minimap menu entries and `/okf best`; V75, V76; Safe for me and the factions (V77) | `specs/024-best-places`, its `verification.md` (V75, V76); `specs/026-safe-faction`, its `verification.md` (V77) | one character with Fishing at level 30 or below, the bundled data, auction prices; a Horde and an Alliance character |
| [import-export.md](import-export.md) | the "Import and export" settings page: export, import on another account, sharing off, a large string, damaged strings, the commands | `specs/027-import-export`, its `verification.md` (V78 to V80) | two accounts, one with other players' data |
| [blocked-actions.md](blocked-actions.md) | the addon's own menus (the minimap button, the filters, the language, the Import and export choice) and a raid marker in a fight after them; the blocked actions in `/okf debug` | `specs/029-blocked-actions`, its `verification.md` (V81, V82) | one character, a mob, Auctionator disabled |
| [luremaster.md](luremaster.md) | the Luremaster spike before spec 028: the talent's rank calls, the lures' enchant IDs, the loot of four sessions (no lure, a lure, the Hut, the Hut with Camper's Lure) recorded by the throwaway OKFSpike addon | none yet (spec 028 is written on its results; [luremaster-research.md](../luremaster-research.md), section 5) | Luremaster rank 1, Fishing 300, ordinary lures, a Fishing Hut and a campfire, one spot of open water, about 2.5 hours |
| [gear-swap.md](gear-swap.md) | the gear swap that waits for the game's answer: entering and leaving 0.1 s apart both ways, full bags, one free slot, a fight, the exit while the line is out, a `/reload` right after entering | `specs/030-gear-in-flight` (SC-001 to SC-004), its `verification.md` (V83) | one character with a one-handed weapon and an off-hand item, the two-handed Fishing Pole, bags to fill, a mob |

The steps still open after 1.2.0 are listed in [docs/release-plan.md](../release-plan.md).

## How a checklist is built

Every checklist has the same parts, so it can be followed top to bottom:

1. **Header**: the feature, its spec, what the checklist closes (the `VERIFY` ids of the feature's
   `verification.md`, when it has one) and what it needs (characters, accounts, clients, a second player).
2. **Setup**: install the build (`npm run install-addon`, or `npm run link` once), restart the game when a file was
   added to the TOC, log in on the right character.
3. **Steps**, numbered and grouped by screen or action. Each step says what to do, what to expect, and which
   assumption it closes (`V12`, `FR-007`). A `[ ]` box is ticked when the step passed; anything that looks wrong is
   noted next to it. `____` is a blank for a value or a report to paste.
4. **Results**: date, client language, build, problems found.

## Reporting back

- Paste the ticked checklist, the notes and every `/okf spike` or `/okf debug` report into the conversation.
- Facts about the game API go into `docs/forever-api.md`; a wrong assumption is fixed in the code with a test, and
  its `VERIFY` marker is removed only after the fix passed in game.
- A step that cannot be run (no second player, no pool nearby) is marked "skipped: why" and stays open.
