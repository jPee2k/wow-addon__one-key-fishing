# Research: Interface Language

Decisions taken for the plan, each with the reason and the alternatives that were rejected.

## R1. When the language can be chosen (load order)

- **Decision**: The language is resolved in Core's `ADDON_LOADED` handler, right after the saved variables
  are migrated and filled with defaults, and before any other code looks up a text. No `L["..."]` lookup may
  run while the addon files load. Every current load-time lookup moves to runtime:
  - `Core.lua`: `BINDING_NAME_ONEKEYFISHING_*` are set in `ADDON_LOADED` (the Keybindings panel reads the
    globals when it is opened).
  - `ns.RegisterCommand(name, description, fn)` takes the description as a function returning the text
    (`function() return L["..."] end`), called when the help is printed. Five commands: scan, debug, toggle,
    config, stats. (Superseded later: every command is now declared in `Commands.lua` (`ns.COMMANDS`), and
    the descriptions and the `/okf` help are English on every client, constitution Principle II.)
  - `UI/Settings.lua` `TOGGLES`, `UI/StatsFrame.lua` `ROWS`, `UI/Indicator.lua` `LABELS`, `Skill.lua`
    `RANK_NAMES` / `NEXT_RANK`: built by a function on first use instead of at file load. (User Story 3
    later replaces the `Skill.lua` tables with `GameData/FishingRanks.lua` and runtime sentences, R13, R15;
    the no-load-time-lookup rule still holds.)
- **Rationale**: WoW loads saved variables after all addon files have run, just before `ADDON_LOADED`, so the
  preference does not exist at file load. A text looked up at load time would be stuck in the client
  language. Keys stay literal (`L["text"]`), so the key sync of `npm run check` keeps working.
- **Guard**: `ns.L` records every lookup made before the language is set; a test loads the addon and asserts
  that list is empty, so a new load-time lookup fails `npm test`.
- **Alternatives rejected**: a custom CVar read at load time (persistence of addon-registered CVars is
  unverified on Forever); a load-on-demand child addon (two addons for one setting); proxy objects that
  translate late (every `SetText` and `format` would need to handle them).

## R2. Translation file format and registry

- **Decision**: A new first file `Localization.lua` owns `ns.L`, the registry and the language list. Each
  translation is `Locales/<code>.lua`:

  ```lua
  local _, ns = ...
  ns.AddTranslation("deDE", "Deutsch", function(L)
      L["Cast"] = "Auswerfen"
  end)
  ```

  The function body runs only for the language that is picked, so the other eight cost no memory beyond their
  code. `Locales/enUS.lua` keeps the English list (`L[key] = true`) and registers "English".
- **Rationale**: the native name lives in the translation file, which is the one place allowed to hold
  non-ASCII text; a language without a file simply does not appear in the list (FR-012). Literal
  `L["..."] = "..."` lines keep the existing key check.
- **Alternatives rejected**: `if GetLocale() == ... then` blocks (cannot follow a preference); one big table
  of all languages in one file (unreadable diffs, all languages in memory).

## R3. Resolving the effective language

- **Decision**: `ns.ResolveLanguage(preference, clientLocale)`:
  1. preference is a registered code → that code;
  2. otherwise (`"auto"`, or a code no longer shipped) → `clientLocale` if registered, after mapping the
     client variants of a shipped language (`enGB` → `enUS`, `ptPT` → `ptBR`);
  3. otherwise → `"enUS"`.
  Ukrainian has no client locale, so it can only come from step 1. `ruRU` is not registered and falls to
  English. Lookups go: chosen translation → English key.
- **Rationale**: one pure function, unit-testable without reloading the addon; covers FR-002, FR-004, FR-005,
  FR-007 and the "language removed in a later version" edge case.

## R4. The language control in the settings

- **Decision**: On the main settings page, next to the title: a "Language:" label and a button showing the
  current choice. Clicking it opens a menu (`MenuUtil.CreateContextMenu`, already used by the minimap button)
  with radio entries: "Game client language" (translated) and each registered language by its native name, in
  the order of `docs/languages.md`. Hovering the button shows the tooltip of FR-013. `MenuUtil` is verified on
  Forever, so it has no fallback (dropped in code review).
