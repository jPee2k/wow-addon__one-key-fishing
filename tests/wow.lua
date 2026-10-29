-- WoW API stubs and test helpers. tests/run.mjs loads this file before every *_test.lua, in a fresh Lua state,
-- and sets ADDON_DIR and TOC_FILES (the addon's Lua files in TOC order).
--
-- The tests run in fengari, which is Lua 5.3; the game runs Lua 5.1. The library parts that only 5.2/5.3 have
-- are removed below, so code that needs them fails here as in the game. The addon also avoids behaviour that
-- differs between the two, such as string.format("%d") with a fraction (5.3 rejects it, 5.1 truncates): use
-- math.floor. A test that fails only because of some other 5.3 difference is fixed in the test or the stub.
--
-- Game data a test can set (before load_addon() where a module reads it at load time):
--   bag_items[itemID] = count           C_Item.GetItemCount
--   item_cooldowns[itemID] = { start, duration }   C_Container.GetItemCooldown
--   item_prices[itemID] = copper        vendor price from C_Item.GetItemInfo
--   weapon_enchant = true               GetWeaponEnchantInfo (a lure on the pole)
--   in_combat = true                    InCombatLockdown
--   loot = { fishing = true, items = { { itemID, quantity } } }   the open loot window (fire LOOT_READY)
--   addon_version = "@project-version@"   the TOC's Version field (C_AddOns.GetAddOnMetadata)
--   CLIENT_LOCALE = "deDE"              GetLocale (the game client's language), set before load_addon()
--   bindings[name] = { "`", "'" }       GetBindingKey (the keys of a binding, in the game's order)
--   settings_pages[name]                the frames registered with the Settings panel (read, not set)
--   player_map_id = 1415                C_Map.GetBestMapForUnit("player") (default 1)
--   map_names[mapID] = "Elwynn Forest"  the name in C_Map.GetMapInfo (default "Test Zone")
--   player_map_position = { x, y }      C_Map.GetPlayerMapPosition (nil: no position, as in an instance)
--   fishing_rank = 150                  the Fishing rank from GetProfessions / GetProfessionInfo (nil: not learned)
--   loot_sources[slot] = guid           GetLootSourceInfo of the open loot window
--   build_version = "1.60.2"            the version string of GetBuildInfo (default "1.60.1")
--   commodity_results[itemID] = { { unitPrice, quantity } }, commodity_total[itemID] = n,
--   item_results[itemID] = { { buyoutAmount, quantity } }   auction search results (fire the result event)
--   panel_tabs                          calls of PanelTemplates_SetNumTabs / SetTab / TabResize, as
--                                       { name, frame or tab, value }; set PanelTemplates_SetTab = nil to test
--                                       the fallback without the game's tab functions
-- Every global not defined here is a permissive stub: it can be called and indexed and returns nil
-- (except the addon's own OneKeyFishing* globals, which are nil until set).

---------------------------------------------------------------------------
-- Lua 5.1 standard library: hide what only Lua 5.3 has, so addon code that needs it fails here too
---------------------------------------------------------------------------
local tunpack = table.unpack
table.unpack, table.move, table.pack = nil, nil, nil
rawlen = nil
local load53 = load
loadstring = load53 -- Lua 5.1 loads a string chunk with loadstring
function load(chunk, ...)
    if type(chunk) == "string" then
        error("load() with a string is Lua 5.2+; the game (Lua 5.1) needs loadstring()", 2)
    end
    return load53(chunk, ...)
end
-- Lua 5.1 functions that fengari no longer has, with their 5.1 behaviour.
math.pow = function(x, y) return x ^ y end
math.mod = math.fmod
local log53 = math.log
math.log10 = function(x) return log53(x, 10) end
math.ldexp = function(m, e) return m * 2 ^ e end
table.getn = function(t) return #t end
table.maxn = function(t)
    local max = 0
    for key in pairs(t) do
        if type(key) == "number" and key > max then
            max = key
        end
    end
    return max
end
string.gfind = string.gmatch
math.log = function(x) return log53(x) end -- Lua 5.1 has no base argument

-- Lua 5.1 string.format("%s") takes only strings and numbers; 5.3 converts anything with tostring.
local format53 = string.format
string.format = function(format, ...)
    local index = 0
    for flags, conversion in tostring(format):gmatch("%%([-+ #0]*%d*%.?%d*)(.)") do
        if conversion ~= "%" then
            index = index + 1
            local value = select(index, ...)
            if conversion == "s" and type(value) ~= "string" and type(value) ~= "number" then
                error(("bad argument #%d to 'format' (string expected, got %s)"):format(index + 1, type(value)), 2)
            end
        end
    end
    return format53(format, ...)
end

-- Lua 5.1 functions that fengari does not have: an error instead of a silent stub. The 5.3 behaviour of
-- __pairs, __ipairs and __len metamethods cannot be switched off; do not rely on them.
local MISSING_51 = { getfenv = true, setfenv = true, gcinfo = true, newproxy = true, bit = true }
math.frexp = function() error("math.frexp exists in the game (Lua 5.1) but not in the test runtime", 2) end
math.type, math.tointeger, math.ult, math.maxinteger, math.mininteger = nil, nil, nil, nil, nil
string.pack, string.unpack, string.packsize = nil, nil, nil
coroutine.isyieldable = nil
utf8 = nil
unpack = tunpack -- a global in Lua 5.1

---------------------------------------------------------------------------
-- Test helpers
---------------------------------------------------------------------------
tests_passed, tests_failed = 0, 0

-- Runs one named test; a failing assert marks it FAIL and the next test still runs.
function test(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if ok then
        tests_passed = tests_passed + 1
        print("  ok   " .. name)
    else
        tests_failed = tests_failed + 1
        print("  FAIL " .. name .. "\n" .. tostring(err))
    end
end

-- assert(actual == expected) with both values in the message.
function eq(actual, expected, what)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(what or "value", tostring(expected), tostring(actual)), 2)
    end
end

-- Like eq for numbers that may carry rounding errors.
function near(actual, expected, what)
    if type(actual) ~= "number" or math.abs(actual - expected) > 1e-6 then
        error(("%s: expected %s, got %s"):format(what or "value", tostring(expected), tostring(actual)), 2)
    end
end

-- Chat lines printed by the addon (ns.Print), oldest first.
chat = {}

function chat_contains(text)
    for _, line in ipairs(chat) do
        if line:find(text, 1, true) then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Time and timers
---------------------------------------------------------------------------
now = 1000
timers = {} -- { at = GetTime() when it runs, fn = callback }, in the order they were created
local MAX_TIMER_RUNS = 10000 -- per advance() or flush_timers(): more means a timer reschedules itself forever

function GetTime()
    return now
end

C_Timer = {
    After = function(delay, fn)
        table.insert(timers, { at = now + delay, fn = fn })
    end,
}

-- Moves the clock forward and runs the timers that are due by then, earliest first, each with the clock at
-- its own due time; timers they create run too if they fall inside the window.
function advance(seconds)
    local target = now + seconds
    local runs = 0
    while true do
        local index
        for i, timer in ipairs(timers) do
            if timer.at <= target and (not index or timer.at < timers[index].at) then
                index = i
            end
        end
        if not index then
            break
        end
        runs = runs + 1
        if runs > MAX_TIMER_RUNS then
            error("more than " .. MAX_TIMER_RUNS .. " timer runs: a timer keeps rescheduling itself", 2)
        end
        local timer = table.remove(timers, index)
        now = math.max(now, timer.at)
        timer.fn()
    end
    now = target
end

-- Runs every pending timer (and the ones they create), moving the clock as far as needed.
function flush_timers()
    local passes = 0
    while #timers > 0 do
        passes = passes + 1
        if passes > MAX_TIMER_RUNS then
            error("more than " .. MAX_TIMER_RUNS .. " timer runs: a timer keeps rescheduling itself", 2)
        end
        local last = now
        for _, timer in ipairs(timers) do
            last = math.max(last, timer.at)
        end
        advance(last - now)
    end
end

time = os.time
date = os.date

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
frames = {} -- every frame created, in order

local Frame = {}

function Frame:RegisterEvent(event)
    self.events[event] = true
end

function Frame:UnregisterEvent(event)
    self.events[event] = nil
end

function Frame:SetScript(name, fn)
    self.scripts[name] = fn
end

function Frame:GetScript(name)
    return self.scripts[name]
end

function Frame:HookScript(name, fn)
    local previous = self.scripts[name]
    self.scripts[name] = function(...)
        if previous then
            previous(...)
        end
        fn(...)
    end
end

function Frame:Show()
    local wasShown = self.shown
    self.shown = true
    if not wasShown and self.scripts.OnShow then
        self.scripts.OnShow(self)
    end
end

function Frame:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then
        self.scripts.OnHide(self)
    end
end

function Frame:SetShown(shown)
    if shown then
        self:Show()
    else
        self:Hide()
    end
end

function Frame:IsShown()
    return self.shown
end

-- Visible: shown, and every parent too (a page in the closed Settings panel is shown but not visible).
function Frame:IsVisible()
    local frame = self
    while frame do
        if not frame.shown then
            return false
        end
        frame = frame.parent
    end
    return true
end

function Frame:SetText(text)
    self.text = text
end

function Frame:GetText()
    return self.text
end

function Frame:SetFormattedText(format, ...)
    self.text = format:format(...)
end

-- Sizes are remembered; an unsized frame is 100 x 100.
function Frame:SetWidth(width)
    self.width = width
end

function Frame:GetWidth()
    return self.width or 100
end

function Frame:SetHeight(height)
    self.height = height
end

function Frame:GetHeight()
    return self.height or 100
end

function Frame:SetSize(width, height)
    self.width, self.height = width, height
end

local NewFrame

-- An unknown CamelCase key is either a method or a template child (frame.CloseButton, frame.Text):
-- this member can be called as a no-op method and used as a child whose methods are no-ops.
local memberMeta = {}
memberMeta.__call = function() end
memberMeta.__index = function()
    return setmetatable({}, memberMeta)
end

-- Unknown lowercase keys (fields) are nil.
local frameMeta = {
    __index = function(frame, key)
        if Frame[key] then
            return Frame[key]
        end
        if type(key) == "string" and key:find("^Create") then
            return function(self)
                return NewFrame(self)
            end
        end
        if type(key) == "string" and key:find("^%u") then
            local member = setmetatable({}, memberMeta)
            rawset(frame, key, member)
            return member
        end
    end,
}

-- Frames start shown, as in the game.
NewFrame = function(parent)
    local frame = setmetatable({ events = {}, scripts = {}, shown = true, parent = parent }, frameMeta)
    table.insert(frames, frame)
    return frame
end

function CreateFrame(_, name, parent)
    local frame = NewFrame(parent)
    if name then
        _G[name] = frame
    end
    return frame
end

-- Sends a game event to every frame registered for it.
function fire(event, ...)
    local targets = {}
    for _, frame in ipairs(frames) do
        if frame.events[event] and frame.scripts.OnEvent then
            table.insert(targets, frame)
        end
    end
    for _, frame in ipairs(targets) do
        frame.scripts.OnEvent(frame, event, ...)
    end
end

local function IsInside(frame, ancestor)
    while frame do
        if frame == ancestor then
            return true
        end
        frame = frame.parent
    end
    return false
end

-- The first frame whose text is `text` (a button label, for example), inside `within` if given.
function find_frame(text, within)
    for _, frame in ipairs(frames) do
        if frame.text == text and (not within or IsInside(frame, within)) then
            return frame
        end
    end
end

-- Clicks a button found by its label, inside `within` if given (labels repeat across windows).
function click(text, within)
    local button = assert(find_frame(text, within), "no frame with text " .. text)
    assert(button.scripts.OnClick, "frame " .. text .. " has no OnClick")
    button.scripts.OnClick(button, "LeftButton")
end

-- Runs one OnUpdate of a frame, as if `delta` seconds passed since the last one. Like the game, it does
-- nothing for a hidden frame.
function tick(frame, delta)
    assert(frame.scripts.OnUpdate, "the frame has no OnUpdate script")
    if frame.shown then
        frame.scripts.OnUpdate(frame, delta or 1)
    end
end

UIParent = CreateFrame("Frame", "UIParent")
Minimap = CreateFrame("Frame", "Minimap")
DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, message)
        table.insert(chat, message)
    end,
}
UISpecialFrames, SlashCmdList, StaticPopupDialogs = {}, {}, {}

-- Accepts the popup that was shown last (StaticPopup_Show(key)).
function StaticPopup_Show(key)
    last_popup = key
end

function accept_popup()
    local key = assert(rawget(_G, "last_popup"), "no popup was shown")
    StaticPopupDialogs[key].OnAccept()
end

-- Declines the popup that was shown last (its second button).
function cancel_popup()
    local key = assert(rawget(_G, "last_popup"), "no popup was shown")
    if StaticPopupDialogs[key].OnCancel then
        StaticPopupDialogs[key].OnCancel()
    end
end

function StaticPopup_Hide(key)
    if rawget(_G, "last_popup") == key then
        last_popup = nil
    end
end

-- Forgets the last popup, so a test can assert that no new one was shown.
function reset_popup()
    last_popup = nil
end

-- ReloadUI only counts: reload_count is how often the addon asked for a reload.
reload_count = 0
function ReloadUI()
    reload_count = reload_count + 1
end

settings_pages = {} -- name -> the frame registered with the Settings panel
Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)
        settings_pages[name] = frame
        return { GetID = function() return 1 end }
    end,
    RegisterCanvasLayoutSubcategory = function(_, frame, name)
        settings_pages[name] = frame
    end,
    RegisterAddOnCategory = function() end,
}

