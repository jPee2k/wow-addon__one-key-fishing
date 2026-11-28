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
  Beta". None is about fishing. The author has rank 1 and cannot buy rank 2 yet. **[Game]** Rank 1 was bought on
  2026-11-25 or 2026-11-26: every catch before it, the Rack and Hut sessions of 2026-11-19 and 2026-11-20 in
  [fishing-investigation.md](fishing-investigation.md) included, was made without the talent.
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
- **[Client]** The addon needs none of Blizzard's Legacy UI: `Blizzard_LegacySystem` is `LoadOnDemand` (`AllowLoadGameType:
  camelot`), and `C_Traits` is native (`Blizzard_LegacyTree.lua:75` calls `GetConfigIDByTreeID` the same way).
  `GetConfigIDByTreeID` and `GetNodeInfo` are `MayReturnNothing` (the unknown state of L14); `TraitNodeInfo` carries
  `activeRank`, `currentRank`, `ranksPurchased`, `maxRanks`. Events for a change: `TRAIT_CONFIG_UPDATED(configID)`,
  `TRAIT_NODE_CHANGED(nodeID)`, `TRAIT_TREE_CHANGED(treeID)`, and `TRAIT_CONFIG_LIST_UPDATED` (likely when the
  configs become readable after login).
- **[Client]** `IsPlayerSpell` is a deprecated wrapper (`Blizzard_DeprecatedSpellBook`) over
  `C_SpellBook.IsSpellKnown(spellID, Enum.SpellBookSpellBank.Player)`, loaded only with the CVar
  `loadDeprecationFallbacks`; the namespaced call is the one to use (`Core/Data.lua` already prefers it).
- **[Data]** The spell's text is one for both ranks: "While fishing with a Lure active, you have a $s1% chance to
  catch an extra fish." (`Spell` 1225455, build 1.60.1.71139, still the latest on 2026-11-27). The rank changes
  `$s1` only, as L12 expects.
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
  [fishing-investigation.md](fishing-investigation.md) were made with Camper's Lure on, but before the talent was
  bought (section 1), so none of them was Luremaster: the camp's extra as a second slot of a different item stands.
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
  game (enchant 8773 seen). That file has no `AllowLoadGameType` tag (it loads in every game type) but returns early
  without the CVar `loadDeprecationFallbacks`, so the CVar is likely on in Forever (to confirm in the spike); the
  addon should not depend on it. The namespaced calls are `C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_MAINHAND)`
  (`{ enchantID, remainingTimeMs, chargesRemaining, hasExpirationTime }`, nothing when no temporary enchant is on) and
  `C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.MainHand)`, which returns a **table** of
  `{ hasEnchant, enchantType, timeLeft, charges, enchantID, enchantIconID }` (as `BuffFrame.lua:766` reads it). A
  change fires `WEAPON_ENCHANT_CHANGED` (and `UNIT_INVENTORY_CHANGED`, which `Fishing/Bags.lua` already uses).
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

The checklist is [checklists/luremaster.md](checklists/luremaster.md) (2026-11-27): four sessions of about 30
minutes at one spot of open water (A no lure and no camp, B an ordinary lure, C the Hut without a lure, D the Hut
with Camper's Lure), the loot recorded by a throwaway logger addon (OKFSpike, outside the repository). The Rack is
left out: its extra came twice in about two hours (too few for 30 minutes), and the Hut gives its Bloated fish too.
The steps:

1. The rank calls of L6 out of combat, right after login and after a `/reload`, before and after the Legacy window was
   opened; what `IsPlayerSpell(1225455)` answers.
2. The fourth value of `GetWeaponEnchantInfo()` with each lure at hand, Camper's Lure included.
3. The loot shape of a proc (rank 1, a lure on): a fish (one slot, quantity 2?), a crate or another container (two
   slots of the same item?), a quest item, a pool.
4. No lure: no quantity 2 and no repeated item over a series of casts (the procs need a lure).
5. Under the Rack and under the Hut, without a lure and with one: the camp's extra is always a different item; a
   repeated item happens only with a lure.
6. Whether a proc leaves any trace besides the loot (a chat line, a loot message, an aura).
7. `GetCVar("loadDeprecationFallbacks")`, and how long after login `C_Traits.GetConfigIDByTreeID(1187)` stays nil.
8. Whether Luremaster procs with Camper's Lure (enchant 8773) as with an ordinary lure (L16).

## 6. Spike results (2026-11-27, enUS, build 1.60.1.71139)

Riverglades, Eastwind Shore (map 2548, 76.1 / 66.9), open water, Fishing 300, Big Iron Fishing Pole (6367).

- **[Game] The rank** (steps 1, 7): `GetConfigIDByTreeID(1187)` gives config 1539346 and `GetNodeInfo(...,
  110293)` `activeRank 1`, `currentRank 1`, `ranksPurchased 1`, `maxRanks 2`, without Blizzard's Legacy UI loaded
  and the same with it loaded. At login the config is nil at `ADDON_LOADED` and readable from
  `TRAIT_CONFIG_LIST_UPDATED` on (4 to 6 s later, three logins); after a `/reload` it is readable at once.
  `C_SpellBook.IsSpellKnown(1225455)` and `IsPlayerSpell` are true; `loadDeprecationFallbacks` is 1.
- **[Game] The lure** (step 2): Bright Baubles gives enchant 265 in both `C_PaperDollInfo.GetTemporaryEnchantmentInfo`
  and `GetWeaponEnchantInfo`. `remainingTimeMs` read 597 s right after a lure applied by hand, but **0** for every
  lure the fishing key applied, still 0 minutes later while the buff frame showed 5 minutes left: the time left is
  not to be trusted, the enchant ID is. `WEAPON_ENCHANT_CHANGED` fires when a lure runs out.
- **[Data]** Every lure enchant (263, 264, 265, 266, 8773) has two equip-spell effects: its skill bonus (8082 to
  8085; 1331727 for Camper's Lure) and the same spell **1277246 "Fishing Lure"** (`APPLY_AURA`, `SPELL_AURA_DUMMY`,
  base 25, no text, cast by nothing else): most likely the "Lure active" that Luremaster checks, the same for every
  lure. **[Game]** `C_UnitAuras.GetPlayerAuraBySpellID(1277246)` returns nothing with a fresh lure on: the client does
  not see that aura.
- **[Game] Session B** (Bright Baubles, no camp, 21:43 to 22:10): 74 casts, all with the lure on, 70 catches, 4
  without loot. **Every catch was one slot of quantity 1** (Raw Rockscale Cod 29, Firefin Snapper 19, Oily Blackmouth
  11, Raw Spotted Yellowtail 11) **and one "You receive loot" line**; no second item pushed to the bags, no aura, no
  other spell. At 25 % about 17 procs were expected; none came (0.75^70 is about 2e-9). So with an ordinary lure at
  rank 1 the talent shows nothing in the loot or the chat.
- **[Game]** The node is active as the client sees it: `isAvailable true`, `meetsEdgeRequirements true`,
  `isDisplayError false`, `activeEntry.rank 1`, committed entry 136849; the tree holds 6 points (5/5 above, 1/2
  Luremaster); the skill modifier is 0 (no Master Forager).
- **[Addon] Pieces per catch in the stored data** (the author's `OneKeyFishing.lua`, 2026-11-27: `shared.mine` and
  the records of other players; pieces over catches per cell, split by the camp parts `q`). Items that come stacked
  by nature (Stranglekelp 3820, Stonescale Eel 13422, the rums 21151 / 21114 / 20709, Elemental Water 7070) are left
  out. Ordinary fish:
  - **The author's own catches have extra pieces only under a camp bonus**, most of them before the talent was
    bought: Moonglade under the Hut (2026-11-20, confirmed by the author) Raw Redgill 100 pieces in 97 catches, 28/28
    without it; map 2652 under the Rack, Raw Mithril Head Trout 97/87 and Bristle Whisker Catfish 53/49, 2/2
    without it; Tanaris under the Hut, Firefin Snapper 32/29, Spotted Yellowtail 23/21, Oily Blackmouth 12/11, every
    fish 1:1 without it. **So a camp bonus gives a repeated item too**, not only a different one: L7 ("a repeated item
    is Luremaster's") does not hold as written.
  - Record `zvz4sx7p@11` (Tanaris, Feralas, map 2482): nearly every extra piece under the Hut, at a far higher rate
    (Oily Blackmouth 65/47, Firefin Snapper 82/62 and 45/33, Sunscale Salmon 62/53, crates 21228 50/39: about +30 %
    against the author's +3 to +11 % under a camp). Fitting Luremaster with Camper's Lure on top of the camp's own
    extra, but nothing in a record says which lure or talent was on.
  - Record `x6nxstvo@12` (Tanaris): extra pieces with no camp part at all (Firefin Snapper 19/16, 12/9); its client
    may predate the camp parts (1.5.0), so whether a camp was up is unknown.
  - The stored pieces cannot tell one slot of quantity 2 from the same item in two slots (`CatchItems` sums a loot's
    quantities per item); the spike's log can.
- **[Game] Riverglades, session D** (the Hut's aura and Camper's Lure, 22:17 to 22:35): 56 casts, 48 with Camper's
  Lure, 54 catches, every one a single slot of quantity 1; no extra of the Hut either. With B, **124 casts with a
  lure in Riverglades and not one proc**, nor one camp extra: in this new zone of Forever (map 2548) neither the
  talent nor the camp bonus seems to act.
- **[Game] Tanaris, Southbreak Shore** (map 1446, all under the Hut's aura, 22:56 to 23:20):
  - C, no lure: 22 casts, **no catch with two slots**; Stonescale Eel came as 2 or 3 (its nature, as in the data).
  - D, Camper's Lure: 33 casts, **6 catches with a second slot, each an ordinary fish of the same water** (Raw
    Rockscale Cod + Raw Spotted Yellowtail, Firefin Snapper + Big-mouth Clam, Firefin + Yellowtail, Yellowtail +
    Firefin, Raw Glossy Mightfish + Yellowtail, Clam + Yellowtail), plus one Raw Winter Squid of quantity 2.
  - E, Bright Baubles: 16 casts, 2 catches with a second ordinary fish (Firefin + Raw Winter Squid, Cod +
    Yellowtail).
  - Every second slot came with its own "You receive loot" line; nothing else (no aura, spell or message).
  - None of these second items is a Hut extra (no Bloated fish, herb, ore or bar in these 71 casts).
- **What this means** (to be confirmed by longer sessions): **a Luremaster proc is a second loot slot holding another
  roll of the water's own loot** (often a different fish, sometimes the same one, then likely merged into one slot of
  quantity 2), not a doubled first slot. It works with an ordinary lure (Bright Baubles) as with Camper's Lure, and
  not without a lure. So:
  - L7 needs a new rule: both the camp and Luremaster can add a second slot; the camp's is a camp item (a Bloated
    fish, or an item that is no catch of that water), Luremaster's an ordinary catch of the water.
  - L8 and L11 change: the extra moves the items' **chances** (a second item counts as a catch of it), not only
    the pieces per catch, so the base must drop the extra slot itself, not halve a quantity.
  - `Camp.IsBonusCatch` counts every Luremaster proc under a camp buff as a camp bonus catch: the author saw the
    bonus catches counted wrong in the statistics.
- **[Game] Moonglade, round 2** (map 1450, Nighthaven and Lake Elune'ara, 2026-11-27/28, no camp):
  - A, no lure: 86 casts, 63 catches, **no catch with two slots, no quantity 2**.
  - B, Bright Baubles: 122 casts, 99 catches: **19 with a second slot and 9 with Raw Redgill x2 = 28 procs in 99
    catches (28 %)**, at rank 1 (25 %). **Luremaster works without a camp.** Every second slot is a fish of the lake
    (Redgill, Mithril Head Trout, Oily Blackmouth, Sunscale Salmon, Nightfin Snapper).
  - **Every quantity 2 is Raw Redgill**, the lake's commonest fish (69 of 99 catches). If the extra is an
    independent second roll of the same table, the chance that both rolls give the same item is the sum of the
    squared shares (about 0.35 here), so about 10 of 28 procs should come as one item twice: 9 did. **So a proc is a
    second roll; a second roll of the same item merges into the first slot as quantity 2, a different item takes a
    second slot.**
  - C, the Hut without a lure (one Hut, Lake Elune'ara): 160 casts, 137 catches, **17 with a second slot (12.4 %),
    none a fish of the lake and none of quantity 2**: Bloated Mud Snapper (2), Bloated Whitescale Salmon, Bloated
    Redgill, Iron Ore (2), Mithril Ore, Dense Stone, Truesilver Bar, Sungrass, Ghost Mushroom, Heavy Leather, Thick
    Hide, Shadow Silk, Lesser Mystic Essence, Empty Vial, Recipe: Draught of Water Walking. The statistics window
    showed 17 camp bonus catches for the session, the same. The Bloated fish belong to other waters (Mud Snapper,
    Whitescale Salmon): the Hut's extra is its own table, not the water's.
  - D, the Hut with Bright Baubles (a second Hut): 168 casts, 161 catches. **Luremaster 39 (24.2 %: 24 second slots
    with a fish of the lake, 15 merges into quantity 2), the Hut 25 (15.5 %), both in 6 catches**, as independent
    rolls would give (161 x 0.242 x 0.155 = 6.0). Five catches had **three slots**, always in the order the base
    catch, Luremaster's fish, the Hut's item (Greater Mana Potion + Raw Redgill + Bloated Bristle Whisker Catfish);
    the sixth was Raw Redgill x2 + Gold Bar. One Hut extra came as **Mageweave Cloth x2**: a camp item can be a stack.
  - Over B and D, Luremaster gave 67 procs in 260 catches with a lure (25.8 %, rank 1 = 25 %); over C and D the Hut
    42 extras in 298 catches (14.1 %).
- **[Game] A merge is visible in the loot.** `GetLootSourceInfo(slot)` gives the bobber (35591) and a quantity for
  every slot. For a Luremaster merge the slot reads 2 and the source 1 (all 25 merges in the log: Raw Redgill 20
  and Raw Nightfin Snapper 4 at Moonglade, Raw Winter Squid 1 at Tanaris); for an item stacked by nature both agree (Stonescale
  Eel 2 and 3, eight times; Mageweave Cloth 2). So **the merged extra is the slot's quantity less the source's**.
  Every slot of a catch has the same source, the bobber: the source does not tell Luremaster's second slot from the
  Hut's, only the item does.
- **What the addon can tell** (for the spec):
  - No lure on the pole: no Luremaster extra; a second slot under a camp is the camp's.
  - A lure and no camp: every slot after the first is Luremaster's, and the slot quantity above the source quantity
    is a merge.
  - A lure and a camp: a merge is Luremaster's (the camp item never merged); a second or third slot is the camp's
    when it is a camp item, else Luremaster's. Which items are camp items (the Bloated fish, the ores, bars, herbs,
    leather, cloth, the recipe) is a question for the spec: a list, or "not a catch of this water" from the data;
    the Hut's item came last in all five three-slot catches.
  - The first slot is always the water's own roll, with or without the extras.
