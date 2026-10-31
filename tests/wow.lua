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
--   known_items = { [itemID] = true }   C_Item.GetItemInfoInstant knows only these item IDs (nil: every ID)
--   settings_pages[name] = frame        the canvas pages registered as settings subcategories (read only)
--   popup_frames_busy = true            StaticPopup_Show shows nothing and returns nil (every dialog frame taken)
-- The catch exchange (Comm.lua, Share.lua):
--   addon_prefixes[prefix] = true       prefixes registered with C_ChatInfo.RegisterAddonMessagePrefix (read)
--   addon_sent                          C_ChatInfo.SendAddonMessage calls, { prefix, text, chatType, target, at }
--   addon_send_result[chatType] = n,    the result SendAddonMessage returns per chat type, else .default, else 0
--   addon_send_result.default = n
--   chat_lockdown = true                C_ChatInfo.InChatMessagingLockdown
--   addon_chat_restricted = true        C_ChatInfo.AreOutgoingAddonChatMessagesRestricted
--   bn_sent                             C_BattleNet.SendGameData calls, { gameAccountID, prefix, text, at }
--   bn_send_result = n                  what SendGameData returns (default 0)
--   bn_friends[i] = { { gameAccountID, clientProgram, wowProjectID, isOnline }, ... }   Battle.net friends and
--                                       their game accounts
--   friends[i] = { name, connected }    character friends (C_FriendList)
--   in_guild = true                     IsInGuild
--   group_type = "party" | "raid"       IsInGroup / IsInRaid (nil: no group)
--   group_members = n                   GetNumGroupMembers (default 2 in a group, 0 outside)
--   in_instance = true                  IsInInstance
--   restrictions[Enum.AddOnRestrictionType.X] = true   C_RestrictedActions.IsAddOnRestrictionActive
--   chat_filters[event] = { fn, ... }   filters added with ChatFrameUtil.AddMessageEventFilter (read)
-- Helpers: receive_addon(prefix, text, chatType, sender, target, localID, name), receive_bn(prefix, text,
-- gameAccountID), filter_hides(event, ...).
-- The public channel (Channel.lua, specs/004-public-channel-sync):
--   channels_joined                     { name, number } of the channels joined through JoinTemporaryChannel
--   channel_extra = n                   the player's own other channels (numbers 1..n, counted as active)
--   channel_join_result[name] = { ... } what JoinTemporaryChannel returns for that name ({}: nil)
--   channel_joins, channel_leaves, channel_passwords, channel_owner_queries   calls recorded (read)
--   window_removals                     { window, name } of each ChatFrameN:RemoveChannel (read)
--   popups_hidden                       keys passed to StaticPopup_Hide (read)
--   secret_values[value] = true         issecretvalue(value) is true
--   unknown_items[itemID] = true        an item the client does not know (GetItemInfoInstant nil)
--   item_load_requests                  IDs passed to C_Item.RequestLoadItemDataByID (read)
--   bit_unsigned = true                 the bit stub returns unsigned results
--   real_proof = true                   (before loading) the real SHA-256 ns.ProofStep instead of the fast stand-in
-- Helpers: chat_window_add(i, name), channel_notice(event, token, channelName, player, actor),
-- channel_text(channelName, text, sender), enter_world(isInitialLogin, isReloadingUi), item_loaded(itemID, ok),
-- proof_for(secret, seq, top), prove(record, secret, top).
-- The catch catalog (specs/005-catch-catalog). Every test file runs in a fresh Lua state, so these start at their
-- defaults in each file:
--   map_types[mapID] = Enum.UIMapType.X  mapType of C_Map.GetMapInfo (default 3, Zone)
--   map_parents[mapID] = parentID       parentMapID of C_Map.GetMapInfo (default 0)
--   map_info_missing[mapID] = true      C_Map.GetMapInfo returns nil
--   waypoint_maps[mapID] = true         C_Map.CanSetUserWaypointOnMap is true (default false)
--   user_waypoint                       the user waypoint (C_Map.Get/Has/Clear/SetUserWaypoint; nil: none)
--   waypoint_sets                       every point passed to C_Map.SetUserWaypoint (read)
--   waypoint_result = false             C_Map.SetUserWaypoint refuses and stores nothing (default true)
--   map_world[mapID] = { continent, left, top, width, height }   the map in world space
--                                       (C_Map.GetWorldPosFromMapPos / GetMapPosFromWorldPos)
--   super_tracked                       C_SuperTrack.SetSuperTrackedUserWaypoint (read; default false)
--   game_rules[Enum.GameRule.X] = true  C_GameRules.IsGameRuleActive
--   world_maps_opened                   map IDs passed to OpenWorldMap (read)
--   sub_zone = "Crystal Lake"           GetSubZoneText (default "")
--   area_names[areaID] = "Crystal Lake" C_Map.GetAreaInfo
--   explored_areas = { 10, 20 }         C_MapExplorationInfo.GetExploredAreaIDsAtPosition (nil: none)
--   area_lookups                        { mapID, x, y } of each GetExploredAreaIDsAtPosition call (read)
--   item_names[itemID] = "Trout"        C_Item.GetItemNameByID (default "Item <id>"; nil for unknown_items)
--   item_qualities[itemID] = n          C_Item.GetItemQualityByID (default 1; nil for unknown_items)
--   missing_atlases[name] = true        C_Texture.GetAtlasInfo returns nil for that atlas (default: every atlas)
--   game_fold = true                    (before loading) defines CaseAccentInsensitiveParse and strcmputf8i
--   no_scroll_templates = true          (before loading) CreateFrame with the scroll and search templates fails
--   tooltip_post_calls[dataType]        functions given to TooltipDataProcessor.AddTooltipPostCall (read)
--   itemref_lines                       lines of ItemRefTooltip (read), like tooltip_lines of GameTooltip
--   profile_ms = n, profile_step = n    debugprofilestop returns profile_ms, then adds profile_step to it (nil:
--                                       debugprofilestop is undefined, as a clock missing)
-- Helpers: scroll_rows(box), type_text(box, text), show_item_tooltip(tooltip, itemID).
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
local MISSING_51 = { getfenv = true, setfenv = true, gcinfo = true, newproxy = true }
math.frexp = function() error("math.frexp exists in the game (Lua 5.1) but not in the test runtime", 2) end
math.type, math.tointeger, math.ult, math.maxinteger, math.mininteger = nil, nil, nil, nil, nil
string.pack, string.unpack, string.packsize = nil, nil, nil
coroutine.isyieldable = nil
utf8 = nil
unpack = tunpack -- a global in Lua 5.1