- **Rationale**: `MenuUtil` is verified on Forever by the minimap menu; `root:CreateRadio` belongs to the same
  menu API but is not verified yet, so the code falls back to `root:CreateButton` with a check mark in the
  text if `CreateRadio` is missing. The settings pages are plain canvas widgets (project rule), not the
  Settings setting-type API.
- **Alternatives rejected**: `WowStyle1DropdownTemplate` (not verified on Forever); a row of ten radio
  buttons (no room on the page, which fits without scrolling).

## R5. Applying a change (reload prompt)

- **Decision**: Choosing a different value saves it in `OneKeyFishingDB.settings.language` and shows a
  `StaticPopup` "The language changes after reloading the interface." with "Reload now" (`ReloadUI()`) and
  "Later". Nothing reloads without that click.
- **Rationale**: matches the clarification (Q1) and Principle I: the reload is the player's click.
  `ReloadUI` is not protected; it runs from the popup's button handler.

## R6. Fonts

- **Decision**: All addon text keeps using the game's font objects (`GameFontNormal`, `GameFontHighlight`,
  `GameFontDisableSmall`, ...) and Blizzard's tooltips and menus; no font file is set by path. These font
  objects pick a per-alphabet font (Korean, Chinese, Cyrillic) when the text needs it. `npm run check`
  reports any `SetFont` call in the addon.
- **Findings**: on the author's English Forever client the font cache holds `frizqt__.ttf` (Latin) and
  `bkai00m.ttf` (Traditional Chinese, so the client draws it); Cyrillic `frizqt___cyr.ttf` is cached on the
  retail and era clients. Korean `2002.ttf` and Simplified Chinese `arkai_t.ttf` are not cached yet, which
  only means nothing drew with them; the in-game check in `quickstart.md` settles it.
- **In game (2026-11-05, EU realm, ruRU client, build 70790)**: `2002`, `ARKai_T`, `bKAI00M` and `FRIZQT___CYR`
  load through `SetFont`; `ARHei` and `blei00d` do not. The language menu draws 한국어, 繁體中文 and 简体中文
  readably, so the font objects find a font for them. With the addon in Korean or Chinese on a client in another
  language the game measures tooltip lines with the client's shorter font: the last line of the minimap and
  Language tooltips fell below the frame (fixed by `ns.TallGlyphs`, spec 007 User Story 6), and some glyphs still
  reach past the right edge (deferred until a player reports it, spec 007 research R9). On a Korean or Chinese
  client the fonts match.
- **Alternatives rejected**: shipping CJK font files (several MB each, against the small package); hiding
  Korean and Chinese on other clients (rejected in clarification Q2).

## R7. Longer texts (SC-006)

- **Decision**: `ns.CreateButton` widens a button to its text when the text is wider than the given width;
  checkbox labels and hint lines get an explicit width with word wrap; the statistics row labels keep their
  column and are checked in game per language. The in-game checklist covers every window in German (usually
  the longest) and Korean / Chinese.
- **Rationale**: fixed widths (140-190 px buttons, 300 px columns) fit English only; growing to fit is cheaper
  than per-language layouts.

## R8. Placeholders and line length in translations

- **Decision**: A test compares, for every translated string, the sequence of `%` format specifiers with the
  English key (Lua 5.1 has no positional arguments, so the order must match) and the `|` escape sequences.
  Translation lines keep the 120-character limit: a long entry is written as
  `L["English"] =\n    "translation"`, split with `..` if still too long.
- **Rationale**: a mismatched specifier makes `string.format` raise an error in game; this catches it in CI.
  `npm run check` measures characters, not bytes, so CJK lines are not penalised.

## R9. Completeness

- **Decision**: A test asserts that every shipped translation has every key of `enUS.lua` (FR-011). A new
  English text therefore needs its nine translations in the same change. The English fallback (FR-007) still
  protects players if a gap slips through in a future volunteer contribution.
- **Alternative rejected**: completeness as a release-time warning only (would let releases ship partial
  translations, against FR-011).

## R10. Out of scope (confirmed)

