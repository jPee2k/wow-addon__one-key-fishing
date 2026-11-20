# Research: Fishing Camp Buffs

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

The sources: the in-game session of 2026-11-19 and the game data in
[docs/fishing-investigation.md](../../docs/fishing-investigation.md) and
[docs/forever-api.md](../../docs/forever-api.md) ("Verified in game", the last entry), and the addon's code of
1.4.0. "Decision N" is the author's decision N in the spec's clarifications.

## R1. Where the buff is read

- **Decision**: a new module `ns.Camp` in `Fishing/Camp.lua` (layer 1), loaded after `Fishing/Skill.lua` and before
  `Catch/Stats.lua`. It owns the buff state, the per-cast rule (R3), the notices (R10) and its debug lines. The
  list of bonuses is game data: `GameData/CampBonuses.lua` (layer 0).
- **Rationale**: the state is read by two modules of different layers (`Catch/Stats.lua`, layer 1, and
  `CatchDB/Events.lua`, layer 2), so it has to live in layer 1; it is about the game's fishing state, like
  `Fishing/Skill.lua`. It must load after `Catch/Catch.lua` (the cast ID is new when its `FISHING_CAST_START`
  handler runs, handlers run in TOC order) and before `Stats` and `CatchDB` (they ask it at the settle).
- **Alternatives**: in `CatchDB/Events.lua` (layer 2: `Stats` could not ask); in `Core/Data.lua` (it would hold
  state and events, which that file of helpers does not); in `Fishing/Bags.lua` next to the lure (a different
  job).

## R2. Reading the aura

- **Decision**: `C_UnitAuras.GetPlayerAuraBySpellID(auraID)` per bonus, by the IDs of `GameData.CampBonuses`. A read
  happens only while auras are not restricted: not `InCombatLockdown()` and not `C_Secrets.ShouldAurasBeSecret()`
  (when that function exists). A table whose `expirationTime` is a plain number (`ns.IsSecret` checked) means active;
  nothing means not active; a table with a secret or missing `expirationTime` is a failed read and changes nothing.
  While restricted, no read: the kept state stands.
- The state per bonus: `known` (a read happened this session), `expires` (the game clock time, `GetTime()`'s, when
  the buff ends; nil when not active). **Active** = `known` and `expires` and `GetTime() < expires`: a buff that
  runs out during a fight ends by the clock, without a read.