-- The game's bit library (specs/004-public-channel-sync/research.md R9). The operators are compiled from a string
-- with loadstring: npm run check parses the tests as Lua 5.1, which has no bitwise operators, while fengari (Lua
-- 5.3) has them. Results are signed 32-bit numbers as LuaBitOp gives them; bit_unsigned = true gives them unsigned
-- (the game's signedness is not documented, and ns.SHA256 must not depend on it). Two operands, as the addon uses.
-- fengari's integers are 32-bit, so an operand goes in as a signed 32-bit value (a float above 2^31 has no integer
-- representation there), and its shifts and complements wrap at 32 bits, as LuaBitOp's do.
local bitOps = loadstring([[
    local M = 4294967296
    local function S(a)
        a = a % M
        if a >= 2147483648 then
            a = a - M
        end
        return a | 0 -- an integer: fengari's unary ~ rejects a float
    end
    return {
        band = function(a, b) return S(a) & S(b) end,
        bor = function(a, b) return S(a) | S(b) end,
        bxor = function(a, b) return S(a) ~ S(b) end,
        bnot = function(a) return ~S(a) end,
        lshift = function(a, n) return S(a) << n end,
        rshift = function(a, n) return S(a) >> n end,
    }
]])()
local function BitResult(value)
    value = value % 4294967296
    if not rawget(_G, "bit_unsigned") and value >= 2147483648 then
        return value - 4294967296
    end
    return value
end
bit = {}
for name, op in pairs(bitOps) do
    bit[name] = function(...)
        return BitResult(op(...))
    end
end

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

Frame.IsVisible = Frame.IsShown

function Frame:SetText(text)
    self.text = text
end

-- Buttons and check buttons: enabled unless SetEnabled(false) or Disable() (read with IsEnabled).
function Frame:SetEnabled(enabled)
    self.enabled = enabled and true or false
end

function Frame:Enable()
    self.enabled = true
end

function Frame:Disable()
    self.enabled = false
end

function Frame:IsEnabled()
    return self.enabled ~= false
end

function Frame:SetChecked(checked)
    self.checked = checked and true or false
end

function Frame:GetChecked()
    return self.checked == true
end

function Frame:GetText()
    return self.text
end

function Frame:SetFormattedText(format, ...)
    self.text = format:format(...)
end

function Frame:GetWidth()
    return 100
end

-- A texture (CreateTexture makes a frame here): the file or file ID it shows.
function Frame:SetTexture(texture)
    self.texture = texture
end

Frame.GetHeight = Frame.GetWidth

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

-- The scroll list and search box templates (UI/CatalogTab.lua); no_scroll_templates makes them fail, as a client
-- without them would.
local SCROLL_TEMPLATES = { WowScrollBoxList = true, MinimalScrollBar = true, SearchBoxTemplate = true }

function CreateFrame(_, name, parent, template)
    if SCROLL_TEMPLATES[template] and rawget(_G, "no_scroll_templates") then
        error("unknown template " .. template, 2)
    end
    local frame = NewFrame(parent)
    frame.template = template
    if template == "SearchBoxTemplate" then
        frame.Instructions = NewFrame(frame)
    end
    if name then
        _G[name] = frame
    end
    return frame
end

