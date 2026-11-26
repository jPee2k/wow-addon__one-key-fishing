# Luremaster: research

Pre-spec research for spec 028 (2026-11-26). Luremaster is a Legacy talent: "While fishing with a Lure active, you
have a 25% chance to catch an extra fish" (rank 1), 50 % at rank 2. The extra fish raises what a player brings home
with a lure on, so the catch data of players with and without the talent no longer compare: the pieces per catch,
the gold per hour, and the camp bonus count of spec 020 (section 2). The feature keeps the shared numbers clean and
shows the talent's part on its own.

Sources are marked: **[Data]** the game's DB2 tables from wago.tools, product `wowf`, build 1.60.1.71139
(2026-11-25); **[Client]** the author's interface export (build 1.60.1.70685, see
[forever-api.md](forever-api.md)); **[Addon]** this repository; **[Game]** seen by the author in play, not yet
checked step by step. Wowhead's Forever page for the spell refused the request (HTTP 403), so nothing comes from
there.

## 1. The talent in the game's data

- **[Client]** Legacy is an account-wide talent system of three C_Traits trees in trait system 45
  (`Blizzard_LegacySystem/`, `Constants.LegacyConsts` in `LegacyConstantsDocumentation.lua`):
  `LEGACY_TREE_PROFESSIONS_ID` 1187, `LEGACY_TREE_ADVENTURE_ID` 1188, `LEGACY_TREE_PROGRESSION_ID` 1189. It also has
  a renown track (faction 2802) and the "Legacy Challenges" achievements.
- **[Data]** The points are trait currency 4225, shared by the three trees (`TraitTreeXTraitCurrency`).
  `TraitCurrencySource` lists 131 sources: a class's first level 25, 45 and 60, crafting professions at 150, 225 and
  300, dungeons and raids, PvP ranks, exalted battleground reputations, Explore Azeroth, "Play in the WoW: Forever
  Beta". None is about fishing. The author has rank 1 and cannot buy rank 2 yet.
