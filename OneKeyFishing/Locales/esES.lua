-- European Spanish translation. Keys are the English texts of Locales/enUS.lua.
local _, ns = ...

ns.AddTranslation("esES", "Español (EU)", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "Acción de pesca (lanzar / recoger)"
    L["Toggle fishing mode"] = "Activar/desactivar el modo pesca"
    L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] =
        "Tus datos guardados son de una versión más reciente de OneKeyFishing. Actualiza el addon para evitar fallos."
    L["v%s commands:"] = "Comandos de v%s:"

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
    L["enter or leave fishing mode"] = "entrar o salir del modo pesca"

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
    L["scan auction prices of caught items (auction house must be open)"] =
        "escanear los precios de subasta de las capturas (con la casa de subastas abierta)"

    -- Skill.lua
    L["Apprentice"] = "Aprendiz"
    L["Journeyman"] = "Oficial"
    L["Expert"] = "Experto"
    L["Artisan"] = "Artesano"
    L["a fishing trainer"] = "un instructor de pesca"
    L["the book \"Expert Fishing - The Bass and You\" (Old Man Heming, Booty Bay)"] =
        "el libro \"Expert Fishing - The Bass and You\" (Viejo Heming, Bahía del Botín)"
    L["the quest from Nat Pagle (Dustwallow Marsh)"] = "la misión de Nat Pagle (Marjal Revolcafango)"
    L["Fishing skill capped (%d/%d): learn %s Fishing from %s."] =
        "Pesca al máximo (%d/%d): aprende el rango %s de Pesca con %s."
    L["Fishing %d/%d: %d point(s) left in this rank. Next: %s Fishing from %s."] =
        "Pesca %d/%d: queda(n) %d punto(s) en este rango. Siguiente: rango %s de Pesca con %s."

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

    -- UI/StatsFrame.lua
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
    L["show the fishing statistics"] = "mostrar las estadísticas de pesca"
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
    L["Items caught, at the higher of the vendor price and the last scanned auction price."] =
        "Objetos capturados, al mayor entre el precio de vendedor y el último precio de subasta escaneado."
    L["Value per hour of fishing time. Updated with every cast and with Refresh."] =
        "Valor por hora de tiempo de pesca. Se actualiza con cada lanzamiento y con Actualizar."

    -- Debug.lua
    L["OneKeyFishing - debug report"] = "OneKeyFishing - informe de depuración"
    L["show a report to copy into a bug report"] = "mostrar un informe para copiarlo en un aviso de error"

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
    L["Warn when the Fishing rank is capped"] = "Avisar cuando el rango de Pesca esté al máximo"
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
    L["open the settings"] = "abrir la configuración"
    L["Language:"] = "Idioma:"
    L["Interface language"] = "Idioma de la interfaz"
    L["Game client language"] = "Idioma del cliente del juego"
    L["Korean and Chinese may show as squares on a game client in another language."] =
        "El coreano y el chino pueden verse como cuadrados en un cliente del juego en otro idioma."
    L["Pick English to get a readable interface back."] = "Elige English para recuperar una interfaz legible."
    L["The language changes after reloading the interface."] = "El idioma cambia después de recargar la interfaz."
    L["Reload now"] = "Recargar ahora"
    L["Later"] = "Más tarde"

    -- UI/ItemHooks.lua
    L["OneKeyFishing: fishing gear (Alt+Click to remove)"] = "OneKeyFishing: equipo de pesca (Alt+clic para quitar)"
    L["OneKeyFishing: Alt+Click to add to fishing gear"] = "OneKeyFishing: Alt+clic para añadir al equipo de pesca"

    -- UI/Minimap.lua
    L["Leave fishing mode"] = "Salir del modo pesca"
    L["Enter fishing mode"] = "Entrar en el modo pesca"
    L["Statistics"] = "Estadísticas"
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
end)
