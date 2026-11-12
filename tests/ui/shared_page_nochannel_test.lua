-- UI/Settings.lua: the "Shared database" page in a release without the public channel (Channel.AVAILABLE false,
-- FR-026): no channel setting, sentence or state line. One login.

reset_popup()
load_addon(function() ns.Channel.AVAILABLE = false end)
local L = ns.L
local page = settings_pages[L["Shared database"]]

test("without the channel the page has no channel setting, sentence or state line", function()
    assert(page, "the page")
    eq(find_frame(L["Use the public channel"], page), nil, "no setting")
    eq(page.channelBox, nil, "no checkbox")
    eq(page.channelLine, nil, "no state line")
    for _, frame in ipairs(frames) do
        if type(frame.text) == "string" then
            assert(not frame.text:find(L["Anyone who joins that channel by its name can see which characters in it use "
                .. "the addon."], 1, true), "no channel sentence")
        end
    end
end)