- Localized TOC fields (`## Notes-deDE:`): first left out because they follow the client, not the setting, and
  the TOC had to stay ASCII. **Revised during implementation**: they were added (FR-027) after the game's addon
  list was seen to read them in the client's language (German client, 2026-11-03); `npm run check` allows UTF-8
  only in those lines, and constitution 1.3.0 names that exception.
- Game names (items, zones, spells): always from the client.
- The debug report and slash command names: stay English (FR-009); the report gains three lines: the
  preference, the effective language and the client locale.

## R11. How Fishing ranks are learned (User Story 3)

Sources (2026-11-03): Wowhead Classic, warcraft.wiki.gg, Forever guides (wow-professions.com, Warcraft Tavern,
Metabot, kami-labs), the Forever client export (build 1.60.1.70685). No source describes a Forever-specific
change; the guides are based on the beta and say requirements may still change.

| Next rank (cap -> new cap) | Source | Can learn from | IDs (VERIFY in game) |
|---|---|---|---|
| Journeyman (75 -> 150) | any fishing trainer | skill 50, level 10 | spell 7731 |
| Expert (150 -> 225) | book "Expert Fishing - The Bass and You", 1 gold, sold by Old Man Heming in Booty Bay (also tradable) | skill 125, level 20 | spell 7732, item 16083, NPC 2626, area 35 (Booty Bay) in 33 (Stranglethorn Vale), map 1434 (Classic) or 224, point ~0.274 / 0.770 |
| Artisan (225 -> 300) | quest "Nat Pagle, Angler Extreme" (four fish: items 16967-16970) from Nat Pagle on an island in Tidefury Cove | skill 225, level 35 | spell 18248, quest 6607, NPC 12919, area 517 (Tidefury Cove) in 15 (Dustwallow Marsh), map 1445 (Classic) or 70, point ~0.586 / 0.602 |

- **Faction**: Old Man Heming, Nat Pagle and the quest are neutral; nothing in the rank path depends on the
  faction. Only the trainers' places differ (each capital and many towns have one; the Booty Bay trainer is
  Myizz Luckycatch, Heming only sells the book).
- **Apprentice** (rank 1) is learned at any trainer; the addon only runs for characters that know Fishing, so
  it has no advice for it.
- **Uncertain until the launch**: whether Forever keeps the book and the quest (one guide says ranks come
  "from a trainer"), which map IDs the Forever client uses (Classic 1434 / 1445 or the modern 224 / 70), the
  exact coordinates, the level requirements. All are checked in game ([quickstart.md](quickstart.md)).
- **In game (2026-11-05, ruRU client)**: area IDs 35, 33, 517 and 15 and item 16083 give the expected names, so
  their `VERIFY` marks are gone. Still open: the level and skill thresholds (level 10 is not reached yet), the
  book seller, the quest (6607 has no title), the map IDs and the points.
- **In game (2026-11-06, release 1.1.0, enUS client)**: Journeyman learned at a trainer at level 10, and the
  "can learn" notice came on reaching level 10, so `level = 10` lost its mark (`learnAt = 50` keeps it: the
  character was past skill 50). The client chose map 1434 for Booty Bay (the Classic ID, so Forever uses the
  Classic uiMapIDs) and the pin landed on Heming at 0.274 / 0.770: those marks are gone too. Next to Heming:
  map 1434, 0.2745 / 0.7719, NPC 2626 in his GUID; he sells item 16083, the book: those marks are gone. Still open: Heming's
  merchant list, Nat Pagle, the quest ID, the Dustwallow map and point, the levels 20 and 35.
- **Forever extras** that do not change the path: Legacy points at skill 150 / 225 / 300, new recipes (Fishing
  Rack, Fishing Hut, Bait and Tackle), faction-bound poles. No Fishing above 300.
- **Decision**: thresholds `learnAt` 50 / 125 / 225 and `level` 10 / 20 / 35 replace the old `WARN_BEFORE = 5`
  (the old rule warned at 70 and 145, long after the next rank could be learned).

## R12. Game names by ID (FR-015, FR-016)

