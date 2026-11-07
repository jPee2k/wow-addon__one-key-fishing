-- Fishing/Gear.lua in a fight (specs/009-pin-combat-fixes US2, contracts/combat.md C1-C4): no equip call while the
-- combat lockdown is on, on any path; a restore refused there is done when the fight ends; the weapon swap before the
-- lockdown (the PLAYER_REGEN_DISABLED moment) still works. Fishing mode stays off in this file, so Gear's own
-- PLAYER_REGEN_ENABLED handler owns the end of the fight. The tests run in order and share one login.

load_addon()

local function Equipped(slot)
    return equipped_slots()[slot] or 0
end

local function SwapEntries()
    local count = 0
    for _ in pairs(ns.charDB.gearSwap or {}) do
        count = count + 1
    end
    return count
end

local function ExpectEachOnce(slots, what)
    for _, slot in ipairs(slots) do
        eq(Equipped(slot), 1, what .. ", slot " .. slot)
    end
    eq(#equip_calls, #slots, what .. ": no other equip call")
end

test("in the lockdown nothing is equipped and the owed gear stays recorded", function()
    owe_gear()
    equip_calls = {}
    in_combat = true
    ns.Gear.RestoreWeapons()
    ns.Gear.Restore()
    eq(#equip_calls, 0, "no equip call in the lockdown")
    eq(SwapEntries(), 3, "every owed slot still recorded")
end)

test("after the fight every owed slot is equipped once, with its own item", function()
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    local slots = { 16, 17, 1 }
    ExpectEachOnce(slots, "restored after the fight")
    for _, call in ipairs(equip_calls) do
        eq(call.item, ns.charDB.gearSwap[call.slot].previous, "the player's own item in slot " .. call.slot)
    end
    in_combat = false
end)

test("a cast that ends in the lockdown equips nothing; the fight's end restores", function()
    local slots = owe_gear()
    equip_calls = {}
    -- Before the lockdown, while channeling: the weapon swap waits for the cast.
    in_combat = false
    channel_info = { "Fishing", "", 0, 1000, 31000, false, false, 7620 }
    ns.Gear.RestoreWeapons()
    eq(#equip_calls, 0, "deferred by the cast")
    -- The cast ends after the lockdown began.
    in_combat = true
    channel_info = nil
    fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast", 7620)
    advance(0.2)
    eq(#equip_calls, 0, "no equip call when the cast ends in the lockdown")
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    ExpectEachOnce(slots, "restored after the fight")
end)

test("before the lockdown the weapons are swapped, the rest waits", function()
    owe_gear()
    equip_calls = {}
    in_combat = false
    channel_info = nil
    ns.Gear.RestoreWeapons()
    ExpectEachOnce({ 16, 17 }, "weapons before the lockdown")
    eq(Equipped(1), 0, "the head waits")
end)

test("gear owed for another reason is not retried after every fight", function()
    -- A restore that ran out of combat and left gear owed (full bags, an item gone): no lockdown refused it.
    owe_gear()
    in_combat = false
    channel_info = nil
    ns.Gear.Restore()
    equip_calls = {}
    fire("PLAYER_REGEN_DISABLED")
    fire("PLAYER_REGEN_ENABLED")
    eq(#equip_calls, 0, "no retry after a fight the restore did not wait for")
end)