-- A scroll box: the data provider it shows (SetDataProvider) and the view ScrollUtil gave it.
function Frame:SetDataProvider(provider, retainScroll)
    self.provider, self.retainScroll = provider, retainScroll
end

function Frame:GetDataProvider()
    return self.provider
end

function CreateDataProvider(list)
    local provider = { elements = {} }
    for _, element in ipairs(list or {}) do
        table.insert(provider.elements, element)
    end
    function provider:Insert(...)
        for i = 1, select("#", ...) do
            table.insert(self.elements, (select(i, ...)))
        end
    end
    function provider:Flush()
        self.elements = {}
    end
    function provider:GetSize()
        return #self.elements
    end
    function provider:Enumerate()
        local i = 0
        return function()
            i = i + 1
            if self.elements[i] ~= nil then
                return i, self.elements[i]
            end
        end
    end
    return provider
end

function CreateScrollBoxListLinearView()
    local view = {}
    function view:SetElementInitializer(template, fn)
        self.template, self.initializer = template, fn
    end
    function view:SetElementExtent(extent)
        self.extent = extent
    end
    return view
end

ScrollUtil = {
    InitScrollBoxListWithScrollBar = function(box, bar, view)
        box.view, box.scrollBar = view, bar
    end,
}

-- One row frame per element of the box's data provider, each set up by the view's initializer, as the game does
-- for the rows in sight.
function scroll_rows(box)
    local rows = {}
    for _, element in box.provider:Enumerate() do
        local row = NewFrame(box)
        box.view.initializer(row, element)
        table.insert(rows, row)
    end
    return rows
end

-- Types into a search box: its text, then OnTextChanged with userInput true.
function type_text(box, text)
    box:SetText(text)
    box.scripts.OnTextChanged(box, true)
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

-- The game tooltip: SetOwner starts over, AddLine and SetItemByID are recorded (tooltip_lines, tooltip_item), Show
-- and Hide set tooltip_shown; any other method does nothing.
-- AddDoubleLine records "left | right".
local function DoubleLine(left, right)
    return tostring(left) .. " | " .. tostring(right)
end
tooltip_lines, tooltip_item, tooltip_shown = {}, nil, false
GameTooltip = setmetatable({
    SetOwner = function() tooltip_lines, tooltip_item = {}, nil end,
    AddLine = function(_, text) table.insert(tooltip_lines, text) end,
    AddDoubleLine = function(_, left, right) table.insert(tooltip_lines, DoubleLine(left, right)) end,
    SetItemByID = function(_, itemID) tooltip_item = itemID end,
    Show = function() tooltip_shown = true end,
    Hide = function() tooltip_shown = false end,
}, { __index = function() return function() end end })

-- The tooltip of chat item links, with its own lines.
itemref_lines = {}
ItemRefTooltip = setmetatable({
    SetOwner = function() itemref_lines = {} end,
    AddLine = function(_, text) table.insert(itemref_lines, text) end,
    AddDoubleLine = function(_, left, right) table.insert(itemref_lines, DoubleLine(left, right)) end,
}, { __index = function() return function() end end })

-- TooltipDataProcessor keeps the post calls; show_item_tooltip runs the item ones as the game does when a tooltip
-- shows an item.
tooltip_post_calls = {}
TooltipDataProcessor = {
    AddTooltipPostCall = function(dataType, fn)
        tooltip_post_calls[dataType] = tooltip_post_calls[dataType] or {}
        table.insert(tooltip_post_calls[dataType], fn)
    end,
}

function show_item_tooltip(tooltip, itemID)
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    for _, fn in ipairs(tooltip_post_calls[Enum.TooltipDataType.Item] or {}) do
        fn(tooltip, { id = itemID })
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

-- Shows a popup: records it as the last one and returns a dialog, as the game does; while popup_frames_busy is true
-- (in the game: every dialog frame is taken) nothing is shown, the dialog's OnCancel runs without a dialog and nil
-- comes back, as Blizzard_StaticPopup/StaticPopup.lua does. As in the game, the popup hides after either button, so
-- its OnHide runs too.
popup_frames_busy = false
function StaticPopup_Show(key)
    if popup_frames_busy == true then
        if StaticPopupDialogs[key].OnCancel then
            StaticPopupDialogs[key].OnCancel(nil)
        end
        return nil
    end
    last_popup = key
    return { which = key }
end

local function HidePopup(key)
    if StaticPopupDialogs[key].OnHide then
        StaticPopupDialogs[key].OnHide()
    end
end

function accept_popup()
    local key = assert(rawget(_G, "last_popup"), "no popup was shown")
    if StaticPopupDialogs[key].OnAccept then
        StaticPopupDialogs[key].OnAccept({ which = key }) -- the game passes the dialog, then its data
    end
    HidePopup(key)
end

-- Declines the popup that was shown last (its second button).
function cancel_popup()
    local key = assert(rawget(_G, "last_popup"), "no popup was shown")
    if StaticPopupDialogs[key].OnCancel then
        StaticPopupDialogs[key].OnCancel({ which = key }, nil, "clicked") -- as the game: dialog, data, reason
    end
    HidePopup(key)