- **Decision**: every game name in the advice is read from the client in its language:
  - zone and sub-zone: `C_Map.GetAreaInfo(areaID)` (synchronous);
  - book: `C_Item.GetItemNameByID(16083)`; requested at login with `C_Item.RequestLoadItemDataByID`, refreshed
    on `ITEM_DATA_LOAD_RESULT`;
  - quest: `C_QuestLog.GetTitleForQuestID(6607)`; requested with `C_QuestLog.RequestLoadQuestByID`, refreshed on
    `QUEST_DATA_LOAD_RESULT`;
  - rank names: `C_Spell.GetSpellSubtext(spellID)` of the rank's Fishing spell (7620 / 7731 / 7732 / 18248),
    which in Classic is the rank name ("Apprentice"); requested with `C_Spell.RequestLoadSpellData`, refreshed on `SPELL_DATA_LOAD_RESULT` and `SPELL_TEXT_UPDATE` (the API doc of `GetSpellSubtext` names the latter); fallback the
    translated `L["Apprentice"]` ... (VERIFY that Forever fills the subtext);
  - NPC names: no API exists. First `C_TooltipInfo.GetHyperlink("unit:Creature-0-0-0-0-<npcID>-0")`, line 1
    (untested; works only when the client has the creature cached, VERIFY), then the table of official names
    per client locale (`GetLocale()`, from Wowhead's localized pages, including ruRU for Ukrainian players on a
    Russian client), then English.
- **In game (2026-11-05, EU realm, ruRU client, build 70790)**: the area names, the book and the four rank
  subtexts come from the client in its language; `C_QuestLog.GetTitleForQuestID(6607)` returns nil even on a
  second call and 5 s after `RequestLoadQuestByID(6607)`; `GetQuestInfo(6607)` is nil too (open: the quest ID on
  Forever, or no quest data for a level 1 character; checked at Nat Pagle later). At skill 52, level 6, the
  debug report shows the next rank's name from the spell subtext (`next rank: <Journeyman in Russian> (game)`).
- **In game (2026-11-06, enUS client)**: after Journeyman the report shows `next rank names: item game, npc game,
  area game, zone game`: Heming's name comes from his creature tooltip (`C_TooltipInfo.GetHyperlink`), so that
  mark is gone. Open: the German Heming name of the table (used only without a tooltip).
- All of them exist in the Forever export (`Blizzard_APIDocumentationGenerated`: `MapDocumentation.lua`,
  `ItemDocumentation.lua`, `QuestLogDocumentation.lua`, `SpellDocumentation.lua`,
  `TooltipInfoDocumentation.lua`).
- **Rationale**: names the addon translates itself never match a client exactly (and Ukrainian has no client
  at all, so its players see English or Russian names on the map). Reading by ID also keeps Principle II.
- **Alternatives rejected**: translating game names in `Locales/` (the old way; mismatches); keeping names in
  English everywhere (wrong on every non-English client).

## R13. Sentences per learning source (FR-017)

