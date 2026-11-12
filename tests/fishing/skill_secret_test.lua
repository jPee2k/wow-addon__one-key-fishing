-- Fishing/Skill.lua in a fight (spec 011, User Story 1): the game gives the trainer's tooltip name as a secret
-- value in an instance fight (seen 2026-11-08), and weapon skill-ups fire the skill events there. The advice treats
-- a secret name as missing, and the skill check waits for the end of the fight.
-- The tests run in order: one character at skill 130 of 150, below the Expert rank's level 20.

fishing_skill = { 130, 150 }
player_level = 15
load_addon()
advance(2) -- the check a moment after logging in

local Skill = ns.Skill
local HEMING = 2626

local lookups = 0
local getHyperlink = C_TooltipInfo.GetHyperlink
C_TooltipInfo.GetHyperlink = function(link)
    lookups = lookups + 1
    return getHyperlink(link)
end

local function count(text)
    local n = 0
    for _, line in ipairs(chat) do
        if line:find(text, 1, true) then
            n = n + 1
        end
    end
    return n
end

test("a skill-up in a fight builds no advice and reads no tooltip", function()
    lookups = 0
    fire("CHAT_MSG_SKILL")
    assert(lookups > 0, "out of a fight the check reads the trainer's tooltip (the notice still waits)")
    in_combat = true
    lookups = 0
    fire("CHAT_MSG_SKILL")
    fire("SKILL_LINES_CHANGED")
    eq(lookups, 0, "no tooltip read in a fight")
    in_combat = false
end)

test("a notice that came due in a fight is shown once after it", function()
    in_combat = true
    player_level = 20
    fire("CHAT_MSG_SKILL")
    eq(count("You can learn Expert Fishing now."), 0, "nothing in the fight")
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    eq(count("You can learn Expert Fishing now."), 1, "the notice after the fight")
    fire("PLAYER_REGEN_ENABLED")
    eq(count("You can learn Expert Fishing now."), 1, "once")
end)

test("a secret trainer name counts as missing: the table's name, no error", function()
    tooltip_names[HEMING] = "Secret Heming"
    secret_values["Secret Heming"] = true
    local advice = Skill.GetNextRank()
    assert(advice.sources.npc == "table" or advice.sources.npc == "english", "a fallback name source")
    assert(advice.where:find("from Old Man Heming in", 1, true), "the table's name in the sentence")
    assert(not advice.where:find("Secret", 1, true), "not the secret name")
end)

test("a secret name is not kept: outside the fight the game's name is read again", function()
    secret_values["Secret Heming"] = nil
    local advice = Skill.GetNextRank()
    eq(advice.sources.npc, "game", "from the tooltip now")
    assert(advice.where:find("from Secret Heming in", 1, true), "the game's name in the sentence")
end)
