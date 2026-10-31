-- French translation. Keys are the English texts of Locales/enUS.lua.
local _, ns = ...

ns.AddTranslation("frFR", "Français", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "Action de pêche (lancer / ferrer)"
    L["Toggle fishing mode"] = "Activer/désactiver le mode pêche"
    L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] =
        "Vos données sauvegardées viennent d'une version plus récente de OneKeyFishing. " ..
        "Mettez l'addon à jour pour éviter les problèmes."
    L["Your game client has no translation, so the addon is in English. Others, such as %s, are in /okf config."] =
        "Il n'y a pas de traduction pour votre client de jeu, l'addon est donc en anglais. " ..
        "D'autres langues, comme %s, sont dans /okf config."

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

    -- Skill.lua
    L["Apprentice"] = "Apprenti"
    L["Journeyman"] = "Compagnon"
    L["Expert"] = "Expert"
    L["Artisan"] = "Artisan"
    L["Any fishing trainer teaches it (capitals and towns; the minimap can track trainers)."] =
        "N'importe quel maître de pêche l'enseigne (capitales et villes ; la minicarte peut suivre les maîtres)."
    L["Buy the book \"%s\" from %s in %s, %s."] = "Achetez le livre « %s » à %s (%s, %s)."
    L["Do the quest \"%s\" from %s at %s, %s."] = "Faites la quête « %s » de %s (%s, %s)."
    L["%s Fishing needs character level %d."] = "Le rang %s de Pêche requiert le niveau %d."
    L["Map pin"] = "Repère sur la carte"
    L["Fishing skill capped (%d/%d): learn %s Fishing to go on."] =
        "Pêche au maximum (%d/%d) : apprenez le rang %s de Pêche pour progresser."
    L["You can learn %s Fishing now."] = "Vous pouvez apprendre le rang %s de Pêche."
    L["Next rank: %s Fishing, from skill %d."] = "Rang suivant : %s de Pêche, dès la compétence %d."
    L["Next rank: %s Fishing, from skill %d and character level %d."] =
        "Rang suivant : %s de Pêche, dès la compétence %d et le niveau %d."
    L["Next rank: %s Fishing, from character level %d."] = "Rang suivant : %s de Pêche, dès le niveau %d."
    L["Next rank: %s Fishing, ready to learn."] = "Rang suivant : %s de Pêche, à apprendre maintenant."

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

    -- UI/MapPin.lua
    L["The game did not accept the map pin."] = "Le jeu n'a pas accepté le repère sur la carte."
    L["Map pin: %s"] = "Repère sur la carte : %s"
    L["Replace your map pin with this place?"] = "Remplacer votre repère sur la carte par ce lieu ?"
    L["Replace"] = "Remplacer"

    -- UI/StatsFrame.lua
    L["Pin"] = "Repère"
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
    L["Items caught, at the higher of vendor and auction price; with few lots listed, the vendor price."] =
        "Objets pêchés, au plus élevé du prix marchand et du prix à l'hôtel des ventes ; avec peu de lots, le prix " ..
        "marchand."
    L["Value per hour of fishing time. Updated with every cast and with Refresh."] =
        "Valeur par heure de pêche. Mise à jour à chaque lancer et avec Actualiser."

    -- UI/CatchHere.lua and the tabs of UI/StatsFrame.lua
    L["Statistics"] = "Statistiques"
    L["What can be caught here"] = "Ce qu'on pêche ici"
    L["Skill: %s"] = "Compétence : %s"
    L["All skill levels"] = "Tous les niveaux de compétence"
    L["Source: %s"] = "Source : %s"
    L["All"] = "Tout"
    L["Only mine"] = "Seulement les miennes"
    L["%d catches"] = "%d prises"
    L["Nothing caught: %s"] = "Rien de pêché : %s"
    L["Numbers for the whole map: few catches at this spot."] =
        "Chiffres de toute la carte : trop peu de prises à cet endroit."
    L["Little data"] = "Peu de données"
    L["Nothing has been caught here yet."] = "Rien n'a encore été pêché ici."
    L["Try \"All skill levels\": little data for your skill."] =
        "Essayez « Tous les niveaux de compétence » : peu de données pour votre compétence."
    L["and %d more"] = "et %d de plus"
    L["No bundled data in this version: only your own catches are shown."] =
        "Aucune donnée incluse dans cette version : seules vos propres prises sont affichées."
    L["The game does not show this place on the map."] = "Le jeu n'affiche pas cet endroit sur la carte."
    L["Item"] = "Objet"
    L["Chance"] = "Chance"
    L["Per catch"] = "Par prise"
    L["Price"] = "Prix"


    -- Prices (the few-lots mark in both tabs)
    L["few lots"] = "peu de lots"
    L["Auction price: %s (few lots)"] = "Prix à l'hôtel des ventes : %s (peu de lots)"

    -- Debug.lua
    L["OneKeyFishing - debug report"] = "OneKeyFishing - rapport de débogage"

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
    L["Remind me about the next Fishing rank"] = "Me rappeler le rang de Pêche suivant"
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
    L["Language:"] = "Langue :"
    L["Interface language"] = "Langue de l'interface"
    L["Game client language"] = "Langue du client de jeu"
    L["Korean and Chinese may show as squares on a game client in another language."] =
        "Le coréen et le chinois peuvent s'afficher sous forme de carrés sur un client de jeu dans une autre langue."
    L["Pick English to get a readable interface back."] = "Choisissez English pour retrouver une interface lisible."
    L["The language changes after reloading the interface."] = "La langue change après le rechargement de l'interface."
    L["Reload now"] = "Recharger"
    L["Later"] = "Plus tard"
    L["Yes"] = "Oui"
    L["No"] = "Non"
    L["Cancel"] = "Annuler"

    -- UI/ItemHooks.lua
    L["OneKeyFishing: fishing gear (Alt+Click to remove)"] =
        "OneKeyFishing : équipement de pêche (Alt+Clic pour retirer)"
    L["OneKeyFishing: Alt+Click to add to fishing gear"] =
        "OneKeyFishing : Alt+Clic pour ajouter à l'équipement de pêche"

    -- UI/Minimap.lua
    L["Pin: next Fishing rank"] = "Repère : rang de Pêche suivant"
    L["Leave fishing mode"] = "Quitter le mode pêche"
    L["Enter fishing mode"] = "Entrer en mode pêche"
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

    -- Share.lua
    L["OneKeyFishing now shares your catches under a random ID with your guild, group and friends who use it."] =
        "OneKeyFishing partage désormais vos prises sous un identifiant aléatoire avec votre guilde, votre groupe " ..
        "et vos amis qui l'utilisent."
    L["No character names are sent, but the players you exchange with can tell which ID is yours."] =
        "Aucun nom de personnage n'est envoyé, mais les joueurs avec qui vous échangez peuvent savoir quel " ..
        "identifiant est le vôtre."
    L["Turn it off in Options -> AddOns -> OneKeyFishing -> Shared database."] =
        "Désactivez-le dans Options -> AddOns -> OneKeyFishing -> Base de données partagée."
    L["Got it"] = "Compris"
    L["Shared database"] = "Base de données partagée"
    L["Shared catch database is off"] = "La base de données de prises partagée est désactivée"
    L["Waiting for you to read the notice"] = "En attente : lisez d'abord l'avis"
    L["Exchange unavailable: the game refuses addon messages"] =
        "Échange indisponible : le jeu refuse les messages d'addon"
    L["Exchange paused: in combat"] = "Échange en pause : en combat"
    L["Exchange paused: in an instance"] = "Échange en pause : dans une instance"
    L["Exchange paused: loading screen"] = "Échange en pause : écran de chargement"
    L["Exchange paused: the game restricts addon messages here"] =
        "Échange en pause : le jeu restreint ici les messages d'addon"
    L["Exchange paused: the game asked to slow down"] = "Échange en pause : le jeu demande de ralentir"
    L["Nobody to exchange with right now"] = "Personne avec qui échanger pour le moment"
    L["Exchange: %d players, %s ago"] = "Échange : %d joueurs, il y a %s"
    L["Exchange: waiting for the first exchange"] = "Échange : en attente du premier échange"
    L["Bundled data: version %d, %d places"] = "Données fournies : version %d, %d lieux"
    L["Records held: %d, %d places"] = "Contributions conservées : %d, %d lieux"
    L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d"] =
        "Joueurs entendus dans la dernière heure : guilde %d, groupe %d, amis %d, Battle.net %d"
    L["Players exchanged with in the last hour: %d"] = "Joueurs avec un échange dans la dernière heure : %d"
    L["Last exchange: %s ago"] = "Dernier échange : il y a %s"
    L["Last exchange: none yet"] = "Dernier échange : aucun pour l'instant"
    L["Traffic in the last hour: %d KB"] = "Trafic de la dernière heure : %d Ko"

    -- UI/Settings.lua: the Shared database page
    L["Use the shared catch database"] = "Utiliser la base de données de prises partagée"
    L["Your catches (items, counts, map cells, the average spot you fish from) are shared under a random ID."] =
        "Vos prises (objets, nombres, cases de carte, l'endroit moyen d'où vous pêchez) sont partagées sous un " ..
        "identifiant aléatoire."
    L["They go to addon users in your guild, group and friends list. No names or gear."] =
        "Elles vont aux utilisateurs de l'addon de votre guilde, groupe et liste d'amis. Ni noms, ni équipement."
    L["The players you exchange with can tell which ID is yours."] =
        "Les joueurs avec qui vous échangez peuvent savoir quel identifiant est le vôtre."
    L["Turned off: nothing is sent or received, and other players' data is not counted."] =
        "Désactivé : rien n'est envoyé ni reçu, et les données des autres joueurs ne sont pas comptées."

    -- UI/CatchHere.lua: other players' catches
    L["%d catches from %d players"] = "%d prises de %d joueurs"

    -- UI/CatchHere.lua: items the game client does not know yet (part 3)
    L["Unknown item"] = "Objet inconnu"
    L["The game has not shown this item yet."] = "Le jeu n'a pas encore montré cet objet."
    L["Reported by %d players on this map"] = "Signalé par %d joueurs sur cette carte"
    L["In the bundled data"] = "Dans les données fournies"
    L["Item ID: %d"] = "ID de l'objet : %d"

    -- Channel.lua: the hidden public channel (part 3)
    L["OneKeyFishing left its hidden channel to free a chat channel slot. Try joining again."] =
        "OneKeyFishing a quitté son canal caché pour libérer une place de canal de discussion. Réessayez."

    -- UI/Settings.lua: the public channel (part 3)
    L["Use the public channel"] = "Utiliser le canal public"
    L["With the public channel on, they also go to every other addon user, through a hidden chat channel."] =
        "Avec le canal public activé, elles vont aussi à tous les autres utilisateurs de l'addon, par un canal de " ..
        "discussion caché."
    L["Anyone who joins that channel by its name can see which characters in it use the addon."] =
        "Quiconque rejoint ce canal par son nom peut voir quels personnages y utilisent l'addon."

    -- Share.lua: the public channel (part 3)
    L["OneKeyFishing now shares your catches under a random ID with other players who use it."] =
        "OneKeyFishing partage désormais vos prises sous un identifiant aléatoire avec les autres joueurs qui " ..
        "l'utilisent."
    L["It reaches your guild, group and friends, and anyone else through a hidden chat channel."] =
        "Cela atteint votre guilde, votre groupe et vos amis, et n'importe qui d'autre par un canal de discussion " ..
        "caché."
    L["Public channel: in use"] = "Canal public : en service"
    L["Public channel: in use (fallback channel %d)"] = "Canal public : en service (canal de secours %d)"
    L["Public channel: off"] = "Canal public : désactivé"
    L["Public channel: no free chat channel slot"] = "Canal public : aucune place de canal de discussion libre"
    L["Public channel: locked or refused by the game"] = "Canal public : verrouillé ou refusé par le jeu"
    L["Public channel: you left it, back at the next login"] =
        "Canal public : vous l'avez quitté, de retour à la prochaine connexion"
    L["Public channel: waiting"] = "Canal public : en attente"
    L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d, channel %d"] =
        "Joueurs entendus dans la dernière heure : guilde %d, groupe %d, amis %d, Battle.net %d, canal %d"

    -- Catalog.lua: the catch catalog (part 4)
    L["Unknown zone (%d)"] = "Zone inconnue (%d)"

    -- Catalog.lua: spots
    L["%s (%s)"] = "%s (%s)"
    L["No exact spot"] = "Pas d'endroit précis"

    -- UI/CatalogTab.lua, UI/StatsFrame.lua, UI/CatchHere.lua: the catch catalog (part 4)
    L["Catch catalog"] = "Catalogue des prises"
    L["Search by item name"] = "Rechercher par nom d'objet"
    L["Zones: %d"] = "Zones : %d"
    L["Back"] = "Retour"
    L["Place"] = "Lieu"
    L["Skill"] = "Compétence"
    L["Counting the catch..."] = "Décompte des prises..."
    L["Nothing has been caught yet."] = "Rien n'a encore été pêché."
    L["The catalog fills with your catches, the bundled data and, with sharing on, other players' catches."] =
        "Le catalogue se remplit de vos prises, des données fournies et, avec le partage activé, des prises des autres "
        .. "joueurs."
    L["You have not caught anything yet."] = "Vous n'avez encore rien pêché."
    L["No item matches the search."] = "Aucun objet ne correspond à la recherche."
    L["No data for this item under these filters."] = "Aucune donnée pour cet objet avec ces filtres."
    L["Click an item to see where else it is caught."] = "Cliquez sur un objet pour voir où il se pêche ailleurs."

    -- UI/CatalogTab.lua: the map pin (part 4)
    L["Set a map pin here"] = "Placer un repère sur la carte ici"

    -- Catalog.lua, UI/ItemHooks.lua, UI/Minimap.lua, UI/Settings.lua: catch chances in tooltips (part 4)
    L["%s (%d players)"] = "%s (%d joueurs)"
    L["Caught in:"] = "Pêché à :"
    L["Likely catch here:"] = "Prise probable ici :"
    L["Show catch chances in tooltips"] = "Afficher les chances de prise dans les infobulles"

    -- UI/CatchHere.lua, UI/CatalogTab.lua: the Water filter (part 4)
    L["Water: %s"] = "Eau : %s"
    L["Everywhere"] = "Partout"
    L["Open water"] = "Eaux libres"
    L["Pools"] = "Bancs"
end)
