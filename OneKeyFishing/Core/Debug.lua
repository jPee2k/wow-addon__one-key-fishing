-- Debug: a read-only report of the addon state for bug reports (/okf debug).
-- The report stays in English on every client so the developer can read it. Each section is wrapped,
-- so one failing call never breaks the whole report.
local _, ns = ...
local L = ns.L

local Debug = {}
ns.Debug = Debug

local STAMP = "%Y-%m-%d %H:%M:%S" -- the times of the Errors section

local function Section(lines, title, fn)
    table.insert(lines, "")
    table.insert(lines, "-- " .. title .. " --")
    local ok, err = pcall(fn)
    if not ok then
        table.insert(lines, ("  !! failed: %s"):format(tostring(err)))
    end
end

-- A function result as text. The parentheses keep one value, nil when the call returned nothing: Lua 5.1's
-- tostring() raises an error without an argument (Bags.FindLure ends without a return when no lure is usable).
local function Value(...)
    return tostring((...))
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
    -- Keys looked up while the files loaded stay in English (docs/architecture/core.md): none is the rule.
    table.insert(lines, ("  early L lookups: %s"):format(#ns.earlyLookups > 0 and table.concat(ns.earlyLookups, ", ")
        or "none"))

    Section(lines, "Mode", function()
        add("fishing mode: %s, leaving after combat: %s, channeling: %s, in combat: %s",
            Value(ns.Mode.IsActive()), Value(ns.Mode.IsExiting()), Value(ns.Action.IsChanneling()),
            Value(InCombatLockdown()))
        add("keys: fishing action [%s], toggle [%s], interact with target [%s]",
            Keys("ONEKEYFISHING_ACTION"), Keys("ONEKEYFISHING_TOGGLE"), Keys("INTERACTTARGET"))
    end)

    Section(lines, "Fishing", function()
        local spellID = ns.GetFishingSpellID()
        add("spell: %s (%s)", tostring(spellID), tostring(spellID and C_Spell.GetSpellName(spellID)))
        local rank, maxRank = ns.Skill.Get()
        add("skill: %s/%s, character level: %s", tostring(rank), tostring(maxRank), Value(UnitLevel("player")))
        local advice = ns.Skill.GetNextRank()
        if not advice then
            add("next rank: none")
        else
            add("next rank: %s (%s), state %s, from skill %d and level %d, reminders %s", advice.rank,
                tostring(advice.sources.rank), advice.state, advice.learnAt, advice.level,
                tostring(ns.db.settings.skillCapWarning))
            local names = {}
            for _, key in ipairs({ "item", "quest", "npc", "area", "zone" }) do
                if advice.sources[key] then
                    table.insert(names, key .. " " .. advice.sources[key])
                end
            end
            add("next rank names: %s", #names > 0 and table.concat(names, ", ") or "trainer (no game names)")
            local pin = advice.pin
            add("next rank pin: %s", pin and ("map %d at %.3f, %.3f"):format(pin.mapID, pin.x, pin.y)
                or "none (trainer, no usable map, or pins disabled)")
        end
    end)

    -- The camp bonuses (specs/020-camp-buffs, Fishing/Camp.lua): their state, the restriction, the last cast's mask.
    Section(lines, "Camp bonus", function()
        for _, line in ipairs(ns.Camp.Describe()) do
            add("%s", line)
        end
    end)

    Section(lines, "Gear", function()
        local mainHand = GetInventoryItemID("player", ns.GameData.EquipSlots.mainHand)
        add("main hand: %s, fishing pole: %s, fishing bonus: %s", ItemText(mainHand),
            Value(ns.IsFishingPole(mainHand)), tostring(mainHand and ns.GetFishingBonus(mainHand)))
        local hasLure, expiration = GetWeaponEnchantInfo()
        add("lure: %s, expires in %s s", tostring(hasLure == true), tostring(expiration and expiration / 1000))
        add("lure setting: %s, needs lure: %s, next lure: %s", tostring(ns.db.settings.lure),
            Value(ns.Bags.NeedsLure()), Value(ns.Bags.FindLure()))
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

    -- No anonymous contribution ID here: this report goes into public bug reports.
    Section(lines, "Catch database", function()
        for _, line in ipairs(ns.CatchDB.Describe()) do
            add("%s", line)
        end
    end)

    -- Where the auction prices come from (specs/019-auctionator-prices): the source, Auctionator's two functions,
    -- the own catches by the source of their price, the oldest Auctionator price.
    Section(lines, "Auction prices", function()
        for _, line in ipairs(ns.Prices.Describe()) do
            add("%s", line)
        end
    end)

    -- The auction scan (specs/018-auction-scan): its state, the last scan, the list and the remembered items.
    Section(lines, "Auction scan", function()
        for _, line in ipairs(ns.Auction.Describe()) do
            add("%s", line)
        end
    end)

    -- Counts and times only, never an item name (specs/005-catch-catalog, V39).
    Section(lines, "Catch catalog", function()
        for _, line in ipairs(ns.Catalog.Describe()) do
            add("%s", line)
        end
    end)

    -- The best places (spec 024): each ranking's state and size, the character's choices; never a place's name.
    Section(lines, "Best places", function()
        for _, line in ipairs(ns.BestPlaces.Describe()) do
            add("%s", line)
        end
    end)

    -- The items of the bundled seed that GameData/ItemKinds.lua does not list (a harvest brought them), with their
    -- names and classes, so each gets its kind by ID (spec 014). A release has none (tests/catalog/kinds_test.lua);
    -- after a harvest, a dev build lists them. An item the client does not know yet is asked for, once per report.
    Section(lines, "Seed items without a kind", function()
        local byItem, missing = ns.GameData.ItemKinds.byItem, {}
        local function check(items)
            for itemID in pairs(type(items) == "table" and items or {}) do
                itemID = tonumber(itemID)
                if itemID and not byItem[itemID] then
                    missing[itemID] = true
                end
            end
        end
        for _, cell in pairs(ns.SeedData and ns.SeedData.cells or {}) do
            if type(cell) == "table" then
                check(cell.i)
                if type(cell.p) == "table" then
                    check(cell.p.i) -- the pool part
                end
            end
        end
        local ids = {}
        for itemID in pairs(missing) do
            table.insert(ids, itemID)
        end
        table.sort(ids)
        if #ids == 0 then
            add("none")
        end
        for _, itemID in ipairs(ids) do
            local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
            local name = C_Item.GetItemNameByID(itemID)
            if not name and C_Item.RequestLoadItemDataByID then
                C_Item.RequestLoadItemDataByID(itemID)
            end
            add("%d %s (%s / %s)", itemID, name or "not loaded yet", tostring(classID), tostring(subClassID))
        end
    end)

    -- No anonymous ID and no names: the exchange state in numbers only.
    Section(lines, "Shared database", function()
        for _, line in ipairs(ns.Share.Describe()) do
            add("%s", line)
        end
        for _, line in ipairs(ns.Comm.Describe()) do
            add("%s", line)
        end
        for _, line in ipairs(ns.Channel.Describe()) do
            add("%s", line)
        end
    end)

    Section(lines, "Game settings", function()
        for _, name in ipairs(ns.Mode.CVAR_NAMES) do -- Fishing/Mode.lua
            add("%s = %s", name, Value(C_CVar.GetCVar(name)))
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
            local value = ns.db.settings[name]
            if type(value) == "table" then
                -- A set (hiddenKinds): its keys, sorted, never the table's address.
                local keys = {}
                for key in pairs(value) do
                    table.insert(keys, tostring(key))
                end
                table.sort(keys)
                value = #keys > 0 and ("{ " .. table.concat(keys, ", ") .. " }") or "{}"
            end
            add("%s = %s", name, tostring(value))
        end
    end)

    -- The addon's recent errors (Core.lua, ns.Safe), the newest first; the last section, as README.md says.
    Section(lines, "Errors", function()
        local log = ns.GetErrors()
        if #log == 0 then
            add("none")
        end
        for i = #log, 1, -1 do
            local entry = log[i]
            local when = date(STAMP, entry.first)
            if entry.last ~= entry.first then
                when = when .. " to " .. date(STAMP, entry.last)
            end
            add("%dx %s, %s, %s", entry.count, entry.context, when, entry.version)
            for line in (entry.message .. "\n" .. entry.stack):gmatch("[^\n]+") do
                add("  %s", line)
            end
        end
    end)

    return table.concat(lines, "\n")
end

-- The window title and the report; Commands.lua shows them in the copy window. Available in combat too: the
-- report and its window are plain (non-secure) frames, and the combat fields above are only meaningful when the
-- report can be taken during combat.
function Debug.Report()
    return L["OneKeyFishing - debug report"], BuildReport()
end
