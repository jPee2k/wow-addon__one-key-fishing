-- UI/Indicator.lua: a change of the Fishing skill redraws the indicator, since the lure the key offers depends on
-- the skill (specs/008-architecture-alignment US2; spec 008 review).

load_addon()

test("SKILL_LINES_CHANGED redraws the indicator", function()
    local calls = 0
    local update = ns.Indicator.Update
    ns.Indicator.Update = function() calls = calls + 1 end
    fire("SKILL_LINES_CHANGED")
    ns.Indicator.Update = update
    eq(calls, 1, "one redraw")
end)
