-- Brazilian Portuguese translation. Keys are the English texts of Locales/enUS.lua.
local _, ns = ...

ns.AddTranslation("ptBR", "Português", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "Ação de pesca (lançar / fisgar)"
    L["Toggle fishing mode"] = "Ativar/desativar modo de pesca"
    L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] =
        "Seus dados salvos vêm de uma versão mais nova do OneKeyFishing. Atualize o addon para evitar problemas."

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
    L["a fishing trainer"] = "um instrutor de pesca"
    L["the book \"Expert Fishing - The Bass and You\" (Old Man Heming, Booty Bay)"] =
        "o livro \"Expert Fishing - The Bass and You\" (Old Man Heming, Angra do Butim)"
    L["the quest from Nat Pagle (Dustwallow Marsh)"] = "a missão de Nat Pagle (Pântano Vadeoso)"
    L["Fishing skill capped (%d/%d): learn %s Fishing from %s."] =
        "Perícia em Pesca no limite (%d/%d): aprenda o nível %s de Pesca com %s."
    L["Fishing %d/%d: %d point(s) left in this rank. Next: %s Fishing from %s."] =
        "Pesca %d/%d: falta(m) %d ponto(s) neste nível. Próximo: nível %s de Pesca com %s."

    -- UI/CopyWindow.lua
    L["Click the text, then Ctrl+A and Ctrl+C to copy."] = "Clique no texto e depois use Ctrl+A e Ctrl+C para copiar."

    -- UI/Indicator.lua
    L["Cast"] = "Lançar"
    L["Hook!"] = "Fisgar!"
    L["Apply lure"] = "Usar isca"
    L["Open"] = "Abrir"
    L["No bobber"] = "Sem boia"
    L["Drag to move. Lock it in the settings."] = "Arraste para mover. Trave a posição nas configurações."

    -- UI/Toast.lua
    L["Caught: %s"] = "Pescado: %s"
    L["Nothing caught"] = "Nada pescado"

    -- UI/StatsFrame.lua
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
    L["Nothing caught: %s"] = "Nada pescado: %s"
    L["Numbers for the whole map: few catches at this spot."] = "Números do mapa inteiro: poucas capturas neste ponto."
    L["Little data"] = "Poucos dados"
    L["Nothing has been caught here yet."] = "Nada foi pescado aqui ainda."
    L["Try \"All skill levels\": little data for your skill."] =
        "Tente 'Todos os níveis de perícia': poucos dados para a sua perícia."
    L["and %d more"] = "e mais %d"
    L["No bundled data in this version: only your own catches are shown."] =
        "Nenhum dado incluído nesta versão: só as suas próprias capturas são mostradas."
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
    L["Warn when the Fishing rank is capped"] = "Avisar quando o nível de Pesca atingir o limite"
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

    -- UI/ItemHooks.lua
    L["OneKeyFishing: fishing gear (Alt+Click to remove)"] =
        "OneKeyFishing: equipamento de pesca (Alt+Clique para remover)"
    L["OneKeyFishing: Alt+Click to add to fishing gear"] =
        "OneKeyFishing: Alt+Clique para adicionar ao equipamento de pesca"

    -- UI/Minimap.lua
    L["Leave fishing mode"] = "Sair do modo de pesca"
    L["Enter fishing mode"] = "Entrar no modo de pesca"
    L["Statistics"] = "Estatísticas"
    L["Settings"] = "Configurações"
    L["Fishing mode: %s"] = "Modo de pesca: %s"
    L["Fishing skill: %d/%d %s"] = "Perícia em Pesca: %d/%d %s"
    L["Session: %d catches, %s"] = "Sessão: %d capturas, %s"
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
end)
