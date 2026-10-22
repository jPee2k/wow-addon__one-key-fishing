-- CopyWindow: a movable window with read-only, selectable text (Ctrl+A, Ctrl+C).
local _, ns = ...

local WINDOW_NAME = "OneKeyFishingCopyWindow"

local window

local function CreateWindow()
    -- BasicFrameTemplateWithInset gives a title bar and close button; fall back to a plain backdrop.
    local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    if not ok then
        frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
    end
    _G[WINDOW_NAME] = frame
    table.insert(UISpecialFrames, WINDOW_NAME) -- close on Escape

    frame:SetSize(680, 500)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -6)

    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.hint:SetPoint("BOTTOMLEFT", 14, 10)
    frame.hint:SetText("Click the text, then Ctrl+A and Ctrl+C to copy.")

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
end
