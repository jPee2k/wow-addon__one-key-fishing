# Contract: what the player sees and does

The catalog tab, the pin, the tooltips, the minimap lines, the setting and the command. Every text below is an
English `ns.L` key with nine translations (FR-026); color codes stay outside the strings. `%d, %d` coordinates and
`%d%%` percentages are number formats in the code, as in CatchHere.

## The "Catch catalog" tab (`UI/CatalogTab.lua`)

The third tab of the statistics window (580 x 660), after "Statistics" and "What can be caught here"; `statsTab`
remembers it like the others. The page drills down (research R8).

### The list

```text
[ Search by item name            ]
[Skill: All skill levels] [Source: All] [Water: Everywhere]
 [icon] Deviate Fish                               Zones: 4
 [icon] Rainbow Fin Albacore                       Zones: 2
 ...                                               (scrolls)
Counting the catch...                              (status line, only while it applies)
```

| Element | Behaviour |
| --- | --- |
| Search box (`SearchBoxTemplate`, the hint `L["Search by item name"]`) | narrows the list on every typed letter (FR-003); clearing it brings the full list back |
| `L["Skill: %s"]` | the ranges and `L["All skill levels"]`, default "All" (FR-006) |
| `L["Source: %s"]` | `L["All"]` / `L["Only mine"]`, default "All" |
| `L["Water: %s"]` | `L["Everywhere"]` / `L["Open water"]` / `L["Pools"]`; shown only with `CatchDB.HasPoolData()` (FR-021) |
| Item row | icon, name (quality color from `ns.ItemDisplay`), `L["Zones: %d"]`; hover: the game's item tooltip (with its own "Caught in" lines); click: the item page |
| Status line | `L["Counting the catch..."]` while no index is complete; `L["Nothing has been caught yet."]` plus `L["The catalog fills with your catches, the bundled data and, with sharing on, other players' catches."]` for an empty database; `L["You have not caught anything yet."]` under "Only mine" without own catches; `L["No item matches the search."]` |

### The item page

```text
[< Back]  [icon] Deviate Fish
Place                                   Skill     Chance   Catches
- Elwynn Forest                         0-149        18%     1840
     Crystal Lake (45, 72)              0-74         22%      610   [pin]
     51, 66                             75-149        9%      402   [pin]
+ Westfall                              75-149        8%      920
+ Elwynn Forest - Jasperlode Mine       0-74    Little data    32
```

| Element | Behaviour |
| --- | --- |
| `L["Back"]` | returns to the list with the search, the filters and the scroll kept |
| Headers | `L["Place"]`, `L["Skill"]`, `L["Chance"]` (existing key), `L["Catches"]` |
| Zone row | `+`/`-` toggles its spots; `Catalog.ZoneName` (`L["Unknown zone (%d)"]` with the map number when the game gives no map info); the span of skill the item was caught with there (`0-74`, `75-149`, ..., `300+`, joined with `-` from the lowest to the highest range); chance or `L["Little data"]`; the zone's catches; hover: `L["%d catches from %d players"]` (2 players on) or `L["%d catches"]` |
| Spot row | indented; `Catalog.SpotName`: `L["%s (%s)"]` with the subzone and the coordinates, the coordinates alone, or `L["No exact spot"]`; the same columns; hover: the subzone and the coordinates, then `L["%d catches from %d players"]` (2 players on) or `L["%d catches"]` (FR-009); the pin button when `spot.pin` is set |
| Pin button | the atlas `Waypoint-MapPin-Untracked` (a text button `L["Pin"]` when the atlas is missing); hover: `L["Set a map pin here"]` |
| Empty item | `L["No data for this item under these filters."]` when the filters leave it no zone |

The page follows new data on the window's 1 s tick without losing the search, the chosen item, the expanded zones or
the scroll (FR-028).

## The pin (research R6)

| Step | What the player sees |
| --- | --- |
| Another pin is on the map | the popup `L["Replace your map pin with this place?"]`, buttons `L["Replace"]` / `L["Cancel"]`; Cancel changes nothing |
| The pin is set | the game's pin on the world map and the minimap, its tracking (the minimap's arrow; the arrow on screen depends on the game, V31), the toast `L["Map pin: %s. Open the world map to see it."]` with the zone and spot name; the world map stays closed (changed by spec 009) |
| The game refuses | the toast `L["The game did not accept the map pin."]` |

## Item tooltips (`UI/ItemHooks.lua`)

```text
Deviate Fish
...the game's lines...
Caught in:                                 (the addon's tooltip color, 0.2 0.8 1)
  Elwynn Forest                  18% (14 players)
  Westfall                        8%
  Loch Modan                      5%
```

- `L["Caught in:"]`, then up to three double lines: the zone, and `%d%%`, or `L["%s (%d players)"]` from 2 players on,
  or `L["Little data"]` for the fallback zones (FR-017).
- Only for items in the default index; nothing with `tooltipChances` off.

## The minimap button tooltip (`UI/Minimap.lua`)

In fishing mode, after the session line:

```text
Likely catch here:
  Deviate Fish                    34%
  Raw Brilliant Smallfish         21%
  Raw Spotted Yellowtail          12%
  1,840 catches from 14 players
```

- `L["Likely catch here:"]`, up to three double lines (item name and percentage), grey and unknown items skipped.
- The footer `L["%d catches from %d players"]`, `L["%d catches"]` or, under 50 catches on the whole map,
  `L["Little data"]` in place of the percentages; `L["Nothing has been caught here yet."]` without data.
- Outside fishing mode, or with the setting off, the tooltip is as before.

## "What can be caught here" (`UI/CatchHere.lua`)

- The "Water" button next to the source button, as in the catalog; under "Open water" or "Pools" the miss line is
  not shown.
- A click on a known item row opens the catalog on it; the hint line gains
  `L["Click an item to see where else it is caught."]`.

## Settings (`UI/Settings.lua`)

- A feature checkbox `L["Show catch chances in tooltips"]` (account-wide, `settings.tooltipChances`, default on).

## The command (`Commands.lua`, English, not translated)

- `/okf catalog [name or item link]` - "open the catch catalog (optionally with an item name or link)".
