# Fishing in WoW Forever: investigation

What is known about fishing in WoW Forever beyond the API: the camp features and their fishing buffs, what changes
a catch, the items and skill sources, what fishing earns, how an addon can tell a catch made under a buff, and what
that means for the catch database. Researched on 2026-11-19 from the client's game data (DB2 tables of build
1.60.1.70959 on wago.tools), Blizzard's hotfix posts, the client's generated API documentation, guides and this
repository, then checked in game the same day with a Fishing Rack: the results are in "Checked in game", and they
overrule an inference elsewhere in this document. The Fishing Hut (it needs Fishing 300) was checked on 2026-11-20
("Checked in game", "The Fishing Hut").

The API facts confirmed in game are also in [forever-api.md](forever-api.md), "Verified in game".

Each statement carries its weight:

- **Data**: read from the client's DB2 tables, the client's API documentation or this repository.
- **Blizzard**: an official post.
- **Guide**: a wiki or guide site, mostly written from the beta; a gold-selling site is named as such.
- **Inference**: follows from the data, with no direct source.
- **Unknown**: only the game can tell.
- **Game**: seen in game on 2026-11-19 (build 1.60.1.70959, a level 35 character with Fishing 231 to 242).

## Summary

- Two IDs players link, spell 1262990 "Fishing Rack" and item 279966 "Fishing Hut", are not buffs. The first is a
  recipe, the second a consumable that places a hut next to a campfire.
- The catch is changed by two player auras of one hour each: **1280341 "Uncommon Fishing"** (from the Rack) and
  **1280342 "Rare Fishing"** (from the Hut). They are the only things in the game data that change the loot;
  everything else adds skill or quantity.
- Blizzard confirmed one thing about the loot: the Rack's effect gives Bloated fish. What the Hut gives is
  published nowhere. In game the bonus is rare and comes as an **extra item** in the same cast: the first hour
  under the Rack's aura (at least 70 casts) brought none, the second one Bloated Mithril Head Trout next to a Raw
  Mithril Head Trout.
- In game the aura is granted at once on placing a Rack, reads by ID, survives the Rack and a relog, and cannot be
  read in a fight.
- **Game** (2026-11-20). The Hut's aura works like the Rack's (granted at placing, one hour, read by ID), but its
  extra item comes far more often (at least 10 in 92 catches in one hour) and from a mixed table: Bloated fish of
  any kind, Blindweed, Iron Ore, Mithril Bar, Heavy Hide, Dream Dust. A Bloated fish can hold an uncommon neck item.
- The aura lasts an hour and the placed object 15 minutes, so the buff travels with the player. An addon reads it
  with `C_UnitAuras.GetPlayerAuraBySpellID`; nearness to the object is the wrong signal.
- The addon reads no aura today and a catch cell has no place for a condition, so catches under a buff already mix
  with normal ones in the shared database, and data collected so far can never be split.

## Checked in game

**Game**, 2026-11-19, with a Fishing Rack (aura 1280341) in Durotar and at Booty Bay.

The aura:

- `C_UnitAuras.GetPlayerAuraBySpellID(1280341)` returns nothing without the buff and, with it, a table:
  `spellId = 1280341`, `name = "Uncommon Fishing"`, `duration = 3600`, `isHelpful = true`, `sourceUnit = "player"`,
  `applications = 0`, empty `points`, an `expirationTime`.
- The aura is granted **at once on placing**: `UNIT_SPELLCAST_SUCCEEDED` 1307247 "Fishing Rack", and one second
  later `UNIT_AURA` adds 1280341 with 3600 s. No sitting and no waiting near the Rack is needed, whatever the
  aura's text says.
- It lasts one hour whatever the campfire (a basic one or one improved with Pouch of Violet Dust) and ends when
  the time is up, not on a catch.
- It outlives the Rack (still there 18 minutes after placing, away from the spot), a trip to another continent and
  a logout to the character screen. After the relog its `auraInstanceID` is another one (129, then 9) and
  `expirationTime` is re-based, so the aura is recognised by `spellId` only.
- `C_Secrets.GetSpellAuraSecrecy` is 2 (depends on the context) for 1280341 and 1280342;
  `C_Secrets.ShouldAurasBeSecret()` is false out of combat and **true in a fight** with an ordinary mob, where
  `GetPlayerAuraBySpellID(1280341)` returns nothing although the buff is up. After the fight the table is back. So
  an empty answer in a fight means "unknown", and the state read before the fight has to be kept.
- In a fight the `UNIT_AURA` payload is secret: `addedAuras` and `updatedAuraInstanceIDs` are secret tables,
  `isFullUpdate` a secret boolean; `ipairs` over one raises "table expected, got secret". Check `issecretvalue`
  before reading the payload.
- `C_VignetteInfo.GetVignettes()` is empty with the buff up.
- A second placing the same day (Booty Bay, 18:03) repeated it: no fishing aura before, `CAST 1307247`, and in the
  same second `UNIT_AURA` added 1280341 with 3600 s, the player standing. **A party member next to the Rack, who
  did not place it, got "Uncommon Fishing" at the same moment**, also without sitting (seen on the friend's
  character, not by a logged command). Whether a nearby player outside the group gets it is not checked.
- The author's report, not from a logged command: the aura **drops on death**, and everyone who sits a minute by
  the campfire gets the benefits of the features around it ("The camp features of Fishing").

The cast and the catch under the aura:

- The cast is the ordinary Fishing spell of the rank (18248 seen), the bobber `GameObject-...-35591-...`, and
  every catch had **one loot slot** with the bobber as its source, in open water and in a pool. The baseline
  without the buff looks the same (7732 on another character rank, one slot, the bobber). `LOOT_READY` fires twice
  per catch.
- **No Bloated fish and no second loot slot** came in at least 70 casts under the aura (30 in Durotar near
  Orgrimmar, the rest at Booty Bay, open water and one pool), with a lure on. The catches were ordinary fish (Raw
  Slitherskin Mackerel; Raw Spotted Yellowtail, Raw Rockscale Cod, Oily Blackmouth, Firefin Snapper) and
  containers (Battered Chest in Durotar; Sealed Crate, Sturdy Locked Chest, and Mithril Bound Trunk from the pool
  at Booty Bay). Such containers are in the seed from before, with the buff state unknown, so they prove nothing.
  Nothing the aura adds was seen in those casts.