- **[Data]** Luremaster: `TraitDefinition` 141612 -> `TraitNodeEntry` 136849 (MaxRanks 2) -> `TraitNode` **110293**
  in tree 1187, the bottom row. It sits in node group 12441 with Performance Bonus, Master Chef and Bartering; that
  group needs 5 points spent in group 12440 (the tree's seven other real nodes). It is the only fishing node in the
  tree. An unused older definition, 135546, points to the same spell.
- **[Data]** **One spell for both ranks: 1225455.** The value comes from `TraitDefinitionEffectPoints` 24323, curve
  97516: rank 1 = 25, rank 2 = 50 (the client's tooltip value 50 noted in
  [fishing-investigation.md](fishing-investigation.md) is the spell's base value, not the rank 1 chance).
- **[Data]** The effect (`SpellEffect` 1214653) is `APPLY_AURA` with aura 4, `SPELL_AURA_DUMMY`, base points 50;
  trigger spell, misc value and class mask are 0, and `SpellMisc`, `SpellAuraOptions`, `SpellAuraRestrictions` have
  no rows. **The server alone adds the extra fish**: no proc spell, aura or combat log event shows it to the client.
- **[Client]** The rank at runtime, as Blizzard's Legacy UI reads it:
  `C_Traits.GetNodeInfo(C_Traits.GetConfigIDByTreeID(1187), 110293)` gives `activeRank`, `currentRank`,
  `ranksPurchased`. `IsPlayerSpell(1225455)` / `C_SpellBook.IsSpellKnown` likely tell "has it" from "has not", not
  the rank. Not tried in game.
- **[Game]** The author's observation: a fish comes as **the same slot with quantity 2**; a junk crate comes as **two
  slots of the same item**. To be checked step by step (section 5).

## 2. What the addon does today

- **[Addon]** One loot window is one catch: `FISH_CAUGHT(items, castID)` carries every slot
  (`Catch/Catch.lua:26-48`). `Catch/Stats.lua` adds 1 to `catches` and each slot's quantity to `items[itemID]`.
- **[Addon]** A catch database cell holds `c`, `m`, `t` and `i[itemID] = {catches with the item, pieces}`;
  `CatchItems` sums one loot's quantities per item (cap 20, `MAX_PIECES`). **The chance is per catch**
  (`entry[1] / c`, `CatchDB/Views.lua:635`), so an extra piece of the same item leaves the chance unchanged and
  raises only the pieces per catch.
- **[Addon]** Gold per hour (`Catalog/BestPlaces.lua`) is the sum of chance x pieces x price times the catches per
  hour: **the extra fish raises it**, and the best places then mix players with and without the talent.
- **[Addon]** `Camp.IsBonusCatch` (`Fishing/Camp.lua:233-251`) counts any catch with two or more non-quest slots as a
  camp bonus catch. A Luremaster crate of two slots under a camp buff counts as a camp bonus today. The Hut casts of
  [fishing-investigation.md](fishing-investigation.md) were made with Camper's Lure on, so some of them may have been
  Luremaster.
- **[Addon]** Camp bonus masks (spec 020): bit 1 Rack (aura 1280341), bit 2 Hut (1280342), "the next bonus takes 4"
  (`GameData/CampBonuses.lua:29-33`). A cast's mask is read at its start and counted only if unchanged at its settle;
  `Camp.Mask()` returns nil when a state is unknown, and such a cast goes into no part. `CatchDB/Checks.lua` allows 8
  parts with masks 1-255, unknown bits included.
- **[Addon]** "No camp bonus" is the cell minus all parts, unknown masks included (`CatchDB/Views.lua:127-157`). A
  1.6.x client would therefore drop every cast with bit 4 from that view.
- **[Addon]** `Exchange/Share.lua` `CleanCell` keeps only `c, m, t, px, py, i, p, a, q`; `tools/harvest.mjs` does the
  same. A new cell field must be added to both and to the checks; an older client drops it and relays the totals
  only (as a 1.4.0 client drops `q`). The cells on the wire carry no format version.
- **[Addon]** Nothing records whether a lure was on at a cast: `Bags.NeedsLure()` is only
  `not GetWeaponEnchantInfo()`, used to apply one.

## 3. What can be on a fishing pole

- **[Data]** Temporary enchants (`SpellEffect` effect 54) that fit a pole (item subclass 20, or any weapon with the
  two-hand inventory type): every lure; Consecrated Weapon 28891 and 1224422 (sharpening stone); every Wizard and
  Mana Oil (25117-25123); Blessed Wizard Oil 28898 and 1224410; Enchanted Repellent 1214004. Sharpening stones,
  weightstones, poisons and shaman imbues do not fit. Whether those items exist in Forever is not known. **So "the
  pole has an enchant" does not mean "a lure is on".**
- **[Data]** No Enchanting weapon enchant fits a pole (2H enchants mask 0x562, Crusader 0x2e5f3). The one permanent
  enchant that does is Eternium Fishing Line (spell 24302, enchant 2603); permanent enchants do not show in the
  temporary enchant call.
- **[Client]** `GetWeaponEnchantInfo()` is defined in `Blizzard_Deprecated/Shared/Deprecated_12_1_0.lua:44` over
  `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)`; its fourth value is the main hand's enchant ID. It works in
  game (enchant 8773 seen), though the deprecated files should need `loadDeprecationFallbacks`; why is unknown. The
  namespaced calls are `C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_MAINHAND)` (`.enchantID`) and
  `C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.MainHand)` (`enchantType`, `enchantID`).
- **[Data]** The lures and their enchant IDs, a complete set in this build:

| Item | Spell | Enchant | Bonus | Duration |
|---|---|---|---|---|
| 6529 Shiny Bauble | 8087 | 263 | +25 | 600 s |
| 6530 Nightcrawlers | 8088 | 264 | +50 | 600 s |
| 6811 Aquadynamic Fish Lens | 8532 | 264 | +50 | 600 s |
| 6532 Bright Baubles | 8090 | 265 | +75 | 600 s |
| 7307 Flesh Eating Worm | 9092 | 265 | +75 | 600 s |
| 6533 Aquadynamic Fish Attractor | 8089 | 266 | +100 | 300 s |
| 291005 Camper's Lure | 1331725 | 8773 | +60 in game | 300 s |
| 259846 Wide-Brimmed Fishing Hat (use) | 1265220 | 263 | +25 | |

  "Secret" Bait 268880 casts 8087 too (enchant 263). The hat is not in `GameData/Lures.lua`.

## 4. The author's decisions, 2026-11-26

The interview went as a quiz; the recommended answer was taken unless the decision says otherwise.

- **L1. Goal**: all of it. The chances and the shared numbers are clean of the extra fish, gold per hour compares
  between players with and without the talent, and the talent's part shows on its own.
- **L2. Model**: separate the extra fish itself, as seen in the loot, rather than divide by an expected 1.25 or 1.5.
- **L3. Order**: spec 028, right after 027 and before 025 (each day without it adds unmarked casts to the shared
  data).
- **L4. Old data** stays as it is: no new seed epoch, no reset. The camp bonus catches counted before the fix stay
  too; only new catches are counted the new way.
- **L5. A spike in game first**, then the spec on its facts (section 5). The author has rank 1 only.
- **L6. The rank**: `C_Traits.GetNodeInfo(GetConfigIDByTreeID(1187), 110293).activeRank`; when the config cannot be
  read, `IsPlayerSpell(1225455)` as "has it, rank unknown". Read out of combat, kept, refreshed when the talents
  change.
- **L7. Fix `Camp.IsBonusCatch` in 028**: a camp bonus is a second slot of a **different** item; a repeated item is
  Luremaster's.
- **L8. Quantity 2 of the same item**: the chance stays the item's per catch; the pieces per catch lose the actual
  extra pieces (L10, L11).
- **L9. A tag like the Rack's and the Hut's**: "Luremaster" joins the bonus filter, and the rows of items that come
  doubled carry the talent's icon, their tooltip "N pieces base, +M with Luremaster". The chance shown stays the base
  one.
- **L10. Storage**: camp mask **bit 4** = "a lure on the pole and Luremaster rank 1 or more" at the cast's start (a
  condition, like the camp buffs, for the filter), **and** a new counter of the extra pieces per item, so the base
  pieces and gold stay clean. Cost accepted: older clients relay the totals only, and three bits take 7 of the 8
  parts the checks allow.
- **L11. A proc is read from the loot shape** (`VERIFY`): under bit 4, an item's quantity 2 in one slot or the same
  item in two slots is a proc, and the extra is the half. Rack, Hut and Luremaster must not mix (L7, L17).
- **L12. Rank 2**: accepted without a check in `verification.md`. The author expects it to raise the chance, as its
  tooltip says, not the quantity; the base is counted from the loot either way, not from the rank.
- **L13. Shared views under "All catches"** (catalog, "What can be caught here", best places): the base pieces and
  gold per hour. Under the "Luremaster" filter: with the extra. The player's own statistics: the real amounts, with a
  "Luremaster" line.
- **L14. Unknown state** at a cast (the Legacy config not ready after login, the lure not readable): as the camp
  buffs, the cast goes into no part. Its extra pieces are still taken out when the lure and the loot shape show them.
- **L15. "No camp bonus"** means no Rack or Hut bit, with or without bit 4 (its pieces the base ones). Older clients
  (1.6.x) show that view thinner for Luremaster casts: accepted, the changelog asks players to update.
- **L16. "A lure is on"**: the pole's temporary enchant ID is one of the lure set (263, 264, 265, 266, 8773; kept in
  `GameData/Lures.lua`), not "any enchant" (section 3: oils and stones fit a pole too). The spike checks whether
  Luremaster works with Camper's Lure and never without a lure.
