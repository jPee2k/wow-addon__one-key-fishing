# Contract: Gear and Mode after spec 030

The functions other files call keep their names and arguments. What changes is what they promise.

## `Fishing/Gear.lua`

| Function | Promise |
|---|---|
| `Gear.Equip()` | Puts on the pole and the fishing items now, or, while a slot waits for the game's answer, as soon as the answers are in (after the fight in the lockdown) and fishing mode is still on, after a second room check (without room: the chat line, nothing equipped). Records each slot before asking for it (unchanged). |
| `Gear.Restore()` | Puts back every recorded slot now, or after the answers while a slot waits, or after the fight in the lockdown, or after the cast while casting. Never drops a record while a slot waits. |
| `Gear.RestoreWeapons()` | The same for the weapon slots, waiting only while a weapon slot waits; a full restore already queued stays full. |
| `Gear.HasPendingRestore()` | Unchanged: a record is saved. |
| `Gear.HasRoomForPole()` (new) | `true`, or `false, offhandLink` when fishing mode must not enter (data-model, "The room check"). Reads only; changes nothing. |
| `Gear.DebugState()` (new) | Two values for `/okf debug`: the waiting slots (sorted list) and the queued action (`"equip"`, `"restore all"`, `"restore weapons"` or `nil`). |

Events Gear listens to: `PLAYER_EQUIPMENT_CHANGED` (also ends a slot's wait), the cast ends, `PLAYER_REGEN_ENABLED`
(unchanged). No message is fired; none is added.

## `Fishing/Mode.lua`

`Mode.Enter` (and the resume after `/reload`): `Gear.HasRoomForPole()` (which itself answers `true` with the gear
setting off) is asked after the combat check and before `Action.Enable`. On `false` the chat says
`L["Fishing mode needs a free bag slot for %s."]` with the off-hand link, and the mode stays off: no binding, no CVar,
no camera, no gear, no `MODE_CHANGED`.

`Mode.Exit` is unchanged: "Fishing mode OFF." prints at once; the gear follows Gear's promise above.

## `Core/Debug.lua`

The Gear section adds `swap in flight: <slots or none>, queued: <action or none>`.