- **The bonus is an extra item.** Under the second Rack's aura (placed 18:03), one cast at 18:45 gave two items
  at once: **Bloated Mithril Head Trout** (8366) and **Raw Mithril Head Trout** (8365), the ordinary fish with
  its Bloated form next to it, not instead of it. It took about 40 minutes of fishing to see one, so it is rare.
  The addon's rare-loot sound played for the uncommon item. The loot window had **two slots, both with the bobber
  as their source**: slot 1 the Bloated fish, slot 2 the ordinary one, each
  `GameObject-0-7083-0-21-35591-26B28401B3`. So the loot source does not tell the bonus item apart either.
- **Inside that Bloated Mithril Head Trout**: two slots, Raw Mithril Head Trout and Silver Hook (poor quality),
  with the loot source `Item-6938-0-...` (the opened item, not a game object); `LOOT_READY` fired several times
  for it. So far a Bloated fish held nothing of value.
- A second bonus catch came six minutes later (18:52), the same shape: slot 1 Bloated Mithril Head Trout, slot 2
  Raw Mithril Head Trout, both from the bobber. Twice out of twice the bonus was the Bloated form of the fish of
  the same cast, and twice out of twice it held the same two items: Raw Mithril Head Trout and Silver Hook.
- The party member, under the aura from the same Rack, caught a **Bloated Glossy Mightfish** (21243) at 18:54.
  It held Raw Glossy Mightfish and a junk item of poor quality (a blood-stained leather boot; seen on a Russian
  client, its English name and ID not noted). The pattern so far, three out of three: a Bloated fish holds one
  ordinary fish of its kind and one grey junk item.

The Rack and the camp:

- The placed Rack can be opened (spell 6247 "Opening"): it gave 5 Camper's Lure, with the loot source
  `GameObject-...-612090-...`, which confirms the Rack's object ID. Each player opens it for a share of their own
  (the placer and a party member got lures from one Rack). Facing it, the `softinteract` unit is the Rack:
  `UnitGUID` gives `GameObject-...-612090-...` and `UnitName` "Fishing Rack".
- **Camper's Lure** is item 291005 (not in `GameData/Lures.lua`), applied by spell 1331725. It is an ordinary
  weapon enchant: `GetWeaponEnchantInfo()` gives true, about 288 000 ms and the enchant ID 8773, and the pole's
  tooltip reads "Fishing Lure +60 (5 min)". Its own tooltip: Conjured Item, Soulbound, Unique (5), "Use: When
  applied to your fishing pole, increases Fishing by 60 for 5 minutes.", Requires Fishing (50).
- The campfire is spell 1307227 "Basic Campfire" (it adds aura 1283391); "Throw Violet Dust" 1328348 and "Violet
  Flames" 1328362 improve it (aura 1328375). Sitting by the fire adds aura 1229739 (60 s) every minute and after a
  minute 1229741 "Camp Benefits": one hour from a basic fire, two (7200 s) from an improved one. That is the
  camp's benefit, apart from the fishing aura.
- Auras 1230098 "Boosted Stats" and 1308027 "Camping" did not show among the added auras.
- The Fishing Hut needs Fishing 300 to be placed, as its data says.

### The Fishing Hut

**Game**, 2026-11-20, a character with Fishing 300, logged by the `UNIT_AURA` and `UNIT_SPELLCAST_SUCCEEDED`
listeners of check 4 (cut to 255 characters).

- Before: neither 1280341 nor 1280342 up (`GetPlayerAuraBySpellID` empty for both).
- `CAST 1307227 Basic Campfire`, and in the same second `AURA+ 1283391 Campfire Nearby` with duration 0.
- `CAST 1307246 Fishing Hut`, and **in the same second** `AURA+ 1280342 Rare Fishing 3600`. Like the Rack's, the
  aura is granted at once on placing, with no sitting.
- `C_UnitAuras.GetPlayerAuraBySpellID(1280342)` returns the same shape as the Rack's: `spellId = 1280342`,
  `name = "Rare Fishing"`, `duration = 3600`, `isHelpful = true`, `sourceUnit = "player"`, `applications = 0`,
  empty `points`, `icon = 5976329`, `auraInstanceID = 107`, `expirationTime = 28208.717` (read at 02:52:09, two
  minutes after placing: about 58 minutes left, so on `GetTime()`'s clock).
- The placed Hut opens with spell **6477** "Opening" (the Rack's was 6247) and gives Camper's Lure (291005), the
  same lure as the Rack's, **5** of them, as the Rack.
- The addon of spec 020 sees it: `/okf debug` gave "hut: aura 1280342, active, 3334 s left", "last cast mask: 2"
  and one catch in the bonus part of mask 2 (V60 confirmed).
- The first cast under the aura (map 1450, a lure on) gave **two items at once: Raw Redgill and Blindweed**
  (8839, a herb). Blindweed is no ordinary catch of open water, so it may be the Hut's extra item, as the Bloated
  fish is the Rack's; one cast proves nothing yet.
- **22 casts under the Hut's aura** (Moonglade, Lake Elune'ara, map 1450, open water, Camper's Lure on; 20
  catches, 2 misses), logged with a `LOOT_OPENED` listener printing each slot and its source. The ordinary catches:
  Raw Redgill, Raw Nightfin Snapper, Oily Blackmouth, Raw Mithril Head Trout, one item each. **Three casts gave a
  second item**, every slot with the bobber as its source (`GameObject-...-35591-...`), the ordinary fish in slot
  1:
  - Raw Redgill + **Blindweed** (8839), the first cast;
  - Raw Mithril Head Trout + **Mithril Bar** (3860);
  - Raw Redgill + **Bloated Firefin Snapper** (21163).
- So the Hut's extra item is not only a Bloated fish: a herb and a metal bar came the same way. Three in 22 casts
  is far more often than the Rack's two in about two hours.
- **The Hut gives Bloated fish too**, so "Rare Fishing" seems to include the Rack's loot. And the Bloated fish was
  **not the Bloated form of the fish of the same cast** (Bloated Firefin Snapper next to Raw Redgill): the Rack's
  "same fish" pattern does not hold. Unlike the Rack's two, the Bloated fish came in slot 2, not slot 1.
- The Bloated Firefin Snapper, opened (source `Item-6938-0-...`), held Firefin Snapper and Silver Hook: four out of
  four, a Bloated fish holds one ordinary fish of its kind and one grey junk item.
- 36 more casts at the same water, under the same aura (the zone column of the statistics: 63 casts, 59 catches,
  4 misses, all 63 with a camp bonus), brought two more extras, both Bloated fish next to Raw Nightfin Snapper:
  **Bloated Bristle Whisker Catfish** (6647) and **Bloated Brilliant Smallfish** (6643), the ordinary fish in slot
  1, the Bloated one in slot 2, both from the bobber. The catfish held Raw Bristle Whisker Catfish and Silver Hook.
- In all, **5 extra items in 59 catches** under the Hut (about 8 %): Blindweed, Mithril Bar and three Bloated fish.
  Neither the Smallfish nor the Catfish lives in Lake Elune'ara, so the Bloated fish is drawn from the Bloated list,
  not from the water's fish. Five out of five, a Bloated fish holds its own raw fish and a Silver Hook (or, once, a
  grey boot).