---------------------------------------------------------------------------
-- Game state and API
---------------------------------------------------------------------------
bag_items = {}
bindings = {} -- binding name -> its keys, in the game's order
item_cooldowns = {}
item_prices = {}
weapon_enchant = false
in_combat = false

WOW_PROJECT_ID = 18
INVSLOT_MAINHAND = 16
NUM_BAG_SLOTS = 4

addon_version = "1.0.0-test" -- the TOC's "## Version:" field
C_AddOns = {
    GetAddOnMetadata = function(addon, field)
        if addon == "OneKeyFishing" and field == "Version" then
            return addon_version
        end
    end,
}

local cvars = {}
C_CVar = {
    GetCVar = function(name)
        return cvars[name] or "0"
    end,
    SetCVar = function(name, value)
        cvars[name] = value
    end,
}

-- Maps and the game's map pin (UI/MapPin.lua, User Story 3 of spec 001):
--   map_info_missing[uiMapID] = true  C_Map.GetMapInfo answers nil (a map the client does not know)
--   pin_maps[uiMapID] = true          C_Map.CanSetUserWaypointOnMap
--   pins_disabled = true              the game rule that turns map pins off is active
--   user_waypoint                     the pin on the map: { uiMapID, position = { x, y } } or nil
--   super_tracked, opened_map         C_SuperTrack.SetSuperTrackedUserWaypoint, OpenWorldMap
--   area_names[areaID] = "name"       C_Map.GetAreaInfo
map_info_missing, pin_maps, area_names = {}, {}, {}
pins_disabled, user_waypoint, super_tracked, opened_map = false, nil, false, nil

