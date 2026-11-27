-- Fishing/Gear.lua and Fishing/Mode.lua: the gear waits for the game's answer to a swap (specs/030-gear-in-flight).
-- The stub C_Item.EquipItemByName records a call and changes nothing; a test lands a swap with land(), the way the game
-- answered in the spike of 2026-11-27 (research R3): the slot changes, then PLAYER_EQUIPMENT_CHANGED(slot, empty).
-- A one-handed weapon in the main hand, a shield in the off hand, the two-handed Fishing Pole in the bags.

local WEAPON, SHIELD, POLE, HAT, OLD_HAT = 3269, 2212, 6256, 4500, 4501
local MAIN, OFF, HEAD = 16, 17, 1

load_addon()
fishing_ready()

local function link(itemID)
    return "item:" .. itemID
end

function GetInventoryItemLink(unit, slot)
    local itemID = unit == "player" and inventory[slot]
    return itemID and link(itemID) or nil
end

local getInstant = C_Item.GetItemInfoInstant
local equipLocs = {
    [WEAPON] = "INVTYPE_WEAPON",
    [SHIELD] = "INVTYPE_SHIELD",
    [HAT] = "INVTYPE_HEAD",
    [OLD_HAT] = "INVTYPE_HEAD",
}
C_Item.GetItemInfoInstant = function(item)
    local itemID = tonumber(item) or tonumber(tostring(item):match("item:(%d+)"))
    if itemID == POLE then
        local class = ns.GameData.FishingPoleClass
        return itemID, nil, nil, "INVTYPE_2HWEAPON", nil, class.classID, class.subclassID
    end
    if equipLocs[itemID] then
        return itemID, nil, nil, equipLocs[itemID]
    end
    return getInstant(item)
end

-- Bag 0 is the only regular bag; its free slots are free_slots.
free_slots = 2
C_Container.GetContainerNumFreeSlots = function(bag)
    if bag == 0 then
        return free_slots, 0
    end
    return 0, 0
end

-- The slots moved to the bags (UnequipToBags).
picked = {}
function PickupInventoryItem(slot)
    table.insert(picked, slot)
end

-- The game's answer to a swap of `slot`: it now holds itemID (nil: empty).
local function land(slot, itemID)
    inventory[slot] = itemID
    fire("PLAYER_EQUIPMENT_CHANGED", slot, itemID == nil)
end

-- The answer to the two-handed pole: the main hand holds it, the off hand is emptied, in one frame (R3 step 2).
local function land_pole()
    land(MAIN, POLE)
    land(OFF, nil)
end

-- The items asked for in a slot since equip_calls was emptied.
local function asked(slot)
    local items = {}
    for _, call in ipairs(equip_calls) do
        if call.slot == slot then
            table.insert(items, call.item)
        end
    end
    return items
end

-- Fishing mode off, every wait over, the normal gear in hand, the records and the recorders empty.
local function reset()
    if ns.Mode.IsActive() then
        ns.Mode.Exit()
    end
    in_combat = false
    channel_info = nil
    advance(6) -- every wait ends and a queued action runs
    advance(6) -- the waits of what it asked for end too
    inventory = { [MAIN] = WEAPON, [OFF] = SHIELD }
    ns.charDB.gearSwap = nil
    ns.charDB.gear.pole = POLE
    ns.charDB.gear.items = {}
    bag_items[POLE], bag_items[HAT] = 1, nil
    free_slots = 2
    ns.db.settings.gear, ns.db.settings.camera = true, false
    equip_calls, chat, picked = {}, {}, {}
end

---------------------------------------------------------------------------
-- User Story 1: leaving right after entering keeps the weapons (B1)
---------------------------------------------------------------------------

