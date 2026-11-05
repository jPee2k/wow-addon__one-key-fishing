-- UI/Minimap.lua: in Korean and Chinese the tooltip ends with a blank line, because their glyphs are taller than
-- the line height the game measures, and the last line reached below the frame (spec 007, User Story 6).

local recorded, wrapped
GameTooltip = {
    SetOwner = function() recorded, wrapped = {}, {} end,
    AddLine = function(_, text, _, _, _, wrap)
        table.insert(recorded, text)
        if wrap then
            table.insert(wrapped, text)
        end
    end,
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

-- The Language button's tooltip wraps two sentences. In game (2026-11-05, ruRU client, addon in zhCN) the game
-- counted the wrapped lines with the Latin font and two lines fell below the frame: no wrapping, and the blank line.
local function languageTooltip(code)
    ns.language = code
    for _, frame in ipairs(frames) do
        if frame.scripts.OnEnter and frame.parent == settings_pages["OneKeyFishing"] then
            frame.scripts.OnEnter(frame)
            if recorded and recorded[1] == ns.L["Interface language"] then
                return recorded, wrapped
            end
        end
    end
    error("no Language button tooltip")
end

test("the Language tooltip does not wrap Korean or Chinese on another client, and ends with a blank line", function()
    local lines, wraps = languageTooltip("zhCN")
    eq(#wraps, 0, "wrapped lines")
    eq(lines[#lines], " ", "last line")
    lines, wraps = languageTooltip("deDE")
    eq(#wraps, 2, "German wraps its two sentences")
    assert(lines[#lines] ~= " ", "no blank line in German")
end)
