-- ShareNotice: the one-time popup about the catch exchange (Exchange/Share.lua): nothing is exchanged before the
-- player closed it. Share says whether a notice is owed (Share.NoticeOwed) and what closing it means
-- (Share.NoticeRead); the popup, its text and the retries are the view's.
local _, ns = ...
local L = ns.L
local Share = ns.Share

local NOTICE_DELAY = 2 -- seconds after entering the world when no loading screen event comes
local NOTICE_RETRY = 30 -- seconds until the next try when the game had no free dialog frame
local noticeShown, noticeAfterCombat, noticeRetry = false, false, false

local function ShowNotice()
    if not Share.NoticeOwed() or noticeShown or not Share.IsEnabled() then
        return
    end
    if InCombatLockdown() then
        noticeAfterCombat = true
        return
    end
    -- Short sentences, so each key fits a line; while the release has the public channel (part 3), two sentences that
    -- name it take the place of the first.
    local sentences = {
        L["No character names are sent, but the players you exchange with can tell which ID is yours."],
        L["Turn it off in Options -> AddOns -> OneKeyFishing -> Shared database."],
    }
    if ns.Channel.AVAILABLE then
        table.insert(sentences, 1,
            L["OneKeyFishing now shares your catches under a random ID with other players who use it."])
        table.insert(sentences, 2,
            L["It reaches your guild, group and friends, and anyone else through a hidden chat channel."])
    else
        table.insert(sentences, 1,
            L["OneKeyFishing now shares your catches under a random ID with your guild, group and friends who use it."])
    end
    local text = table.concat(sentences, " ")
    local dialog = ns.ShowPopup(Share.NOTICE_POPUP, text, nil, L["Got it"], L["Settings"],
        function() ns.SettingsUI.OpenShare() end,
        function()
            -- Any button or Escape; not the whole interface hidden (Alt+Z, a cinematic), which hides the popup too.
            if UIParent:IsShown() then
                Share.NoticeRead()
            end
        end)
    if dialog then
        noticeShown = true
    elseif not noticeRetry then
        -- Every dialog frame was taken (other addons' prompts at login): the exchange waits for the notice.
        noticeRetry = true
        C_Timer.After(NOTICE_RETRY, function()
            noticeRetry = false
            ShowNotice()
        end)
    end
end

local function ShowNoticeSoon()
    if Share.NoticeOwed() then
        C_Timer.After(NOTICE_DELAY, ShowNotice)
    end
end
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "LOADING_SCREEN_DISABLED" }) do
    ns.RegisterEvent(event, ShowNoticeSoon)
end

ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if noticeAfterCombat then
        noticeAfterCombat = false
        ShowNotice()
    end
end)
