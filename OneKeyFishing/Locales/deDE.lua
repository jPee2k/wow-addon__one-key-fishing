-- German translation. Keys are the English texts of Locales/enUS.lua.
local _, ns = ...

ns.AddTranslation("deDE", "Deutsch", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "Angelaktion (Auswerfen / Anhieb)"
    L["Toggle fishing mode"] = "Angelmodus umschalten"
    L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] =
        "Deine gespeicherten Daten stammen aus einer neueren Version von OneKeyFishing. " ..
        "Aktualisiere das Addon, um Probleme zu vermeiden."
    L["Your game client has no translation, so the addon is in English. Others, such as %s, are in /okf config."] =
        "Für deinen Spielclient gibt es keine Übersetzung, daher ist das Addon auf Englisch. " ..
        "Weitere Sprachen, etwa %s, gibt es unter /okf config."

    -- Gear.lua
    L["Fishing pole set."] = "Angelrute festgelegt."
    L["This item cannot be used as fishing gear."] =
        "Dieser Gegenstand kann nicht als Angelausrüstung verwendet werden."
    L["Already in the list."] = "Bereits in der Liste."
    L["Added."] = "Hinzugefügt."
    L["Fishing pole: automatic (best in bags)."] = "Angelrute: automatisch (beste in den Taschen)."
    L["Removed from fishing gear."] = "Aus der Angelausrüstung entfernt."
    L["No fishing pole found in your bags."] = "Keine Angelrute in deinen Taschen gefunden."
    L["%d fishing item(s) are not in your bags."] = "%d Angelgegenstand/-gegenstände nicht in deinen Taschen."
    L["No free bag space to take off %s."] = "Kein freier Taschenplatz, um %s abzulegen."
    L["Fishing mode needs a free bag slot for %s."] = "Der Angelmodus braucht einen freien Taschenplatz für %s."
    L["an item"] = "einen Gegenstand"

    -- Bags.lua
    L["Cannot apply %s, skipping it until fishing mode is turned on again."] =
        "%s kann nicht angebracht werden und wird übersprungen, bis der Angelmodus wieder eingeschaltet wird."
    L["Not enough bag space to loot %s. It will be opened again when you free a bag slot."] =
        "Nicht genug Taschenplatz, um %s zu plündern. Es wird erneut geöffnet, sobald ein Taschenplatz frei wird."
    L["Cannot open %s, skipping it for this session."] =
        "%s kann nicht geöffnet werden und wird für diese Sitzung übersprungen."

    -- Action.lua
    L["You have not learned Fishing."] = "Du hast Angeln nicht erlernt."
    L["No key is bound to 'Fishing action'. Bind one in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
        "Keine Taste ist 'Angelaktion' zugewiesen. Lege eine fest unter " ..
        "Optionen -> Tastaturbelegung -> AddOns -> OneKeyFishing."

    -- Mode.lua
    L["Cannot enter fishing mode in combat."] = "Im Kampf kann der Angelmodus nicht aktiviert werden."
    L["Fishing mode %s."] = "Angelmodus %s."
    L["ON"] = "AN"
    L["OFF"] = "AUS"
    L["Restored game settings from an unfinished fishing session."] =
        "Spieleinstellungen einer nicht beendeten Angelsitzung wiederhergestellt."
    L["Fishing mode is off. Press your 'Toggle fishing mode' key first."] =
        "Der Angelmodus ist aus. Drücke zuerst deine Taste für 'Angelmodus umschalten'."
    L["The fishing key is paused in combat."] = "Die Angeltaste ist im Kampf pausiert."
    L["Leaving fishing mode after combat."] = "Der Angelmodus wird nach dem Kampf verlassen."

    -- Auction.lua
    L["Scanning %d/%d"] = "Scanne %d/%d"
    L["Scan fish prices"] = "Fischpreise scannen"
    L["Auction scan finished: %d of %d price(s) found."] = "Auktionsscan beendet: %d von %d Preis(en) gefunden."
    L["Open the auction house first."] = "Öffne zuerst das Auktionshaus."
    L["Nothing to scan yet: catch some fish first."] = "Noch nichts zu scannen: Fang zuerst ein paar Fische."
    L["Scanning auction prices of %d item(s)..."] = "Scanne Auktionspreise von %d Gegenstand/Gegenständen..."
    L["Auction scan stopped: %d of %d price(s) found."] = "Auktionsscan abgebrochen: %d von %d Preis(en) gefunden."
    L["Auction scan stopped: the auction house does not answer (%d of %d price(s) found). Log out and back in."] =
        "Auktionsscan abgebrochen: Das Auktionshaus antwortet nicht (%d von %d Preis(en) gefunden). " ..
        "Logge dich aus und wieder ein."
    L["The auction house does not answer. Log out and back in to bring it back."] =
        "Das Auktionshaus antwortet nicht. Logge dich aus und wieder ein, um es zurückzuholen."
    L["Auction house not answering"] = "Auktionshaus antwortet nicht"

    -- Skill.lua
    L["Apprentice"] = "Lehrling"
    L["Journeyman"] = "Geselle"
    L["Expert"] = "Experte"
    L["Artisan"] = "Fachmann"
    L["Any fishing trainer teaches it (capitals and towns; the minimap can track trainers)."] =
        "Jeder Angellehrer bringt es dir bei (Hauptstädte und Orte; die Minikarte kann Lehrer anzeigen)."
    L["Buy the book \"%s\" from %s in %s, %s."] = "Kaufe das Buch „%s“ bei %s (%s, %s)."
    L["Do the quest \"%s\" from %s at %s, %s."] = "Erledige die Quest „%s“ von %s (%s, %s)."
    L["%s Fishing needs character level %d."] = "Angeln (%s) erfordert Charakterstufe %d."
    L["Map pin"] = "Kartenmarkierung"
    L["Fishing skill capped (%d/%d): learn %s Fishing to go on."] =
        "Angelfertigkeit am Maximum (%d/%d): Lerne Angeln (%s), um weiterzukommen."
    L["You can learn %s Fishing now."] = "Du kannst jetzt Angeln (%s) lernen."
    L["Next rank: %s Fishing, from skill %d."] = "Nächster Rang: Angeln (%s), ab Fertigkeit %d."
    L["Next rank: %s Fishing, from skill %d and character level %d."] =
        "Nächster Rang: Angeln (%s), ab Fertigkeit %d und Charakterstufe %d."
    L["Next rank: %s Fishing, from character level %d."] = "Nächster Rang: Angeln (%s), ab Charakterstufe %d."
    L["Next rank: %s Fishing, ready to learn."] = "Nächster Rang: Angeln (%s), jetzt erlernbar."

    -- UI/CopyWindow.lua
    L["Click the text, then Ctrl+A and Ctrl+C to copy."] = "Klicke in den Text, dann Strg+A und Strg+C zum Kopieren."

    -- UI/Indicator.lua
    L["Cast"] = "Auswerfen"
    L["Hook!"] = "Anhieb!"
    L["Apply lure"] = "Köder anbringen"
    L["Open"] = "Öffnen"
    L["No bobber"] = "Kein Schwimmer"
    L["Paused in combat"] = "Im Kampf pausiert"
    L["Drag to move. Lock it in the settings."] = "Ziehen zum Verschieben. In den Einstellungen fixierbar."

    -- UI/Toast.lua
    L["Caught: %s"] = "Gefangen: %s"
    L["Nothing caught"] = "Nichts gefangen"

    -- Core/MapPin.lua and its toasts in UI/Toast.lua
    L["The game did not accept the map pin."] = "Das Spiel hat die Kartenmarkierung nicht angenommen."
    L["Map pin: %s. Open the world map to see it."] = "Kartenmarkierung: %s. Öffne die Weltkarte, um sie zu sehen."
    L["Replace your map pin with this place?"] = "Deine Kartenmarkierung durch diesen Ort ersetzen?"
    L["Replace"] = "Ersetzen"

    -- UI/StatsFrame.lua
    L["Pin"] = "Markieren"
    L["Time fishing"] = "Angelzeit"
    L["Time casting"] = "Wurfzeit"
    L["Casts"] = "Würfe"
    L["Catches"] = "Fänge"
    L["Catches per hour"] = "Fänge pro Stunde"
    L["Value"] = "Wert"
    L["Gold per hour"] = "Gold pro Stunde"
    L["OneKeyFishing - Statistics"] = "OneKeyFishing - Statistik"
    L["Session"] = "Sitzung"
    L["This zone"] = "Dieses Gebiet"
    L["All time"] = "Gesamt"
    L["Top catches (all time)"] = "Top-Fänge (gesamt)"
    L["Zones (all time)"] = "Gebiete (gesamt)"
    L["Reset session"] = "Sitzung zurücksetzen"
    L["Reset the fishing statistics of this session?"] = "Die Angelstatistik dieser Sitzung zurücksetzen?"
    L["Reset all"] = "Alles zurücksetzen"
    L["Delete ALL fishing statistics of this character?"] = "ALLE Angelstatistiken dieses Charakters löschen?"
    L["Scan auction prices"] = "Auktionspreise scannen"
    L["Fishing skill: %d/%d %s%s"] = "Angelfertigkeit: %d/%d %s%s"
    L["(+%d this session)"] = "(+%d in dieser Sitzung)"
    L["Fishing is not learned."] = "Angeln ist nicht erlernt."
    L["Values: higher of vendor and auction price (scanned %s)"] =
        "Werte: der höhere aus Händler- und Auktionspreis (gescannt %s)"
    L["%dm"] = "%d Min."
    L["%dh %02dm"] = "%d Std. %02d Min."
    L["Values: vendor price (scan the auction house for market prices)"] =
        "Werte: Händlerpreis (scanne das Auktionshaus für Marktpreise)"
    L["%d catches, %s"] = "%d Fänge, %s"
    L["1 catch, %s"] = "1 Fang, %s"
    L["No catches yet."] = "Noch keine Fänge."
    L["Time"] = "Zeit"
    L["Results"] = "Ergebnisse"
    L["Money"] = "Geld"
    L["Refresh"] = "Aktualisieren"
    L["Time in fishing mode. Paused while AFK if that option is on."] =
        "Zeit im Angelmodus. Pausiert, solange du AFK bist, wenn diese Option aktiv ist."
    L["Time with the bobber in the water."] = "Zeit mit dem Schwimmer im Wasser."
    L["Fishing casts made in fishing mode."] = "Im Angelmodus ausgeführte Würfe."
    L["Casts that brought loot."] = "Würfe mit Beute."
    L["Casts that ended without loot."] = "Würfe, die ohne Beute endeten."
    L["Catches per hour of fishing time. Updated with every cast and with Refresh."] =
        "Fänge pro Stunde Angelzeit. Wird bei jedem Wurf und mit Aktualisieren erneuert."
    L["Items caught, at the higher of vendor and auction price; with few lots listed, the vendor price."] =
        "Gefangene Gegenstände, bewertet mit dem höheren aus Händler- und Auktionspreis; bei wenigen Angeboten der " ..
        "Händlerpreis."
    L["Value per hour of fishing time. Updated with every cast and with Refresh."] =
        "Wert pro Stunde Angelzeit. Wird bei jedem Wurf und mit Aktualisieren erneuert."

    -- UI/CatchHere.lua and the tabs of UI/StatsFrame.lua
    L["Statistics"] = "Statistik"
    L["What can be caught here"] = "Was man hier fangen kann"
    L["Skill: Up to %d"] = "Fertigkeit: Bis %d"
    L["Skill: All"] = "Fertigkeit: Alle"
    L["Up to %d"] = "Bis %d"
    L["Up to %d (yours)"] = "Bis %d (deine)"
    L["All (%d+)"] = "Alle (%d+)"
    L["All (%d+) (yours)"] = "Alle (%d+) (deine)"
    L["Catches with skill up to %d."] = "Fänge mit Fertigkeit bis %d."
    L["Catches with any skill."] = "Fänge mit jeder Fertigkeit."
    L["Misses only with skill %s."] = "Würfe ohne Fang nur mit Fertigkeit %s."
    L["Nothing caught: little data"] = "Nichts gefangen: wenige Daten"
    L["Source: %s"] = "Quelle: %s"
    L["All"] = "Alle"
    L["Only mine"] = "Nur meine"
    L["%d catches"] = "%d Fänge"
    L["1 catch"] = "1 Fang"
    L["Nothing caught: %s"] = "Nichts gefangen: %s"
    L["Numbers for the whole map: few catches at this spot."] =
        "Zahlen für die ganze Karte: zu wenige Fänge an dieser Stelle."
    L["Little data"] = "Wenige Daten"
    L["Nothing has been caught here yet."] = "Hier wurde noch nichts gefangen."
    L["and %d more"] = "und %d weitere"
    L["No bundled data in this version: only your own catches are shown."] =
        "Keine mitgelieferten Daten in dieser Version: Nur deine eigenen Fänge werden gezeigt."
    L["No bundled data in this version."] = "Keine mitgelieferten Daten in dieser Version."
    L["The game does not show this place on the map."] = "Das Spiel zeigt diesen Ort nicht auf der Karte."
    L["Item"] = "Gegenstand"
    L["Chance"] = "Chance"
    L["Per catch"] = "Pro Fang"
    L["Price"] = "Preis"


    -- Prices (the few-lots mark in both tabs)
    L["few lots"] = "wenige Angebote"
    L["Auction price (OneKeyFishing): %s (few lots)"] = "Auktionspreis (OneKeyFishing): %s (wenige Angebote)"
    L["Auction price (OneKeyFishing): %s"] = "Auktionspreis (OneKeyFishing): %s"

    -- Debug.lua
    L["OneKeyFishing - debug report"] = "OneKeyFishing - Debug-Bericht"

    -- UI/Settings.lua
    L["Auto loot while fishing"] = "Automatisch plündern beim Angeln"
    L["Show the interact icon over the bobber"] = "Interaktionssymbol über dem Schwimmer anzeigen"
    L["Leave fishing mode when attacked"] = "Angelmodus bei Angriff verlassen"
    L["Equip fishing pole and fishing gear"] = "Angelrute und Angelausrüstung anlegen"
    L["Apply lures automatically"] = "Köder automatisch anbringen"
    L["Open clams and fished containers"] = "Muscheln und geangelte Behälter öffnen"
    L["Show the action indicator and cast timer"] = "Aktionsanzeige und Wurf-Timer anzeigen"
    L["Lock the indicator position"] = "Position der Anzeige fixieren"
    L["Show catch notifications"] = "Fangbenachrichtigungen anzeigen"
    L["Show session fishing time under the indicator"] = "Angelzeit der Sitzung unter der Anzeige anzeigen"
    L["Pause the fishing timer while AFK"] = "Angel-Timer pausieren, solange du AFK bist"
    L["Remind me about the next Fishing rank"] = "An den nächsten Angelrang erinnern"
    L["Use scanned auction prices for catch value"] = "Gescannte Auktionspreise für den Fangwert verwenden"
    L["Zoom the camera while fishing"] = "Kamera beim Angeln zoomen"
    L["Show the minimap button"] = "Minikartenknopf anzeigen"
    L["not bound"] = "nicht belegt"
    L["Keys"] = "Tasten"
    L["Change them in Options -> Keybindings -> AddOns -> OneKeyFishing."] =
        "Ändere sie unter Optionen -> Tastaturbelegung -> AddOns -> OneKeyFishing."
    L["WoW names punctuation keys (' ; [ , .) by keyboard language: bind them in both slots, once per language."] =
        "WoW benennt Satzzeichentasten (' ; [ , .) nach der Tastatursprache: " ..
        "Belege sie in beiden Feldern, einmal pro Sprache."
    L["Features"] = "Funktionen"
    L["Auto loot, bobber icon and gear changes apply the next time you enter fishing mode."] =
        "Automatisches Plündern, Schwimmersymbol und Ausrüstungsänderungen gelten ab dem nächsten Angelmodus."
    L["Camera distance while fishing:"] = "Kameraabstand beim Angeln:"
    L["Actions"] = "Aktionen"
    L["Debug report"] = "Debug-Bericht"
    L["Open statistics"] = "Statistik öffnen"
    L["Reset indicator position"] = "Position der Anzeige zurücksetzen"
    L["Fishing action: %s      Toggle fishing mode: %s"] = "Angelaktion: %s      Angelmodus umschalten: %s"
    L["Remove"] = "Entfernen"
    L["Fishing gear"] = "Angelausrüstung"
    L["Fishing pole"] = "Angelrute"
    L["Use the best pole automatically"] = "Automatisch die beste Angelrute verwenden"
    L["Add an item"] = "Gegenstand hinzufügen"
    L["Easiest: close this window and Alt+Click an item in your bags or on the character panel."] =
        "Am einfachsten: Schließe dieses Fenster und nutze Alt+Klick auf einen Gegenstand " ..
        "in deinen Taschen oder im Charakterfenster."
    L["Alt+Click it again to remove it. A fishing pole becomes your chosen pole."] =
        "Erneuter Alt+Klick entfernt ihn. Eine Angelrute wird zu deiner gewählten Angelrute."
    L["Here you can type an item name, or find all items with a fishing bonus automatically."] =
        "Hier kannst du einen Gegenstandsnamen eingeben oder alle Gegenstände mit Angelbonus automatisch finden."
    L["Item not found. Check the name, or Alt+Click the item in your bags."] =
        "Gegenstand nicht gefunden. Prüfe den Namen oder nutze Alt+Klick auf den Gegenstand in deinen Taschen."
    L["Add"] = "Hinzufügen"
    L["Find fishing items"] = "Angelgegenstände finden"
    L["Added %d item(s)."] = "%d Gegenstand/Gegenstände hinzugefügt."
    L["No new items with a fishing bonus found."] = "Keine neuen Gegenstände mit Angelbonus gefunden."
    L["Extra fishing gear"] = "Zusätzliche Angelausrüstung"
    L["No items yet."] = "Noch keine Gegenstände."
    L["Chosen: %s (+%d)"] = "Gewählt: %s (+%d)"
    L["Automatic, best in your bags: %s (+%d)"] = "Automatisch, beste in deinen Taschen: %s (+%d)"
    L["Automatic: no fishing pole in your bags."] = "Automatisch: keine Angelrute in deinen Taschen."
    L["Settings cannot be opened in combat."] = "Die Einstellungen können im Kampf nicht geöffnet werden."
    L["Settings panel is not available in this client."] =
        "Das Einstellungsfenster ist in diesem Client nicht verfügbar."
    L["Language:"] = "Sprache:"
    L["Interface language"] = "Oberflächensprache"
    L["Game client language"] = "Sprache des Spielclients"
    L["Korean and Chinese may show as squares on a game client in another language."] =
        "Koreanisch und Chinesisch können in einem Spielclient mit anderer Sprache als Kästchen erscheinen."
    L["Pick English to get a readable interface back."] =
        "Wähle English, um wieder eine lesbare Oberfläche zu erhalten."
    L["The language changes after reloading the interface."] =
        "Die Sprache ändert sich nach dem Neuladen der Oberfläche."
    L["Reload now"] = "Jetzt neu laden"
    L["Later"] = "Später"
    L["Yes"] = "Ja"
    L["No"] = "Nein"
    L["Cancel"] = "Abbrechen"

    -- UI/ItemHooks.lua
    L["OneKeyFishing: fishing gear (Alt+Click to remove)"] = "OneKeyFishing: Angelausrüstung (Alt+Klick zum Entfernen)"
    L["OneKeyFishing: Alt+Click to add to fishing gear"] =
        "OneKeyFishing: Alt+Klick, um zur Angelausrüstung hinzuzufügen"

    -- UI/Minimap.lua
    L["Pin: next Fishing rank"] = "Markieren: nächster Angelrang"
    L["Leave fishing mode"] = "Angelmodus verlassen"
    L["Enter fishing mode"] = "Angelmodus aktivieren"
    L["Settings"] = "Einstellungen"
    L["Fishing mode: %s"] = "Angelmodus: %s"
    L["Fishing skill: %d/%d %s"] = "Angelfertigkeit: %d/%d %s"
    L["Session: %d catches, %s"] = "Sitzung: %d Fänge, %s"
    L["Session: 1 catch, %s"] = "Sitzung: 1 Fang, %s"
    L["Fishing key:"] = "Angeltaste:"
    L["Toggle mode key:"] = "Modus-Taste:"
    L["How to use: press the toggle key, then the fishing key to cast,"] =
        "So geht's: Drücke die Modus-Taste, dann die Angeltaste zum Auswerfen"
    L["and the same key again when the bobber splashes."] = "und dieselbe Taste erneut, wenn der Schwimmer platscht."
    L["Alt+Click items in your bags to add fishing gear."] =
        "Alt+Klick auf Gegenstände in deinen Taschen fügt Angelausrüstung hinzu."
    L["Left-click: toggle fishing mode"] = "Linksklick: Angelmodus umschalten"
    L["Shift+Left-click: statistics"] = "Umschalt+Linksklick: Statistik"
    L["Right-click: menu"] = "Rechtsklick: Menü"
    L["Drag: move this button"] = "Ziehen: Knopf verschieben"

    -- Share.lua
    L["OneKeyFishing now shares your catches under a random ID with your guild, group and friends who use it."] =
        "OneKeyFishing teilt deine Fänge jetzt unter einer zufälligen ID mit deiner Gilde, Gruppe und deinen " ..
        "Freunden, die es nutzen."
    L["No character names are sent, but the players you exchange with can tell which ID is yours."] =
        "Es werden keine Charakternamen gesendet, aber die Spieler, mit denen du Daten austauschst, können " ..
        "erkennen, welche ID deine ist."
    L["Turn it off in Options -> AddOns -> OneKeyFishing -> Shared database."] =
        "Abschalten unter Optionen -> AddOns -> OneKeyFishing -> Gemeinsame Datenbank."
    L["Got it"] = "Verstanden"
    L["Shared database"] = "Gemeinsame Datenbank"
    L["Shared catch database is off"] = "Die gemeinsame Fangdatenbank ist aus"
    L["Waiting for you to read the notice"] = "Wartet, bis du den Hinweis gelesen hast"
    L["Exchange unavailable: the game refuses addon messages"] =
        "Austausch nicht möglich: Das Spiel lehnt Addon-Nachrichten ab"
    L["Exchange paused: in combat"] = "Austausch pausiert: im Kampf"
    L["Exchange paused: in an instance"] = "Austausch pausiert: in einer Instanz"
    L["Exchange paused: loading screen"] = "Austausch pausiert: Ladebildschirm"
    L["Exchange paused: the game restricts addon messages here"] =
        "Austausch pausiert: Das Spiel schränkt Addon-Nachrichten hier ein"
    L["Exchange paused: the game asked to slow down"] = "Austausch pausiert: Das Spiel verlangt eine Pause"
    L["Nobody to exchange with right now"] = "Gerade niemand zum Austauschen da"
    L["Exchange: %d players, %s ago"] = "Austausch: %d Spieler, vor %s"
    L["Exchange: 1 player, %s ago"] = "Austausch: 1 Spieler, vor %s"
    L["Exchange: waiting for the first exchange"] = "Austausch: wartet auf den ersten Austausch"
    L["Bundled data: version %d, %d places"] = "Mitgelieferte Daten: Version %d, %d Orte"
    L["Records held: %d, %d places"] = "Gespeicherte Beiträge: %d, %d Orte"
    L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d"] =
        "Spieler in der letzten Stunde: Gilde %d, Gruppe %d, Freunde %d, Battle.net %d"
    L["Players exchanged with in the last hour: %d"] = "Spieler mit Austausch in der letzten Stunde: %d"
    L["Last exchange: %s ago"] = "Letzter Austausch: vor %s"
    L["Last exchange: none yet"] = "Letzter Austausch: noch keiner"
    L["Traffic in the last hour: %d KB"] = "Datenverkehr in der letzten Stunde: %d KB"

    -- UI/Settings.lua: the Shared database page
    L["Use the shared catch database"] = "Gemeinsame Fangdatenbank verwenden"
    L["Your catches (items, counts, map cells, the average spot you fish from) are shared under a random ID."] =
        "Deine Fänge (Gegenstände, Anzahlen, Kartenfelder, der durchschnittliche Punkt, von dem aus du angelst) " ..
        "werden unter einer zufälligen ID geteilt."
    L["They go to addon users in your guild, group and friends list. No names or gear."] =
        "Sie gehen an Addon-Nutzer in deiner Gilde, Gruppe und Freundesliste. Keine Namen, keine Ausrüstung."
    L["The players you exchange with can tell which ID is yours."] =
        "Die Spieler, mit denen du Daten austauschst, können erkennen, welche ID deine ist."
    L["Turned off: nothing is sent or received, and other players' data is not counted."] =
        "Aus: Es wird nichts gesendet oder empfangen, und Daten anderer Spieler werden nicht gezählt."

    -- UI/CatchHere.lua: other players' catches
    L["%d catches from %d players"] = "%d Fänge von %d Spielern"

    -- UI/CatchHere.lua: items the game client does not know yet (part 3)
    L["Unknown item"] = "Unbekannter Gegenstand"
    L["The game has not shown this item yet."] = "Das Spiel hat diesen Gegenstand noch nicht gezeigt."
    L["Reported by %d players on this map"] = "Von %d Spielern auf dieser Karte gemeldet"
    L["In the bundled data"] = "In den mitgelieferten Daten"
    L["Item ID: %d"] = "Gegenstands-ID: %d"

    -- Channel.lua: the hidden public channel (part 3)
    L["OneKeyFishing left its hidden channel to free a chat channel slot. Try joining again."] =
        "OneKeyFishing hat seinen versteckten Kanal verlassen, um einen Chatkanal-Platz freizugeben. "
        .. "Versuche es noch einmal."

    -- UI/Settings.lua: the public channel (part 3)
    L["Use the public channel"] = "Öffentlichen Kanal verwenden"
    L["With the public channel on, they also go to every other addon user, through a hidden chat channel."] =
        "Mit eingeschaltetem öffentlichem Kanal gehen sie über einen versteckten Chatkanal auch an alle anderen " ..
        "Addon-Nutzer."
    L["Anyone who joins that channel by its name can see which characters in it use the addon."] =
        "Wer diesem Kanal über seinen Namen beitritt, kann sehen, welche Charaktere darin das Addon nutzen."

    -- Share.lua: the public channel (part 3)
    L["OneKeyFishing now shares your catches under a random ID with other players who use it."] =
        "OneKeyFishing teilt deine Fänge jetzt unter einer zufälligen ID mit anderen Spielern, die es nutzen."
    L["It reaches your guild, group and friends, and anyone else through a hidden chat channel."] =
        "Das erreicht deine Gilde, Gruppe und Freunde und über einen versteckten Chatkanal auch alle anderen."
    L["Public channel: in use"] = "Öffentlicher Kanal: in Verwendung"
    L["Public channel: in use (fallback channel %d)"] = "Öffentlicher Kanal: in Verwendung (Ersatzkanal %d)"
    L["Public channel: off"] = "Öffentlicher Kanal: aus"
    L["Public channel: no free chat channel slot"] = "Öffentlicher Kanal: kein freier Chatkanal-Platz"
    L["Public channel: locked or refused by the game"] = "Öffentlicher Kanal: gesperrt oder vom Spiel abgelehnt"
    L["Public channel: you left it, back at the next login"] =
        "Öffentlicher Kanal: von dir verlassen, ab der nächsten Anmeldung wieder da"
    L["Public channel: waiting"] = "Öffentlicher Kanal: wartet"
    L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d, channel %d"] =
        "Spieler in der letzten Stunde: Gilde %d, Gruppe %d, Freunde %d, Battle.net %d, Kanal %d"

    -- Catalog.lua: the catch catalog (part 4)
    L["Unknown zone (%d)"] = "Unbekannte Zone (%d)"

    -- Catalog.lua: spots
    L["%s (%s)"] = "%s (%s)"
    L["No exact spot"] = "Keine genaue Stelle"

    -- UI/CatalogTab.lua, UI/StatsFrame.lua, UI/CatchHere.lua: the catch catalog (part 4)
    L["Catch catalog"] = "Fangkatalog"
    L["Search by item name"] = "Nach Gegenstandsnamen suchen"
    L["Zones: %d"] = "Zonen: %d"
    L["Back"] = "Zurück"
    L["Place"] = "Ort"
    L["Skill"] = "Fertigkeit"
    L["Counting the catch..."] = "Fänge werden gezählt..."
    L["Nothing has been caught yet."] = "Noch nichts gefangen."
    L["The catalog fills with your catches, the bundled data and, with sharing on, other players' catches."] =
        "Der Katalog füllt sich mit deinen Fängen, den mitgelieferten Daten und, mit aktivem Teilen, den Fängen "
        .. "anderer Spieler."
    L["You have not caught anything yet."] = "Du hast noch nichts gefangen."
    L["No item matches the search."] = "Kein Gegenstand passt zur Suche."
    L["No data for this item under these filters."] = "Keine Daten zu diesem Gegenstand mit diesen Filtern."
    L["Click an item to see where else it is caught."] =
        "Klicke auf einen Gegenstand, um zu sehen, wo er sonst gefangen wird."

    -- UI/CatalogTab.lua: the map pin (part 4)
    L["Set a map pin here"] = "Hier einen Kartenpin setzen"

    -- Catalog.lua, UI/ItemHooks.lua, UI/Minimap.lua, UI/Settings.lua: catch chances in tooltips (part 4)
    L["%s (%d players)"] = "%s (%d Spieler)"
    L["Caught in:"] = "Gefangen in:"
    L["Likely catch here:"] = "Wahrscheinlicher Fang hier:"
    L["Show catch chances in tooltips"] = "Fangchancen in Tooltips anzeigen"

    -- UI/CatchHere.lua, UI/CatalogTab.lua: the Water filter (part 4)
    L["Water: %s"] = "Gewässer: %s"
    L["Everywhere"] = "Überall"
    L["Open water"] = "Offenes Wasser"
    L["Pools"] = "Schwärme"
    -- Fishing/Sound.lua, UI/Settings.lua, UI/Minimap.lua: the fishing sounds (spec 013)
    L["Sound effects"] = "Soundeffekte"
    L["Play fishing sounds"] = "Angelgeräusche abspielen"
    L["A bell rings when you cast, and a sound plays when you hook."] =
        "Eine Glocke läutet beim Auswerfen, und ein Ton erklingt beim Anhieb."
    L["A notification follows when the loot holds an Uncommon or better item."] =
        "Eine Benachrichtigung folgt, wenn die Beute einen seltenen oder besseren Gegenstand enthält."
    L["Only while fishing mode is on; silent in a fight."] = "Nur im Angelmodus; im Kampf still."
    L["Turn fishing sounds on"] = "Angelgeräusche einschalten"
    L["Turn fishing sounds off"] = "Angelgeräusche ausschalten"
    -- UI/Settings.lua: the volume of the fishing sounds (spec 013)
    L["Volume"] = "Lautstärke"
    L["%d%%"] = "%d%%"
    -- UI/Settings.lua: game sound in the background while fishing (spec 013)
    L["Fishing sound in the background"] = "Angelgeräusche im Hintergrund"
    L["All game sound keeps playing while the game window is in the background."] =
        "Der gesamte Spielsound läuft weiter, während das Spielfenster im Hintergrund ist."
    L["Only while fishing mode is on; your own game setting comes back when the mode ends."] =
        "Nur im Angelmodus; deine eigene Spieleinstellung kehrt zurück, wenn der Modus endet."
    -- UI/Settings.lua: the splash focus (spec 013)
    L["Splash focus while fishing"] = "Platschen beim Angeln hervorheben"
    L["Music, ambience and dialog are silenced and sound effects raised, so the bobber's splash stands out."] =
        "Musik, Umgebung und Dialoge verstummen und die Soundeffekte werden lauter, damit das Platschen des " ..
        "Schwimmers hervorsticht."
    L["Lifted in a fight; everything comes back when fishing mode ends."] =
        "Im Kampf aufgehoben; alles kehrt zurück, wenn der Angelmodus endet."
    -- Item kinds (spec 014)
    L["Fish"] = "Fisch"
    L["Containers"] = "Behälter"
    L["Potions & drinks"] = "Tränke & Getränke"
    L["Reagents & herbs"] = "Reagenzien & Kräuter"
    L["Other"] = "Sonstiges"
    L["Trophies"] = "Trophäen"
    L["Quest"] = "Questgegenstände"
    L["%s (%d/%d)"] = "%s (%d/%d)"
    L["New trophy: %s (%d/%d)"] = "Neue Trophäe: %s (%d/%d)"
    L["Best places"] = "Beste Plätze"
    L["Catalog"] = "Katalog"
    L["Level"] = "Stufe"
    L["No subzone"] = "Ohne Teilgebiet"
    L["Safe for me: %s"] = "Sicher für mich: %s"
    L["On"] = "An"
    L["Off"] = "Aus"
    L["Continent: %s"] = "Kontinent: %s"
    L["Nothing matches the filters."] = "Nichts passt zu den Filtern."
    L["%d%% of the catch here has no price: the gold may be higher."] =
        "%d%% des Fangs hier hat keinen Preis: das Gold kann höher sein."
    L["%s: %s chance, %s each, %d%% of the gold"] = "%s: %s Chance, je %s, %d%% des Goldes"
    L["Kinds: All"] = "Arten: Alle"
    L["Kinds: %d of %d"] = "Arten: %d von %d"
    L["The kind filter hides every item."] = "Der Artenfilter blendet alle Gegenstände aus."
    L["The kind filter hides the matches."] = "Der Artenfilter blendet die Treffer aus."
    L["Sort: %s"] = "Sortierung: %s"
    L["Name"] = "Name"
    L["No price"] = "Kein Preis"

    -- Auctionator as a price source (specs/019-auctionator-prices): Auction.lua, Settings.lua, StatsFrame.lua
    L["Prices come from Auctionator."] = "Die Preise kommen von Auctionator."
    L["Auction prices"] = "Auktionspreise"
    L["Take prices from Auctionator"] = "Preise von Auctionator übernehmen"
    L["Auctionator is not installed."] = "Auctionator ist nicht installiert."
    L["Auctionator failed this session: the addon's own scan is in use."] =
        "Auctionator ist in dieser Sitzung ausgefallen: Der eigene Scan des Addons wird verwendet."
    L["Prices come from the addon's own scan (last scan %s)."] =
        "Die Preise kommen vom eigenen Scan des Addons (letzter Scan %s)."
    L["Prices come from the addon's own scan (no scan yet)."] =
        "Die Preise kommen vom eigenen Scan des Addons (noch kein Scan)."
    L["Auction prices are off: catch values use vendor prices."] =
        "Auktionspreise sind aus: Fangwerte nutzen Händlerpreise."
    L["Your catches: %d priced by Auctionator, %d by the addon's scan, %d at vendor price, %d without a price."] =
        "Deine Fänge: %d mit Auctionator-Preis, %d mit Preis aus dem Addon-Scan, %d nur mit Händlerpreis, %d " ..
        "ohne Preis."
    L["Values: higher of vendor and Auctionator price."] = "Werte: der höhere aus Händler- und Auctionator-Preis."
    L["%d of your catches have no Auctionator price: run its scan."] =
        "%d deiner Fänge haben keinen Auctionator-Preis: Starte dessen Scan."

    -- Camp bonus tag and filter values (specs/020-camp-buffs): Catalog.lua
    L["Fishing Rack bonus"] = "Bonus des Angelgestells"
    L["Fishing Hut bonus"] = "Bonus der Anglerhütte"
    L["Bonus catch: comes only with the buff of a Fishing Rack (Uncommon Fishing)."] =
        "Bonusfang: kommt nur mit dem Stärkungszauber eines Angelgestells (Ungewöhnliches Angeln)."
    L["Bonus catch: comes only with the buff of a Fishing Hut (Rare Fishing)."] =
        "Bonusfang: kommt nur mit dem Stärkungszauber einer Anglerhütte (Seltenes Angeln)."
    L["Bonus catch: comes only with the buff of a Fishing Rack or a Fishing Hut."] =
        "Bonusfang: kommt nur mit dem Stärkungszauber eines Angelgestells oder einer Anglerhütte."
    L["%s with the bonus"] = "%s mit Bonus"
    L["All catches"] = "Alle Fänge"
    L["No camp bonus"] = "Ohne Lagerbonus"
    L["Fishing Rack"] = "Angelgestell"
    L["Fishing Hut"] = "Anglerhütte"

    -- The Camp bonus filter button (specs/020-camp-buffs): CatchHere.lua, CatalogTab.lua
    L["Camp bonus"] = "Lagerbonus"
    L["Show the catches made with a camp bonus: the fishing buff of a Fishing Rack or a Fishing Hut by a campfire."] =
        "Zeigt die Fänge mit einem Lagerbonus: dem Angel-Stärkungszauber eines Angelgestells oder einer " ..
        "Anglerhütte, die an einem Lagerfeuer aufgestellt wurden."
    L["\"No camp bonus\" also holds older catches for which the bonus is not known."] =
        "„Ohne Lagerbonus“ enthält auch ältere Fänge, bei denen der Bonus nicht bekannt ist."

    -- The camp bonus notices and their setting (specs/020-camp-buffs): Camp.lua, Settings.lua
    L["The Fishing Rack bonus ends in 5 minutes."] = "Der Bonus des Angelgestells endet in 5 Minuten."
    L["The Fishing Rack bonus has ended."] = "Der Bonus des Angelgestells ist abgelaufen."
    L["The Fishing Hut bonus ends in 5 minutes."] = "Der Bonus der Anglerhütte endet in 5 Minuten."
    L["The Fishing Hut bonus has ended."] = "Der Bonus der Anglerhütte ist abgelaufen."
    L["Warn when a camp bonus is ending"] = "Warnen, wenn ein Lagerbonus endet"

    -- The camp bonus rows of the statistics (specs/020-camp-buffs): StatsFrame.lua
    L["Casts with a camp bonus"] = "Würfe mit Lagerbonus"
    L["Bonus catches"] = "Bonusfänge"

    -- The Camp bonus button and Bonus catches only (spec 020 follow-up): Catalog.lua, CatchHere.lua
    L["Bonus catches only"] = "Nur Bonusfänge"
    L["Camp bonus: All"] = "Lagerbonus: Alle"
    L["Camp bonus: No bonus"] = "Lagerbonus: Ohne"
    L["Camp bonus: Bonus only"] = "Lagerbonus: Nur Bonus"
    L["Camp bonus: Rack"] = "Lagerbonus: Gestell"
    L["Camp bonus: Hut"] = "Lagerbonus: Hütte"
    L["No bonus catch has been recorded here yet."] = "Hier wurde noch kein Bonusfang erfasst."
    L["No bonus catch has been recorded yet."] = "Es wurde noch kein Bonusfang erfasst."

    -- Import and export (specs/027-import-export): UI/TransferPage.lua
    L["Import and export"] = "Import und Export"
    L["Import"] = "Importieren"
    L["Import a string"] = "Text importieren"
    L["Export my data"] = "Meine Daten exportieren"
    L["Move catch data between players without both being online: export it, send the text, import it."] =
        "Fangdaten zwischen Spielern austauschen, ohne dass beide online sind: exportieren, Text senden, importieren."
    L["Imported data counts even with the shared database off."] =
        "Importierte Daten zählen auch bei ausgeschalteter geteilter Datenbank."
    L["Data you imported still counts."] = "Importierte Daten zählen trotzdem."
    L["Preparing..."] = "Wird vorbereitet..."
    L["Nothing to export yet: catch some fish first."] = "Noch nichts zu exportieren: fang zuerst ein paar Fische."
    L["Your own data is still being prepared: choose Export my data again in a minute."] =
        "Deine eigenen Daten werden noch vorbereitet: wähle in einer Minute erneut Meine Daten exportieren."
    L["%d records, %d KB. Press Ctrl+C to copy, then paste it where the other player can read it."] =
        "%d Einträge, %d KB. Mit Strg+C kopieren und dort einfügen, wo der andere Spieler es lesen kann."
    L["It holds anonymous IDs and catch counts per place, no names."] =
        "Enthalten sind anonyme IDs und Fangzahlen pro Ort, keine Namen."
    L["Importing: %d of %d records checked..."] = "Import: %d von %d Einträgen geprüft..."
    L["Paste a string with Ctrl+V, then press Import."] =
        "Füge einen Text mit Strg+V ein und klicke dann auf Importieren."
    L["Pasted %d KB. Press Import."] = "%d KB eingefügt. Klicke auf Importieren."
    L["No catch data found in the text."] = "Im Text wurden keine Fangdaten gefunden."
    L["The text is incomplete: copy the whole string again."] =
        "Der Text ist unvollständig: kopiere den ganzen Text noch einmal."
    L["This string comes from a newer version of the addon: update OneKeyFishing."] =
        "Dieser Text stammt aus einer neueren Version des Addons: aktualisiere OneKeyFishing."
    L["The text is damaged: copy the whole string again."] =
        "Der Text ist beschädigt: kopiere den ganzen Text noch einmal."
    L["Imported: %d new, %d already known, %d your own, %d refused."] =
        "Importiert: %d neu, %d schon bekannt, %d eigene, %d abgelehnt."
end)