end

popups_hidden = {} -- every key passed to StaticPopup_Hide, in order
function StaticPopup_Hide(key)
    table.insert(popups_hidden, key)
    if rawget(_G, "last_popup") == key then
        last_popup = nil
        HidePopup(key)
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

settings_pages = {}
settings_opened = {} -- category IDs passed to Settings.OpenToCategory
local categoryCount = 0
local function NewCategory()
    categoryCount = categoryCount + 1
    local id = categoryCount
    return { GetID = function() return id end }
end
Settings = {
    RegisterCanvasLayoutCategory = function()
        return NewCategory()
    end,
    RegisterCanvasLayoutSubcategory = function(_, frame, name)
        settings_pages[name] = frame
        local category = NewCategory()
        frame.categoryID = category:GetID()
        return category
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id)
        table.insert(settings_opened, id)
    end,
}

---------------------------------------------------------------------------
-- Game state and API
---------------------------------------------------------------------------
bag_items = {}
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

player_map_id = 1
map_names = {}
player_map_position = nil
map_types, map_parents, map_info_missing = {}, {}, {}
waypoint_maps, waypoint_sets, map_world, area_names, area_lookups = {}, {}, {}, {}, {}
user_waypoint, waypoint_result, explored_areas = nil, nil, nil

function CreateVector2D(x, y)
    return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end

UiMapPoint = {
    CreateFromCoordinates = function(mapID, x, y, z)
        return { uiMapID = mapID, position = CreateVector2D(x, y), z = z }
    end,
}

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
        return { mapID = mapID, name = map_names[mapID] or "Test Zone", mapType = map_types[mapID] or 3,
            parentMapID = map_parents[mapID] or 0 }
    end,
    GetAreaInfo = function(areaID)
        return area_names[areaID]
    end,
    CanSetUserWaypointOnMap = function(mapID)
        return waypoint_maps[mapID] == true
    end,
    SetUserWaypoint = function(point)
        table.insert(waypoint_sets, point)
        if rawget(_G, "waypoint_result") == false then
            return false
        end
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
    GetWorldPosFromMapPos = function(mapID, pos)
        local world = map_world[mapID]
        if world then
            return world[1], CreateVector2D(world[2] + pos.x * world[4], world[3] + pos.y * world[5])
        end
    end,
    GetMapPosFromWorldPos = function(continent, worldPos, overrideMapID)
        local world = map_world[overrideMapID]
        if world and world[1] == continent then
            return overrideMapID, CreateVector2D((worldPos.x - world[2]) / world[4], (worldPos.y - world[3]) / world[5])
        end
    end,
    GetPlayerMapPosition = function(_, unit)
        local position = player_map_position
        if unit == "player" and position then
            return { GetXY = function() return position[1], position[2] end }
        end
    end,
}

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
        local itemID = tonumber(item) or tonumber(tostring(item):match("item:(%d+)"))
        local known = rawget(_G, "known_items")
        if (known and not known[itemID]) or unknown_items[itemID] then
            return nil
        end
        return itemID
    end,
    DoesItemExistByID = function(item)
        return not unknown_items[tonumber(item)]
    end,
    RequestLoadItemDataByID = function(item)
        table.insert(item_load_requests, tonumber(item))
    end,
    GetItemNameByID = function(item)
        local itemID = tonumber(item)
        if unknown_items[itemID] then
            return nil
        end
        return item_names[itemID] or ("Item " .. itemID)
    end,
    GetItemQualityByID = function(item)
        local itemID = tonumber(item)
        if unknown_items[itemID] then
            return nil
        end
        return item_qualities[itemID] or 1
    end,
}
item_names, item_qualities = {}, {}

-- The map pin, the navigation arrow, the game rules and the world map (specs/005-catch-catalog, research R6).
super_tracked, game_rules, world_maps_opened = false, {}, {}
C_SuperTrack = {
    SetSuperTrackedUserWaypoint = function(on)
        super_tracked = on
    end,
    IsSuperTrackingUserWaypoint = function()
        return super_tracked
    end,
}
C_GameRules = {
    IsGameRuleActive = function(rule)
        return game_rules[rule] == true
    end,
}
function OpenWorldMap(mapID)
    table.insert(world_maps_opened, mapID)
end

-- Atlases: every name exists unless missing_atlases[name] is true.
missing_atlases = {}
C_Texture = {
    GetAtlasInfo = function(atlas)
        if not missing_atlases[atlas] then
            return { file = 0, width = 16, height = 16 }
        end
    end,
}

-- The explored areas at a position (research R4).
C_MapExplorationInfo = {
    GetExploredAreaIDsAtPosition = function(mapID, pos)
        table.insert(area_lookups, { mapID, pos.x, pos.y })
        return rawget(_G, "explored_areas")
    end,
}

