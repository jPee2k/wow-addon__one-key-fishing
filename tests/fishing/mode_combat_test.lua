-- Fishing/Mode.lua in a fight (specs/009-pin-combat-fixes US2 and US3, contracts/combat.md C5-C8): leaving the mode
-- in the lockdown only sets a pending exit and equips nothing; the exit finishes when the fight ends; a login in a
-- fight with gear owed waits for the fight's end; an attack with "Leave fishing mode when attacked" on says once that
-- the mode ends, and the key hint does not repeat it within 5 seconds. The tests run in order and share one login.

load_addon()

local L = ns.L
local LEAVING = L["Leaving fishing mode after combat."]

-- Ends a fight and any exit it left pending, so the next case starts with fishing mode off.
local function EndFight()
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    assert(not ns.Mode.IsActive(), "fishing mode is still on")
end

test("the toggle key in a fight: one line, no equip, the mode waits for the fight's end", function()
    ns.db.settings.exitOnCombat = false
    enter_fishing_mode()
    owe_gear()
    in_combat = true
    OneKeyFishing_ToggleMode()
    OneKeyFishing_ToggleMode()
    eq(chat_count(LEAVING), 1, "the line once")
    eq(#equip_calls, 0, "no equip call in the lockdown")
    eq(ns.Mode.IsActive(), true, "still on")
    eq(ns.Mode.IsExiting(), true, "leaving after the fight")
end)

test("the end of that fight: the mode is off and every owed slot is back once", function()
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    eq(ns.Mode.IsActive(), false, "off")
    local slots = equipped_slots()
    eq(slots[16], 1, "main hand")
    eq(slots[17], 1, "off hand")
    eq(slots[1], 1, "head")
    eq(#equip_calls, 3, "no other equip call")
    eq(chat_count((L["Fishing mode %s."]):format("|cffff3333" .. L["OFF"] .. "|r")), 1, "the OFF line")
end)

test("a login in a fight with gear owed equips nothing until the fight ends", function()
    owe_gear()
    equip_calls = {}
    in_combat = true
    enter_world(true, false)
    advance(1)
    eq(#equip_calls, 0, "no equip call in the lockdown")
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    local slots = equipped_slots()
    eq(slots[16], 1, "main hand")
    eq(slots[17], 1, "off hand")
    eq(slots[1], 1, "head")
end)

test("an attack with the setting on: the weapons before the lockdown and the line once", function()
    ns.db.settings.exitOnCombat = true
    enter_fishing_mode()
    owe_gear()
    in_combat = false -- PLAYER_REGEN_DISABLED runs before the lockdown
    fire("PLAYER_REGEN_DISABLED")
    eq(chat_count(LEAVING), 1, "the line once")
    local slots = equipped_slots()
    eq(slots[16], 1, "main hand")
    eq(slots[17], 1, "off hand")
    eq(slots[1], nil, "the head waits")
    eq(ns.Mode.IsExiting(), true, "leaving after the fight")
end)

test("the keys within 5 seconds of the attack line do not repeat it", function()
    in_combat = true
    OneKeyFishing_ActionKeyIdle()
    OneKeyFishing_ToggleMode()
    eq(chat_count(LEAVING), 1, "still once")
    EndFight()
end)

test("another hint right after the fight is not held back by the attack line", function()
    advance(1) -- within 5 seconds of the attack line
    OneKeyFishing_ActionKeyIdle()
    eq(chat_count(L["Fishing mode is off. Press your 'Toggle fishing mode' key first."]), 1, "the mode-off hint")
end)

test("an attack with the setting off: no line, the mode stays on", function()
    ns.db.settings.exitOnCombat = false
    enter_fishing_mode()
    in_combat = false
    fire("PLAYER_REGEN_DISABLED")
    eq(chat_count(LEAVING), 0, "no line")
    eq(#equip_calls, 0, "no equip call")
    eq(ns.Mode.IsActive(), true, "still on")
    eq(ns.Mode.IsExiting(), false, "not leaving")
    in_combat = false
    OneKeyFishing_ToggleMode() -- out of the fight: leaves at once
    eq(ns.Mode.IsActive(), false, "off")
end)

test("an attack with the mode off: no line", function()
    chat = {}
    ns.db.settings.exitOnCombat = true
    fire("PLAYER_REGEN_DISABLED")
    eq(chat_count(LEAVING), 0, "no line")
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
end)
