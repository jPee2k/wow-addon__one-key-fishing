-- Brazilian Portuguese translation. Keys are the English texts of Locales/enUS.lua.
local _, ns = ...

ns.AddTranslation("ptBR", "Português", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "Ação de pesca (lançar / fisgar)"
    L["Toggle fishing mode"] = "Ativar/desativar modo de pesca"
    L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] =
        "Seus dados salvos vêm de uma versão mais nova do OneKeyFishing. Atualize o addon para evitar problemas."
    L["Your game client has no translation, so the addon is in English. Others, such as %s, are in /okf config."] =
        "Não há tradução para o seu cliente do jogo, então o addon está em inglês. " ..
        "Outros idiomas, como %s, estão em /okf config."

    -- Gear.lua
    L["Fishing pole set."] = "Vara de pesca definida."
    L["This item cannot be used as fishing gear."] = "Este item não pode ser usado como equipamento de pesca."
    L["Already in the list."] = "Já está na lista."
    L["Added."] = "Adicionado."
    L["Fishing pole: automatic (best in bags)."] = "Vara de pesca: automática (a melhor nas bolsas)."
    L["Removed from fishing gear."] = "Removido do equipamento de pesca."
    L["No fishing pole found in your bags."] = "Nenhuma vara de pesca encontrada nas suas bolsas."
    L["%d fishing item(s) are not in your bags."] = "%d item(ns) de pesca não está(ão) nas suas bolsas."
    L["No free bag space to take off %s."] = "Sem espaço livre nas bolsas para remover %s."
    L["an item"] = "um item"

    -- Bags.lua
    L["Cannot apply %s, skipping it until fishing mode is turned on again."] =
        "Não foi possível aplicar %s; será ignorado até o modo de pesca ser ativado novamente."
    L["Not enough bag space to loot %s. It will be opened again when you free a bag slot."] =
        "Sem espaço nas bolsas para saquear %s. Será aberto novamente quando você liberar um espaço."
    L["Cannot open %s, skipping it for this session."] = "Não foi possível abrir %s; será ignorado nesta sessão."

    -- Action.lua
    L["You have not learned Fishing."] = "Você não aprendeu Pesca."
    L["No key is bound to 'Fishing action'. Bind one in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
        "Nenhuma tecla atribuída a 'Ação de pesca'. Atribua uma em Opções -> Teclas de Atalho -> AddOns -> " ..
        "OneKeyFishing."

    -- Mode.lua
    L["Cannot enter fishing mode in combat."] = "Não é possível entrar no modo de pesca em combate."
    L["Fishing mode %s."] = "Modo de pesca %s."
    L["ON"] = "ATIVADO"
    L["OFF"] = "DESATIVADO"
    L["Restored game settings from an unfinished fishing session."] =
        "Configurações do jogo restauradas de uma sessão de pesca não finalizada."
    L["Fishing mode is off. Press your 'Toggle fishing mode' key first."] =
        "O modo de pesca está desativado. Pressione primeiro a tecla 'Ativar/desativar modo de pesca'."
    L["The fishing key is paused in combat."] = "A tecla de pesca fica pausada em combate."
    L["Leaving fishing mode after combat."] = "Saindo do modo de pesca após o combate."

    -- Auction.lua
    L["Scanning %d/%d"] = "Verificando %d/%d"
    L["Scan fish prices"] = "Verificar preços"
    L["Auction scan finished: %d of %d price(s) found."] =
        "Verificação de leilões concluída: %d de %d preço(s) encontrado(s)."
    L["Open the auction house first."] = "Abra a casa de leilões primeiro."
    L["Nothing to scan yet: catch some fish first."] = "Nada para verificar ainda: pesque alguns peixes primeiro."
    L["Scanning auction prices of %d item(s)..."] = "Verificando preços de leilão de %d item(ns)..."
    L["Auction scan stopped: %d of %d price(s) found."] =
        "Verificação de leilões interrompida: %d de %d preço(s) encontrado(s)."

    -- Skill.lua
    L["Apprentice"] = "Aprendiz"
    L["Journeyman"] = "Artífice"
    L["Expert"] = "Especialista"
    L["Artisan"] = "Artesão"
    L["Any fishing trainer teaches it (capitals and towns; the minimap can track trainers)."] =
        "Qualquer instrutor de pesca ensina (capitais e vilas; o minimapa pode rastrear instrutores)."
    L["Buy the book \"%s\" from %s in %s, %s."] = "Compre o livro \"%s\" de %s (%s, %s)."
    L["Do the quest \"%s\" from %s at %s, %s."] = "Faça a missão \"%s\" de %s (%s, %s)."
    L["%s Fishing needs character level %d."] = "O nível %s de Pesca exige personagem de nível %d."
    L["Map pin"] = "Marcador no mapa"
    L["Fishing skill capped (%d/%d): learn %s Fishing to go on."] =
        "Perícia em Pesca no limite (%d/%d): aprenda o nível %s de Pesca para continuar."
    L["You can learn %s Fishing now."] = "Você já pode aprender o nível %s de Pesca."
    L["Next rank: %s Fishing, from skill %d."] = "Próximo nível: %s de Pesca, a partir da perícia %d."
    L["Next rank: %s Fishing, from skill %d and character level %d."] =
        "Próximo nível: %s de Pesca, a partir da perícia %d e do nível de personagem %d."
    L["Next rank: %s Fishing, from character level %d."] =
        "Próximo nível: %s de Pesca, a partir do nível de personagem %d."
    L["Next rank: %s Fishing, ready to learn."] = "Próximo nível: %s de Pesca, pronto para aprender."

    -- UI/CopyWindow.lua
    L["Click the text, then Ctrl+A and Ctrl+C to copy."] = "Clique no texto e depois use Ctrl+A e Ctrl+C para copiar."

    -- UI/Indicator.lua
    L["Cast"] = "Lançar"
    L["Hook!"] = "Fisgar!"
    L["Apply lure"] = "Usar isca"
    L["Open"] = "Abrir"
    L["No bobber"] = "Sem boia"
    L["Paused in combat"] = "Pausado em combate"
    L["Drag to move. Lock it in the settings."] = "Arraste para mover. Trave a posição nas configurações."

    -- UI/Toast.lua
    L["Caught: %s"] = "Pescado: %s"
    L["Nothing caught"] = "Nada pescado"

    -- Core/MapPin.lua and its toasts in UI/Toast.lua
    L["The game did not accept the map pin."] = "O jogo não aceitou o marcador no mapa."
    L["Map pin: %s. Open the world map to see it."] = "Marcador no mapa: %s. Abra o mapa-múndi para vê-lo."
    L["Replace your map pin with this place?"] = "Substituir seu marcador no mapa por este local?"
    L["Replace"] = "Substituir"

    -- UI/StatsFrame.lua
    L["Pin"] = "Marcar"
    L["Time fishing"] = "Tempo pescando"
    L["Time casting"] = "Tempo lançando"
    L["Casts"] = "Lançamentos"
    L["Catches"] = "Capturas"
    L["Catches per hour"] = "Capturas por hora"
    L["Value"] = "Valor"
    L["Gold per hour"] = "Ouro por hora"
    L["OneKeyFishing - Statistics"] = "OneKeyFishing - Estatísticas"
    L["Session"] = "Sessão"
    L["This zone"] = "Esta zona"
    L["All time"] = "Total"
    L["Top catches (all time)"] = "Melhores capturas (total)"
    L["Zones (all time)"] = "Zonas (total)"
    L["Reset session"] = "Zerar sessão"
    L["Reset the fishing statistics of this session?"] = "Zerar as estatísticas de pesca desta sessão?"
    L["Reset all"] = "Zerar tudo"
    L["Delete ALL fishing statistics of this character?"] = "Apagar TODAS as estatísticas de pesca deste personagem?"
    L["Scan auction prices"] = "Verificar preços de leilão"
    L["Fishing skill: %d/%d %s%s"] = "Perícia em Pesca: %d/%d %s%s"
    L["(+%d this session)"] = "(+%d nesta sessão)"
    L["Fishing is not learned."] = "Pesca não foi aprendida."
    L["Values: higher of vendor and auction price (scanned %s)"] =
        "Valores: o maior entre o preço do vendedor e o de leilão (verificado em %s)"
    L["%dm"] = "%d min"
    L["%dh %02dm"] = "%d h %02d min"
    L["Values: vendor price (scan the auction house for market prices)"] =
        "Valores: preço do vendedor (verifique a casa de leilões para obter preços de mercado)"
    L["%d catches, %s"] = "%d capturas, %s"
    L["1 catch, %s"] = "1 captura, %s"
    L["No catches yet."] = "Nenhuma captura ainda."
    L["Time"] = "Tempo"
    L["Results"] = "Resultados"
    L["Money"] = "Dinheiro"
    L["Refresh"] = "Atualizar"
    L["Time in fishing mode. Paused while AFK if that option is on."] =
        "Tempo no modo de pesca. Pausado enquanto LDT se essa opção estiver ativada."
    L["Time with the bobber in the water."] = "Tempo com a boia na água."
    L["Fishing casts made in fishing mode."] = "Lançamentos de Pesca feitos no modo de pesca."
    L["Casts that brought loot."] = "Lançamentos que trouxeram saque."
    L["Casts that ended without loot."] = "Lançamentos que terminaram sem saque."
    L["Catches per hour of fishing time. Updated with every cast and with Refresh."] =
        "Capturas por hora de pesca. Atualizado a cada lançamento e com Atualizar."
    L["Items caught, at the higher of vendor and auction price; with few lots listed, the vendor price."] =
        "Itens pescados, pelo maior entre o preço do vendedor e o de leilão; com poucos lotes, o preço do vendedor."
    L["Value per hour of fishing time. Updated with every cast and with Refresh."] =
        "Valor por hora de pesca. Atualizado a cada lançamento e com Atualizar."

    -- UI/CatchHere.lua and the tabs of UI/StatsFrame.lua
    L["Statistics"] = "Estatísticas"
    L["What can be caught here"] = "O que se pesca aqui"
    L["Skill: %s"] = "Perícia: %s"
    L["All skill levels"] = "Todos os níveis de perícia"
    L["Source: %s"] = "Fonte: %s"
    L["All"] = "Tudo"
    L["Only mine"] = "Só as minhas"
    L["%d catches"] = "%d capturas"
    L["1 catch"] = "1 captura"
    L["Nothing caught: %s"] = "Nada pescado: %s"
    L["Numbers for the whole map: few catches at this spot."] = "Números do mapa inteiro: poucas capturas neste ponto."
    L["Little data"] = "Poucos dados"
    L["Nothing has been caught here yet."] = "Nada foi pescado aqui ainda."
    L["Try \"All skill levels\": little data for your skill."] =
        "Tente 'Todos os níveis de perícia': poucos dados para a sua perícia."
    L["and %d more"] = "e mais %d"
    L["No bundled data in this version: only your own catches are shown."] =
        "Nenhum dado incluído nesta versão: só as suas próprias capturas são mostradas."
    L["No bundled data in this version."] = "Nenhum dado incluído nesta versão."
    L["The game does not show this place on the map."] = "O jogo não mostra este lugar no mapa."
    L["Item"] = "Item"
    L["Chance"] = "Chance"
    L["Per catch"] = "Por captura"
    L["Price"] = "Preço"


    -- Prices (the few-lots mark in both tabs)
    L["few lots"] = "poucos lotes"
    L["Auction price: %s (few lots)"] = "Preço no leilão: %s (poucos lotes)"

    -- Debug.lua
    L["OneKeyFishing - debug report"] = "OneKeyFishing - relatório de depuração"

    -- UI/Settings.lua
    L["Auto loot while fishing"] = "Saque automático ao pescar"
    L["Show the interact icon over the bobber"] = "Mostrar o ícone de interação sobre a boia"
    L["Leave fishing mode when attacked"] = "Sair do modo de pesca ao ser atacado"
    L["Equip fishing pole and fishing gear"] = "Equipar vara de pesca e equipamento de pesca"
    L["Apply lures automatically"] = "Aplicar iscas automaticamente"
    L["Open clams and fished containers"] = "Abrir mariscos e recipientes pescados"
    L["Show the action indicator and cast timer"] = "Mostrar o indicador de ação e o tempo do lançamento"
    L["Lock the indicator position"] = "Travar a posição do indicador"
    L["Show catch notifications"] = "Mostrar avisos de captura"
    L["Show session fishing time under the indicator"] = "Mostrar o tempo de pesca da sessão abaixo do indicador"
    L["Pause the fishing timer while AFK"] = "Pausar o tempo de pesca enquanto LDT"
    L["Remind me about the next Fishing rank"] = "Lembrar do próximo nível de Pesca"
    L["Use scanned auction prices for catch value"] = "Usar os preços de leilão verificados no valor das capturas"
    L["Zoom the camera while fishing"] = "Aproximar a câmera ao pescar"
    L["Show the minimap button"] = "Mostrar o botão no minimapa"
    L["not bound"] = "não atribuída"
    L["Keys"] = "Teclas"
    L["Change them in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
        "Altere-as em Opções -> Teclas de Atalho -> AddOns -> OneKeyFishing."
    L["WoW names punctuation keys (' ; [ , .) by keyboard language: bind them in both slots, once per language."] =
        "O WoW nomeia as teclas de pontuação (' ; [ , .) conforme o idioma do teclado: atribua-as nos dois " ..
        "campos, uma vez por idioma."
    L["Features"] = "Recursos"
    L["Auto loot, bobber icon and gear changes apply the next time you enter fishing mode."] =
        "Saque automático, ícone da boia e troca de equipamento valem na próxima vez que você entrar no modo de pesca."
    L["Camera distance while fishing:"] = "Distância da câmera ao pescar:"
    L["Actions"] = "Ações"
    L["Debug report"] = "Relatório de depuração"
    L["Open statistics"] = "Abrir estatísticas"
    L["Reset indicator position"] = "Redefinir posição do indicador"
    L["(open the auction house first)"] = "(abra a casa de leilões primeiro)"
    L["Fishing action: %s      Toggle fishing mode: %s"] = "Ação de pesca: %s      Ativar/desativar modo de pesca: %s"
    L["Remove"] = "Remover"
    L["Fishing gear"] = "Equipamento de pesca"
    L["Fishing pole"] = "Vara de pesca"
    L["Use the best pole automatically"] = "Usar a melhor vara automaticamente"
    L["Add an item"] = "Adicionar um item"
    L["Easiest: close this window and Alt+Click an item in your bags or on the character panel."] =
        "Mais fácil: feche esta janela e use Alt+Clique em um item nas suas bolsas ou no painel do personagem."
    L["Alt+Click it again to remove it. A fishing pole becomes your chosen pole."] =
        "Use Alt+Clique de novo para removê-lo. Uma vara de pesca se torna a sua vara escolhida."
    L["Here you can type an item name, or find all items with a fishing bonus automatically."] =
        "Aqui você pode digitar o nome de um item ou encontrar automaticamente todos os itens com bônus de pesca."
    L["Item not found. Check the name, or Alt+Click the item in your bags."] =
        "Item não encontrado. Confira o nome ou use Alt+Clique no item nas suas bolsas."
    L["Add"] = "Adicionar"
    L["Find fishing items"] = "Encontrar itens de pesca"
    L["Added %d item(s)."] = "%d item(ns) adicionado(s)."
    L["No new items with a fishing bonus found."] = "Nenhum item novo com bônus de pesca encontrado."
    L["Extra fishing gear"] = "Equipamento de pesca extra"
    L["No items yet."] = "Nenhum item ainda."
    L["Chosen: %s (+%d)"] = "Escolhida: %s (+%d)"
    L["Automatic, best in your bags: %s (+%d)"] = "Automática, a melhor nas suas bolsas: %s (+%d)"
    L["Automatic: no fishing pole in your bags."] = "Automática: nenhuma vara de pesca nas suas bolsas."
    L["Settings cannot be opened in combat."] = "As configurações não podem ser abertas em combate."
    L["Settings panel is not available in this client."] =
        "O painel de configurações não está disponível neste cliente."
    L["Language:"] = "Idioma:"
    L["Interface language"] = "Idioma da interface"
    L["Game client language"] = "Idioma do cliente do jogo"
    L["Korean and Chinese may show as squares on a game client in another language."] =
        "Coreano e chinês podem aparecer como quadrados em um cliente do jogo em outro idioma."
    L["Pick English to get a readable interface back."] = "Escolha English para ter de volta uma interface legível."
    L["The language changes after reloading the interface."] = "O idioma muda após recarregar a interface."
    L["Reload now"] = "Recarregar agora"
    L["Later"] = "Depois"
    L["Yes"] = "Sim"
    L["No"] = "Não"
    L["Cancel"] = "Cancelar"

    -- UI/ItemHooks.lua
    L["OneKeyFishing: fishing gear (Alt+Click to remove)"] =
        "OneKeyFishing: equipamento de pesca (Alt+Clique para remover)"
    L["OneKeyFishing: Alt+Click to add to fishing gear"] =
        "OneKeyFishing: Alt+Clique para adicionar ao equipamento de pesca"

    -- UI/Minimap.lua
    L["Pin: next Fishing rank"] = "Marcar: próximo nível de Pesca"
    L["Leave fishing mode"] = "Sair do modo de pesca"
    L["Enter fishing mode"] = "Entrar no modo de pesca"
    L["Settings"] = "Configurações"
    L["Fishing mode: %s"] = "Modo de pesca: %s"
    L["Fishing skill: %d/%d %s"] = "Perícia em Pesca: %d/%d %s"
    L["Session: %d catches, %s"] = "Sessão: %d capturas, %s"
    L["Session: 1 catch, %s"] = "Sessão: 1 captura, %s"
    L["Fishing key:"] = "Tecla de pesca:"
    L["Toggle mode key:"] = "Tecla do modo:"
    L["How to use: press the toggle key, then the fishing key to cast,"] =
        "Como usar: pressione a tecla do modo e depois a tecla de pesca para lançar,"
    L["and the same key again when the bobber splashes."] = "e a mesma tecla de novo quando a boia balançar."
    L["Alt+Click items in your bags to add fishing gear."] =
        "Use Alt+Clique em itens das suas bolsas para adicionar equipamento de pesca."
    L["Left-click: toggle fishing mode"] = "Clique esquerdo: ativar/desativar modo de pesca"
    L["Shift+Left-click: statistics"] = "Shift+Clique esquerdo: estatísticas"
    L["Right-click: menu"] = "Clique direito: menu"
    L["Drag: move this button"] = "Arrastar: mover este botão"

    -- Share.lua
    L["OneKeyFishing now shares your catches under a random ID with your guild, group and friends who use it."] =
        "O OneKeyFishing agora compartilha suas capturas, com um ID aleatório, com sua guilda, seu grupo e seus " ..
        "amigos que o usam."
    L["No character names are sent, but the players you exchange with can tell which ID is yours."] =
        "Nenhum nome de personagem é enviado, mas os jogadores com quem você troca dados podem saber qual ID é o seu."
    L["Turn it off in Options -> AddOns -> OneKeyFishing -> Shared database."] =
        "Desative em Opções -> AddOns -> OneKeyFishing -> Banco de dados compartilhado."
    L["Got it"] = "Entendi"
    L["Shared database"] = "Banco de dados compartilhado"
    L["Shared catch database is off"] = "O banco de dados de capturas compartilhado está desativado"
    L["Waiting for you to read the notice"] = "Aguardando você ler o aviso"
    L["Exchange unavailable: the game refuses addon messages"] = "Troca indisponível: o jogo recusa mensagens de addons"
    L["Exchange paused: in combat"] = "Troca pausada: em combate"
    L["Exchange paused: in an instance"] = "Troca pausada: em uma instância"
    L["Exchange paused: loading screen"] = "Troca pausada: tela de carregamento"
    L["Exchange paused: the game restricts addon messages here"] =
        "Troca pausada: o jogo restringe mensagens de addons aqui"
    L["Exchange paused: the game asked to slow down"] = "Troca pausada: o jogo pediu para ir mais devagar"
    L["Nobody to exchange with right now"] = "Ninguém com quem trocar no momento"
    L["Exchange: %d players, %s ago"] = "Troca: %d jogadores, há %s"
    L["Exchange: 1 player, %s ago"] = "Troca: 1 jogador, há %s"
    L["Exchange: waiting for the first exchange"] = "Troca: aguardando a primeira troca"
    L["Bundled data: version %d, %d places"] = "Dados incluídos: versão %d, %d lugares"
    L["Records held: %d, %d places"] = "Contribuições guardadas: %d, %d lugares"
    L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d"] =
        "Jogadores ouvidos na última hora: guilda %d, grupo %d, amigos %d, Battle.net %d"
    L["Players exchanged with in the last hour: %d"] = "Jogadores com troca na última hora: %d"
    L["Last exchange: %s ago"] = "Última troca: há %s"
    L["Last exchange: none yet"] = "Última troca: nenhuma ainda"
    L["Traffic in the last hour: %d KB"] = "Tráfego na última hora: %d KB"

    -- UI/Settings.lua: the Shared database page
    L["Use the shared catch database"] = "Usar o banco de dados de capturas compartilhado"
    L["Your catches (items, counts, map cells, the average spot you fish from) are shared under a random ID."] =
        "Suas capturas (itens, quantidades, células do mapa, o ponto médio de onde você pesca) são compartilhadas " ..
        "com um ID aleatório."
    L["They go to addon users in your guild, group and friends list. No names or gear."] =
        "Elas vão para quem usa o addon na sua guilda, grupo e lista de amigos. Sem nomes nem equipamento."
    L["The players you exchange with can tell which ID is yours."] =
        "Os jogadores com quem você troca dados podem saber qual ID é o seu."
    L["Turned off: nothing is sent or received, and other players' data is not counted."] =
        "Desativado: nada é enviado nem recebido, e os dados de outros jogadores não são contados."

    -- UI/CatchHere.lua: other players' catches
    L["%d catches from %d players"] = "%d capturas de %d jogadores"

    -- UI/CatchHere.lua: items the game client does not know yet (part 3)
    L["Unknown item"] = "Item desconhecido"
    L["The game has not shown this item yet."] = "O jogo ainda não mostrou este item."
    L["Reported by %d players on this map"] = "Relatado por %d jogadores neste mapa"
    L["In the bundled data"] = "Nos dados incluídos"
    L["Item ID: %d"] = "ID do item: %d"

    -- Channel.lua: the hidden public channel (part 3)
    L["OneKeyFishing left its hidden channel to free a chat channel slot. Try joining again."] =
        "O OneKeyFishing saiu do seu canal oculto para liberar uma vaga de canal de bate-papo. Tente entrar de novo."

    -- UI/Settings.lua: the public channel (part 3)
    L["Use the public channel"] = "Usar o canal público"
    L["With the public channel on, they also go to every other addon user, through a hidden chat channel."] =
        "Com o canal público ligado, elas também vão para todos os outros usuários do addon, por um canal de " ..
        "bate-papo oculto."
    L["Anyone who joins that channel by its name can see which characters in it use the addon."] =
        "Quem entrar nesse canal pelo nome pode ver quais personagens nele usam o addon."

    -- Share.lua: the public channel (part 3)
    L["OneKeyFishing now shares your catches under a random ID with other players who use it."] =
        "O OneKeyFishing agora compartilha suas capturas, com um ID aleatório, com outros jogadores que o usam."
    L["It reaches your guild, group and friends, and anyone else through a hidden chat channel."] =
        "Isso chega à sua guilda, ao seu grupo e aos seus amigos, e a qualquer outra pessoa por um canal de " ..
        "bate-papo oculto."
    L["Public channel: in use"] = "Canal público: em uso"
    L["Public channel: in use (fallback channel %d)"] = "Canal público: em uso (canal reserva %d)"
    L["Public channel: off"] = "Canal público: desligado"
    L["Public channel: no free chat channel slot"] = "Canal público: nenhuma vaga livre de canal de bate-papo"
    L["Public channel: locked or refused by the game"] = "Canal público: bloqueado ou recusado pelo jogo"
    L["Public channel: you left it, back at the next login"] = "Canal público: você saiu dele; volta no próximo login"
    L["Public channel: waiting"] = "Canal público: aguardando"
    L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d, channel %d"] =
        "Jogadores ouvidos na última hora: guilda %d, grupo %d, amigos %d, Battle.net %d, canal %d"

    -- Catalog.lua: the catch catalog (part 4)
    L["Unknown zone (%d)"] = "Zona desconhecida (%d)"

    -- Catalog.lua: spots
    L["%s (%s)"] = "%s (%s)"
    L["No exact spot"] = "Sem local exato"

    -- UI/CatalogTab.lua, UI/StatsFrame.lua, UI/CatchHere.lua: the catch catalog (part 4)
    L["Catch catalog"] = "Catálogo de capturas"
    L["Search by item name"] = "Buscar pelo nome do item"
    L["Zones: %d"] = "Zonas: %d"
    L["Back"] = "Voltar"
    L["Place"] = "Local"
    L["Skill"] = "Perícia"
    L["Counting the catch..."] = "Contando as capturas..."
    L["Nothing has been caught yet."] = "Nada foi pescado ainda."
    L["The catalog fills with your catches, the bundled data and, with sharing on, other players' catches."] =
        "O catálogo é preenchido com suas capturas, os dados incluídos e, com o compartilhamento ativado, as capturas "
        .. "de outros jogadores."
    L["You have not caught anything yet."] = "Você ainda não pescou nada."
    L["No item matches the search."] = "Nenhum item corresponde à busca."
    L["No data for this item under these filters."] = "Sem dados deste item com estes filtros."
    L["Click an item to see where else it is caught."] = "Clique em um item para ver onde mais ele é pescado."

    -- UI/CatalogTab.lua: the map pin (part 4)
    L["Set a map pin here"] = "Colocar um marcador no mapa aqui"

    -- Catalog.lua, UI/ItemHooks.lua, UI/Minimap.lua, UI/Settings.lua: catch chances in tooltips (part 4)
    L["%s (%d players)"] = "%s (%d jogadores)"
    L["Caught in:"] = "Pescado em:"
    L["Likely catch here:"] = "Captura provável aqui:"
    L["Show catch chances in tooltips"] = "Mostrar chances de captura nas dicas"

    -- UI/CatchHere.lua, UI/CatalogTab.lua: the Water filter (part 4)
    L["Water: %s"] = "Água: %s"
    L["Everywhere"] = "Em toda parte"
    L["Open water"] = "Águas abertas"
    L["Pools"] = "Cardumes"
end)