-- The game's folding of case and accents, with game_fold: lower case, and the capital and small e acute to "e".
local function GameFold(text)
    return (text:lower():gsub("\195\137", "e"):gsub("\195\169", "e"))
end
local GAME_FOLD = {
    CaseAccentInsensitiveParse = GameFold,
    strcmputf8i = function(a, b)
        a, b = GameFold(a), GameFold(b)
        return a < b and -1 or (a > b and 1 or 0)
    end,
}

-- The frame clock, with profile_ms.
local function ProfileClock()
    local value = profile_ms
    if rawget(_G, "profile_step") then
        profile_ms = profile_ms + profile_step
    end
    return value
end

-- Items the game client does not know yet (WoW Forever reveals some only when found): GetItemInfoInstant returns
-- nil and DoesItemExistByID false for them. item_load_requests: the IDs passed to RequestLoadItemDataByID.
unknown_items, item_load_requests = {}, {}

-- The game answers a RequestLoadItemDataByID: on success the client knows the item from then on.
function item_loaded(itemID, success)
    if success then
        unknown_items[itemID] = nil
    end
    fire("ITEM_DATA_LOAD_RESULT", itemID, success)
end

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
    -- A loot link as the game gives it: the ID is in it also for an item the client does not know yet.
    return item and ("|cffffffff|Hitem:%d::::::::|h[Item %d]|h|r"):format(item[1], item[1])
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
    UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 },
    GameRule = { WorldMapTrackingPinDisabled = 1 }, -- a stand-in value
    ItemQuality = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4 },
    -- These three as in the 1.60.1 export: the values matter for the results the addon reads.
    AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 },
    SendAddonMessageResult = { Success = 0, InvalidPrefix = 1, InvalidMessage = 2, AddonMessageThrottle = 3,
        InvalidChatType = 4, NotInGroup = 5, TargetRequired = 6, InvalidChannel = 7, ChannelThrottle = 8,
        GeneralError = 9, NotInGuild = 10, AddOnMessageLockdown = 11, TargetOffline = 12 },
    CompressionMethod = { Deflate = 0, Zlib = 1, Gzip = 2 },
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

---------------------------------------------------------------------------
-- The catch exchange: addon messages, Battle.net, friends, guild and group, restrictions, encoding
---------------------------------------------------------------------------
addon_prefixes, addon_sent, addon_send_result = {}, {}, {}
chat_lockdown, addon_chat_restricted = false, false
bn_sent, bn_send_result, bn_friends = {}, nil, {}
friends = {}
in_guild, group_type, group_members, in_instance = false, nil, nil, false
restrictions = {}
chat_filters = {}

BNET_CLIENT_WOW = "WoW"
ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
LE_PARTY_CATEGORY_HOME = 1

C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix)
        addon_prefixes[prefix] = true
        return 0
    end,
    SendAddonMessage = function(prefix, text, chatType, target)
        assert(#text <= 255, "an addon message longer than 255 bytes: " .. #text)
        assert(not text:find("\0", 1, true), "an addon message with a NUL byte")
        table.insert(addon_sent, { prefix = prefix, text = text, chatType = chatType, target = target, at = now })
        return addon_send_result[chatType] or addon_send_result.default or 0
    end,
    InChatMessagingLockdown = function()
        return chat_lockdown
    end,
    AreOutgoingAddonChatMessagesRestricted = function()
        return addon_chat_restricted
    end,
}

