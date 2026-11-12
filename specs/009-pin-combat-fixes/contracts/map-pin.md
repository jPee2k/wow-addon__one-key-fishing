# Contract: the map pin (`Core/MapPin.lua`, `UI/Toast.lua`)

`MapPin.Target` and `MapPin.Link` do not change. `MapPin.Set(target, placeName)` changes as below.

## `MapPin.Set(target, placeName)`

Called only on the player's click (the next-rank Pin button, the minimap menu entry, a catalog spot's pin button).

| # | Given | Then |
|---|---|---|
| P1 | no user waypoint, or the addon's own, or one at this place | `C_Map.SetUserWaypoint` at the target; on success `C_SuperTrack.SetSuperTrackedUserWaypoint(true)`, `charDB.pin` saved, `MAP_PIN_SET(placeName)` |
| P2 | a waypoint the player set elsewhere | the replace popup (`L["Replace"]` / `L["Cancel"]`); Replace does P1, Cancel changes nothing |
| P3 | the game refuses the waypoint | `MAP_PIN_SET(nil)`; nothing saved |
| P4 | any case, in or out of a fight | **`OpenWorldMap` is never called** (and no other call that opens the world map) |

The code keeps `-- VERIFY(R14): a pin set without opening the map leaves the map untainted for a later fight` until
`docs/checklists/interface-language.md` section 10 passes.

## `MAP_PIN_SET` in `UI/Toast.lua`

| Argument | Toast |
|---|---|
| a place name | `L["Map pin: %s. Open the world map to see it."]:format(placeName)`, white, loud (shown with catch notifications off) |
| nil | `L["The game did not accept the map pin."]`, red, loud (unchanged) |

## Unchanged

- `MapPin.Link`: the game's own `worldmap:` link handler sets the pin and opens the map. That is not addon code, and
  the game showed no blocked action afterwards.
- The hidden CVar `showInGameNavigation` is neither read nor written.
