# Research: the Stranglethorn Fishing Extravaganza and the item kinds

Pre-spec research (2026-11-23) for two roadmap items taken together: the helper for the Stranglethorn Fishing
Extravaganza (the Booty Bay fishing contest) and new item kinds in the catch lists (a group for quest fish, a kind for
the weighed "N Pound" fish). No code is written yet. The design quiz with the author's decisions is
[section 11](#11-decisions-agreed-with-the-author-2026-11-23); the two specs (023 kinds, 024 the helper) are listed in
[ROADMAP.md](ROADMAP.md), "Planned".

Sources and tags used below:

- **[DB2]** the WoW Forever client tables on wago.tools, product `wowf`, build 1.60.1.71037
  (`https://wago.tools/db2/<Table>/csv?build=1.60.1.71037`).
- **[export]** the author's client export of build 1.60.1.70685 (`Blizzard_APIDocumentationGenerated`, FrameXML).
- **[web-F]** a WoW Forever guide or news page; **[WH-F]** Wowhead's `/forever/` database.
- **[CE]** Classic Era or the original 1.x game, not confirmed for Forever.
- **[addons]** other Forever fishing addons kept in `static/examples/` (FishingForever, ForeverFishing, Hooked,
  OneCast). Facts only; their code is not copied (licenses: FishingForever is "All Rights Reserved" over a CC BY-NC-SA
  core, ForeverFishing is "All Rights Reserved", OneCast and Hooked state no license).
- **[memory]** general WoW knowledge not confirmed anywhere above.

## 1. Schedule

- **Holiday 301** in `Holidays.db2` [DB2]: name "Stranglethorn Fishing Extravaganza" (HolidayNames 6), description
  (HolidayDescriptions 4) "A fishing tournament, held along the coasts of Stranglethorn Vale. Catch as many tastyfish as
  you can! Will you be the master fisherman who catches forty fish first and wins the grand prize?".
  - `Date_0` = 536855424 decodes to minute 0, hour 14, weekday 0 (Sunday), day, month and year "any"; `Duration_0` = 2
    hours; `Looping` 0, `Flags` 1, `CalendarFilterType` 0, `TextureFileDataID` 235458. So: **every Sunday 14:00-16:00
    realm time**. The decoder was checked on other rows (Winter Veil 15 Dec, 18 days; Call to Arms 1840 on
    2026-04-21).
  - `CalendarFilterType` 0 is most likely the "weekly holidays" filter (`calendarShowWeeklyHolidays`): inferred from
    the other rows, not confirmed.
  - No second row: no announcement or pre-event holiday.
- [CE] The schools spawn 14:00-16:00; Riggle stays one more hour, until 17:00, for turn-ins (his end yell says so).
- [web-F] Forever contests were reported on 2026-11-08, 2026-11-15 and 2026-11-22 at Sunday 14:00 realm time.
- **The realm's time zone is not known** for any Forever region; every source says "realm time". The addon must work in
  realm time (`C_DateAndTime.GetCurrentCalendarTime`) or from the calendar, never in a fixed zone.
- [CE] Pre-event flyer: item 19978 "Fishing Tournament!" from the Fishing Promoters Barrus (NPC 15119, Ironforge, quest
  8228) and Grinkle (NPC 15116, Orgrimmar, quest 8229). Whether Forever has them is not known.

## 2. People and places

| NPC | ID | Role |
|---|---|---|
| Riggle Bassbait `<Fishmaster>` | 15077 | Master Angler (40 Speckled Tastyfish) |
| Jang | 15078 | [WH-F] `<Fishing Extravaganza Prizes>` in Forever: the coin's prizes, coin bags for Tastyfish ([CE] `<Fishmaster Apprentice>`, quest Apprentice Angler) |
| Fishbot 5000 | 15079 | the three rare fish quests |

- The IDs come from Wowhead and classicdb; the `Creature` table is not readable on wago for `wowf`, so they are not
  confirmed in Forever's own data (OneCast uses 15078 for Jang).
- Place: all three on one dock of Booty Bay next to the fishing trainer. Coordinates on the Stranglethorn Vale map
  (UiMap 1434): 27.4, 76.8 (LFCarry; OneCast's NPC list), 27.6, 77.6 (OneCast's waypoint to Riggle). Not checked in game. The NPCs are
  spawned by the event, so the databases show no map.
- Map and areas [DB2]: UiMap 1434 "Stranglethorn Vale" (Forever has no split Northern STV / Cape maps); AreaTable 33
  Stranglethorn Vale, 35 Booty Bay, 301 The Savage Coast. The bundled seed already holds Speckled Tastyfish on map 1434
  (87 catches in `docs/fishing-investigation.md`).

## 3. Quests

| Quest | ID | NPC | Asks | Reward |
|---|---|---|---|---|
| Master Angler | 8193 | Riggle 15077 | 40 Speckled Tastyfish | see below; repeatable, quest level 60, required level 1 |
| Apprentice Angler | 8194 | Jang 15078 | 5 Speckled Tastyfish | [CE] money; in Forever Jang sells coin bags for Tastyfish instead (below) |
| Rare Fish - Keefer's Angelfish | 8221 | Fishbot 15079 | 19805 | Lucky Fishing Hat 19972 (+5 Fishing) |
| Rare Fish - Dezian Queenfish | 8224 | Fishbot 15079 | 19806 | High Test Eternium Fishing Line 19971 (+5 to the pole) |
| Rare Fish - Brownell's Blue Striped Racer | 8225 | Fishbot 15079 | 19803 | Nat Pagle's Extreme Anglin' Boots 19969 (+5 Fishing) |

- None asks for a Fishing skill; the rare fish quests are repeatable, both factions [CE].
- `QuestV2` of `wowf` has a row for 8193, none for the others (that table lists only some quests: proves nothing).
- **Winners in Forever** [web-F, addons]: 50 per ruleset at launch; a hotfix of 2026-11-13 "greatly increased" the
  number; Riggle's quest text says "the FIRST 250 PEOPLE" (seen 2026-11-15 and, by OneCast, 2026-11-22). "Ruleset" is
  most likely the game mode (Normal, PvP, RP, Hardcore). [CE] one winner per realm.
- **Master Angler's reward in Forever** [web-F, WH-F, addons]: Arcanite Fishing Pole 19970 (+35 Fishing, needs 300),
  one Extravagant Extravaganza Coin 274026, and the title "Master Angler" for a week: spell **1299323** "Master
  Angler!" [DB2], "Achieved victory in this week's Stranglethorn Fishing Extravaganza! Permitted to wear the title
  "Master Angler" for the duration of this effect." Wowhead shows a choice of pole or Hook; most guides and OneCast say
  pole + coin, the Hook bought from Jang with the coin.
- [DB2] spell 1299291 "Snacking on Tastyfish" ("Enjoying the results of everyone else's labor."), new in Forever,
  purpose unknown.

## 4. Items

| ID | Name | Class/sub | Notes [DB2] |
|---|---|---|---|
| 19807 | Speckled Tastyfish | 15/4 | white, **stack 40**, **expires 4 h** after the catch, bind on pickup, no use, sells for 0 |
| 19803 | Brownell's Blue Striped Racer | 15/0 | green, stack 20, 4 h, bind on pickup, "Someone in Booty Bay might be interested." |
| 19805 | Keefer's Angelfish | 15/0 | same |
| 19806 | Dezian Queenfish | 15/0 | same |
| 19804 | Pale Ghoulfish | 15/0 | unused item of the series, not in the contest |
| 19808 | Rockhide Strongfish | 2/4 | a one-handed mace fished from the schools; no `ItemSparse` row: hidden until found |
| 19970 | Arcanite Fishing Pole | 2/20 | +35 Fishing; already in `GameData/FishingPoles.lua` |
| 19979 | Hook of the Master Angler | 4/0 trinket | frenzy fish form, water breathing (spell 24347) |
| 19969, 19971, 19972 | the rare fish rewards | | see section 3 |
| **274026** | Extravagant Extravaganza Coin | 15/4 | Forever only: "Awarded to the winners ... Exchange for a prize of your choosing from Jang." |
| 276272 | Master Angler's Fishing Hat | 4/5 | Jang, 1 coin (cosmetic) |
| 276273 | Empty Fish Bucket | 4/0 off-hand | Jang, 1 coin (cosmetic) |
| 276274 | Surfer Shoes | 4/1 | Jang, 1 coin (water walking) |
| 276275 | Bitter Baitling | 15/2 pet | Jang, 1 coin |
| 276278, 276279, 276280 | Handful of Coins, Small Bag of Coins, Hefty Sack of Coins | | Jang, for 1, 5 and 10 Tastyfish |
| 274974 | Message in a Bottle | | 20 Tastyfish; reported as not sold live |

- `ItemExtendedCost` 11642 = 1 coin; 11643-11646 = 1, 5, 10, 20 Tastyfish [DB2]. Which vendor sells what is server
  data; the list comes from guides and OneCast, not checked in game ([fishing-investigation.md](fishing-investigation.md)
  lists the coin as open).
- The 4 h expiry matters: Tastyfish caught on one Sunday do not last to the next.

## 5. Where and how to fish

- Only the **School of Tastyfish**, GameObject **180248**, gives the contest's fish; it spawns only during the contest,
  along the Stranglethorn coast, never inside Booty Bay. The bobber must land in the school.
- [CE] A school is gone after 2-5 casts and comes back after about 6 minutes.
- Loot (OneCast's table of Classic data): Speckled Tastyfish about 85 %, Oily Blackmouth 6358, Firefin Snapper 6359,
  Stonescale Eel 13422 about 5 % each, the rare fish 19803, 19805, 19806, 19808 about 0.1 % each. No source ties a
  rare fish to a spot.
- Spots named by guides (vague): Yojamba Isle down to the Cape, the Savage Coast islands, south of Grom'gol. No spawn
  coordinates published. Our seed has Tastyfish catches on map 1434 with positions: the addon can show its own spots.
- Skill: quoted as 130, 150, 225 or 255. Our seed's Skill filter knows the real ranges per place.
- **Forever so far** [web-F]: on 2026-11-08 and 2026-11-15 the schools stopped after about 20-30 minutes, once the
  winners came in (2026-11-08 had one winner instead of 50). Blizzard: "performance issues", fixes promised. Whether
  the schools are meant to stop after the winners is not said.
- Layers: unknown whether a layer has its own schools; the winner count is per ruleset, not per layer.

## 6. Yells (start, winners, end)

All `CHAT_MSG_MONSTER_YELL` by Riggle Bassbait [WH-F, 115 quotes]:

- start: "Let the Fishing Tournament BEGIN!" (also "Let the Fishing Tournament... BEGIN!");
- a winner (Forever): "We have a winner! <name> is one of our Master Anglers this week!" ([CE] "... is the Master
  Angler!"); the name seems to be the first name only;
- end: "And the Tastyfish have gone for the week! I will remain for another hour to allow you to turn in your fish!"
  and "... Thank you to all who chose to participate!".
- Jang: "Don't forget to bring any extra fish back to Booty Bay for a consolation prize! We'll be here for a little
  while longer."
- [CE] Zone-wide yells; not confirmed for Forever (one guide says the start yell is zone-wide).

By ID [export]: the yell's 12th argument is the speaker's GUID (`Creature-0-...-<npcID>-<spawn>`), so Riggle is known
by NPC ID 15077, not by name. The text cannot be matched by ID: `BroadcastText` is empty on wago for `wowf`, so the
client's localized yell texts are not available as needles. With 250 winners a yell during the contest is mostly
"a winner"; the start and the end yells come at known times (14:00, 16:00). Under chat lockdown the text, name and GUID
are secret values (encounters, PvP matches, instances); open-world Stranglethorn should be free, but `ns.IsSecret`
guards it.

## 7. API

- **Calendar** [export]: Forever loads `Blizzard_Calendar` (load on demand, the minimap's calendar button).
  `C_Calendar.OpenCalendar`, `SetAbsMonth`, `GetMonthInfo`, `GetNumDayEvents(offsetMonths, monthDay)`,
  `GetDayEvent(...)` (`eventID`, `title`, `startTime`, `endTime`, `calendarType == "HOLIDAY"`, `iconTexture`),
  `GetHolidayInfo`, `GetEventIndexInfo(eventID)`, event `CALENDAR_UPDATE_EVENT_LIST`. No separate holiday ID field:
  that `eventID` is 301 for this holiday is retail behaviour, **not confirmed in Forever**. Trap: month offsets are
  relative to the calendar's current month, which `SetAbsMonth` changes (also for Blizzard's open calendar). Whether the
  weekly-holiday filter CVar hides the event from the API is not known.
- **Time** [export]: `C_DateAndTime.GetCurrentCalendarTime()` (realm date and time, `weekday` 1 = Sunday),
  `GetServerTime()` (epoch), `GetGameTime()` (realm hour, minute), `C_DateAndTime.AdjustTimeByDays`,
  `GetCalendarTimeFromEpoch`. The schedule can be computed from realm time alone; the calendar can confirm it.
- **Own result**: `QUEST_TURNED_IN` (questID 8193), `C_QuestLog.IsQuestFlaggedCompleted(8193)`; the aura 1299323
  (read by ID out of combat only, see CLAUDE.md); the coin 274026 or the pole 19970 appearing in the bags.
- **Others' result**: no event tells that another player turned in. Only Riggle's yells (by GUID), the schools
  stopping, or other addon users.
- **Bag count**: the bag iterator of `Core/Data.lua` (or `C_Item.GetItemCount(19807)`), `BAG_UPDATE_DELAYED`.

## 8. What other Forever addons do [addons]

| Addon | Schedule | Notices | Counter | Winners and end |
|---|---|---|---|---|
| OneCast (`Extravaganza.lua`) | fixed Sunday 14:00, 2 h, from `GetCurrentCalendarTime` | chat: 60 min before (a checklist of what is missing: skill, pole, lures, food, bag room), 15 min, at the start, 10 min before the end if 40 are held; a summary at the end | bag count of 19807; at 40: raid warning, sound, waypoint to Riggle; pace and forecast | own win by `QUEST_TURNED_IN` 8193 or a new coin or pole in the bags; counts Riggle's yells by English name and "winner" text; end by the clock |
| Hooked | fixed Sunday 14-16 | one notice once a day while it runs ("First 50 ..." outdated) | none | own win by 8193, a crown for 7 days, win count |
| ForeverFishing | the next 4 Sundays listed (realm and local time, `AdjustTimeByDays`) | none | none | none; a guide page (what, where, rewards) |
| FishingForever | fixed Sunday 14-16 (weekday from the local clock: wrong near midnight) | a HUD line "STV DERBY LIVE" | none | none (the old Fishing Buddy winner pattern is dead code) |

- None of them uses the calendar or the holiday ID, and none tells the winner yell by NPC ID. OneCast is the fullest:
  readiness checklist, counter, pace, records (best haul, fastest 40, wins), a page with spots, rare fish and Jang's
  prizes.
- OneCast uses the pool's object 180248 and the Riggle spot 27.6, 77.6 "Classic's spot".

## 9. Item kinds

Today `Catalog.KINDS = { "fish", "containers", "potions", "reagents", "other" }` (`Catalog/Catalog.lua`), assigned by
item ID in `GameData/ItemKinds.lua`, then by class. The quest fish (19805-19807, the Nat Pagle fish 16967-16970,
Spotted Sunfish 1467) are filed as "fish". `GameData/FishedQuestItems.lua` lists the quest items fished beside a catch
(6718, 16967-16970, 19806, 19807, and the quest class 12); Gaffer Jack 6717, a quest item of Darkshore, was under "other".

**Weighed "N Pound" fish** [DB2]: all class 15/0 (junk), white, stack 1, not bound, sold for 100 copper per pound, used
by no quest; caught in place of the ordinary fish of the same kind.

| Series | IDs | Held in the off hand (InventoryType 23) |
|---|---|---|
| Mud Snapper 10, 12, 15 | 6292, 6294, 6295 | yes |
| Catfish 17, 19, 22, 26, 32 | 6309, 6310, 6311, 6363, 6364 | yes |
| Redgill 34, 37, 42, 45, 49, 52 | 13885, 13886, 13882, 13883, 13884, 13887 | yes |
| Salmon 15, 18, 22, 25, 29, 32 | 13901, 13902, 13903, 13904, 13905, 13906 | yes |
| Mightfish 70, 85, 92, 103 | 13914, 13915, 13916, 13917 | yes |
| Lobster 7, 9, 12, 15, 19, 21, 22 | 13907-13913 | **no** (InventoryType 0) |
| Yellowtail 40, 47, 53, 59, 68 | 13876-13880 | **no** (some guides call them "Grouper"; Forever's data says Yellowtail) |

- 36 items in all (every "Pound" item of `ItemSparse` but 887 Pound of Flesh and 21028 500 Pound Chicken).
- Not yet in `ItemKinds.lua` (they fall to "other"): 6364, 13880, 13884, 13887, 13902-13906, 13911-13913, 13916,
  13917, and the contest fish 19803, 19804.
- The class tells nothing (15/0 is also a chest); the kind must be listed by ID, as the other kinds are.

## 10. Open, to check in game

1. The calendar: does `C_Calendar.GetDayEvent` list the contest on Sundays, is its `eventID` 301, does the weekly
   filter CVar hide it.
2. The realm's clock: the contest really starts at 14:00 of `GetCurrentCalendarTime` on the author's realm; Riggle's
   last hour for turn-ins (until 17:00?).
3. Riggle's GUID in his yells carries 15077 and is not secret in Stranglethorn; which yells come (start, each winner,
   end) and whether they reach the whole zone; Jang's 15078 and Fishbot's 15079.
4. The winner count (250?) and what ends the contest in Forever: the clock or the winners (the schools stopped early
   twice).
5. Jang's prizes and coin bags with their prices; the aura 1299323 on a winner.
6. The School of Tastyfish object 180248 and how the catch database records its catches (pool or open water).

## 11. Decisions agreed with the author (2026-11-23)

The design quiz after this research, one question at a time; the author's answer to each. These decisions feed the
two specs; anything not listed here is decided in the spec.

### Scope

- Two specs: **023**, the new item kinds (small, released first), and **024**, the Extravaganza helper (it uses the
  kinds of 023).

### 023: item kinds

- **"Trophies"**: a new kind for all 36 weighed "N Pound" fish (those held in the off hand and the Lobster and
  Yellowtail series alike).
- **"Quest"**: a new kind for every quest item: the Nat Pagle fish (16967-16970), the contest's fish (19803-19807),
  Spotted Sunfish 1467, Electropeller 6718, Gaffer Jack 6717, and any item of the quest class (12).
- The order of the kinds in the filter: Fish, Containers, Trophies, Potions, Reagents, Quest, Other. Every kind is shown
  by default.
- **Trophy collection** in the catalog: a count "12/36" with the Trophies kind and a mark beside the trophies caught.
  "Caught" means by any character of the account (the own catch record, which the catalog already reads).
- **Trophy notice**: the first catch of a trophy gives a loud toast "New trophy (13/36)" with the rare loot sound, also
  with catch notifications off; a trophy caught again gives the ordinary catch toast, by the settings.

### 024: the Extravaganza helper

- **Schedule**: Sunday 14:00-16:00 from the realm's time through the API (`GetServerTime`,
  `C_DateAndTime.GetCurrentCalendarTime`), independent of the clock's "Use Local Time" display setting, so a notice is
  right whatever the player's clock shows. The game's calendar confirms it: when the calendar gives another time or no
  contest, the calendar wins; without the calendar the clock alone works.
- **Time shown**: notices say how long until ("in 30 min"); the tab shows a countdown and the start time in the same
  time as the player's clock (realm or local, as the player set it).
- **Notices before the start** (1 day, 1 hour, 30 min, 5 min; one switch): a toast and a chat line each, the 5 min one
  with a sound. Each threshold once per account and contest, not repeated after a `/reload`. A login after a threshold
  gives one notice ("in 3 h"); missed thresholds are not caught up.
- **Notices during the contest**: the start (by the clock); the first winner (Riggle's first yell during the contest,
  told by his NPC ID, not by the text: "someone turned in 40, the schools may vanish"; only when the player hears the
  yell, in Stranglethorn); the end at 16:00 ("the schools are gone, one hour left to turn in"). The count of winners
  heard is shown in the tab, without notices.
- **Tastyfish counter** (x/40): in the fishing mode indicator during the contest ("Tastyfish 23/40, 1:12 left") and in
  the tab. At 40: a loud toast "bring them to Riggle" and a map pin on Riggle (the minimap's arrow, as the rank pin).
- **Rare contest fish**: a loud toast with the reward ("Rare fish! Fishbot 5000 gives [Lucky Fishing Hat]. Expires in
  4 h") and the rare loot sound, also with catch notifications off; Rockhide Strongfish the same, without a reward.
- **Settings page "Extravaganza"**, every switch on by default: notices before the start; notices during the contest;
  the counter in the indicator; the pin on Riggle at 40. The toasts for 40 and for a rare fish are always on.
- **Tab next to the catalog**: status and countdown at the top, then: this contest's progress (Tastyfish x/40, rare
  fish in the bags, winners heard, whether the player is a Master Angler this week); preparation (a checklist: Fishing
  skill against Stranglethorn's need, pole, lures in the bags, bag room); where to fish (places with Tastyfish from the
  catch database, a pin on a click as in the catalog, where Riggle, Jang and Fishbot stand); rewards and exchange (40 to
  pole, coin and title; rare fish to Fishbot; the coin to Jang's prizes; 1, 5 and 10 Tastyfish to coin bags; item icons
  with tooltips). No history or records of past contests.
- **Minimap menu**: two new entries, "Catalog" and "Extravaganza", each opening its tab of the window; the contest
  entry always, with its countdown ("Extravaganza: in 2 d 5 h" / "Extravaganza: on, 1:12 left"). The minimap button's
  tooltip has a contest line only within a day before the start and during the contest.
- **Commands**: a new `/okf event` opens the tab and prints a status line (the countdown or x/40); `/okf catalog`
  exists already.
- **In-game checks** (`VERIFY` markers; the first chance is the contest of 2026-11-29): the calendar gives the contest
  with ID 301; the start at 14:00 realm time; Riggle's yell carries GUID 15077 and is not secret; Riggle's
  coordinates; Jang's prizes; the aura 1299323 on a winner.
