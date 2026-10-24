-- Debug: a read-only report of the addon state for bug reports (/okf debug).
-- The report stays in English on every client so the developer can read it. Each section is wrapped,
-- so one failing call never breaks the whole report.
local _, ns = ...
local L = ns.L

local REPORT_CVARS = { "autoLootDefault", "SoftTargetInteract", "SoftTargetIconGameObject", "SoftTargetIconInteract" }

local function Section(lines, title, fn)
    table.insert(lines, "")
    table.insert(lines, "-- " .. title .. " --")
    local ok, err = pcall(fn)
    if not ok then
        table.insert(lines, ("  !! failed: %s"):format(tostring(err)))
    end
end

local function Keys(binding)
    local keys = { GetBindingKey(binding) }
    return #keys > 0 and table.concat(keys, ", ") or "not bound"
end

local function ItemText(itemID)
    if not itemID then
        return "none"
    end
    local _, link = C_Item.GetItemInfo(itemID)
    return ("%s (%d)"):format(link or "?", itemID)
end

local function BuildReport()
    local lines = {}
    local function add(fmt, ...)
        table.insert(lines, "  " .. (select("#", ...) > 0 and fmt:format(...) or fmt))
    end

    table.insert(lines, ("== OneKeyFishing %s report =="):format(ns.version))
    local version, build, _, interface = GetBuildInfo()
    table.insert(lines, ("Game %s (%s), interface %s, project %s, locale %s"):format(tostring(version),
        tostring(build), tostring(interface), tostring(WOW_PROJECT_ID), GetLocale()))
    table.insert(lines, ("Language: %s (in use: %s)"):format(tostring(ns.db.settings.language),
        tostring(ns.language)))

    Section(lines, "Mode", function()
        add("fishing mode: %s, leaving after combat: %s, channeling: %s, in combat: %s",
            tostring(ns.Mode.IsActive()), tostring(ns.Mode.IsExiting()), tostring(ns.Action.IsChanneling()),
            tostring(InCombatLockdown()))
        add("keys: fishing action [%s], toggle [%s], interact with target [%s]",
            Keys("ONEKEYFISHING_ACTION"), Keys("ONEKEYFISHING_TOGGLE"), Keys("INTERACTTARGET"))
    end)

    Section(lines, "Fishing", function()
        local spellID = ns.GetFishingSpellID()
        add("spell: %s (%s)", tostring(spellID), tostring(spellID and C_Spell.GetSpellName(spellID)))
        local rank, maxRank = ns.Skill.Get()
        add("skill: %s/%s", tostring(rank), tostring(maxRank))
    end)

    Section(lines, "Gear", function()
        local mainHand = GetInventoryItemID("player", INVSLOT_MAINHAND or 16)
        add("main hand: %s, fishing pole: %s, fishing bonus: %s", ItemText(mainHand),
            tostring(ns.IsFishingPole(mainHand)), tostring(mainHand and ns.GetFishingBonus(mainHand)))
        local hasLure, expiration = GetWeaponEnchantInfo()
        add("lure: %s, expires in %s s", tostring(hasLure == true), tostring(expiration and expiration / 1000))
        add("lure setting: %s, needs lure: %s, next lure: %s", tostring(ns.db.settings.lure),
            tostring(ns.Bags.NeedsLure()), tostring(ns.Bags.FindLure()))
        for _, line in ipairs(ns.Bags.DescribeLures()) do
            add("  lure %s", line)
        end
        local best, bonus = ns.Gear.FindBestPole()
        add("best pole: %s (+%s), chosen pole: %s, extra items: %d", ItemText(best), tostring(bonus),
            ItemText(ns.Gear.GetChosenPole()), #ns.Gear.GetItems())
        local swap = ns.charDB.gearSwap
        if not swap then
            add("pending restore: none")
        end
        for slot, entry in pairs(swap or {}) do
            add("pending restore: slot %d %s -> %s%s", slot, tostring(entry.previous), tostring(entry.equipped),
                entry.restoring and " (restoring)" or "")
        end
    end)

    Section(lines, "Fished items in bags", function()
        local items = ns.Bags.Describe()
        if #items == 0 then
            add("none")
        end
        for _, line in ipairs(items) do
            add("%s", line)
        end
    end)

    Section(lines, "Game settings", function()
        for _, name in ipairs(REPORT_CVARS) do
            add("%s = %s", name, tostring(C_CVar.GetCVar(name)))
        end
        add("saved by the addon: CVars %s, camera zoom %s", tostring(ns.charDB.savedCVars ~= nil),
            tostring(ns.charDB.savedCameraZoom))
    end)

    Section(lines, "Addon settings", function()
        local names = {}
        for name in pairs(ns.db.settings) do
            table.insert(names, name)
        end
        table.sort(names)
        for _, name in ipairs(names) do
            add("%s = %s", name, tostring(ns.db.settings[name]))
        end
    end)

    return table.concat(lines, "\n")
end

-- Available in combat too: the report and its window are plain (non-secure) frames, and the combat
-- fields above are only meaningful when the report can be taken during combat.
function ns.ShowReport()
    ns.ShowCopyWindow(L["OneKeyFishing - debug report"], BuildReport())
end

ns.RegisterCommand("debug", function() return L["show a report to copy into a bug report"] end, ns.ShowReport)
