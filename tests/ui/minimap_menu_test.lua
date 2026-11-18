-- UI/Minimap.lua: the minimap button's menu in a fight. The game's title element is refused to addon code in combat
-- (the "Interface action failed because of an AddOn" line, seen in game 2026-11-18); the stub counts it.

load_addon()
local L = ns.L

local function OpenMenu()
    OneKeyFishing_OnAddonCompartmentClick(nil, "RightButton")
end

local function texts()
    local out = {}
    for _, entry in ipairs(menu_entries) do
        if entry.kind ~= "title" then
            table.insert(out, entry.text)
        end
    end
    return table.concat(out, "|")
end

test("out of combat the menu has its title", function()
    in_combat = false
    OpenMenu()
    eq(menu_entries[1].kind, "title", "first entry")
    eq(menu_entries[1].text, "OneKeyFishing", "the title")
    eq(menu_blocked, 0, "nothing refused")
end)

test("in combat the menu opens without a title, and the game refuses nothing", function()
    in_combat = false
    OpenMenu()
    local outside = texts()
    in_combat = true
    OpenMenu()
    in_combat = false
    eq(menu_blocked, 0, "no title, divider or spacer in combat")
    assert(not menu_entry("OneKeyFishing"), "no title")
    eq(texts(), outside, "the same entries as out of combat")
    assert(menu_entry(L["Statistics"]), "the statistics entry")
end)
