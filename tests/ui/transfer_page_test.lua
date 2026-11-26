-- UI/TransferPage.lua: the "Import and export" settings page (specs/027-import-export, User Story 1): the choice,
-- the text area, the hint and the Import button; /okf share import|export open it.

local FISH = 6291
OneKeyFishingDB = { shareNotice = true, settings = { shareDB = true } }
load_addon()

local L = ns.L
local Share, Store, P = ns.Share, ns.Share.Store, ns.Share.private
local page = assert(settings_pages[L["Import and export"]], "the page is registered")
local shared = ns.db.shared

local function rec(id)
    local cells = { ["1415:3:47"] = catch_cell(3, 1, { [FISH] = { 2, 2 } }) }
    return prove({ id = id, epoch = 1, seq = math.max(3, math.ceil(cells["1415:3:47"].t /
        ns.CatchDB.private.STEP_SECONDS)), builds = { ["1.60.1"] = cells } }, nil, 4096)
end

local function settle()
    for _ = 1, 2000 do
        page.Refresh()
        if Share.TransferState().state == "idle" then
            page.Refresh()
            return
        end
        advance(0)
    end
end

test("the page opens on Import with an empty area and the paste hint", function()
    page:Show()
    eq(page.Choice(), "import", "the choice")
    eq(page.edit:GetText(), "", "empty")
    assert(page.importButton:IsShown(), "the Import button")
    eq(page.hint:GetText(), L["Paste a string with Ctrl+V, then press Import."], "the hint")
end)

test("Export fills the area with the string and says what it holds", function()
    Store.Accept(shared, rec("aaaaaaaa"), 100)
    ns.SettingsUI.OpenTransfer("export") -- the page is shown: the choice applies at once
    eq(page.hint:GetText(), L["Preparing..."], "while it is built")
    settle()
    assert(page.edit:GetText():find("^OKF:1:"), "the string")
    assert(not page.importButton:IsShown(), "no Import button")
    assert(page.hint:GetText():find(L["It holds anonymous IDs and catch counts per place, no names."], 1, true),
        "what it holds")
end)

test("Import with a pasted string shows the counts; a damaged one its error", function()
    local text = P.ExportText({ Share.Encode(Store.ForSending(rec("baaaaaab"))) })
    ns.SettingsUI.OpenTransfer("import")
    page.edit:SetText(text)
    page.importButton:GetScript("OnClick")(page.importButton)
    settle()
    eq(page.hint:GetText(), (L["Imported: %d new, %d already known, %d your own, %d refused."]):format(1, 0, 0, 0),
        "the counts")
    page.edit:SetText("OKF:1:1:AAAAAAA:" .. text:match("^OKF:1:1:%w+:(.*):END$") .. ":END")
    page.importButton:GetScript("OnClick")(page.importButton)
    settle()
    eq(page.hint:GetText(), L["The text is damaged: copy the whole string again."], "the error")
end)

test("the Import button waits while an import runs", function()
    local text = P.ExportText({ Share.Encode(Store.ForSending(rec("caaaaaac"))) })
    page.edit:SetText(text)
    page.importButton:GetScript("OnClick")(page.importButton)
    page.Refresh()
    eq(page.importButton:IsEnabled(), false, "disabled while importing")
    settle()
    eq(page.importButton:IsEnabled(), true, "enabled again")
end)

