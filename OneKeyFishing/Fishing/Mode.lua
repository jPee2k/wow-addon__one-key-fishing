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

-- Every CVar fishing mode may change. Fields:
--   value    the string to set, or a function old -> string (the value depends on the player's own one)
--   setting  the settings key that asks for the row (none: always)
--   live     a change of that setting while the mode is on applies or restores the row at once (spec 013)
--   combat   "lift": not wanted during a fight, so it is restored at the fight's start and set again after it
-- Soft-target interact must work with keyboard and mouse (3) for the hook key to find the bobber.
local CVARS = {
    { name = "SoftTargetInteract", value = "3" },
    { name = "autoLootDefault", value = "1", setting = "autoLoot" },
    { name = "SoftTargetIconGameObject", value = "1", setting = "bobberIcon" },
    { name = "SoftTargetIconInteract", value = "1", setting = "bobberIcon" },
    -- The "Sound effects" page (spec 013): the game's "Sound in Background", for the time of fishing mode only; a
    -- fight keeps it.
    -- Seen in game 2026-11-16 (V49): with it on, the splash and the addon's sounds play with the window unfocused.
    { name = "Sound_EnableSoundWhenGameIsInBG", value = "1", setting = "backgroundSound", live = true },
    -- The splash focus: music, ambience and dialog silent, effects on and at least 90 %, so the bobber's splash stands
    -- out. Lifted in a fight, where the player needs the game's sound (spec 013 FR-018).
    { name = "Sound_MusicVolume", value = "0", setting = "splashFocus", live = true, combat = "lift" },
    { name = "Sound_AmbienceVolume", value = "0", setting = "splashFocus", live = true, combat = "lift" },
    { name = "Sound_DialogVolume", value = "0", setting = "splashFocus", live = true, combat = "lift" },
    { name = "Sound_EnableSFX", value = "1", setting = "splashFocus", live = true, combat = "lift" },
    { name = "Sound_SFXVolume", setting = "splashFocus", live = true, combat = "lift",
        value = function(old) return tostring(math.max(tonumber(old) or 0, 0.9)) end },
}
-- Their names, for the debug report (Core/Debug.lua).
Mode.CVAR_NAMES = {}
local ROWS = {} -- name -> row
for _, cvar in ipairs(CVARS) do
    table.insert(Mode.CVAR_NAMES, cvar.name)
    ROWS[cvar.name] = cvar
end

-- From PLAYER_REGEN_DISABLED to PLAYER_REGEN_ENABLED: the "lift" rows are not wanted and the fishing sounds are
-- silent (Fishing/Sound.lua reads Mode.InFight). A /reload in a fight brings no new PLAYER_REGEN_DISABLED, so the
-- start value comes from the lockdown.
local inFight = InCombatLockdown() and true or false
-- Rows whose value the player changed by hand while fishing, found when a fight or a switch restored them: not set
-- again until the next entry or until their setting is switched on again (spec 013 FR-015).
local playerOwned = {}

function Mode.InFight()
    return inFight
end

-- CVar values are strings; "0.90" and "0.9" are the same number.
local function SameValue(a, b)
    if a == b then
        return true
    end
    local x, y = tonumber(a), tonumber(b)
    return x ~= nil and y ~= nil and math.abs(x - y) < 0.0001
end

-- The value the row sets when the player's own value was `old`.
local function Applied(row, old)
    if type(row.value) == "function" then
        return row.value(old)
    end
    return row.value
end

local function Wanted(row)
    if not active or playerOwned[row.name] then
        return false
    end
    if row.setting and not ns.db.settings[row.setting] then
        return false
    end
    return not (row.combat == "lift" and inFight)
end

-- Puts a saved value back, but only while the CVar still holds what the addon set: a value the player changed while
-- fishing is theirs (constitution Principle III, spec 013 FR-015). A name without a row (an older build's) is set
-- back as it was.
local function RestoreSaved(name, old)
    local row = ROWS[name]
    local current = C_CVar.GetCVar(name)
    local restored = false
    if not row or current == nil or SameValue(current, Applied(row, old)) then
        restored = not SameValue(current, old)
        C_CVar.SetCVar(name, old)
    elseif active then
        playerOwned[name] = true
    end
    ns.charDB.savedCVars[name] = nil
    return restored
end

local function DropEmptyRecord()
    if ns.charDB.savedCVars and next(ns.charDB.savedCVars) == nil then
        ns.charDB.savedCVars = nil
    end
end

-- Seen in game 2026-11-16 (V48): a sound CVar set through C_CVar takes effect at once, also at
-- PLAYER_REGEN_DISABLED.
-- Brings the rows to what they want now: a wanted row not yet saved is recorded first, then set; a saved row no
-- longer wanted (the mode ended, its setting was turned off, a fight lifted it) is restored. `include(row)` limits it
-- to the rows an event concerns: the entry takes every row, a fight only the "lift" rows, a switch only the live
-- rows of its setting, so the other rows keep their "next time you enter fishing mode" behaviour.
local function SyncCVars(include)
    local saved = ns.charDB.savedCVars or {}
    ns.charDB.savedCVars = saved
    for _, row in ipairs(CVARS) do
        if not include or include(row) then
            local old = saved[row.name]
            if Wanted(row) then
                local current = old == nil and C_CVar.GetCVar(row.name)
                if current then
                    -- Recorded before any change (constitution Principle III), also when it already holds the
                    -- addon's value: the record is what tells a later hand change apart (FR-015).
                    saved[row.name] = current
                    local value = Applied(row, current)
                    if not SameValue(current, value) then
                        C_CVar.SetCVar(row.name, value)
                    end
                end
            elseif old ~= nil then
                RestoreSaved(row.name, old)
            end
        end
    end
    DropEmptyRecord()
end

-- Logout, the next login after a crash, and the exit: every saved CVar comes back (by the rule of RestoreSaved).
-- Returns true when a value really changed back.
local function RestoreCVars()
    local saved = ns.charDB.savedCVars
    if not saved then
        return false
    end
    local any = false
    for name, old in pairs(saved) do
        any = RestoreSaved(name, old) or any
    end
    DropEmptyRecord()
    return any
end

function Mode.IsActive()
    return active
end

-- On, but leaving as soon as combat ends.
function Mode.IsExiting()
    return pendingExit
end

-- `owned`: the rows the player changed by hand before a /reload, which the resumed mode leaves to them (spec 015
-- FR-005); nil for every other entry, which starts with none.
local function Enter(owned)
    if active then
        return
    end
    if InCombatLockdown() then
        ns.Print(L["Cannot enter fishing mode in combat."])
        return
    end
    -- Before anything changes: without room for the off hand the game refuses the pole (spec 030).
    local room, offhand = ns.Gear.HasRoomForPole()
    if not room then
        ns.Print(L["Fishing mode needs a free bag slot for %s."], offhand or L["an item"])
        return
    end
    if not ns.Action.Enable() then
        return
    end
    if ns.db.settings.gear then
        ns.Gear.Equip()
    end
    ns.Camera.Apply()
    active = true
    pendingExit = false
    playerOwned = owned or {}
    SyncCVars() -- after `active`, which the rows read
    ns.Print(L["Fishing mode %s."], "|cff00ff00" .. L["ON"] .. "|r")
    ns.Fire("MODE_CHANGED", true)
end

-- Enter(owned) stays private: every caller from outside (the key, the toggle, the commands) starts with no
-- player-owned rows (spec 015 contract M5).
function Mode.Enter()
    Enter(nil)
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

local function LiftedInFight(row)
    return row.combat == "lift"
end

-- The values the lifted rows had right after a fight lifted them: a different value at the fight's end was set by
-- the player during the fight, and stays theirs (FR-015).
local liftedValues = {}

ns.RegisterEvent("PLAYER_REGEN_DISABLED", function()
    -- Before the lockdown: the rows lifted in a fight come back now (the splash focus, spec 013 FR-018).
    inFight = true
    liftedValues = {}
    if active then
        local saved = ns.charDB.savedCVars or {}
        local restoring = {}
        for _, row in ipairs(CVARS) do
            if LiftedInFight(row) and saved[row.name] ~= nil then
                restoring[row.name] = true -- applied by the focus, so restored now
            end
        end
        SyncCVars(LiftedInFight)
        for name in pairs(restoring) do
            liftedValues[name] = C_CVar.GetCVar(name)
        end
    end
    if active and ns.db.settings.exitOnCombat then
        pendingExit = true
        -- Weapons can be swapped here, before the combat lockdown; the rest of the gear waits until combat ends.
        ns.Gear.RestoreWeapons()
        PrintHint(L["Leaving fishing mode after combat."])
    end
end)

ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
    inFight = false
    if pendingExit then
        Mode.Exit()
    elseif active then
        for name, value in pairs(liftedValues) do
            if not SameValue(C_CVar.GetCVar(name), value) then
                playerOwned[name] = true
            end
        end
        SyncCVars(LiftedInFight) -- the lifted rows are set again (first: an error in Rebind must not keep them off)
        ns.Action.Rebind()
    end
    liftedValues = {}
end)

-- A live row's setting switched while fishing: applied or restored at once (spec 013 FR-016). The other rows keep
-- their "next time you enter fishing mode" behaviour.
local LIVE_SETTINGS = {} -- the settings of the live rows
for _, row in ipairs(CVARS) do
    if row.live then
        LIVE_SETTINGS[row.setting] = true
    end
end

ns.On("SETTINGS_CHANGED", function(key)
    if not active or not LIVE_SETTINGS[key] then
        return
    end
    -- A switch clears the player's mark of its rows: switched on, the addon's value is wanted again; switched off,
    -- a row the player changed is marked again by its restore.
    SyncCVars(function(row)
        if row.live and row.setting == key then
            playerOwned[row.name] = nil
            return true
        end
        return false
    end)
end)

ns.RegisterEvent("PLAYER_LOGIN", function()
    -- Left over from a session that ended without leaving the mode (crash, disconnect).
    if RestoreCVars() then
        ns.Print(L["Restored game settings from an unfinished fishing session."])
    end
end)

-- PLAYER_LOGOUT also fires on /reload: restore CVars now and resume the mode if it was only a reload.
ns.RegisterEvent("PLAYER_LOGOUT", function()
    if active then
        RestoreCVars() -- marks every row the player changed by hand as theirs
        ns.charDB.resumeMode = true
        -- Kept for the resume, so the mode does not silence again what the player turned up (spec 015 FR-005). Only
        -- the live rows (the "Sound effects" page), which their switch takes back: the other rows are set again by the
        -- resume as before, so a soft target changed by hand or by another addon cannot keep the hook key from the
        -- bobber past a /reload.
        local owned
        for name in pairs(playerOwned) do
            if ROWS[name] and ROWS[name].live then
                owned = owned or {}
                owned[name] = true
            end
        end
        ns.charDB.resumeOwned = owned
    end
end)

-- Bindings and the spellbook are not reliably ready on PLAYER_ENTERING_WORLD, so wait a moment.
local RESUME_DELAY = 1

ns.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, isInitialLogin, isReloadingUi)
    local resume = ns.charDB.resumeMode and isReloadingUi
    -- The hand-changed rows count only for this resume; a real login or a resume that does not happen (a fight) is
    -- the end of the mode, and drops them (spec 015 FR-006).
    local owned = resume and ns.charDB.resumeOwned or nil
    ns.charDB.resumeMode, ns.charDB.resumeOwned = nil, nil
    -- Only on a real login: loading screens also fire this event while the mode stays on.
    if isInitialLogin then
        ns.Camera.Forget()
    end
    C_Timer.After(RESUME_DELAY, function()
        if resume then
            Enter(owned)
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
