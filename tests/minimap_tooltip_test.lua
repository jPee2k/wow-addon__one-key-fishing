-- UI/Minimap.lua: in Korean and Chinese the tooltip ends with a blank line, because their glyphs are taller than
-- the line height the game measures, and the last line reached below the frame (spec 007, User Story 6).

local recorded
GameTooltip = {
    SetOwner = function() recorded = {} end,
    AddLine = function(_, text) table.insert(recorded, text) end,
    AddDoubleLine = function(_, left) table.insert(recorded, left) end,
    Show = function() end,
    Hide = function() end,
}

load_addon()

local CJK = { koKR = true, zhCN = true, zhTW = true }

local function lastLine(code)
    ns.language = code -- the tooltip reads the language in use when it is built
    local button = assert(_G.OneKeyFishingMinimapButton, "the minimap button")
    button.scripts.OnEnter(button)
    return recorded[#recorded]
end

test("a blank last line only for Korean and Chinese", function()
    local languages = ns.GetLanguages()
    eq(#languages, 10, "languages")
    for _, language in ipairs(languages) do
        local last = lastLine(language.code)
        if CJK[language.code] and not CJK[CLIENT_LOCALE] then
            eq(last, " ", language.code .. " last line")
        else
            assert(last ~= " ", language.code .. ": no blank last line")
        end
    end
end)

test("a Korean or Chinese client measures its own font: no blank line", function()
    CLIENT_LOCALE = "koKR"
    assert(lastLine("koKR") ~= " ", "koKR on a Korean client")
    assert(lastLine("zhCN") ~= " ", "zhCN on a Korean client")
    CLIENT_LOCALE = nil
end)