C_BattleNet = {
    SendGameData = function(gameAccountID, prefix, text)
        assert(#text <= 255, "Battle.net game data longer than 255 bytes: " .. #text)
        table.insert(bn_sent, { gameAccountID = gameAccountID, prefix = prefix, text = text, at = now })
        return rawget(_G, "bn_send_result") or 0
    end,
    GetFriendNumGameAccounts = function(index)
        return #(bn_friends[index] or {})
    end,
    GetFriendGameAccountInfo = function(index, accountIndex)
        return (bn_friends[index] or {})[accountIndex]
    end,
}

function BNGetNumFriends()
    return #bn_friends
end

C_FriendList = {
    GetNumFriends = function()
        return #friends
    end,
    GetFriendInfoByIndex = function(index)
        return friends[index]
    end,
}

function IsInGuild()
    return in_guild
end

function IsInGroup()
    return rawget(_G, "group_type") ~= nil
end

function IsInRaid()
    return rawget(_G, "group_type") == "raid"
end

function GetNumGroupMembers()
    return rawget(_G, "group_members") or (rawget(_G, "group_type") and 2 or 0)
end

function IsInInstance()
    return in_instance, in_instance and "party" or "none"
end

C_RestrictedActions = {
    IsAddOnRestrictionActive = function(restriction)
        return restrictions[restriction] == true
    end,
}

ChatFrameUtil = {
    AddMessageEventFilter = function(event, fn)
        chat_filters[event] = chat_filters[event] or {}
        table.insert(chat_filters[event], fn)
    end,
}

-- True when a chat filter added for `event` hides a line with these event arguments (the text first).
function filter_hides(event, ...)
    for _, fn in ipairs(chat_filters[event] or {}) do
        if fn(DEFAULT_CHAT_FRAME, event, ...) then
            return true
        end
    end
    return false
end

-- The full CHAT_MSG_ADDON payload: prefix, text, chat type, sender, target, zoneChannelID, localID, name, instanceID.
function receive_addon(prefix, text, chatType, sender, target, localID, name)
    fire("CHAT_MSG_ADDON", prefix, text, chatType, sender, target, 0, localID, name, 0)
end

function receive_bn(prefix, text, gameAccountID)
    fire("BN_CHAT_MSG_ADDON", prefix, text, "WHISPER", gameAccountID)
end

---------------------------------------------------------------------------
-- The public channel (Channel.lua): chat channels, chat windows, channel notices
---------------------------------------------------------------------------
channels_joined = {} -- { name, number } of every channel the player is in that a test or the addon joined
channel_extra = 0 -- the player's own other channels, numbered 1..channel_extra (counted as active)
channel_joins, channel_leaves, channel_passwords, channel_owner_queries = {}, {}, {}, {}
channel_join_result = {} -- name -> the values JoinTemporaryChannel returns instead ({}: nil)
window_removals = {} -- { window, name } for every ChatFrameN:RemoveChannel call
secret_values = {} -- value -> true: issecretvalue(value) is true (chat lockdown)

Constants = { ChatFrameConstants = { MaxChatChannels = 20, MaxChatWindows = 10 } }
ERR_TOO_MANY_CHAT_CHANNELS = "You can only be in %d channels at a time."
NUM_CHAT_WINDOWS = 10

function issecretvalue(value)
    return value ~= nil and secret_values[value] == true
end

local function JoinedChannel(nameOrNumber)
    for _, entry in ipairs(channels_joined) do
        if entry.name == nameOrNumber or entry.number == nameOrNumber then
            return entry
        end
    end
end

-- type, name as the game returns them; the lowest free number above the player's own channels.
function JoinTemporaryChannel(name, password, frameID)
    table.insert(channel_joins, { name = name, password = password, frameID = frameID })
    local forced = channel_join_result[name]
    if forced then
        return tunpack(forced)
    end
    if not JoinedChannel(name) then
        local number = channel_extra + 1
        while JoinedChannel(number) do
            number = number + 1
        end
        table.insert(channels_joined, { name = name, number = number })
    end
    return 0, name
end

function LeaveChannelByName(name)
    table.insert(channel_leaves, name)
    for i, entry in ipairs(channels_joined) do
        if entry.name == name then
            table.remove(channels_joined, i)
            break
        end
    end
end

function GetChannelName(nameOrNumber)
    local entry = JoinedChannel(nameOrNumber)
    if entry then
        return entry.number, entry.name, 0, false
    end
    return 0
end

function GetChannelList()
    local sorted, out = {}, {}
    for _, entry in ipairs(channels_joined) do
        table.insert(sorted, entry)
    end
    table.sort(sorted, function(a, b) return a.number < b.number end)
    for _, entry in ipairs(sorted) do
        table.insert(out, entry.number)
        table.insert(out, entry.name)
        table.insert(out, false)
    end
    return tunpack(out)
end

function SetChannelPassword(name, password)
    table.insert(channel_passwords, { name = name, password = password })
end

-- The game answers with a CHANNEL_OWNER notice (a test fires it with channel_notice).
function DisplayChannelOwner(name)
    table.insert(channel_owner_queries, name)
end

C_ChatInfo.GetNumActiveChannels = function()
    return #channels_joined + channel_extra
end

-- Chat windows with their channel lists (ChatFrameMixin's ContainsChannel and RemoveChannel).
local ChatWindow = {}
ChatWindow.__index = ChatWindow
function ChatWindow:ContainsChannel(name)
    for _, listed in ipairs(self.channelList) do
        if listed == name then
            return true
        end
    end
    return false
end
function ChatWindow:RemoveChannel(name)
    for i, listed in ipairs(self.channelList) do
        if listed == name then
            table.remove(self.channelList, i)
            table.insert(window_removals, { window = self.index, name = name })
            return
        end
    end
end
for i = 1, NUM_CHAT_WINDOWS do
    _G["ChatFrame" .. i] = setmetatable({ index = i, channelList = {} }, ChatWindow)
end

function chat_window_add(i, name)
    table.insert(_G["ChatFrame" .. i].channelList, name)
end

-- A channel notice as the game sends it: token, player, "", "<number>. <name>", actor, "", zone ID, number, name.
function channel_notice(event, token, channelName, player, actor)
    local entry = JoinedChannel(channelName)
    local number = entry and entry.number or 0
    fire(event, token, player or "", "", number .. ". " .. channelName, actor or "", "", 0, number, channelName)
end

-- True when a CHAT_MSG_CHANNEL filter discards a line typed into a channel.
function channel_text(channelName, text, sender)
    local entry = JoinedChannel(channelName)
    local number = entry and entry.number or 0
    return filter_hides("CHAT_MSG_CHANNEL", text, sender, "", number .. ". " .. channelName, sender, "", 0, number,
        channelName)
end

-- Enters the world as the game does after a login (isInitialLogin) or a /reload (isReloadingUi).
function enter_world(isInitialLogin, isReloadingUi)
    fire("PLAYER_ENTERING_WORLD", isInitialLogin, isReloadingUi)
end

-- The addon messages sent after the first `from`, only those of `chatType` when given.
function addon_sent_since(from, chatType)
    local out = {}
    for i = from + 1, #addon_sent do
        if not chatType or addon_sent[i].chatType == chatType then
            table.insert(out, addon_sent[i])
        end
    end
    return out
end

-- A SUM of session `sid` whose 32 bucket hashes (7 characters each) differ from any real database.
function sum_text(sid)
    return "S" .. sid .. " " .. ("a"):rep(7 * 32)
end

-- C_EncodingUtil: a deterministic serializer (keys sorted) for the CBOR pair, identity for compression and a real
-- Base64 with the standard alphabet, so a record goes through the addon's whole chain.
local TYPE_ORDER = { number = 1, string = 2, boolean = 3 }

local function SortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b)
        if type(a) ~= type(b) then
            return TYPE_ORDER[type(a)] < TYPE_ORDER[type(b)]
        end
        if type(a) == "boolean" then
            return not a and b
        end
        return a < b
    end)
    return keys
