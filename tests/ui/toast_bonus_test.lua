-- UI/Toast.lua and the camp bonus notice (specs/020-camp-buffs FR-032): the notice's text is shown even with catch
-- notifications off, like the next-rank notice.

load_addon()

test("CAMP_BONUS_WARNING shows its text with catch notifications off", function()
    ns.db.settings.toasts = false
    local text = ns.L["The Fishing Rack bonus ends in 5 minutes."]
    ns.Fire("CAMP_BONUS_WARNING", text)
    local line = assert(find_frame(text), "a toast line with the text")
    assert(line:IsShown(), "shown")
end)