- **Decision**: the advice is built from complete sentences: a state sentence ("You can learn %s Fishing
  now.", "Fishing skill capped (%d/%d): learn %s Fishing to go on.", "%s Fishing needs character level %d.")
  and a where sentence per source (trainer, book, quest), each a literal `L` key with its nine translations.
  Game names only fill `%s` placeholders, quoted where the language quotes titles. The old keys (`a fishing
  trainer`, the book and quest phrases, the two old templates) are removed.
- **Rationale**: the old "learn %s Fishing from %s" put a translated phrase into another sentence, and the
  case of the inserted phrase was wrong in several languages (Ukrainian genitive, German "von"/"ueber").
- **Alternative rejected**: one template with an inserted phrase (the old way).

## R14. Notices, the "Next rank" line and the map pin (FR-018 - FR-023)

- **Notices**: "can learn" is quiet (chat and toast) once per session per rank, checked on
  `SKILL_LINES_CHANGED`, `CHAT_MSG_SKILL`, `PLAYER_LEVEL_UP` and 2 s after `PLAYER_ENTERING_WORLD`. The cap
  notice adds the raid-warning message only the first time per session; entering fishing mode repeats it as a
  chat line. When a pin target exists, the chat line ends with a clickable map link
  (`|Hworldmap:<mapID>:<x*10000>:<y*10000>|h[...]|h`, the link type `LinkTypes.WorldMapWaypoint` that
  Blizzard's own handler turns into a pin, `ItemRefHandlers.lua`; VERIFY). That handler
  (`Blizzard_UIPanels_Game/Mainline/ItemRefHandlers.lua:219`) calls `C_Map.SetUserWaypoint` and
  `OpenMapToUserWaypoint` directly: no confirmation, no navigation arrow, no `charDB.pin`. FR-022 accepts this
  for the chat link (standard game behaviour); the confirmation and the arrow belong to the addon's own pin
  button and menu entry. A custom addon link type running `MapPin.Set` was rejected: more code and one more
  in-game unknown for little gain.
- **No journal**: no branch has a message journal; a permanent line in the statistics window and the minimap
  tooltip keeps the advice, which is all the player needs after the toast fades.
- **Map pin**: a shared module `UI/MapPin.lua` takes over the pin logic built for the catch catalog on
  `002-shared-db` (`Catalog.PinTarget`, `CatalogTab.Pin`): `C_Map.CanSetUserWaypointOnMap`, the game rule
  `Enum.GameRule.WorldMapTrackingPinDisabled` (checked with `C_GameRules.IsGameRuleActive`),
  `C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(...))`, `C_SuperTrack.SetSuperTrackedUserWaypoint(true)`,
  `OpenWorldMap(mapID)` out of combat, a popup before replacing a pin the player set, the addon's last pin in
  `charDB.pin`. Same saved field and texts as on `002-shared-db`, so the 1.2.0 merge switches the catalog to the
  module. The map is the first candidate ID the client knows and allows pins on (Classic ID first).
- **In game (2026-11-06, enUS client)**: the Pin button and the minimap menu entry set the pin on Heming (map
  1434) with the navigation arrow and open the map; a pin of the player's own is replaced only after the popup,
  whose buttons are in the addon's language. The arrow mark is gone (and the catch catalog's V31, the same call).
  The chat map link (at the cap 150) sets the pin and opens the map, and a fight afterwards is clean: the
  game's own handler opens the map. **Failed**: after the pin opened the map (`OpenWorldMap` from addon code), opening it
  in a fight gave "Interface action failed because of an AddOn"; `Logs/taint.log` names the map canvas field
  `targetScrollY` and the blocked `Button:SetPassThroughButtons()` of the map's quest pins. The fix (the pin leaves
  the map closed) waits in `docs/tech-debt.md`.
- **Policy**: setting a pin is the player's click; no game action is automated (Principle I).

## R15. Static game data (FR-024)

- **Decision**: a data-only file `OneKeyFishing/GameData/FishingRanks.lua` (after `Data.lua` in the TOC) holds
  the rank steps, thresholds, levels, IDs, map candidates, coordinates, English fallback names and the NPC
  names per client locale (`ns.FishingRanks`, `ns.FishingRankSpells`, `ns.NpcNames`). No logic, no `L`
  lookup. The NPC names are UTF-8: constitution 1.3.0 (Technical Constraints) allows UTF-8 string literals
  in `GameData/` files, while code, keys and comments there stay ASCII; `npm run check` enforces exactly that.
- **Checked**: `002-shared-db` has no separate game-data layer (`LURES`, `CONTAINERS` and `KNOWN_POLE_BONUS`
  stay in `Fishing/Bags.lua` and `Fishing/Gear.lua`; `Core/Data.lua` mixes IDs with helpers), so there is no
  pattern to follow yet.
- **Technical debt (1.2.0)**: move the older tables (lures, containers, pole bonuses, Fishing spell IDs, the
  bobber ID) into `GameData/` after `001-interface-language` is merged into `002-shared-db`
  (`docs/release-plan.md`).

## R16. Out of scope for User Story 3

- A pin on the nearest fishing trainer: needs a table of about 25 trainers with Forever map IDs and coordinates
  that cannot be checked before the launch; the minimap's trainer tracking (enabled in Forever,
  `MinimapConstants.lua` `TrainerProfession`) already finds them. Goes to `docs/ROADMAP.md`.
- A general message journal: not needed for this story (R14).