end

local function Serialize(value, out)
    local kind = type(value)
    if kind == "string" then
        table.insert(out, "s" .. #value .. ":" .. value)
    elseif kind == "number" then
        table.insert(out, "n" .. tostring(value) .. ";")
    elseif kind == "boolean" then
        table.insert(out, value and "T" or "F")
    elseif kind == "table" then
        table.insert(out, "{")
        for _, key in ipairs(SortedKeys(value)) do
            Serialize(key, out)
            Serialize(value[key], out)
        end
        table.insert(out, "}")
    else
        error("cannot serialize a " .. kind)
    end
end

local function Deserialize(text, position)
    local tag = text:sub(position, position)
    if tag == "s" then
        local length, start = text:match("^(%d+):()", position + 1)
        assert(length, "bad string")
        return text:sub(start, start + length - 1), start + length
    elseif tag == "n" then
        local number, after = text:match("^([^;]+);()", position + 1)
        return assert(tonumber(number), "bad number"), after
    elseif tag == "T" or tag == "F" then
        return tag == "T", position + 1
    elseif tag == "{" then
        local result = {}
        position = position + 1
        while text:sub(position, position) ~= "}" do
            assert(position <= #text, "unterminated table")
            local key, value
            key, position = Deserialize(text, position)
            value, position = Deserialize(text, position)
            result[key] = value
        end
        return result, position + 1
    end
    error("bad serialized data at " .. position)
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_INDEX = {}
for i = 1, #B64 do
    B64_INDEX[B64:sub(i, i)] = i - 1
end

local function B64Char(n)
    return B64:sub(n + 1, n + 1)
end

C_EncodingUtil = {
    SerializeCBOR = function(value)
        local out = {}
        Serialize(value, out)
        return table.concat(out)
    end,
    DeserializeCBOR = function(text)
        local value, after = Deserialize(text, 1)
        assert(after == #text + 1, "trailing data")
        return value
    end,
    CompressString = function(text)
        return text
    end,
    DecompressString = function(text)
        return text
    end,
    EncodeBase64 = function(text)
        local out = {}
        for i = 1, #text, 3 do
            local a, b, c = text:byte(i, i + 2)
            local n = a * 65536 + (b or 0) * 256 + (c or 0)
            table.insert(out, B64Char(math.floor(n / 262144) % 64) .. B64Char(math.floor(n / 4096) % 64)
                .. (b and B64Char(math.floor(n / 64) % 64) or "=") .. (c and B64Char(n % 64) or "="))
        end
        return table.concat(out)
    end,
    DecodeBase64 = function(text)
        if #text % 4 ~= 0 then
            return nil
        end
        local out = {}
        for i = 1, #text, 4 do
            local chunk = text:sub(i, i + 3)
            local pad = #(chunk:match("=*$"))
            if pad > 2 or chunk:sub(1, 4 - pad):find("=", 1, true) or (pad > 0 and i + 3 < #text) then
                return nil
            end
            local n = 0
            for j = 1, 4 do
                local char = chunk:sub(j, j)
                local value = char == "=" and 0 or B64_INDEX[char]
                if not value then
                    return nil
                end
                n = n * 64 + value
            end
            local bytes = string.char(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
            table.insert(out, bytes:sub(1, 3 - pad))
        end
        return table.concat(out)
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
    "Settings", "C_ChatInfo", "C_BattleNet", "C_FriendList", "C_RestrictedActions", "ChatFrameUtil",
    "C_EncodingUtil", "C_SuperTrack", "C_GameRules", "C_MapExplorationInfo", "ScrollUtil", "TooltipDataProcessor",
    "UiMapPoint", "C_Texture" }) do
    WithStubFallback(name, _G[name])
end

-- Units, casts and loot sources: nothing targeted, nothing being cast
function UnitGUID() end
function UnitName(unit)
    if unit == "player" then
        return "Me"
    end
end
function GetNormalizedRealmName()
    return "Realm"
end
loot_sources = {}
function GetLootSourceInfo(slot)
    return loot_sources[slot]
end
function UnitChannelInfo() end
function UnitCastingInfo() end

function GetWeaponEnchantInfo()
    return weapon_enchant
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

sub_zone = ""
function GetSubZoneText()
    return sub_zone
end

CLIENT_LOCALE = "enUS"
function GetLocale()
    return CLIENT_LOCALE
end

build_version = "1.60.1"
function GetBuildInfo()
    return build_version, "70450", "Oct 15 2026", 16001
end

function UnitIsAFK()
    return false
end

fishing_rank = nil
function GetProfessions()
    if fishing_rank then
        return nil, nil, nil, 1 -- prof1, prof2, archaeology, fishing
    end
end

-- name, icon, rank, maxRank, numSpells, spellOffset, skillLine
function GetProfessionInfo(index)
    local rank = fishing_rank
    if index == 1 and rank then
        return "Fishing", 136245, rank, 300, 0, 0, 356
    end
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

-- SHA-256 in fengari costs milliseconds per call, and an own record's chain takes thousands of them, so every test
-- but tests/core/proof_test.lua (which sets real_proof = true before loading) runs with this fast stand-in for
-- ns.ProofStep: deterministic, 16 base32 characters, not one-way. ns.real_ProofStep keeps the real one.
local function FastProofStep(link)
    local a, b = 7, 13
    for i = 1, #link do
        local byte = link:byte(i)
        a = (a * 31 + byte) % 1048573
        b = (b * 37 + byte) % 1048571
    end
    return ns.Base32(a, 4) .. ns.Base32(b, 4) .. ns.Base32((a * 7 + b) % 1048573, 4)
        .. ns.Base32((b * 11 + a) % 1048571, 4)
end

-- Loads addon files (paths relative to the addon folder) in the given order.
function load_files(files)
    for _, file in ipairs(files) do
        local chunk = assert(loadfile(ADDON_DIR .. "/" .. file))
        chunk("OneKeyFishing", ns)
        if file:match("[^/]+$") == "Data.lua" and ns.ProofStep and not rawget(_G, "real_proof") then
            ns.real_ProofStep, ns.ProofStep = ns.ProofStep, FastProofStep
        end
    end
end

-- Link `seq` of a version chain of `top` links (default 256) made from `secret`, as the owner's client makes it
-- (specs/004-public-channel-sync/data-model.md "The version chain"): link top = ProofStep(secret), every lower link
-- the ProofStep of the one above. Chains are kept per secret and top, so the versions of one record agree.
local chains = {}
function proof_for(secret, seq, top)
    top = top or 256
    assert(seq <= top, "seq above the chain's top")
    local key = secret .. "@" .. top
    local chain = chains[key]
    if not chain then
        assert(ns.ProofStep, "ProofStep not loaded")
        chain = { [top] = ns.ProofStep(secret) }
        for i = top - 1, 0, -1 do
            chain[i] = ns.ProofStep(chain[i + 1])
        end
        chains[key] = chain
    end
    return chain[seq]
end

-- Gives another player's record a valid proof for its seq (from `secret`, default its ID); returns the record.
function prove(record, secret, top)
    record.proof = proof_for(secret or record.id, record.seq, top)
    return record
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
stubMeta.__call = function() return nil end -- one nil, as the game API returns a value

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
local NIL_GAME_DATA = { player_map_id = true, player_map_position = true, fishing_rank = true, known_items = true,
    group_type = true, group_members = true, bn_send_result = true, user_waypoint = true, waypoint_result = true,
    explored_areas = true, profile_ms = true, profile_step = true, game_fold = true, no_scroll_templates = true }
setmetatable(_G, {
    __index = function(_, key)
        if key == "utf8" or NIL_GAME_DATA[key] or (type(key) == "string" and key:find("^OneKeyFishing")) then
            return nil -- utf8: Lua 5.3 only, see the top of this file
        end
        -- Game functions a test switches on (see the top of this file); undefined otherwise, as in an older client.
        if GAME_FOLD[key] then
            return rawget(_G, "game_fold") and GAME_FOLD[key] or nil
        end
        if key == "debugprofilestop" then
            return rawget(_G, "profile_ms") and ProfileClock or nil
        end
        if MISSING_51[key] then
            error("'" .. key .. "' exists in the game (Lua 5.1) but not in the test runtime; add a stub", 2)
        end
        RejectInTests(key, 3)
        stubs[key] = stubs[key] or Stub(key)
        return stubs[key]
    end,
})
