# Data Model: Interface Language

## Language preference (saved, account-wide)

| Field | Where | Type | Default | Rules |
|---|---|---|---|---|
| `settings.language` | `OneKeyFishingDB` | string | `"auto"` | `"auto"` or a language code from the registry |

- New key only: `ApplyDefaults` fills it for existing players, so `DB_SCHEMA` stays 1 and no migration is
  needed (players upgrading get `"auto"`, as the spec requires).
- A stored code that is not registered (a language removed in a later version) is treated as `"auto"` when
  resolving; the stored value is left as it is, so a downgrade-upgrade round trip keeps the choice.

## Language (registry entry, runtime only)

| Field | Type | Example | Notes |
|---|---|---|---|
| `code` | string | `"ukUA"` | WoW locale code; `ukUA` is the addon's own code (no client reports it) |
| `name` | string | `"Українська"` | native name, shown in the language menu |
| `fill` | function(L) | | sets `L[english] = translation`; called only for the effective language |

- Registered by `ns.AddTranslation(code, name, fill)` from `Locales/<code>.lua`; English is registered by
  `Locales/enUS.lua` with an empty `fill`.
- Menu order is fixed (`LANGUAGE_ORDER` in `Localization.lua`): enUS, deDE, esES, esMX, frFR, ukUA, koKR, ptBR,
  zhTW, zhCN; only registered codes are listed.

## Effective language (runtime only)

- `ns.language`: the code in use for this UI session, set once in `ADDON_LOADED` by
  `ns.ResolveLanguage(settings.language, GetLocale())` (see `research.md` R3).
- Changes only through a UI reload; changing the preference does not change it.

## Translation lookup

```text
L[key] -> translations[ns.language][key] -> key (English)
```

- Before `ns.language` is set, a lookup returns the key and is recorded in `ns.earlyLookups` (test guard,
  `research.md` R1).

## State transitions

```text
preference "auto" --pick language X--> preference X (saved) --"Reload now"--> effective language = X
                                                      \--"Later"--> effective unchanged until next reload/login
preference X --pick "Game client language"--> preference "auto" (same reload prompt)
```

## Rank steps (User Story 3, static, `GameData/FishingRanks.lua`)

`ns.FishingRanks[cap]` for `cap` 75, 150, 225 (research R11); no entry for 300.

| Field | Type | Example (cap 150) | Notes |
|---|---|---|---|
| `next` | spell ID | `7732` | the next rank's Fishing spell; its subtext is the rank name |
| `learnAt` | number | `125` | skill from which the next rank can be learned |
| `level` | number | `20` | character level required |
| `source.kind` | string | `"book"` | `"trainer"`, `"book"` or `"quest"` |
| `source.itemID` / `source.questID` | number | `16083` | book or quest |
| `source.npcID` | number | `2626` | seller or quest giver |
| `source.areaID`, `source.zoneAreaID` | number | `35`, `33` | sub-zone and zone for `C_Map.GetAreaInfo` |
| `source.maps` | list of uiMapID | `{ 1434, 224 }` | candidates, first usable wins |
| `source.x`, `source.y` | 0..1 | `0.274`, `0.770` | the NPC's point on those maps |
| `fallback` | table | `{ item = "Expert Fishing - The Bass and You", npc = "Old Man Heming", area = "Booty Bay", zone = "Stranglethorn Vale" }` | English names until the client delivers its own |

`ns.FishingRankSpells[cap]` maps each cap to the Fishing spell of that rank (75 -> 7620, 150 -> 7731,
225 -> 7732, 300 -> 18248) for rank names. `ns.NpcNames[npcID][clientLocale]` holds official NPC names
(enUS, deDE, esES, esMX, frFR, itIT, ptBR, ruRU, koKR, zhCN, zhTW; UTF-8 string literals, constitution 1.3.0);
a missing locale falls back to enUS.

## Next-rank advice (runtime, `Skill.GetNextRank()`)

```text
{ rank = <name>, state = "later" | "now" | "level" | "cap", level = <required>, where = <sentence>,
  pin = { mapID, x, y } | nil, sources = { rank, item|quest, npc, area, zone = "game" | "table" | "english" } }
```

State transitions per cap (once per session per cap and kind of notice):

```text
later --skill >= learnAt and level ok--> now      (quiet notice)
later --skill >= learnAt, level low----> level    (no notice; line shows the level)
level --PLAYER_LEVEL_UP to the level---> now      (quiet notice)
now/level --skill = cap----------------> cap      (loud notice first time; chat line on mode entry)
later --skill = cap = learnAt (225)----> cap      (only the cap notice, no "can learn" notice)
any --next rank learned (cap rises)----> later of the next cap
```

## Map pin (saved, per character)

| Field | Where | Type | Default | Rules |
|---|---|---|---|---|
| `pin` | `OneKeyFishingCharDB` | `{ mapID, x, y }` or nil | nil | the addon's last pin; a waypoint at the same map within 0.0005 is "own" and is replaced without asking |

- New key only, so `DB_SCHEMA` stays as it is. Same field and meaning as on `002-shared-db`.
- Its default is nil, so it needs no entry in `CHAR_DB_DEFAULTS` (`ApplyDefaults` cannot fill a nil); the field
  is documented in `CLAUDE.md`. Only the addon's pin button and menu entry write it; a pin set through the
  chat map link is the game's own; a pin already at the place it is set for is replaced without asking.