test("/okf share export and import open the page on that choice", function()
    page:Hide()
    settings_opened = {}
    SlashCmdList.ONEKEYFISHING("share export")
    eq(#settings_opened, 1, "the settings opened")
    page:Show()
    eq(page.Choice(), "export", "on Export")
    settle()
    page:Hide()
    SlashCmdList.ONEKEYFISHING("share import")
    page:Show()
    eq(page.Choice(), "import", "on Import")
    SlashCmdList.ONEKEYFISHING("share")
    assert(chat_contains(L["Shared database"]), "plain /okf share still prints the state")
end)

test("Export chosen while an import runs starts once the import is over", function()
    local list = {}
    for i = 1, 6 do
        table.insert(list, Share.Encode(Store.ForSending(rec(ns.BASE32:sub(i + 10, i + 10):rep(8)))))
    end
    ns.SettingsUI.OpenTransfer("import")
    page.edit:SetText(P.ExportText(list))
    page.importButton:GetScript("OnClick")(page.importButton)
    eq(Share.TransferState().state, "importing", "the import runs")
    ns.SettingsUI.OpenTransfer("export")
    settle()
    page.Refresh() -- the export the page started once the import was over
    settle()
    assert(page.edit:GetText():find("^OKF:1:"), "the export string came")
end)

test("coming back to the page keeps a pasted string that was not imported yet", function()
    ns.SettingsUI.OpenTransfer("import")
    page.edit:SetText("OKF:1:1:aaaaaaa:pasted:END")
    page:Hide()
    page:Show()
    eq(page.edit:GetText(), "OKF:1:1:aaaaaaa:pasted:END", "still there")
end)

test("/okf share export in a fight changes nothing on the page", function()
    ns.SettingsUI.OpenTransfer("import")
    page.edit:SetText("OKF:1:1:aaaaaaa:pasted:END")
    page:Hide()
    in_combat = true
    SlashCmdList.ONEKEYFISHING("share export")
    in_combat = false
    page:Show()
    eq(page.Choice(), "import", "still on Import")
    eq(page.edit:GetText(), "OKF:1:1:aaaaaaa:pasted:END", "the pasted string kept")
end)

test("after the area was reset, the hint gives the instruction again, not the last import's counts", function()
    local text = P.ExportText({ Share.Encode(Store.ForSending(rec("qaaaaaaq"))) })
    ns.SettingsUI.OpenTransfer("import")
    page.edit:SetText(text)
    page.importButton:GetScript("OnClick")(page.importButton)
    settle()
    assert(page.hint:GetText():find("1", 1, true), "the counts")
    ns.SettingsUI.OpenTransfer("export")
    settle()
    ns.SettingsUI.OpenTransfer("import")
    page.Refresh()
    eq(page.hint:GetText(), L["Paste a string with Ctrl+V, then press Import."], "the instruction")
end)

test("Export chosen again exports again; Import chosen again keeps a pasted string", function()
    ns.SettingsUI.OpenTransfer("export")
    settle()
    local exports = 0
    local export = Share.Export
    Share.Export = function(...)
        exports = exports + 1
        return export(...)
    end
    page.Choose("export")
    Share.Export = export
    eq(exports, 1, "a new export started")
    settle()
    ns.SettingsUI.OpenTransfer("import")
    page.edit:SetText("OKF:1:1:aaaaaaa:pasted:END")
    page.Choose("import")
    eq(page.edit:GetText(), "OKF:1:1:aaaaaaa:pasted:END", "the pasted string kept")
end)

test("a long paste on Import: the box keeps its start, OnChar collects the whole string, Import takes it", function()
    ns.SettingsUI.OpenTransfer("import")
    local list = {}
    for i = 1, 30 do
        table.insert(list, Share.Encode(Store.ForSending(rec(ns.BASE32:sub(i % 26 + 1, i % 26 + 1) .. "aaaaaa"
            .. ns.BASE32:sub(i % 7 + 1, i % 7 + 1)))))
    end
    local text = P.ExportText(list)
    assert(#text > 2048, "a string longer than the box shows: " .. #text)
    -- What the game does on a paste: the box takes its first 2048 bytes, OnChar runs for every character.
    page.edit:SetText(text:sub(1, 2048))
    local onChar = page.edit:GetScript("OnChar")
    for i = 1, #text do
        onChar(page.edit, text:sub(i, i))
    end
    page.edit:GetScript("OnUpdate")(page.edit, 0)
    eq(page.Pasted(), text, "the whole paste")
    page.Refresh()
    eq(page.hint:GetText(), (L["Pasted %d KB. Press Import."]):format(math.ceil(#text / 1024)), "the hint")
    page.importButton:GetScript("OnClick")(page.importButton)
    settle()
    local result = Share.TransferState().result
    eq(result.error, nil, "no error: the whole string was imported")
    eq(result.new + result.known + result.own + result.refused, 30, "every record answered")
end)

test("a character typed by hand is not taken for a paste", function()
    ns.SettingsUI.OpenTransfer("import")
    page.edit:SetText("x")
    page.edit:GetScript("OnChar")(page.edit, "x")
    page.edit:GetScript("OnUpdate")(page.edit, 0)
    page.edit:SetText("xy")
    page.edit:GetScript("OnChar")(page.edit, "y")
    page.edit:GetScript("OnUpdate")(page.edit, 0)
    eq(page.Pasted(), nil, "the box's own text is used")
end)

