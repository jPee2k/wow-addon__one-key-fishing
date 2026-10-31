-- European Spanish translation. Keys are the English texts of Locales/enUS.lua.
local _, ns = ...

ns.AddTranslation("esES", "Español (EU)", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "Acción de pesca (lanzar / recoger)"
    L["Toggle fishing mode"] = "Activar/desactivar el modo pesca"
    L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] =
        "Tus datos guardados son de una versión más reciente de OneKeyFishing. Actualiza el addon para evitar fallos."
    L["Your game client has no translation, so the addon is in English. Others, such as %s, are in /okf config."] =
        "No hay traducción para tu cliente del juego, así que el addon está en inglés. " ..
        "Hay otros idiomas, como %s, en /okf config."

    -- Gear.lua
    L["Fishing pole set."] = "Caña de pescar elegida."
    L["This item cannot be used as fishing gear."] = "Este objeto no se puede usar como equipo de pesca."
    L["Already in the list."] = "Ya está en la lista."
    L["Added."] = "Añadido."
    L["Fishing pole: automatic (best in bags)."] = "Caña de pescar: automática (la mejor de las bolsas)."
    L["Removed from fishing gear."] = "Quitado del equipo de pesca."
    L["No fishing pole found in your bags."] = "No hay ninguna caña de pescar en tus bolsas."
    L["%d fishing item(s) are not in your bags."] = "%d objeto(s) de pesca no están en tus bolsas."
    L["No free bag space to take off %s."] = "No hay espacio libre en las bolsas para quitarte %s."
    L["an item"] = "un objeto"

    -- Bags.lua
    L["Cannot apply %s, skipping it until fishing mode is turned on again."] =
        "No se puede aplicar %s; se omitirá hasta que vuelvas a activar el modo pesca."
    L["Not enough bag space to loot %s. It will be opened again when you free a bag slot."] =
        "No hay espacio en las bolsas para despojar %s. Se volverá a abrir cuando liberes un hueco."
    L["Cannot open %s, skipping it for this session."] = "No se puede abrir %s; se omitirá durante esta sesión."

    -- Action.lua
    L["You have not learned Fishing."] = "No has aprendido Pesca."
    L["No key is bound to 'Fishing action'. Bind one in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
        "No hay ninguna tecla asignada a 'Acción de pesca'. Asigna una en " ..
        "Opciones -> Asignación de teclas -> Accesorios -> OneKeyFishing."

    -- Mode.lua
    L["Cannot enter fishing mode in combat."] = "No puedes entrar en el modo pesca en combate."
    L["Fishing mode %s."] = "Modo pesca %s."
    L["ON"] = "ACTIVADO"
    L["OFF"] = "DESACTIVADO"
    L["Restored game settings from an unfinished fishing session."] =
        "Se ha restaurado la configuración del juego de una sesión de pesca sin terminar."
    L["Fishing mode is off. Press your 'Toggle fishing mode' key first."] =
        "El modo pesca está desactivado. Pulsa primero tu tecla de 'Activar/desactivar el modo pesca'."
    L["The fishing key is paused in combat."] = "La tecla de pesca está en pausa durante el combate."
    L["Leaving fishing mode after combat."] = "Saldrás del modo pesca al terminar el combate."

    -- Auction.lua
    L["Scanning %d/%d"] = "Escaneando %d/%d"
    L["Scan fish prices"] = "Escanear precios"
    L["Auction scan finished: %d of %d price(s) found."] =
        "Escaneo de subastas terminado: %d de %d precio(s) encontrados."
    L["Open the auction house first."] = "Abre primero la casa de subastas."
    L["Nothing to scan yet: catch some fish first."] = "Aún no hay nada que escanear: pesca algo primero."
    L["Scanning auction prices of %d item(s)..."] = "Escaneando los precios de subasta de %d objeto(s)..."
    L["Auction scan stopped: %d of %d price(s) found."] =
        "Escaneo de subastas detenido: %d de %d precio(s) encontrados."

    -- Skill.lua
    L["Apprentice"] = "Aprendiz"
    L["Journeyman"] = "Oficial"
    L["Expert"] = "Experto"
    L["Artisan"] = "Artesano"
    L["Any fishing trainer teaches it (capitals and towns; the minimap can track trainers)."] =
        "Cualquier instructor de pesca lo enseña (capitales y pueblos; el minimapa puede rastrear instructores)."
    L["Buy the book \"%s\" from %s in %s, %s."] = "Compra el libro «%s» a %s (%s, %s)."
    L["Do the quest \"%s\" from %s at %s, %s."] = "Completa la misión «%s» de %s (%s, %s)."
    L["%s Fishing needs character level %d."] = "El rango %s de Pesca requiere nivel de personaje %d."
    L["Map pin"] = "Marcador de mapa"
    L["Fishing skill capped (%d/%d): learn %s Fishing to go on."] =
        "Pesca al máximo (%d/%d): aprende el rango %s de Pesca para seguir."
    L["You can learn %s Fishing now."] = "Ya puedes aprender el rango %s de Pesca."
    L["Next rank: %s Fishing, from skill %d."] = "Siguiente rango: %s de Pesca, desde habilidad %d."
    L["Next rank: %s Fishing, from skill %d and character level %d."] =
        "Siguiente rango: %s de Pesca, desde habilidad %d y nivel de personaje %d."
    L["Next rank: %s Fishing, from character level %d."] = "Siguiente rango: %s de Pesca, desde nivel de personaje %d."
    L["Next rank: %s Fishing, ready to learn."] = "Siguiente rango: %s de Pesca, ya puedes aprenderlo."

    -- UI/CopyWindow.lua
    L["Click the text, then Ctrl+A and Ctrl+C to copy."] = "Haz clic en el texto y pulsa Ctrl+A y Ctrl+C para copiarlo."

    -- UI/Indicator.lua
    L["Cast"] = "Lanzar"
    L["Hook!"] = "¡Recoge!"
    L["Apply lure"] = "Poner cebo"
    L["Open"] = "Abrir"
    L["No bobber"] = "Sin corcho"
    L["Drag to move. Lock it in the settings."] = "Arrastra para moverlo. Puedes bloquearlo en la configuración."

    -- UI/Toast.lua
    L["Caught: %s"] = "Capturado: %s"
    L["Nothing caught"] = "Nada capturado"

    -- UI/MapPin.lua
    L["The game did not accept the map pin."] = "El juego no aceptó el marcador de mapa."
    L["Map pin: %s"] = "Marcador de mapa: %s"
    L["Replace your map pin with this place?"] = "¿Reemplazar tu marcador de mapa por este lugar?"
    L["Replace"] = "Reemplazar"

    -- UI/StatsFrame.lua
    L["Pin"] = "Marcar"
    L["Time fishing"] = "Tiempo pescando"
    L["Time casting"] = "Tiempo con el corcho"
    L["Casts"] = "Lanzamientos"
    L["Catches"] = "Capturas"
    L["Catches per hour"] = "Capturas por hora"
    L["Value"] = "Valor"
    L["Gold per hour"] = "Oro por hora"
    L["OneKeyFishing - Statistics"] = "OneKeyFishing - Estadísticas"
    L["Session"] = "Sesión"
    L["This zone"] = "Esta zona"
    L["All time"] = "Total"
    L["Top catches (all time)"] = "Mejores capturas (total)"
    L["Zones (all time)"] = "Zonas (total)"
    L["Reset session"] = "Reiniciar sesión"
    L["Reset the fishing statistics of this session?"] = "¿Reiniciar las estadísticas de pesca de esta sesión?"
    L["Reset all"] = "Reiniciar todo"
    L["Delete ALL fishing statistics of this character?"] =
        "¿Borrar TODAS las estadísticas de pesca de este personaje?"
    L["Scan auction prices"] = "Escanear subastas"
    L["Fishing skill: %d/%d %s%s"] = "Habilidad de Pesca: %d/%d %s%s"
    L["(+%d this session)"] = "(+%d en esta sesión)"
    L["Fishing is not learned."] = "No has aprendido Pesca."
    L["Values: higher of vendor and auction price (scanned %s)"] =
        "Valores: el mayor entre precio de vendedor y de subasta (escaneado el %s)"
    L["%dm"] = "%d min"
    L["%dh %02dm"] = "%d h %02d min"
    L["Values: vendor price (scan the auction house for market prices)"] =
        "Valores: precio de vendedor (escanea la casa de subastas para obtener precios de mercado)"
    L["%d catches, %s"] = "%d capturas, %s"
    L["No catches yet."] = "Aún no hay capturas."
    L["Time"] = "Tiempo"
    L["Results"] = "Resultados"
    L["Money"] = "Dinero"
    L["Refresh"] = "Actualizar"
    L["Time in fishing mode. Paused while AFK if that option is on."] =
        "Tiempo en modo pesca. Se pausa mientras estás ausente si esa opción está activada."
    L["Time with the bobber in the water."] = "Tiempo con el corcho en el agua."
    L["Fishing casts made in fishing mode."] = "Lanzamientos de pesca hechos en modo pesca."
    L["Casts that brought loot."] = "Lanzamientos que dieron botín."
    L["Casts that ended without loot."] = "Lanzamientos que terminaron sin botín."
    L["Catches per hour of fishing time. Updated with every cast and with Refresh."] =
        "Capturas por hora de tiempo de pesca. Se actualiza con cada lanzamiento y con Actualizar."
    L["Items caught, at the higher of vendor and auction price; with few lots listed, the vendor price."] =
        "Objetos capturados, al mayor entre el precio de vendedor y el de subasta; con pocos lotes, el precio de " ..
        "vendedor."
    L["Value per hour of fishing time. Updated with every cast and with Refresh."] =
        "Valor por hora de tiempo de pesca. Se actualiza con cada lanzamiento y con Actualizar."

    -- UI/CatchHere.lua and the tabs of UI/StatsFrame.lua
    L["Statistics"] = "Estadísticas"
    L["What can be caught here"] = "Qué se pesca aquí"
    L["Skill: %s"] = "Habilidad: %s"
    L["All skill levels"] = "Todos los niveles de habilidad"
    L["Source: %s"] = "Fuente: %s"
    L["All"] = "Todo"
    L["Only mine"] = "Solo las mías"
    L["%d catches"] = "%d capturas"
    L["Nothing caught: %s"] = "Nada capturado: %s"
    L["Numbers for the whole map: few catches at this spot."] = "Datos de todo el mapa: pocas capturas en este punto."
    L["Little data"] = "Pocos datos"
    L["Nothing has been caught here yet."] = "Aquí aún no se ha pescado nada."
    L["Try \"All skill levels\": little data for your skill."] =
        "Prueba 'Todos los niveles de habilidad': pocos datos para tu habilidad."
    L["and %d more"] = "y %d más"
    L["No bundled data in this version: only your own catches are shown."] =
        "Esta versión no incluye datos: solo se muestran tus propias capturas."
    L["The game does not show this place on the map."] = "El juego no muestra este lugar en el mapa."
    L["Item"] = "Objeto"
    L["Chance"] = "Probabilidad"
    L["Per catch"] = "Por captura"
    L["Price"] = "Precio"


    -- Prices (the few-lots mark in both tabs)
    L["few lots"] = "pocos lotes"
    L["Auction price: %s (few lots)"] = "Precio de subasta: %s (pocos lotes)"

    -- Debug.lua
    L["OneKeyFishing - debug report"] = "OneKeyFishing - informe de depuración"

    -- UI/Settings.lua
    L["Auto loot while fishing"] = "Despojo automático al pescar"
    L["Show the interact icon over the bobber"] = "Mostrar el icono de interacción sobre el corcho"
    L["Leave fishing mode when attacked"] = "Salir del modo pesca al ser atacado"
    L["Equip fishing pole and fishing gear"] = "Equipar la caña de pescar y el equipo de pesca"
    L["Apply lures automatically"] = "Aplicar cebos automáticamente"
    L["Open clams and fished containers"] = "Abrir almejas y contenedores pescados"
    L["Show the action indicator and cast timer"] = "Mostrar el indicador de acción y el temporizador del lanzamiento"
    L["Lock the indicator position"] = "Bloquear la posición del indicador"
    L["Show catch notifications"] = "Mostrar avisos de capturas"
    L["Show session fishing time under the indicator"] = "Mostrar el tiempo de pesca de la sesión bajo el indicador"
    L["Pause the fishing timer while AFK"] = "Pausar el temporizador de pesca mientras estás ausente"
    L["Remind me about the next Fishing rank"] = "Recordarme el siguiente rango de Pesca"
    L["Use scanned auction prices for catch value"] =
        "Usar los precios de subasta escaneados para el valor de las capturas"
    L["Zoom the camera while fishing"] = "Acercar la cámara al pescar"
    L["Show the minimap button"] = "Mostrar el botón del minimapa"
    L["not bound"] = "sin asignar"
    L["Keys"] = "Teclas"
    L["Change them in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
        "Cámbialas en Opciones -> Asignación de teclas -> Accesorios -> OneKeyFishing."
    L["WoW names punctuation keys (' ; [ , .) by keyboard language: bind them in both slots, once per language."] =
        "WoW nombra las teclas de puntuación (' ; [ , .) según el idioma del teclado: " ..
        "asígnalas en ambas casillas, una vez por idioma."
    L["Features"] = "Funciones"
    L["Auto loot, bobber icon and gear changes apply the next time you enter fishing mode."] =
        "El despojo automático, el icono del corcho y los cambios de equipo se aplican " ..
        "la próxima vez que entres en el modo pesca."
    L["Camera distance while fishing:"] = "Distancia de la cámara al pescar:"
    L["Actions"] = "Acciones"
    L["Debug report"] = "Informe de depuración"
    L["Open statistics"] = "Abrir estadísticas"
    L["Reset indicator position"] = "Restablecer posición del indicador"
    L["(open the auction house first)"] = "(abre primero la casa de subastas)"
    L["Fishing action: %s      Toggle fishing mode: %s"] = "Acción de pesca: %s      Activar/desactivar modo pesca: %s"
    L["Remove"] = "Quitar"
    L["Fishing gear"] = "Equipo de pesca"
    L["Fishing pole"] = "Caña de pescar"
    L["Use the best pole automatically"] = "Usar automáticamente la mejor caña"
    L["Add an item"] = "Añadir un objeto"
    L["Easiest: close this window and Alt+Click an item in your bags or on the character panel."] =
        "Lo más fácil: cierra esta ventana y haz Alt+clic en un objeto de tus bolsas o del panel de personaje."
    L["Alt+Click it again to remove it. A fishing pole becomes your chosen pole."] =
        "Haz Alt+clic de nuevo para quitarlo. Una caña de pescar pasa a ser tu caña elegida."
    L["Here you can type an item name, or find all items with a fishing bonus automatically."] =
        "Aquí puedes escribir el nombre de un objeto " ..
        "o buscar automáticamente todos los objetos con bonificación de pesca."
    L["Item not found. Check the name, or Alt+Click the item in your bags."] =
        "Objeto no encontrado. Revisa el nombre o haz Alt+clic en el objeto en tus bolsas."
    L["Add"] = "Añadir"
    L["Find fishing items"] = "Buscar objetos de pesca"
    L["Added %d item(s)."] = "Añadido(s) %d objeto(s)."
    L["No new items with a fishing bonus found."] = "No se han encontrado objetos nuevos con bonificación de pesca."
    L["Extra fishing gear"] = "Equipo de pesca adicional"
    L["No items yet."] = "Aún no hay objetos."
    L["Chosen: %s (+%d)"] = "Elegida: %s (+%d)"
    L["Automatic, best in your bags: %s (+%d)"] = "Automática, la mejor de tus bolsas: %s (+%d)"
    L["Automatic: no fishing pole in your bags."] = "Automática: no hay ninguna caña de pescar en tus bolsas."
    L["Settings cannot be opened in combat."] = "La configuración no se puede abrir en combate."
    L["Settings panel is not available in this client."] =
        "El panel de configuración no está disponible en este cliente."
    L["Language:"] = "Idioma:"
    L["Interface language"] = "Idioma de la interfaz"
    L["Game client language"] = "Idioma del cliente del juego"
    L["Korean and Chinese may show as squares on a game client in another language."] =
        "El coreano y el chino pueden verse como cuadrados en un cliente del juego en otro idioma."
    L["Pick English to get a readable interface back."] = "Elige English para recuperar una interfaz legible."
    L["The language changes after reloading the interface."] = "El idioma cambia después de recargar la interfaz."
    L["Reload now"] = "Recargar ahora"
    L["Later"] = "Más tarde"
    L["Yes"] = "Sí"
    L["No"] = "No"
    L["Cancel"] = "Cancelar"

    -- UI/ItemHooks.lua
    L["OneKeyFishing: fishing gear (Alt+Click to remove)"] = "OneKeyFishing: equipo de pesca (Alt+clic para quitar)"
    L["OneKeyFishing: Alt+Click to add to fishing gear"] = "OneKeyFishing: Alt+clic para añadir al equipo de pesca"

    -- UI/Minimap.lua
    L["Pin: next Fishing rank"] = "Marcar: siguiente rango de Pesca"
    L["Leave fishing mode"] = "Salir del modo pesca"
    L["Enter fishing mode"] = "Entrar en el modo pesca"
    L["Settings"] = "Configuración"
    L["Fishing mode: %s"] = "Modo pesca: %s"
    L["Fishing skill: %d/%d %s"] = "Habilidad de Pesca: %d/%d %s"
    L["Session: %d catches, %s"] = "Sesión: %d capturas, %s"
    L["Fishing key:"] = "Tecla de pesca:"
    L["Toggle mode key:"] = "Tecla de modo:"
    L["How to use: press the toggle key, then the fishing key to cast,"] =
        "Uso: pulsa la tecla de modo y luego la tecla de pesca para lanzar,"
    L["and the same key again when the bobber splashes."] = "y la misma tecla otra vez cuando el corcho salpique."
    L["Alt+Click items in your bags to add fishing gear."] =
        "Haz Alt+clic en objetos de tus bolsas para añadirlos al equipo de pesca."
    L["Left-click: toggle fishing mode"] = "Clic izquierdo: activar/desactivar el modo pesca"
    L["Shift+Left-click: statistics"] = "Mayús+clic izquierdo: estadísticas"
    L["Right-click: menu"] = "Clic derecho: menú"
    L["Drag: move this button"] = "Arrastrar: mover este botón"

    -- Share.lua
    L["OneKeyFishing now shares your catches under a random ID with your guild, group and friends who use it."] =
        "OneKeyFishing ahora comparte tus capturas bajo un ID aleatorio con tu hermandad, tu grupo y tus amigos que " ..
        "lo usan."
    L["No character names are sent, but the players you exchange with can tell which ID is yours."] =
        "No se envían nombres de personajes, pero quienes intercambian datos contigo pueden saber qué ID es el tuyo."
    L["Turn it off in Options -> AddOns -> OneKeyFishing -> Shared database."] =
        "Desactívalo en Opciones -> Accesorios -> OneKeyFishing -> Base de datos compartida."
    L["Got it"] = "Entendido"
    L["Shared database"] = "Base de datos compartida"
    L["Shared catch database is off"] = "La base de datos de capturas compartida está desactivada"
    L["Waiting for you to read the notice"] = "Esperando a que leas el aviso"
    L["Exchange unavailable: the game refuses addon messages"] =
        "Intercambio no disponible: el juego rechaza los mensajes de addons"
    L["Exchange paused: in combat"] = "Intercambio en pausa: en combate"
    L["Exchange paused: in an instance"] = "Intercambio en pausa: en una instancia"
    L["Exchange paused: loading screen"] = "Intercambio en pausa: pantalla de carga"
    L["Exchange paused: the game restricts addon messages here"] =
        "Intercambio en pausa: el juego restringe aquí los mensajes de addons"
    L["Exchange paused: the game asked to slow down"] = "Intercambio en pausa: el juego pidió ir más despacio"
    L["Nobody to exchange with right now"] = "Ahora no hay nadie con quien intercambiar"
    L["Exchange: %d players, %s ago"] = "Intercambio: %d jugadores, hace %s"
    L["Exchange: waiting for the first exchange"] = "Intercambio: esperando el primer intercambio"
    L["Bundled data: version %d, %d places"] = "Datos incluidos: versión %d, %d lugares"
    L["Records held: %d, %d places"] = "Aportaciones guardadas: %d, %d lugares"
    L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d"] =
        "Jugadores oídos en la última hora: hermandad %d, grupo %d, amigos %d, Battle.net %d"
    L["Players exchanged with in the last hour: %d"] = "Jugadores con intercambio en la última hora: %d"
    L["Last exchange: %s ago"] = "Último intercambio: hace %s"
    L["Last exchange: none yet"] = "Último intercambio: ninguno todavía"
    L["Traffic in the last hour: %d KB"] = "Tráfico en la última hora: %d KB"

    -- UI/Settings.lua: the Shared database page
    L["Use the shared catch database"] = "Usar la base de datos de capturas compartida"
    L["Your catches (items, counts, map cells, the average spot you fish from) are shared under a random ID."] =
        "Tus capturas (objetos, cantidades, casillas del mapa, el punto medio desde el que pescas) se comparten " ..
        "bajo un ID aleatorio."
    L["They go to addon users in your guild, group and friends list. No names or gear."] =
        "Llegan a quienes usan el addon en tu hermandad, grupo y lista de amigos. Sin nombres ni equipo."
    L["The players you exchange with can tell which ID is yours."] =
        "Quienes intercambian datos contigo pueden saber qué ID es el tuyo."
    L["Turned off: nothing is sent or received, and other players' data is not counted."] =
        "Desactivada: no se envía ni se recibe nada, y los datos de otros jugadores no se cuentan."

    -- UI/CatchHere.lua: other players' catches
    L["%d catches from %d players"] = "%d capturas de %d jugadores"

    -- UI/CatchHere.lua: items the game client does not know yet (part 3)
    L["Unknown item"] = "Objeto desconocido"
    L["The game has not shown this item yet."] = "El juego todavía no ha mostrado este objeto."
    L["Reported by %d players on this map"] = "Notificado por %d jugadores en este mapa"
    L["In the bundled data"] = "En los datos incluidos"
    L["Item ID: %d"] = "ID del objeto: %d"

    -- Channel.lua: the hidden public channel (part 3)
    L["OneKeyFishing left its hidden channel to free a chat channel slot. Try joining again."] =
        "OneKeyFishing ha salido de su canal oculto para liberar un hueco de canal de chat. Vuelve a intentarlo."

    -- UI/Settings.lua: the public channel (part 3)
    L["Use the public channel"] = "Usar el canal público"
    L["With the public channel on, they also go to every other addon user, through a hidden chat channel."] =
        "Con el canal público activado, también llegan a todos los demás usuarios del addon a través de un canal de " ..
        "chat oculto."
    L["Anyone who joins that channel by its name can see which characters in it use the addon."] =
        "Quien se una a ese canal por su nombre puede ver qué personajes del canal usan el addon."

    -- Share.lua: the public channel (part 3)
    L["OneKeyFishing now shares your catches under a random ID with other players who use it."] =
        "OneKeyFishing ahora comparte tus capturas bajo un ID aleatorio con otros jugadores que lo usan."
    L["It reaches your guild, group and friends, and anyone else through a hidden chat channel."] =
        "Llega a tu hermandad, tu grupo y tus amigos, y a cualquier otro a través de un canal de chat oculto."
    L["Public channel: in use"] = "Canal público: en uso"
    L["Public channel: in use (fallback channel %d)"] = "Canal público: en uso (canal de reserva %d)"
    L["Public channel: off"] = "Canal público: desactivado"
    L["Public channel: no free chat channel slot"] = "Canal público: no hay un hueco libre de canal de chat"
    L["Public channel: locked or refused by the game"] = "Canal público: bloqueado o rechazado por el juego"
    L["Public channel: you left it, back at the next login"] =
        "Canal público: lo has abandonado; vuelve en el próximo inicio de sesión"
    L["Public channel: waiting"] = "Canal público: en espera"
    L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d, channel %d"] =
        "Jugadores oídos en la última hora: hermandad %d, grupo %d, amigos %d, Battle.net %d, canal %d"

    -- Catalog.lua: the catch catalog (part 4)
    L["Unknown zone (%d)"] = "Zona desconocida (%d)"

    -- Catalog.lua: spots
    L["%s (%s)"] = "%s (%s)"
    L["No exact spot"] = "Sin lugar exacto"

    -- UI/CatalogTab.lua, UI/StatsFrame.lua, UI/CatchHere.lua: the catch catalog (part 4)
    L["Catch catalog"] = "Catálogo de capturas"
    L["Search by item name"] = "Buscar por nombre de objeto"
    L["Zones: %d"] = "Zonas: %d"
    L["Back"] = "Atrás"
    L["Place"] = "Lugar"
    L["Skill"] = "Habilidad"
    L["Counting the catch..."] = "Contando las capturas..."
    L["Nothing has been caught yet."] = "Aún no se ha pescado nada."
    L["The catalog fills with your catches, the bundled data and, with sharing on, other players' catches."] =
        "El catálogo se llena con tus capturas, los datos incluidos y, con el intercambio activado, las capturas de "
        .. "otros jugadores."
    L["You have not caught anything yet."] = "Aún no has pescado nada."
    L["No item matches the search."] = "Ningún objeto coincide con la búsqueda."
    L["No data for this item under these filters."] = "No hay datos de este objeto con estos filtros."
    L["Click an item to see where else it is caught."] = "Haz clic en un objeto para ver dónde más se pesca."

    -- UI/CatalogTab.lua: the map pin (part 4)
    L["Set a map pin here"] = "Poner una marca en el mapa aquí"

    -- Catalog.lua, UI/ItemHooks.lua, UI/Minimap.lua, UI/Settings.lua: catch chances in tooltips (part 4)
    L["%s (%d players)"] = "%s (%d jugadores)"
    L["Caught in:"] = "Se pesca en:"
    L["Likely catch here:"] = "Captura probable aquí:"
    L["Show catch chances in tooltips"] = "Mostrar probabilidades de captura en las descripciones"

    -- UI/CatchHere.lua, UI/CatalogTab.lua: the Water filter (part 4)
    L["Water: %s"] = "Agua: %s"
    L["Everywhere"] = "En todas partes"
    L["Open water"] = "Aguas abiertas"
    L["Pools"] = "Bancos"
end)
