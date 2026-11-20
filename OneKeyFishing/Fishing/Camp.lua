-- Camp: the camp bonuses (spec 020), the fishing buffs of a Fishing Rack or a Fishing Hut placed by a campfire. It
-- reads the player's aura of each bonus by its spell ID (GameData/CampBonuses.lua), keeps the state through a fight,
-- in which the game hides the auras, and answers per cast the mask of the bonuses the cast counts for (research R2,
-- R3). It only reads: nothing is cast, used or placed, and no frame is made (FR-008).
local _, ns = ...

local Camp = {}
ns.Camp = Camp

local BONUSES = ns.GameData.CampBonuses -- in rank order
local KEEP_CASTS = 8 -- a cast's mask is kept until it settles, or until it is more than this many casts old

-- state[key] = { known, expires }: known: read at least once this session; expires: the GetTime() at which the buff
-- ends, nil when not active.
local state = {}
-- The bonuses by key and the known bonus items (item ID -> the keys of the bonuses whose list names it, in rank
-- order: a Bloated fish is both bonuses'): Camp is the one owner of these lookups (CatchDB and Catalog ask it).
local BY_KEY, KNOWN_ITEMS = {}, {}
for _, bonus in ipairs(BONUSES) do
    state[bonus.key] = { known = false }
    BY_KEY[bonus.key] = bonus
    for itemID in pairs(bonus.items) do
        KNOWN_ITEMS[itemID] = KNOWN_ITEMS[itemID] or {}
        table.insert(KNOWN_ITEMS[itemID], bonus.key)
    end
end
local QUEST_ITEMS = ns.GameData.FishedQuestItems

local castMasks = {} -- castID -> the mask at the cast's start, or false when it was unknown
local lastMask -- what CastMask last answered (the debug report)

-- The bonus's game data entry ({ key, bit, aura, item, items }), or nil.
function Camp.Bonus(key)
    return BY_KEY[key]
end

-- Auras are restricted in a fight: the call returns nothing for an aura that is up (seen 2026-11-19). The player's
-- combat flag counts too: it is set before the lockdown (PLAYER_REGEN_DISABLED runs first), and an aura event of the
-- fight's first moment must not read an empty answer as "no buff".
-- VERIFY(V69): the player's combat flag is clear when PLAYER_REGEN_ENABLED fires
local function Restricted()
    if InCombatLockdown() or (UnitAffectingCombat ~= nil and UnitAffectingCombat("player")) then
        return true
    end
    return C_Secrets ~= nil and C_Secrets.ShouldAurasBeSecret ~= nil and C_Secrets.ShouldAurasBeSecret() == true
end

---------------------------------------------------------------------------
-- The notices (research R10): "ends in 5 minutes" and "has ended", decided by a check after every allowed read and
-- when a timer comes due (it reads first); the clock alone never shows one. A crossing is marked as passed the moment
-- it is found; the notice shows only with fishing mode and the setting on then, the five-minute one only within
-- WINDOW seconds of the crossing. A renewed buff (a later expiration on a read) starts a new pair of crossings.
---------------------------------------------------------------------------
local WARN = 300 -- seconds left at the five-minute crossing
local WINDOW = 30 -- a five-minute crossing found later than this (after a fight) stays silent
-- A crossing passes once per buff: the end clears `tracked`, and after the five-minute one `seen` stays at or below
-- WARN until a renewal (a new expiration) starts over.
local tracked = {} -- key -> the expiration of the buff the last check saw active
local seen = {} -- key -> the seconds left at the last check of that buff

-- The texts are read when a notice fires, never while the files load.
local function NoticeText(key, kind)
    local L = ns.L
    local texts = {
        rack = { warn = L["The Fishing Rack bonus ends in 5 minutes."],
            ended = L["The Fishing Rack bonus has ended."] },
        hut = { warn = L["The Fishing Hut bonus ends in 5 minutes."],
            ended = L["The Fishing Hut bonus has ended."] },
    }
    return texts[key][kind]
end

local function Notify(key, kind)
    if ns.Mode.IsActive() and ns.db and ns.db.settings.campBonusWarning then
        ns.Fire("CAMP_BONUS_WARNING", NoticeText(key, kind))
    end
end

-- A timer a second past each threshold, so its own check always finds the crossing; it does nothing while auras
-- are restricted (the read at the fight's end checks then).
local function Arm(seconds)
    if seconds > 0 and seconds < math.huge then
        C_Timer.After(seconds, function()
            Camp.Read()
        end)
    end
end

local function Check()
    local now = GetTime()
    for _, bonus in ipairs(BONUSES) do
        local key = bonus.key
        local s = state[key]
        local expires = s.expires
        local active = expires ~= nil and now < expires
        local last = tracked[key]
        if last and (not active or expires ~= last) then
            -- Gone (a read found nothing, or its time passed), or renewed (no end for the old one).
            if not active then
                Notify(key, "ended")
            end
            tracked[key] = nil
        end
        if active then
            local left = expires - now
            if tracked[key] ~= expires then
                tracked[key], seen[key] = expires, left
                Arm(left - (WARN - 1))
                Arm(left + 1)
            end
            if seen[key] > WARN and left <= WARN then
                if WARN - left <= WINDOW then
                    Notify(key, "warn")
                end
            end
            seen[key] = left
        end
    end
end

-- Reads every bonus's aura when auras are not restricted; returns whether a read happened. A table with a plain
-- expiration time is an active buff, nothing is no buff, anything else is a failed read that changes nothing. Every
-- read is followed by the notices' check.
function Camp.Read()
    if Restricted() then
        return false
    end
    for _, bonus in ipairs(BONUSES) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(bonus.aura)
        local s = state[bonus.key]
        if aura == nil then
            s.known, s.expires = true, nil
        elseif not ns.IsSecret(aura) and type(aura) == "table" then
            local expires = aura.expirationTime
            if not ns.IsSecret(expires) and type(expires) == "number" then
                if expires <= 0 then
                    expires = math.huge -- an aura without an end
                end
                s.known, s.expires = true, expires
            end
        end
    end
    Check()
    return true
end

-- true, false, or nil when the bonus's state is unknown.
function Camp.IsActive(key)
    local s = state[key]
    if not s or not s.known then
        return nil
    end
    return s.expires ~= nil and GetTime() < s.expires
end

-- Seconds until the bonus ends, or nil when it is not active or unknown.
function Camp.TimeLeft(key)
    if Camp.IsActive(key) then
        return state[key].expires - GetTime()
    end
end

-- VERIFY(V62): both auras can be held at once
-- The sum of the bits of the active bonuses (0: none), or nil when any bonus's state is unknown.
function Camp.Mask()
    local mask = 0
    for _, bonus in ipairs(BONUSES) do
        local active = Camp.IsActive(bonus.key)
        if active == nil then
            return nil
        elseif active then
            mask = mask + bonus.bit
        end
    end
    return mask
end

-- Whether the mask (a number) holds the bonus's bit.
function Camp.HasBit(mask, key)
    local bonus = BY_KEY[key]
    return bonus ~= nil and type(mask) == "number" and math.floor(mask / bonus.bit) % 2 == 1
end

-- The keys of the bonuses whose known list names the item, in rank order (a list, not to be changed), or nil.
function Camp.KnownBonuses(itemID)
    return KNOWN_ITEMS[itemID]
end

-- Whether the mask holds the bit of one of the bonuses whose known list names the item.
local function KnownUnder(mask, itemID)
    for _, key in ipairs(KNOWN_ITEMS[itemID] or {}) do
        if Camp.HasBit(mask, key) then
            return true
        end
    end
    return false
end

-- A quest item fished beside the ordinary catch without any bonus (GameData/FishedQuestItems.lua): its slot is no
-- camp bonus.
local function IsQuestItem(itemID)
    if QUEST_ITEMS.items[itemID] then
        return true
    end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
    return classID == QUEST_ITEMS.classID
end

-- VERIFY(V63): the bonus is decided by the aura during the cast
-- The mask the cast counts for: its start mask when that is a number equal to Mask() now, else 0 (a buff that began
-- or ended in the cast, or a state not known, counts for no bonus: decision 17). Drops the masks of earlier casts and
-- keeps this one: two modules ask for the same cast, and a miss settles a second after its cast stopped, when the next
-- cast may have started.
function Camp.CastMask(castID)
    if type(castID) ~= "number" then
        return 0
    end
    for id in pairs(castMasks) do
        if id < castID then
            castMasks[id] = nil
        end
    end
    local start = castMasks[castID]
    local mask = 0
    if type(start) == "number" and start == Camp.Mask() then
        mask = start
    end
    lastMask = mask
    return mask
end

-- Whether a catch under the mask is a bonus catch (the statistics' bonus catches, FR-034, decision 33): it holds a
-- known bonus item of one of the mask's bonuses, or, without the quest items fished beside an ordinary catch, two
-- loot slots or more (both bonuses give their extra item as a second slot; without a buff a catch has one).
-- items: the list of FISH_CAUGHT, one { itemID, ... } entry per loot slot.
-- VERIFY(V68): without a camp buff a catch has one loot slot, quest items aside
function Camp.IsBonusCatch(mask, items)
    if type(mask) ~= "number" or mask <= 0 then
        return false
    end
    local slots = 0
    for _, item in ipairs(items or {}) do
        local itemID = item.itemID
        if itemID and KnownUnder(mask, itemID) then
            return true
        end
        if itemID and not IsQuestItem(itemID) then -- an entry without an item ID (a currency link) is no item
            slots = slots + 1
        end
    end
    if slots >= 2 then
        return true
    end
    return false
end

-- Lines for /okf debug (research R14), English: each bonus's state, whether aura reads are restricted now, the mask
-- the last settled cast counted for, and the setting.
function Camp.Describe()
    local lines = {}
    for _, bonus in ipairs(BONUSES) do
        local active, text = Camp.IsActive(bonus.key), "unknown"
        local left = active and Camp.TimeLeft(bonus.key)
        if left and left == math.huge then
            text = "active, no end"
        elseif left then
            text = ("active, %d s left"):format(math.floor(left))
        elseif active == false then
            text = "not active"
        end
        table.insert(lines, ("%s: aura %d, %s"):format(bonus.key, bonus.aura, text))
    end
    table.insert(lines, "aura reads restricted: " .. tostring(Restricted()))
    table.insert(lines, "last cast mask: " .. (lastMask and tostring(lastMask) or "none"))
    table.insert(lines, "setting campBonusWarning: " .. tostring(ns.db and ns.db.settings.campBonusWarning))
    return lines
end

local function OnCastStart()
    Camp.Read()
    local castID = ns.GetFishingCastID()
    castMasks[castID] = Camp.Mask() or false
    for id in pairs(castMasks) do
        if id < castID - KEEP_CASTS then
            castMasks[id] = nil
        end
    end
end

ns.RegisterEvent("PLAYER_ENTERING_WORLD", function()
    Camp.Read()
end)
-- VERIFY(V65): UNIT_AURA fires when the aura comes and goes out of combat
-- UNIT_AURA is registered for the player only (it fires for every unit around); its payload (secret tables in a
-- fight) is never read.
ns.RegisterUnitEvent("UNIT_AURA", "player", function(_, unit)
    if not ns.IsSecret(unit) and unit == "player" then
        Camp.Read()
    end
end)
ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
    Camp.Read()
end)
-- Catch.lua (earlier in the TOC) has numbered the new cast when this runs.
ns.On("FISHING_CAST_START", OnCastStart)