- When to read: `PLAYER_ENTERING_WORLD` (login, `/reload`, a loading screen), `UNIT_AURA` for the unit `"player"`
  (its payload is not read at all, so its secret tables cannot hurt), `PLAYER_REGEN_ENABLED` (the fight's end),
  and at `FISHING_CAST_START` (a fresh value for the cast).
- **Rationale**: confirmed in game: the call returns nothing in a fight for a buff that is up, the `UNIT_AURA`
  payload is secret there, and `GetSpellAuraSecrecy` is 2 for both auras. Death needs no handler: the fight ends,
  the read sees the buff gone.
- **Alternatives**: reading the `UNIT_AURA` payload (`addedAuras`, by `spellId`): secret in a fight and no better
  than the read by ID; `AuraUtil.ForEachAura`: a walk for what one call answers; the placing cast
  (`UNIT_SPELLCAST_SUCCEEDED` 1307247): misses a party member's Rack.
- Open: that `expirationTime` is on `GetTime()`'s clock (the value seen, 87155.101, fits) is V64; the Hut's aura
  is V60.

## R3. Which casts count for a bonus

- **Decision**: `Camp` keeps, per cast ID, the **mask** read at `FISHING_CAST_START`: a number with one bit per
  active bonus (1 the Rack, 2 the Hut), or `false` when any bonus's state is not known. `Camp.CastMask(castID)`,
  called when the cast settles, reads the mask again and returns the start mask when both are known and equal,
  else 0. `CatchDB/Events.lua` and `Catch/Stats.lua` both call it for the cast they settle.
- **A kept mask lives until its cast settles, not until the next cast starts.** `Catch/Catch.lua` fires
  `FISH_MISSED` one second after the cast stopped, "also when the next cast already started: a quick recast must
  not hide the miss", so the mask of cast N is still asked after cast N+1 began. `CastMask(castID)` drops the
  masks of the casts before `castID` and keeps the asked one (two modules ask for it); a cast start only drops
  masks more than eight casts old, so the table cannot grow.
- **Rationale**: decision 17 (a doubtful cast counts for no condition), one rule in one place for the database and
  the statistics. A cast picked up after a `/reload` gets its mask at the pickup, like its place.
  `CatchDB/Events.lua` keeps its own casts until the settle for the same reason.
- **Alternatives**: dropping at the next cast start (misses followed by a quick recast would lose their mask: the
  miss rate under a bonus and the count of bonus casts would be too low); the mask at the cast's start only (a
  buff ending mid-cast would count; which moment the server uses is not known, V63); passing the mask in
  `FISH_CAUGHT` (it would change a message's payload for every listener).

## R4. The shape of a bonus part

- **Decision**: a cell gains `q = { ["<mask>"] = { c = catches, m = misses, i = { [itemID] = { catches, pieces } }
  } }`. The key is the mask written as a **string** (`"1"`, `"2"`, `"3"`): a table with the number keys 1, 2, 3
  could be taken for an array by the game's CBOR encoder and by its saved-variables writer (a missing key then
  comes back as a hole, which the harvest reads as a null entry); every other number-keyed table of a record has
  large keys (item IDs, area IDs). A string key has no such question and needs no in-game check.
  The parts of a cell are **disjoint** (a cast is in exactly one: the one of its mask) and **inclusive** (already
  in the cell's `c`, `m`, `i`). A cast under both buffs goes to the part of mask 3.
- A filter by one bonus sums every part whose mask has that bonus's bit, so a cast under both counts for both
  (decision 12); "No camp bonus" is the cell minus all its parts, each cast once.
- **Rationale**: two overlapping inclusive parts (one per bonus) cannot give "no bonus": the casts under both would
  be subtracted twice. Disjoint parts by mask make every filter a plain sum or difference, and a new bonus is a new
  bit, no new field. Misses are in (unlike the pool part), so the miss rate with a bonus is right.
- **Alternatives**: one part per bonus plus a part "both" (the same thing with more rules); the mask in the place
  key (refused by 1.4.0 clients' key check, the sender ignored); a virtual map ID (kept as the fallback of the
  investigation document, not needed while the split may be lost through old relays, decision 5).

## R5. Checks, the clean copy and old clients

- **Decision**: `CatchDB/Checks.lua` `CheckCell` learns `q`: a table of at most 8 parts; each key the decimal text of
  a whole number from 1 to 255 without a leading zero (`tostring(mask)`); each part's `c` and `m` are counts, its
  items pass `CheckItems(part.i, part.c)`; the parts' `c` sum to at most the cell's `c`, their `m` to at most the
  cell's `m`; every item of a part is in the cell, and the rest (the cell minus the parts) passes `CheckItems` too, as
  the open-water rest does for the pool part.
- The limit of 8 parts holds every combination of three bonuses (7); a fourth bonus would need a higher limit, and
  clients of this version would refuse a cell with more than 8 parts. Known and accepted: raise it with that
  bonus.
- A mask with bits this version does not know (4 and up) is valid: the part is kept and relayed (FR-012); the
  views count it for the bits they know, and "No camp bonus" leaves it out.
- `Exchange/Share.lua` `CleanCell` copies `q` (fresh tables of the same numbers). `tools/harvest.mjs` mirrors both
  (R15).
- **1.4.0 clients** (read from the code of 1.4.0): `CheckCell` reads only the fields it knows, so the record
  passes; `CleanCell` rebuilds the cell from a fixed field list, so `q` is dropped and the stripped record is
  relayed under the same `seq`. Totals right, the split lost on that path, nobody ignored (FR-011). The record's
  `seq <= casts` check is over `c + m`, untouched since the parts are inclusive.
- **Alternatives**: refusing unknown bits (a later bonus would get the senders of the newer version ignored by
  this one).

## R6. The filter in the sums

- **Decision**: the data filter gains a field: `filter.bonus` = `"all"` (default), `"none"` or a bonus key
  (`"rack"`, `"hut"`). `CatchDB/Views.lua` reduces a cell before it is added, like `ThroughWater`:
  - a key: `{ c, m, i }` summed over the parts whose mask has the key's bit;
  - `"none"`: the cell's `c`, `m`, `i` minus all parts;
    - both keep the cell's `a`; a key takes `k`, `r` and `x` of a seed cell from its parts (R15), `"none"` keeps
    the cell's `k` and drops `r` and `x` of a cell it reduces (as the water filter does); a cell without parts is
    read whole, `r` and `x` included, so a place without bonus data reads the same as under `"all"`.
- `CatchDB.FilterKey` becomes `range|source|water|bonus`; the catalog's `DefaultFilter` and `IndexFor` carry the
  field. Under a bonus filter the miss rate is shown (the parts have misses).
- `CatchDB.HasBonusData(key)`: whether the seed, the own counts or any held record has a part with that bonus's bit,
  at any place (no key: any part; FR-024); cached per key; it counts the held records only while sharing is on (the
  views read them only then) and only the parts with a known bit, so the button never shows over data no view uses.
  Unlike the pool cache, which forgets only a "no", it is dropped whole on every `SHARED_DATA_CHANGED`, at
  `ADDON_LOADED` and when the own catch writes a new part: a record with the only part may leave, and the button has
  to go with it (FR-027).
- **Water and bonus do not combine**: both are sub-counts of the same cell and the data do not hold their overlap.
  A filter with `bonus ~= "all"` reads `water` as `"all"`, and the UI offers one of the two (R8).
- **Rationale**: the weights, the players, the 50-catch threshold and the skill ranges all follow the reduced cell
  by themselves, as they do for water.

## R7. The tag and the chance with the bonus

- **Decision**: computed in `CatchDB/Views.lua` in **one pass over a scope**, with the scope fixed; no view fetches
  another. `CatchDB.Query` chooses its scope by the filtered catches (the spot from 50 on, else the map), so "the
  same scope under another filter" does not exist through the public query: a spot with 50 catches and 10 under the
  Rack would be compared with the map. And two views asking each other would recurse, the cache being written only
  after a build.
- **Summing.** While a scope is summed, `AddCell` sees the raw cell before it is reduced. Beside the filtered sum it
  fills:
  - under `bonus == "all"`: one sub-sum per bonus key that the scope's cells hold a part for, built from the same
    cells reduced by that key (the same weights, parts per player and threshold as any sum);
  - under a bonus key or `"none"`: `sum.rawAll[itemID]`, the item's unfiltered raw catches;
  - under any filter: per bonus key and item, **who** has the item under that bonus: the seed (a flag), the own
    catch, each other record's ID.
- **The tag of an item** (data-model.md, "A view item's bonus"):
  - **known**: the item is in `GameData.CampBonuses[...].items` (the twelve Bloated fish, the Rack's and, since
    R22, the Hut's too: `Camp.KnownBonuses` gives both keys). A known item carries a key in every view (FR-016);
    which one, when it has two, is R22's rule.
  - **from the data**, for a bonus: all the item's raw catches of the scope lie under that bonus (in an "all" view:
    its raw catches equal those in the bonus's sub-sum; in a key view: its filtered raw catches equal
    `rawAll`), **and** the seed holds it under that bonus or at least three different players do (the own catch
    one of them; `NEW_ITEM_REPORTERS`, FR-017). The highest-ranked bonus that holds wins (the Hut over the Rack,
    FR-018).
  - An item caught under the Rack alone and under the Hut alone, never without a buff, gets no tag from the data.
    Accepted (spec, edge cases).
- **In a view under a bonus key** the data tag is that key when the item's filtered raw catches equal `rawAll`
  (all its catches lie under this key, a mask-3 catch included) and the holders' rule holds; the rank does not
  matter there. So an item caught only under both buffs is the Hut's in an "all" view, the Rack's in a "rack" view
  and the Hut's in a "hut" view.
- **What the item carries**:
  - "all" view: `item.bonus = { key, chance, littleData, catches, players }` from the bonus's sub-sum built as a
    view of the same scope (`catches`: all catches of the scope under the bonus, the chance's denominator;
    `players`: those with a catch there under the bonus); a known item without data under its bonus: `{ key,
    littleData = true, catches = 0, players = 0 }`, no chance. A known item of two bonuses takes the one under
    which it has the most catches, else the lowest-ranked (R22).
  - a view under one of the item's own bonus keys: the same five fields from the view itself.
  - `"none"`, or a view under another bonus's key: only a known item is tagged, as `{ key, plain = true }` (`key`
    its first known bonus): the tag shows, the numbers are the ordinary ones of that view.
  - every tag of an item known to more than one bonus also carries `several = true` (R22).