- **L17. Where it shows**, besides the filter and the tag:
  - the statistics window: "Luremaster: N procs, +M fish, +X gold" for the session and in total, like the camp rows;
  - `/okf debug`: the rank and where it was read from (C_Traits, the spell, unknown), the lure's enchant ID, the
    last loot shapes;
  - a toast when fishing mode starts, with the talent learned and no lure on the pole or in the bags (with one in
    the bags the key applies it anyway); a setting turns it off.
- **L18. Out of 028**: the Wide-Brimmed Fishing Hat as a lure source for the key goes to the roadmap; its enchant
  (263) already counts for L16.

## 5. In-game checks for the spike

To be written as a checklist in `docs/checklists/` before the spec:

1. The rank calls of L6 out of combat, right after login and after a `/reload`, before and after the Legacy window was
   opened; what `IsPlayerSpell(1225455)` answers.
2. The fourth value of `GetWeaponEnchantInfo()` with each lure at hand, Camper's Lure included.
3. The loot shape of a proc (rank 1, a lure on): a fish (one slot, quantity 2?), a crate or another container (two
   slots of the same item?), a quest item, a pool.
4. No lure: no quantity 2 and no repeated item over a series of casts (the procs need a lure).
5. Under the Rack and under the Hut, without a lure and with one: the camp's extra is always a different item; a
   repeated item happens only with a lure.
6. Whether a proc leaves any trace besides the loot (a chat line, a loot message, an aura).