player_map_id = 1
map_names = {}
player_map_position = nil
C_Map = {
    GetBestMapForUnit = function(unit)
        if unit == "player" then
            return player_map_id
        end
    end,
    GetMapInfo = function(mapID)
        if map_info_missing[mapID] then
            return nil
        end
        return { mapID = mapID, name = map_names[mapID] or "Test Zone", mapType = 3, parentMapID = 0 }
    end,
    GetPlayerMapPosition = function(_, unit)
        local position = player_map_position
        if unit == "player" and position then
            return { GetXY = function() return position[1], position[2] end }
        end
    end,
    GetAreaInfo = function(areaID)
        return area_names[areaID]
    end,
    CanSetUserWaypointOnMap = function(mapID)
        return pin_maps[mapID] == true
    end,
    SetUserWaypoint = function(point)
        user_waypoint = point
        return true
    end,
    HasUserWaypoint = function()
        return rawget(_G, "user_waypoint") ~= nil
    end,
    GetUserWaypoint = function()
        return rawget(_G, "user_waypoint")
    end,
    ClearUserWaypoint = function()
        user_waypoint = nil
    end,
}

UiMapPoint = {
    CreateFromCoordinates = function(mapID, x, y)
        return { uiMapID = mapID, position = { x = x, y = y } }
    end,
}

