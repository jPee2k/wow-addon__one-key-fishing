-- TransferPage: the "Import and export" settings page (specs/027-import-export). A choice (Import, the default, or
-- Export), one text area and a hint under it. Export fills the area with the string (Share.Export), selected and
-- focused, read-only; Import starts with an empty, focused area and an Import button (Share.Import). The addon has no
-- clipboard: the player presses Ctrl+C or Ctrl+V. The page polls Share.TransferState() while shown.
local _, ns = ...
local L = ns.L

local PADDING = 16
-- On Import the box shows only this much of a paste: laying out a whole string of 100 KB froze the game for seconds
-- (seen 2026-11-26, a 110 KB string). The whole paste is collected by OnChar (CreatePage).
local PREVIEW_BYTES = 2048

local page, opener
local choice = "import"

local function Hint(state)
    if choice == "export" then
        local export = state.export
        if state.state == "exporting" or not export or page.exportPending then
            return L["Preparing..."]
        end
        -- The own record left out for now: its proof is being built after a roll.
        local pending = export.ownPending
            and L["Your own data is still being prepared: choose Export my data again in a minute."]
        if not export.text then
            return pending or L["Nothing to export yet: catch some fish first."]
        end
        local text = (L["%d records, %d KB. Press Ctrl+C to copy, then paste it where the other player can read it."])
            :format(export.records, math.ceil(export.bytes / 1024)) .. " "
            .. L["It holds anonymous IDs and catch counts per place, no names."]
        return pending and (pending .. " " .. text) or text
    end
    if state.state == "importing" and state.progress then
        return (L["Importing: %d of %d records checked..."]):format(state.progress.done, state.progress.total)
    end
    local result = state.result
    if not result or state.resultSeq == page.clearedSeq then -- the area was reset since: the instruction again
        local pasted = page.Pasted()
        if pasted and #pasted > PREVIEW_BYTES then -- the box shows only its start
            return (L["Pasted %d KB. Press Import."]):format(math.ceil(#pasted / 1024))
        end
        return L["Paste a string with Ctrl+V, then press Import."]
    end
    local errors = {
        empty = L["No catch data found in the text."],
        cut = L["The text is incomplete: copy the whole string again."],
        format = L["This string comes from a newer version of the addon: update OneKeyFishing."],
        damaged = L["The text is damaged: copy the whole string again."],
    }
    if result.error then
        return errors[result.error] or errors.damaged
    end
    return (L["Imported: %d new, %d already known, %d your own, %d refused."]):format(result.new, result.known,
        result.own, result.refused)
end

-- The choice's text in the selector: other words than the Import button's, so the two never read alike.
local function ChoiceText(value)
    return value == "export" and L["Export my data"] or L["Import a string"]
end

-- Shows the choice: Export starts an export and shows its string once ready; Import empties the area.
local function Show(value)
    choice = value
    page.ShowChoice()
    page.importButton:SetShown(value == "import")
    page.shownExport = nil
    page.edit.text = nil
    page.pasted = nil
    -- Import shows only the start of a paste (OnChar keeps all of it); Export shows its whole string to copy.
    page.edit:SetMaxBytes(value == "import" and PREVIEW_BYTES or 0)
    page.edit:SetText("")
    page.clearedSeq = ns.Share.TransferState().resultSeq
    -- An import still running: the export starts once it is over (Refresh), not never.
    page.exportPending = value == "export" and not ns.Share.Export()
    page.edit:SetFocus()
    page.Refresh()
end

local function CreatePage()
    local frame = CreateFrame("Frame")
    page = frame

    local title = ns.CreateText(frame, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PADDING, -PADDING)
    title:SetText(L["Import and export"])

    local about = ns.CreateText(frame, "GameFontHighlightSmall")
    about:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    about:SetWidth(560)
    about:SetText(L["Move catch data between players without both being online: export it, send the text, import it."]
        .. " " .. L["Imported data counts even with the shared database off."])

    local function IsChosen(value)
        return choice == value
    end
    -- Export chosen again exports again (the hint asks for it while the own record is being prepared); Import chosen
    -- again keeps a pasted string.
    local function Choose(value)
        if value ~= choice or value == "export" then
            Show(value)
        end
    end
    frame.Choose = Choose
    -- The selector: a button with the chosen text that opens the choices in the addon's own menu. Not the game's
    -- dropdown: its menu rows come from the game's shared pool and would stay tainted (specs/029-blocked-actions).
    local choiceButton = ns.CreateButton(frame, ChoiceText(choice), 160, function(self)
        ns.OpenRadioMenu(self, { { value = "import", text = ChoiceText("import") },
            { value = "export", text = ChoiceText("export") } }, IsChosen, Choose, "import and export choice")
    end)
    function frame.ShowChoice()
        choiceButton:SetText(ChoiceText(choice))
    end
    choiceButton:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -12)
    frame.choiceButton = choiceButton
    frame.Choice = function() return choice end

    local importButton = ns.CreateButton(frame, L["Import"], 120, function()
        ns.Share.Import(frame.Pasted() or frame.edit:GetText())
        frame.Refresh()
    end)
    importButton:SetPoint("LEFT", choiceButton, "RIGHT", 12, 0)
    frame.importButton = importButton

    -- The text area's frame: a dark field with a border, so it reads as a place to paste into.
    local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    box:SetPoint("TOPLEFT", choiceButton, "BOTTOMLEFT", 0, -10)
    box:SetSize(570, 310)
    if box.SetBackdrop then
        box:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        box:SetBackdropColor(0, 0, 0, 0.6)
        box:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end
    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetMaxLetters(0) -- no limit: an export is up to Share.EXPORT_LIMIT (V78, see ShareTransfer.lua)
    edit:SetWidth(520)
    -- A multi-line edit box is only as tall as its text: an empty one leaves nothing to click into, so a click anywhere
    -- in the scroll area focuses it.
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)
    -- On Export the area is read-only: typing restores the string.
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput and choice == "export" then
            self:SetText(self.text or "")
            self:HighlightText()
        end
    end)
    edit:SetScript("OnEditFocusGained", function(self)
        if choice == "export" then
            self:HighlightText()
        end
    end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- A paste on Import: OnChar runs for every pasted character, also those over the box's byte limit; they are
    -- collected and joined on the next frame, so the box lays out only PREVIEW_BYTES.
    -- OnChar runs for each pasted character, also past SetMaxBytes (V80, seen in game 2026-11-26: a 138 KB paste in
    -- about half a second, every record imported).
    local buffer, count, collecting = {}, 0, false
    edit:SetScript("OnChar", function(_, char)
        if choice ~= "import" then
            return
        end
        if not collecting then
            collecting, buffer, count = true, {}, 0
        end
        count = count + 1
        buffer[count] = char
    end)
    edit:SetScript("OnUpdate", function()
        if collecting then
            collecting = false
            frame.pasted = table.concat(buffer, "", 1, count)
            buffer = {}
            frame.clearedSeq = ns.Share.TransferState().resultSeq -- a new paste: the last result is not its answer
        end
    end)
    -- The text to import: the whole paste while the box still shows its start, else what the box holds (typed).
    function frame.Pasted()
        local pasted, shown = frame.pasted, edit:GetText()
        if pasted and shown ~= "" and pasted:sub(1, #shown) == shown then
            return pasted
        end
    end
    scroll:SetScrollChild(edit)
    frame.edit = edit

    local hint = ns.CreateText(frame, "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -10)
    hint:SetWidth(560)
    frame.hint = hint

    function frame.Refresh()
        local state = ns.Share.TransferState()
        local text = Hint(state)
        if hint:GetText() ~= text then
            hint:SetText(text)
        end
        importButton:SetEnabled(state.state == "idle")
        local export = state.export
        if choice == "export" and frame.exportPending and state.state == "idle" then
            frame.exportPending = not ns.Share.Export()
            return
        end
        local ready = state.state == "idle" and export and export.text and not frame.exportPending
        if choice == "export" and ready and frame.shownExport ~= export.text then
            frame.shownExport = export.text
            edit.text = export.text
            edit:SetText(export.text)
            edit:SetCursorPosition(0)
            edit:SetFocus()
            edit:HighlightText()
        end
    end

    -- The first show, or one a command asked for, sets the choice up; coming back from another settings page keeps
    -- what the area holds (a pasted string not imported yet).
    frame:SetScript("OnShow", function()
        if not frame.ready or frame.requested then
            frame.ready, frame.requested = true, nil
            Show(choice)
        else
            frame.Refresh()
            frame.edit:SetFocus()
        end
    end)
    -- The transfer's state is polled ten times a second while the page is shown.
    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + (delta or 0)
        if elapsed >= 0.1 then
            elapsed = 0
            frame.Refresh()
        end
    end)
    return frame
end

ns.RegisterEvent("PLAYER_LOGIN", function()
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
        return
    end
    -- Registered after the addon's own pages and its add-on category: the page shows under OneKeyFishing in the
    -- panel's list (seen in game 2026-11-25, the author's screenshot).
    opener = ns.SettingsUI.AddPage(CreatePage(), L["Import and export"])
    ns.SettingsUI.transferOpener = function(value)
        -- In a fight the settings do not open: the page keeps its choice and what it holds (opener prints why).
        if InCombatLockdown() then
            opener()
            return
        end
        choice = value == "export" and "export" or "import"
        if page:IsShown() then
            Show(choice)
        else
            page.requested = true
        end
        opener()
    end
end)
