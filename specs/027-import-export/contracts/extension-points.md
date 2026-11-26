# Contract: extension points

Documented module functions for code that loads after the addon's own files. With none of them called, the addon
behaves exactly as it does without them (SC-004). None fires a message.

## Session rules (`Exchange/ShareGame.lua`)

```lua
ns.Share.SetSessionRules({ gap = 30, strangerChance = 1, offerOthers = false }) -- any subset of the fields
ns.Share.ResetSessionRules()
local rules = ns.Share.SessionRules() -- a copy: { gap, strangerChance, offerOthers }
```

- `gap`: whole seconds between two session starts, at least 15 (a smaller value is raised to 15, a fraction is
  cut). Default 120.
- `strangerChance`: the chance of starting a session with a stranger whose channel `HELLO` differs, 0..1. With nil
  the default formula applies, `min(1, 2 / H)`. Near peers (guild, group, friends) keep their own timing either way.
- `offerOthers`: with false, a session answers a peer's `WANT` with the own units only. Default true. The summary
  still lists every unit (so peers send nothing back that is held), so a peer that lacks one of them keeps wanting
  it: their hashes stay different and it starts a session again after each cooldown (30 min), a few small messages
  each time. Meant for a limited time only.
- Not settable: the pause per peer, the session size and record limit, the send budget, the timeouts and the
  flood limits.
- The rules apply to the game node at once. A node made later (after `Share.SetEnabled(true)`) starts with the
  current rules. `/okf debug` lists them under "Shared database".

## `/okf share` lines (`Exchange/ShareGame.lua`)

```lua
ns.Share.AddStatusLine(function() return "some line" end) -- nil: no line this time
```

Each function's line is printed after the addon's own lines of `Share.PrintStatus`, in the order added. A function
that raises an error adds nothing; the error goes to the error log (`ns.Safe`).

## Debug report sections (`Core/Debug.lua`)

```lua
ns.Debug.AddSection("Title", function(add) add("value %d", 1) end)
```

It runs like the report's own sections, after them: an error becomes a `!! failed: ...` line.

## Minimap menu (`UI/Minimap.lua`)

```lua
ns.MinimapMenu.AddEntries(function(root) root:CreateButton("Text", onClick) end)
```

It is called while the menu is built, after "Debug report", in the minimap button's menu and the Addon
Compartment's. It runs in `pcall`, so an error leaves the addon's own entries. A menu built in combat has no title,
divider or spacer (see `CLAUDE.md`); added entries follow the same rule.

## Settings pages (`UI/Settings.lua`)

```lua
local open = ns.SettingsUI.AddPage(frame, "Title")
```

- The frame is registered as a subcategory of "OneKeyFishing" after the addon's own pages, at the `PLAYER_LOGIN`
  registration; it is queued when called before. The frame should start hidden.
- The function returned opens the page (not in combat, like the addon's own `SettingsUI.Open*`).