- An untagged item has no `item.bonus` and its numbers are today's (SC-008).
- **The catalog** (`Catalog/Catalog.lua`) takes a place's `chance`, `littleData`, `catches` and `players` from
  `item.bonus` when the item has one that is not `plain`: the zone rows (`RebuildItems`), the spot rows
  (`Catalog.Spots`, built from `CatchDB.QueryCells`' views), `Catalog.Places`, the list rows, the order by chance,
  the tooltip lines and the minimap lines all use it; a place carries the whole `item.bonus` table as
  `place.bonus`. A known item with no chance is "Little data" everywhere a chance is written, never an empty cell,
  and its catches and players are 0, never nil.
- **In the rows** the tag is an icon (R19); `Catalog.ChanceText(chance, littleData, players, withBonus)` writes the
  number alone in a row's chance cell, and with `withBonus` the tooltip form, "0.47% with the bonus (3 players)"
  (the players' wrapper outside the bonus's), also in the "Caught in:" lines and the minimap lines.
- Under the source "Only mine" no item is tagged from the data (one player); the known items are.
- **Rationale**: the tag and its numbers come with the item wherever a view goes, and the catalog needs no third
  index (it keeps the default one and one other). Old catches with the bonus not known sit outside every part, so
  an item with any of them is never tagged from the data; that is why the known list exists (decision 11).
- **Cost**: per scope that holds parts, one more sum per bonus over the same cells; none for the others (today:
  none at all).
- **Alternatives**: fetching the bonus's view through `Query` (wrong scope, recursion); the tag in `Catalog` (the
  "catch here" tab reads `CatchDB.Query` directly and would need it twice).

