-- Korean translation. Keys are the English texts of Locales/enUS.lua.
local _, ns = ...

ns.AddTranslation("koKR", "한국어", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "낚시 동작 (던지기 / 낚아채기)"
    L["Toggle fishing mode"] = "낚시 모드 전환"
    L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] =
        "저장된 데이터가 더 새로운 버전의 OneKeyFishing에서 만들어졌습니다. 문제를 피하려면 애드온을 업데이트하세요."
    L["v%s commands:"] = "v%s 명령어:"

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
    L["enter or leave fishing mode"] = "낚시 모드 켜기 또는 끄기"

    -- Auction.lua
    L["Scanning %d/%d"] = "검색 중 %d/%d"
    L["Scan fish prices"] = "물고기 가격 검색"
    L["Auction scan finished: %d of %d price(s) found."] = "경매장 검색 완료: %d/%d개 가격 확인."
    L["Open the auction house first."] = "먼저 경매장을 여세요."
    L["Nothing to scan yet: catch some fish first."] = "아직 검색할 것이 없습니다. 먼저 물고기를 낚으세요."
    L["Scanning auction prices of %d item(s)..."] = "아이템 %d개의 경매장 가격 검색 중..."
    L["Auction scan stopped: %d of %d price(s) found."] = "경매장 검색 중지: %d/%d개 가격 확인."
    L["scan auction prices of caught items (auction house must be open)"] =
        "낚은 아이템의 경매장 가격 검색 (경매장이 열려 있어야 함)"

    -- Skill.lua
    L["Apprentice"] = "수습"
    L["Journeyman"] = "숙련"
    L["Expert"] = "전문"
    L["Artisan"] = "장인"
    L["a fishing trainer"] = "낚시 전문기술 상급자"
    L["the book \"Expert Fishing - The Bass and You\" (Old Man Heming, Booty Bay)"] =
        "책 \"Expert Fishing - The Bass and You\" (Old Man Heming, 무법항)"
    L["the quest from Nat Pagle (Dustwallow Marsh)"] = "내트 페글의 퀘스트 (먼지진흙 습지대)"
    L["Fishing skill capped (%d/%d): learn %s Fishing from %s."] =
        "낚시 숙련도가 최대입니다 (%d/%d). %s 낚시를 배우세요. 배울 곳: %s."
    L["Fishing %d/%d: %d point(s) left in this rank. Next: %s Fishing from %s."] =
        "낚시 %d/%d: 이 등급에서 %d점 남음. 다음: %s 낚시, 배울 곳: %s."

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

    -- UI/StatsFrame.lua
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
    L["show the fishing statistics"] = "낚시 통계 보기"
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
    L["Items caught, at the higher of the vendor price and the last scanned auction price."] =
        "낚은 아이템의 가치입니다. 상점 판매가와 마지막으로 검색한 경매장 가격 중 높은 값으로 계산합니다."
    L["Value per hour of fishing time. Updated with every cast and with Refresh."] =
        "낚시 시간 1시간당 가치입니다. 던질 때마다, 그리고 새로고침할 때 갱신됩니다."

    -- Debug.lua
    L["OneKeyFishing - debug report"] = "OneKeyFishing - 디버그 보고서"
    L["show a report to copy into a bug report"] = "버그 제보에 붙여 넣을 보고서 보기"

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
    L["Warn when the Fishing rank is capped"] = "낚시 숙련도가 등급 최대치에 도달하면 경고"
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
    L["open the settings"] = "설정 열기"
    L["Language:"] = "언어:"
    L["Interface language"] = "인터페이스 언어"
    L["Game client language"] = "게임 클라이언트 언어"
    L["Korean and Chinese may show as squares on a game client in another language."] =
        "다른 언어의 게임 클라이언트에서는 한국어와 중국어가 네모로 표시될 수 있습니다."
    L["Pick English to get a readable interface back."] = "English를 선택하면 읽을 수 있는 인터페이스로 돌아갑니다."
    L["The language changes after reloading the interface."] = "언어는 인터페이스를 다시 불러온 후 바뀝니다."
    L["Reload now"] = "지금 다시 불러오기"
    L["Later"] = "나중에"

    -- UI/ItemHooks.lua
    L["OneKeyFishing: fishing gear (Alt+Click to remove)"] = "OneKeyFishing: 낚시 장비 (Alt+클릭으로 제거)"
    L["OneKeyFishing: Alt+Click to add to fishing gear"] = "OneKeyFishing: Alt+클릭으로 낚시 장비에 추가"

    -- UI/Minimap.lua
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
end)
