# Contract: Module Functions Changed by Spec 012

No message is added or changed; the exchange format does not change.

## `Core/Data.lua`

### `ns.IsSecret(value)` -> boolean (new)

- S1: true when the game has `issecretvalue` and it reports the value as secret; false otherwise (nil included).

### `ns.GameObjectID(guid)` -> objectID | nil

- G1: nil for nil and for a secret value (no `strsplit` on it).
- G2: otherwise as today (the object ID of a `GameObject-...` GUID, nil for other unit types).

### `ns.IsBobberTargeted()` -> targeted, known

- B1: the soft target's GUID is secret: `false, false`.
- B2: otherwise: `targeted` as today, `known` true.

## `UI/Indicator.lua`

- I1: while channeling with the bobber answer unknown, the label is "Hook!", never "No bobber"; no error.
- I2: with a readable answer, as today (grace time, lost bobber).

## `Fishing/Bags.lua`

- L1: a loot source the game gives as a secret value is neither the opened container nor another known source; the
  timing fallback decides.
- L2: a lure refused at skill S (0 when not known) below its requirement stays skipped until a skill event finds the
  Fishing skill at or above the requirement; then it is offered again and `LURE_READY` fires. A lure refused with S
  at its requirement stays skipped until the next mode session.
- L3: entering fishing mode clears every skipped lure, as today.

## `UI/CatchHere.lua`

- H1: no seed, source "All", no other player's catch in the view (sharing off, or none counted here): "No
  bundled data in this version: only your own catches are shown."
- H2: no seed, source "All", `view.others` (another player's catch in the sum, with or without the own):
  "No bundled data in this version."
- H3: with a seed or another source: no such hint, as today.

## `Exchange/ShareGame.lua`

### `Share.StatusLine()`

- T1: one player exchanged with: "Exchange: 1 player, %s ago".
- T2: two or more: "Exchange: %d players, %s ago", as today.

## `UI/Minimap.lua`

- M1: the tooltip is cleared (`ClearLines`) after `SetOwner`, before any line.
- M2: every line given a colour carries it as a colour code in its text as well (both sides of a double line).

## `tools/addon.mjs`

### `privateProblems(text, folder, folderOf)` -> problems

- P1: reports `X.private`, `ns.X.private`, `ns["X"].private` and an alias `local A = ns.X` ... `A.private` when
  X's folder is not `folder`.
- P2: `--` inside a string hides nothing; comments are not read.
- P3: the module's own folder reports nothing; a file that does not parse returns no problems.
