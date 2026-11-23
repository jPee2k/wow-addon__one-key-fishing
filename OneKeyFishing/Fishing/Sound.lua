-- Sound: the addon's fishing sounds (specs/013-fishing-sounds). While "Play fishing sounds" is on and fishing mode is
-- on, it plays the author's files:
--   bell  when the line is cast (FISHING_CAST_START: the fishing channel starts)
--   hook  on the result of the hook press: FISH_CAUGHT, or FISH_ESCAPED (the game's "fish got away" / "no fish
--         hooked" line, Catch.lua)
--   rare  for a loot with an Uncommon or better item, a moment after the hook sound
-- The sounds are notices only: nothing here casts, hooks or loots. The fishing key runs the game's interact action
-- while the line is out, so no addon code sees that press; its result is what the addon hears (research R1).
-- PlaySoundFile has no volume argument: each file ships pre-rendered at every 10 % step (Media/Sounds/VolumeNN/,
-- npm run sounds) and the volume picks the file. In a fight every sound stops and none plays until it ends.
local _, ns = ...

local Sound = {}
ns.Sound = Sound

local FOLDER = "Interface\\AddOns\\OneKeyFishing\\Media\\Sounds\\"
local FADE_MS = 100 -- the fade of a sound stopped early
local RARE_DELAY = 0.4 -- seconds between the hook sound and the rare one of the same catch, so both are heard

-- The volume grid: 0-100 % in steps of 10, the steps tools/addon.mjs VOLUME_STEPS renders (npm run sounds).
Sound.VOLUME_MIN, Sound.VOLUME_MAX, Sound.VOLUME_STEP = 0, 100, 10

local handles = {} -- event -> the handle of its last sound
local token = 0 -- bumped on every stop: a delayed sound plays only under the token it was scheduled with

function Sound.IsEnabled()
    return ns.db.settings.fishingSounds == true
end

-- The only writer of settings.fishingSounds (CLAUDE.md, cross-module rules).
function Sound.SetEnabled(value)
    ns.db.settings.fishingSounds = value == true
    if not Sound.IsEnabled() then
        Sound.StopAll()
    end
    ns.Fire("SETTINGS_CHANGED", "fishingSounds")
end

local function Clamp(percent)
    percent = tonumber(percent)
    if not percent or percent ~= percent then
        return 100
    end
    percent = math.max(Sound.VOLUME_MIN, math.min(Sound.VOLUME_MAX, percent))
    return math.floor(percent / Sound.VOLUME_STEP + 0.5) * Sound.VOLUME_STEP
end

-- 0-100 in steps of 10; a saved value off that grid is clamped and rounded.
function Sound.Volume()
    return Clamp(ns.db.settings.soundVolume)
end

-- No SETTINGS_CHANGED: only this module and the slider read the volume, and the slider fires a step per move, which
-- would make every listener of that message (the open catch views among them) rebuild for nothing.
function Sound.SetVolume(percent)
    ns.db.settings.soundVolume = Clamp(percent)
end

-- The file of an event ("bell", "hook", "rare") at a volume step; nil at 0 (nothing to play).
function Sound.Path(event, volume)
    if volume <= 0 then
        return nil
    end
    local step = volume < 100 and ("Volume" .. volume .. "\\") or ""
    return FOLDER .. step .. event .. ".ogg"
end

local function Stop(event)
    local handle = handles[event]
    handles[event] = nil
    if handle then
        pcall(StopSound, handle, FADE_MS)
    end
end

-- Plays one event's file at the current volume; the event's previous sound stops first.
-- Seen in game 2026-11-16 (V46): an addon .ogg plays by path on the Master channel and StopSound stops it.
local function Play(event)
    Stop(event)
    local path = Sound.Path(event, Sound.Volume())
    if not path then
        return -- 0 %: nothing plays, and the previous sound of the event is stopped too
    end
    local ok, willPlay, handle = pcall(PlaySoundFile, path, "Master")
    if ok and willPlay then
        handles[event] = handle
    end
end

-- The sample of the volume slider (FR-010): the hook sound at the current volume, also outside fishing mode, but
-- not in a fight. The page greys the slider while the sounds are off, so only the player's own move asks for it.
function Sound.Preview()
    if not ns.Mode.InFight() then
        Play("hook")
    end
end

function Sound.StopAll()
    token = token + 1
    for event in pairs(handles) do
        Stop(event)
    end
end

-- Every sound of fishing needs the sounds on, fishing mode on and no fight (FR-005, FR-018; Mode.lua tracks the
-- fight from PLAYER_REGEN_DISABLED, which runs there first: TOC order).
local function Allowed()
    return Sound.IsEnabled() and ns.Mode.IsActive() and not ns.Mode.InFight()
end

local hookCast = 0 -- the cast that already played its hook sound

-- Once per cast: every FISHING_CAST_START is a new cast (Catch.lua numbers each one).
ns.On("FISHING_CAST_START", function()
    if Allowed() then
        Play("bell")
    end
end)

local function PlayHook(cast)
    if hookCast == cast then
        return
    end
    hookCast = cast
    Play("hook")
end

local function IsRare(items)
    local uncommon = Enum and Enum.ItemQuality and Enum.ItemQuality.Uncommon or 2
    for _, item in ipairs(items) do
        if type(item.quality) == "number" and item.quality >= uncommon then
            return true
        end
    end
    return false
end

-- The hook press has no event of its own; its answer is a catch (FISH_CAUGHT) or the game's line for a fish that got
-- away or was not hooked (FISH_ESCAPED, Catch.lua). A green or better item adds the rare sound a moment later.
-- Seen in game 2026-11-16 (V47): the loot and the game's fish line come at once after the hook press.
local rareCast -- the cast whose rare sound is scheduled: one per cast

local function PlayRare(castID)
    if castID ~= nil and rareCast == castID then
        return
    end
    rareCast = castID
    local scheduled = token
    C_Timer.After(RARE_DELAY, function()
        if scheduled == token and Allowed() then
            Play("rare")
        end
    end)
end

ns.On("FISH_CAUGHT", function(items, castID)
    if not Allowed() then
        return
    end
    PlayHook(castID)
    if IsRare(items) then
        PlayRare(castID)
    end
end)

-- A trophy new to the account (spec 023, CatchDB settles after this module's FISH_CAUGHT) gets the rare sound too,
-- once per cast. Its kind is read from the game data: this layer knows no Catalog.
ns.On("ITEM_FIRST_CAUGHT", function(itemID, castID)
    if Allowed() and ns.GameData.ItemKinds.byItem[itemID] == "trophies" then
        PlayRare(castID)
    end
end)

ns.On("FISH_ESCAPED", function(castID)
    if Allowed() then
        PlayHook(castID)
    end
end)

ns.On("MODE_CHANGED", function(on)
    if not on then
        Sound.StopAll()
    end
end)

-- A fight silences what plays; Allowed() keeps it silent until the fight ends.
ns.RegisterEvent("PLAYER_REGEN_DISABLED", Sound.StopAll)
