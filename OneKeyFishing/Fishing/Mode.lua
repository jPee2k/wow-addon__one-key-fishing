-- Mode: entering and leaving fishing mode.
-- Every CVar changed on enter is saved to the character DB first, so leaving the mode,
-- logging out, or even a crash followed by the next login restores the original values.
local _, ns = ...
local L = ns.L

local Mode = {}
ns.Mode = Mode

local active = false
local pendingExit = false
-- The last key hint or combat line and its GetTime(): the same line waits 5 s before the key hint repeats it.
local lastHint, lastHintText = 0, nil

local function PrintHint(message)
    lastHint, lastHintText = GetTime(), message
    ns.Print(message)
end

-- Every CVar fishing mode may change, with its value and the setting that asks for it (none: always). Soft-target
-- interact must work with keyboard and mouse (3) for the hook key to find the bobber.
local CVARS = {
    { name = "SoftTargetInteract", value = "3" },
    { name = "autoLootDefault", value = "1", setting = "autoLoot" },
    { name = "SoftTargetIconGameObject", value = "1", setting = "bobberIcon" },
    { name = "SoftTargetIconInteract", value = "1", setting = "bobberIcon" },
}
-- Their names, for the debug report (Core/Debug.lua).
Mode.CVAR_NAMES = {}
for _, cvar in ipairs(CVARS) do
    table.insert(Mode.CVAR_NAMES, cvar.name)
end

local function DesiredCVars()
    local settings = ns.db.settings
    local cvars = {}
    for _, cvar in ipairs(CVARS) do
        if not cvar.setting or settings[cvar.setting] then
            cvars[cvar.name] = cvar.value
        end
    end
    return cvars
end

local function ApplyCVars()
    local saved = {}
    for name, value in pairs(DesiredCVars()) do
        local current = C_CVar.GetCVar(name)
        if current ~= nil then
            saved[name] = current
            C_CVar.SetCVar(name, value)
        end
    end
    ns.charDB.savedCVars = saved
end

local function RestoreCVars()
    local saved = ns.charDB.savedCVars
    if not saved then
        return
    end
    for name, value in pairs(saved) do
        C_CVar.SetCVar(name, value)
    end
    ns.charDB.savedCVars = nil
end

function Mode.IsActive()
    return active
end

-- On, but leaving as soon as combat ends.
function Mode.IsExiting()
    return pendingExit
end

function Mode.Enter()
    if active then
        return
    end
    if InCombatLockdown() then
        ns.Print(L["Cannot enter fishing mode in combat."])
        return
    end
    if not ns.Action.Enable() then
        return
    end
    if ns.db.settings.gear then
        ns.Gear.Equip()
    end
    ns.Camera.Apply()
    ApplyCVars()
    active = true
    pendingExit = false
    ns.Print(L["Fishing mode %s."], "|cff00ff00" .. L["ON"] .. "|r")
    ns.Fire("MODE_CHANGED", true)
end

function Mode.Exit()
    if not active then
        return
    end
    -- Bindings are already dropped by the secure combat handler. Equipping is protected in the lockdown, weapons
    -- too (constitution III): the gear and the rest come back when the fight ends (spec 009).
    if InCombatLockdown() then
        if not pendingExit then
            pendingExit = true
            PrintHint(L["Leaving fishing mode after combat."])
        end
        return
    end
    ns.Action.Disable()
    ns.Gear.Restore()
    ns.Camera.Restore()
    RestoreCVars()
    active = false
    pendingExit = false
    ns.Print(L["Fishing mode %s."], "|cffff3333" .. L["OFF"] .. "|r")
    ns.Fire("MODE_CHANGED", false)
end

function Mode.Toggle()
    if active then
        Mode.Exit()
    else
        Mode.Enter()
    end
end

ns.RegisterEvent("PLAYER_REGEN_DISABLED", function()
    if active and ns.db.settings.exitOnCombat then
        pendingExit = true
        -- Weapons can be swapped here, before the combat lockdown; the rest of the gear waits until combat ends.
        ns.Gear.RestoreWeapons()
        PrintHint(L["Leaving fishing mode after combat."])
    end
end)

ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if pendingExit then
        Mode.Exit()
    elseif active then
        ns.Action.Rebind()
    end
end)

ns.RegisterEvent("PLAYER_LOGIN", function()
    -- Left over from a session that ended without leaving the mode (crash, disconnect).
    if ns.charDB.savedCVars then
        RestoreCVars()
        ns.Print(L["Restored game settings from an unfinished fishing session."])
    end
end)

-- PLAYER_LOGOUT also fires on /reload: restore CVars now and resume the mode if it was only a reload.
ns.RegisterEvent("PLAYER_LOGOUT", function()
    if active then
        RestoreCVars()
        ns.charDB.resumeMode = true
    end
end)

-- Bindings and the spellbook are not reliably ready on PLAYER_ENTERING_WORLD, so wait a moment.
local RESUME_DELAY = 1

ns.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, isInitialLogin, isReloadingUi)
    local resume = ns.charDB.resumeMode and isReloadingUi
    ns.charDB.resumeMode = nil
    -- Only on a real login: loading screens also fire this event while the mode stays on.
    if isInitialLogin then
        ns.Camera.Forget()
    end
    C_Timer.After(RESUME_DELAY, function()
        if resume then
            Mode.Enter()
        end
        if not active then
            -- Logged out or crashed in fishing gear, or the mode could not resume (e.g. in combat):
            -- put the normal gear and camera back.
            if ns.Gear.HasPendingRestore() then
                ns.Gear.Restore() -- in combat Gear waits for the fight's end
            end
            ns.Camera.Restore()
        end
    end)
end)

-- Called from Bindings.xml
function OneKeyFishing_ToggleMode()
    Mode.Toggle()
end

-- The action key only does something while the mode is on; outside of it, explain why.
function OneKeyFishing_ActionKeyIdle()
    local message
    if not active then
        message = L["Fishing mode is off. Press your 'Toggle fishing mode' key first."]
    elseif pendingExit then
        message = L["Leaving fishing mode after combat."]
    elseif InCombatLockdown() then
        message = L["The fishing key is paused in combat."] -- combat dropped the key's bindings
    end
    if message and (message ~= lastHintText or GetTime() - lastHint > 5) then
        PrintHint(message)
    end
end
