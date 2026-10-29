-- Korean translation. Keys are the English texts of Locales/enUS.lua.
local _, ns = ...

ns.AddTranslation("koKR", "한국어", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "낚시 동작 (던지기 / 낚아채기)"
    L["Toggle fishing mode"] = "낚시 모드 전환"
    L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] =
        "저장된 데이터가 더 새로운 버전의 OneKeyFishing에서 만들어졌습니다. 문제를 피하려면 애드온을 업데이트하세요."
    L["Your game client has no translation, so the addon is in English. Others, such as %s, are in /okf config."] =
        "게임 클라이언트에 맞는 번역이 없어 애드온이 영어로 표시됩니다. " ..
        "%s 등 다른 언어는 /okf config에서 고를 수 있습니다."

    -- Gear.lua
    L["Fishing pole set."] = "낚싯대를 지정했습니다."
    L["This item cannot be used as fishing gear."] = "이 아이템은 낚시 장비로 사용할 수 없습니다."
    L["Already in the list."] = "이미 목록에 있습니다."
    L["Added."] = "추가했습니다."
    L["Fishing pole: automatic (best in bags)."] = "낚싯대: 자동 (가방에서 가장 좋은 것)."
    L["Removed from fishing gear."] = "낚시 장비에서 제거했습니다."
    L["No fishing pole found in your bags."] = "가방에 낚싯대가 없습니다."
    L["%d fishing item(s) are not in your bags."] = "낚시 장비 %d개가 가방에 없습니다."
    L["No free bag space to take off %s."] = "가방에 빈 칸이 없어 벗을 수 없습니다: %s."
    L["an item"] = "아이템"

    -- Bags.lua
    L["Cannot apply %s, skipping it until fishing mode is turned on again."] =
        "%s을(를) 사용할 수 없습니다. 낚시 모드를 다시 켤 때까지 건너뜁니다."
    L["Not enough bag space to loot %s. It will be opened again when you free a bag slot."] =
        "가방 공간이 부족해 %s의 내용물을 획득할 수 없습니다. 가방 칸을 비우면 다시 엽니다."
    L["Cannot open %s, skipping it for this session."] = "%s을(를) 열 수 없습니다. 이번 세션 동안 건너뜁니다."

    -- Action.lua
    L["You have not learned Fishing."] = "낚시를 배우지 않았습니다."
    L["No key is bound to 'Fishing action'. Bind one in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
        "'낚시 동작'에 지정된 키가 없습니다. 설정 -> 단축키 -> 애드온 -> OneKeyFishing에서 지정하세요."

    -- Mode.lua
    L["Cannot enter fishing mode in combat."] = "전투 중에는 낚시 모드를 켤 수 없습니다."
    L["Fishing mode %s."] = "낚시 모드 %s."
    L["ON"] = "켜짐"
    L["OFF"] = "꺼짐"
    L["Restored game settings from an unfinished fishing session."] = "끝나지 않은 낚시 세션의 게임 설정을 복원했습니다."
    L["Fishing mode is off. Press your 'Toggle fishing mode' key first."] =
        "낚시 모드가 꺼져 있습니다. 먼저 '낚시 모드 전환' 키를 누르세요."
    L["The fishing key is paused in combat."] = "전투 중에는 낚시 키가 일시 중지됩니다."
    L["Leaving fishing mode after combat."] = "전투가 끝나면 낚시 모드를 종료합니다."

    -- Auction.lua
    L["Scanning %d/%d"] = "검색 중 %d/%d"
    L["Scan fish prices"] = "물고기 가격 검색"
    L["Auction scan finished: %d of %d price(s) found."] = "경매장 검색 완료: %d/%d개 가격 확인."
    L["Open the auction house first."] = "먼저 경매장을 여세요."
    L["Nothing to scan yet: catch some fish first."] = "아직 검색할 것이 없습니다. 먼저 물고기를 낚으세요."
    L["Scanning auction prices of %d item(s)..."] = "아이템 %d개의 경매장 가격 검색 중..."
    L["Auction scan stopped: %d of %d price(s) found."] = "경매장 검색 중지: %d/%d개 가격 확인."

    -- Skill.lua
    L["Apprentice"] = "수습"
    L["Journeyman"] = "숙련"
    L["Expert"] = "전문"
    L["Artisan"] = "장인"
    L["Any fishing trainer teaches it (capitals and towns; the minimap can track trainers)."] =
        "모든 낚시 전문기술 상급자에게 배울 수 있습니다 (수도와 마을, 미니맵에서 상급자 추적 가능)."
    L["Buy the book \"%s\" from %s in %s, %s."] = "'%s' 책을 %s에게서 구입하세요 (%s, %s)."
    L["Do the quest \"%s\" from %s at %s, %s."] = "퀘스트 '%s'를 완료하세요. 퀘스트 제공: %s (%s, %s)."
    L["%s Fishing needs character level %d."] = "%s 낚시는 캐릭터 레벨 %d이(가) 필요합니다."
    L["Map pin"] = "지도 핀"
    L["Fishing skill capped (%d/%d): learn %s Fishing to go on."] = "낚시 숙련도가 최대입니다 (%d/%d). 계속하려면 %s 낚시를 배우세요."
    L["You can learn %s Fishing now."] = "이제 %s 낚시를 배울 수 있습니다."
    L["Next rank: %s Fishing, from skill %d."] = "다음 등급: %s 낚시, 숙련도 %d부터."
    L["Next rank: %s Fishing, from skill %d and character level %d."] = "다음 등급: %s 낚시, 숙련도 %d 및 캐릭터 레벨 %d부터."
    L["Next rank: %s Fishing, from character level %d."] = "다음 등급: %s 낚시, 캐릭터 레벨 %d부터."
    L["Next rank: %s Fishing, ready to learn."] = "다음 등급: %s 낚시, 지금 배울 수 있습니다."

    -- UI/CopyWindow.lua
    L["Click the text, then Ctrl+A and Ctrl+C to copy."] = "텍스트를 클릭한 후 Ctrl+A, Ctrl+C로 복사하세요."

    -- UI/Indicator.lua
    L["Cast"] = "던지기"
    L["Hook!"] = "낚아채기!"
    L["Apply lure"] = "미끼 사용"
    L["Open"] = "열기"
    L["No bobber"] = "찌 없음"
    L["Drag to move. Lock it in the settings."] = "끌어서 이동합니다. 설정에서 고정할 수 있습니다."

    -- UI/Toast.lua
    L["Caught: %s"] = "낚음: %s"
    L["Nothing caught"] = "아무것도 낚지 못함"

    -- UI/MapPin.lua
    L["The game did not accept the map pin."] = "게임이 지도 핀을 받아들이지 않았습니다."
    L["Map pin: %s"] = "지도 핀: %s"
    L["Replace your map pin with this place?"] = "지도 핀을 이 장소로 바꾸시겠습니까?"
    L["Replace"] = "바꾸기"

    -- UI/StatsFrame.lua
    L["Pin"] = "핀"
    L["Time fishing"] = "낚시 시간"
    L["Time casting"] = "찌 대기 시간"
    L["Casts"] = "던진 횟수"
    L["Catches"] = "어획"
    L["Catches per hour"] = "시간당 어획"
    L["Value"] = "가치"
    L["Gold per hour"] = "시간당 골드"
    L["OneKeyFishing - Statistics"] = "OneKeyFishing - 통계"
    L["Session"] = "세션"
    L["This zone"] = "현재 지역"
    L["All time"] = "전체"
    L["Top catches (all time)"] = "주요 어획 (전체)"
    L["Zones (all time)"] = "지역 (전체)"
    L["Reset session"] = "세션 초기화"
    L["Reset the fishing statistics of this session?"] = "이번 세션의 낚시 통계를 초기화하시겠습니까?"
    L["Reset all"] = "모두 초기화"
    L["Delete ALL fishing statistics of this character?"] = "이 캐릭터의 낚시 통계를 모두 삭제하시겠습니까?"
    L["Scan auction prices"] = "경매장 가격 검색"
    L["Fishing skill: %d/%d %s%s"] = "낚시 숙련도: %d/%d %s%s"
    L["(+%d this session)"] = "(이번 세션 +%d)"
    L["Fishing is not learned."] = "낚시를 배우지 않았습니다."
    L["Values: higher of vendor and auction price (scanned %s)"] =
        "가치: 상점 판매가와 경매장 가격 중 높은 값 (검색: %s)"
    L["%dm"] = "%d분"
    L["%dh %02dm"] = "%d시간 %02d분"
    L["Values: vendor price (scan the auction house for market prices)"] =
        "가치: 상점 판매가 (시세를 보려면 경매장을 검색하세요)"
    L["%d catches, %s"] = "어획 %d회, %s"
    L["No catches yet."] = "아직 어획이 없습니다."
    L["Time"] = "시간"
    L["Results"] = "결과"
    L["Money"] = "골드"
    L["Refresh"] = "새로고침"
    L["Time in fishing mode. Paused while AFK if that option is on."] =
        "낚시 모드로 보낸 시간입니다. 해당 옵션이 켜져 있으면 자리 비움 중에는 멈춥니다."
    L["Time with the bobber in the water."] = "찌가 물에 떠 있던 시간입니다."
    L["Fishing casts made in fishing mode."] = "낚시 모드에서 던진 횟수입니다."
    L["Casts that brought loot."] = "전리품을 얻은 던지기입니다."
    L["Casts that ended without loot."] = "전리품 없이 끝난 던지기입니다."
    L["Catches per hour of fishing time. Updated with every cast and with Refresh."] =
        "낚시 시간 1시간당 어획입니다. 던질 때마다, 그리고 새로고침할 때 갱신됩니다."
    L["Items caught, at the higher of vendor and auction price; with few lots listed, the vendor price."] =
        "낚은 아이템의 가치입니다. 상점 판매가와 경매장 가격 중 높은 값으로 계산하며, 매물이 적으면 상점 판매가를 씁니다."
    L["Value per hour of fishing time. Updated with every cast and with Refresh."] =
        "낚시 시간 1시간당 가치입니다. 던질 때마다, 그리고 새로고침할 때 갱신됩니다."

    -- UI/CatchHere.lua and the tabs of UI/StatsFrame.lua
    L["Statistics"] = "통계"
    L["What can be caught here"] = "여기서 낚이는 것"
    L["Skill: %s"] = "숙련도: %s"
    L["All skill levels"] = "모든 숙련도"
    L["Source: %s"] = "출처: %s"
    L["All"] = "전체"
    L["Only mine"] = "내 것만"
    L["%d catches"] = "어획 %d회"
    L["Nothing caught: %s"] = "아무것도 낚지 못함: %s"
    L["Numbers for the whole map: few catches at this spot."] = "지도 전체 수치: 이 지점의 어획이 적습니다."
    L["Little data"] = "데이터 부족"
    L["Nothing has been caught here yet."] = "아직 여기서 낚은 것이 없습니다."
    L["Try \"All skill levels\": little data for your skill."] = "'모든 숙련도'를 선택해 보세요: 현재 숙련도의 데이터가 부족합니다."
    L["and %d more"] = "외 %d개"
    L["No bundled data in this version: only your own catches are shown."] = "이 버전에는 기본 제공 데이터가 없습니다: 내 어획만 표시됩니다."
    L["The game does not show this place on the map."] = "게임이 이 장소를 지도에 표시하지 않습니다."
    L["Item"] = "아이템"
    L["Chance"] = "확률"
    L["Per catch"] = "어획당"
    L["Price"] = "가격"


    -- Prices (the few-lots mark in both tabs)
    L["few lots"] = "매물 적음"
    L["Auction price: %s (few lots)"] = "경매장 가격: %s (매물 적음)"

    -- Debug.lua
    L["OneKeyFishing - debug report"] = "OneKeyFishing - 디버그 보고서"

    -- UI/Settings.lua
    L["Auto loot while fishing"] = "낚시 중 자동 획득"
    L["Show the interact icon over the bobber"] = "찌 위에 상호작용 아이콘 표시"
    L["Leave fishing mode when attacked"] = "공격받으면 낚시 모드 종료"
    L["Equip fishing pole and fishing gear"] = "낚싯대와 낚시 장비 착용"
    L["Apply lures automatically"] = "미끼 자동 사용"
    L["Open clams and fished containers"] = "대합과 낚은 상자 열기"
    L["Show the action indicator and cast timer"] = "동작 표시기와 던지기 타이머 표시"
    L["Lock the indicator position"] = "표시기 위치 고정"
    L["Show catch notifications"] = "어획 알림 표시"
    L["Show session fishing time under the indicator"] = "표시기 아래에 세션 낚시 시간 표시"
    L["Pause the fishing timer while AFK"] = "자리 비움 중 낚시 타이머 일시 중지"
    L["Remind me about the next Fishing rank"] = "다음 낚시 등급 알림"
    L["Use scanned auction prices for catch value"] = "어획 가치에 검색한 경매장 가격 사용"
    L["Zoom the camera while fishing"] = "낚시 중 카메라 확대"
    L["Show the minimap button"] = "미니맵 버튼 표시"
    L["not bound"] = "지정 안 됨"
    L["Keys"] = "키"
    L["Change them in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
        "설정 -> 단축키 -> 애드온 -> OneKeyFishing에서 변경하세요."
    L["WoW names punctuation keys (' ; [ , .) by keyboard language: bind them in both slots, once per language."] =
        "WoW는 문장 부호 키(' ; [ , .)를 키보드 언어에 따라 다르게 인식합니다. 언어마다 한 번씩, 두 칸 모두에 지정하세요."
    L["Features"] = "기능"
    L["Auto loot, bobber icon and gear changes apply the next time you enter fishing mode."] =
        "자동 획득, 찌 아이콘, 장비 변경은 다음에 낚시 모드를 켤 때 적용됩니다."
    L["Camera distance while fishing:"] = "낚시 중 카메라 거리:"
    L["Actions"] = "동작"
    L["Debug report"] = "디버그 보고서"
    L["Open statistics"] = "통계 열기"
    L["Reset indicator position"] = "표시기 위치 초기화"
    L["(open the auction house first)"] = "(먼저 경매장을 여세요)"
    L["Fishing action: %s      Toggle fishing mode: %s"] = "낚시 동작: %s      낚시 모드 전환: %s"
    L["Remove"] = "제거"
    L["Fishing gear"] = "낚시 장비"
    L["Fishing pole"] = "낚싯대"
    L["Use the best pole automatically"] = "가장 좋은 낚싯대 자동 사용"
    L["Add an item"] = "아이템 추가"
    L["Easiest: close this window and Alt+Click an item in your bags or on the character panel."] =
        "가장 쉬운 방법: 이 창을 닫고 가방이나 캐릭터 창에서 아이템을 Alt+클릭하세요."
    L["Alt+Click it again to remove it. A fishing pole becomes your chosen pole."] =
        "다시 Alt+클릭하면 제거됩니다. 낚싯대는 선택한 낚싯대로 지정됩니다."
    L["Here you can type an item name, or find all items with a fishing bonus automatically."] =
        "여기에 아이템 이름을 입력하거나, 낚시 보너스가 있는 아이템을 모두 자동으로 찾을 수 있습니다."
    L["Item not found. Check the name, or Alt+Click the item in your bags."] =
        "아이템을 찾을 수 없습니다. 이름을 확인하거나 가방에서 아이템을 Alt+클릭하세요."
    L["Add"] = "추가"
    L["Find fishing items"] = "낚시 아이템 찾기"
    L["Added %d item(s)."] = "아이템 %d개를 추가했습니다."
    L["No new items with a fishing bonus found."] = "낚시 보너스가 있는 새 아이템이 없습니다."
    L["Extra fishing gear"] = "추가 낚시 장비"
    L["No items yet."] = "아직 아이템이 없습니다."
    L["Chosen: %s (+%d)"] = "선택됨: %s (+%d)"
    L["Automatic, best in your bags: %s (+%d)"] = "자동, 가방에서 가장 좋은 것: %s (+%d)"
    L["Automatic: no fishing pole in your bags."] = "자동: 가방에 낚싯대가 없습니다."
    L["Settings cannot be opened in combat."] = "전투 중에는 설정을 열 수 없습니다."
    L["Settings panel is not available in this client."] = "이 클라이언트에서는 설정 창을 사용할 수 없습니다."
    L["Language:"] = "언어:"
    L["Interface language"] = "인터페이스 언어"
    L["Game client language"] = "게임 클라이언트 언어"
    L["Korean and Chinese may show as squares on a game client in another language."] =
        "다른 언어의 게임 클라이언트에서는 한국어와 중국어가 네모로 표시될 수 있습니다."
    L["Pick English to get a readable interface back."] = "English를 선택하면 읽을 수 있는 인터페이스로 돌아갑니다."
    L["The language changes after reloading the interface."] = "언어는 인터페이스를 다시 불러온 후 바뀝니다."
    L["Reload now"] = "지금 다시 불러오기"
    L["Later"] = "나중에"
    L["Yes"] = "예"
    L["No"] = "아니요"
    L["Cancel"] = "취소"

    -- UI/ItemHooks.lua
    L["OneKeyFishing: fishing gear (Alt+Click to remove)"] = "OneKeyFishing: 낚시 장비 (Alt+클릭으로 제거)"
    L["OneKeyFishing: Alt+Click to add to fishing gear"] = "OneKeyFishing: Alt+클릭으로 낚시 장비에 추가"

    -- UI/Minimap.lua
    L["Pin: next Fishing rank"] = "핀: 다음 낚시 등급"
    L["Leave fishing mode"] = "낚시 모드 종료"
    L["Enter fishing mode"] = "낚시 모드 시작"
    L["Statistics"] = "통계"
    L["Settings"] = "설정"
    L["Fishing mode: %s"] = "낚시 모드: %s"
    L["Fishing skill: %d/%d %s"] = "낚시 숙련도: %d/%d %s"
    L["Session: %d catches, %s"] = "세션: 어획 %d회, %s"
    L["Fishing key:"] = "낚시 키:"
    L["Toggle mode key:"] = "모드 전환 키:"
    L["How to use: press the toggle key, then the fishing key to cast,"] =
        "사용법: 전환 키를 누른 다음, 낚시 키를 눌러 찌를 던지고,"
    L["and the same key again when the bobber splashes."] = "찌가 첨벙거리면 같은 키를 다시 누르세요."
    L["Alt+Click items in your bags to add fishing gear."] = "가방의 아이템을 Alt+클릭하면 낚시 장비에 추가됩니다."
    L["Left-click: toggle fishing mode"] = "왼쪽 클릭: 낚시 모드 전환"
    L["Shift+Left-click: statistics"] = "Shift+왼쪽 클릭: 통계"
    L["Right-click: menu"] = "오른쪽 클릭: 메뉴"
    L["Drag: move this button"] = "끌기: 이 버튼 이동"

    -- Share.lua
    L["OneKeyFishing now shares your catches under a random ID with your guild, group and friends who use it."] =
        "이제 OneKeyFishing이 내 어획을 무작위 ID로 이 애드온을 쓰는 길드원, 파티원과 친구에게 공유합니다."
    L["No character names are sent, but the players you exchange with can tell which ID is yours."] =
        "캐릭터 이름은 보내지 않지만, 데이터를 교환하는 플레이어는 어떤 ID가 내 것인지 알 수 있습니다."
    L["Turn it off in Options -> AddOns -> OneKeyFishing -> Shared database."] =
        "설정 -> 애드온 -> OneKeyFishing -> 공유 데이터베이스에서 끌 수 있습니다."
    L["Got it"] = "확인"
    L["Shared database"] = "공유 데이터베이스"
    L["Shared catch database is off"] = "공유 어획 데이터베이스가 꺼져 있습니다"
    L["Waiting for you to read the notice"] = "안내를 읽을 때까지 기다리는 중"
    L["Exchange unavailable: the game refuses addon messages"] = "교환 불가: 게임이 애드온 메시지를 거부합니다"
    L["Exchange paused: in combat"] = "교환 일시 중지: 전투 중"
    L["Exchange paused: in an instance"] = "교환 일시 중지: 인스턴스 안"
    L["Exchange paused: loading screen"] = "교환 일시 중지: 로딩 화면"
    L["Exchange paused: the game restricts addon messages here"] = "교환 일시 중지: 이곳에서는 게임이 애드온 메시지를 제한합니다"
    L["Exchange paused: the game asked to slow down"] = "교환 일시 중지: 게임이 속도를 줄이라고 요청했습니다"
    L["Nobody to exchange with right now"] = "지금은 교환할 상대가 없습니다"
    L["Exchange: %d players, %s ago"] = "교환: %d명, %s 전"
    L["Exchange: waiting for the first exchange"] = "교환: 첫 교환을 기다리는 중"
    L["Bundled data: version %d, %d places"] = "기본 데이터: 버전 %d, 장소 %d곳"
    L["Records held: %d, %d places"] = "보유한 기록: %d개, 장소 %d곳"
    L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d"] =
        "지난 1시간 동안 확인된 플레이어: 길드 %d, 파티 %d, 친구 %d, Battle.net %d"
    L["Players exchanged with in the last hour: %d"] = "지난 1시간 동안 교환한 플레이어: %d"
    L["Last exchange: %s ago"] = "마지막 교환: %s 전"
    L["Last exchange: none yet"] = "마지막 교환: 아직 없음"
    L["Traffic in the last hour: %d KB"] = "지난 1시간 트래픽: %d KB"

    -- UI/Settings.lua: the Shared database page
    L["Use the shared catch database"] = "공유 어획 데이터베이스 사용"
    L["Your catches (items, counts, map cells, the average spot you fish from) are shared under a random ID."] =
        "내 어획(아이템, 수량, 지도 칸, 낚시한 평균 위치)은 무작위 ID로 공유됩니다."
    L["They go to addon users in your guild, group and friends list. No names or gear."] =
        "길드, 파티와 친구 목록의 애드온 사용자에게 전달됩니다. 이름과 장비는 보내지 않습니다."
    L["The players you exchange with can tell which ID is yours."] = "데이터를 교환하는 플레이어는 어떤 ID가 내 것인지 알 수 있습니다."
    L["Turned off: nothing is sent or received, and other players' data is not counted."] =
        "끄면: 아무것도 보내거나 받지 않으며, 다른 플레이어의 데이터는 계산하지 않습니다."

    -- UI/CatchHere.lua: other players' catches
    L["%d catches from %d players"] = "어획 %d회, 플레이어 %d명"
end)