- After a relog the Hut's aura was still up, `auraInstanceID` 5 (107 before) and `expirationTime` 28218.663
  (28208.717 before): re-based, as the Rack's.
- The last quarter hour of the aura, same water, three more extras in slot 2, from the bobber: **Bloated Mud
  Snapper** (6645) and **Bloated Redgill** (13881), each next to another raw fish, and **Dream Dust** (11176), an
  enchanting material, next to Raw Nightfin Snapper.
- **A Bloated fish can hold gear**: the Bloated Redgill held Raw Redgill and **Vanadium Talisman of the
  Channeler**, an uncommon neck item, in place of the grey junk. So the "valuables" of the guides are real.
- The addon's toast "The Fishing Hut bonus ends in 5 minutes." came about five minutes before the end (V64), and
  the end toast when the buff ran out, out of combat. The aura ended on time; `/okf debug` then read "hut: aura
  1280342, not active".
- The whole hour at that water, by the addon's bonus part of mask 2 at place `1450:4:54`: **92 catches and 5
  misses** under the Hut. At least 10 of the catches carried an extra item in slot 2: Blindweed (8839), Mithril Bar
  (3860), Dream Dust (11176), **Iron Ore** (2772), **Heavy Hide** (4235) and five Bloated fish (6643, 6645, 6647,
  13881, 21163); the last two were seen in the bags, not in the log, and the author confirmed they came as a second
  slot. Not every cast was logged.
- **What it means for the addon.** The Hut's extra item is drawn from a mixed table (Bloated fish, herb, ore, bar,
  hide, enchanting dust), not tied to the water's fish. A known list of the Hut's items by ID is hard to keep; the
  data of the bonus part (items caught only under mask 2) are the better source of a tag. Since spec 020 decision
  32 the twelve Bloated fish are the known items of both bonuses (one list in `GameData/CampBonuses.lua`); the
  Hut's other extras are tagged from the data.
- **The addon's "Bonus catches" stayed 0** for the session while "Casts with a camp bonus" was 22: a cast was a
  bonus catch only when its item was in the known list of a bonus in its mask, and the Hut's list was empty; the
  Bloated fish were listed under the Rack only. Since spec 020 decision 33 a catch under a buff is also a bonus
  catch when it has a second loot slot that is not a fished quest item (below), and a Bloated fish counts under
  either bonus. The session's statistics are not recounted.

### A second loot slot without a buff

Why a second loot slot can stand for the camp bonus in the statistics (spec 020 decision 33, V68, accepted
2026-11-20):

- **Game.** Without a buff every catch had one slot, in open water and in a pool (2026-11-19). Pools, schools and
  floating wreckage or debris give one item too: a quantity in one slot, or a trunk opened later.
- **Sources.** Only fished quest items come as a second slot without a buff: Warcraft Wiki, "Nat Pagle, Angler
  Extreme" (`https://warcraft.wiki.gg/wiki/Nat_Pagle,_Angler_Extreme`): "As well as looting the quest fish, you will
  loot another fish or item"; classicdb, quest 1580 (`https://classicdb.ch/?quest=1580`), a comment on the
  Electropellers: "always in the same loot as some other fish".
- **The bundled seed.** 43 of 525 places have more item catches than catches: 306 extra slots in 33951 catches
  (0.9 %), and the large ones follow the quest items: Darkshore `1439:1:47` has 24 extra, 24 Electropellers; Feralas
  `1444:3:65` 16, Feralas Ahi; Swamp of Sorrows, Desolace and Stranglethorn likewise.
- **The addon.** `GameData/FishedQuestItems.lua` lists them (Electropeller 6718, Nat Pagle's fish 16967 to 16970,
  Dezian Queenfish 19806, Speckled Tastyfish 19807) and names the quest class (12), and `Camp.IsBonusCatch` leaves
  their slots out. If another item comes as a second slot without a buff, "Bonus catches" reads too high under a buff
  until the item joins that list.
- **Game, 2026-11-20 (H9 in part).** 63 catches without any fishing aura at Lake Elune'ara (map 1450), counted by a
  `LOOT_OPENED` listener (`IsFishingLoot()`, `GetNumLootItems() > 1`): no second slot and no Bloated fish. Under the
  Hut at the same water a second slot came in 4 of 36 and 5 of 59 catches, so a zero without the buff by chance is
  about 0.5 %. The author accepted V61 and V68 on it; other waters are not checked.
- **Game, 2026-11-20 (H14 in part).** 50 casts under the Hut at Hillsbrad Foothills (open water) gave no second slot
  at all, against about 8 % at Lake Elune'ara: the Hut's extra item may depend on the water or its level.

## The camp features of Fishing

How a camp works, in short: **campfire + Fishing Rack = "Camp Benefits" + "Uncommon Fishing"**.

- **Data.** A campfire is built by Cooking: spell 1307227 "Basic Campfire" (Tier 1) "builds a basic campfire that
  allows cooking and the placement of up to [3] additional camp features. Players sitting or crafting nearby for
  [1 minute] will gain benefits from other camp features." Near it a player has aura 1283391 "Campfire Nearby".
- **Data.** Sitting by the fire gives aura 1229739 "Welcoming Campfire" (60 s): "Grants various camp benefits
  after [60 s] spent sitting near the campfire, based on what additional camp objects are placed near the
  campfire." When it runs out the player gets 1229741 "Camp Benefits", whose text lists what the features around
  the fire gave: Mana Well, Sharpening Wheel, Enchanted Lute, First Aid Kit, Fish Bowl (all stats, aura 1230098),
  Incense Candle, Lodestone, Camp Chair, Faction Banner. The fire alone gives nothing; the features around it do.
- **Data.** Aura 1328375 "Violet Flames" (from Pouch of Violet Dust thrown into the fire): "Campfire effects
  gained while affected have increased duration." **Game.** Camp Benefits then lasts two hours instead of one;
  the fishing aura stays at one hour.
