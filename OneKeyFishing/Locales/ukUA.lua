-- Ukrainian translation. Keys are the English texts of Locales/enUS.lua.
-- No game client is in Ukrainian, so menu paths of the game stay in English (as most players see them).
local _, ns = ...

ns.AddTranslation("ukUA", "Українська", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "Дія риболовлі (закинути / підсікти)"
    L["Toggle fishing mode"] = "Увімкнути / вимкнути режим риболовлі"
    L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] =
        "Збережені дані з новішої версії OneKeyFishing. Оновіть аддон, щоб уникнути проблем."
    L["Your game client has no translation, so the addon is in English. Others, such as %s, are in /okf config."] =
        "Для вашого клієнта гри немає перекладу, тому аддон англійською. " ..
        "Інші мови, наприклад %s, є в /okf config."

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

    -- Auction.lua
    L["Scanning %d/%d"] = "Сканування %d/%d"
    L["Scan fish prices"] = "Сканувати ціни на рибу"
    L["Auction scan finished: %d of %d price(s) found."] = "Сканування аукціону завершено: знайдено цін %d із %d."
    L["Open the auction house first."] = "Спершу відкрийте аукціон."
    L["Nothing to scan yet: catch some fish first."] = "Поки нічого сканувати: спершу щось упіймайте."
    L["Scanning auction prices of %d item(s)..."] = "Сканую ціни на аукціоні, предметів: %d..."
    L["Auction scan stopped: %d of %d price(s) found."] = "Сканування аукціону зупинено: знайдено цін %d із %d."
    L["Auction scan stopped: the auction house does not answer (%d of %d price(s) found). Log out and back in."] =
        "Сканування аукціону зупинено: аукціон не відповідає (знайдено цін %d із %d). " ..
        "Вийдіть із гри персонажем і зайдіть знову."
    L["The auction house does not answer. Log out and back in to bring it back."] =
        "Аукціон не відповідає. Вийдіть із гри персонажем і зайдіть знову, щоб його повернути."
    L["Auction house not answering"] = "Аукціон не відповідає"

    -- Skill.lua
    L["Apprentice"] = "Учень"
    L["Journeyman"] = "Підмайстер"
    L["Expert"] = "Експерт"
    L["Artisan"] = "Майстер"
    L["Any fishing trainer teaches it (capitals and towns; the minimap can track trainers)."] =
        "Його навчає будь-який наставник риболовлі (у столицях і містечках; мінікарта може показувати наставників)."
    L["Buy the book \"%s\" from %s in %s, %s."] = "Купіть книгу «%s», продавець: %s (%s, %s)."
    L["Do the quest \"%s\" from %s at %s, %s."] = "Виконайте завдання «%s», яке дає %s (%s, %s)."
    L["%s Fishing needs character level %d."] = "Ранг «%s» риболовлі потребує рівня персонажа %d."
    L["Map pin"] = "Мітка на карті"
    L["Fishing skill capped (%d/%d): learn %s Fishing to go on."] =
        "Навичка риболовлі на межі (%d/%d): щоб рости далі, вивчіть ранг «%s»."
    L["You can learn %s Fishing now."] = "Ви вже можете вивчити ранг «%s» риболовлі."
    L["Next rank: %s Fishing, from skill %d."] = "Наступний ранг: «%s», з навички %d."
    L["Next rank: %s Fishing, from skill %d and character level %d."] =
        "Наступний ранг: «%s», з навички %d і рівня персонажа %d."
    L["Next rank: %s Fishing, from character level %d."] = "Наступний ранг: «%s», з рівня персонажа %d."
    L["Next rank: %s Fishing, ready to learn."] = "Наступний ранг: «%s», можна вивчити вже зараз."

    -- UI/CopyWindow.lua
    L["Click the text, then Ctrl+A and Ctrl+C to copy."] = "Клацніть по тексту, потім Ctrl+A і Ctrl+C, щоб скопіювати."

    -- UI/Indicator.lua
    L["Cast"] = "Закинути"
    L["Hook!"] = "Підсікай!"
    L["Apply lure"] = "Наживка"
    L["Open"] = "Відкрити"
    L["No bobber"] = "Немає поплавця"
    L["Paused in combat"] = "Пауза в бою"
    L["Drag to move. Lock it in the settings."] = "Перетягніть, щоб перемістити. Закріпити можна в налаштуваннях."

    -- UI/Toast.lua
    L["Caught: %s"] = "Упіймано: %s"
    L["Nothing caught"] = "Нічого не впіймано"

    -- Core/MapPin.lua and its toasts in UI/Toast.lua
    L["The game did not accept the map pin."] = "Гра не прийняла мітку на карті."
    L["Map pin: %s. Open the world map to see it."] = "Мітка на карті: %s. Відкрийте карту світу, щоб її побачити."
    L["Replace your map pin with this place?"] = "Замінити вашу мітку на карті цим місцем?"
    L["Replace"] = "Замінити"

    -- UI/StatsFrame.lua
    L["Pin"] = "Мітка"
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
    L["1 catch, %s"] = "улов: 1, %s"
    L["No catches yet."] = "Поки нічого не впіймано."
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
    L["Items caught, at the higher of vendor and auction price; with few lots listed, the vendor price."] =
        "Улов за більшою з ціни торговця та ціни аукціону; якщо лотів мало — за ціною торговця."
    L["Value per hour of fishing time. Updated with every cast and with Refresh."] =
        "Вартість за годину риболовлі. Оновлюється з кожним закиданням і кнопкою «Оновити»."

    -- UI/CatchHere.lua and the tabs of UI/StatsFrame.lua
    L["Statistics"] = "Статистика"
    L["What can be caught here"] = "Що тут ловиться"
    L["Skill: Up to %d"] = "Навичка: До %d"
    L["Skill: All"] = "Навичка: Усі"
    L["Up to %d"] = "До %d"
    L["Up to %d (yours)"] = "До %d (ваша)"
    L["All (%d+)"] = "Усі (%d+)"
    L["All (%d+) (yours)"] = "Усі (%d+) (ваша)"
    L["Catches with skill up to %d."] = "Улови з навичкою до %d."
    L["Catches with any skill."] = "Улови з будь-якою навичкою."
    L["Misses only with skill %s."] = "Промахи — лише з навичкою %s."
    L["Nothing caught: little data"] = "Нічого не впіймано: мало даних"
    L["Source: %s"] = "Джерело: %s"
    L["All"] = "Усе"
    L["Only mine"] = "Лише моє"
    L["%d catches"] = "улов: %d"
    L["1 catch"] = "улов: 1"
    L["Nothing caught: %s"] = "Нічого не впіймано: %s"
    L["Numbers for the whole map: few catches at this spot."] = "Дані по всій карті: на цьому місці замало уловів."
    L["Little data"] = "Мало даних"
    L["Nothing has been caught here yet."] = "Тут ще нічого не ловили."
    L["and %d more"] = "і ще %d"
    L["No bundled data in this version: only your own catches are shown."] =
        "У цій версії немає вбудованих даних: показано лише ваш улов."
    L["No bundled data in this version."] = "У цій версії немає вбудованих даних."
    L["The game does not show this place on the map."] = "Гра не показує це місце на карті."
    L["Item"] = "Предмет"
    L["Chance"] = "Шанс"
    L["Per catch"] = "За улов"
    L["Price"] = "Ціна"


    -- Prices (the few-lots mark in both tabs)
    L["few lots"] = "мало лотів"
    L["Auction price (OneKeyFishing): %s (few lots)"] = "Ціна аукціону (OneKeyFishing): %s (мало лотів)"
    L["Auction price (OneKeyFishing): %s"] = "Ціна аукціону (OneKeyFishing): %s"

    -- Debug.lua
    L["OneKeyFishing - debug report"] = "OneKeyFishing - звіт для налагодження"

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
    L["Remind me about the next Fishing rank"] = "Нагадувати про наступний ранг риболовлі"
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
    L["Language:"] = "Мова:"
    L["Interface language"] = "Мова інтерфейсу"
    L["Game client language"] = "Мова клієнта гри"
    L["Korean and Chinese may show as squares on a game client in another language."] =
        "Корейська й китайська можуть відображатися квадратиками, якщо клієнт гри іншою мовою."
    L["Pick English to get a readable interface back."] = "Виберіть English, щоб повернути читабельний інтерфейс."
    L["The language changes after reloading the interface."] = "Мова зміниться після перезавантаження інтерфейсу."
    L["Reload now"] = "Перезавантажити"
    L["Later"] = "Пізніше"
    L["Yes"] = "Так"
    L["No"] = "Ні"
    L["Cancel"] = "Скасувати"

    -- UI/ItemHooks.lua
    L["OneKeyFishing: fishing gear (Alt+Click to remove)"] =
        "OneKeyFishing: рибальське спорядження (Alt+клік, щоб прибрати)"
    L["OneKeyFishing: Alt+Click to add to fishing gear"] =
        "OneKeyFishing: Alt+клік, щоб додати до рибальського спорядження"

    -- UI/Minimap.lua
    L["Pin: next Fishing rank"] = "Мітка: наступний ранг риболовлі"
    L["Leave fishing mode"] = "Вимкнути режим риболовлі"
    L["Enter fishing mode"] = "Увімкнути режим риболовлі"
    L["Settings"] = "Налаштування"
    L["Fishing mode: %s"] = "Режим риболовлі: %s"
    L["Fishing skill: %d/%d %s"] = "Навичка риболовлі: %d/%d %s"
    L["Session: %d catches, %s"] = "Сесія: улов %d, %s"
    L["Session: 1 catch, %s"] = "Сесія: улов 1, %s"
    L["Fishing key:"] = "Клавіша риболовлі:"
    L["Toggle mode key:"] = "Клавіша режиму:"
    L["How to use: press the toggle key, then the fishing key to cast,"] =
        "Як користуватися: натисніть клавішу режиму, потім клавішу риболовлі, щоб закинути,"
    L["and the same key again when the bobber splashes."] = "і ту саму клавішу ще раз, коли рибка клюне."
    L["Alt+Click items in your bags to add fishing gear."] =
        "Alt+клік по предметах у сумках додає рибальське спорядження."
    L["Left-click: toggle fishing mode"] = "Лівий клік: режим риболовлі"
    L["Shift+Left-click: statistics"] = "Shift+лівий клік: статистика"
    L["Right-click: menu"] = "Правий клік: меню"
    L["Drag: move this button"] = "Перетягування: перемістити кнопку"

    -- Share.lua
    L["OneKeyFishing now shares your catches under a random ID with your guild, group and friends who use it."] =
        "OneKeyFishing тепер ділиться вашим уловом під випадковим ID з вашою гільдією, групою та друзями, які ним " ..
        "користуються."
    L["No character names are sent, but the players you exchange with can tell which ID is yours."] =
        "Імена персонажів не надсилаються, але гравці, з якими ви обмінюєтеся, можуть знати, який ID ваш."
    L["Turn it off in Options -> AddOns -> OneKeyFishing -> Shared database."] =
        "Вимкнути можна в Options -> AddOns -> OneKeyFishing -> Спільна база даних."
    L["Got it"] = "Зрозуміло"
    L["Shared database"] = "Спільна база даних"
    L["Shared catch database is off"] = "Спільну базу уловів вимкнено"
    L["Waiting for you to read the notice"] = "Чекаємо, поки ви прочитаєте повідомлення"
    L["Exchange unavailable: the game refuses addon messages"] = "Обмін недоступний: гра відхиляє повідомлення аддонів"
    L["Exchange paused: in combat"] = "Обмін призупинено: бій"
    L["Exchange paused: in an instance"] = "Обмін призупинено: ви в підземеллі"
    L["Exchange paused: loading screen"] = "Обмін призупинено: екран завантаження"
    L["Exchange paused: the game restricts addon messages here"] =
        "Обмін призупинено: гра обмежує тут повідомлення аддонів"
    L["Exchange paused: the game asked to slow down"] = "Обмін призупинено: гра попросила сповільнитися"
    L["Nobody to exchange with right now"] = "Зараз немає з ким обмінюватися"
    L["Exchange: %d players, %s ago"] = "Обмін: гравців %d, %s тому"
    L["Exchange: 1 player, %s ago"] = "Обмін: 1 гравець, %s тому"
    L["Exchange: waiting for the first exchange"] = "Обмін: чекаємо на перший обмін"
    L["Bundled data: version %d, %d places"] = "Вбудовані дані: версія %d, місць %d"
    L["Records held: %d, %d places"] = "Збережені внески: %d, місць %d"
    L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d"] =
        "Гравці за останню годину: гільдія %d, група %d, друзі %d, Battle.net %d"
    L["Players exchanged with in the last hour: %d"] = "Гравців, з якими був обмін за останню годину: %d"
    L["Last exchange: %s ago"] = "Останній обмін: %s тому"
    L["Last exchange: none yet"] = "Останній обмін: ще не було"
    L["Traffic in the last hour: %d KB"] = "Трафік за останню годину: %d КБ"

    -- UI/Settings.lua: the Shared database page
    L["Use the shared catch database"] = "Використовувати спільну базу уловів"
    L["Your catches (items, counts, map cells, the average spot you fish from) are shared under a random ID."] =
        "Ваш улов (предмети, кількість, клітинки карт, середня точка, з якої ви ловите) передається під випадковим ID."
    L["They go to addon users in your guild, group and friends list. No names or gear."] =
        "Його отримують користувачі аддона у вашій гільдії, групі та списку друзів. Без імен і спорядження."
    L["The players you exchange with can tell which ID is yours."] =
        "Гравці, з якими ви обмінюєтеся, можуть знати, який ID ваш."
    L["Turned off: nothing is sent or received, and other players' data is not counted."] =
        "Вимкнено: нічого не надсилається й не приймається, а дані інших гравців не враховуються."

    -- UI/CatchHere.lua: other players' catches
    L["%d catches from %d players"] = "улов: %d, гравців: %d"

    -- UI/CatchHere.lua: items the game client does not know yet (part 3)
    L["Unknown item"] = "Невідомий предмет"
    L["The game has not shown this item yet."] = "Гра ще не показала цей предмет."
    L["Reported by %d players on this map"] = "Повідомили гравців на цій карті: %d"
    L["In the bundled data"] = "У вбудованих даних"
    L["Item ID: %d"] = "ID предмета: %d"

    -- Channel.lua: the hidden public channel (part 3)
    L["OneKeyFishing left its hidden channel to free a chat channel slot. Try joining again."] =
        "OneKeyFishing вийшов зі свого прихованого каналу, щоб звільнити місце для каналу чату. Спробуйте ще раз."

    -- UI/Settings.lua: the public channel (part 3)
    L["Use the public channel"] = "Використовувати публічний канал"
    L["With the public channel on, they also go to every other addon user, through a hidden chat channel."] =
        "Коли публічний канал увімкнено, його отримують також усі інші користувачі аддона через прихований канал " ..
        "чату."
    L["Anyone who joins that channel by its name can see which characters in it use the addon."] =
        "Будь-хто, хто приєднається до цього каналу за його назвою, бачитиме, які персонажі в ньому користуються " ..
        "аддоном."

    -- Share.lua: the public channel (part 3)
    L["OneKeyFishing now shares your catches under a random ID with other players who use it."] =
        "OneKeyFishing тепер ділиться вашим уловом під випадковим ID з іншими гравцями, які ним користуються."
    L["It reaches your guild, group and friends, and anyone else through a hidden chat channel."] =
        "Його отримують ваша гільдія, група та друзі, а також будь-хто інший через прихований канал чату."
    L["Public channel: in use"] = "Публічний канал: використовується"
    L["Public channel: in use (fallback channel %d)"] = "Публічний канал: використовується (запасний канал %d)"
    L["Public channel: off"] = "Публічний канал: вимкнено"
    L["Public channel: no free chat channel slot"] = "Публічний канал: немає вільного місця для каналу чату"
    L["Public channel: locked or refused by the game"] = "Публічний канал: заблоковано або гра відмовляє"
    L["Public channel: you left it, back at the next login"] =
        "Публічний канал: ви з нього вийшли, повернеться з наступним входом у гру"
    L["Public channel: waiting"] = "Публічний канал: очікування"
    L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d, channel %d"] =
        "Гравці за останню годину: гільдія %d, група %d, друзі %d, Battle.net %d, канал %d"

    -- Catalog.lua: the catch catalog (part 4)
    L["Unknown zone (%d)"] = "Невідома зона (%d)"

    -- Catalog.lua: spots
    L["%s (%s)"] = "%s (%s)"
    L["No exact spot"] = "Без точного місця"

    -- UI/CatalogTab.lua, UI/StatsFrame.lua, UI/CatchHere.lua: the catch catalog (part 4)
    L["Catch catalog"] = "Каталог улову"
    L["Search by item name"] = "Пошук за назвою предмета"
    L["Zones: %d"] = "Зон: %d"
    L["Back"] = "Назад"
    L["Place"] = "Місце"
    L["Skill"] = "Навичка"
    L["Counting the catch..."] = "Підрахунок улову..."
    L["Nothing has been caught yet."] = "Ще нічого не спіймано."
    L["The catalog fills with your catches, the bundled data and, with sharing on, other players' catches."] =
        "Каталог наповнюється вашим уловом, вбудованими даними та, з увімкненим обміном, уловом інших гравців."
    L["You have not caught anything yet."] = "Ви ще нічого не спіймали."
    L["No item matches the search."] = "Жоден предмет не відповідає пошуку."
    L["No data for this item under these filters."] = "Немає даних про цей предмет за цими фільтрами."
    L["Click an item to see where else it is caught."] = "Клацніть предмет, щоб побачити, де ще його ловлять."

    -- UI/CatalogTab.lua: the map pin (part 4)
    L["Set a map pin here"] = "Поставити тут мітку на мапі"

    -- Catalog.lua, UI/ItemHooks.lua, UI/Minimap.lua, UI/Settings.lua: catch chances in tooltips (part 4)
    L["%s (%d players)"] = "%s (гравців: %d)"
    L["Caught in:"] = "Ловиться в:"
    L["Likely catch here:"] = "Імовірний улов тут:"
    L["Show catch chances in tooltips"] = "Показувати шанси улову в підказках"

    -- UI/CatchHere.lua, UI/CatalogTab.lua: the Water filter (part 4)
    L["Water: %s"] = "Вода: %s"
    L["Everywhere"] = "Усюди"
    L["Open water"] = "Відкрита вода"
    L["Pools"] = "Косяки"
    -- Fishing/Sound.lua, UI/Settings.lua, UI/Minimap.lua: the fishing sounds (spec 013)
    L["Sound effects"] = "Звукові ефекти"
    L["Play fishing sounds"] = "Відтворювати звуки риболовлі"
    L["A bell rings when you cast, and a sound plays when you hook."] =
        "Дзвоник лунає, коли ви закидаєте, а звук — коли підсікаєте."
    L["A notification follows when the loot holds an Uncommon or better item."] =
        "Далі лунає сповіщення, коли в здобичі є предмет незвичайної якості або кращий."
    L["Only while fishing mode is on; silent in a fight."] = "Лише в режимі риболовлі; у бою тиша."
    L["Turn fishing sounds on"] = "Увімкнути звуки риболовлі"
    L["Turn fishing sounds off"] = "Вимкнути звуки риболовлі"
    -- UI/Settings.lua: the volume of the fishing sounds (spec 013)
    L["Volume"] = "Гучність"
    L["%d%%"] = "%d%%"
    -- UI/Settings.lua: game sound in the background while fishing (spec 013)
    L["Fishing sound in the background"] = "Звук риболовлі у фоні"
    L["All game sound keeps playing while the game window is in the background."] =
        "Увесь звук гри грає далі, коли вікно гри у фоні."
    L["Only while fishing mode is on; your own game setting comes back when the mode ends."] =
        "Лише в режимі риболовлі; ваше власне налаштування гри повертається, коли режим завершується."
    -- UI/Settings.lua: the splash focus (spec 013)
    L["Splash focus while fishing"] = "Фокус на сплеск під час риболовлі"
    L["Music, ambience and dialog are silenced and sound effects raised, so the bobber's splash stands out."] =
        "Музика, звуки оточення і діалоги вимикаються, а звукові ефекти гучнішають, щоб сплеск поплавця було чути."
    L["Lifted in a fight; everything comes back when fishing mode ends."] =
        "У бою знімається; усе повертається, коли режим риболовлі завершується."
    -- Item kinds (spec 014)
    L["Fish"] = "Риба"
    L["Containers"] = "Контейнери"
    L["Potions & drinks"] = "Зілля й напої"
    L["Reagents & herbs"] = "Реагенти й трави"
    L["Other"] = "Інше"
    L["Trophies"] = "Трофеї"
    L["Quest"] = "Квестові"
    L["%s (%d/%d)"] = "%s (%d/%d)"
    L["New trophy: %s (%d/%d)"] = "Новий трофей: %s (%d/%d)"
    L["Best places"] = "Найкращі місця"
    L["Catalog"] = "Каталог"
    L["Level"] = "Рівень"
    L["No subzone"] = "Без підзони"
    L["Safe for me: %s"] = "Безпечні для мене: %s"
    L["On"] = "Так"
    L["Off"] = "Ні"
    L["Continent: %s"] = "Континент: %s"
    L["Nothing matches the filters."] = "Нічого не відповідає фільтрам."
    L["%d%% of the catch here has no price: the gold may be higher."] =
        "%d%% улову тут не має ціни: заробіток може бути більшим."
    L["%s: %s chance, %s each, %d%% of the gold"] = "%s: шанс %s, %s за штуку, %d%% заробітку"
    L["Kinds: All"] = "Види: Усі"
    L["Kinds: %d of %d"] = "Види: %d з %d"
    L["The kind filter hides every item."] = "Фільтр видів приховує всі предмети."
    L["The kind filter hides the matches."] = "Фільтр видів приховує збіги."
    L["Sort: %s"] = "Сортування: %s"
    L["Name"] = "Назва"
    L["No price"] = "Без ціни"

    -- Auctionator as a price source (specs/019-auctionator-prices): Auction.lua, Settings.lua, StatsFrame.lua
    L["Prices come from Auctionator."] = "Ціни беруться з Auctionator."
    L["Auction prices"] = "Ціни аукціону"
    L["Take prices from Auctionator"] = "Брати ціни з Auctionator"
    L["Auctionator is not installed."] = "Auctionator не встановлено."
    L["Auctionator failed this session: the addon's own scan is in use."] =
        "Auctionator дав збій у цій сесії: використовується власне сканування аддона."
    L["Prices come from the addon's own scan (last scan %s)."] =
        "Ціни беруться з власного сканування аддона (останнє сканування: %s)."
    L["Prices come from the addon's own scan (no scan yet)."] =
        "Ціни беруться з власного сканування аддона (сканування ще не було)."
    L["Auction prices are off: catch values use vendor prices."] =
        "Ціни аукціону вимкнено: вартість улову рахується за цінами торговця."
    L["Your catches: %d priced by Auctionator, %d by the addon's scan, %d at vendor price, %d without a price."] =
        "Ваш улов: %d з ціною Auctionator, %d з ціною сканування аддона, %d лише з ціною торговця, %d без ціни."
    L["Values: higher of vendor and Auctionator price."] = "Вартість: більша з ціни торговця та Auctionator."
    L["%d of your catches have no Auctionator price: run its scan."] =
        "Для %d предметів вашого улову немає ціни в Auctionator: запустіть його сканування."

    -- Camp bonus tag and filter values (specs/020-camp-buffs): Catalog.lua
    L["Fishing Rack bonus"] = "Бонус рами"
    L["Fishing Hut bonus"] = "Бонус хижки"
    L["Bonus catch: comes only with the buff of a Fishing Rack (Uncommon Fishing)."] =
        "Бонусний улов: ловиться лише з бафом рибальської рами (Ловля незвичайної риби)."
    L["Bonus catch: comes only with the buff of a Fishing Hut (Rare Fishing)."] =
        "Бонусний улов: ловиться лише з бафом рибальської хижки (Ловля рідкісної риби)."
    L["Bonus catch: comes only with the buff of a Fishing Rack or a Fishing Hut."] =
        "Бонусний улов: ловиться лише з бафом рибальської рами або хижки."
    L["%s with the bonus"] = "%s із бонусом"
    L["All catches"] = "Усі улови"
    L["No camp bonus"] = "Без табірного бонусу"
    L["Fishing Rack"] = "Рибальська рама"
    L["Fishing Hut"] = "Рибальська хижка"

    -- The Camp bonus filter button (specs/020-camp-buffs): CatchHere.lua, CatalogTab.lua
    L["Camp bonus"] = "Табірний бонус"
    L["Show the catches made with a camp bonus: the fishing buff of a Fishing Rack or a Fishing Hut by a campfire."] =
        "Показати улови з табірним бонусом: рибальським бафом від рами чи хижки, поставленої біля вогнища."
    L["\"No camp bonus\" also holds older catches for which the bonus is not known."] =
        "«Без табірного бонусу» містить і давніші улови, для яких бонус невідомий."

    -- The camp bonus notices and their setting (specs/020-camp-buffs): Camp.lua, Settings.lua
    L["The Fishing Rack bonus ends in 5 minutes."] = "Бонус рибальської рами закінчиться за 5 хвилин."
    L["The Fishing Rack bonus has ended."] = "Бонус рибальської рами закінчився."
    L["The Fishing Hut bonus ends in 5 minutes."] = "Бонус рибальської хижки закінчиться за 5 хвилин."
    L["The Fishing Hut bonus has ended."] = "Бонус рибальської хижки закінчився."
    L["Warn when a camp bonus is ending"] = "Попереджати про кінець табірного бонусу"

    -- The camp bonus rows of the statistics (specs/020-camp-buffs): StatsFrame.lua
    L["Casts with a camp bonus"] = "Закидання з табірним бонусом"
    L["Bonus catches"] = "Бонусні улови"

    -- The Camp bonus button and Bonus catches only (spec 020 follow-up): Catalog.lua, CatchHere.lua
    L["Bonus catches only"] = "Тільки бонусні улови"
    L["Camp bonus: All"] = "Табірний бонус: Усі"
    L["Camp bonus: No bonus"] = "Табірний бонус: Без бонусу"
    L["Camp bonus: Bonus only"] = "Табірний бонус: Бонусні"
    L["Camp bonus: Rack"] = "Табірний бонус: Рама"
    L["Camp bonus: Hut"] = "Табірний бонус: Хижка"
    L["No bonus catch has been recorded here yet."] = "Бонусних уловів тут ще не було."
    L["No bonus catch has been recorded yet."] = "Бонусних уловів ще не було."

    -- Import and export (specs/027-import-export): UI/TransferPage.lua
    L["Import and export"] = "Імпорт і експорт"
    L["Import"] = "Імпортувати"
    L["Import a string"] = "Імпорт рядка"
    L["Export my data"] = "Експорт моїх даних"
    L["Move catch data between players without both being online: export it, send the text, import it."] =
        "Обмін даними улову між гравцями без одночасного онлайну: експортуйте, надішліть текст, імпортуйте."
    L["Imported data counts even with the shared database off."] =
        "Імпортовані дані враховуються навіть із вимкненою спільною базою."
    L["Data you imported still counts."] = "Імпортовані дані все одно враховуються."
    L["Preparing..."] = "Підготовка..."
    L["Nothing to export yet: catch some fish first."] = "Поки нічого експортувати: спершу щось упіймайте."
    L["Your own data is still being prepared: choose Export my data again in a minute."] =
        "Ваші власні дані ще готуються: за хвилину знову виберіть «Експорт моїх даних»."
    L["%d records, %d KB. Press Ctrl+C to copy, then paste it where the other player can read it."] =
        "Записів: %d, %d КБ. Скопіюйте Ctrl+C і вставте туди, де інший гравець зможе це прочитати."
    L["It holds anonymous IDs and catch counts per place, no names."] =
        "Містить лише анонімні ID і кількість улову за місцями, без імен."
    L["Importing: %d of %d records checked..."] = "Імпорт: перевірено %d з %d записів..."
    L["Paste a string with Ctrl+V, then press Import."] = "Вставте текст через Ctrl+V і натисніть «Імпортувати»."
    L["Pasted %d KB. Press Import."] = "Вставлено %d КБ. Натисніть «Імпортувати»."
    L["No catch data found in the text."] = "У тексті немає даних улову."
    L["The text is incomplete: copy the whole string again."] = "Текст неповний: скопіюйте весь рядок ще раз."
    L["This string comes from a newer version of the addon: update OneKeyFishing."] =
        "Цей рядок із новішої версії аддона: оновіть OneKeyFishing."
    L["The text is damaged: copy the whole string again."] = "Текст пошкоджено: скопіюйте весь рядок ще раз."
    L["Imported: %d new, %d already known, %d your own, %d refused."] =
        "Імпортовано: нових %d, уже відомих %d, ваших %d, відхилено %d."
end)