test("leaving before the pole's answer keeps the gear and puts it back after the answer", function()
    reset()
    ns.Mode.Enter()
    eq(asked(MAIN)[1], POLE, "the pole asked for")
    equip_calls = {}
    ns.Mode.Exit()
    eq(ns.Mode.IsActive(), false, "fishing mode off")
    eq(#equip_calls, 0, "nothing asked before the answer")
    local swap = ns.charDB.gearSwap
    assert(swap and swap[MAIN] and swap[OFF], "both records kept")
    land_pole()
    advance(0)
    eq(asked(MAIN)[1], link(WEAPON), "the weapon asked back")
    eq(asked(OFF)[1], link(SHIELD), "the shield asked back")
    land(MAIN, WEAPON)
    land(OFF, SHIELD)
    eq(ns.charDB.gearSwap, nil, "the records settled")
end)

test("two answers in one frame run the restore once, on the next frame", function()
    reset()
    ns.Mode.Enter()
    ns.Mode.Exit()
    equip_calls = {}
    land_pole()
    eq(#equip_calls, 0, "nothing inside the answers' frame")
    advance(0)
    eq(#equip_calls, 2, "the weapon and the shield, once each")
    eq(#asked(MAIN), 1, "main hand once")
    eq(#asked(OFF), 1, "off hand once")
end)

test("a refused swap ends the wait after 5 seconds", function()
    reset()
    ns.Mode.Enter()
    equip_calls = {}
    ns.Mode.Exit()
    advance(4.9)
    eq(#equip_calls, 0, "still waiting")
    assert(ns.charDB.gearSwap and ns.charDB.gearSwap[MAIN], "the records kept while waiting")
    advance(0.3) -- the wait ends at 5 s, its timer a little after
    eq(#equip_calls, 0, "the weapon never left: nothing to put back")
    eq(ns.charDB.gearSwap, nil, "the records dropped as not ours, as before")
end)

test("a fight during the wait: the restore after the fight", function()
    reset()
    ns.Mode.Enter()
    ns.Mode.Exit()
    equip_calls = {}
    in_combat = true
    land_pole()
    advance(0)
    eq(#equip_calls, 0, "nothing equipped in the lockdown")
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    eq(asked(MAIN)[1], link(WEAPON), "the weapon after the fight")
    eq(asked(OFF)[1], link(SHIELD), "the shield after the fight")
end)

test("a weapons-only restore keeps a full one queued", function()
    reset()
    ns.charDB.gear.items = { HAT }
    bag_items[HAT] = 1
    ns.Mode.Enter()
    eq(asked(HEAD)[1], HAT, "the hat asked for")
    ns.Mode.Exit()
    ns.Gear.RestoreWeapons()
    equip_calls = {}
    land_pole()
    land(HEAD, HAT)
    advance(0)
    eq(asked(MAIN)[1], link(WEAPON), "the weapon back")
    eq(picked[1], HEAD, "the hat taken off too")
end)

---------------------------------------------------------------------------
-- User Story 2: entering right after leaving equips the pole (B2)
---------------------------------------------------------------------------

test("entering before the restore's answer equips the pole after it", function()
    reset()
    ns.Mode.Enter()
    land_pole()
    advance(0)
    ns.Mode.Exit()
    eq(asked(MAIN)[2], link(WEAPON), "the restore asked for the weapon")
    equip_calls = {}
    ns.Mode.Enter()
    eq(#asked(MAIN), 0, "no pole before the answer")
    land(MAIN, WEAPON)
    land(OFF, SHIELD)
    advance(0)
    eq(asked(MAIN)[1], POLE, "the pole after the answer")
    eq(#asked(MAIN), 1, "once")
    eq(ns.charDB.gearSwap[MAIN].previous, link(WEAPON), "the weapon recorded as the player's")
end)

test("a fight during the wait of a quick re-entry: the pole after the fight, nothing in the lockdown", function()
    reset()
    ns.db.settings.exitOnCombat = false
    ns.Mode.Enter()
    land_pole()
    advance(0)
    ns.Mode.Exit()
    ns.Mode.Enter()
    equip_calls = {}
    fire("PLAYER_REGEN_DISABLED")
    in_combat = true
    land(MAIN, WEAPON)
    land(OFF, SHIELD)
    advance(0)
    eq(#equip_calls, 0, "nothing equipped in the lockdown")
    local _, action = ns.Gear.DebugState()
    eq(action, "equip", "the equip still queued")
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    advance(0)
    eq(asked(MAIN)[1], POLE, "the pole after the fight")
    eq(#asked(MAIN), 1, "once")
    ns.db.settings.exitOnCombat = true
end)

test("bags filled during that fight: no pole after it, the reason in the chat, the mode stays on", function()
    reset()
    ns.db.settings.exitOnCombat = false
    ns.Mode.Enter()
    land_pole()
    advance(0)
    ns.Mode.Exit()
    ns.Mode.Enter()
    equip_calls, chat = {}, {}
    fire("PLAYER_REGEN_DISABLED")
    in_combat = true
    land(MAIN, WEAPON)
    land(OFF, SHIELD)
    advance(0)
    free_slots = 0 -- loot in the fight
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    advance(0)
    eq(#asked(MAIN), 0, "no pole: the game would refuse it")
    eq(chat_count("Fishing mode needs a free bag slot for"), 1, "the reason once")
    eq(ns.Mode.IsActive(), true, "only a key press ends the mode")
    ns.db.settings.exitOnCombat = true
end)

test("a fight's start brings the weapons back while an extra item still waits", function()
    reset()
    ns.charDB.gear.items = { HAT }
    bag_items[HAT] = 1
    ns.Mode.Enter()
    land_pole()
    advance(0) -- the hat's swap is not answered (refused): its slot waits
    equip_calls = {}
    fire("PLAYER_REGEN_DISABLED") -- "Leave fishing mode when attacked" on; before the lockdown
    eq(asked(MAIN)[1], link(WEAPON), "the weapon at once")
    eq(asked(OFF)[1], link(SHIELD), "the shield at once")
    fire("PLAYER_REGEN_ENABLED")
end)

test("a fight after leaving brings the weapons back while only the hat waits", function()
    reset()
    ns.charDB.gear.items = { HAT }
    bag_items[HAT] = 1
    ns.Mode.Enter()
    land_pole()
    advance(0) -- the hat's swap is not answered (refused): its slot waits
    ns.Mode.Exit()
    equip_calls = {}
    eq(#equip_calls, 0, "the full restore waits for the hat")
    fire("PLAYER_REGEN_DISABLED") -- fishing mode off; before the lockdown
    eq(asked(MAIN)[1], link(WEAPON), "the weapon at the fight's start")
    eq(asked(OFF)[1], link(SHIELD), "the shield at the fight's start")
    local _, action = ns.Gear.DebugState()
    eq(action, "restore all", "the rest still queued")
    fire("PLAYER_REGEN_ENABLED")
end)

test("a cast before the re-entry's answers: the pole after the cast", function()
    reset()
    ns.Mode.Enter()
    land_pole()
    advance(0)
    ns.Mode.Exit()
    ns.Mode.Enter()
    equip_calls = {}
    channel_info = { "Fishing" } -- the fishing key pressed before the answers
    land(MAIN, WEAPON)
    land(OFF, SHIELD)
    advance(0)
    eq(#asked(MAIN), 0, "nothing asked while casting: the game would refuse it")
    local _, action = ns.Gear.DebugState()
    eq(action, "equip", "the equip still queued")
    channel_info = nil
    fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast", 7620)
    advance(0.3)
    eq(asked(MAIN)[1], POLE, "the pole after the cast")
    eq(#asked(MAIN), 1, "once")
end)

test("entering during a cast: the pole after the cast, not lost to the silent failure", function()
    reset()
    channel_info = { "Summon Mount" } -- a cast already running as the toggle key is pressed
    ns.Mode.Enter()
    eq(ns.Mode.IsActive(), true, "fishing mode on")
    eq(#asked(MAIN), 0, "nothing asked while casting: the game would refuse it")
    local _, action = ns.Gear.DebugState()
    eq(action, "equip", "the equip queued")
    channel_info = nil
    fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast", 1)
    advance(0.3)
    eq(asked(MAIN)[1], POLE, "the pole after the cast")
    eq(#asked(MAIN), 1, "once")
end)

test("leaving cancels a queued equip also with nothing recorded", function()
    reset()
    ns.charDB.gear.items = { HAT }
    bag_items[HAT] = 1
    inventory[MAIN] = POLE
    inventory[OFF] = nil
    ns.Mode.Enter()
    land(HEAD, HAT)
    advance(0)
    ns.charDB.gearSwap = { [HEAD] = { previous = false, equipped = HAT } }
    ns.Mode.Exit() -- the hat to the bags: no record left, the head slot waits
    eq(ns.charDB.gearSwap, nil, "nothing recorded")
    ns.Mode.Enter()
    ns.Mode.Exit()
    local _, action = ns.Gear.DebugState()
    eq(action, nil, "the equip is cancelled")
end)

test("enter, leave, enter before any answer: only the last wish runs", function()
    reset()
    ns.Mode.Enter()
    equip_calls = {}
    ns.Mode.Exit()
    ns.Mode.Enter()
    land_pole()
    advance(0)
    eq(#equip_calls, 0, "no restore and no second pole")
    eq(ns.charDB.gearSwap[MAIN].previous, link(WEAPON), "the first entry's record")
    ns.Mode.Exit()
    eq(asked(MAIN)[1], link(WEAPON), "leaving later brings the weapon back")
    eq(asked(OFF)[1], link(SHIELD), "and the shield")
end)

test("a hat moved to the bags on exit is put on again after its answer", function()
    reset()
    ns.charDB.gear.items = { HAT }
    bag_items[HAT] = 1
    ns.Mode.Enter()
    land_pole()
    land(HEAD, HAT)
    advance(0)
    ns.Mode.Exit()
    eq(picked[1], HEAD, "the hat moved to the bags")
    ns.Mode.Enter()
    equip_calls = {}
    land(MAIN, WEAPON)
    land(OFF, SHIELD)
    advance(0)
    eq(#asked(HEAD), 0, "the hat's slot still waits")
    land(HEAD, nil)
    advance(0)
    eq(#asked(HEAD), 1, "the hat asked for once")
    eq(asked(HEAD)[1], HAT, "the hat")
end)

---------------------------------------------------------------------------
-- User Story 3: no fishing mode without room for the off hand (B3)
---------------------------------------------------------------------------

local NO_ROOM = "Fishing mode needs a free bag slot for"

test("full bags keep fishing mode off", function()
    reset()
    free_slots = 0
    ns.Mode.Enter()
    eq(ns.Mode.IsActive(), false, "fishing mode off")
    eq(#equip_calls, 0, "nothing equipped")
    eq(ns.charDB.gearSwap, nil, "nothing recorded")
    eq(chat_count(NO_ROOM), 1, "the reason once")
    eq(chat_count(link(SHIELD)), 1, "the off-hand item named")
end)

test("the mode enters as before when the pole needs no room", function()
    local cases = {
        { "one free slot", function() free_slots = 1 end },
        { "the pole in hand", function()
            free_slots, inventory[MAIN], inventory[OFF] = 0, POLE, nil
        end },
        { "the gear setting off", function()
            free_slots, ns.db.settings.gear = 0, false
        end },
        { "nothing in the off hand", function()
            free_slots, inventory[OFF] = 0, nil
        end },
    }
    for _, case in ipairs(cases) do
        reset()
        case[2]()
        ns.Mode.Enter()
        eq(ns.Mode.IsActive(), true, case[1])
        eq(chat_count(NO_ROOM), 0, case[1] .. ": no reason printed")
    end
end)

test("the resume after /reload with full bags stays off and restores as before", function()
    reset()
    free_slots = 0
    inventory[HEAD] = HAT
    ns.charDB.gearSwap = { [HEAD] = { previous = link(OLD_HAT), equipped = HAT } }
    ns.charDB.resumeMode = true
    fire("PLAYER_ENTERING_WORLD", false, true)
    advance(1)
    eq(ns.Mode.IsActive(), false, "the mode did not resume")
    eq(chat_count(NO_ROOM), 1, "the reason once")
    eq(asked(HEAD)[1], link(OLD_HAT), "the login restore put the old hat back")
    eq(#asked(MAIN), 0, "no pole")
end)

---------------------------------------------------------------------------
-- The debug report (D8)
---------------------------------------------------------------------------

test("the debug state shows the waiting slots and the queued action", function()
    reset()
    local slots, action = ns.Gear.DebugState()
    eq(#slots, 0, "idle: no slot waits")
    eq(action, nil, "idle: nothing queued")
    ns.Mode.Enter()
    ns.Mode.Exit()
    slots, action = ns.Gear.DebugState()
    eq(table.concat(slots, " "), "16 17", "the main and the off hand wait")
    eq(action, "restore all", "the exit queued")
    ns.Gear.RestoreWeapons()
    slots, action = ns.Gear.DebugState()
    eq(action, "restore all", "still all")
end)
