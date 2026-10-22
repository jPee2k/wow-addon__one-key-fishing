# OneKeyFishing — план MVP

## Контекст
Особистий аддон лише для WoW Forever: риболовля однією клавішею без миші й без ботів, кожна дія = натискання гравця. Публікації немає. Код у `D:\projects\dev\wow\addons\OneKeyFishing` (локальний git, без remote). Тестування — на бета-клієнті; аддон у папку гри користувач переносить сам.
Клієнт: `D:\Games\World of Warcraft\_forever_`, build `1.60.1.70532`, модерний (Mainline) API. Мова аддону — англійська.

## Результати спайку API (етап 0, build 1.60.1.70450)
- Interface `16001` підтверджено, `WOW_PROJECT_ID = 18`. Клієнт **ruRU** → усе шукаємо лише за ID, ніколи за назвами.
- `INTERACTTARGET` є. CVar `SoftTargetInteract`, `SoftTargetIconGameObject`, `SoftTargetIconInteract`, `autoLootDefault` є.
- Fishing — ранги-заклинання 7620 / 7731 / 7732 / 18248; скіл через `GetProfessions` + `GetProfessionInfo` (skillLine 356), `GetSkillLineInfo` відсутній. Кап рангу видно як `maxRank` (74/150 на Journeyman).
- Вудка: `classID 2`, `subclassID 20` (`Enum.ItemWeaponSubclass.Fishingpole`). Наживка — `GetWeaponEnchantInfo`.
- Відсутні: `GetSpellInfo`, `GetItemInfo`, `EquipItemByName`, класичний API аукціону. Використовуємо `C_Spell.*`, `C_Item.GetItemInfo`, `C_Item.EquipItemByName`, `C_AuctionHouse.*`. Є `C_EquipmentSet`, `MenuUtil`, `Settings`, `AddonCompartmentFrame`, усі потрібні secure-шаблони.

## Стек
- Чистий Lua 5.1 + XML лише для `Bindings.xml`. **Без бібліотек** (ні Ace3, ні LibDBIcon): аддон невеликий і особистий.
- Нативний Settings API (Esc → Options → AddOns).
- `luacheck` з `.luacheckrc` (globals WoW API), `.gitignore`.
- SavedVariables: `OneKeyFishingDB` (налаштування, статистика, ціни), `OneKeyFishingCharDB` (сети спорядження персонажа).

## Структура
```
OneKeyFishing/
  OneKeyFishing.toc      ## Interface: 16001 (перевірити), SavedVariables, AddonCompartmentFunc
  Bindings.xml           дві дії: Fishing action, Toggle fishing mode
  Core.lua               namespace, події, дефолти DB, /okf (/fish)
  Mode.lua               вхід/вихід з режиму, збереження/відновлення CVar
  Action.lua             secure-кнопка + secure handler для клавіші, пріоритети дії
  Bags.lua               пошук наживки, кламів/контейнерів, вудки
  Gear.lua               запам'ятати поточний одяг → одягти fishing set → повернути
  Camera.lua             zoom під риболовлю і відновлення
  Stats.lua              закиди, улов, зриви, зони, риба/год
  Skill.lua              скіл Fishing, кап рангу, сповіщення «вивчи наступний ранг»
  Prices.lua             ціна вендора + скан аукціону для риби
  UI/Indicator.lua       іконка дії біля центру + таймер закиду (перетягувана)
  UI/Toast.lua           сповіщення про улов над індикатором
  UI/StatsFrame.lua      вікно статистики
  UI/Minimap.lua         кнопка біля мінікарти + тултіп
  UI/Settings.lua        панель налаштувань
  .luacheckrc  .gitignore  CLAUDE.md
```

## Ключові механізми
- **Клавіші.** `Bindings.xml` дає дві дії в меню Key Bindings. Клавіша дії поза режимом нічого не робить (виділена). У режимі аддон читає `GetBindingKey(...)` і ставить override-прив'язки на ці клавіші.
- **Одна клавіша.** Override належить фрейму на `SecureHandlerStateTemplate`:
  - поза каналом → `CLICK OneKeyFishingButton`; `PreClick` (поза боєм) вибирає дію за пріоритетом: **немає наживки** (`GetWeaponEnchantInfo`) → `type=item, target-slot=16`; **клам/контейнер у сумці** → `type=item` (bag slot); інакше → `type=spell` Fishing;
  - `UNIT_SPELLCAST_CHANNEL_START` (Fishing) → клавіша = `INTERACTTARGET`; `CHANNEL_STOP` → назад на кнопку.
  - стан-драйвер `[combat]` знімає прив'язки прямо в бою (secure snippet), після `PLAYER_REGEN_ENABLED` — повний вихід з режиму.
