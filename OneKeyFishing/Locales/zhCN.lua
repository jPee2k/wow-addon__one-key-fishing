-- Simplified Chinese translation. Keys are the English texts of Locales/enUS.lua.
local _, ns = ...

ns.AddTranslation("zhCN", "简体中文", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "钓鱼动作（抛竿/收竿）"
    L["Toggle fishing mode"] = "切换钓鱼模式"
    L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] =
        "你的存档数据来自更新版本的 OneKeyFishing。请更新插件以免出现问题。"
    L["v%s commands:"] = "v%s 命令："

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
    L["enter or leave fishing mode"] = "进入或退出钓鱼模式"

    -- Auction.lua
    L["Scanning %d/%d"] = "扫描中 %d/%d"
    L["Scan fish prices"] = "扫描鱼价"
    L["Auction scan finished: %d of %d price(s) found."] = "拍卖扫描完成：找到 %d/%d 个价格。"
    L["Open the auction house first."] = "请先打开拍卖行。"
    L["Nothing to scan yet: catch some fish first."] = "还没有可扫描的物品：先去钓点鱼吧。"
    L["Scanning auction prices of %d item(s)..."] = "正在扫描%d件物品的拍卖价格……"
    L["Auction scan stopped: %d of %d price(s) found."] = "拍卖扫描已停止：找到 %d/%d 个价格。"
    L["scan auction prices of caught items (auction house must be open)"] = "扫描钓到物品的拍卖价格（需打开拍卖行）"

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
    L["show the fishing statistics"] = "显示钓鱼统计"
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
    L["Items caught, at the higher of the vendor price and the last scanned auction price."] =
        "钓到的物品价值，取商人价格与最近扫描的拍卖价格中较高者。"
    L["Value per hour of fishing time. Updated with every cast and with Refresh."] =
        "按钓鱼时间计算的每小时价值。每次抛竿和点击刷新时更新。"

    -- Debug.lua
    L["OneKeyFishing - debug report"] = "OneKeyFishing - 调试报告"
    L["show a report to copy into a bug report"] = "显示可复制到错误报告中的报告"

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
    L["open the settings"] = "打开设置"
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
end)
