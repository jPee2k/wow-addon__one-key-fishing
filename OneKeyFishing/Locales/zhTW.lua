-- Traditional Chinese translation. Keys are the English texts of Locales/enUS.lua.
local _, ns = ...

ns.AddTranslation("zhTW", "繁體中文", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "釣魚動作（拋竿 / 收竿）"
    L["Toggle fishing mode"] = "切換釣魚模式"
    L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] =
        "你的存檔資料來自較新版本的 OneKeyFishing。請更新插件以避免問題。"

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

    -- Auction.lua
    L["Scanning %d/%d"] = "掃描中 %d/%d"
    L["Scan fish prices"] = "掃描魚價"
    L["Auction scan finished: %d of %d price(s) found."] = "拍賣掃描完成：找到 %d / %d 個價格。"
    L["Open the auction house first."] = "請先開啟拍賣場。"
    L["Nothing to scan yet: catch some fish first."] = "還沒有可掃描的物品：請先釣些魚。"
    L["Scanning auction prices of %d item(s)..."] = "正在掃描 %d 件物品的拍賣價格……"
    L["Auction scan stopped: %d of %d price(s) found."] = "拍賣掃描已停止：找到 %d / %d 個價格。"

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
    L["Items caught, at the higher of vendor and auction price; with few lots listed, the vendor price."] =
        "釣到的物品價值，取商人價與拍賣價較高者；掛單少時用商人價。"
    L["Value per hour of fishing time. Updated with every cast and with Refresh."] =
        "每小時釣魚時間的價值。每次拋竿及按下重新整理時更新。"

    -- UI/CatchHere.lua and the tabs of UI/StatsFrame.lua
    L["Statistics"] = "統計"
    L["What can be caught here"] = "這裡能釣到什麼"
    L["Skill: %s"] = "技能：%s"
    L["All skill levels"] = "所有技能等級"
    L["Source: %s"] = "來源：%s"
    L["All"] = "全部"
    L["Only mine"] = "僅限我的"
    L["%d catches"] = "%d 次漁獲"
    L["Nothing caught: %s"] = "什麼都沒釣到：%s"
    L["Numbers for the whole map: few catches at this spot."] = "整張地圖的數據：此處漁獲太少。"
    L["Little data"] = "資料不足"
    L["Nothing has been caught here yet."] = "這裡還沒有釣到過東西。"
    L["Try \"All skill levels\": little data for your skill."] = "試試「所有技能等級」：你的技能等級資料不足。"
    L["and %d more"] = "還有 %d 項"
    L["No bundled data in this version: only your own catches are shown."] = "此版本沒有內建資料：只顯示你自己的漁獲。"
    L["The game does not show this place on the map."] = "遊戲沒有在地圖上顯示這個地方。"
    L["Item"] = "物品"
    L["Chance"] = "機率"
    L["Per catch"] = "每次"
    L["Price"] = "價格"


    -- Prices (the few-lots mark in both tabs)
    L["few lots"] = "掛單少"
    L["Auction price: %s (few lots)"] = "拍賣價格：%s（掛單少）"

    -- Debug.lua
    L["OneKeyFishing - debug report"] = "OneKeyFishing - 除錯報告"

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

    -- Share.lua
    L["OneKeyFishing now shares your catches under a random ID with your guild, group and friends who use it."] =
        "OneKeyFishing 現在會以隨機 ID 與使用本插件的公會成員、隊友和好友分享你的漁獲。"
    L["No character names are sent, but the players you exchange with can tell which ID is yours."] =
        "不會傳送角色名稱，但與你交換資料的玩家可以知道哪個 ID 是你的。"
    L["Turn it off in Options -> AddOns -> OneKeyFishing -> Shared database."] =
        "可在 選項 -> 插件 -> OneKeyFishing -> 共享資料庫 中關閉。"
    L["Got it"] = "知道了"
    L["Shared database"] = "共享資料庫"
    L["Shared catch database is off"] = "共享漁獲資料庫已關閉"
    L["Waiting for you to read the notice"] = "等待你閱讀說明"
    L["Exchange unavailable: the game refuses addon messages"] = "無法交換：遊戲拒絕插件訊息"
    L["Exchange paused: in combat"] = "交換已暫停：戰鬥中"
    L["Exchange paused: in an instance"] = "交換已暫停：在副本中"
    L["Exchange paused: loading screen"] = "交換已暫停：載入畫面"
    L["Exchange paused: the game restricts addon messages here"] = "交換已暫停：遊戲在此限制插件訊息"
    L["Exchange paused: the game asked to slow down"] = "交換已暫停：遊戲要求放慢速度"
    L["Nobody to exchange with right now"] = "目前沒有可交換的對象"
    L["Exchange: %d players, %s ago"] = "交換：%d 名玩家，%s前"
    L["Exchange: waiting for the first exchange"] = "交換：等待第一次交換"
    L["Bundled data: version %d, %d places"] = "內建資料：版本 %d，%d 個地點"
    L["Records held: %d, %d places"] = "保存的紀錄：%d 筆，%d 個地點"
    L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d"] =
        "過去一小時聽到的玩家：公會 %d，隊伍 %d，好友 %d，Battle.net %d"
    L["Players exchanged with in the last hour: %d"] = "過去一小時交換過的玩家：%d"
    L["Last exchange: %s ago"] = "上次交換：%s前"
    L["Last exchange: none yet"] = "上次交換：尚無"
    L["Traffic in the last hour: %d KB"] = "過去一小時流量：%d KB"

    -- UI/Settings.lua: the Shared database page
    L["Use the shared catch database"] = "使用共享漁獲資料庫"
    L["Your catches (items, counts, map cells, the average spot you fish from) are shared under a random ID."] =
        "你的漁獲（物品、數量、地圖格子、你釣魚的平均位置）會以隨機 ID 分享。"
    L["They go to addon users in your guild, group and friends list. No names or gear."] =
        "資料會傳給你的公會、隊伍和好友名單中的插件使用者。不含名稱或裝備。"
    L["The players you exchange with can tell which ID is yours."] = "與你交換資料的玩家可以知道哪個 ID 是你的。"
    L["Turned off: nothing is sent or received, and other players' data is not counted."] =
        "關閉時：不傳送也不接收任何資料，其他玩家的資料也不計入。"

    -- UI/CatchHere.lua: other players' catches
    L["%d catches from %d players"] = "%d 次漁獲，來自 %d 名玩家"

    -- UI/CatchHere.lua: items the game client does not know yet (part 3)
    L["Unknown item"] = "未知物品"
    L["The game has not shown this item yet."] = "遊戲尚未顯示此物品。"
    L["Reported by %d players on this map"] = "此地圖上有 %d 名玩家回報"
    L["In the bundled data"] = "在內建資料中"
    L["Item ID: %d"] = "物品 ID：%d"

    -- Channel.lua: the hidden public channel (part 3)
    L["OneKeyFishing left its hidden channel to free a chat channel slot. Try joining again."] =
        "OneKeyFishing 已離開其隱藏頻道，以空出一個聊天頻道位置。請再試一次。"

    -- UI/Settings.lua: the public channel (part 3)
    L["Use the public channel"] = "使用公開頻道"
    L["With the public channel on, they also go to every other addon user, through a hidden chat channel."] =
        "開啟公開頻道後，資料也會透過隱藏的聊天頻道傳給其他所有插件使用者。"
    L["Anyone who joins that channel by its name can see which characters in it use the addon."] =
        "任何以名稱加入該頻道的人，都能看到頻道中哪些角色使用本插件。"

    -- Share.lua: the public channel (part 3)
    L["OneKeyFishing now shares your catches under a random ID with other players who use it."] =
        "OneKeyFishing 現在會以隨機 ID 與其他使用本插件的玩家分享你的漁獲。"
    L["It reaches your guild, group and friends, and anyone else through a hidden chat channel."] =
        "資料會傳給你的公會、隊伍和好友，也會透過隱藏的聊天頻道傳給其他任何人。"
    L["Public channel: in use"] = "公開頻道：使用中"
    L["Public channel: in use (fallback channel %d)"] = "公開頻道：使用中（備用頻道 %d）"
    L["Public channel: off"] = "公開頻道：關閉"
    L["Public channel: no free chat channel slot"] = "公開頻道：沒有空的聊天頻道位置"
    L["Public channel: locked or refused by the game"] = "公開頻道：已鎖定或遭遊戲拒絕"
    L["Public channel: you left it, back at the next login"] = "公開頻道：你已離開，下次登入時會再加入"
    L["Public channel: waiting"] = "公開頻道：等待中"
    L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d, channel %d"] =
        "過去一小時聽到的玩家：公會 %d，隊伍 %d，好友 %d，Battle.net %d，頻道 %d"

    -- Catalog.lua: the catch catalog (part 4)
    L["Unknown zone (%d)"] = "未知區域 (%d)"

    -- Catalog.lua: spots
    L["%s (%s)"] = "%s（%s）"
    L["No exact spot"] = "無確切地點"

    -- UI/CatalogTab.lua, UI/StatsFrame.lua, UI/CatchHere.lua: the catch catalog (part 4)
    L["Catch catalog"] = "漁獲目錄"
    L["Search by item name"] = "依物品名稱搜尋"
    L["Zones: %d"] = "區域：%d"
    L["Back"] = "返回"
    L["Place"] = "地點"
    L["Skill"] = "技能"
    L["Counting the catch..."] = "正在統計漁獲..."
    L["Nothing has been caught yet."] = "尚未釣到任何東西。"
    L["The catalog fills with your catches, the bundled data and, with sharing on, other players' catches."] =
        "目錄會收錄你的漁獲、內建資料，以及開啟分享時其他玩家的漁獲。"
    L["You have not caught anything yet."] = "你尚未釣到任何東西。"
    L["No item matches the search."] = "沒有符合搜尋的物品。"
    L["No data for this item under these filters."] = "在這些篩選條件下沒有此物品的資料。"
    L["Click an item to see where else it is caught."] = "點擊物品以查看還能在哪裡釣到。"

    -- UI/CatalogTab.lua: the map pin (part 4)
    L["Pin"] = "標記"
    L["Set a map pin here"] = "在此設置地圖標記"
    L["Replace your map pin with this place?"] = "要以此地點取代你的地圖標記嗎？"
    L["Replace"] = "取代"
    L["Cancel"] = "取消"
    L["Map pin: %s"] = "地圖標記：%s"
    L["The game did not accept the map pin."] = "遊戲不接受此地圖標記。"

    -- Catalog.lua, UI/ItemHooks.lua, UI/Minimap.lua, UI/Settings.lua: catch chances in tooltips (part 4)
    L["%s (%d players)"] = "%s（%d 名玩家）"
    L["Caught in:"] = "釣獲地點："
    L["Likely catch here:"] = "此處可能釣到："
    L["Show catch chances in tooltips"] = "在滑鼠提示中顯示釣獲機率"

    -- UI/CatchHere.lua, UI/CatalogTab.lua: the Water filter (part 4)
    L["Water: %s"] = "水域：%s"
    L["Everywhere"] = "所有地方"
    L["Open water"] = "開放水域"
    L["Pools"] = "魚群"
end)
