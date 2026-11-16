-- Fishing/Mode.lua: a game setting fishing mode changed is put back only while it still holds the value the addon
-- set; a value the player changed while fishing stays (constitution Principle III, spec 013 FR-015, research R6).

load_addon()

local function cvar(name)
    return C_CVar.GetCVar(name)
end

test("auto loot is set while fishing and put back on exit", function()
    C_CVar.SetCVar("autoLootDefault", "0")
    ns.db.settings.autoLoot = true
    enter_fishing_mode()
    eq(cvar("autoLootDefault"), "1", "on while fishing")
    eq(ns.charDB.savedCVars.autoLootDefault, "0", "the old value recorded")
    ns.Mode.Exit()
    eq(cvar("autoLootDefault"), "0", "back after the exit")
    eq(ns.charDB.savedCVars, nil, "no record left")
end)

test("a value the player changed while fishing is kept at the exit", function()
    C_CVar.SetCVar("SoftTargetInteract", "0")
    enter_fishing_mode()
    eq(cvar("SoftTargetInteract"), "3", "set by fishing mode")
    C_CVar.SetCVar("SoftTargetInteract", "1") -- by hand, in the game's options
    ns.Mode.Exit()
    eq(cvar("SoftTargetInteract"), "1", "the player's value, not the old 0")
    eq(ns.charDB.savedCVars, nil, "the records are dropped")
end)

test("a saved name without a row (an older build's) is set back at login", function()
    C_CVar.SetCVar("someOldCVar", "9")
    ns.charDB.savedCVars = { someOldCVar = "5" }
    fire("PLAYER_LOGIN")
    eq(cvar("someOldCVar"), "5", "set back")
    eq(ns.charDB.savedCVars, nil, "no record left")
end)

-- Final review: the login line only when a value really came back.
test("a crash record whose CVars already hold the player's values restores nothing and says nothing", function()
    local line = ns.L["Restored game settings from an unfinished fishing session."]
    chat = {}
    C_CVar.SetCVar("autoLootDefault", "0")
    ns.charDB.savedCVars = { autoLootDefault = "0" }
    fire("PLAYER_LOGIN")
    eq(chat_count(line), 0, "no line")
    eq(ns.charDB.savedCVars, nil, "the record is dropped")
    C_CVar.SetCVar("autoLootDefault", "1")
    ns.charDB.savedCVars = { autoLootDefault = "0" }
    fire("PLAYER_LOGIN")
    eq(chat_count(line), 1, "the line when a value came back")
    eq(C_CVar.GetCVar("autoLootDefault"), "0", "restored")
end)
