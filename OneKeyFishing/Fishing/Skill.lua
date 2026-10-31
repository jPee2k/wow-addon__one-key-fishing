-- Skill: the Fishing skill, and the advice for the next rank (spec 001, User Story 3): when it can be learned,
-- where, and a notice when that moment comes and at the cap. The rank data is in GameData/FishingRanks.lua; every
-- game name in the advice is read from the client in its language, with English as the fallback.
local _, ns = ...
local L = ns.L

local Skill = {}
ns.Skill = Skill

-- The addon's own rank names, for a client that gives no spell subtext. Built on first use: the texts need the
-- language, which is set after the files load.
local fallbackRankNames

local function FallbackRankName(spellID)
    fallbackRankNames = fallbackRankNames or {
        [7620] = L["Apprentice"],
        [7731] = L["Journeyman"],
        [7732] = L["Expert"],
        [18248] = L["Artisan"],
    }
    return fallbackRankNames[spellID] or ""
end

-- warned[cap] = { now = true, cap = true }: the notices already shown this session.
local warned = {}

-- rank, maxRank of Fishing, or nil if it is not learned.
function Skill.Get()
    if not GetProfessions then
        return nil
    end
    local _, _, _, fishing = GetProfessions()
    if not fishing then
        return nil
    end
    local _, _, rank, maxRank = GetProfessionInfo(fishing)
    return rank, maxRank
end

local function NonEmpty(text)
    return type(text) == "string" and text ~= "" and text or nil
end

-- The name of a Fishing rank spell: its spell subtext in the client's language, else the addon's own name.
-- The Forever client gives the rank name ("Apprentice") as the subtext of the rank's Fishing spell (seen in game)
-- name, "game" | "addon"
local function RankNameBySpell(spellID)
    local subtext = C_Spell and type(C_Spell.GetSpellSubtext) == "function"
        and NonEmpty(C_Spell.GetSpellSubtext(spellID))
    if subtext then
        return subtext, "game"
    end
    return FallbackRankName(spellID), "addon"
end

-- The name of the rank whose skill cap is maxRank.
function Skill.GetRankName(maxRank)
    local spellID = ns.FishingRankSpells[maxRank]
    return spellID and (RankNameBySpell(spellID)) or ""
end

-- A name read from the client, or the fallback: name, "game" | "english".
local function FromGame(name, fallback)
    name = NonEmpty(name)
    if name then
        return name, "game"
    end
    return fallback, "english"
end

local function AreaName(areaID, fallback)
    return FromGame(type(C_Map.GetAreaInfo) == "function" and C_Map.GetAreaInfo(areaID), fallback)
end

local function ItemName(itemID, fallback)
    return FromGame(type(C_Item.GetItemNameByID) == "function" and C_Item.GetItemNameByID(itemID), fallback)
end

local function QuestTitle(questID, fallback)
    local api = C_QuestLog and C_QuestLog.GetTitleForQuestID
    return FromGame(type(api) == "function" and api(questID), fallback)
end

-- An NPC's name: the first line of its creature tooltip (no API reads an NPC name by ID; it works only for a
-- creature the client has cached), else the official name for the client's language, else English.
-- name, "game" | "table" | "english"
-- VERIFY(R12): a creature hyperlink gives a tooltip on Forever
local gameNpcNames = {} -- npcID -> the name the client gave once: no new tooltip on every refresh

local function NpcName(npcID)
    local api = C_TooltipInfo and C_TooltipInfo.GetHyperlink
    if gameNpcNames[npcID] then
        return gameNpcNames[npcID], "game"
    end
    if type(api) == "function" then
        local ok, data = pcall(api, ("unit:Creature-0-0-0-0-%d-0000000000"):format(npcID))
        local line = ok and type(data) == "table" and data.lines and data.lines[1]
        local name = line and NonEmpty(line.leftText)
        if name then
            gameNpcNames[npcID] = name
            return name, "game"
        end
    end
    local names = ns.NpcNames[npcID] or {}
    local name = NonEmpty(names[GetLocale()])
    if name then
        return name, "table"
    end
    return names.enUS or "", "english"
end

-- The sentence that says where the next rank is learned, the place name for a map pin, and where each name
-- came from.
local function Where(step)
    local source, fallback = step.source, step.fallback or {}
    if source.kind == "trainer" then
        return L["Any fishing trainer teaches it (capitals and towns; the minimap can track trainers)."], nil, {}
    end
    local sources = {}
    local npc, area, zone, what
    npc, sources.npc = NpcName(source.npcID)
    area, sources.area = AreaName(source.areaID, fallback.area)
    zone, sources.zone = AreaName(source.zoneAreaID, fallback.zone)
    if source.kind == "book" then
        what, sources.item = ItemName(source.itemID, fallback.item)
        return L["Buy the book \"%s\" from %s in %s, %s."]:format(what, npc, area, zone), area, sources
    end
    what, sources.quest = QuestTitle(source.questID, fallback.quest)
    return L["Do the quest \"%s\" from %s at %s, %s."]:format(what, npc, area, zone), area, sources
end