## R8. The filter button

- **Decision**: one slot, one button. In both tabs the "Camp bonus" button sits where the Water button is and is
  shown when `HasBonusData()`; the Water button shows only with pool data and no bonus data. The menu offers "All
  catches", "No camp bonus", "Bonus catches only" (R20) and each bonus that has data, by their full labels
  (`Catalog.BonusLabel`). Its tooltip is the two agreed lines under the title "Camp bonus".
- **The button's text** (decision 23, after the first try in game): "Camp bonus: " with the value in short,
  `Catalog.BonusButtonText(value)`: "Camp bonus: All", "Camp bonus: No bonus", "Camp bonus: Bonus only", "Camp
  bonus: Rack", "Camp bonus: Hut". Each is a whole text, not `"Camp bonus: %s"` with a short label, so each language
  words the pair its own way (German "Lagerbonus: Nur Bonus", French "Bonus de camp : bonus seul"). The first
  build named the value alone ("Fishing Rack", and "Camp bonus" for all catches), which read as a list title rather
  than a filter.
- **Two rows** (decision 22): the filter buttons of both tabs stand in two rows, row A Skill and Source, row B the
  slot, Kinds and, in the catalog, Sort. The slot's buttons are made by `CatchHere.CreateWaterButton(parent, x, y,
  current, choose)` and `CatchHere.CreateBonusButton(parent, x, y, current, choose)` (both tabs);
  `CatchHere.UpdateFilterSlot(waterButton, bonusButton, water, bonus, nextButton)` shows the one the data call for,
  sets both texts, places `nextButton` (Kinds) right of the shown one or at the slot when none shows, and returns
  the water and the bonus the tab's filter keeps. Sort follows Kinds. A panel button grows to its text, so a longer
  translation pushes the next button along instead of being cut.
- The choice lives in memory per tab, like the Water filter; every login starts at "All catches" (decision 10). A
  value that is no longer offered falls back to "All catches" (FR-027).
- **Rationale**: decision 9 for the slot; a row of its own for the slot and Kinds leaves room for the value in the
  button's text, which one row of four or five buttons did not (the catalog's row was 551 of 560 pixels in French
  with three buttons of 150); the Kinds button of "What can be caught here" leaves its top right corner, so the
  place's line gets the full width.
- **Open**: that row B fits the tab in every language is a checklist step, with the French and German texts.

## R9. Percentages

- **Decision**: `ns.Percent(value)` (`Core/Data.lua`), the one formatter, with `p = value * 100`:
  `p >= 9.95` a whole number; `p >= 0.995` one decimal; `p >= 0.005` two decimals; `p > 0` the text `<0.01%`;
  `0` stays `0%`. The bounds are the rounding edges, so "10.0%" and "1.00%" never appear. The decimal sign is a
  point in every language, like the addon's other numbers.
- **Rationale**: decision 7; every chance and the miss rate already go through this function; the sort uses the
  exact values.
- **Alternatives**: a separate formatter for chances (two rules for one kind of number).

## R10. The notices

- **Decision**: notices are decided by a **check** that runs after every allowed read and when a timer comes due; the
  clock alone never shows one. `Camp` arms one timer per active bonus for `expires - 299` and one for `expires + 1`
  (`C_Timer.After`; a second past each threshold, so the timer's own check always finds the crossing); the timers run
  whatever fishing mode and the setting. A timer that comes due reads the aura when reads are allowed and then checks;
  while auras are restricted (a fight) it does nothing, and the read at the fight's end does the check.
- The check looks for two **crossings** per bonus, against what it saw last:
  - **five minutes**: the last check saw more than 300 s left (or the buff was first seen with more than 300 s),
    and now 300 s or less are left;
  - **ended**: the last check saw the bonus active, and a read now finds it gone (or its time passed).
- A crossing is **marked as passed** (`warned[key]`, `ended[key]` set to that `expires`) the moment it is found,
  whatever the mode and the setting. The notice is shown only when, at that moment, fishing mode is on and
  `settings.campBonusWarning` is on, and, for the five-minute one, when it is found within 30 s of the crossing (the
  timer's own check always is; a crossing found later, after a fight, is marked and stays silent). The end notice has
  no such window: an end found after a fight is shown when the mode is still on. So a player who enters fishing mode
  with 200 s left gets the end notice only, and a player who turns the mode on after the end gets none.
- A renewed buff (a later `expires` on a read) starts a new pair of crossings and cancels the pending end of the
  old one (FR-033): a party member's new Rack placed during a fight gives no false "has ended".
- With "Leave fishing mode when attacked" on (`exitOnCombat`, the default), `Fishing/Mode.lua` leaves the mode at
  the fight's end before `Camp` reads (it is registered earlier), so the end of a buff lost in a fight is marked
  and stays silent; with it off the end notice comes after the fight. Accepted and said in the spec (FR-033).
- `UI/Toast.lua` shows the message even with catch notifications off, like `SKILL_WARNING`.
- **Rationale**: decision 13, FR-031 to FR-033. A check of the state alone ("300 s or less left, not warned yet")
  would warn about "5 minutes" with 3 left after a fight or a late start of fishing mode.
- **Alternatives**: showing the end from the timer alone (wrong when the buff was renewed in a fight); reuse
  `SKILL_WARNING` (its second argument means "loud at the cap"); a check on every frame.

## R11. The setting

- **Decision**: `settings.campBonusWarning`, default `true` (`ApplyDefaults`), a row on the main settings page next
  to "Remind me about the next Fishing rank". Written by the page's row like the other plain toggles; no setter,
  since nothing has to react at the moment of the change.
- No `DB_SCHEMA` bump: an added key (and added fields in cells and statistics buckets, R4, R12).

## R12. Statistics

- **Decision**: a statistics bucket gains `bonusCasts` and `bonusCatches` (read as 0 when missing in a saved bucket).
  On `FISH_CAUGHT` and `FISH_MISSED`, `Stats` asks `Camp.CastMask(castID)`: a mask above 0 adds a bonus cast; a catch
  for which `Camp.IsBonusCatch(mask, items)` holds adds a bonus catch: since R22 an item of the known list of one of
  the mask's bonuses, or two loot slots or more once the fished quest items are left out. The statistics window shows
  the two rows in its three columns (session, current zone, total) when the total has a bonus cast. The window is laid
  out once with fixed offsets, so the two rows keep their place when hidden (a two-line gap at the end of the
  "Results" block) and the window grows by two lines (`HEIGHT` 700 to 736).
- **Rationale**: decision 14. Only the known list and the catch's own loot count (FR-034): `Stats` is layer 1 and
  cannot ask the views, and a number of the player's own must not change with other players' data. The first rule
  (the known list alone) left the Hut's bonus catches at 0 (R22).

## R13. Camper's Lure

- **Decision**: `GameData.Lures[291005] = { bonus = 60, order = 4, skill = 50 }`; Aquadynamic Fish Lens,
  Nightcrawlers and Shiny Bauble move to orders 5, 6, 7. Nothing else: `Fishing/Bags.lua` builds its order from
  the table, and the lure is a weapon enchant like the others (seen in game: `GetWeaponEnchantInfo` true, enchant
  8773, about 288 s).
- **Rationale**: decisions 3 and 8. The skill rule is the accepted V44 (the base skill is compared).

## R14. The debug report

- **Decision**: `Camp.Describe()` (English lines): per bonus its key, aura ID, the state (`active, N s left`,
  `not active`, `unknown`), whether reads are restricted now, and the mask of the last cast. The catch database
  section adds, for the current place, the own counts of each part (`mask: catches / misses`).

## R15. The bundled database

- **Decision**: `tools/harvest.mjs` learns `q` in `cleanCell`, `checkCell` (the rules of R5; the keys arrive as
  strings by themselves, and `luaTable` reads `["1"]`, `[1]` and a positional entry all as `"1"`, so a number key
  cannot be told apart there), `sumContributions` (parts summed per mask) and `cellLines` (written into `SeedData.lua`
  as `q = { ["1"] = { c = ..., m = ..., i = { ... } } }`). The harvest's check of the seed's own cells
  (`seedProblems`) reads only `a` today; it gains nothing.
- **`scaleCell` with parts** follows what it already does for the pool part ("rounding c, p.c and i on their own
  can leave more open catches of an item than of all"): each part is scaled alone (its `c` by `factor`, its `m` by
  `missFactor`, its items by `scaleItems` against its scaled `c`), the rest (the cell minus all parts) is scaled
  alone, and the cell's `c`, `m` and `i` are **built as their sum**. So no part exceeds the totals after rounding,
  the rest is never negative, and an item whose catches all lie in parts keeps exactly that property (the tag
  from the data survives the seed). `checkCell` runs on every scaled cell.
- **A seed part carries its own `k`, `r` and `x`**, by the rules the harvest uses for a cell, over the part's own
  contributions: `k` the contributors with a catch in that part, `r` its raw catches when the weights changed
  them, `x` its catches weighted by casts when they differ. `ThroughBonus` (R6) gives the reduced seed cell the `k`
  (the largest `k` of the summed parts, a lower bound like the cell's), `r` (the summed `r`, else `c`) and `x` of
  the parts it sums, so the players beside a bonus chance and the 50-catch threshold read the bonus's own
  numbers. "No camp bonus" keeps the cell's `k` (an upper bound: the data cannot split it) and drops `r` and `x`
  of a cell with parts, as the water filter does; a cell without parts keeps them (it is all "No camp bonus").
- **A cell with both a pool part and bonus parts**: a contribution's cell that has both loses `p` before it is
  scaled or checked (a record from before spec 011 with a pool part gains `q` at its next cast there), and
  `sumContributions` drops `p` from a summed cell that has `q`,
  scaled or not (one contribution's `p` beside another's `q` included). The overlap of the two is not in the
  data, nothing has written a pool part since spec 011, and the seed holds none.
- **Rationale**: decision 19, FR-014; "what a client accepts the next seed accepts too".

## R16. Record size

- **Decision**: no new limit, and no automated size test. A cell fished under a bonus lists its items twice (the
  totals and the part), so such a cell grows by roughly the size of its item table; the roll before a 501st place
  and the 32 KB per record stay as they are.
- **The size is read in game** (V67): the test stubs cannot measure it (their `CompressString` is the identity and
  their serializer is text, so any 500-place record is far over 100 KB there, with or without parts). The debug
  report already prints "own record offered: N bytes encoded for M places"; the checklist compares the bytes per
  place of a character that fished under a buff with one that did not. A record over the limit is not sent
  ("too large for a peer"), without an error.
- **If the measured growth is too large**: the roll counts a place with a part as two; decided with the measured
  number before the release, not before.

## R17. Globals and stubs

- `.luacheckrc` `read_globals`: `C_UnitAuras`, `C_Secrets`, added in the same task as the code that reads them
  (`npm run check` reports a declared global no file uses). `tests/wow.lua`: a stub `C_UnitAuras` with a table of
  auras by spell ID a test sets, a restricted switch, `C_Secrets.ShouldAurasBeSecret`.

## R18. Texts

- Nineteen new keys: the table "Wording for the feature" of the investigation document, counting the Rack's and
  the Hut's forms, without the setting's hint (the settings page's rows are `{ key, label }` and have no hint).
  In `Locales/enUS.lua` with nine translations. The Ukrainian texts are agreed, all of them, on 2026-11-19
  (`static/reports/camp-bonus-wording-ukUA.md`, outside the repository's checks); the others use the client's own
  names of the Fishing Rack, the Fishing Hut and the two auras in that language.
- The follow-up of 2026-11-20 adds eight keys: `Bonus catches only`, the five button texts of R8 and the two empty
  texts of R20, each with nine translations.
- The follow-up after the Hut session adds one key, "Bonus catch: comes only with the buff of a Fishing Rack or a
  Fishing Hut." (R22), with nine translations.
- The debug lines and the game data comments stay English.

## R19. The tag in a row

- **Decision**: the tag is a 14-pixel **icon** at the right end of the row's name column: the item icon of the
  camp feature (`C_Item.GetItemIconByID` of `GameData.CampBonuses[...].item`: 279965 the Fishing Rack, 279966 the
  Fishing Hut), by ID, the same in every language (V66). The name's width shrinks by the icon's on a tagged row.
  The chance cell shows the number alone.
- **The words come from one helper**, `ns.AddBonusLines(tooltip, bonus)` in `UI/Widgets.lua`: the tag's name
  (`Catalog.BonusTag`, its colour also as a code in the text: R22), the explanation (`Catalog.BonusTip(bonus.key,
  bonus.several)`) and, unless the tag is `plain`, the chance with the
  bonus and its players (`Catalog.ChanceText(..., true)`). Every row kind calls it from its own `bonus` table:
  - an item row ("What can be caught here", the catalog's list): through `ns.ShowItemTooltip(owner, itemID,
    withPrice, bonus)`, after the game's item lines;
  - an "Unknown item" row of "What can be caught here": in its own tooltip branch, after its lines;
  - a zone or spot row of the catalog (a place tooltip, `ShowPlaceTooltip`): after the catches line.
  They show whatever `settings.tooltipChances`, and never disagree with the row (FR-019). The catalog's list rows
  carry `players` for it (`Catalog.Items`).
- **No doubled line**: the game runs the item post call inside `GameTooltip:SetItemByID` (Mainline; not
  confirmed in Forever), so `ns.ShowItemTooltip` sets what it keeps **after `SetOwner` and before
  `SetItemByID`**, on every call: `{ owner, itemID }` with a bonus, nil without one (the settings rows and the
  statistics' top catches call it too). `ns.TooltipHasBonus(tooltip, itemID)` is true only when something is kept,
  `tooltip == GameTooltip`, `tooltip:GetOwner() == kept.owner` and the item matches, so a later bag or link
  tooltip of the same item (another owner) gets its line. A `GameTooltip:HookScript("OnHide", ...)` clears it.
  `UI/ItemHooks.lua` adds no explanation line to such a tooltip.
- When the game rebuilds an item tooltip for an item it was still loading (`TOOLTIP_DATA_UPDATE`), the lines
  `ns.ShowItemTooltip` added after the item's own are lost, as the price line is today; a checklist step notes it.
- Elsewhere in the game (bags, links) the item hooks add the explanation line under "Caught in:" from
  `Catalog.TooltipLines`' second value (the best place's `bonus`), under the same setting as those lines. The
  catalog's list and the item tooltip follow the item's best place; each zone and spot row shows its own tag
  (spec, edge cases).
- **Rationale**: the chance columns are 90 and 70 pixels and the name columns 220 ("What can be caught here"; since
  2026-11-20 the chance column there is 110 and the name 195, for French "Peu de données"; the catalog's zone and
  spot rows likewise: chance 110, name 230), 270 (the
  catalog's zone and spot rows) and 350 (its list), without word wrap:
  "0.47% with the bonus (3 players)" and "Bloated Mithril Head Trout" plus "Fishing Rack bonus" do not fit, less
  so in German or French.
- **Alternatives**: a second text line per row (the rows have one fixed height); a coloured chance with no mark
  (colour alone says nothing).

## R20. "Bonus catches only"

- **Decision** (decisions 24 to 26, 31): a value `"bonusOnly"` of the Camp bonus filter, after "No camp bonus",
  offered whenever the filter shows. It is a **filter of the list** over "All catches", like the kinds: it keeps the
  items whose `item.bonus` is not `plain` (the known Bloated fish, which always carry a tag under "all", and the
  items tagged from the data), Rack and Hut alike. Every number is the one of "All catches": the counts line, the
  miss rate, and each row's chance with the bonus.
- **Where it is applied**: "What can be caught here" queries with `CatchHere.QueryBonus(value)` (`"all"` for
  `"bonusOnly"`, else the value) and narrows the view's items with `CatchHere.BonusItems(items, value)` before
  `Catalog.Group`. The catalog's `IndexFilter` maps `"bonusOnly"` to the filter of `"all"` before `FilterKey`, so it
  shares the index of "All catches" (no third index, nothing new in `Catalog.Describe`), and `Catalog.Items` drops the
  untagged rows; `Places` and `Spots` read the same index, so an item's page shows all its zones (decision 31).
  `CatchDB` never sees the value: `FilterKey` and the views stay as they are.
- **Empty lists** (decision 26): "What can be caught here" says "No bonus catch has been recorded here yet." when
  the view has items and none is tagged (`page.message`); the catalog's status line says "No bonus catch has been
  recorded yet." when no row is left and there is no search text. The kind filter's own messages come first when it
  hides tagged rows.
- **Rationale**: the author's wish after the first try was "show me the bonus fish", not the casts under a buff:
  under "Fishing Rack" every fish of those casts is listed, by design. A list filter answers it without a new sum,
  a new index or a new cache key, and the numbers stay those the player knows from "All catches".
- **Alternatives**: one value per bonus ("Rack bonus catches only", "Hut ..."): more values for a list that holds a
  handful of items, rejected (decision 25); the tag rule applied inside `CatchDB` as a view filter: a new cache key
  and index for the same items, rejected.

## R21. The layout of "What can be caught here" and the catalog

- **Decision** (decisions 27 to 30): "What can be caught here", from the top: the place (one line, the full width),
  the scope line, the hints (`page.hint`, up to three lines, their room always kept), the exchange line
  (`page.status`), the counts, row A, row B, the column headers and the list. The y offsets are constants in one
  place at the top of `UI/CatchHere.lua`. The catalog: the search box, the status line (`page.status`, two lines),
  row A, row B, the list; on an item's page the status line sits where the zones begin.
- **The scroll list**: `ns.CreateList(parent, top, initialize)` moves from `UI/CatalogTab.lua` to
  `UI/Widgets.lua` unchanged: a `WowScrollBoxList` with a `MinimalScrollBar`, or, when the templates are missing
  (`pcall`), a fixed pool of rows with "and N more" (kind headers not counted, never a header on the last row).
  "What can be caught here" uses it in place of its 16 fixed rows; its row initializer draws the row as before
  (icon, columns, tag, kind header, unknown item, tooltip, click to the catalog), and `page.more` is gone. The tests
  read the rows of either list through `list_rows(list)` (`tests/wow.lua`).
- **Per catch** (decision 27): `ns.FormatCount(value)` (`Core/Data.lua`): rounds to tenths; a whole result is
  written with `%d`, another with `ns.FormatDecimal(value, 1)`, the client's decimal separator. 1 -> "1", 1.04 ->
  "1", 1.25 -> "1.3", 1.5 -> "1.5" ("1,5" with a comma separator).
- **Rationale**: a scrolling list has no fixed bottom for the hints and the exchange line, so they go to the top,
  where they are read with the counts they explain, in a room of fixed height so nothing below them moves. A scroll
  list shows every item of a place with many kinds, as the catalog's already did, and one list serves both tabs.
  "1.0" per catch is the common case and only noise.

## R22. Follow-up after the Hut session (decisions 32 to 34)

The session of 2026-11-20 ([docs/fishing-investigation.md](../../docs/fishing-investigation.md), "The Fishing
Hut"): the Hut's extra item is a second loot slot from a mixed table (Bloated fish, Blindweed 8839, Mithril Bar
3860, Iron Ore 2772, Heavy Hide 4235, Dream Dust 11176); the Hut gives Bloated fish too; "Bonus catches" stayed 0
under the Hut, whose known list was empty; the addon's cyan lines in the catalog's item tooltips sometimes showed
white.

- **Decision 32, the Bloated fish under both bonuses**: `GameData/CampBonuses.lua` has one local table `BLOATED`,
  the `items` of both entries. `Camp.KnownBonuses(itemID)` (replacing `Camp.KnownBonus`) gives the keys of the
  bonuses whose list names the item, in rank order, or nil. The tag in `CatchDB/Views.lua` (`Tag`):
  - in an "all" view a known item takes, among its bonuses, the one under which it has the most catches in the
    view's scope, its numbers from that bonus's sub-view; with no catch under any, the lowest-ranked (the Rack:
    the cheapest way to get it), `{ key, littleData = true, catches = 0, players = 0 }`;
  - in a view under a bonus key, a known item of that key carries the view's own numbers; a known item not of that
    key, or under `"none"`, is `{ key = known[1], plain = true }`;
  - every tag of an item known to more than one bonus carries `several = true`, carried to the catalog's places
    and rows with the rest of the table; `Catalog.BonusTip(key, several)` then gives one text naming both camp
    features ("Bonus catch: comes only with the buff of a Fishing Rack or a Fishing Hut.").
  The Hut's other extras are not listed: they are ordinary items elsewhere (Iron Ore is mined, Blindweed picked)
  and the data tag them by R7's rule (all raw catches of the scope under the bonus, and the seed or three players).
- **Decision 33, a bonus catch**: `Camp.IsBonusCatch(mask, items)` with a mask above 0 holds when a catch has a
  known item of one of the mask's bonuses, or two loot slots or more once the quest items fished beside an ordinary
  catch are left out (`FISH_CAUGHT`'s items are one entry per loot slot). The quest items are
  `GameData.FishedQuestItems`: `classID = 12` (`Enum.ItemClass.Questitem`, any item of the quest class, by
  `C_Item.GetItemInfoInstant`) and `items` (Electropeller 6718, Nat Pagle's fish 16967 to 16970, Dezian Queenfish
  19806, Speckled Tastyfish 19807; most are of class 15, so the class alone misses them).
  - **Evidence**: without a buff a catch had one slot in open water and in a pool (2026-11-19); pools, schools and
    floating wreckage give one item (a quantity in one slot, or a trunk opened later); only fished quest items come
    as a second slot without a buff (warcraft.wiki.gg, "Nat Pagle, Angler Extreme": "As well as looting the quest
    fish, you will loot another fish or item"; classicdb, quest 1580, on Electropellers: "always in the same loot as
    some other fish"). The bundled seed agrees: 43 of 525 places have more item catches than catches, 306 extra
    slots in 33951 catches (0.9 %), and the large ones follow the quest items (Darkshore 1439:1:47: 24 extra, 24
    Electropellers; Feralas 1444:3:65: 16, Feralas Ahi; Swamp of Sorrows, Desolace, Stranglethorn likewise).
  - Marked `-- VERIFY(V68): without a camp buff a catch has one loot slot, quest items aside` (verification.md).
  - Old statistics are not recounted: the Hut session's 0 stays.
- **Decision 34, coloured lines**: `ns.ColoredText(text, r, g, b)` (`Core/Data.lua`, moved from `UI/Minimap.lua`'s
  local `Colored`) wraps a text in its colour code; `ns.AddColoredLine(tooltip, text, r, g, b, wrap)`
  (`UI/Widgets.lua`) adds the line with the coded text and the colour arguments. Used for the tag's name in
  `ns.AddBonusLines`, "Caught in:" and the two fishing gear lines in `UI/ItemHooks.lua`, the grey "(few lots)" price
  line in `Prices.AddTooltipLine`, and the minimap tooltip's lines. The codes wrap the translated text, never inside
  an `L[...]` string.
- **Rationale**: the Hut's extra slot is the bonus the player sees; the slot count is the player's own loot, so the
  statistics stay layer 1 and independent of other players' data. A Bloated fish is the same item under either
  bonus; the bonus that gave it most often at a place is the one whose chance means something there. The colour code
  survives whatever resets the line colours, as the minimap tooltip showed (spec 012 R5).
- **Alternatives**:
  - the known list only, with the Hut's items listed (Q1): rejected, the herbs, ore, bars, hides and dust are
    ordinary items elsewhere, so a list would tag them wrongly at every other place;
  - slots without exceptions: rejected, the quest fish come as a second slot without a buff;
  - the tag always of the higher bonus: rejected, a water fished only with the Rack would read "Little data" under
    the Hut's tag;
  - two tag lines, one per bonus: more code and tooltip room for the same fact, rejected;
  - finding the addon that resets the colours first: rejected, the code fix works whatever resets them.