- **Blizzard** ("Gather Around the Campfire"): the basic campfire holds up to 3 features and each player can add
  one; "Players sitting or crafting at a campsite for at least 1 minute will gain the benefits from other camp
  features"; all camp features share a cooldown of one hour; the features mirror class buffs and are exclusive
  with them (the Fish Bowl with Blessing of Kings).
- **Guide** (Warcraft Tavern). Journeyman Campfire (Tier 2, Cooking 90, recipe from Lord Serpentis in Wailing
  Caverns) holds 5 features, Expert Campfire (Tier 3, Cooking 220) holds 10.
- **Game.** The fishing aura does not wait for the minute of sitting: the player who places the Rack and a party
  member standing next to it both got "Uncommon Fishing" in the second of the placing ("Checked in game"). The
  minute by the fire is for "Camp Benefits" (the author's account: everyone who sits there gets it).

**Data.** Fishing (skill line 356) has its own craft menu in Forever: the passive spell 1278067 "Bait and Tackle"
opens the recipe category "Camping" (TradeSkillCategory 2715) with exactly three recipes. Each recipe creates an
item; using the item casts a placing spell; the placing spell puts an object next to a campfire.

| Tier | Feature | Recipe spell | Item | Placing spell | Object | Area trigger | Fishing skill | Reagents | Gives |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Fish Bowl | 1229745 | 279967 | 1307245 | 651954 | | 20 | 1 Raw Brilliant Smallfish (6291), 1 Empty Vial (3371) | aura 1230098 "Boosted Stats": +8 % to all stats for those sitting nearby, 1 hour, exclusive with Blessing of Kings |
| 2 | Fishing Rack | **1262990** | 279965 | 1307247 | 612090 | 43850 | 140 | 2 Simple Wood (4470), 1 Crystal Vial (8925), 2 Raw Mithril Head Trout (8365) | aura **1280341 "Uncommon Fishing"**, lures, the Fish Bowl's benefit |
| 3 | Fishing Hut | 1262998 | **279966** | 1307246 | 612092 | 43851 | 300 | 5 Simple Wood (4470), 2 Bolt of Runecloth (14048), 1 Seasonal Fish Steaks (273295) | aura **1280342 "Rare Fishing"**, lures, the Fish Bowl's benefit |

- **Data.** Spell 1262990 has one effect, "create item 279965", a 10-second cast and no aura. Item 279966 is of
  common quality, stacks to 20, needs Fishing 300 and is used up when placed. Its tooltip: "Places a Fishing Hut
  that grants the ability to catch rare fish for 1 hour, provides Fishing Skill lures, and provides all of the
  benefits of a Fish Bowl. Requires a Campfire nearby. May be placed over a Fish Bowl to replace it. All camping
  features share a cooldown of 1 hour".
- **Data.** The placing spells last 900 000 ms (15 minutes), need the spell focus 2341 "Camping Fire" and belong to
  the category 97 "Camping Feature" with a shared cooldown of one hour, shown by the aura 1308027 "Camping". One
  character places one camp feature of any kind per hour. Each placing spell summons a game object, creates an area
  trigger and runs two scripted effects with a radius of 35 yards; the objects and triggers have no row in the
  client's tables, so their numbers are known only as effect values.
- **Data.** The recipes come from blueprints: 273141 "Blueprint: Fishing Rack" (Fishing 140) and 273119
  "Blueprint: Fishing Hut" (Fishing 300), neither bound. The camp is a system of every profession: 26 campsite
  blueprints exist (items 273085 to 273141).
- **Guide.** The Rack's blueprint drops from Gelihast in Blackfathom Deeps (Warcraft Wiki, Method) and can also be
  fished up from pools (Warcraft Tavern). The Hut's blueprint drops from Jammal'an the Prophet in the Temple of
  Atal'Hakkar (Warcraft Tavern; the Warcraft Wiki has no source).
- **Inference.** Seasonal Fish Steaks (273295), the Hut's one unusual reagent, are probably made with the Chef's
  Knife (273636, Fishing 275, spell 1292332 "Prepare Fish": "Use on unique fish to prepare them in a special way")
  from seasonal fish. No spell in the client creates 273295 by a plain effect.
- **Blizzard.** Hotfix of 2026-11-16, "Camping": "The Fishing Rack now provides lures for everyone." **Guide.**
  The lures a Rack hands out are named as Aquadynamic Fish Lens and Bright Baubles. **Game.** The Rack, opened,
  gave 5 Camper's Lure (291005, +60 for 5 minutes).

## The two fishing auras

- **Data.** Auras 1280341 and 1280342 each have one effect: a dummy aura on the caster with all values zero,
  3 600 000 ms long, with no stacks. Their texts: "Fishing boosted from time spent near Fishing Rack. Additional
  rewards while fishing for $d." and "Fishing boosted from time spent near Fishing Hut. Greater additional rewards
  while fishing for $d."
- **Data.** No effect in the client casts these auras and nothing in them modifies the Fishing skill, the cast
  speed, a phase or an area. The server grants them by script and decides what they change in the loot. The
  Russian client's text speaks of a raised Fishing skill; that is a loose translation of "Fishing boosted", not a
  skill bonus.
- **Inference.** The only attribute bit set (`0x80000000`) reads as "cannot be cancelled"; no "hidden" bit is set,
  so it is an ordinary visible buff.
- **Game.** In practice: light a campfire, place the Rack (it stands about 15 minutes), get the one-hour aura at
  once, open the Rack for the lures, then fish anywhere. The aura outlives the object, a zone change and a relog.
- **Game** (the author's report). The aura drops on death, as a beta article of a gold-selling site (MMOexp) said.
- **Game.** A party member next to the Rack gets the aura at once, without placing anything.
- **Unknown.** Whether a player outside the group gets it, or one who comes to the Rack later; whether both auras
  can be held at once. The author's guess: the Hut's aura
  replaces the Rack's, since the Hut's text promises better rewards than the Rack's.

## What is caught under the auras

- **Blizzard.** Hotfix of 2026-11-16: "Bloated Fish caught from the Fishing Rack effect have had their drop chance
  increased and their loot tables adjusted accordingly."
- **Data.** The client has twelve "Bloated ..." items (openable, item class 15.4), all with old Classic IDs: ten
  of uncommon quality (6643 Brilliant Smallfish, 6645 Mud Snapper, 6647 Bristle Whisker Catfish, 8366 Mithril Head
  Trout, 13881 Redgill, 13891 Whitescale Salmon, 21162 Oily Blackmouth, 21163 Firefin Snapper, 21164 Rockscale Cod,
  21243 Glossy Mightfish) and two of common quality (6644 Mackerel, 6646 Albacore). There is no Bloated fish of
  rare quality and none new to Forever.
- **Data.** The bundled seed (`CatchDB/SeedData.lua`, epoch 6: 24 759 catches of 94 items) holds Bloated fish
  7 times (13881 and 21162 twice each; 8366, 6645 and 21163 once each), and does not know whether an aura was up.
- **Guide.** Method: Bloated fish "can contain valuables when fished in open water with a lure and campfire
  buffs", and higher camp buffs "enable catching special fish", unnamed. MMOexp (gold seller, beta) describes
  "gem fish" in Mount Hyjal: Bloated fish with Citrine, Star Ruby, Aquamarine and rings under the Rack's buff.
- **Inference.** The Rack's "uncommon fish" are the Bloated fish of uncommon quality that match the water's
  ordinary fish.
- **Game.** The bonus is an **extra** item next to the ordinary fish, not a replacement: one cast under the
  Rack's aura gave Raw Mithril Head Trout and Bloated Mithril Head Trout together ("Checked in game"). So mixing
  hardly distorts the chances of ordinary fish; what is understated is the bonus item's chance, whose denominator
  holds the catches made without the aura too.
- **Unknown**, in the order that matters for the addon:
  1. Whether every bonus is the Bloated form of the fish caught in the same cast (twice out of twice so far), and
     how often it comes (none in the first hour, two in the second, six minutes apart).
  2. Whether Bloated fish are caught **only** under the aura. Their IDs are Classic ones, so a list "item X means
     buff" by item ID is unreliable until the game shows they never come without it.
  3. What the Hut's "rare fish" are: the same items with better odds and contents, or items a search by name does
     not find.
  4. Whether "Rare Fishing" includes the loot of "Uncommon Fishing", and whether the miss rate changes.

## Everything else adds skill or quantity

**Data.** By the tooltips in the client's tables, only the two camp auras change the loot.

| Group | What | Effect |
|---|---|---|
| Camp auras | 1280341 Uncommon Fishing, 1280342 Rare Fishing | **loot** ("additional rewards") |
| Lures | Shiny Bauble 6529 and the new "Secret" Bait 268880 (+25); Nightcrawlers 6530 and Aquadynamic Fish Lens 6811 (+50); Bright Baubles 6532 and Flesh Eating Worm 7307 (+75); Aquadynamic Fish Attractor 6533 (+100, 5 minutes) | skill |
| Hat with a lure | Wide-Brimmed Fishing Hat 259846, use spell 1265220 (+25 for 10 minutes) | skill |
| Food | "Well Fed" 1249521 (15 minutes): Loch Frenzy Delight +3, Fillet of Frenzy +5, Bristle Whisker Catfish +8, Rockscale Cod +12, Filet of Redgill and Spinefin Halibut +18 | skill |
| Legacy talents | 1225468 Master Forager (+25 Fishing), 1225451 Working Overtime (+10 % chance of a skill-up) | skill |
| Legacy talent | 1225455 Luremaster: a chance of an extra fish while a lure is active (the client's value is 50; the wiki says 25 % or 50 %) | quantity |
| Coin | 1321323 "Shiny Silver Coin": +30 Fishing for 30 minutes; no item in the data casts it (about 60 named fountain coins, 286263 to 286328, exist; the link is an inference) | skill |
| Gear | poles, Lucky Fishing Hat 19972, Nat Pagle's Extreme Anglin' Boots 19969, High Test Eternium Fishing Line 19971, the glove enchant 13620 | skill |

- **Data.** There is no bait that attracts one fish and no link to housing: the items named "bait" are quest
  objects, except "Secret" Bait. Nothing is dried or smoked at the Rack; it is a buff and lure feature only.
- **Data.** Classic's conditional catches remain, and the seed confirms part of them: Nat Pagle's quest fish
  (Savage Coast Blue Sailfin and Sar'theris Striker, 16 catches each), the tournament's Speckled Tastyfish (87),
  Raw Winter Squid (161) with no Raw Summer Bass in the November seed. So "the catch depends on a condition" is
  wider than the two auras (season, quest, tournament, probably time of day).
- **Guide.** Ranks: Apprentice 75, Journeyman 150, Expert 225 from a book, Artisan 300 from Nat Pagle's quest.
- **Unknown.** Whether Nightfin Snapper and Sunscale Salmon keep their time-of-day rule; where Whimsyfin (251524,
  a new fish that cooks into Savory Whimsyfin Delight 251525) is caught; what the Extravaganza coin (274026) buys;
  whether Find Fish (43308) can be learned (it is in the skill line, but no item that teaches it has an
  `ItemSparse` row).

Findings that touch `GameData/`, not checked in game unless said:

- Camper's Lure (291005, from an opened Fishing Rack) is a lure of +60 for 5 minutes, seen in game, and is not in
  `GameData/Lures.lua`, so the addon does not apply it.
- "Secret" Bait (268880) casts the Shiny Bauble spell 8087 and is not in `GameData/Lures.lua`; its source is
  unknown.
- Wide-Brimmed Fishing Hat (259846) applies a lure by its use effect (spell 1265220).
- Darkwood Fishing Pole (6366) is in `GameData/FishingPoles.lua` but has no row in the build's `ItemSparse`. The
  wiki lists a "Ravaged Fishing Pole" instead (+15, from Lord Angler in Dustwallow Marsh; item 285094 by Warcraft
  Tavern, not found in `ItemSparse` either).

## Profit

- **Data.** No auction prices and no measured gold per hour from the live servers were found. The figures in
  guides come from the beta or from gold-selling sites (about 10 to 20 gold per hour). What is firm is the vendor
  value in the client and the frequencies in the seed.
- **Data.** The best vendor catches are the "N Pound" trophy fish: Mud Snapper 10 to 15 silver, Catfish 17 to 32,
  Redgill 34 to 52, Yellowtail 40 to 68, Mightfish 70 silver to 1 gold 3 silver. They are about 117 of 24 759 seed
  catches (0.47 %).
- **Data.** Ordinary raw fish vendors for 1 to 10 copper; its worth is the auction and the crafts: Oily Blackmouth
  (Blackmouth Oil), Firefin Snapper (Fire Oil), Stonescale Eel (Stonescale Oil), Deviate Fish, Sagefish, Winter
  Squid.
- **Data.** Other catches in the seed: Stranglekelp (311 catches, 1 silver), Big-mouth Clam (152), Iron Bound
  Trunk (293), Tightly Sealed Trunk (83), Watertight Trunk (78).
- **Inference.** Since the hotfix of 2026-11-16 the Rack is probably the main profit lever from Fishing 140 on: an
  hour of the buff costs 2 Simple Wood, 1 Crystal Vial and 2 Raw Mithril Head Trout, and the contents of a Bloated
  fish after the change are published nowhere. The addon could measure it once it records the aura with a catch.

## Telling a catch under a buff from the addon

- **Data.** The client has `C_UnitAuras.GetPlayerAuraBySpellID(spellID)`, returning an `AuraData` table or nil. It
  is flagged `SecretWhenUnitAuraRestricted` and `RequiresNonSecretAura`: values become secret under the
  restrictions of combat, an encounter, challenge mode or a PvP match, and asking for a secret aura returns
  nothing instead of raising an error. `C_Secrets.ShouldAurasBeSecret()`, `C_Secrets.ShouldSpellAuraBeSecret(id)`
  and `C_Secrets.GetSpellAuraSecrecy(id)` ask in advance. `UNIT_AURA` carries `addedAuras` (with `spellId`),
  `updatedAuraInstanceIDs` and `removedAuraInstanceIDs`. `GetAuraDataByIndex`, `GetUnitAuras` and
  `AuraUtil.ForEachAura` exist too; `GetAuraDataBySpellName` is by name and so ruled out.
- **Game.** Confirmed: the call reads the aura out of combat and returns nothing in a fight; the `UNIT_AURA`
  payload is secret in a fight ("Checked in game").
- **Inference.** The rule for the addon: **nil under a restriction means "unknown", not "no buff"**. Keep the
  state read while unrestricted (on entering fishing mode and on the player's `UNIT_AURA`), and at the cast take a
  fresh value when there is one, else the kept one.
- **Data.** The object gives nothing reliable. There is no API for the distance to a game object; the `Vignette`
  table has no row about fishing or camps; the loot source of open water and of a pool is the same bobber
  (`GameObject-...-35591-...`, [forever-api.md](forever-api.md)). Only the four Fishing spells (7620, 7731, 7732,
  18248) summon the bobber 35591, and the auras override no spell.
- **Game.** The cast spell, the bobber and the loot source are the same under the buff; the aura is the only
  signal by ID. The own placing cast (`UNIT_SPELLCAST_SUCCEEDED` with 1307247 or 1307246) and the aura 1308027
  "Camping" are context at best: they miss another player's object and do not prove the fishing aura was granted.
- **Unknown.** Two dummy auras named "Fishing" (1229271 and 1283866, 30 seconds each) have no known purpose; if
  one shows only under the buff, it would be a second signal.

## What it means for the catch database

The facts about the code, as of 1.4.0:

- A catch is added to a counter cell keyed `"<mapID>:<range>:<cell>"`; there is no record per catch
  (`CatchDB/CatchDB.lua`). `FISH_CAUGHT` carries only the items and the cast ID. The place is taken at
  `FISHING_CAST_START` and kept by cast ID (`CatchDB/Events.lua`), which is the natural point to take a condition
  too, misses included.
- The addon reads no aura; the one buff-like read is the lure, through `GetWeaponEnchantInfo`
  (`Fishing/Bags.lua`).
- An item's chance is its catches divided by all catches of the selection (`CatchDB/Views.lua`), so two loot
  tables in one denominator distort the numbers by a ratio that is no property of the place. `Catch/Stats.lua` and
  `Catch/Prices.lua` hold no chances and need no split.
- The pool part of a cell, `p = { c, i }`, is the ready pattern: an inclusive sub-count with its check, copy,
  harvest sum, the `filter.water` data filter and a "Water" button shown only when such data exists. Nothing writes
  it since spec 011 and the seed has none.
- The exchange format has no version. A 1.4.0 client accepts an unknown **field** of a cell, strips it on saving
  (`CleanCell` in `Exchange/Share.lua`) and relays the stripped copy under the same `seq`. An unknown **key shape**
  fails the key check of `CatchDB/Checks.lua`: the whole record is refused and its sender ignored until logout.
  `seq` may not exceed `c + m`, so a condition part must be inclusive.
- A new field needs no `DB_SCHEMA` bump (the `a` field is the precedent); `tools/harvest.mjs` must mirror any new
  check.

The ways to store the condition, none chosen yet:

| Option | What | 1.4.0 clients | Chances | Cost and risk |
|---|---|---|---|---|
| A1 | A virtual map ID in the key (an offset plus the map ID) | accept and relay intact; show an unknown zone row | fully split, also through old clients | a magic number in a key documented as the game's map; every reader of the key needs a helper; twice the keys in a record |
| A2 | A new key segment | refuse the record, ignore the sender | split | needs a protocol break; the network splits in two |
| B | An inclusive part per condition in the cell, like `p`, with misses | accept, count mixed, strip the part and relay the stripped copy | right where the part arrived; the loss is silent | the model the code already knows; changes in `Settle`, `Checks.lua`, `CleanCell`, `Views.lua`, `tools/harvest.mjs` |
| C | A separate own record per condition | see one more valid record | split on new clients | the largest change, in the chain and roll code; the player counts twice |
| D | A static `GameData` list, item to condition | nothing changes | not fixed | kept by hand; wrong if an item comes both ways; collects nothing |

The research's recommendation (an opinion until a spec decides): option B with both a tag and a filter.

- **Recording.** Take the condition where the place is taken, from a list of aura IDs in `GameData`, through a
  small reader in layer 1. Read it at the cast and at the settle, and write the part only when both agree and
  neither was unknown. Keep the Rack and the Hut as separate conditions. Build the condition as a list, not a pair
  of flags: season, quest and tournament already behave like conditions.
- **Filter.** A data filter `filter.condition` next to `water`, part of the view's cache key, so the chances are
  right. Its button shows only once such data exists and takes the place of the hidden "Water" button (the
  catalog's filter row is nearly full). The default "everything" keeps today's numbers.
- **Tag.** An item whose catches all lie in a condition part gets an "only with the buff" mark in both tabs and in
  the tooltip lines, derived from the data.
- **Honest limit.** "Without a buff" means "without a buff or unknown" for all old data and stripped records, and
  the label has to say so.
- **Not to do.** Do not write buff catches into `p`; do not make the part exclusive; do not derive the condition
  from the object or the own placing cast; do not start with the static list D, which collects nothing while every
  week without recording adds data that can never be split.

A1 stays the fallback if 1.4.0 clients linger; their share cannot be measured, since `HELLO` carries no version.

What [spec 020](../specs/020-camp-buffs/) built: option B's inclusive part, but one part per **mask** of bonuses
(`q = { ["<mask>"] = { c, m, i } }`, keyed by the mask as a string, disjoint), not one part per condition, so a
cast under both bonuses is in one part only; `filter.bonus`, a tag from the data and a known list, and the notices.

## Wording for the feature

Proposed English texts (the `ns.L` keys) for the feature that records catches under the camp auras; the nine
translations are written with the feature, in `Locales/`. The rules behind them:

- **Name the thing the player places, not the aura.** "Uncommon Fishing" and "Rare Fishing" say nothing about how
  to get them; "Fishing Rack" and "Fishing Hut" do, and the aura's own text names them. The aura's name appears
  only in explanations.
- **One word for the concept: "camp bonus".** Not "buff" alone (every lure and food is a buff) and not
  "condition" (the code's word). A catch the bonus adds is a "bonus catch".
- **A translation uses the game's own names** of the Fishing Rack, the Fishing Hut and the two auras in that
  language, as the client shows them, so the player recognises them.

| Where | English text | Notes |
|---|---|---|
| Filter button, its title | `Camp bonus` | the button shows the chosen value |
| Filter value | `All catches` | the default: today's numbers |
| Filter value | `No camp bonus` | not "No buff" |
| Filter value | `Fishing Rack` | catches made with "Uncommon Fishing" up |
| Filter value | `Fishing Hut` | catches made with "Rare Fishing" up |
| Filter tooltip | `Show the catches made with a camp bonus: the fishing buff of a Fishing Rack or a Fishing Hut by a campfire.` | shortened on 2026-11-20 to fit a code line |
| Filter tooltip, second line | `"No camp bonus" also holds older catches for which the bonus is not known.` | the honest limit of old data |
| Tag: the row's icon, named in its tooltip | `Fishing Rack bonus` / `Fishing Hut bonus` | the rows have no room for the words: the tag is the camp feature's item icon, the words are the tooltip's first line (spec 020) |
| Tag's tooltip, item tooltip line | `Bonus catch: comes only with the buff of a Fishing Rack (Uncommon Fishing).` / `... of a Fishing Hut (Rare Fishing).` | says what to do to get it |
| Chance of a tagged item | `%s with the bonus` | "0.47% with the bonus": the chance among catches made under the aura |
| Toast, 5 minutes left | `The Fishing Rack bonus ends in 5 minutes.` / `The Fishing Hut bonus ends in 5 minutes.` | |
| Toast, ended | `The Fishing Rack bonus has ended.` / `The Fishing Hut bonus has ended.` | |
| Setting | `Warn when a camp bonus is ending` | no hint: the settings rows have none |
| Statistics row | `Casts with a camp bonus` | |
| Statistics row | `Bonus catches` | catches under a buff that held a known bonus item (a Bloated fish) or a second loot slot, fished quest items aside (spec 020 decision 33) |
| Changelog and manual | "camp bonus", "bonus catch" | the same two terms everywhere |

## In-game checks

Done on 2026-11-19 with a Fishing Rack: checks 1 to 8;
the results are in "Checked in game". **Still open:**

- How often the bonus comes and whether it is always the Bloated form of the fish of the same cast; whether a
  Bloated fish ever comes without the aura. Two bonus catches were seen (an extra loot slot each).
- The Fishing Hut (2026-11-20, one hour at one water): the checks left are H9 to H14 below.
- Whether a player outside the group, or one who comes later, gets the fishing aura from the Rack, and whether
  both fishing auras can be held.

The commands as they were run. The `UNIT_AURA` listener of check 4 must skip a secret payload, or it raises an
error in a fight: `local t=u.addedAuras if t and not issecretvalue(t) then ... end`.

| # | Question | Command | Expectation and what it decides |
|---|---|---|---|
| 1 | Is the aura readable by ID? | `/dump C_UnitAuras.GetPlayerAuraBySpellID(1280341)`, the same with `1280342` | A table with `spellId` and `duration` 3600; nil without the buff. Without it the approach fails |
| 2 | Is the aura secret? | `/dump C_Secrets.ShouldSpellAuraBeSecret(1280341), C_Secrets.GetSpellAuraSecrecy(1280341), C_Secrets.ShouldAurasBeSecret()`, the same for `1280342`; then check 1 again in a fight with an ordinary mob | `false, 0` out of combat. A value of 2, or nil in the fight, makes the kept state mandatory |
| 3 | Every aura of the player with its ID, near the object and with the line out | `/run for i=1,40 do local a=C_UnitAuras.GetAuraDataByIndex("player",i,"HELPFUL") if not a then break end print(i,a.spellId,a.name,a.duration) end`, the same with `"HARMFUL"` | Look for 1280341, 1280342, 1230098, 1229271, 1283866, and 1308027. Shows whether both auras can be held and whether a second signal exists |
| 4 | When and to whom is the aura granted? | `/run local f=CreateFrame("Frame") f:RegisterUnitEvent("UNIT_AURA","player") f:SetScript("OnEvent",function(_,_,_,u) for _,a in ipairs(u.addedAuras or {}) do print("AURA+",a.spellId,a.name,a.duration) end end)` and `/run local f=CreateFrame("Frame") f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED","player") f:SetScript("OnEvent",function(_,_,_,_,id) print("CAST",id,C_Spell.GetSpellName(id)) end)` | `CAST 1307247` or `1307246`, then `AURA+`; note the seconds between them and whether a second player nearby gets the aura. The same listener shows the cast spell under the buff (7620, 7731, 7732 or 18248 expected) |
| 5 | Channel, bobber and loot source under the buff | `/run print(select(8,UnitChannelInfo("player")), UnitGUID("softinteract"))` and `/run local f=CreateFrame("Frame") f:RegisterEvent("LOOT_READY") f:SetScript("OnEvent",function() for i=1,GetNumLootItems() do print(i,GetLootSlotLink(i),GetLootSourceInfo(i)) end end)` | Compare with `GameObject-...-35591-...`. The main point: is the bonus an **extra slot** next to the ordinary fish or a replacement, and has it another source |
| 6 | The object as the interact target | `/run print(UnitGUID("softinteract"), UnitName("softinteract"))` facing the Rack or the Hut | `GameObject-...-612090-...` or `...-612092-...`, or nil. For reference only |
| 7 | Does the aura outlive the object and the place? | Check 1 again after the object is gone (15 minutes) and 100 yards away; fish with the aura and no object near; again after a death and a relog | The aura stays with its remaining time and the catch is as in check 5. Confirms the aura, not nearness, as the signal |
| 8 | Vignettes | `/dump C_VignetteInfo.GetVignettes()` | Nothing about the object |

### The Fishing Hut: checks left

Done on 2026-11-20: H1 (no fishing aura before), H2 (the aura at placing), H3 (the aura's table), H4 (`/okf debug`
sees it, V60), H5 to H7 (an hour of catches with the loot logged, the five-minute toast, V64), H8 (the end toast out
of combat, V65 in part). The results are in "Checked in game", "The Fishing Hut". Later that day: H9 in part (63
catches without an aura, no second slot; V61 and V68 accepted), H11 (the buff lost at a death in a fight was read
at once after it, V65 and V69 confirmed), H14 in part (no extra item in 50 casts at Hillsbrad Foothills); see "A
second loot slot without a buff".

The listeners, each under the chat line's 255 characters (a `/run` after every login):

- auras: `/run local f=CreateFrame("Frame")f:RegisterUnitEvent("UNIT_AURA","player")f:SetScript("OnEvent",function(_,_,_,u)local t=u.addedAuras if t and not issecretvalue(t)then for _,x in ipairs(t)do print("AURA+",x.spellId,x.name,x.duration)end end end)`
- casts: `/run local f=CreateFrame("Frame")f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED","player")f:SetScript("OnEvent",function(_,_,_,_,id)print(date("%X"),"CAST",id,C_Spell.GetSpellName(id))end)`
- loot: `/run local f=CreateFrame("Frame")f:RegisterEvent("LOOT_OPENED")f:SetScript("OnEvent",function()for i=1,GetNumLootItems()do print("LOOT",i,GetLootSlotLink(i),(GetLootSourceInfo(i)))end end)`

| # | Question | How | What it decides |
|---|---|---|---|
| H9 | Do the extra items (a second slot) come without a camp aura? (V61, V68) | Reset the session; at Lake Elune'ara (map 1450) with the loot listener and no fishing aura, 90 or more casts; note every second slot and the session's casts and catches | None in 90+ casts: the extra item is the aura's. Any: the Bloated list and the tag by item are wrong for it |
| H10 | Is the Hut's aura hidden in a fight, like the Rack's? | With the aura, in a fight with an ordinary mob: `/dump C_UnitAuras.GetPlayerAuraBySpellID(1280342)`, again after the fight | Empty in the fight and back after it, as the Rack's: the kept state covers the Hut too |
| H11 | Does a death in a fight drop the aura, and does the end toast come after the fight? (V65) | With the aura, "Leave fishing mode when attacked" off, die in a fight; after the fight read the toast and `/okf debug` | The end toast after the fight and "hut: ... not active": closes V65 |
| H12 | Does a party member next to the Hut get "Rare Fishing"? | A party member stands by the fire when the Hut is placed, with the auras listener | `AURA+ 1280342` for them too, as with the Rack |
| H13 | Can both auras be held, and is such a cast in the part of mask 3? (V62) | One player places a Rack, the other a Hut (each has one camp feature per hour), both in a party by the fire; `/dump` both auras, cast once, `/okf debug` | Both tables and "last cast mask: 3": the part of mask 3 is real. One aura replacing the other: mask 3 never comes |
| H14 | Does the extra item depend on the water? | An hour of the Hut at another water (a pool, or water of another level), with the loot listener | Which extras come there: the same mixed table, or items of that zone |

The rare cast in which the aura ends (V63) and the checks of the addon's own screens (V66, V67) are in the feature's
checklist, [checklists/camp-buffs.md](checklists/camp-buffs.md).

One observation no API replaces: a few hundred casts in one water with the Rack's buff and without it (and with
the Hut's, once its blueprint is found), noting which items come, whether a Bloated fish ever comes without the
aura, whether "Rare Fishing" includes the loot of "Uncommon Fishing", and whether the miss rate changes. Whether
the server decides the loot by the aura at the cast or at the hook shows only in the rare cast during which the
aura ends.

## Sources

- Game data: wago.tools, product `wowf`, build 1.60.1.70959 (`SpellName`, `Spell`, `SpellEffect`, `SpellMisc`,
  `SpellCooldowns`, `SpellCastingRequirements`, `SpellReagents`, `SkillLineAbility`, `ItemSparse`,
  `ItemXItemEffect`, `GameObjects`, `Vignette`); how to query it is in [forever-api.md](forever-api.md).
- Tooltips: Wowhead's tooltip endpoint (`https://nether.wowhead.com/forever/tooltip/spell/1262990`,
  `.../item/279966`). Wowhead's database pages, comments and its guides "Camping Overview in Forever" and "Fishing
  Profession Overview in Forever" answered 403 and were not read; they are the likeliest place for the practical
  details.
- Blizzard: "WoW: Forever Hotfixes", the post of 2026-11-16 (`https://us.forums.blizzard.com/en/wow/t/2403040/11`).
- API: `UnitAuraDocumentation.lua` and `SecretPredicatesDocumentation.lua` of
  `Blizzard_APIDocumentationGenerated` (the local client export; mirrored on the `forever` branch of
  `Gethe/wow-ui-source`).
- Blizzard: "Gather Around the Campfire in World of Warcraft: Forever"
  (`https://news.blizzard.com/en-us/article/24301516`); it lists the Fish Bowl only.
- Camp guide: Warcraft Tavern, "Camping Objects & Buffs"
  (`https://www.warcrafttavern.com/forever/guides/camping-objects-buffs/`).
- Guides: Warcraft Wiki (`https://warcraft.wiki.gg/wiki/Fishing_Hut`,
  `https://warcraft.wiki.gg/wiki/Forever_fishing_techniques`), Method
  (`https://www.method.gg/wow-forever/fishing-in-wow-forever-leveling-guide-fishing-items-trainers`), Warcraft
  Tavern; MMOexp is a gold-selling site and its article is from the beta.
- Fished quest items: Warcraft Wiki, "Nat Pagle, Angler Extreme"
  (`https://warcraft.wiki.gg/wiki/Nat_Pagle,_Angler_Extreme`); classicdb, quest 1580
  (`https://classicdb.ch/?quest=1580`).
- The repository: the seed of epoch 6 and the code of 1.4.0.