C_SuperTrack = {
    SetSuperTrackedUserWaypoint = function(value)
        super_tracked = value
    end,
}

C_GameRules = {
    IsGameRuleActive = function(rule)
        return rule == Enum.GameRule.WorldMapTrackingPinDisabled and pins_disabled
    end,
}

function OpenWorldMap(mapID)
    opened_map = mapID
end

-- Names the client knows by ID (User Story 3), nil until a test sets them, as for data the client has not loaded:
--   item_names[itemID], quest_titles[questID], spell_subtexts[spellID], tooltip_names[npcID] (a creature link)
--   requested_items[itemID], requested_quests[questID], requested_spells[spellID]: the addon asked the client to
--   load them
item_names, quest_titles, spell_subtexts, tooltip_names = {}, {}, {}, {}
requested_items, requested_quests = {}, {}

C_QuestLog = {
    GetTitleForQuestID = function(questID)
        return quest_titles[questID]
    end,
    RequestLoadQuestByID = function(questID)
        requested_quests[questID] = true
    end,
}

requested_spells = {}
C_Spell = {
    GetSpellSubtext = function(spellID)
        return spell_subtexts[spellID] or ""
    end,
    RequestLoadSpellData = function(spellID)
        requested_spells[spellID] = true
    end,
}

C_TooltipInfo = {
    GetHyperlink = function(link)
        local npcID = tonumber(tostring(link):match("^unit:Creature%-0%-0%-0%-0%-(%d+)%-"))
        local name = npcID and tooltip_names[npcID]
        if name then
            return { lines = { { leftText = name } } }
        end
    end,
}

