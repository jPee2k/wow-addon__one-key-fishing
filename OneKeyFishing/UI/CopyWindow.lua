-- CopyWindow: a movable window with read-only, selectable text (Ctrl+A, Ctrl+C).
local _, ns = ...
local L = ns.L

local WINDOW_NAME = "OneKeyFishingCopyWindow"

local window

local function CreateWindow()
    -- BasicFrameTemplateWithInset gives a title bar and close button; fall back to a plain backdrop (ns.SetupWindow
    -- adds the close button it lacks).
    local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    if not ok then
        frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
    end
    frame:SetSize(680, 500)
    frame:SetPoint("CENTER")
    ns.SetupWindow(frame, WINDOW_NAME)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -6)

    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.hint:SetPoint("BOTTOMLEFT", 14, 10)
    frame.hint:SetText(L["Click the text, then Ctrl+A and Ctrl+C to copy."])

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -32)
    scroll:SetPoint("BOTTOMRIGHT", -34, 28)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(scroll:GetWidth() > 0 and scroll:GetWidth() or 620)
    edit:SetScript("OnEscapePressed", function() frame:Hide() end)
    -- Read-only: undo any typing by restoring the original text.
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(frame.text or "")
        end
    end)
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    scroll:SetScrollChild(edit)
    scroll:SetScript("OnSizeChanged", function(_, width) edit:SetWidth(width) end)

    frame.edit = edit
    return frame
end

function ns.ShowCopyWindow(title, text)
    window = window or CreateWindow()
    window.text = text
    window.title:SetText(title)
    window.edit:SetText(text)
    window.edit:SetCursorPosition(0)
    window:Show()
    window:Raise() -- above the addon's other window, also when it was already shown
end

-- The debug report (Core/Debug.lua) in the copy window: the /okf debug command, the minimap menu and the settings
-- page all show it this way.
function ns.ShowDebugReport()
    ns.ShowCopyWindow(ns.Debug.Report())
end
