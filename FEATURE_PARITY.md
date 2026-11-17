# Vibrant+ — Spezifikation und Feature-Parität

## Vollständiger Abgleich mit vorssaint-utils

Ziel: alle Funktionen der [Referenz](https://github.com/vorssaint/vorssaint-utils) eigenständig nachbauen, vorhandene Vibrant+-Funktionen erhalten und verbessern. Alle Erweiterungen müssen zuschaltbar sein. Die Insel-Navigation oberhalb der Kacheln ist ebenfalls konfigurierbar. Design und Lizenzstatus von Vibrant+ bleiben erhalten; keine GPL-Code-/Assetübernahme. Ausschliesslich öffentliche APIs; technische Ausnahmen werden konkret ausgewiesen.

Referenzstand: `89d2626089d693bf0462ba29ea5d047d80c9da2e`. Die folgende Liste enthält sämtliche **80 Feature-Katalogeinträge** der Referenz. «Teilweise» bedeutet ausdrücklich keine vollständige Funktionsgleichheit; jede Funktion benötigt zusätzlich den Detailabgleich der Optionen und ihrer Laufzeitpfade.

| Referenz-ID | Stand | Abdeckung / offene Arbeit |
|---|---|---|
| `switcher` | In Prüfung | App- und Fensterwechsler mit Suche, Bildschirmfilter, optionalen ScreenCaptureKit-Bildern, Anordnen und Kurzbefehl; Laufzeitprüfung ausstehend. |
| `dockPreview` | Technisch teilweise eingeschränkt | Hover-Vorschau über öffentliche AX- und ScreenCaptureKit-Daten. Privates DockAutohideHold/SkyLight und Steuerung fremder Spaces bleiben aus. |
| `dockClick` | In Prüfung | Klick auf die bereits aktive Dock-App: minimieren, ausblenden oder Fenster wechseln; Laufzeitprüfung ausstehend. |
| `windowMaximizer` | In Prüfung | Grüner Knopf füllt die nutzbare Fläche ohne neues Space; erneuter Klick stellt die Grösse wieder her. |
| `windowLayout` | In Prüfung | Rowline, Snap-Kurzbefehle, gespeicherte Anordnungen, Rand-Snap, ⌥-Ziehen, Drittel, nächster Bildschirm und Wiederherstellung. Trackpad-Gesten der Referenz brauchen private Multitouch-APIs und bleiben aus. |
| `autoQuit` | In Prüfung | Ausgewählte Apps nach letztem Fenster, normales Beenden implementiert; Laufzeitprüfung ausstehend. |
| `spacesOrder` | In Prüfung | Öffentliche Dock-Voreinstellung `mru-spaces` wird gesichert und zurückgesetzt; keine private Space-Verwaltung. |
| `scrollInverter` | In Prüfung | Vertikal/horizontal getrennt für Mausräder implementiert; Laufzeitprüfung ausstehend. |
| `scrollHorizontal` | In Prüfung | ⇧-Scroll-Umsetzung implementiert; Laufzeitprüfung ausstehend. |
| `scrollZoom` | In Prüfung | ⌘ und Mausrad sendet öffentliches ⌘+/⌘−; Trackpad bleibt unverändert. |
| `focusFollowsMouse` | In Prüfung | Fenster unter dem Zeiger nach Hover-Pause nach vorne; Ausnahmen und Verzögerung in den Fensterwerkzeugen. |
| `smoothScroll` | In Prüfung | Mausrad-Pixel werden in 60-Hz-Schritten auslaufen gelassen; Trackpad bleibt unverändert. |
| `linearScroll` | In Prüfung | Gleiche Schrittweite pro Mausrad-Ereignis; Trackpad bleibt unverändert. |
| `scrollSpeed` | In Prüfung | Multiplikator implementiert; Laufzeitprüfung ausstehend. |
| `mouseAcceleration` | In Prüfung | IOHIDSetCFTypeParameter schaltet HIDMouseAcceleration auf −1 und stellt den vorherigen Wert wieder her. |
| `mouseNavigation` | In Prüfung | Seitentasten als Zurück/Vorwärts implementiert; Laufzeitprüfung ausstehend. |
| `mouseButtonShortcuts` | In Prüfung | Zusatztasten 5 und 6 sowie diskretes Maus-Seitenrad (Achse 2) auf Mission Control, App-Fenster, Schreibtisch oder Spaces. Trackpad bleibt unverändert. |
| `middleClick` | Technische Ausnahme | Drei-Finger-Mitteltaste braucht private Multitouch-Schnittstellen. |
| `mouseClickDebounce` | In Prüfung | Filter implementiert, standardmässig aus; Laufzeitprüfung ausstehend. |
| `keyboardDebounce` | In Prüfung | Filter implementiert, Tastenwiederholung bleibt; Laufzeitprüfung ausstehend. |
| `textSnippets` | In Prüfung | Kürzel mit «;», Einfügen über Bedienungshilfen, Suche in der Befehlsleiste. |
| `superKey` | In Prüfung | Rechte Ctrl-Taste als ⌃⌥⌘, Antippen als Esc; App-Ausnahmen. |
| `quitWindowProtection` | In Prüfung | Doppeltes ⌘Q/⌘W implementiert, standardmässig aus; Laufzeitprüfung ausstehend. |
| `clipboardHistory` | In Prüfung | Text, Bilder und Dateipfade, Suche, Pins, Autolöschen und optionales ⌘V in die vordere App. |
| `pastePlain` | In Prüfung | Einfügen mit Wiederherstellen der Formate implementiert; Laufzeitprüfung ausstehend. |
| `finderCutPaste` | In Prüfung | Finder-Kurzbefehle implementiert; Laufzeitprüfung ausstehend. |
| `finderRename` | In Prüfung | F2 im Finder implementiert; Laufzeitprüfung ausstehend. |
| `shelf` | In Prüfung | Insel-Ablage plus Drag-Palette am Zeiger (⌃⌥⌘A); Dateien hineinziehen und wieder herausziehen. |
| `urlCleaner` | In Prüfung | Manuelle und automatische Offline-Bereinigung kopierter Weblinks, ohne sie aufzurufen. |
| `diskImageInstaller` | In Prüfung | Schreibgeschütztes Einhängen, Kopieren von App-Bundles, kein pkg/Skript und kein Überschreiben; Laufzeitprüfung ausstehend. |
| `mixer` | In Prüfung | Pro-App-Pegel inkl. Verstärkung bis 200 % über Process-Tap, Favoriten und gemerktes Ausgaberouting; Laufzeitprüfung ausstehend. |
| `soundOutputSwitcher` | In Prüfung | Audiogeräteauswahl implementiert; Prüfung ausstehend. |
| `audioPriority` | In Prüfung | Pro-App-Ausgang über denselben Process-Tap (Aggregat mit gewähltem Gerät); Systemstandard bleibt der Rückfall. |
| `micMute` | In Prüfung | Hardware-Mute und Eingangspegel implementiert, falls Gerät unterstützt; keine allgemeine Privatsperre. Prüfung ausstehend. |
| `musicBlock` | In Prüfung | Music wird nur beendet, wenn sie nach einer Medientaste frisch startet, nicht bei manuellem Öffnen. |
| `keepAwake` | Technisch teilweise eingeschränkt | Manueller Schalter plus Timer, Netzteil-, Bildschirm- und App-Regeln über IOPMAssertion. Geschlossener Deckel ohne öffentliche API. |
| `brightness` | Technisch teilweise eingeschränkt | Referenz nutzt private DisplayServices/CoreDisplay-/CGS-Aufrufe. Öffentliche Software-/Monitorwege separat prüfen; kein pauschales Paritätsversprechen. |
| `extraBrightness` | Technische Ausnahme | XDR-HDR-Headroom der Referenz nutzt private DisplayServices; kein pauschales Paritätsversprechen. |
| `bluetoothSleep` | Technische Ausnahme | Referenz nutzt dynamisch geladene IOBluetoothPreference*-Funktionen. Keine private Bluetooth-Stromsteuerung in Vibrant+. |
| `quickLauncher` | In Prüfung | App-Raster und Schnellpalette mit Favoriten; Palette und Radialmenü öffnen am Zeiger. |
| `quickToggles` | In Prüfung | Steuerungen-Kachel mit Dark Mode, Desktop-Symbolen, versteckten Dateien, Papierkorb, DND-Kurzbefehl und Wachhalten. Bluetooth ohne öffentliche API. |
| `quitApps` | In Prüfung | Kachel mit Beenden, bestätigtem Sofort-Beenden und «Andere» (alle ausser der vorderen App). |
| `colorPicker` | In Prüfung | HEX, RGB, HSL und SwiftUI Color lokal aus sRGB; NSColorSampler. |
| `screenOCR` | In Prüfung | Lokale Vision-Text-/QR-Erkennung implementiert; Prüfung ausstehend. |
| `cleaningMode` | In Prüfung | Tastatursperre 60 s, schwarze Abdeckung, dreimal Esc; Laufzeitprüfung ausstehend. |
| `mediaTools` | In Prüfung | Stow: JPEG/PNG/HEIC/WebP/PDF/MP4/M4A/GIF, Zuschnitt, Metadaten, Verkleinern, Upscaling, PDF teilen. Keine Cloud-Formate. |
| `cleaner` | In Prüfung | Nur eigene Library-Caches/Logs, Auswahl in den Papierkorb, keine Systemordner; Laufzeitprüfung ausstehend. |
| `uninstaller` | In Prüfung | App plus exakt zur Bundle-ID passende Reste, Auswahl in den Papierkorb; keine Vendor-Suche. |
| `homebrew` | In Prüfung | Suchen, Info, Installieren, Entfernen über festen brew-Pfad, ohne Shell und ohne sudo. |
| `appUpdates` | In Prüfung | Homebrew-Updates, App-Store-Link und Vibrant+-Selbstupdate über GitHub Releases (`ArijanVr/VibrantPlus`; optional `PROJEKTELAB_RELEASES`), ohne Sparkle, Prüfung aus bis eingeschaltet. |
| `screenshot` | In Prüfung | Screen/Window/Area, Preview-Markup, Schwärzen, Wasserzeichen, Rand und scrollendes Fenster (max. 8 Streifen). Teilen-Links brauchen einen Server und bleiben aus. |
| `cameraPreview` | In Prüfung | Insel-Spiegel und schwebendes Fenster; Kamera nur solange eine der beiden Oberflächen offen ist. |
| `radialMenu` | In Prüfung | Radialmenü der ersten acht Favoriten am Zeiger; Profile und Untermenüs der Referenz offen. |
| `scratchpad` | In Prüfung | Mehrere lokale Notizen, Markdown-Vorschau/Export implementiert; Prüfung ausstehend. |
| `commandBar` | In Prüfung | Suche nach Apps, Dateien, Fenstern, Menüs, Zwischenablage, Textbausteinen, Rechnen und Einheiten; Kurzbefehl ⌃⌥⌘K. |
| `screenRecorder` | In Prüfung | Bildschirmaufnahme, optionaler Zoom um den Zeiger, Mehrspur-MOV und GIF. Bildeditor für Standbilder. Teilen-Links ohne Server aus. |
| `wallpaper` | In Prüfung | Nacht-/Papier-Bilder, optional mit macOS-Dunkelmodus; «Jetzt legen» setzt das Bild über NSWorkspace auf alle Schreibtische. |
| `killProcess` | In Prüfung | App-Beenden und ausdrücklich bestätigtes Force Quit implementiert; Prüfung ausstehend. |
| `portManager` | In Prüfung | Portliste und bestätigtes SIGTERM mit erneuter Portprüfung implementiert; Prüfung ausstehend. |
| `notch` | In Prüfung | Insel mit konfigurierbarer Navigation (Reihenfolge, Namen, Sichtbarkeit, Platzierung). |
| `notchCalendar` | In Prüfung | EventKit-Termine, Countdown und Kalenderauswahl; leere Auswahl bedeutet alle Kalender. |
| `notchNotifications` | Technisch teilweise eingeschränkt | Eigene Insel-Hinweise können gemerkt werden. Fremde Systemmitteilungen ohne öffentliche API. |
| `notchGestures` | In Prüfung | Zwei Finger seitwärts wechselt die Seite, nach unten schliesst die Insel. Nur Gesten mit Phase, keine Mausräder. |
| `notchTimer` | In Prüfung | Insel-Timer und Today-Fokus mit ±5 Min. und Fortschritt. |
| `notchAccessories` | In Prüfung | Datum und Einstellungen in der Notch-Leiste, analoge Uhr optional. |
| `notchLyrics` | In Prüfung | Synchronisierte Liedtexte über LRCLIB, lokal zwischengespeichert, standardmässig aus. |
| `notchQueue` | Technisch teilweise eingeschränkt | Nächste Titel der aktuellen Music-Playlist per AppleScript. Spotify hat keine öffentliche Queue-API. |
| `notchLiveEqualizer` | Technisch teilweise eingeschränkt | Dekorativer Equalizer aus der Wiedergabe. Echter Mix-FFT ohne öffentlichen System-Tap. |
| `notchDownloads` | In Prüfung | Eigener Link-Downloader (yt-dlp-Pfad, Formate, Ordner). Keine fremden Konten-APIs. |
| `notchAgents` | Technisch teilweise eingeschränkt | Claude-Hooks, lokale Claude/Codex/OpenCode-Auswertung. Copilot-Konten und Hersteller-Limits ohne öffentliche lokale API. |
| `notchWatch` | In Prüfung | Optionales analoges Zifferblatt in der Uhr-Kachel, lokal aus der Systemzeit. |
| `notchMascot` | In Prüfung | Pulsi mit eigenem Reiter, drei eigenen Stimmrufen, optionaler Siri-Stimme und «Hey Pulsi»-Weckruf (Beta, on-device). |
| `monitorCPU` | In Prüfung | CPU-Verlauf, Wärmezustand von macOS (normal bis kritisch), Lastwarnung und Prozessliste. Sensor-Gradzahlen ohne öffentliche API. |
| `monitorGPU` | Technische Ausnahme | Keine öffentliche GPU-Auslastungs- oder Temperaturschnittstelle; Werte werden nicht erfunden. |
| `monitorMemory` | In Prüfung | RAM-Wert, Kompressor-Anteil, Warnung und die acht speicherstärksten Prozesse. |
| `monitorNetwork` | Technisch teilweise eingeschränkt | Live-Raten, Sitzungssummen und lokale IPs. Kein Speedtest gegen fremde Server. |
| `monitorDisk` | In Prüfung | Freier Platz, Warnung und Live-Lesen/Schreiben über IOBlockStorageDriver-Statistiken. |
| `monitorPower` | In Prüfung | Akku, Stromquelle, Restlaufzeit, Warnung, Ladezyklen und Kapazität gegen Auslegung soweit IOPS sie liefert. |
| `connectedDevices` | In Prüfung | Bildschirme, entfernbare Datenträger und USB-Produktnamen; keine privaten Bluetooth-Daten. |
| `fanControl` | Technische Ausnahme | Referenz schreibt SMC-Schlüssel über privilegierten Helper. Keine undokumentierten SMC-Schreibzugriffe. |

### Bedienungsgrundlage

Funktionskatalog mit Suche und Profilen sowie fortsetzbare Einrichtung sind vorhanden. Die Insel-Navigation bietet Reihenfolge, eigene Namen, Sichtbarkeit und Platzierung; neben dem Notch bleiben alle sichtbaren Seiten einzelne Symbole ohne Extra-Klick, auch bei vollem Umfang. Datum/Einstellungszugang sind separat schaltbar. Ausblenden stoppt keine Dienste. Mindestens eine verfügbare Seite bleibt erreichbar.

## Bisherige Referenz

Nummern verweisen auf `docs/reference-analysis/feature-matrix.md`. Umfang: **CORE** (ohne geht der Zweck verloren), **PARITY** (weitere belegte Funktionen), **ENH** (Verbesserung), **AUS** (bewusst nicht umgesetzt, mit Grund).

Die Spalte **Stand** wird während der Entwicklung nachgeführt: ✅ umgesetzt und getestet · 🟡 umgesetzt, nur teilweise getestet · ⬜ offen · ⛔ nicht umgesetzt.

| # | Bereich | Referenzverhalten | Vibrant+-Umsetzung | Prio | Testkriterium | Stand |
|---|---|---|---|---|---|---|
| 1 | Grundlage | Menüleisten-App | `LSUIElement`, `MenuBarExtra` mit Menü: Insel, Today, Agent-Panel, Rowline, Einstellungen, Beenden | CORE | App startet ohne Dock-Symbol, Menü erscheint | 🟡 |
| 2 | Grundlage | Module an/aus, Onboarding | Willkommensfenster beim ersten Start + Einstellungsseite «Module»; aus = kein Dienst, keine Rechteanfrage | CORE | Modul aus → Dienst gestoppt (Selbsttest) | 🟡 |
| 3 | Grundlage | Rechte bei Bedarf | Seite «Berechtigungen» mit Status + «Erlauben»/«Systemeinstellungen öffnen» | CORE | Status korrekt angezeigt | 🟡 |
| 4 | Insel | Insel aus dem Notch | Randloses `NSPanel` oben mittig; Notch-Erkennung über `safeAreaInsets`; ohne Notch mittig unter der Menüleiste | CORE | Hover öffnet, Panel sitzt am Notch | ✅ |
| 5 | Insel | Klick ausserhalb klappt zu | globaler Maus-Monitor + Mausverlassen | CORE | Klick ausserhalb → zu | 🟡 |
| 6 | Insel | Musik | Apple Music + Spotify via AppleScript: Titel, Interpret, Cover, Play/Pause, Vor/Zurück, Fortschritt; Akzent aus Coverfarbe | CORE | Wiedergabe steuerbar | 🟡 |
| 6b | Insel | Synchronisierte Lyrics | Nicht umgesetzt (offen, Version 1.1) | PARITY | – | ⛔ |
| 7 | Insel | YouTube im Browser | — | AUS | Benötigt «JavaScript aus Apple Events» im Browser, fragil | ⛔ |
| 8 | Insel | Nächstes Meeting | EventKit (Lesen), Countdown ab 5 Min. im Notch, «Beitreten» für Zoom/Meet/Teams/Webex-Links | CORE | Link-Erkennung (Unit-Test), Event erscheint | 🟡 |
| 9 | Insel | Kacheln | Wetter (Open-Meteo, nur Stadtname), Uhr+Monat, Systemwerte (CPU/RAM/Disk/Akku), Zwischenablage-Verlauf, Ablage (Shelf), letzte Apps, Timer, Sperren/Ruhezustand, Steuerungen; ein/aus + Reihenfolge | CORE | Jede Kachel zeigt echte Daten | 🟡 |
| 10 | Insel | Warnhinweise | Speicherdruck, freier Platz < Grenze, Akku < 10 %, thermischer Zustand | PARITY | Hinweis-Logik (Unit-Test) | ✅ |
| 11 | Insel | Steuerungen | Dark Mode (System Events), Desktop-Symbole, versteckte Dateien, Papierkorb leeren (mit Bestätigung), Nicht stören (Kurzbefehl «Vibrant DND»), Wachhalten (IOPMAssertion, ENH) | PARITY | Schalter wirkt | 🟡 |
| 11b | Insel | Bluetooth-Schalter | — | AUS | Nur über private/abgekündigte API | ⛔ |
| 12 | Agent | Claude Code live | Eigener Hook (`Vibrant+ --hook`, im App-Binary), Unix-Socket, Sessions mit Schritten; Pille im Notch | CORE | Simulierte Hook-Ereignisse aktualisieren Status | ✅ |
| 13 | Agent | Allow/Deny/Always | Karte in der Insel; Antwort im offiziellen `PermissionRequest`-Format; Zeitlimit → Terminal fragt | CORE | Hook-CLI liefert korrektes JSON | ✅ |
| 14 | Agent | Panel mit Schritten, Dateien, Diffs | Agent-Fenster: Sessions, Schritte, geänderte Dateien, Diff (alt/neu aus Edit/Write) | CORE | Diff sichtbar | 🟡 |
| 15 | Agent | Fragen als Auswahl | `PreToolUse` für `AskUserQuestion`: Auswahl in der Insel, Antwort zurück | PARITY | JSON-Antwort korrekt | 🟡 |
| 16 | Agent | Datei auf Notch → an Claude | Ablage «Für Claude»; Pfade gehen per `UserPromptSubmit.additionalContext` mit | PARITY | Nächster Prompt enthält Pfade | ✅ |
| 17 | Agent | Hooks per Klick | Installieren/Entfernen in `~/.claude/settings.json` mit Sicherung, nur eigene Einträge | CORE | Merge/Entfernen (Unit-Test) | ✅ |
| 18 | Agent | Ton bei Fertig/Frage | Systemton (wählbar) | PARITY | Ton spielt | 🟡 |
| 19 | Agent | Nachricht während Arbeit | — | AUS | Nicht offiziell unterstützt (nur über Stop-Block-Trick) | ⛔ |
| 20 | Agent | Menüleiste Branch/Server/Limit | Git-Branch (liest `.git/HEAD`), laufende Server (`lsof`, nur lesend); Claude-Limit AUS (bräuchte Zugangsdaten) | PARITY | Parser (Unit-Test) | 🟡 |
| 21 | Agent | iPhone-Begleiter | — | AUS | Eigene iOS-App nötig | ⛔ |
| 22 | Mixer | Regler am Rand: Lautstärke, Mixer pro App, Timer | Lasche am linken Rand → Panel: Systemlautstärke + Stumm (CoreAudio), Lautstärke pro App (Core-Audio-Prozess-Taps), Timer | CORE | Lautstärke ändert sich messbar | 🟡 |
| 23 | Mixer | Helligkeit | — | AUS | Nur private API | ⛔ |
| 24 | Mixer | Trackpad-Rand | — | AUS | Nur private API | ⛔ |
| 25 | Today | Aufgaben + Erinnerung | Aufgaben, Glocke (15 Min., 1 Std., 18 Uhr, morgen 9 Uhr), fällig → Notch mit «+10 Min.» und «Erledigt» | CORE | Fälligkeitslogik (Unit-Test) | 🟡 |
| 26 | Today | Fokus-Timer | Start/Pause, ±5 Min., Fortschrittsbalken | CORE | Timer zählt | ✅ |
| 27 | Today | Notiz | gespeichert in JSON | CORE | bleibt nach Neustart | ✅ |
| 28 | Today | Ereignisse heute | EventKit | CORE | Liste | 🟡 |
| 29 | Today | Insights 7 Tage | Swift Charts: erstellt/erledigt/Fokusminuten | PARITY | Aggregation (Unit-Test) | ✅ |
| 30 | Today | Anpassen | Karten ein/aus, Reihenfolge, Fokusdauer | PARITY | Einstellung wirkt | 🟡 |
| 31 | Stow | Ziele + Formate | Für Web (JPEG 2000 px), Zum Senden (JPEG 1600 px / komprimiert), Zum Drucken (PDF), JPEG/PNG/HEIC/TIFF/PDF/MP4/M4A/MOV; WebP nur wenn ImageIO schreiben kann | CORE | Konvertierung erzeugt Datei | ✅ |
| 32 | Stow | Bilder → PDF | PDFKit | CORE | Seitenzahl = Bildzahl | ✅ |
| 33 | Stow | Werkzeuge | Zuschneiden 1:1/4:5/16:9/9:16, unter Grösse, Metadaten entfernen, Video kürzen (Start/Ende), PDF teilen | PARITY | je Werkzeug Test | ✅ |
| 34 | Stow | Nie überschreiben | Eindeutiger Name «… (Vibrant).ext» neben Original | CORE | Unit-Test | ✅ |
| 35 | Stow | Aufräumen + Rückgängig | Schreibtisch/Downloads → Bilder/Filme/Musik/Dokumente, standardmässig aus, Protokoll + Rückgängig | PARITY | Test in /tmp | ✅ |
| 36 | Rowline | Fensterreihe | Bedienungshilfen-API: Reihe (scrollbar per Taste), ½, ⅔, voll, Stapel, Raster; Kurzbefehle ⌃⌥⌘… | CORE | Fensterrahmen-Mathe (Unit-Test), echtes Fenster bewegt | 🟡 |
| 37 | Rowline | Ausnahmen, Abstand | Liste Bundle-IDs, Abstand in pt | PARITY | Einstellung wirkt | 🟡 |
| 38 | Rowline | Layouts speichern | Name, speichern, wiederherstellen, fehlende Apps öffnen | PARITY | Speichern/Laden | 🟡 |
| 39 | Voice | Diktat/Befehl/Einkreisen | ⌃⌥ halten: Diktat (SFSpeechRecognizer) → Text ins aktive Feld; ⌃⌘ Befehle «öffne …» lokal ohne KI; Ollama optional für Bereinigung; Einkreisen AUS | PARITY | Diktat einfügen | 🟡 |
| 40 | App-Grid | Apps im Vollbild | ⌥⌘4 (statt ⌘4, um Tab-Kürzel nicht zu stehlen), Suche, Start | PARITY | Apps gelistet, Start | 🟡 |
| 41 | Themes | Dark/White Matte | «Nacht» / «Papier»: App-Erscheinung, optional macOS Dark Mode und eigenes Hintergrundbild | PARITY | Umschalten wirkt | 🟡 |
| 42 | Tastatur | Tastengeräusche, Tasten anzeigen | Synthetische Klick-Sounds (eigene) via AVAudioEngine; Tastenanzeige-Overlay | PARITY | Ton bei Taste | 🟡 |
| 43 | Terminal | Terminal im Notch | — | AUS | Drittbibliothek (SwiftTerm) nötig; Ersatz: «Im Terminal öffnen» | ⛔ |
| 44 | Starter | Websites neben Dock | — | AUS | Geringer Nutzen, nicht vollständig belegt | ⛔ |
| 45 | Sonstiges | WhatsApp/Versprechen | — | AUS | Liest private Chats, ungeklärt | ⛔ |
| 46 | Sonstiges | Clean bar | — | AUS | Nur mit Hacks möglich | ⛔ |
| 47 | Lizenz | Gumroad | — | AUS | Eigene App, keine Lizenzprüfung | ⛔ |
| 48 | Updates | Sparkle | — | AUS | Keine Fremdabhängigkeit, kein Update-Server | ⛔ |
| E1 | ENH | Wachhalten | IOPMAssertion in Steuerungen | ENH | Assertion aktiv (`pmset -g assertions`) | 🟡 |
| E2 | ENH | Agent-CLI | Verworfen: kein konkreter Nutzen gegenüber dem Panel | ENH | – | ⛔ |

## Zusammenfassung (Stand 08.11.2026)

- ✅ umgesetzt und getestet: 14 · 🟡 umgesetzt, teilweise getestet: 24 · ⛔ nicht umgesetzt: 14 (12 bewusst wegen privater APIs, Fremddiensten oder fehlendem Nutzen; offen: Lyrics; verworfen: Agent-CLI).
- Getestet heisst: Unit-Test (Kit), Selbsttest gegen echte Dateien/Prozesse in /tmp, oder live auf diesem Mac beobachtet. Details in `TEST_REPORT.md`.
- 🟡 bedeutet meist: Code läuft, aber die Prüfung braucht eine Berechtigung (Kalender, Mikrofon, Bedienungshilfen, Systemaudio) oder ein laufendes Programm (Spotify/Musik, eingeloggtes Claude Code), die während der Entwicklung nicht erteilt bzw. nicht verfügbar waren.
- Antwort auf Claude-Fragen (#15): Format `updatedInput.answers` nach bestem Wissen über die öffentliche Hook-API; mit echtem Claude Code noch nicht geprüft.