-- The Fishing skill and the character (User Story 3): fishing_skill = { rank, maxRank } or nil (not learned);
-- fishing_rank = rank is the short form with the maximum 300.
fishing_skill = nil
fishing_rank = nil
player_level = 60

-- The current skill as { rank, maxRank }, or nil.
local function FishingSkill()
    local skill, rank = rawget(_G, "fishing_skill"), rawget(_G, "fishing_rank")
    return skill or (rank and { rank, 300 }) or nil
end

function GetProfessions()
    if FishingSkill() then
        return nil, nil, nil, 4 -- prof1, prof2, archaeology, fishing
    end
end

-- name, icon, rank, maxRank, numSpells, spellOffset, skillLine
function GetProfessionInfo(index)
    local skill = FishingSkill()
    if index == 4 and skill then
        return "Fishing", 136245, skill[1], skill[2], 0, 0, 356
    end
end

function UnitLevel()
    return player_level
end

-- Raid-warning style messages (RaidNotice_AddMessage), oldest first.
raid_warnings = {}
RaidWarningFrame = CreateFrame("Frame", "RaidWarningFrame")
ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.3, b = 0.1 } }
function RaidNotice_AddMessage(_, text)
    table.insert(raid_warnings, text)
end

C_Item = {
    GetItemCount = function(itemID)
        return bag_items[itemID] or 0
    end,
    IsUsableItem = function()
        return true
    end,
    -- name, link, quality, level, minLevel, type, subType, stackCount, equipLoc, icon, sellPrice
    GetItemInfo = function(itemID)
        return "Item " .. itemID, "[Item " .. itemID .. "]", 1, 1, 1, "Trade Goods", "Fish", 20, "", 134400,
            item_prices[itemID] or 0
    end,
    GetItemIconByID = function()
        return 134400
    end,
    GetItemInfoInstant = function(item)
        return tonumber(item) or tonumber(tostring(item):match("item:(%d+)"))
    end,
    GetItemNameByID = function(itemID)
        return item_names[itemID]
    end,
    RequestLoadItemDataByID = function(itemID)
        requested_items[itemID] = true
    end,
}

