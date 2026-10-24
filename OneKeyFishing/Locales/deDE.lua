-- German translation. Keys are the English texts of Locales/enUS.lua.
local _, ns = ...

ns.AddTranslation("deDE", "Deutsch", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "Angelaktion (Auswerfen / Anhieb)"
    L["Toggle fishing mode"] = "Angelmodus umschalten"
    L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."] =
        "Deine gespeicherten Daten stammen aus einer neueren Version von OneKeyFishing. " ..
        "Aktualisiere das Addon, um Probleme zu vermeiden."
    L["v%s commands:"] = "v%s Befehle:"

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
    L["enter or leave fishing mode"] = "Angelmodus aktivieren oder verlassen"

    -- Auction.lua
    L["Scanning %d/%d"] = "Scanne %d/%d"
    L["Scan fish prices"] = "Fischpreise scannen"
    L["Auction scan finished: %d of %d price(s) found."] = "Auktionsscan beendet: %d von %d Preis(en) gefunden."
    L["Open the auction house first."] = "Öffne zuerst das Auktionshaus."
    L["Nothing to scan yet: catch some fish first."] = "Noch nichts zu scannen: Fang zuerst ein paar Fische."
    L["Scanning auction prices of %d item(s)..."] = "Scanne Auktionspreise von %d Gegenstand/Gegenständen..."
    L["Auction scan stopped: %d of %d price(s) found."] = "Auktionsscan abgebrochen: %d von %d Preis(en) gefunden."
    L["scan auction prices of caught items (auction house must be open)"] =
        "Auktionspreise gefangener Gegenstände scannen (Auktionshaus muss geöffnet sein)"

    -- Skill.lua
    L["Apprentice"] = "Lehrling"
    L["Journeyman"] = "Geselle"
    L["Expert"] = "Experte"
    L["Artisan"] = "Fachmann"
    L["a fishing trainer"] = "einen Angellehrer"
    L["the book \"Expert Fishing - The Bass and You\" (Old Man Heming, Booty Bay)"] =
        "das Buch \"Expert Fishing - The Bass and You\" (Der alte Heming, Beutebucht)"
    L["the quest from Nat Pagle (Dustwallow Marsh)"] = "die Quest von Nat Pagle (Düstermarschen)"
    L["Fishing skill capped (%d/%d): learn %s Fishing from %s."] =
        "Angelfertigkeit am Maximum (%d/%d): Lerne Angeln (%s) über %s."
    L["Fishing %d/%d: %d point(s) left in this rank. Next: %s Fishing from %s."] =
        "Angeln %d/%d: noch %d Punkt(e) in diesem Rang. Als Nächstes: Angeln (%s) über %s."

    -- UI/CopyWindow.lua
    L["Click the text, then Ctrl+A and Ctrl+C to copy."] = "Klicke in den Text, dann Strg+A und Strg+C zum Kopieren."

    -- UI/Indicator.lua
    L["Cast"] = "Auswerfen"
    L["Hook!"] = "Anhieb!"
    L["Apply lure"] = "Köder anbringen"
    L["Open"] = "Öffnen"
    L["No bobber"] = "Kein Schwimmer"
    L["Drag to move. Lock it in the settings."] = "Ziehen zum Verschieben. In den Einstellungen fixierbar."

    -- UI/Toast.lua
    L["Caught: %s"] = "Gefangen: %s"
    L["Nothing caught"] = "Nichts gefangen"

    -- UI/StatsFrame.lua
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
    L["No catches yet."] = "Noch keine Fänge."
    L["show the fishing statistics"] = "Angelstatistik anzeigen"
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
    L["Items caught, at the higher of the vendor price and the last scanned auction price."] =
        "Gefangene Gegenstände, bewertet mit dem höheren aus Händlerpreis und zuletzt gescanntem Auktionspreis."
    L["Value per hour of fishing time. Updated with every cast and with Refresh."] =
        "Wert pro Stunde Angelzeit. Wird bei jedem Wurf und mit Aktualisieren erneuert."

    -- Debug.lua
    L["OneKeyFishing - debug report"] = "OneKeyFishing - Debug-Bericht"
    L["show a report to copy into a bug report"] = "einen Bericht zum Kopieren in eine Fehlermeldung anzeigen"

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
    L["Warn when the Fishing rank is capped"] = "Warnen, wenn der Angelrang ausgeschöpft ist"
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
    L["(open the auction house first)"] = "(öffne zuerst das Auktionshaus)"
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
    L["open the settings"] = "Einstellungen öffnen"
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

    -- UI/ItemHooks.lua
    L["OneKeyFishing: fishing gear (Alt+Click to remove)"] = "OneKeyFishing: Angelausrüstung (Alt+Klick zum Entfernen)"
    L["OneKeyFishing: Alt+Click to add to fishing gear"] =
        "OneKeyFishing: Alt+Klick, um zur Angelausrüstung hinzuzufügen"

    -- UI/Minimap.lua
    L["Leave fishing mode"] = "Angelmodus verlassen"
    L["Enter fishing mode"] = "Angelmodus aktivieren"
    L["Statistics"] = "Statistik"
    L["Settings"] = "Einstellungen"
    L["Fishing mode: %s"] = "Angelmodus: %s"
    L["Fishing skill: %d/%d %s"] = "Angelfertigkeit: %d/%d %s"
    L["Session: %d catches, %s"] = "Sitzung: %d Fänge, %s"
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
end)
