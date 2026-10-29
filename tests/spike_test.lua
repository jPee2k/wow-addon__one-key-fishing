-- Spike.lua (temporary, removed with it before the release): the /okf spike report.

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon()

local function report()
    local text
    local show = ns.ShowCopyWindow
    ns.ShowCopyWindow = function(_, body) text = body end
    ns.ShowSpikeReport()
    ns.ShowCopyWindow = show
    return text
end

test("the report has every section and the pool decision of the last fishing loot", function()
    ns.Fire("FISHING_CAST_START", 7620)
    loot = { fishing = true, items = { { 6291, 1 } } }
    loot_sources = { [1] = "GameObject-0-1-2-3-180582-4" }
    fire("LOOT_READY")
    loot, loot_sources = nil, {}
    local text = report()
    for _, title in ipairs({ "Build (V7)", "Map (V1, V2)", "Last fishing loot (V3)", "Last auction search (V4, V5)",
        "Tabs (V6)" }) do
        assert(text:find("-- " .. title .. " --", 1, true), title)
    end
    assert(text:find("(game object 180582)", 1, true), "the object ID the addon compares")
    assert(text:find("ns.IsPoolLoot(): true", 1, true), "the pool decision")
    assert(text:find("position: 0.43, 0.78", 1, true), "the position")
end)

test("running the report again makes no new tab frame", function()
    local count = #frames
    report()
    eq(#frames, count, "frames")
end)