C_Container = {
    GetItemCooldown = function(itemID)
        local cooldown = item_cooldowns[itemID]
        if cooldown then
            return cooldown[1], cooldown[2], 1
        end
        return 0, 0, 1
    end,
    GetContainerNumSlots = function()
        return 0
    end,
    GetContainerNumFreeSlots = function()
        return 0, 0
    end,
}

loot = nil

-- rawget: a test sets loot = nil, and a nil global would otherwise read as a stub.
local function Loot()
    return rawget(_G, "loot")
end

function IsFishingLoot()
    local current = Loot()
    return current ~= nil and current.fishing == true
end

function GetNumLootItems()
    local current = Loot()
    return current and #current.items or 0
end

function GetLootSlotLink(slot)
    local current = Loot()
    local item = current and current.items[slot]
    return item and ("item:" .. item[1])
end

-- icon, name, quantity
function GetLootSlotInfo(slot)
    local current = Loot()
    local item = current and current.items[slot]
    if item then
        return 134400, "Item " .. item[1], item[2]
    end
end

-- The values do not matter, only that the names exist and compare as numbers.
Enum = {
    AuctionHouseSortOrder = { Price = 0 },
    ItemClass = { Weapon = 2 },
    ItemWeaponSubclass = { Fishingpole = 20 },
    TooltipDataType = { Item = 0 },
    GameRule = { WorldMapTrackingPinDisabled = 1 },
}

auction_queries = {} -- item keys sent with C_AuctionHouse.SendSearchQuery
commodity_results = {} -- itemID -> { { unitPrice, quantity }, ... } in the order the game returns them
commodity_total = {} -- itemID -> the total listed (GetCommoditySearchResultsQuantity); default: the sum
item_results = {} -- itemID -> { { buyoutAmount, quantity }, ... } for items that are not commodities
commodity_full = {} -- itemID -> false while more commodity results are on their way (HasFullCommoditySearchResults)
commodity_more_requests = {} -- item IDs asked for with RequestMoreCommoditySearchResults
C_AuctionHouse = {
    IsThrottledMessageSystemReady = function()
        return true
    end,
    MakeItemKey = function(itemID)
        return { itemID = itemID }
    end,
    SendSearchQuery = function(itemKey)
        table.insert(auction_queries, itemKey)
    end,
    GetNumCommoditySearchResults = function(itemID)
        return #(commodity_results[itemID] or {})
    end,
    GetCommoditySearchResultInfo = function(itemID, index)
        local result = (commodity_results[itemID] or {})[index]
        if result then
            return { itemID = itemID, unitPrice = result[1], quantity = result[2] }
        end
    end,
    GetCommoditySearchResultsQuantity = function(itemID)
        if commodity_total[itemID] then
            return commodity_total[itemID]
        end
        local total = 0
        for _, result in ipairs(commodity_results[itemID] or {}) do
            total = total + result[2]
        end
        return total
    end,
    HasFullCommoditySearchResults = function(itemID)
        return commodity_full[itemID] ~= false
    end,
    RequestMoreCommoditySearchResults = function(itemID)
        table.insert(commodity_more_requests, itemID)
    end,
    GetNumItemSearchResults = function(itemKey)
        return #(item_results[itemKey.itemID] or {})
    end,
    GetItemSearchResultInfo = function(itemKey, index)
        local result = (item_results[itemKey.itemID] or {})[index]
        if result then
            return { itemKey = itemKey, buyoutAmount = result[1], quantity = result[2] }
        end
    end,
}

