-- French translation. Keys are the English texts of Locales/enUS.lua.
local _, ns = ...

ns.AddTranslation("frFR", "Français", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "Action de pêche (lancer / ferrer)"
    L["Toggle fishing mode"] = "Activer/désactiver le mode pêche"
    L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] =
        "Vos données sauvegardées viennent d'une version plus récente de OneKeyFishing. " ..
        "Mettez l'addon à jour pour éviter les problèmes."
    L["v%s commands:"] = "Commandes v%s :"

    -- Gear.lua
    L["Fishing pole set."] = "Canne à pêche choisie."
    L["This item cannot be used as fishing gear."] = "Cet objet ne peut pas servir d'équipement de pêche."
    L["Already in the list."] = "Déjà dans la liste."
    L["Added."] = "Ajouté."
    L["Fishing pole: automatic (best in bags)."] = "Canne à pêche : automatique (la meilleure de vos sacs)."
    L["Removed from fishing gear."] = "Retiré de l'équipement de pêche."
    L["No fishing pole found in your bags."] = "Aucune canne à pêche dans vos sacs."
    L["%d fishing item(s) are not in your bags."] = "%d objet(s) de pêche ne sont pas dans vos sacs."
    L["No free bag space to take off %s."] = "Pas de place libre dans les sacs pour retirer %s."
    L["an item"] = "un objet"

    -- Bags.lua
    L["Cannot apply %s, skipping it until fishing mode is turned on again."] =
        "Impossible d'appliquer %s, il est ignoré jusqu'à la prochaine activation du mode pêche."
    L["Not enough bag space to loot %s. It will be opened again when you free a bag slot."] =
        "Pas assez de place dans les sacs pour ramasser le contenu de %s. " ..
        "Il sera rouvert dès qu'un emplacement se libère."
    L["Cannot open %s, skipping it for this session."] = "Impossible d'ouvrir %s, il est ignoré pour cette session."

    -- Action.lua
    L["You have not learned Fishing."] = "Vous n'avez pas appris la Pêche."
    L["No key is bound to 'Fishing action'. Bind one in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
        "Aucune touche n'est assignée à « Action de pêche ». " ..
        "Assignez-en une dans Options -> Raccourcis -> AddOns -> OneKeyFishing."

    -- Mode.lua
    L["Cannot enter fishing mode in combat."] = "Impossible d'activer le mode pêche en combat."
    L["Fishing mode %s."] = "Mode pêche %s."
    L["ON"] = "ACTIVÉ"
    L["OFF"] = "DÉSACTIVÉ"
    L["Restored game settings from an unfinished fishing session."] =
        "Paramètres du jeu restaurés après une session de pêche inachevée."
    L["Fishing mode is off. Press your 'Toggle fishing mode' key first."] =
        "Le mode pêche est désactivé. Appuyez d'abord sur votre touche « Activer/désactiver le mode pêche »."
    L["The fishing key is paused in combat."] = "La touche de pêche est en pause pendant le combat."
    L["Leaving fishing mode after combat."] = "Sortie du mode pêche après le combat."
    L["enter or leave fishing mode"] = "activer ou désactiver le mode pêche"

    -- Auction.lua
    L["Scanning %d/%d"] = "Analyse %d/%d"
    L["Scan fish prices"] = "Analyser les prix"
    L["Auction scan finished: %d of %d price(s) found."] =
        "Analyse de l'hôtel des ventes terminée : %d prix trouvé(s) sur %d."
    L["Open the auction house first."] = "Ouvrez d'abord l'hôtel des ventes."
    L["Nothing to scan yet: catch some fish first."] =
        "Rien à analyser pour l'instant : pêchez d'abord quelques poissons."
    L["Scanning auction prices of %d item(s)..."] = "Analyse des prix de %d objet(s) à l'hôtel des ventes..."
    L["Auction scan stopped: %d of %d price(s) found."] =
        "Analyse de l'hôtel des ventes interrompue : %d prix trouvé(s) sur %d."
    L["scan auction prices of caught items (auction house must be open)"] =
        "analyser les prix des prises à l'hôtel des ventes (l'hôtel des ventes doit être ouvert)"

    -- Skill.lua
    L["Apprentice"] = "Apprenti"
    L["Journeyman"] = "Compagnon"
    L["Expert"] = "Expert"
    L["Artisan"] = "Artisan"
    L["a fishing trainer"] = "un maître de pêche"
    L["the book \"Expert Fishing - The Bass and You\" (Old Man Heming, Booty Bay)"] =
        "le livre « Expert Fishing - The Bass and You » (Old Man Heming, Baie-du-Butin)"
    L["the quest from Nat Pagle (Dustwallow Marsh)"] = "la quête de Nat Pagle (marécage d'Âprefange)"
    L["Fishing skill capped (%d/%d): learn %s Fishing from %s."] =
        "Compétence de Pêche au maximum (%d/%d) : apprenez le rang %s de Pêche, source : %s."
    L["Fishing %d/%d: %d point(s) left in this rank. Next: %s Fishing from %s."] =
        "Pêche %d/%d : encore %d point(s) dans ce rang. Ensuite : rang %s de Pêche, source : %s."

    -- UI/CopyWindow.lua
    L["Click the text, then Ctrl+A and Ctrl+C to copy."] = "Cliquez sur le texte, puis Ctrl+A et Ctrl+C pour copier."

    -- UI/Indicator.lua
    L["Cast"] = "Lancer"
    L["Hook!"] = "Ferrer !"
    L["Apply lure"] = "Appâter"
    L["Open"] = "Ouvrir"
    L["No bobber"] = "Pas de bouchon"
    L["Drag to move. Lock it in the settings."] = "Faites glisser pour déplacer. Verrouillez-le dans les options."

    -- UI/Toast.lua
    L["Caught: %s"] = "Prise : %s"
    L["Nothing caught"] = "Rien de pêché"

    -- UI/StatsFrame.lua
    L["Time fishing"] = "Temps de pêche"
    L["Time casting"] = "Temps de lancer"
    L["Casts"] = "Lancers"
    L["Catches"] = "Prises"
    L["Catches per hour"] = "Prises par heure"
    L["Value"] = "Valeur"
    L["Gold per hour"] = "Or par heure"
    L["OneKeyFishing - Statistics"] = "OneKeyFishing - Statistiques"
    L["Session"] = "Session"
    L["This zone"] = "Cette zone"
    L["All time"] = "Total"
    L["Top catches (all time)"] = "Meilleures prises (total)"
    L["Zones (all time)"] = "Zones (total)"
    L["Reset session"] = "Réinitialiser la session"
    L["Reset the fishing statistics of this session?"] = "Réinitialiser les statistiques de pêche de cette session ?"
    L["Reset all"] = "Tout réinitialiser"
    L["Delete ALL fishing statistics of this character?"] =
        "Supprimer TOUTES les statistiques de pêche de ce personnage ?"
    L["Scan auction prices"] = "Analyser les prix de l'HV"
    L["Fishing skill: %d/%d %s%s"] = "Compétence de Pêche : %d/%d %s%s"
    L["(+%d this session)"] = "(+%d cette session)"
    L["Fishing is not learned."] = "La Pêche n'est pas apprise."
    L["Values: higher of vendor and auction price (scanned %s)"] =
        "Valeurs : le plus élevé du prix marchand et du prix de l'HV (analysé %s)"
    L["%dm"] = "%d min"
    L["%dh %02dm"] = "%d h %02d"
    L["Values: vendor price (scan the auction house for market prices)"] =
        "Valeurs : prix marchand (analysez l'hôtel des ventes pour les prix du marché)"
    L["%d catches, %s"] = "%d prises, %s"
    L["No catches yet."] = "Aucune prise pour l'instant."
    L["show the fishing statistics"] = "afficher les statistiques de pêche"
    L["Time"] = "Temps"
    L["Results"] = "Résultats"
    L["Money"] = "Argent"
    L["Refresh"] = "Actualiser"
    L["Time in fishing mode. Paused while AFK if that option is on."] =
        "Temps passé en mode pêche. En pause en cas d'absence (ABS) si cette option est activée."
    L["Time with the bobber in the water."] = "Temps passé avec le bouchon dans l'eau."
    L["Fishing casts made in fishing mode."] = "Lancers de pêche effectués en mode pêche."
    L["Casts that brought loot."] = "Lancers qui ont rapporté du butin."
    L["Casts that ended without loot."] = "Lancers terminés sans butin."
    L["Catches per hour of fishing time. Updated with every cast and with Refresh."] =
        "Prises par heure de pêche. Mis à jour à chaque lancer et avec Actualiser."
    L["Items caught, at the higher of the vendor price and the last scanned auction price."] =
        "Objets pêchés, au plus élevé du prix marchand et du dernier prix analysé à l'hôtel des ventes."
    L["Value per hour of fishing time. Updated with every cast and with Refresh."] =
        "Valeur par heure de pêche. Mise à jour à chaque lancer et avec Actualiser."

    -- Debug.lua
    L["OneKeyFishing - debug report"] = "OneKeyFishing - rapport de débogage"
    L["show a report to copy into a bug report"] = "afficher un rapport à copier dans un signalement de bug"

    -- UI/Settings.lua
    L["Auto loot while fishing"] = "Butin automatique pendant la pêche"
    L["Show the interact icon over the bobber"] = "Afficher l'icône d'interaction au-dessus du bouchon"
    L["Leave fishing mode when attacked"] = "Quitter le mode pêche en cas d'attaque"
    L["Equip fishing pole and fishing gear"] = "Équiper la canne à pêche et l'équipement de pêche"
    L["Apply lures automatically"] = "Appliquer les appâts automatiquement"
    L["Open clams and fished containers"] = "Ouvrir les palourdes et les coffres pêchés"
    L["Show the action indicator and cast timer"] = "Afficher l'indicateur d'action et le minuteur de lancer"
    L["Lock the indicator position"] = "Verrouiller la position de l'indicateur"
    L["Show catch notifications"] = "Afficher les notifications de prise"
    L["Show session fishing time under the indicator"] = "Afficher le temps de pêche de la session sous l'indicateur"
    L["Pause the fishing timer while AFK"] = "Mettre en pause le temps de pêche en cas d'absence (ABS)"
    L["Warn when the Fishing rank is capped"] = "Avertir quand le rang de Pêche est au maximum"
    L["Use scanned auction prices for catch value"] = "Utiliser les prix analysés de l'HV pour la valeur des prises"
    L["Zoom the camera while fishing"] = "Zoomer la caméra pendant la pêche"
    L["Show the minimap button"] = "Afficher le bouton de la minicarte"
    L["not bound"] = "non assignée"
    L["Keys"] = "Touches"
    L["Change them in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
        "Modifiez-les dans Options -> Raccourcis -> AddOns -> OneKeyFishing."
    L["WoW names punctuation keys (' ; [ , .) by keyboard language: bind them in both slots, once per language."] =
        "WoW nomme les touches de ponctuation (' ; [ , .) selon la langue du clavier : " ..
        "assignez-les dans les deux emplacements, une fois par langue."
    L["Features"] = "Fonctions"
    L["Auto loot, bobber icon and gear changes apply the next time you enter fishing mode."] =
        "Le butin automatique, l'icône du bouchon et les changements d'équipement " ..
        "s'appliquent à la prochaine activation du mode pêche."
    L["Camera distance while fishing:"] = "Distance de la caméra pendant la pêche :"
    L["Actions"] = "Actions"
    L["Debug report"] = "Rapport de débogage"
    L["Open statistics"] = "Ouvrir les statistiques"
    L["Reset indicator position"] = "Réinitialiser la position de l'indicateur"
    L["(open the auction house first)"] = "(ouvrez d'abord l'hôtel des ventes)"
    L["Fishing action: %s      Toggle fishing mode: %s"] = "Action de pêche : %s      Mode pêche : %s"
    L["Remove"] = "Retirer"
    L["Fishing gear"] = "Équipement de pêche"
    L["Fishing pole"] = "Canne à pêche"
    L["Use the best pole automatically"] = "Utiliser automatiquement la meilleure canne"
    L["Add an item"] = "Ajouter un objet"
    L["Easiest: close this window and Alt+Click an item in your bags or on the character panel."] =
        "Le plus simple : fermez cette fenêtre et faites Alt+Clic sur un objet dans vos sacs " ..
        "ou dans la fiche du personnage."
    L["Alt+Click it again to remove it. A fishing pole becomes your chosen pole."] =
        "Refaites Alt+Clic pour le retirer. Une canne à pêche devient votre canne choisie."
    L["Here you can type an item name, or find all items with a fishing bonus automatically."] =
        "Ici, vous pouvez saisir le nom d'un objet ou trouver automatiquement tous les objets avec un bonus de pêche."
    L["Item not found. Check the name, or Alt+Click the item in your bags."] =
        "Objet introuvable. Vérifiez le nom ou faites Alt+Clic sur l'objet dans vos sacs."
    L["Add"] = "Ajouter"
    L["Find fishing items"] = "Trouver les objets de pêche"
    L["Added %d item(s)."] = "%d objet(s) ajouté(s)."
    L["No new items with a fishing bonus found."] = "Aucun nouvel objet avec un bonus de pêche trouvé."
    L["Extra fishing gear"] = "Équipement de pêche supplémentaire"
    L["No items yet."] = "Aucun objet pour l'instant."
    L["Chosen: %s (+%d)"] = "Choisie : %s (+%d)"
    L["Automatic, best in your bags: %s (+%d)"] = "Automatique, la meilleure de vos sacs : %s (+%d)"
    L["Automatic: no fishing pole in your bags."] = "Automatique : aucune canne à pêche dans vos sacs."
    L["Settings cannot be opened in combat."] = "Les options ne peuvent pas être ouvertes en combat."
    L["Settings panel is not available in this client."] = "Le panneau des options n'est pas disponible sur ce client."
    L["open the settings"] = "ouvrir les options"
    L["Language:"] = "Langue :"
    L["Interface language"] = "Langue de l'interface"
    L["Game client language"] = "Langue du client de jeu"
    L["Korean and Chinese may show as squares on a game client in another language."] =
        "Le coréen et le chinois peuvent s'afficher sous forme de carrés sur un client de jeu dans une autre langue."
    L["Pick English to get a readable interface back."] = "Choisissez English pour retrouver une interface lisible."
    L["The language changes after reloading the interface."] = "La langue change après le rechargement de l'interface."
    L["Reload now"] = "Recharger"
    L["Later"] = "Plus tard"

    -- UI/ItemHooks.lua
    L["OneKeyFishing: fishing gear (Alt+Click to remove)"] =
        "OneKeyFishing : équipement de pêche (Alt+Clic pour retirer)"
    L["OneKeyFishing: Alt+Click to add to fishing gear"] =
        "OneKeyFishing : Alt+Clic pour ajouter à l'équipement de pêche"

    -- UI/Minimap.lua
    L["Leave fishing mode"] = "Quitter le mode pêche"
    L["Enter fishing mode"] = "Entrer en mode pêche"
    L["Statistics"] = "Statistiques"
    L["Settings"] = "Options"
    L["Fishing mode: %s"] = "Mode pêche : %s"
    L["Fishing skill: %d/%d %s"] = "Compétence de Pêche : %d/%d %s"
    L["Session: %d catches, %s"] = "Session : %d prises, %s"
    L["Fishing key:"] = "Touche de pêche :"
    L["Toggle mode key:"] = "Touche du mode :"
    L["How to use: press the toggle key, then the fishing key to cast,"] =
        "Utilisation : appuyez sur la touche du mode, puis sur la touche de pêche pour lancer,"
    L["and the same key again when the bobber splashes."] =
        "et de nouveau sur la même touche quand le bouchon plonge."
    L["Alt+Click items in your bags to add fishing gear."] =
        "Alt+Clic sur des objets de vos sacs pour ajouter de l'équipement de pêche."
    L["Left-click: toggle fishing mode"] = "Clic gauche : activer/désactiver le mode pêche"
    L["Shift+Left-click: statistics"] = "Maj+Clic gauche : statistiques"
    L["Right-click: menu"] = "Clic droit : menu"
    L["Drag: move this button"] = "Glisser : déplacer ce bouton"
end)
