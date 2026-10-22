-- Mode: entering and leaving fishing mode.
-- Every CVar changed on enter is saved to the character DB first, so leaving the mode,
-- logging out, or even a crash followed by the next login restores the original values.
local _, ns = ...

local Mode = {}
ns.Mode = Mode

local active = false
local pendingExit = false

local function DesiredCVars()
    local settings = ns.db.settings
    -- Soft-target interact must work with keyboard and mouse (3) for the hook key to find the bobber.
    local cvars = { SoftTargetInteract = "3" }
    if settings.autoLoot then
        cvars.autoLootDefault = "1"
    end
    if settings.bobberIcon then
        cvars.SoftTargetIconGameObject = "1"
        cvars.SoftTargetIconInteract = "1"
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

function Mode.Enter()
    if active then
        return
    end
    if InCombatLockdown() then
        ns.Print("Cannot enter fishing mode in combat.")
        return
    end
    if not ns.Action.Enable() then
        return
    end
    ApplyCVars()
    active = true
    pendingExit = false
    ns.Print("Fishing mode |cff00ff00ON|r.")
    ns.Fire("MODE_CHANGED", true)
end

function Mode.Exit()
    if not active then
        return
    end
    -- Bindings are already dropped by the secure combat handler; finish the rest after combat.
    if InCombatLockdown() then
        pendingExit = true
        return
    end
    ns.Action.Disable()
    RestoreCVars()
    active = false
    pendingExit = false
    ns.Print("Fishing mode |cffff3333OFF|r.")
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
        ns.Print("Restored game settings from an unfinished fishing session.")
    end
end)

-- PLAYER_LOGOUT also fires on /reload: restore CVars now and resume the mode if it was only a reload.
ns.RegisterEvent("PLAYER_LOGOUT", function()
    if active then
        RestoreCVars()
        ns.charDB.resumeMode = true
    end
end)

ns.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, _, isReloadingUi)
    if not ns.charDB.resumeMode then
        return
    end
    ns.charDB.resumeMode = nil
    if isReloadingUi then
        Mode.Enter()
    end
end)

-- Called from Bindings.xml
function OneKeyFishing_ToggleMode()
    Mode.Toggle()
end

-- The action key only does something while the mode is on; outside of it, explain why.
local lastHint = 0
function OneKeyFishing_ActionKeyIdle()
    if GetTime() - lastHint > 5 then
        lastHint = GetTime()
        ns.Print("Fishing mode is off. Press your 'Toggle fishing mode' key first.")
    end
end

ns.RegisterCommand("toggle", "enter or leave fishing mode", Mode.Toggle)