-- The API tables above answer only what the tests need; any other field is a stub, like an unknown global.
local function WithStubFallback(name, api)
    return setmetatable(api, {
        __index = function(_, key)
            local full = name .. "." .. tostring(key)
            RejectInTests(full, 3)
            return _G[full]
        end,
    })
end
for _, name in ipairs({ "C_AddOns", "C_CVar", "C_Map", "C_Item", "C_Container", "C_AuctionHouse", "C_Timer",
    "Settings", "UiMapPoint", "C_SuperTrack", "C_GameRules", "C_QuestLog", "C_Spell", "C_TooltipInfo" }) do
    WithStubFallback(name, _G[name])
end

-- Units, casts and loot sources: nothing targeted, nothing being cast
function UnitGUID() end
loot_sources = {}
function GetLootSourceInfo(slot)
    return loot_sources[slot]
end
function UnitChannelInfo() end
function UnitCastingInfo() end

function GetWeaponEnchantInfo()
    return weapon_enchant
end

function GetBindingKey(name)
    return unpack(bindings[name] or {})
end

-- The game writes modifiers its own way ("SHIFT-`" reads "Shift-`"); the stub does the same, so a test can
-- see that the text went through GetBindingText.
function GetBindingText(key)
    return (key:gsub("SHIFT%-", "Shift-"))
end

function InCombatLockdown()
    return in_combat
end

function GetMoneyString(copper)
    return copper .. "c"
end

function GetZoneText()
    return "Test Zone"
end

function GetSubZoneText()
    return ""
end

CLIENT_LOCALE = "enUS"
function GetLocale()
    return CLIENT_LOCALE
end

-- The decimal separator of the game client (Blizzard spells it SEPERATOR); a test may set "," for a German client.
DECIMAL_SEPERATOR = "."

build_version = "1.60.1"
function GetBuildInfo()
    return build_version, "70450", "Oct 15 2026", 16001
end

function UnitIsAFK()
    return false
end

-- The game's tab helpers (SharedUIPanelTemplates): only recorded.
panel_tabs = {}
function PanelTemplates_SetNumTabs(frame, count)
    table.insert(panel_tabs, { "SetNumTabs", frame, count })
end
function PanelTemplates_SetTab(frame, index)
    table.insert(panel_tabs, { "SetTab", frame, index })
end
function PanelTemplates_TabResize(tab, padding)
    table.insert(panel_tabs, { "TabResize", tab, padding })
end

-- Lua extensions of the game client

function wipe(t)
    for key in pairs(t) do
        t[key] = nil
    end
    return t
end

-- strsplit(delimiters, text, pieces): every character of `delimiters` splits; with `pieces`, the last piece
-- keeps the rest of the text.
function strsplit(delimiters, text, pieces)
    local set = "[" .. delimiters:gsub("[%]%^%-%%]", "%%%0") .. "]"
    local parts, start = {}, 1
    while not pieces or #parts < pieces - 1 do
        local from, to = text:find(set, start)
        if not from then
            break
        end
        table.insert(parts, text:sub(start, from - 1))
        start = to + 1
    end
    table.insert(parts, text:sub(start))
    return tunpack(parts)
end

function strtrim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

