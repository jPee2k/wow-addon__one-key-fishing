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
| [public-channel.md](public-channel.md) | the hidden public channel and the protections | `specs/004-public-channel-sync` | three accounts sharing nothing |
| [catch-catalog.md](catch-catalog.md) | the catalog tab, map pins, subzones, tooltips | `specs/005-catch-catalog` | two client languages, a fresh item cache |

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