-- The advice for the next rank, or nil without one (Fishing not learned, or 300):
-- { cap, rank, state = "later" | "now" | "level" | "cap", level, levelLow, where, pin, placeName, sources }
-- "level": the skill is enough but the character level is not. At the cap, levelLow says the level is missing.
function Skill.GetNextRank()
    local rank, maxRank = Skill.Get()
    local step = rank and ns.FishingRanks[maxRank]
    if not step then
        return nil
    end
    local levelLow = (UnitLevel("player") or 0) < step.level
    local state
    if rank >= maxRank then
        state = "cap"
    elseif rank >= step.learnAt then
        state = levelLow and "level" or "now"
    else
        state = "later"
    end
    local where, placeName, sources = Where(step)
    local rankName
    rankName, sources.rank = RankNameBySpell(step.next)
    local source = step.source
    return {
        cap = maxRank,
        learnAt = step.learnAt,
        rank = rankName,
        state = state,
        level = step.level,
        levelLow = levelLow,
        where = where,
        pin = source.maps and ns.MapPin.Target(source.maps, source.x, source.y) or nil,
        placeName = placeName,
        sources = sources,
    }
end

-- The advice as the statistics window and the minimap tooltip show it (FR-021): what the next rank waits for,
-- then where it is learned.
function Skill.DescribeNextRank(advice)
    local head
    if advice.state == "later" and advice.levelLow then
        head = L["Next rank: %s Fishing, from skill %d and character level %d."]:format(advice.rank, advice.learnAt,
            advice.level)
    elseif advice.state == "later" then
        head = L["Next rank: %s Fishing, from skill %d."]:format(advice.rank, advice.learnAt)
    elseif advice.levelLow then
        head = L["Next rank: %s Fishing, from character level %d."]:format(advice.rank, advice.level)
    else
        head = L["Next rank: %s Fishing, ready to learn."]:format(advice.rank)
    end
    return head .. " " .. advice.where
end

-- The map pin on the next rank's place (the statistics window's button and the minimap menu), on the player's click.
function Skill.PinNextRank()
    local advice = Skill.GetNextRank()
    if advice and advice.pin then
        ns.MapPin.Set(advice.pin, advice.placeName)
    end
end

-- The chat line for the advice: the state sentence, where, and a map link.
local function ChatLine(first, advice)
    local text = first .. " " .. advice.where
    if advice.pin then
        text = text .. " " .. ns.MapPin.Link(advice.pin, L["Map pin"])
    end
    return text
end

-- Notices (FR-018 - FR-020): "can learn" once per session per rank, quiet (chat and toast), as soon as skill and
-- level allow; at the cap the raid-warning message the first time (naming a missing level), and on later entries
-- into fishing mode (`modeEntry`) a chat line. A cap reached before the level still gets "can learn" at the level.
local function Check(modeEntry)
    local rank, maxRank = Skill.Get()
    if not rank then
        return
    end
    local session = ns.charDB.session
    if session and not session.skillStart then
        session.skillStart = rank
    end

    -- Cheap checks first: SKILL_LINES_CHANGED fires for every skill, and the advice reads names and a tooltip.
    local step = ns.FishingRanks[maxRank]
    if not (step and ns.db.settings.skillCapWarning) or rank < step.learnAt then
        return
    end
    local done = warned[maxRank] or {}
    warned[maxRank] = done
    if not modeEntry and done.now and (done.cap or rank < maxRank) then
        return -- everything for this rank was said
    end
    local advice = Skill.GetNextRank()
    local levelOk = not advice.levelLow
    local capNotice = advice.state == "cap" and (not done.cap or modeEntry)
    if not (capNotice or (levelOk and not done.now)) then
        return
    end
    if capNotice then
        local first = L["Fishing skill capped (%d/%d): learn %s Fishing to go on."]:format(rank, maxRank,
            advice.rank)
        if advice.levelLow then
            first = first .. " " .. L["%s Fishing needs character level %d."]:format(advice.rank, advice.level)
        end
        ns.Print(ChatLine(first, advice))
        if not done.cap then
            done.cap = true
            ns.Toast(first, 1, 0.55, 0.1, true) -- shown even with catch notifications off
            if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo then
                RaidNotice_AddMessage(RaidWarningFrame, first, ChatTypeInfo.RAID_WARNING)
            end
        end
        done.now = done.now or levelOk -- the cap message already says it can be learned
    else
        done.now = true
        local first = L["You can learn %s Fishing now."]:format(advice.rank)
        ns.Print(ChatLine(first, advice))
        ns.Toast(first, 1, 0.82, 0, true)
    end
end

-- The client loads item, quest and spell data on request; ask for the book, the quest and the rank spells (their
-- subtext is the rank name) once at login.
local function RequestNames()
    if C_Spell and type(C_Spell.RequestLoadSpellData) == "function" then
        for _, spellID in pairs(ns.FishingRankSpells) do
            C_Spell.RequestLoadSpellData(spellID)
        end
    end
    for _, step in pairs(ns.FishingRanks) do
        local source = step.source
        if source.itemID and type(C_Item.RequestLoadItemDataByID) == "function" then
            C_Item.RequestLoadItemDataByID(source.itemID)
        end
        if source.questID and C_QuestLog and type(C_QuestLog.RequestLoadQuestByID) == "function" then
            C_QuestLog.RequestLoadQuestByID(source.questID)
        end
    end
end

ns.RegisterEvent("SKILL_LINES_CHANGED", function() Check(false) end)
ns.RegisterEvent("CHAT_MSG_SKILL", function() Check(false) end)
-- UnitLevel can still return the old level while PLAYER_LEVEL_UP runs: check a moment later.
ns.RegisterEvent("PLAYER_LEVEL_UP", function() C_Timer.After(1, function() Check(false) end) end)
ns.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, isLogin, isReload)
    if isLogin or isReload then
        RequestNames()
    end
    -- Profession data is not always ready right at login.
    C_Timer.After(2, function() Check(false) end)
end)
ns.On("MODE_CHANGED", function(active)
    if active then
        Check(true)
    end
end)
