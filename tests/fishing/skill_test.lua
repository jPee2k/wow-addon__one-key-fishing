-- Fishing/Skill.lua: the cap warning reaches the chat and, through SKILL_WARNING, the toast (UI/Toast.lua).

fishing_rank = 75
-- The stub's max rank is 300 (Artisan, no next rank); this character is a capped Apprentice (75 of 75).
function GetProfessionInfo(index)
    if index == 1 then
        return "Fishing", 136245, fishing_rank, 75, 0, 0, 356
    end
end
load_addon()

local toasts = {}
ns.Toast = function(text) table.insert(toasts, text) end

test("a skill change at the cap warns in chat and with a toast", function()
    local warned = {}
    ns.On("SKILL_WARNING", function(text, loud) table.insert(warned, { text = text, loud = loud }) end)
    fire("SKILL_LINES_CHANGED")
    eq(#warned, 1, "one warning")
    eq(warned[1].loud, true, "loud at the cap")
    eq(#toasts, 1, "the toast listens to the message")
    eq(toasts[1], warned[1].text, "the same text")
end)
