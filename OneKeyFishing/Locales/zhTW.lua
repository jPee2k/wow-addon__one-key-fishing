-- Traditional Chinese translation. Keys are the English texts of Locales/enUS.lua.
local _, ns = ...

ns.AddTranslation("zhTW", "繁體中文", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "釣魚動作（拋竿 / 收竿）"
    L["Toggle fishing mode"] = "切換釣魚模式"
    L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] =
        "你的存檔資料來自較新版本的 OneKeyFishing。請更新插件以避免問題。"
    L["v%s commands:"] = "v%s 指令："

    -- Gear.lua
    L["Fishing pole set."] = "已設定魚竿。"
    L["This item cannot be used as fishing gear."] = "此物品無法作為釣魚裝備。"
    L["Already in the list."] = "已在清單中。"
    L["Added."] = "已加入。"
    L["Fishing pole: automatic (best in bags)."] = "魚竿：自動（背包中最好的）。"
    L["Removed from fishing gear."] = "已從釣魚裝備中移除。"
    L["No fishing pole found in your bags."] = "背包中找不到魚竿。"
    L["%d fishing item(s) are not in your bags."] = "有 %d 件釣魚裝備不在背包中。"
    L["No free bag space to take off %s."] = "背包沒有空位，無法卸下%s。"
    L["an item"] = "一件物品"

    -- Bags.lua
    L["Cannot apply %s, skipping it until fishing mode is turned on again."] =
        "無法使用%s，在再次開啟釣魚模式前將略過它。"
    L["Not enough bag space to loot %s. It will be opened again when you free a bag slot."] =
        "背包空間不足，無法拾取%s。騰出背包空位後會再次開啟。"
    L["Cannot open %s, skipping it for this session."] = "無法開啟%s，本次遊戲中將略過它。"

    -- Action.lua
    L["You have not learned Fishing."] = "你尚未學會釣魚。"
    L["No key is bound to 'Fishing action'. Bind one in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
        "「釣魚動作」尚未綁定按鍵。請在 選項 -> 按鍵設定 -> 插件 -> OneKeyFishing 中設定。"

    -- Mode.lua
    L["Cannot enter fishing mode in combat."] = "戰鬥中無法進入釣魚模式。"
    L["Fishing mode %s."] = "釣魚模式%s。"
    L["ON"] = "已開啟"
    L["OFF"] = "已關閉"
    L["Restored game settings from an unfinished fishing session."] = "已從上次未正常結束的釣魚中還原遊戲設定。"
    L["Fishing mode is off. Press your 'Toggle fishing mode' key first."] = "釣魚模式未開啟。請先按「切換釣魚模式」鍵。"
    L["The fishing key is paused in combat."] = "釣魚鍵在戰鬥中暫停使用。"
    L["Leaving fishing mode after combat."] = "戰鬥結束後將離開釣魚模式。"
    L["enter or leave fishing mode"] = "進入或離開釣魚模式"

    -- Auction.lua
    L["Scanning %d/%d"] = "掃描中 %d/%d"
    L["Scan fish prices"] = "掃描魚價"
    L["Auction scan finished: %d of %d price(s) found."] = "拍賣掃描完成：找到 %d / %d 個價格。"
    L["Open the auction house first."] = "請先開啟拍賣場。"
    L["Nothing to scan yet: catch some fish first."] = "還沒有可掃描的物品：請先釣些魚。"
    L["Scanning auction prices of %d item(s)..."] = "正在掃描 %d 件物品的拍賣價格……"
    L["Auction scan stopped: %d of %d price(s) found."] = "拍賣掃描已停止：找到 %d / %d 個價格。"
    L["scan auction prices of caught items (auction house must be open)"] = "掃描漁獲的拍賣價格（需開啟拍賣場）"

    -- Skill.lua
    L["Apprentice"] = "學徒"
    L["Journeyman"] = "熟手"
    L["Expert"] = "專家"
    L["Artisan"] = "工匠"
    L["a fishing trainer"] = "釣魚訓練師"
    L["the book \"Expert Fishing - The Bass and You\" (Old Man Heming, Booty Bay)"] =
        "書籍《Expert Fishing - The Bass and You》（Old Man Heming，藏寶海灣）"
    L["the quest from Nat Pagle (Dustwallow Marsh)"] = "納特·帕格的任務（塵泥沼澤）"
    L["Fishing skill capped (%d/%d): learn %s Fishing from %s."] =
        "釣魚技能已達上限（%d/%d）：請學習%s釣魚，來源：%s。"
    L["Fishing %d/%d: %d point(s) left in this rank. Next: %s Fishing from %s."] =
        "釣魚 %d/%d：此等級還剩 %d 點。下一級：%s釣魚，來源：%s。"

    -- UI/CopyWindow.lua
    L["Click the text, then Ctrl+A and Ctrl+C to copy."] = "點擊文字，然後按 Ctrl+A 和 Ctrl+C 複製。"

    -- UI/Indicator.lua
    L["Cast"] = "拋竿"
    L["Hook!"] = "收竿！"
    L["Apply lure"] = "上魚餌"
    L["Open"] = "開啟"
    L["No bobber"] = "沒有浮標"
    L["Drag to move. Lock it in the settings."] = "拖曳以移動。可在設定中鎖定。"

    -- UI/Toast.lua
    L["Caught: %s"] = "釣到：%s"
    L["Nothing caught"] = "什麼都沒釣到"

    -- UI/StatsFrame.lua
    L["Time fishing"] = "釣魚時間"
    L["Time casting"] = "拋竿時間"
    L["Casts"] = "拋竿次數"
    L["Catches"] = "漁獲"
    L["Catches per hour"] = "每小時漁獲"
    L["Value"] = "價值"
    L["Gold per hour"] = "每小時金幣"
    L["OneKeyFishing - Statistics"] = "OneKeyFishing - 統計"
    L["Session"] = "本次"
    L["This zone"] = "此區域"
    L["All time"] = "全部"
    L["Top catches (all time)"] = "最多漁獲（全部）"
    L["Zones (all time)"] = "區域（全部）"
    L["Reset session"] = "重置本次"
    L["Reset the fishing statistics of this session?"] = "要重置本次的釣魚統計嗎？"
    L["Reset all"] = "全部重置"
    L["Delete ALL fishing statistics of this character?"] = "要刪除此角色的所有釣魚統計嗎？"
    L["Scan auction prices"] = "掃描拍賣價格"
    L["Fishing skill: %d/%d %s%s"] = "釣魚技能：%d/%d %s%s"
    L["(+%d this session)"] = "（本次 +%d）"
    L["Fishing is not learned."] = "尚未學會釣魚。"
    L["Values: higher of vendor and auction price (scanned %s)"] = "價值：取商人價與拍賣價較高者（掃描於 %s）"
    L["%dm"] = "%d分"
    L["%dh %02dm"] = "%d小時%02d分"
    L["Values: vendor price (scan the auction house for market prices)"] = "價值：商人價（掃描拍賣場以取得市場價格）"
    L["%d catches, %s"] = "%d 次漁獲，%s"
    L["No catches yet."] = "尚無漁獲。"
    L["show the fishing statistics"] = "顯示釣魚統計"
    L["Time"] = "時間"
    L["Results"] = "成果"
    L["Money"] = "金錢"
    L["Refresh"] = "重新整理"
    L["Time in fishing mode. Paused while AFK if that option is on."] = "釣魚模式中的時間。若開啟該選項，暫離時會暫停計時。"
    L["Time with the bobber in the water."] = "浮標在水中的時間。"
    L["Fishing casts made in fishing mode."] = "在釣魚模式中的拋竿次數。"
    L["Casts that brought loot."] = "有收穫的拋竿。"
    L["Casts that ended without loot."] = "沒有收穫的拋竿。"
    L["Catches per hour of fishing time. Updated with every cast and with Refresh."] =
        "每小時釣魚時間的漁獲數。每次拋竿及按下重新整理時更新。"
    L["Items caught, at the higher of the vendor price and the last scanned auction price."] =
        "釣到的物品價值，取商人價與最近一次掃描的拍賣價較高者。"
    L["Value per hour of fishing time. Updated with every cast and with Refresh."] =
        "每小時釣魚時間的價值。每次拋竿及按下重新整理時更新。"

    -- Debug.lua
    L["OneKeyFishing - debug report"] = "OneKeyFishing - 除錯報告"
    L["show a report to copy into a bug report"] = "顯示可複製到錯誤回報中的報告"

    -- UI/Settings.lua
    L["Auto loot while fishing"] = "釣魚時自動拾取"
    L["Show the interact icon over the bobber"] = "在浮標上顯示互動圖示"
    L["Leave fishing mode when attacked"] = "受到攻擊時離開釣魚模式"
    L["Equip fishing pole and fishing gear"] = "裝備魚竿與釣魚裝備"
    L["Apply lures automatically"] = "自動上魚餌"
    L["Open clams and fished containers"] = "開啟蚌殼與釣到的容器"
    L["Show the action indicator and cast timer"] = "顯示動作提示與拋竿計時"
    L["Lock the indicator position"] = "鎖定提示位置"
    L["Show catch notifications"] = "顯示漁獲通知"
    L["Show session fishing time under the indicator"] = "在提示下方顯示本次釣魚時間"
    L["Pause the fishing timer while AFK"] = "暫離時暫停釣魚計時"
    L["Warn when the Fishing rank is capped"] = "釣魚等級達上限時提醒"
    L["Use scanned auction prices for catch value"] = "以掃描到的拍賣價格計算漁獲價值"
    L["Zoom the camera while fishing"] = "釣魚時拉近鏡頭"
    L["Show the minimap button"] = "顯示小地圖按鈕"
    L["not bound"] = "未綁定"
    L["Keys"] = "按鍵"
    L["Change them in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
        "可在 選項 -> 按鍵設定 -> 插件 -> OneKeyFishing 中更改。"
    L["WoW names punctuation keys (' ; [ , .) by keyboard language: bind them in both slots, once per language."] =
        "魔獸世界依鍵盤語言命名標點按鍵 (' ; [ , .)：請使用兩個綁定欄位，每種語言各綁定一次。"
    L["Features"] = "功能"
    L["Auto loot, bobber icon and gear changes apply the next time you enter fishing mode."] =
        "自動拾取、浮標圖示與裝備變更會在下次進入釣魚模式時生效。"
    L["Camera distance while fishing:"] = "釣魚時的鏡頭距離："
    L["Actions"] = "操作"
    L["Debug report"] = "除錯報告"
    L["Open statistics"] = "開啟統計"
    L["Reset indicator position"] = "重置提示位置"
    L["(open the auction house first)"] = "（請先開啟拍賣場）"
    L["Fishing action: %s      Toggle fishing mode: %s"] = "釣魚動作：%s      切換釣魚模式：%s"
    L["Remove"] = "移除"
    L["Fishing gear"] = "釣魚裝備"
    L["Fishing pole"] = "魚竿"
    L["Use the best pole automatically"] = "自動使用最好的魚竿"
    L["Add an item"] = "加入物品"
    L["Easiest: close this window and Alt+Click an item in your bags or on the character panel."] =
        "最簡單的方法：關閉此視窗，然後在背包或角色視窗中 Alt+點擊物品。"
    L["Alt+Click it again to remove it. A fishing pole becomes your chosen pole."] =
        "再次 Alt+點擊即可移除。魚竿會成為你指定的魚竿。"
    L["Here you can type an item name, or find all items with a fishing bonus automatically."] =
        "你可以在此輸入物品名稱，或自動尋找所有具有釣魚加成的物品。"
    L["Item not found. Check the name, or Alt+Click the item in your bags."] =
        "找不到物品。請檢查名稱，或在背包中 Alt+點擊該物品。"
    L["Add"] = "加入"
    L["Find fishing items"] = "尋找釣魚物品"
    L["Added %d item(s)."] = "已加入 %d 件物品。"
    L["No new items with a fishing bonus found."] = "沒有找到新的釣魚加成物品。"
    L["Extra fishing gear"] = "額外釣魚裝備"
    L["No items yet."] = "尚無物品。"
    L["Chosen: %s (+%d)"] = "已指定：%s (+%d)"
    L["Automatic, best in your bags: %s (+%d)"] = "自動，背包中最好的：%s (+%d)"
    L["Automatic: no fishing pole in your bags."] = "自動：背包中沒有魚竿。"
    L["Settings cannot be opened in combat."] = "戰鬥中無法開啟設定。"
    L["Settings panel is not available in this client."] = "此用戶端無法使用設定面板。"
    L["open the settings"] = "開啟設定"
    L["Language:"] = "語言："
    L["Interface language"] = "介面語言"
    L["Game client language"] = "遊戲用戶端語言"
    L["Korean and Chinese may show as squares on a game client in another language."] =
        "在其他語言的遊戲用戶端上，韓文與中文可能會顯示為方塊。"
    L["Pick English to get a readable interface back."] = "選擇 English 即可恢復可讀的介面。"
    L["The language changes after reloading the interface."] = "重新載入介面後才會變更語言。"
    L["Reload now"] = "立即重新載入"
    L["Later"] = "稍後"

    -- UI/ItemHooks.lua
    L["OneKeyFishing: fishing gear (Alt+Click to remove)"] = "OneKeyFishing：釣魚裝備（Alt+點擊移除）"
    L["OneKeyFishing: Alt+Click to add to fishing gear"] = "OneKeyFishing：Alt+點擊加入釣魚裝備"

    -- UI/Minimap.lua
    L["Leave fishing mode"] = "離開釣魚模式"
    L["Enter fishing mode"] = "進入釣魚模式"
    L["Statistics"] = "統計"
    L["Settings"] = "設定"
    L["Fishing mode: %s"] = "釣魚模式：%s"
    L["Fishing skill: %d/%d %s"] = "釣魚技能：%d/%d %s"
    L["Session: %d catches, %s"] = "本次：%d 次漁獲，%s"
    L["Fishing key:"] = "釣魚鍵："
    L["Toggle mode key:"] = "切換模式鍵："
    L["How to use: press the toggle key, then the fishing key to cast,"] = "使用方法：按下切換鍵，再按釣魚鍵拋竿，"
    L["and the same key again when the bobber splashes."] = "浮標濺起水花時再按同一個鍵。"
    L["Alt+Click items in your bags to add fishing gear."] = "在背包中 Alt+點擊物品即可加入釣魚裝備。"
    L["Left-click: toggle fishing mode"] = "左鍵：切換釣魚模式"
    L["Shift+Left-click: statistics"] = "Shift+左鍵：統計"
    L["Right-click: menu"] = "右鍵：選單"
    L["Drag: move this button"] = "拖曳：移動此按鈕"
end)
