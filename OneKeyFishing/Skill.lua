-- Skill: Fishing skill and a warning when the current rank is (almost) capped and the next rank must be learned.
local _, ns = ...
local L = ns.L

local Skill = {}
ns.Skill = Skill

-- Points before the cap at which the first warning appears.
local WARN_BEFORE = 5

local RANK_NAMES = {
    [75] = L["Apprentice"],
    [150] = L["Journeyman"],
    [225] = L["Expert"],
    [300] = L["Artisan"],
}

-- Where to learn the rank that follows each cap. From the original game; Forever may differ.
local NEXT_RANK = {
    [75] = { name = L["Journeyman"], where = L["a fishing trainer"] },
    [150] = {
        name = L["Expert"],
        where = L["the book \"Expert Fishing - The Bass and You\" (Old Man Heming, Booty Bay)"],
    },
    [225] = { name = L["Artisan"], where = L["the quest from Nat Pagle (Dustwallow Marsh)"] },
}

local warned = {} -- maxRank -> "near" | "cap", for this session

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

function Skill.GetRankName(maxRank)
    return RANK_NAMES[maxRank] or ""
end

local function Announce(text, loud)
    ns.Print(text)
    ns.Toast(text, 1, 0.55, 0.1)
    if loud and RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo then
        RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo.RAID_WARNING)
    end
end

-- `repeatCap`: remind again about an already announced cap (on entering fishing mode).
local function Check(repeatCap)
    local rank, maxRank = Skill.Get()
    if not rank then
        return
    end
    local session = ns.charDB.session
    if session and not session.skillStart then
        session.skillStart = rank
    end

    local nextRank = NEXT_RANK[maxRank]
    if not nextRank or not ns.db.settings.skillCapWarning then
        return
    end
    if rank >= maxRank then
        if repeatCap or warned[maxRank] ~= "cap" then
            warned[maxRank] = "cap"
            Announce((L["Fishing skill capped (%d/%d): learn %s Fishing from %s."]):format(
                rank, maxRank, nextRank.name, nextRank.where), true)
        end
    elseif maxRank - rank <= WARN_BEFORE and not warned[maxRank] then
        warned[maxRank] = "near"
        Announce((L["Fishing %d/%d: %d point(s) left in this rank. Next: %s Fishing from %s."]):format(
            rank, maxRank, maxRank - rank, nextRank.name, nextRank.where), false)
    end
end

ns.RegisterEvent("SKILL_LINES_CHANGED", function() Check(false) end)
ns.RegisterEvent("CHAT_MSG_SKILL", function() Check(false) end)
ns.RegisterEvent("PLAYER_ENTERING_WORLD", function()
    -- Profession data is not always ready right at login.
    C_Timer.After(2, function() Check(false) end)
end)
ns.On("MODE_CHANGED", function(active)
    if active then
        Check(true)
    end
end)
