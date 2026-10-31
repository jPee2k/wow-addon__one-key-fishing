-- Action: the single fishing key.
-- While fishing mode is on, the keys bound to "Fishing action" are overridden:
--   not channeling -> click the secure button (cast Fishing)
--   channeling     -> INTERACTTARGET (hook the bobber via soft-target interact)
-- Override bindings belong to a secure state handler, so they are dropped even inside combat.
local _, ns = ...
local L = ns.L

local Action = {}
ns.Action = Action

local BUTTON_NAME = "OneKeyFishingButton"
local OWNER_NAME = "OneKeyFishingBindingOwner"

local button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
-- Bound clicks arrive as down and up; the template fires on the edge chosen by ActionButtonUseKeyDown.
button:RegisterForClicks("AnyUp", "AnyDown")
button:SetAttribute("type", "spell")

local owner = CreateFrame("Frame", OWNER_NAME, UIParent, "SecureHandlerStateTemplate")
owner:SetAttribute("_onstate-combat", [[
    if newstate == "1" then
        self:ClearBindings()
    end
]])
RegisterStateDriver(owner, "combat", "[combat] 1; 0")

local enabled = false
local channeling = false
local fishingSpellID
local keys = {}

-- What the next press should do, by priority: apply a lure, open a fished container, cast.
-- Returns kind ("lure" | "open" | "cast") and its arguments.
function Action.Resolve()
    local settings = ns.db.settings
    if settings.lure and ns.Bags.NeedsLure() then
        local lureID = ns.Bags.FindLure()
        if lureID then
            return "lure", lureID
        end
    end
    if settings.openContainers then
        local bag, slot = ns.Bags.FindContainer()
        if bag then
            return "open", bag, slot
        end
    end
    return "cast"
end

-- Attributes can only change outside combat; in combat the bindings are dropped anyway.
button:SetScript("PreClick", function(self)
    if InCombatLockdown() then
        return
    end
    local kind, arg1, arg2 = Action.Resolve()
    if kind == "lure" then
        self:SetAttribute("type", "item")
        self:SetAttribute("item", "item:" .. arg1)
        self:SetAttribute("target-slot", INVSLOT_MAINHAND or 16)
        ns.Bags.NoteLureAttempt(arg1)
    elseif kind == "open" then
        self:SetAttribute("type", "item")
        self:SetAttribute("item", arg1 .. " " .. arg2) -- "bag slot"
        self:SetAttribute("target-slot", nil)
        ns.Bags.NoteOpenAttempt(arg1, arg2)
    else
        self:SetAttribute("type", "spell")
        self:SetAttribute("spell", fishingSpellID)
        self:SetAttribute("item", nil)
        self:SetAttribute("target-slot", nil)
    end
end)

local function BoundKeys()
    local list = {}
    local key1, key2 = GetBindingKey("ONEKEYFISHING_ACTION")
    if key1 then
        table.insert(list, key1)
    end
    if key2 then
        table.insert(list, key2)
    end
    return list
end

local function ReadKeys()
    keys = BoundKeys()
    return #keys > 0
end

local function BindCast()
    ClearOverrideBindings(owner)
    for _, key in ipairs(keys) do
        SetOverrideBindingClick(owner, true, key, BUTTON_NAME, "LeftButton")
    end
    ns.Fire("ACTION_STATE", "cast")
end

local function BindInteract()
    ClearOverrideBindings(owner)
    for _, key in ipairs(keys) do
        SetOverrideBinding(owner, true, key, "INTERACTTARGET")
    end
    ns.Fire("ACTION_STATE", "hook")
end

-- Returns false (with a chat hint) when the key cannot work yet.
function Action.Enable()
    local spellID = ns.GetFishingSpellID()
    if not spellID then
        ns.Print(L["You have not learned Fishing."])
        return false
    end
    if not ReadKeys() then
        ns.Print(
            L["No key is bound to 'Fishing action'. Bind one in Options -> Keybindings -> AddOns -> OneKeyFishing."])
        return false
    end
    fishingSpellID = spellID
    button:SetAttribute("spell", spellID)
    enabled = true
    -- No CHANNEL_START comes for a cast that began before a /reload or before the mode was switched on.
    if not channeling then
        local _, _, _, startMS, _, _, _, channelSpellID = UnitChannelInfo("player")
        if startMS and ns.IsFishingSpell(channelSpellID) then
            channeling = true
            ns.Fire("FISHING_CAST_START", channelSpellID)
        end
    end
    -- `channeling` is left to CHANNEL_STOP: re-entering during a cast must still bind the hook.
    if channeling then
        BindInteract()
    else
        BindCast()
    end
    return true
end

-- `channeling` is not reset here: CHANNEL_STOP of a cast that is still running must still fire FISHING_CAST_STOP.
function Action.Disable()
    enabled = false
    if not InCombatLockdown() then
        ClearOverrideBindings(owner)
    end
    ns.Fire("ACTION_STATE", nil)
end

-- Re-reads the keys after the player changed the binding while the mode is on. Returns true if they changed.
-- With every key unbound the old ones are kept until the mode is left.
local function RefreshKeys()
    local fresh = BoundKeys()
    if #fresh == 0 or (fresh[1] == keys[1] and fresh[2] == keys[2]) then
        return false
    end
    keys = fresh
    return true
end

-- Restores the right binding after combat dropped it or the keys changed.
function Action.Rebind()
    if not enabled or InCombatLockdown() then
        return
    end
    RefreshKeys()
    if channeling then
        BindInteract()
    else
        BindCast()
    end
end

-- Our own overrides fire this event too, so rebind only when the keys really changed.
ns.RegisterEvent("UPDATE_BINDINGS", function()
    if enabled and not InCombatLockdown() and RefreshKeys() then
        Action.Rebind()
    end
end)

function Action.IsChanneling()
    return channeling
end

ns.RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", function(_, unit, _, spellID)
    if unit ~= "player" or not enabled or not ns.IsFishingSpell(spellID) then
        return
    end
    channeling = true
    if not InCombatLockdown() then
        BindInteract()
    end
    ns.Fire("FISHING_CAST_START", spellID)
end)

ns.RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", function(_, unit, _, spellID)
    if unit ~= "player" or not channeling then
        return
    end
    channeling = false
    if enabled and not InCombatLockdown() then
        BindCast()
    end
    ns.Fire("FISHING_CAST_STOP", spellID)
end)
