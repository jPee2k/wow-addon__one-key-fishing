-- English strings, the base locale. Keys are the English text itself and every entry is `true`
-- ("use the key"); a missing entry also falls back to its key, so the addon never shows a blank.
-- A translation goes into Locales/<locale>.lua (loaded after this file) and sets L[english] = translation
-- only when GetLocale() matches. `npm run check` keeps this list in sync with the code.
local _, ns = ...

-- The strings live in a separate table so every assignment goes through __newindex.
local strings = {}
local L = setmetatable({}, {
    __index = function(_, key)
        return strings[key] or key
    end,
    __newindex = function(_, key, value)
        strings[key] = value == true and key or value
    end,
})
ns.L = L

-- Core.lua
L["Fishing action (cast / hook)"] = true
L["Toggle fishing mode"] = true
L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] = true
L["v%s commands:"] = true

-- Gear.lua
L["Fishing pole set."] = true
L["This item cannot be used as fishing gear."] = true
L["Already in the list."] = true
L["Added."] = true
L["Fishing pole: automatic (best in bags)."] = true
L["Removed from fishing gear."] = true
L["No fishing pole found in your bags."] = true
L["%d fishing item(s) are not in your bags."] = true
L["No free bag space to take off %s."] = true
L["an item"] = true

-- Bags.lua
L["Cannot apply %s, skipping it for this session."] = true
L["Not enough bag space to loot %s. It will be opened again when you free a bag slot."] = true
L["Cannot open %s, skipping it for this session."] = true

