-- Camera: zoom to a set distance while fishing and back to the previous zoom afterwards.
-- The previous zoom is kept in the character DB so a /reload in fishing mode does not lose it.
local _, ns = ...

local Camera = {}
ns.Camera = Camera

Camera.MIN_DISTANCE = 2
Camera.MAX_DISTANCE = 30

-- Zooming is animated: right after a zoom GetCameraZoom() returns a value halfway there.
-- Within this window the previous target is used as the starting point instead.
local ZOOM_SETTLE_TIME = 1.5

local lastTarget, lastZoomTime

-- Where the camera is, or is heading to if a zoom was just started.
local function CurrentZoom()
    if lastTarget and GetTime() - lastZoomTime < ZOOM_SETTLE_TIME then
        return lastTarget
    end
    return GetCameraZoom()
end

local function ZoomTo(distance)
    local delta = distance - CurrentZoom()
    if delta > 0 then
        CameraZoomOut(delta)
    elseif delta < 0 then
        CameraZoomIn(-delta)
    end
    lastTarget, lastZoomTime = distance, GetTime()
end

function Camera.Apply()
    if not ns.db.settings.camera then
        return
    end
    ns.charDB.savedCameraZoom = ns.charDB.savedCameraZoom or CurrentZoom()
    ZoomTo(ns.db.settings.cameraDistance)
end

function Camera.Restore()
    local saved = ns.charDB.savedCameraZoom
    if saved then
        ns.charDB.savedCameraZoom = nil
        ZoomTo(saved)
    end
end

-- A zoom saved before logging out means nothing in a new session.
function Camera.Forget()
    ns.charDB.savedCameraZoom = nil
end

function Camera.SetDistance(distance)
    distance = math.max(Camera.MIN_DISTANCE, math.min(Camera.MAX_DISTANCE, distance))
    ns.db.settings.cameraDistance = distance
    if ns.Mode.IsActive() then
        Camera.Apply()
    end
    return distance
end
