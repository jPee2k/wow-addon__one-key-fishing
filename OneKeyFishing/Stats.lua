-- Stats: casts, catches, misses, caught items and time, per session, per zone and in total (per character).
-- Time is counted in segments: a segment runs while fishing mode is on (and the player is not AFK, if
-- that option is on) and is added to the buckets when it ends, on zone change and on logout.
-- A session lasts until the next login (not /reload) or until it is reset.
local _, ns = ...

local Stats = {}
ns.Stats = Stats

local zoneKey, zoneName
local segmentStart -- GetTime() when the running time segment began
local castStart -- GetTime() when the current cast began

local function NewBucket()
    return { casts = 0, catches = 0, misses = 0, modeTime = 0, castTime = 0, items = {} }
end

local function NewSession()
    local session = NewBucket()
    session.started = time()
    session.skillStart = ns.Skill and ns.Skill.Get() or nil
    return session
end

---------------------------------------------------------------------------
-- Zones
---------------------------------------------------------------------------
local function ReadZone()
    local mapID = C_Map.GetBestMapForUnit("player")
    local info = mapID and C_Map.GetMapInfo(mapID)
    local zone = info and info.name or GetZoneText() or "?"
    local subZone = GetSubZoneText() or ""
    local name = (subZone ~= "" and subZone ~= zone) and (zone .. " - " .. subZone) or zone
    return tostring(mapID or 0) .. ":" .. subZone, name
end

local function CurrentZoneBucket()
    if not zoneKey then
        zoneKey, zoneName = ReadZone()
    end
    local zones = ns.charDB.stats.zones
    local bucket = zones[zoneKey]
    if not bucket then
        bucket = NewBucket()
        zones[zoneKey] = bucket
    end
    bucket.name = zoneName
    return bucket
end

local function ForEachLiveBucket(fn)
    fn(ns.charDB.session)
    fn(ns.charDB.stats.total)
    fn(CurrentZoneBucket())
end

local function Add(field, amount)
    ForEachLiveBucket(function(bucket) bucket[field] = bucket[field] + amount end)
end

---------------------------------------------------------------------------
-- Time
---------------------------------------------------------------------------
local function ShouldTimerRun()
    return ns.Mode.IsActive() and not (ns.db.settings.pauseOnAFK and UnitIsAFK("player"))
end

local function FlushTime()
    local now = GetTime()
    if segmentStart then
        Add("modeTime", now - segmentStart)
        segmentStart = nil
    end
    if castStart then
        Add("castTime", now - castStart)
        castStart = now
    end
end

local function UpdateTimer()
    FlushTime()
    if ShouldTimerRun() then
        segmentStart = GetTime()
    end
end

-- Seconds not yet added to the session / current zone / total buckets.
function Stats.GetLiveTime()
    local now = GetTime()
    return segmentStart and (now - segmentStart) or 0, castStart and (now - castStart) or 0
end

local function OnZoneChanged()
    local key, name = ReadZone()
    if key == zoneKey then
        return
    end
    FlushTime() -- into the zone we are leaving
    zoneKey, zoneName = key, name
    UpdateTimer()
end

---------------------------------------------------------------------------
-- Access for the UI
---------------------------------------------------------------------------
function Stats.GetSession()
    return ns.charDB.session
end

-- Fishing mode time of this session, including the running segment.
function Stats.GetSessionTime()
    local session = ns.charDB.session
    return session and (session.modeTime + Stats.GetLiveTime()) or 0
end

-- Seconds -> "H:MM:SS".
function Stats.FormatTime(seconds)
    seconds = math.floor(seconds or 0)
    return ("%d:%02d:%02d"):format(seconds / 3600, (seconds / 60) % 60, seconds % 60)
end

function Stats.GetTotal()
    return ns.charDB.stats.total
end

function Stats.GetCurrentZone()
    return CurrentZoneBucket()
end

function Stats.GetZones()
    return ns.charDB.stats.zones
end

function Stats.GetValue(bucket)
    local value = 0
    for itemID, count in pairs(bucket.items) do
        value = value + count * ns.Prices.Get(itemID)
    end
    return value
end

function Stats.ResetSession()
    FlushTime()
    ns.charDB.session = NewSession()
    UpdateTimer()
    ns.Fire("STATS_CHANGED")
end

function Stats.ResetAll()
    FlushTime()
    ns.charDB.stats = { total = NewBucket(), zones = {} }
    ns.charDB.session = NewSession()
    UpdateTimer()
    ns.Fire("STATS_CHANGED")
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
-- `resumed`: a cast picked up after a /reload. It was counted before, and its time so far was flushed on logout.
ns.On("FISHING_CAST_START", function(_, resumed)
    if not resumed then
        Add("casts", 1)
    end
    castStart = GetTime()
end)

ns.On("FISHING_CAST_STOP", function()
    if castStart then
        Add("castTime", GetTime() - castStart)
        castStart = nil
    end
end)

ns.On("FISH_CAUGHT", function(items)
    Add("catches", 1)
    for _, item in ipairs(items) do
        local itemID = C_Item.GetItemInfoInstant(item.link)
        if itemID then
            ForEachLiveBucket(function(bucket)
                bucket.items[itemID] = (bucket.items[itemID] or 0) + item.quantity
            end)
        end
    end
    ns.Fire("STATS_CHANGED")
end)

ns.On("FISH_MISSED", function()
    Add("misses", 1)
    ns.Fire("STATS_CHANGED")
end)

ns.On("MODE_CHANGED", UpdateTimer)
ns.On("SETTINGS_CHANGED", UpdateTimer)

ns.RegisterEvent("PLAYER_FLAGS_CHANGED", function(_, unit)
    if unit == "player" then
        UpdateTimer()
    end
end)

ns.RegisterEvent("PLAYER_LOGIN", function()
    ns.charDB.stats = ns.charDB.stats or { total = NewBucket(), zones = {} }
    ns.charDB.session = ns.charDB.session or NewSession()
end)

ns.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, isInitialLogin)
    if isInitialLogin then
        ns.charDB.session = NewSession()
    end
    FlushTime() -- after a loading screen: into the zone we came from
    zoneKey, zoneName = ReadZone()
    UpdateTimer()
end)

ns.RegisterEvent("ZONE_CHANGED", OnZoneChanged)
ns.RegisterEvent("ZONE_CHANGED_INDOORS", OnZoneChanged)
ns.RegisterEvent("ZONE_CHANGED_NEW_AREA", OnZoneChanged)
ns.RegisterEvent("PLAYER_LOGOUT", FlushTime)
-- Loading screens do not count as fishing time; PLAYER_ENTERING_WORLD restarts the timer.
ns.RegisterEvent("PLAYER_LEAVING_WORLD", FlushTime)