-- Action.lua
L["You have not learned Fishing."] = true
L["No key is bound to 'Fishing action'. Bind one in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
    true

-- Mode.lua
L["Cannot enter fishing mode in combat."] = true
L["Fishing mode %s."] = true
L["ON"] = true
L["OFF"] = true
L["Restored game settings from an unfinished fishing session."] = true
L["Fishing mode is off. Press your 'Toggle fishing mode' key first."] = true
L["The fishing key is paused in combat."] = true
L["Leaving fishing mode after combat."] = true
L["enter or leave fishing mode"] = true

-- Auction.lua
L["Scanning %d/%d"] = true
L["Scan fish prices"] = true
L["Auction scan finished: %d of %d price(s) found."] = true
L["Open the auction house first."] = true
L["Nothing to scan yet: catch some fish first."] = true
L["Scanning auction prices of %d item(s)..."] = true
L["Auction scan stopped: %d of %d price(s) found."] = true
L["scan auction prices of caught items (auction house must be open)"] = true

-- Skill.lua
L["Apprentice"] = true
L["Journeyman"] = true
L["Expert"] = true
L["Artisan"] = true
L["a fishing trainer"] = true
L["the book \"Expert Fishing - The Bass and You\" (Old Man Heming, Booty Bay)"] = true
L["the quest from Nat Pagle (Dustwallow Marsh)"] = true
L["Fishing skill capped (%d/%d): learn %s Fishing from %s."] = true
L["Fishing %d/%d: %d point(s) left in this rank. Next: %s Fishing from %s."] = true

-- UI/CopyWindow.lua
L["Click the text, then Ctrl+A and Ctrl+C to copy."] = true

-- UI/Indicator.lua
L["Cast"] = true
L["Hook!"] = true
L["Apply lure"] = true
L["Open"] = true
L["No bobber"] = true
L["Drag to move. Lock it in the settings."] = true

-- UI/Toast.lua
L["Caught: %s"] = true
L["Nothing caught"] = true

-- UI/StatsFrame.lua
L["Time fishing"] = true
L["Time casting"] = true
L["Casts"] = true
L["Catches"] = true
L["Catches per hour"] = true
L["Value"] = true
L["Gold per hour"] = true
L["OneKeyFishing - Statistics"] = true
L["Session"] = true
L["This zone"] = true
L["All time"] = true
L["Top catches (all time)"] = true
L["Zones (all time)"] = true
L["Reset session"] = true
L["Reset the fishing statistics of this session?"] = true
L["Reset all"] = true
L["Delete ALL fishing statistics of this character?"] = true
L["Scan auction prices"] = true
L["Fishing skill: %d/%d %s%s"] = true
L["(+%d this session)"] = true
L["Fishing is not learned."] = true
L["Values: higher of vendor and auction price (scanned %s)"] = true
L["%dm"] = true
L["%dh %02dm"] = true
L["Values: vendor price (scan the auction house for market prices)"] = true
L["%d catches, %s"] = true
L["No catches yet."] = true
L["show the fishing statistics"] = true
L["Time"] = true
L["Results"] = true
L["Money"] = true
L["Refresh"] = true
L["Time in fishing mode. Paused while AFK if that option is on."] = true
L["Time with the bobber in the water."] = true
L["Fishing casts made in fishing mode."] = true
L["Casts that brought loot."] = true
L["Casts that ended without loot."] = true
L["Catches per hour of fishing time. Updated with every cast and with Refresh."] = true
L["Items caught, at the higher of the vendor price and the last scanned auction price."] = true
L["Value per hour of fishing time. Updated with every cast and with Refresh."] = true

-- Debug.lua
L["OneKeyFishing - debug report"] = true
L["show a report to copy into a bug report"] = true

-- UI/Settings.lua
L["Auto loot while fishing"] = true
L["Show the interact icon over the bobber"] = true
L["Leave fishing mode when attacked"] = true
L["Equip fishing pole and fishing gear"] = true
L["Apply lures automatically"] = true
L["Open clams and fished containers"] = true
L["Show the action indicator and cast timer"] = true
L["Lock the indicator position"] = true
L["Show catch notifications"] = true
L["Show session fishing time under the indicator"] = true
L["Pause the fishing timer while AFK"] = true
L["Warn when the Fishing rank is capped"] = true
L["Use scanned auction prices for catch value"] = true
L["Zoom the camera while fishing"] = true
L["Show the minimap button"] = true
L["not bound"] = true
L["Keys"] = true
L["Change them in Options -> Keybindings -> AddOns -> OneKeyFishing."] = true
L["WoW names punctuation keys (' ; [ , .) by keyboard language: bind them in both slots, once per language."] = true
L["Features"] = true
L["Auto loot, bobber icon and gear changes apply the next time you enter fishing mode."] = true
L["Camera distance while fishing:"] = true
L["Actions"] = true
L["Debug report"] = true
L["Open statistics"] = true
L["Reset indicator position"] = true
L["(open the auction house first)"] = true
L["Fishing action: %s      Toggle fishing mode: %s"] = true
L["Remove"] = true
L["Fishing gear"] = true
L["Fishing pole"] = true
L["Use the best pole automatically"] = true
L["Add an item"] = true
L["Easiest: close this window and Alt+Click an item in your bags or on the character panel."] = true
L["Alt+Click it again to remove it. A fishing pole becomes your chosen pole."] = true
L["Here you can type an item name, or find all items with a fishing bonus automatically."] = true
L["Item not found. Check the name, or Alt+Click the item in your bags."] = true
L["Add"] = true
L["Find fishing items"] = true
L["Added %d item(s)."] = true
L["No new items with a fishing bonus found."] = true
L["Extra fishing gear"] = true
L["No items yet."] = true
L["Chosen: %s (+%d)"] = true
L["Automatic, best in your bags: %s (+%d)"] = true
L["Automatic: no fishing pole in your bags."] = true
L["Settings cannot be opened in combat."] = true
L["Settings panel is not available in this client."] = true
L["open the settings"] = true

-- UI/ItemHooks.lua
L["OneKeyFishing: fishing gear (Alt+Click to remove)"] = true
L["OneKeyFishing: Alt+Click to add to fishing gear"] = true

-- UI/Minimap.lua
L["Leave fishing mode"] = true
L["Enter fishing mode"] = true
L["Statistics"] = true
L["Settings"] = true
L["Fishing mode: %s"] = true
L["Fishing skill: %d/%d %s"] = true
L["Session: %d catches, %s"] = true
L["Fishing key:"] = true
L["Toggle mode key:"] = true
L["How to use: press the toggle key, then the fishing key to cast,"] = true
L["and the same key again when the bobber splashes."] = true
L["Alt+Click items in your bags to add fishing gear."] = true
L["Left-click: toggle fishing mode"] = true
L["Shift+Left-click: statistics"] = true
L["Right-click: menu"] = true
L["Drag: move this button"] = true