---------------------------------------------------------------------------
-- Fishing
---------------------------------------------------------------------------
-- One cast in fishing mode: start, `seconds` (default 10), the loot `items` ({ { itemID, quantity } }) or none
-- (a miss), stop, and the second Catch.lua waits before it counts a miss. `sources`: loot_sources of that loot.
function fish_cast(items, seconds, sources)
    ns.Fire("FISHING_CAST_START", 7620)
    advance(seconds or 10)
    if items then
        loot = { fishing = true, items = items }
        loot_sources = sources or {}
        fire("LOOT_READY")
        loot, loot_sources = nil, {}
    end
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(2)
end

-- A catch database cell (CatchDB.lua) with c catches, m misses, 10 s of casting per cast and the items.
function catch_cell(c, m, items)
    return { c = c, m = m, t = (c + m) * 10, i = items or {} }
end

---------------------------------------------------------------------------
-- Loading the addon
---------------------------------------------------------------------------
ns = {} -- the addon namespace, shared by every file as in the game

-- Loads addon files (paths relative to the addon folder) in the given order.
function load_files(files)
    for _, file in ipairs(files) do
        local chunk = assert(loadfile(ADDON_DIR .. "/" .. file))
        chunk("OneKeyFishing", ns)
    end
end

-- Reads Locales/<code>.lua on its own: returns the native name and the translated texts (key -> text).
function load_translation(code)
    local name, texts = nil, {}
    assert(loadfile(ADDON_DIR .. "/Locales/" .. code .. ".lua"))("OneKeyFishing", {
        AddTranslation = function(registered, nativeName, fill)
            assert(registered == code, code .. ".lua registers " .. tostring(registered))
            name = nativeName
            fill(texts)
        end,
    })
    return name, texts
end

-- Loads the whole addon in TOC order and logs in: ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD.
-- beforeLogin runs between the two, e.g. to replace the bundled seed (ns.SeedData) the files just set.
function load_addon(beforeLogin)
    load_files(TOC_FILES)
    if beforeLogin then
        beforeLogin()
    end
    fire("ADDON_LOADED", "OneKeyFishing")
    fire("PLAYER_LOGIN")
    fire("PLAYER_ENTERING_WORLD", true, false)
end

---------------------------------------------------------------------------
-- Everything else: a permissive stub (callable, indexable, returns nil when called)
---------------------------------------------------------------------------
local stubMeta = {}
local function Stub(name)
    return setmetatable({ name = name }, stubMeta)
end
stubMeta.__index = function(stub, key)
    local child = Stub(rawget(stub, "name") .. "." .. tostring(key))
    rawset(stub, key, child)
    return child
end
stubMeta.__call = function() end

-- Stubs are for the addon's API calls. In a test file an unknown name is a typo (eqq, C_Item.GetItemCont).
-- `level` is the stack level of the code that did the lookup, as seen from this function.
function RejectInTests(name, level)
    local caller = debug.getinfo(level, "S")
    if caller and caller.source:find("_test%.lua$") then
        error("unknown name '" .. tostring(name) .. "' in a test (a typo, or a stub missing in tests/wow.lua)",
            level)
    end
end

-- The addon's own globals (saved variables, named frames) stay nil until they are set, as in the game.
-- Other unknown names get one stub each, so `Foo == Foo` holds. A stub's calls return nil, so code whose
-- path depends on an API's answer needs a real stub above.
local stubs = {}
-- Game data the tests set that may be nil on purpose (see the top of this file): nil, not a stub.
local NIL_GAME_DATA = { player_map_id = true, player_map_position = true, fishing_rank = true }
setmetatable(_G, {
    __index = function(_, key)
        if key == "utf8" or NIL_GAME_DATA[key] or (type(key) == "string" and key:find("^OneKeyFishing")) then
            return nil -- utf8: Lua 5.3 only, see the top of this file
        end
        if MISSING_51[key] then
            error("'" .. key .. "' exists in the game (Lua 5.1) but not in the test runtime; add a stub", 2)
        end
        RejectInTests(key, 3)
        stubs[key] = stubs[key] or Stub(key)
        return stubs[key]
    end,
})
