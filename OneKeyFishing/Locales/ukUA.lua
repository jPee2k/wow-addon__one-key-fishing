-- Ukrainian translation. Keys are the English texts of Locales/enUS.lua.
-- No game client is in Ukrainian, so menu paths of the game stay in English (as most players see them).
local _, ns = ...

ns.AddTranslation("ukUA", "Українська", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "Дія риболовлі (закинути / підсікти)"
    L["Toggle fishing mode"] = "Увімкнути / вимкнути режим риболовлі"
    L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] =
        "Збережені дані з новішої версії OneKeyFishing. Оновіть аддон, щоб уникнути проблем."
    L["v%s commands:"] = "v%s, команди:"

    -- Gear.lua
    L["Fishing pole set."] = "Вудку вибрано."
    L["This item cannot be used as fishing gear."] = "Цей предмет не можна використати як рибальське спорядження."
    L["Already in the list."] = "Уже в списку."
    L["Added."] = "Додано."
    L["Fishing pole: automatic (best in bags)."] = "Вудка: автоматично (найкраща в сумках)."
    L["Removed from fishing gear."] = "Прибрано з рибальського спорядження."
    L["No fishing pole found in your bags."] = "У сумках немає вудки."
    L["%d fishing item(s) are not in your bags."] = "Рибальських предметів, яких немає в сумках: %d."
    L["No free bag space to take off %s."] = "Немає вільного місця в сумках, щоб зняти %s."
    L["an item"] = "предмет"

    -- Bags.lua
    L["Cannot apply %s, skipping it until fishing mode is turned on again."] =
        "Не вдається застосувати %s, пропускаю до наступного ввімкнення режиму риболовлі."
    L["Not enough bag space to loot %s. It will be opened again when you free a bag slot."] =
        "Недостатньо місця в сумках, щоб забрати вміст %s. Його буде відкрито знову, щойно звільниться місце."
    L["Cannot open %s, skipping it for this session."] = "Не вдається відкрити %s, пропускаю до кінця сесії."

    -- Action.lua
    L["You have not learned Fishing."] = "Ви ще не вивчили риболовлю."
    L["No key is bound to 'Fishing action'. Bind one in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
        "На «Дію риболовлі» не призначено клавішу. Призначте її в Options -> Keybindings -> AddOns -> " ..
        "OneKeyFishing."

    -- Mode.lua
    L["Cannot enter fishing mode in combat."] = "Не можна ввімкнути режим риболовлі в бою."
    L["Fishing mode %s."] = "Режим риболовлі %s."
    L["ON"] = "УВІМКНЕНО"
    L["OFF"] = "ВИМКНЕНО"
    L["Restored game settings from an unfinished fishing session."] =
        "Відновлено налаштування гри після незавершеної сесії риболовлі."
    L["Fishing mode is off. Press your 'Toggle fishing mode' key first."] =
        "Режим риболовлі вимкнено. Спершу натисніть клавішу «Увімкнути / вимкнути режим риболовлі»."
    L["The fishing key is paused in combat."] = "У бою клавіша риболовлі не працює."
    L["Leaving fishing mode after combat."] = "Режим риболовлі вимкнеться після бою."
    L["enter or leave fishing mode"] = "увімкнути або вимкнути режим риболовлі"

    -- Auction.lua
    L["Scanning %d/%d"] = "Сканування %d/%d"
    L["Scan fish prices"] = "Сканувати ціни на рибу"
    L["Auction scan finished: %d of %d price(s) found."] = "Сканування аукціону завершено: знайдено цін %d із %d."
    L["Open the auction house first."] = "Спершу відкрийте аукціон."
    L["Nothing to scan yet: catch some fish first."] = "Поки нічого сканувати: спершу щось упіймайте."
    L["Scanning auction prices of %d item(s)..."] = "Сканую ціни на аукціоні, предметів: %d..."
    L["Auction scan stopped: %d of %d price(s) found."] = "Сканування аукціону зупинено: знайдено цін %d із %d."
    L["scan auction prices of caught items (auction house must be open)"] =
        "сканувати ціни на впіймане на аукціоні (аукціон має бути відкритий)"

    -- Skill.lua
    L["Apprentice"] = "Учень"
    L["Journeyman"] = "Підмайстер"
    L["Expert"] = "Експерт"
    L["Artisan"] = "Майстер"
    L["a fishing trainer"] = "наставника риболовлі"
    L["the book \"Expert Fishing - The Bass and You\" (Old Man Heming, Booty Bay)"] =
        "книги «Риболовля для експертів: окунь і ти» (Старий Хемінг, Бухта Здобичі)"
    L["the quest from Nat Pagle (Dustwallow Marsh)"] = "завдання від Нета Пейгла (Пилові Топи)"
    L["Fishing skill capped (%d/%d): learn %s Fishing from %s."] =
        "Навичка риболовлі досягла межі (%d/%d): вивчіть ранг «%s» риболовлі з %s."
    L["Fishing %d/%d: %d point(s) left in this rank. Next: %s Fishing from %s."] =
        "Риболовля %d/%d: до межі рангу залишилося %d. Далі: ранг «%s» з %s."

    -- UI/CopyWindow.lua
    L["Click the text, then Ctrl+A and Ctrl+C to copy."] = "Клацніть по тексту, потім Ctrl+A і Ctrl+C, щоб скопіювати."

    -- UI/Indicator.lua
    L["Cast"] = "Закинути"
    L["Hook!"] = "Підсікай!"
    L["Apply lure"] = "Наживка"
    L["Open"] = "Відкрити"
    L["No bobber"] = "Немає поплавця"
    L["Drag to move. Lock it in the settings."] = "Перетягніть, щоб перемістити. Закріпити можна в налаштуваннях."

    -- UI/Toast.lua
    L["Caught: %s"] = "Упіймано: %s"
    L["Nothing caught"] = "Нічого не впіймано"

    -- UI/StatsFrame.lua
    L["Time fishing"] = "Час риболовлі"
    L["Time casting"] = "Час із закинутою вудкою"
    L["Casts"] = "Закидання"
    L["Catches"] = "Улов"
    L["Catches per hour"] = "Улов за годину"
    L["Value"] = "Вартість"
    L["Gold per hour"] = "Золото за годину"
    L["OneKeyFishing - Statistics"] = "OneKeyFishing - статистика"
    L["Session"] = "Сесія"
    L["This zone"] = "Ця зона"
    L["All time"] = "Увесь час"
    L["Top catches (all time)"] = "Найбільше впіймано (за весь час)"
    L["Zones (all time)"] = "Зони (за весь час)"
    L["Reset session"] = "Скинути сесію"
    L["Reset the fishing statistics of this session?"] = "Скинути статистику риболовлі цієї сесії?"
    L["Reset all"] = "Скинути все"
    L["Delete ALL fishing statistics of this character?"] = "Видалити ВСЮ статистику риболовлі цього персонажа?"
    L["Scan auction prices"] = "Сканувати ціни аукціону"
    L["Fishing skill: %d/%d %s%s"] = "Навичка риболовлі: %d/%d %s%s"
    L["(+%d this session)"] = "(+%d за сесію)"
    L["Fishing is not learned."] = "Риболовлю не вивчено."
    L["Values: higher of vendor and auction price (scanned %s)"] =
        "Вартість: більша з ціни торговця та аукціону (скановано %s)"
    L["%dm"] = "%d хв"
    L["%dh %02dm"] = "%d год %02d хв"
    L["Values: vendor price (scan the auction house for market prices)"] =
        "Вартість: ціна торговця (проскануйте аукціон, щоб отримати ринкові ціни)"
    L["%d catches, %s"] = "улов: %d, %s"
    L["No catches yet."] = "Поки нічого не впіймано."
    L["show the fishing statistics"] = "показати статистику риболовлі"
    L["Time"] = "Час"
    L["Results"] = "Результати"
    L["Money"] = "Гроші"
    L["Refresh"] = "Оновити"
    L["Time in fishing mode. Paused while AFK if that option is on."] =
        "Час у режимі риболовлі. Ставиться на паузу під час AFK, якщо цю опцію ввімкнено."
    L["Time with the bobber in the water."] = "Час, коли поплавець у воді."
    L["Fishing casts made in fishing mode."] = "Закидання вудки в режимі риболовлі."
    L["Casts that brought loot."] = "Закидання, що принесли здобич."
    L["Casts that ended without loot."] = "Закидання, що закінчилися без здобичі."
    L["Catches per hour of fishing time. Updated with every cast and with Refresh."] =
        "Улов за годину риболовлі. Оновлюється з кожним закиданням і кнопкою «Оновити»."
    L["Items caught, at the higher of the vendor price and the last scanned auction price."] =
        "Упіймані предмети за більшою з ціни торговця та останньої сканованої ціни аукціону."
    L["Value per hour of fishing time. Updated with every cast and with Refresh."] =
        "Вартість за годину риболовлі. Оновлюється з кожним закиданням і кнопкою «Оновити»."

    -- Debug.lua
    L["OneKeyFishing - debug report"] = "OneKeyFishing - звіт для налагодження"
    L["show a report to copy into a bug report"] = "показати звіт, який можна скопіювати в повідомлення про помилку"

    -- UI/Settings.lua
    L["Auto loot while fishing"] = "Автозбір здобичі під час риболовлі"
    L["Show the interact icon over the bobber"] = "Показувати значок взаємодії над поплавцем"
    L["Leave fishing mode when attacked"] = "Вимикати режим риболовлі, коли на вас нападають"
    L["Equip fishing pole and fishing gear"] = "Вдягати вудку й рибальське спорядження"
    L["Apply lures automatically"] = "Автоматично чіпляти наживку"
    L["Open clams and fished containers"] = "Відкривати мушлі й виловлені скрині"
    L["Show the action indicator and cast timer"] = "Показувати індикатор дії та таймер закидання"
    L["Lock the indicator position"] = "Закріпити індикатор"
    L["Show catch notifications"] = "Показувати сповіщення про улов"
    L["Show session fishing time under the indicator"] = "Показувати час риболовлі за сесію під індикатором"
    L["Pause the fishing timer while AFK"] = "Ставити таймер риболовлі на паузу під час AFK"
    L["Warn when the Fishing rank is capped"] = "Попереджати, коли ранг риболовлі досяг межі"
    L["Use scanned auction prices for catch value"] = "Рахувати вартість улову за сканованими цінами аукціону"
    L["Zoom the camera while fishing"] = "Наближати камеру під час риболовлі"
    L["Show the minimap button"] = "Показувати кнопку біля мінікарти"
    L["not bound"] = "не призначено"
    L["Keys"] = "Клавіші"
    L["Change them in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
        "Змінити їх можна в Options -> Keybindings -> AddOns -> OneKeyFishing."
    L["WoW names punctuation keys (' ; [ , .) by keyboard language: bind them in both slots, once per language."] =
        "WoW називає клавіші з розділовими знаками (' ; [ , .) за мовою клавіатури: " ..
        "призначте їх в обидва слоти, по разу для кожної мови."
    L["Features"] = "Можливості"
    L["Auto loot, bobber icon and gear changes apply the next time you enter fishing mode."] =
        "Зміни автозбору, значка поплавця і спорядження діють з наступного ввімкнення режиму риболовлі."
    L["Camera distance while fishing:"] = "Відстань камери під час риболовлі:"
    L["Actions"] = "Дії"
    L["Debug report"] = "Звіт для налагодження"
    L["Open statistics"] = "Відкрити статистику"
    L["Reset indicator position"] = "Скинути позицію індикатора"
    L["(open the auction house first)"] = "(спершу відкрийте аукціон)"
    L["Fishing action: %s      Toggle fishing mode: %s"] = "Дія риболовлі: %s      Режим риболовлі: %s"
    L["Remove"] = "Прибрати"
    L["Fishing gear"] = "Рибальське спорядження"
    L["Fishing pole"] = "Вудка"
    L["Use the best pole automatically"] = "Автоматично брати найкращу вудку"
    L["Add an item"] = "Додати предмет"
    L["Easiest: close this window and Alt+Click an item in your bags or on the character panel."] =
        "Найпростіше: закрийте це вікно й зробіть Alt+клік по предмету в сумках або на панелі персонажа."
    L["Alt+Click it again to remove it. A fishing pole becomes your chosen pole."] =
        "Ще один Alt+клік прибирає предмет. Вудка стає вибраною вудкою."
    L["Here you can type an item name, or find all items with a fishing bonus automatically."] =
        "Тут можна ввести назву предмета або автоматично знайти всі предмети з бонусом до риболовлі."
    L["Item not found. Check the name, or Alt+Click the item in your bags."] =
        "Предмет не знайдено. Перевірте назву або зробіть Alt+клік по предмету в сумках."
    L["Add"] = "Додати"
    L["Find fishing items"] = "Знайти рибальські предмети"
    L["Added %d item(s)."] = "Додано предметів: %d."
    L["No new items with a fishing bonus found."] = "Нових предметів із бонусом до риболовлі не знайдено."
    L["Extra fishing gear"] = "Додаткове рибальське спорядження"
    L["No items yet."] = "Поки немає предметів."
    L["Chosen: %s (+%d)"] = "Вибрано: %s (+%d)"
    L["Automatic, best in your bags: %s (+%d)"] = "Автоматично, найкраща в сумках: %s (+%d)"
    L["Automatic: no fishing pole in your bags."] = "Автоматично: у сумках немає вудки."
    L["Settings cannot be opened in combat."] = "Налаштування не можна відкрити в бою."
    L["Settings panel is not available in this client."] = "Панель налаштувань недоступна в цьому клієнті."
    L["open the settings"] = "відкрити налаштування"
    L["Language:"] = "Мова:"
    L["Interface language"] = "Мова інтерфейсу"
    L["Game client language"] = "Мова клієнта гри"
    L["Korean and Chinese may show as squares on a game client in another language."] =
        "Корейська й китайська можуть відображатися квадратиками, якщо клієнт гри іншою мовою."
    L["Pick English to get a readable interface back."] = "Виберіть English, щоб повернути читабельний інтерфейс."
    L["The language changes after reloading the interface."] = "Мова зміниться після перезавантаження інтерфейсу."
    L["Reload now"] = "Перезавантажити"
    L["Later"] = "Пізніше"

    -- UI/ItemHooks.lua
    L["OneKeyFishing: fishing gear (Alt+Click to remove)"] =
        "OneKeyFishing: рибальське спорядження (Alt+клік, щоб прибрати)"
    L["OneKeyFishing: Alt+Click to add to fishing gear"] =
        "OneKeyFishing: Alt+клік, щоб додати до рибальського спорядження"

    -- UI/Minimap.lua
    L["Leave fishing mode"] = "Вимкнути режим риболовлі"
    L["Enter fishing mode"] = "Увімкнути режим риболовлі"
    L["Statistics"] = "Статистика"
    L["Settings"] = "Налаштування"
    L["Fishing mode: %s"] = "Режим риболовлі: %s"
    L["Fishing skill: %d/%d %s"] = "Навичка риболовлі: %d/%d %s"
    L["Session: %d catches, %s"] = "Сесія: улов %d, %s"
    L["Fishing key:"] = "Клавіша риболовлі:"
    L["Toggle mode key:"] = "Клавіша режиму:"
    L["How to use: press the toggle key, then the fishing key to cast,"] =
        "Як користуватися: натисніть клавішу режиму, потім клавішу риболовлі, щоб закинути,"
    L["and the same key again when the bobber splashes."] = "і ту саму клавішу ще раз, коли поплавець сплесне."
    L["Alt+Click items in your bags to add fishing gear."] =
        "Alt+клік по предметах у сумках додає рибальське спорядження."
    L["Left-click: toggle fishing mode"] = "Лівий клік: режим риболовлі"
    L["Shift+Left-click: statistics"] = "Shift+лівий клік: статистика"
    L["Right-click: menu"] = "Правий клік: меню"
    L["Drag: move this button"] = "Перетягування: перемістити кнопку"
end)