- **Режим** (клавіша-перемикач / мінікарта / `/okf`): зберегти й виставити CVar (`autoLootDefault`, `SoftTargetInteract`, `SoftTargetIconGameObject`/`SoftTargetIconInteract`), одягнути сет, камера; при виході все відновити рівно як було.
- **Спорядження.** Перший вхід: користувач одягає риболовне й робить `/okf saveset` (або кнопка в налаштуваннях). Далі вхід = запам'ятати поточне по слотах → `EquipItemByName` сету; вихід/атака = повернути запам'ятоване.
- **Статистика.** `LOOT_READY` + `IsFishingLoot()` → улов; канал без луту → зрив. Ключ: `C_Map.GetBestMapForUnit` + subzone. Сесія + історія по зонах, прогрес скіла.
- **Таймер часу на риболовлю.** Два лічильники: *час у режимі* (від входу до виходу) і *чистий час закидів* (сума тривалостей каналу Fishing). Рахуються для поточної сесії, по кожній зоні та загалом; зберігаються в DB і переживають `/reload`/релог (незавершений відрізок дописується на `PLAYER_LOGOUT`). Пауза при AFK (`PLAYER_FLAGS_CHANGED` + `UnitIsAFK`) — налаштовується. Риба/год і золото/год рахуються від часу в режимі. Живий таймер (`hh:mm:ss`) — у вікні статистики, тултіпі мінікарти й опційно під індикатором.
- **Ціни.** `C_Item.GetItemInfo` → sellPrice; на аукціоні кнопка «Scan fish» сканує лише предмети зі статистики (API аукціону Forever — перевірити).
- **Мінікарта.** Власна кнопка, перетягувана по колу. ЛКМ: режим, ПКМ: налаштування, Shift+ЛКМ: статистика. Тултіп: стан, призначені клавіші, коротка інструкція. Плюс Addon Compartment, якщо є.
- **Налаштування (усе вмикається/вимикається):** autoloot, іконка над поплавком, наживка, клами, спорядження, камера (+ дистанція), вихід при атаці, індикатор (+ lock), тости, кнопка мінікарти, сповіщення про кап скіла, таймер під індикатором, пауза таймера при AFK.
- **Усі команди доступні з меню, чат не потрібен.** Slash-команди лишаються лише як дубль.
  - Панель налаштувань, секція *Actions*: кнопки Toggle fishing mode, Save current gear as fishing set, Clear fishing set, Open statistics, Reset session / Reset all stats (з підтвердженням), Scan auction (активна лише коли відкритий аукціон), Run API check (debug-звіт у вікні з копіюванням), Reset indicator position.
  - ПКМ по кнопці мінікарти → контекстне меню (`MenuUtil.CreateContextMenu`) з тими самими діями + Settings; ЛКМ — режим, Shift+ЛКМ — статистика.
  - У вікні статистики — кнопки Reset session / Scan auction.
- **Сповіщення про кап професії.** Модуль `Skill.lua`: на `SKILL_LINES_CHANGED` / `CHAT_MSG_SKILL`, при вході в гру й у режим читає поточний і максимальний скіл Fishing. Якщо `rank == max` і `max` < глобального капу → великий тост + повідомлення «Fishing skill capped (150/150) — learn the next rank» з підказкою, де вчити (таблиця рангів Apprentice 75 / Journeyman 150 / Expert 225 / Artisan 300, тренер / книга / квест — уточнити для Forever). Попередження заздалегідь за N пунктів до капу (налаштовується). Показ один раз на кап, повтор при вході в режим, доки ранг не вивчено. Стан і прогрес також у тултіпі мінікарти та у вікні статистики.

## Етапи
0. **Спайк API** — `git init`, TOC, `/okf debug`, що друкує: interface version, наявність `INTERACTTARGET`, soft-target CVar, ID/назву Fishing, `C_EquipmentSet`, `AddonCompartmentFrame`, `IsFishingLoot`, `GetWeaponEnchantInfo`, `C_AuctionHouse`, `MenuUtil`, API скілів професій (`GetProfessions`/`GetProfessionInfo` чи `GetSkillLineInfo`) з поточним і макс. рангом Fishing. Перевірити на беті → підкоригувати план.
1. Режим + одна клавіша (закид/підсікання) + autoloot + відновлення CVar + безпека в бою.
2. Індикатор, таймер, тости, іконка над поплавком.
3. Спорядження, наживка, клами.
4. Статистика + таймер часу + ціна вендора + вікно статистики + сповіщення про кап скіла.
5. Скан аукціону.
6. Налаштування з секцією Actions, мінікарта з контекстним меню, камера, CLAUDE.md.

## Перевірка
- `luacheck .` без помилок після кожного етапу.
- Ручний чекліст на беті після кожного етапу: `/reload` без Lua errors; вхід/вихід з режиму повертає CVar, одяг, камеру, прив'язки; повний цикл закид → підсікання → лут однією клавішею; атака під час риболовлі не ламає клавіші; статистика й таймер переживають `/reload` і релог, таймер стоїть поза режимом і під час AFK; кожна дія з меню (налаштування й мінікарта) працює без жодної slash-команди; на капі рангу з'являється сповіщення і зникає після вивчення наступного рангу.
