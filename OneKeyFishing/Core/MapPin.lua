-- MapPin: the game's own map pin (user waypoint) with the navigation arrow, set on the player's click
-- (spec 001, User Story 3, FR-022; research R14). Every pin of the addon goes through it: the next rank
-- (Fishing/Skill.lua) and the catch catalog (Catalog.Spots, UI/CatalogTab.lua; spec 008). In Core: it makes no
-- frame, and its toasts are the UI's (MAP_PIN_SET, UI/Toast.lua).
local _, ns = ...
local L = ns.L

local MapPin = {}
ns.MapPin = MapPin

local PIN_EPSILON = 0.0005 -- a waypoint this close to the addon's last pin is that pin
local REPLACE_POPUP = "ONEKEYFISHING_REPLACE_PIN"

local function HasWaypointAPI()
    return type(C_Map.SetUserWaypoint) == "function" and type(C_Map.CanSetUserWaypointOnMap) == "function"
        and type(C_Map.GetMapInfo) == "function" and type(C_Map.HasUserWaypoint) == "function"
        and type(C_Map.GetUserWaypoint) == "function" and UiMapPoint ~= nil
end

-- True while the game rule that turns map pins off is active.
local function PinsDisabled()
    local rule = Enum and Enum.GameRule and Enum.GameRule.WorldMapTrackingPinDisabled
    return rule ~= nil and C_GameRules ~= nil and type(C_GameRules.IsGameRuleActive) == "function"
        and C_GameRules.IsGameRuleActive(rule) == true
end

-- The point on a Micro map (a cave, a building) that allows no pin, carried through the world position to its
-- parent zone: { mapID, x, y }, or nil. Dungeons and other maps never fall back: their zone is the wrong water.
local function OnParentMap(mapID, info, x, y)
    local parent = info.parentMapID
    if not (Enum.UIMapType and info.mapType == Enum.UIMapType.Micro and parent and parent ~= 0
        and C_Map.CanSetUserWaypointOnMap(parent)) or type(C_Map.GetWorldPosFromMapPos) ~= "function"
        or type(C_Map.GetMapPosFromWorldPos) ~= "function" then
        return nil
    end
    -- VERIFY(V33): a Micro map converts to its parent zone through the world position
    local continent, world = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
    if not world then
        return nil
    end
    local onMap, position = C_Map.GetMapPosFromWorldPos(continent, world, parent)
    local px, py = position and position.x, position and position.y
    if onMap ~= parent or not (px and py) or px < 0 or px > 1 or py < 0 or py > 1 then
        return nil
    end
    return { mapID = parent, x = px, y = py }
end

-- Where a pin for a point can go: { mapID, x, y } on the first of `maps` (uiMapIDs, best first, the point is on the
-- first) that the client knows and allows pins on; else, when the first candidate (the point's own map) is a cave or a
-- building the client knows, the same place on its zone's map; nil without the waypoint API, under the game rule and
-- when nothing fits.
-- The Forever client uses the Classic uiMapIDs (1434 for Stranglethorn Vale, seen in game).
function MapPin.Target(maps, x, y)
    if not (maps and x and y) or not HasWaypointAPI() or PinsDisabled() then
        return nil
    end
    for _, mapID in ipairs(maps) do
        local info = C_Map.GetMapInfo(mapID)
        -- CanSetUserWaypointOnMap answers per map, open world true; an instance has no map (V30, seen in game)
        if info and C_Map.CanSetUserWaypointOnMap(mapID) then
            return { mapID = mapID, x = x, y = y }
        end
    end
    -- The point is on the first candidate, so only that map can carry it to its parent.
    local first = C_Map.GetMapInfo(maps[1])
    return first and OnParentMap(maps[1], first, x, y)
end

-- True when the waypoint on the map is at pin ({ mapID, x, y }): same map, positions within PIN_EPSILON.
local function IsAt(point, pin)
    local position = point and point.position
    if not (pin and position) then
        return false
    end
    return point.uiMapID == pin.mapID and math.abs(position.x - pin.x) <= PIN_EPSILON
        and math.abs(position.y - pin.y) <= PIN_EPSILON
end

-- Sets the game's map pin at target ({ mapID, x, y }) with the navigation arrow, a toast and, out of combat, the
-- world map at that map. A pin the player set is replaced only after a question. Only on the player's click.
function MapPin.Set(target, placeName)
    local function Apply()
        if not C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(target.mapID, target.x, target.y)) then
            ns.Fire("MAP_PIN_SET", nil)
            return
        end
        -- Super tracking the user waypoint shows the navigation arrow (seen in game).
        if C_SuperTrack and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
        ns.charDB.pin = { mapID = target.mapID, x = target.x, y = target.y }
        ns.Fire("MAP_PIN_SET", placeName)
        -- VERIFY(R14): failed in game, docs/tech-debt.md: OpenWorldMap from addon code taints the map for a later fight
        if not InCombatLockdown() and type(OpenWorldMap) == "function" then
            OpenWorldMap(target.mapID) -- the global, not C_Map.OpenWorldMap: that one is restricted
        end
    end
    -- Replaced without asking: the addon's last pin, or a pin already at this place (set through the chat link).
    local current = C_Map.HasUserWaypoint() and C_Map.GetUserWaypoint()
    if current and not IsAt(current, ns.charDB.pin) and not IsAt(current, target) then
        ns.ShowPopup(REPLACE_POPUP, L["Replace your map pin with this place?"], Apply, L["Replace"], L["Cancel"])
    else
        Apply()
    end
end

-- A chat link to a point, as the game's own map links read ("worldmap:<uiMapID>:<x * 10000>:<y * 10000>"). The game
-- handles the click itself: it sets the pin and opens the map, without the addon's question or arrow (FR-022).
-- The Forever client accepts a worldmap link built by an addon, and the map it opens stays clean (seen in game).
function MapPin.Link(target, text)
    return ("|cffffff00|Hworldmap:%d:%d:%d|h[%s]|h|r"):format(target.mapID, math.floor(target.x * 10000 + 0.5),
        math.floor(target.y * 10000 + 0.5), text)
end
