-- Simplified Chinese translation. Keys are the English texts of Locales/enUS.lua.
local _, ns = ...

ns.AddTranslation("zhCN", "简体中文", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "钓鱼动作（抛竿/收竿）"
    L["Toggle fishing mode"] = "切换钓鱼模式"
    L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] =
        "你的存档数据来自更新版本的 OneKeyFishing。请更新插件以免出现问题。"

    -- Gear.lua
    L["Fishing pole set."] = "已设置鱼竿。"
    L["This item cannot be used as fishing gear."] = "该物品不能用作钓鱼装备。"
    L["Already in the list."] = "已在列表中。"
    L["Added."] = "已添加。"
    L["Fishing pole: automatic (best in bags)."] = "鱼竿：自动（背包中最好的）。"
    L["Removed from fishing gear."] = "已从钓鱼装备中移除。"
    L["No fishing pole found in your bags."] = "背包中没有找到鱼竿。"
    L["%d fishing item(s) are not in your bags."] = "有%d件钓鱼装备不在背包中。"
    L["No free bag space to take off %s."] = "背包没有空位，无法卸下%s。"
    L["an item"] = "一件物品"

    -- Bags.lua
    L["Cannot apply %s, skipping it until fishing mode is turned on again."] =
        "无法使用%s，在再次开启钓鱼模式之前将跳过它。"
    L["Not enough bag space to loot %s. It will be opened again when you free a bag slot."] =
        "背包空间不足，无法拾取%s。腾出背包空位后会再次打开它。"
    L["Cannot open %s, skipping it for this session."] = "无法打开%s，本次游戏中将跳过它。"

    -- Action.lua
    L["You have not learned Fishing."] = "你还没有学会钓鱼。"
    L["No key is bound to 'Fishing action'. Bind one in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
        "“钓鱼动作”没有绑定按键。请在 选项 -> 快捷键 -> 插件 -> OneKeyFishing 中绑定。"

    -- Mode.lua
    L["Cannot enter fishing mode in combat."] = "战斗中无法进入钓鱼模式。"
    L["Fishing mode %s."] = "钓鱼模式已%s。"
    L["ON"] = "开启"
    L["OFF"] = "关闭"
    L["Restored game settings from an unfinished fishing session."] = "已恢复上次未正常结束的钓鱼时的游戏设置。"
    L["Fishing mode is off. Press your 'Toggle fishing mode' key first."] = "钓鱼模式未开启。请先按“切换钓鱼模式”键。"
    L["The fishing key is paused in combat."] = "战斗中钓鱼键暂停使用。"
    L["Leaving fishing mode after combat."] = "战斗结束后将退出钓鱼模式。"

    -- Auction.lua
    L["Scanning %d/%d"] = "扫描中 %d/%d"
    L["Scan fish prices"] = "扫描鱼价"
    L["Auction scan finished: %d of %d price(s) found."] = "拍卖扫描完成：找到 %d/%d 个价格。"
    L["Open the auction house first."] = "请先打开拍卖行。"
    L["Nothing to scan yet: catch some fish first."] = "还没有可扫描的物品：先去钓点鱼吧。"
    L["Scanning auction prices of %d item(s)..."] = "正在扫描%d件物品的拍卖价格……"
    L["Auction scan stopped: %d of %d price(s) found."] = "拍卖扫描已停止：找到 %d/%d 个价格。"

    -- Skill.lua
    L["Apprentice"] = "初级"
    L["Journeyman"] = "中级"
    L["Expert"] = "高级"
    L["Artisan"] = "专家级"
    L["a fishing trainer"] = "钓鱼训练师"
    L["the book \"Expert Fishing - The Bass and You\" (Old Man Heming, Booty Bay)"] =
        "书籍《Expert Fishing - The Bass and You》（Old Man Heming，藏宝海湾）"
    L["the quest from Nat Pagle (Dustwallow Marsh)"] = "纳特·帕格的任务（尘泥沼泽）"
    L["Fishing skill capped (%d/%d): learn %s Fishing from %s."] =
        "钓鱼技能已达上限（%d/%d）：请学习%s钓鱼，来源：%s。"
    L["Fishing %d/%d: %d point(s) left in this rank. Next: %s Fishing from %s."] =
        "钓鱼 %d/%d：本级还差%d点。下一级：%s钓鱼，来源：%s。"

    -- UI/CopyWindow.lua
    L["Click the text, then Ctrl+A and Ctrl+C to copy."] = "点击文本，然后按 Ctrl+A 和 Ctrl+C 复制。"

    -- UI/Indicator.lua
    L["Cast"] = "抛竿"
    L["Hook!"] = "收竿！"
    L["Apply lure"] = "上鱼饵"
    L["Open"] = "打开"
    L["No bobber"] = "无鱼漂"
    L["Drag to move. Lock it in the settings."] = "拖动以移动。可在设置中锁定。"

    -- UI/Toast.lua
    L["Caught: %s"] = "钓到：%s"
    L["Nothing caught"] = "什么也没钓到"

    -- UI/StatsFrame.lua
    L["Time fishing"] = "钓鱼时间"
    L["Time casting"] = "抛竿时间"
    L["Casts"] = "抛竿次数"
    L["Catches"] = "渔获"
    L["Catches per hour"] = "每小时渔获"
    L["Value"] = "价值"
    L["Gold per hour"] = "每小时金币"
    L["OneKeyFishing - Statistics"] = "OneKeyFishing - 统计"
    L["Session"] = "本次"
    L["This zone"] = "本区域"
    L["All time"] = "总计"
    L["Top catches (all time)"] = "最多渔获（总计）"
    L["Zones (all time)"] = "区域（总计）"
    L["Reset session"] = "重置本次"
    L["Reset the fishing statistics of this session?"] = "重置本次的钓鱼统计？"
    L["Reset all"] = "全部重置"
    L["Delete ALL fishing statistics of this character?"] = "删除该角色的全部钓鱼统计？"
    L["Scan auction prices"] = "扫描拍卖价格"
    L["Fishing skill: %d/%d %s%s"] = "钓鱼技能：%d/%d %s%s"
    L["(+%d this session)"] = "（本次 +%d）"
    L["Fishing is not learned."] = "尚未学会钓鱼。"
    L["Values: higher of vendor and auction price (scanned %s)"] = "价值：取商人价格与拍卖价格中较高者（扫描于%s）"
    L["%dm"] = "%d分"
    L["%dh %02dm"] = "%d小时%02d分"
    L["Values: vendor price (scan the auction house for market prices)"] = "价值：商人价格（扫描拍卖行以获取市场价格）"
    L["%d catches, %s"] = "%d次渔获，%s"
    L["No catches yet."] = "还没有渔获。"
    L["Time"] = "时间"
    L["Results"] = "结果"
    L["Money"] = "金钱"
    L["Refresh"] = "刷新"
    L["Time in fishing mode. Paused while AFK if that option is on."] = "处于钓鱼模式的时间。开启相应选项后，暂离时暂停计时。"
    L["Time with the bobber in the water."] = "鱼漂在水中的时间。"
    L["Fishing casts made in fishing mode."] = "在钓鱼模式中的抛竿次数。"
    L["Casts that brought loot."] = "有收获的抛竿。"
    L["Casts that ended without loot."] = "没有收获的抛竿。"
    L["Catches per hour of fishing time. Updated with every cast and with Refresh."] =
        "按钓鱼时间计算的每小时渔获。每次抛竿和点击刷新时更新。"
    L["Items caught, at the higher of vendor and auction price; with few lots listed, the vendor price."] =
        "钓到的物品价值，取商人价格与拍卖价格中较高者；挂单少时用商人价格。"
    L["Value per hour of fishing time. Updated with every cast and with Refresh."] =
        "按钓鱼时间计算的每小时价值。每次抛竿和点击刷新时更新。"

    -- UI/CatchHere.lua and the tabs of UI/StatsFrame.lua
    L["Statistics"] = "统计"
    L["What can be caught here"] = "这里能钓到什么"
    L["Skill: %s"] = "技能：%s"
    L["All skill levels"] = "所有技能等级"
    L["Source: %s"] = "来源：%s"
    L["All"] = "全部"
    L["Only mine"] = "仅我的"
    L["%d catches"] = "%d次渔获"
    L["Nothing caught: %s"] = "什么也没钓到：%s"
    L["Numbers for the whole map: few catches at this spot."] = "整张地图的数据：此处渔获太少。"
    L["Little data"] = "数据不足"
    L["Nothing has been caught here yet."] = "这里还没有钓到过东西。"
    L["Try \"All skill levels\": little data for your skill."] = "试试“所有技能等级”：你的技能等级数据不足。"
    L["and %d more"] = "还有%d项"
    L["No bundled data in this version: only your own catches are shown."] = "此版本没有内置数据：只显示你自己的渔获。"
    L["The game does not show this place on the map."] = "游戏没有在地图上显示这个地方。"
    L["Item"] = "物品"
    L["Chance"] = "几率"
    L["Per catch"] = "每次"
    L["Price"] = "价格"


    -- Prices (the few-lots mark in both tabs)
    L["few lots"] = "挂单少"
    L["Auction price: %s (few lots)"] = "拍卖价格：%s（挂单少）"

    -- Debug.lua
    L["OneKeyFishing - debug report"] = "OneKeyFishing - 调试报告"

    -- UI/Settings.lua
    L["Auto loot while fishing"] = "钓鱼时自动拾取"
    L["Show the interact icon over the bobber"] = "在鱼漂上方显示互动图标"
    L["Leave fishing mode when attacked"] = "受到攻击时退出钓鱼模式"
    L["Equip fishing pole and fishing gear"] = "装备鱼竿和钓鱼装备"
    L["Apply lures automatically"] = "自动使用鱼饵"
    L["Open clams and fished containers"] = "打开蚌壳和钓到的容器"
    L["Show the action indicator and cast timer"] = "显示动作指示器和抛竿计时条"
    L["Lock the indicator position"] = "锁定指示器位置"
    L["Show catch notifications"] = "显示渔获提示"
    L["Show session fishing time under the indicator"] = "在指示器下方显示本次钓鱼时间"
    L["Pause the fishing timer while AFK"] = "暂离时暂停钓鱼计时"
    L["Warn when the Fishing rank is capped"] = "钓鱼技能达到当前等级上限时提醒"
    L["Use scanned auction prices for catch value"] = "用扫描到的拍卖价格计算渔获价值"
    L["Zoom the camera while fishing"] = "钓鱼时调整镜头距离"
    L["Show the minimap button"] = "显示小地图按钮"
    L["not bound"] = "未绑定"
    L["Keys"] = "按键"
    L["Change them in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
        "可在 选项 -> 快捷键 -> 插件 -> OneKeyFishing 中更改。"
    L["WoW names punctuation keys (' ; [ , .) by keyboard language: bind them in both slots, once per language."] =
        "魔兽世界按键盘语言命名标点键（' ; [ , .）：请在两个栏位中各绑定一次，每种语言一次。"
    L["Features"] = "功能"
    L["Auto loot, bobber icon and gear changes apply the next time you enter fishing mode."] =
        "自动拾取、鱼漂图标和装备更改将在下次进入钓鱼模式时生效。"
    L["Camera distance while fishing:"] = "钓鱼时的镜头距离："
    L["Actions"] = "操作"
    L["Debug report"] = "调试报告"
    L["Open statistics"] = "打开统计"
    L["Reset indicator position"] = "重置指示器位置"
    L["(open the auction house first)"] = "（请先打开拍卖行）"
    L["Fishing action: %s      Toggle fishing mode: %s"] = "钓鱼动作：%s      切换钓鱼模式：%s"
    L["Remove"] = "移除"
    L["Fishing gear"] = "钓鱼装备"
    L["Fishing pole"] = "鱼竿"
    L["Use the best pole automatically"] = "自动使用最好的鱼竿"
    L["Add an item"] = "添加物品"
    L["Easiest: close this window and Alt+Click an item in your bags or on the character panel."] =
        "最简单的方法：关闭此窗口，然后在背包或角色面板中 Alt+点击 物品。"
    L["Alt+Click it again to remove it. A fishing pole becomes your chosen pole."] =
        "再次 Alt+点击 即可移除。鱼竿会成为你选定的鱼竿。"
    L["Here you can type an item name, or find all items with a fishing bonus automatically."] =
        "可以在这里输入物品名称，或自动查找所有带钓鱼加成的物品。"
    L["Item not found. Check the name, or Alt+Click the item in your bags."] =
        "未找到物品。请检查名称，或在背包中 Alt+点击 该物品。"
    L["Add"] = "添加"
    L["Find fishing items"] = "查找钓鱼物品"
    L["Added %d item(s)."] = "已添加%d件物品。"
    L["No new items with a fishing bonus found."] = "没有找到新的带钓鱼加成的物品。"
    L["Extra fishing gear"] = "其他钓鱼装备"
    L["No items yet."] = "还没有物品。"
    L["Chosen: %s (+%d)"] = "已选定：%s（+%d）"
    L["Automatic, best in your bags: %s (+%d)"] = "自动，背包中最好的：%s（+%d）"
    L["Automatic: no fishing pole in your bags."] = "自动：背包中没有鱼竿。"
    L["Settings cannot be opened in combat."] = "战斗中无法打开设置。"
    L["Settings panel is not available in this client."] = "此客户端无法使用设置面板。"
    L["Language:"] = "语言："
    L["Interface language"] = "界面语言"
    L["Game client language"] = "游戏客户端语言"
    L["Korean and Chinese may show as squares on a game client in another language."] =
        "在其他语言的游戏客户端上，韩文和中文可能显示为方块。"
    L["Pick English to get a readable interface back."] = "选择 English 即可恢复可读的界面。"
    L["The language changes after reloading the interface."] = "重新加载界面后语言才会更改。"
    L["Reload now"] = "立即重新加载"
    L["Later"] = "稍后"

    -- UI/ItemHooks.lua
    L["OneKeyFishing: fishing gear (Alt+Click to remove)"] = "OneKeyFishing：钓鱼装备（Alt+点击移除）"
    L["OneKeyFishing: Alt+Click to add to fishing gear"] = "OneKeyFishing：Alt+点击添加到钓鱼装备"

    -- UI/Minimap.lua
    L["Leave fishing mode"] = "退出钓鱼模式"
    L["Enter fishing mode"] = "进入钓鱼模式"
    L["Statistics"] = "统计"
    L["Settings"] = "设置"
    L["Fishing mode: %s"] = "钓鱼模式：%s"
    L["Fishing skill: %d/%d %s"] = "钓鱼技能：%d/%d %s"
    L["Session: %d catches, %s"] = "本次：%d次渔获，%s"
    L["Fishing key:"] = "钓鱼键："
    L["Toggle mode key:"] = "切换模式键："
    L["How to use: press the toggle key, then the fishing key to cast,"] = "用法：按下切换键，再按钓鱼键抛竿，"
    L["and the same key again when the bobber splashes."] = "鱼漂溅起水花时再按一次同一个键。"
    L["Alt+Click items in your bags to add fishing gear."] = "在背包中 Alt+点击 物品即可添加钓鱼装备。"
    L["Left-click: toggle fishing mode"] = "左键点击：切换钓鱼模式"
    L["Shift+Left-click: statistics"] = "Shift+左键点击：统计"
    L["Right-click: menu"] = "右键点击：菜单"
    L["Drag: move this button"] = "拖动：移动此按钮"

    -- Share.lua
    L["OneKeyFishing now shares your catches under a random ID with your guild, group and friends who use it."] =
        "OneKeyFishing 现在会以随机ID与使用本插件的公会成员、队友和好友分享你的渔获。"
    L["No character names are sent, but the players you exchange with can tell which ID is yours."] =
        "不会发送角色名称，但与你交换数据的玩家可以知道哪个ID是你的。"
    L["Turn it off in Options -> AddOns -> OneKeyFishing -> Shared database."] =
        "可在 选项 -> 插件 -> OneKeyFishing -> 共享数据库 中关闭。"
    L["Got it"] = "知道了"
    L["Shared database"] = "共享数据库"
    L["Shared catch database is off"] = "共享渔获数据库已关闭"
    L["Waiting for you to read the notice"] = "等待你阅读说明"
    L["Exchange unavailable: the game refuses addon messages"] = "无法交换：游戏拒绝插件消息"
    L["Exchange paused: in combat"] = "交换已暂停：战斗中"
    L["Exchange paused: in an instance"] = "交换已暂停：在副本中"
    L["Exchange paused: loading screen"] = "交换已暂停：载入画面"
    L["Exchange paused: the game restricts addon messages here"] = "交换已暂停：游戏在此限制插件消息"
    L["Exchange paused: the game asked to slow down"] = "交换已暂停：游戏要求放慢速度"
    L["Nobody to exchange with right now"] = "当前没有可交换的对象"
    L["Exchange: %d players, %s ago"] = "交换：%d名玩家，%s前"
    L["Exchange: waiting for the first exchange"] = "交换：等待第一次交换"
    L["Bundled data: version %d, %d places"] = "内置数据：版本%d，%d个地点"
    L["Records held: %d, %d places"] = "保存的记录：%d条，%d个地点"
    L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d"] =
        "过去一小时听到的玩家：公会%d，队伍%d，好友%d，Battle.net %d"
    L["Players exchanged with in the last hour: %d"] = "过去一小时交换过的玩家：%d"
    L["Last exchange: %s ago"] = "上次交换：%s前"
    L["Last exchange: none yet"] = "上次交换：暂无"
    L["Traffic in the last hour: %d KB"] = "过去一小时流量：%d KB"

    -- UI/Settings.lua: the Shared database page
    L["Use the shared catch database"] = "使用共享渔获数据库"
    L["Your catches (items, counts, map cells, the average spot you fish from) are shared under a random ID."] =
        "你的渔获（物品、数量、地图格子、你钓鱼的平均位置）会以随机ID分享。"
    L["They go to addon users in your guild, group and friends list. No names or gear."] =
        "数据会发送给你的公会、队伍和好友列表中的插件用户。不含名称或装备。"
    L["The players you exchange with can tell which ID is yours."] = "与你交换数据的玩家可以知道哪个ID是你的。"
    L["Turned off: nothing is sent or received, and other players' data is not counted."] =
        "关闭时：不发送也不接收任何数据，其他玩家的数据也不计入。"

    -- UI/CatchHere.lua: other players' catches
    L["%d catches from %d players"] = "%d次渔获，来自%d名玩家"

    -- UI/CatchHere.lua: items the game client does not know yet (part 3)
    L["Unknown item"] = "未知物品"
    L["The game has not shown this item yet."] = "游戏尚未显示此物品。"
    L["Reported by %d players on this map"] = "此地图上有%d名玩家报告"
    L["In the bundled data"] = "在内置数据中"
    L["Item ID: %d"] = "物品ID：%d"

    -- Channel.lua: the hidden public channel (part 3)
    L["OneKeyFishing left its hidden channel to free a chat channel slot. Try joining again."] =
        "OneKeyFishing已离开其隐藏频道，以空出一个聊天频道位置。请再试一次。"

    -- UI/Settings.lua: the public channel (part 3)
    L["Use the public channel"] = "使用公开频道"
    L["With the public channel on, they also go to every other addon user, through a hidden chat channel."] =
        "开启公开频道后，数据也会通过隐藏的聊天频道发送给其他所有插件用户。"
    L["Anyone who joins that channel by its name can see which characters in it use the addon."] =
        "任何通过名称加入该频道的人，都能看到频道中哪些角色使用本插件。"

    -- Share.lua: the public channel (part 3)
    L["OneKeyFishing now shares your catches under a random ID with other players who use it."] =
        "OneKeyFishing 现在会以随机ID与其他使用本插件的玩家分享你的渔获。"
    L["It reaches your guild, group and friends, and anyone else through a hidden chat channel."] =
        "数据会发送给你的公会、队伍和好友，也会通过隐藏的聊天频道发送给其他任何人。"
    L["Public channel: in use"] = "公开频道：使用中"
    L["Public channel: in use (fallback channel %d)"] = "公开频道：使用中（备用频道%d）"
    L["Public channel: off"] = "公开频道：关闭"
    L["Public channel: no free chat channel slot"] = "公开频道：没有空的聊天频道位置"
    L["Public channel: locked or refused by the game"] = "公开频道：已锁定或被游戏拒绝"
    L["Public channel: you left it, back at the next login"] = "公开频道：你已离开，下次登录时会重新加入"
    L["Public channel: waiting"] = "公开频道：等待中"
    L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d, channel %d"] =
        "过去一小时听到的玩家：公会%d，队伍%d，好友%d，Battle.net %d，频道%d"

    -- Catalog.lua: the catch catalog (part 4)
    L["Unknown zone (%d)"] = "未知区域 (%d)"

    -- Catalog.lua: spots
    L["%s (%s)"] = "%s（%s）"
    L["No exact spot"] = "无确切地点"

    -- UI/CatalogTab.lua, UI/StatsFrame.lua, UI/CatchHere.lua: the catch catalog (part 4)
    L["Catch catalog"] = "渔获目录"
    L["Search by item name"] = "按物品名称搜索"
    L["Zones: %d"] = "区域：%d"
    L["Back"] = "返回"
    L["Place"] = "地点"
    L["Skill"] = "技能"
    L["Counting the catch..."] = "正在统计渔获..."
    L["Nothing has been caught yet."] = "尚未钓到任何东西。"
    L["The catalog fills with your catches, the bundled data and, with sharing on, other players' catches."] =
        "目录会收录你的渔获、内置数据，以及开启分享时其他玩家的渔获。"
    L["You have not caught anything yet."] = "你尚未钓到任何东西。"
    L["No item matches the search."] = "没有符合搜索的物品。"
    L["No data for this item under these filters."] = "在这些筛选条件下没有此物品的数据。"
    L["Click an item to see where else it is caught."] = "点击物品以查看还能在哪里钓到。"
end)
