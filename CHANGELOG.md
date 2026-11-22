# Changelog

## 1.1.0 — 2026-11-22

Neu gestaltete Insel, neue Kacheln und Funktionen, Codex-Anbindung und ein Hinweis bei neuen Versionen.

**Insel und Bedienung**

- Liquid Glass neu: Rauchglas, neben dem Notch schwarz, jede Kachel als Scheibe mit Lichtkante. In Hell und Dunkel lesbar (alle Textstufen mindestens 4,5 : 1).
- Navigation: links vom Notch die Seiten, rechts der Seitenname; beim Überfahren steht dort der Name des Symbols. Seiten gleiten aus ihrer Richtung herein.
- Seitennamen «Downloads» und «Assistent» statt «Laden» und «Fragen».
- Leuchtumriss in Puls: läuft bei Claude-Start, Frage und Fertig, optional bei ⌘C/⌘V/⌘X/⌘Z, beim Netzteil und beim Öffnen mit der Maus; dauernd, solange die Insel offen ist. Stile Lichtwelle, Komet und Portal, mit Vorschau.
- Szenen: Kachelsätze auf einen Klick, das eigene Layout bleibt gesichert.
- Neue Kacheln: Teleprompter, Befehle, Browser-Tab (mit Wiedergabe/Pause), Nachricht.
- Ablage mit Filter, per AirDrop erhaltene Dateien erscheinen in der Insel, Screenshot-Karte kann hängen bleiben.
- Acht neue Tastenklänge.

**Claude Code und Codex**

- Codex-Anbindung: Freigaben von Codex erscheinen in der Insel (Einstellungen › Claude Code › Codex).
- Fragen mit mehreren Teilen einzeln mit Zurück und Weiter; Antworten auch per Stimme.
- «Dateien automatisch»: erlaubt einem Chat nur Dateien im Projektordner; Befehle, versteckte Dateien und alles ausserhalb fragen weiter.

**Updates**

- Gibt es eine neue Version, öffnet sich die Insel mit «Jetzt aktualisieren», «Später» und «Überspringen». Geprüft wird beim Start und alle sechs Stunden, GitHub höchstens einmal am Tag.

**Fehlerbehebungen**

- Die geschlossene Insel mit Hinweis wurde so breit wie ihr Fenster und lag über der Menüleiste.
- «Aufnehmen» in der Farbpipette war abgeschnitten.
- Wischen über einer Liste konnte die Insel schliessen; eine wartende Anfrage schliesst sie nie mehr.
- Mit der Navigation über den Kacheln verrutschte die Lücke für den Notch, und ⌘1 bis ⌘9 fehlten.
- Tastenklänge liefen bei ausgeschaltetem Tastatur-Modul.

## 1.0.2 — 2026-11-18

Selbstupdate: Nach dem Aktualisieren startet immer die neu installierte Kopie in `/Applications`. Vorher öffnete der Neustart den Pfad der laufenden App; lief sie aus einem anderen Ordner (Downloads, Build-Ordner), kam die alte Version zurück.

## 1.0.1 — 2026-11-18

Stabilitäts-Release: Ursachen für «Vibrant+ schliesst sich von alleine» und «reagiert manchmal nicht» behoben.

- Bauen: Die laufende App wird beendet und abgewartet, bevor `/Applications/Vibrant+.app` ersetzt wird. Vorher starb die alte Kopie beim nächsten Nachladen einer Code-Seite (`SIGBUS`).
- Bauen: Die Signatur wird nach dem Installieren geprüft (inklusive Team-ID der verschachtelten Dylibs). Ein fehlgeschlagenes Signieren bricht ab, statt eine App zu installieren, die nicht startet – davon waren die Debug-Builds betroffen.
- Selbstupdate: Das alte Bundle wird zur Seite gelegt und erst nach dem Beenden gelöscht, statt die laufende App zu überschreiben.
- Nur eine Kopie gleichzeitig: Ein zweiter Start aktiviert die laufende App und beendet sich.
- Kurzbefehle: Belegte Kombinationen werden in den Einstellungen angezeigt und protokolliert; die Aufnahme endet beim Wechsel in eine andere App.
- Systemmonitor: Prozessliste, Kompressor-Anteil und freier Speicher werden ausserhalb des Hauptthreads gelesen; die Prozessliste nur noch alle acht Sekunden.
- Alle wiederkehrenden Timer laufen auch bei offenem Menü, laufendem Dialog oder beim Ziehen eines Fensters weiter.

## 1.0.0 — 2026-11-17 (VibrantPL)

- Frischer öffentlicher Start im Repo [ArijanVr/VibrantPL](https://github.com/ArijanVr/VibrantPL).
- Auto-Update-Feed zeigt auf dieses Repo.
- Inhalt: Open-Source-Stand (GPL-3.0-or-later).

## 1.1.0 — 2026-11-17 (früherer Stand, in diesem Repo nie veröffentlicht)

- Versionsnummer für Updates von 1.0.x (Auto-Update erkennt 1.1.0).
- Inhaltlich der Open-Source-Stand von 0.1.0 (GPL-3.0-or-later).

## 0.1.0 — 2026-11-17

- Erste **Open-Source-Version** unter GPL-3.0-or-later.
- Ersetzt die bisherigen internen Versionen 1.0.x und 3.x.
- **Neuinstallation nötig**, kein automatisches Update von 1.0.x (kleinere Versionsnummer).
- Selbstupdate über GitHub Releases (optional, standardmässig aus).
- Pulsi mit Stimme und Hey Pulsi (Beta).
- Katalog- und Stabilitätsarbeiten auf dem Audit-Zweig.

## In Arbeit — 17.11.2026 (vor 0.1.0)

- Funktionen: durchsuchbarer Modulkatalog mit Profilen Alltag, Produktiv, Entwicklung und Alle Werkzeuge; Profilwechsel rückgängig machen, pro Modul direkt zu den Einstellungen.
- Ersteinrichtung in vier fortsetzbaren Schritten: Orientierung, Auswahl, passende optionale Berechtigungen, Abschluss mit bewusst gewähltem Autostart. Keine Module vor Abschluss; bestehende Auswahlen bleiben beim Update bestehen.
- Menü und Einstellungen: aktive Werkzeuge direkt erreichen, Einstellungsseiten suchen, ausgeschaltete Module über den Katalog wiederfinden. Eigene Seiten für App-Raster und Entwicklerleiste.
- Zwischenablage: eigenständiges Modul samt globalem Kurzbefehl, zusätzlich zur bisherigen Insel-Kachel. Gemeinsamer Dienst stoppt erst, wenn beide Zugänge aus sind.
- Links bereinigen: lokale Vorschau und Kopieren ohne bekannte Tracking-Parameter; keine Netzabfrage, signierte Links bleiben unverändert.
- Berechtigungen: Tastatur, Textbausteine und Stimme warten ohne automatische Abfrage auf eine Freigabe und verbinden sich nach Rückkehr aus den Systemeinstellungen. Erinnerungen auch in der Berechtigungsübersicht.
- Prüfungen: Einrichtungs-/Katalog-Selbsttests und sechs Linkbereinigungs-Tests; isolierte Voreinstellungen für Testdaten unter APP_DATA.
- Farben, Wortmarke, Insel, Kachelanordnung, Typografie und Design-Tokens bleiben erhalten. Funktionskonzepte eigenständig nach vorssaint-utils umgesetzt; kein fremder Code und keine fremden Assets übernommen.

## 1.0.2 — 17.11.2026

- Neu: **Tastaturklänge.** Neue Profile «Thock», «Blauer Schalter» und «Blubb» (selbst erzeugt), «Echte Aufnahme (Cherry)» mit 32 CC0-Aufnahmen und «Klick (Kenney)» sowie «Tick (Kenney)» mit CC0-Klicks. Leertaste, Return und Löschen klingen tiefer. Quellen und Lizenzen: `Resources/KeySounds/LICENSE.txt`.
- Geändert: Im Bereich Tastatur steht die Bedienungshilfen-Berechtigung sichtbar. Der Tastenmonitor startet erst nach der Erlaubnis, und die Abfrage kommt nur einmal pro Start.

## 1.0.1 — 17.11.2026

- Behoben: Die Insel öffnete sich, wenn man Browser-Tabs in die Nähe des Notchs zog. Sie reagiert nur noch auf Datei-Drags, die gerade neu begonnen wurden, nicht auf Web-Adressen oder alte Inhalte der Ziehablage.

## 1.0.0 — 16.11.2026

Die erste definitive Version. Die Nummern 3.x davor waren Vorabstände; ab hier zählt Vibrant+ neu.

- Neu: **Maskottchen Pulsi.** Er taucht unter dem Notch auf, wenn die Maus dort ruht, und hängt an der offenen Insel. Anklicken (Herzen, Hüpfen, Wackeln), mit der Maus verschieben, ein- und ausschaltbar.
- Neu: **Pfeiltasten** wechseln die Seiten der offenen Insel.
- Geändert: Die Insel öffnet nur noch ganz oben am Notch (4 pt, Mitte der Kerbe, 200 ms Ruhe) und wächst fließend zur vollen Größe.
- Entfernt: Grok-Anbindung (war nur in 3.8.x vorhanden).
- Behoben: Mitschreiben und Sprachdienste lieferten im Live-Betrieb keinen Text (fehlende Option «fastResults»).
- Behoben: Absturz beim Start durch Erinnerungen, Tab-Leiste unter dem Notch, Menüleisten-Symbole über der Insel.

## 3.8.2 — 16.11.2026

- Behoben: **Absturz beim Start** (Erinnerungen). macOS meldet die Erinnerungen auf einem Hintergrund-Thread, die App erwartete den Hauptthread und brach ab. Der Fehler bestand seit 3.5.

## 3.8.1 — 16.11.2026

- Behoben: Bei neun Seiten lag der letzte Tab (Fragen) unter dem Notch. Die Tab-Leiste hat eine engere Stufe.

## 3.8 — 16.11.2026

- Neu: **Kacheln anordnen.** Rechtsklick auf eine Kachel: nach links oder rechts, «Breit» (312 pt) oder normale Breite, ausblenden. «Kacheln anordnen» schaltet das Ziehen ein.
- Neu: **Eigene Akzentfarbe** unter Darstellung. Die Insel folgt jeder gewählten Akzentfarbe.
- Neu: **Bildschirmaufnahme** als .mov in Downloads (Steuerungen, Ablage-Seite, Menüleiste).
- Neu: Kachel **Apps beenden** mit «Beenden» und «Sofort» (fragt vor dem erzwungenen Beenden nach).
- Neu: **Mac wach halten** auch im Menüleistenmenü.
- Neu: Claude-Code-Panel zeigt den Abschnitt **Terminal** mit Befehl und Ausgabe.
- Neu: Kachel **Besprechung** schreibt Gespräche (Mikrofon und Mac-Ton, auf dem Mac in Text umgewandelt) als Datei in Dokumente › Vibrant+ Besprechungen mit, optional als Apple-Notizen-Notiz.
- Neu: Kachel **Grok**: Sprachdialog mit Grok (xAI-Schlüssel im Schlüsselbund). «Gib an meinen Bot: …» schickt eine Aufgabe nach Bestätigung per «Senden» an eine eigene Webhook-Adresse.
- Behoben: Menüleisten-Symbole wurden über die offene Insel gezeichnet.

## 3.7 — 16.11.2026

- Entfernt: **Aufräumen.** Vibrant+ verschiebt keine Dateien mehr von selbst aus Schreibtisch und Downloads. Der Menüpunkt unter «Stow» und der Abschnitt «Aufräumen» in den Einstellungen entfallen.
- Geändert: **Screenshots** landen immer im Download-Ordner von Vibrant+ (Standard `~/Downloads`), nicht mehr im Screenshot-Ordner von macOS oder auf dem Schreibtisch.

## 3.6 — 15.11.2026

- Geändert: **Start ist aufgeteilt.** Die Kacheln liegen jetzt auf Seiten nach Kategorie: Start (Musik, Termin, Wetter, Aufgaben, Erinnerungen, Uhr), Mac (Systemwerte, Letzte Apps, Steuerungen, Kurzbefehle, Zwischenablage, Ablage), KI (Claude Code, KI-Verbrauch) und Werkzeuge (Timer, Schnellnotiz, Umrechner, Farbpipette, Spiegel). Eine Seite ohne eingeschaltete Kachel erscheint nicht. Unter Einstellungen › Insel steht neben jeder Kachel ihre Seite.
- Neu: **Wischen von Seite zu Seite.** Innerhalb einer Seite wischst du wie bisher von Kachel zu Kachel; ein weiteres Zweifinger-Wischen am Ende der Reihe wechselt zur Nachbarseite.
- Geändert: ⌘1 bis ⌘9 wählen die Seiten in der Reihenfolge der Tabs.
- Behoben: **OpenCode** erschien nie im KI-Verbrauch (falscher Spaltentrenner in der Abfrage) und zählte alle Zeiten statt der letzten 7 Tage. OpenCode wird auch in `~/.opencode/bin` und als App gefunden.

## 3.5 — 15.11.2026

- Neu: **KI-Verbrauch.** Eine Kachel zeigt als Ring, wie sich die Tokens der letzten 7 Tage auf die Modelle von Claude Code, Codex und OpenCode verteilen, mit der Prozentzahl des führenden Modells in der Mitte. Codex zeigt zusätzlich sein Kontingent. Gelesen werden nur die eigenen Dateien dieser Werkzeuge auf deinem Mac; nichts wird gesendet.
- Neu: **KI-Werkzeuge** in den Agent-Einstellungen zeigt, ob Claude Code, Codex und OpenCode gefunden wurden.
- Neu: **Erinnerungen.** Kachel mit fälligen Erinnerungen, abhaken geht direkt dort. Die Berechtigung steht unter Einstellungen › Berechtigungen. Inhalte der Nachrichten-App sind für Apps nicht zugänglich und lassen sich nicht anbinden.
- Geändert: **Wetter** zeigt das Alter der Messung, lädt alle 10 Minuten neu und beim Öffnen der Insel; die gefühlte Temperatur steht im Tooltip.
- Geändert: **Herunterladen** erkennt Kurzlinks (vm.tiktok.com, vt.tiktok.com, instagr.am). Bei Instagram-Storys, -Reels und -Highlights ohne Anmeldung weist die Fehlermeldung auf die Anmeldung hin.

## 3.4 — 14.11.2026

- Neu: **Brandguide Vibrant+ V1.0.** Die Oberfläche folgt «Grau trägt. Puls zeigt.»: Grau für Flächen und Text, Puls (#D63C7A) als einziger Akzent für Ereignisse, Fokus und Status.
- Geändert: **Insel immer Schwarz**, hell wie dunkel. Der Stil «ARJO Verspielt» mit Pastellkarten ist entfallen; gespeicherte Auswahl fällt auf «Notch-Schwarz» zurück.
- Geändert: **App-Icon** mit der Pulslinie auf Himmel-zu-Pfirsich-Verlauf und Puls-Glow. Das Menüleisten-Symbol ist dieselbe Pulslinie.
- Geändert: **Wortmarke** mit Puls-«+» statt der Plus-Aussparung im Feld.
- Geändert: Radien 6 / 8 / 12 (Chip, Bedienelement, Karte). Akzent «Mehrfarbig» zeigt Puls statt Himmel; Himmel und Pfirsich sind als Akzent entfallen.
- Geändert: Über zeigt «Ein Produkt von ARJO LAB».

## 3.3 — 14.11.2026

- Neu: **Spiegel.** Kachel mit dem Kamerabild, gespiegelt wie ein echter Spiegel. Die Kamera läuft erst nach «Einschalten» und stoppt, sobald die Insel schliesst. macOS fragt beim ersten Mal nach der Kamera.
- Neu: **Schnellnotiz.** Gedanke tippen, ↩ legt ihn ans Ende der Notiz von Heute; «Als Aufgabe» macht eine Aufgabe daraus.
- Neu: **Farbpipette.** Farbe vom Bildschirm aufnehmen, der Hex-Wert landet in der Zwischenablage. Die letzten fünf Farben bleiben als Punkte, ein Klick kopiert sie wieder.
- Neu: **Umrechner.** Ein Feld für Geld, Masse und Zeitzonen: «100 chf in eur», «5 km in mi», «20 c in f», «15:00 zürich in tokio». Ein Klick auf das Ergebnis kopiert es. Wechselkurse der Europäischen Zentralbank über frankfurter.dev, nur wenn du eine Währung tippst und höchstens alle zwölf Stunden; der Abruf enthält keinen Betrag.
- Neu: **Wetter-Vorschau.** Die Wetter-Kachel zeigt die Temperatur der nächsten zwölf Stunden als Kurve.
- Neu: **Video-Qualität** unter Einstellungen › Herunterladen: Beste in H.264 (meist bis 1080p), 4K, 720p oder klein (480p).
- Neu: **Diktat-Pegel.** Solange Vibrant+ zuhört, zeigen fünf Balken neben dem Notch die Lautstärke deiner Stimme.
- Die vier neuen Kacheln sind einmalig eingeschaltet; ausschalten und sortieren unter Einstellungen › Insel.
- Neu: **Fortschritt neben dem Notch.** Läuft ein Download, zeigt die geschlossene Insel einen Ring mit Prozent, bis er fertig ist; ohne bekannte Grösse «lädt». Wandelt Stow um, steht dort «wandelt um». Die Insel muss dafür nicht geöffnet werden.
- Geladene Videos spielen in QuickTime Player. Instagram liefert oft VP9, auch in einer MP4-Datei, und QuickTime öffnet das nicht. Vibrant+ wählt jetzt nur noch Formate, die sich als H.264 ausweisen, und wandelt alles andere (VP9, AV1, WebM, MKV) nach dem Laden einmal mit ffmpeg in H.264 um. Ohne ffmpeg bleibt die Datei, wie sie geladen wurde.

## 3.2 — 14.11.2026

- **Insel öffnet nur noch absichtlich.** Der Zeiger muss ganz oben am Bildschirmrand im Notch liegen und dort einen Moment bleiben. Der Weg zur Menüleiste, zu einem Tab oder einer Symbolleiste öffnet nichts mehr, und die geschlossene Insel zeigt sich erst auf dem Notch selbst.
- **Insel kompakter.** Die Seiten-Tabs sitzen neu im Band neben dem Notch (Symbole, die gewählte Seite mit Namen), die Kopfzeile darunter entfällt. Seiten 648 statt 720 pt breit, Start 172 statt 236 pt hoch. Eine einzelne Karte (Claude-Anfrage, Erinnerung, Ablegen, Stow, Assistent) ist nur noch 520 pt breit. Schrift bleibt gleich gross.
- **Insel-Design.** Karten mit feiner Lichtkante, Ecken von Insel und Karten laufen parallel, weicherer Schatten, Öffnen mit sanftem Nachfedern. Musik-Kachel neu geordnet (Titel, Interpret, Liedzeile, Fortschritt in einer Zeile), CPU und RAM als schmale Balken.
- Neu: **Mit meinem Login laden (Instagram).** Unter Einstellungen › Herunterladen meldest du dich auf der echten Instagram-Seite an, in einem eigenen Fenster von Vibrant+. Dein Passwort bleibt bei Instagram. Danach lädt Vibrant+ auch Beiträge, die nur angemeldet sichtbar sind, und zwar genau das, was dein Konto sieht. Die Anmeldung geht nur beim Laden eines Instagram-Links an yt-dlp, als private Kopie, die gleich danach gelöscht wird. «Abmelden» löscht die Anmeldung. Storys zeigen dich als Betrachter.
- Bildbeiträge in Originalgrösse statt Vorschau (z. B. 1439 × 1141 statt 640 × 640), bei Karussells alle Bilder als eigene Einträge. Ist «Video» gewählt und der Beitrag zeigt nur Bilder, lädt Vibrant+ die Bilder und sagt es.

## 3.1 — 10.11.2026

- Neu: **Herunterladen per Link.** Link einfügen, Video, Audio oder Bild wählen, laden. Auf der neuen Inselseite «Laden» (⌘ und Seitennummer), im Menü «Herunterladen» (lädt den kopierten Link) und unter Einstellungen › Herunterladen.
- Direkte Links auf Bild-, Video- und Musikdateien lädt Vibrant+ selbst, mit Fortschritt und Abbrechen. Der Dateiname kommt vom Server, nichts wird überschrieben («… 2»).
- Links von YouTube, Instagram, TikTok, Vimeo, SoundCloud und vielen mehr gehen über yt-dlp, wenn es installiert ist (`brew install yt-dlp ffmpeg`). Vibrant+ liefert yt-dlp nicht mit und zeigt in den Einstellungen, ob es gefunden wurde. Video als MP4 (H.264, spielt überall), Ton als M4A oder MP3, Bild als Vorschaubild.
- Öffentliche Bildbeiträge (z. B. Instagram-Fotos, bei denen yt-dlp kein Video findet): Vibrant+ lädt das Bild, das die öffentliche Seite für Link-Vorschauen nennt, ohne Anmeldung und ohne Cookies. Meist in Vorschaugrösse, bei Karussells das erste Bild. Bei eingeschränkten oder privaten Beiträgen greift das nicht.
- Fair laden: Kopiergeschützte Dienste (Spotify, Netflix, Apple Music u. a.) lehnt Vibrant+ ab, private Inhalte und Inhalte hinter einer Anmeldung ebenso. Ein Hinweis erinnert daran, nur eigene oder freigegebene Inhalte zu laden.
- Ziel: der Ordner «Downloads» oder ein eigener. macOS fragt beim ersten Mal einmal nach dem Zugriff auf «Downloads».

## 3.0 — 2026-11-10

- Mehrere Bildschirme: App-Raster und Tastenanzeige öffnen auf dem Bildschirm mit dem Mauszeiger, nicht mehr auf dem mit dem aktiven Fenster.
- Rand-Regler: bleibt auf seinem Bildschirm und springt nach Anstecken/Abziehen eines Monitors, neuer Auflösung oder Skalierung zurück an den Rand.
- Das Claude-Code-Fenster öffnet nie grösser als der Bildschirm (z. B. 13" Air mit «Grösserer Text»).
- Akku: Alle wiederkehrenden Timer haben 10 % Toleranz, macOS kann Aufwachvorgänge bündeln.
- Build: Release entfernt ungenutzten Code (Dead Code Stripping).

## 2.1.1 — noch nicht veröffentlicht

- Bildschirmfotos: Vibrant+ fragte immer wieder nach der Bildschirmaufnahme, obwohl sie erlaubt war. Ursache: Die Erlaubnis galt für eine anders signierte Kopie (Entwicklerversion), nicht für die installierte. Lokale Builds sind jetzt gleich signiert wie die Releases (Developer ID), damit eine Erlaubnis für alle Kopien gilt.
- Die Systemabfrage erscheint nur noch einmal pro Start. Neu unter Einstellungen › Bildschirmfotos: «Erlaubnis neu einrichten» (löscht den veralteten Eintrag von Vibrant+ und fragt neu) und «Vibrant+ neu starten».
- Claude-Berechtigungen: Die Karte zeigt den ganzen Befehl (scrollbar statt nach vier Zeilen gekürzt), bei MCP-Werkzeugen die Eingabe und bei «Datei schreiben» den Inhalt. Die Überschrift nennt die Aktion; Claudes eigene Beschreibung steht nur noch als «Laut Claude: …» darunter. Heikle Teile eines Befehls (Löschen, sudo, heruntergeladenes Skript ausführen, Git überschreiben) bekommen einen Hinweis.
- Erlauben nur noch mit ⌘↩, nie mit ↩ allein: Ein Return in einem anderen Feld der Insel gibt keinen Befehl mehr frei.
- Rückfragen von Claude: Mehrfachauswahl funktioniert, Erklärungen zu den Optionen erscheinen als Tooltip und für VoiceOver.
- VoiceOver sagt Berechtigungsanfragen, Rückfragen und Hinweise der Insel an.
- Insel: Hover auf Karten ist im Stil «ARJO Verspielt» wieder sichtbar. Kein Text mehr unter 10 pt; die Steuerungen haben volle Namen als Tooltip.
- Liedtexte (LRCLIB) sind neu standardmässig aus, weil dafür Titel und Interpret ins Netz gehen. Einschalten unter Einstellungen › Insel.
- Einstellungen: Akzentfarben mit deutschen Namen; Hinweis zur Darstellung korrigiert.
- «Immer erlauben» nennt die Regel, die es einträgt, und wo (z. B. «Bash(swift build:*) · dieses Projekt, nur für dich»). Warten mehrere Anfragen, zeigt die Karte «1 von n».
- «Verbindung veraltet»: Zeigen die Hooks auf eine andere Kopie von Vibrant+ (verschoben, aus einem anderen Ordner verbunden), sagen das die Einstellungen und das Menü; «Verbindung erneuern» behebt es. Die settings.json wird nur noch geschrieben, wenn sich wirklich etwas ändert.
- Tastatur: Der Kurzbefehl öffnet die Insel mit Fokus; Esc schliesst sie, ⌘1–⌘5 wählt die Seite.
- «Kontrast erhöhen» und «Bewegung reduzieren» wirken sofort, auch auf laufende Animationen.
- Bewegung: Knöpfe der Insel geben beim Drücken leicht nach; der Rand-Regler gleitet vom Rand herein und hinaus, das App-Raster blendet weich aus.
- Lange Hinweise im Notch werden lesbar (beide Flügel wachsen mit).
- Einstellungen: Seitenleiste in drei Abschnitten, das Fenster heisst wie die gewählte Seite.
- Weniger Last im Leerlauf: Die geschlossene Insel tickt nur noch jede Sekunde, solange ein Countdown läuft. Hängt Musik oder Spotify, wartet Vibrant+ höchstens 3 Sekunden statt bis zu 2 Minuten.
- Neu gestaltete Seiten-Tabs der Insel in den eigenen Farben; der Farbschein des Covers füllt die Musik-Kachel bis an den runden Rand (vorher ein eckiger Streifen).
- Wortmarke von Vibrant+ in Willkommen und Über; Module im Willkommensfenster nach «Im Notch» und «Auf dem ganzen Mac» gruppiert.
- Neue Claude-Anfragen gleiten sanft herein; die Seite «Claude» sagt, wie viele Sitzungen nur im Panel stehen.
- Equalizer neben dem Notch lässt sich anhalten (Einstellungen › Insel).
- Speichern, das scheitert (voller Speicher, fehlender Ordner), meldet sich in der Insel statt still Daten zu verlieren.
- «Vibrant+ neu starten» beendet zuerst und öffnet dann neu: zwei Kopien gleichzeitig konnten sich den Claude-Socket wegnehmen. Höchstens 32 wartende Claude-Anfragen gleichzeitig; weitere fragen sofort im Terminal.

## 2.1 — 09.11.2026

- Bildschirmfotos direkt aus Vibrant+: ganzer Bildschirm (der mit dem Mauszeiger), ein Fenster zum Anklicken oder ein Ausschnitt zum Aufziehen (Leertaste wechselt zum Fenster, Esc bricht ab). Das Bild landet im Screenshot-Ordner von macOS, in der Zwischenablage und mit Vorschau in der Insel.
- Auslösen über Tastenkürzel (Standard ⌥⇧⌘3, ⌥⇧⌘4, ⌥⇧⌘5, änderbar unter Einstellungen › Kurzbefehle), die Inselseite «Ablage», das Menü in der Menüleiste oder die neue Aktion «Bildschirmfoto aufnehmen» in der Kurzbefehle-App (gibt die Datei weiter, auch per Siri).
- Fehlt die Berechtigung «Bildschirmaufnahme», fragt Vibrant+ beim ersten Versuch, öffnet die passende Stelle in den Systemeinstellungen und sagt in der Insel, was zu tun ist. Status auch unter Einstellungen › Bildschirmfotos und › Berechtigungen.

## 2.0 — 09.11.2026

- Neues App-Icon (v2A): Display mit Plus füllt die Fläche, Himmel und Pfirsich.
- Absturz behoben, wenn die Mikrofon- oder Spracherkennungs-Berechtigung abgefragt wird oder der erste Audio-Puffer eintrifft.
- Mikrofon: Ist Diktieren im System ausgeschaltet, zeigt die Insel jetzt den Grund («Systemeinstellungen › Tastatur › Diktieren einschalten») statt «nichts gehört».
- Neue Stimmenwahl «Systemstimme»: nutzt die Stimme aus Systemeinstellungen › Bedienungshilfen › Gesprochene Inhalte (z. B. Siri Stimme 1).
- Textbausteine: Fehler behoben, der bei jedem Mausklick eine Ausnahme auslöste.

## 1.9 — 09.11.2026

- Mikrofon-Knopf auf der Inselseite «Fragen»: antippen, sprechen, nach einer kurzen Pause endet die Aufnahme von selbst (oder erneut tippen). Das Gesagte erscheint live.
- Gesprächsmodus (Standard: an): nach der vorgelesenen Antwort hört Vibrant+ wieder zu; «Danke», «Stopp», «Tschüss» oder das Schliessen der Insel beenden das Gespräch.
- Stimme wählbar (alle installierten Apple-Stimmen, deutsch zuerst, nach Qualität) und Sprechtempo, mit «Probehören». Alles läuft mit Apples Spracherkennung, Apple Intelligence und Apple-Stimmen auf dem Mac.
- Musik-Kachel: Interpret im Kopf, damit eine Liedtext-Zeile Platz hat; kein doppelter Punkt nach abgekürztem Datum.

## 1.8 — 09.11.2026

- Auslieferung **notarisiert** von Apple (Developer ID, Ticket angeheftet): öffnet auf anderen Macs ohne Warnung. Neue Releases: `tools/release.sh`.

- Neue Seiten in der Insel: «Claude» (bis zu drei laufende Sitzungen mit Status, Auftrag, letzten Schritten, Dateien und Token), «Ablage» (Ablage und durchsuchbare Zwischenablage nebeneinander) und «Fragen» (Assistent). Es erscheinen nur die Seiten, deren Modul eingeschaltet ist. Das Datum im Kopf ist kürzer, damit alle Seiten Platz haben.

## 1.7 — 09.11.2026

- Notch reagiert sofort: öffnet ohne Wartezeit, sobald die Maus auf dem Notch ist; schliesst 120 ms nach dem Wegfahren. Kritisch gedämpfte Federn (öffnen 0,24 s, schliessen 0,18 s), leichterer Inhaltswechsel. Die Prüfung auf offene Menüs wird zwischengespeichert (150 ms) und nur in der Notch-Zone gemacht, statt bei jeder Mausbewegung das Fenstersystem abzufragen.
- Umgebung überblenden: solange die Insel offen ist, tritt der Rest des Bildschirms zurück, passend zum Stil (Notch-Schwarz: dunkler Schleier vom Notch aus; ARJO Verspielt: Off-White bzw. Schwarz; Liquid Glass: Unschärfe, die vom Notch nach unten ausläuft). Klicks gehen durch; abschaltbar unter Einstellungen › Insel.
- Notch-Form aus der gemessenen Notch jedes MacBooks (Air 13/15, Pro 14/16, jede Skalierung): Eckenradius und konkave Schultern am Menüleisten-Rand skalieren mit der Notch-Höhe; ohne Notch eine Pille in Menüleistenhöhe. Neu gemessen bei jedem Öffnen und bei jeder Änderung der Anzeige.

## 1.6 — 09.11.2026

- Notch: Die Insel öffnet nur noch, wenn die Maus ganz oben genau auf dem Notch steht (nicht mehr darunter oder daneben), nach 70 ms statt 120 ms, und nie, solange ein Menü offen ist. Die kleine Vorschau beim Annähern ist enger und erscheint ebenfalls nie über Menüs. Schnellere, straffere Bewegung (Feder 0,30 s, kaum Überschwingen), schnelleres Schliessen (280 ms).
- Neuer Insel-Stil «Liquid Glass» (Einstellungen › Darstellung): Insel und Rand-Regler im Glas von macOS 26, Karten nur als sanfte Tönung darauf (kein Glas auf Glas), folgt Hell/Dunkel, bei «Transparenz reduzieren» eine feste Fläche. Geschlossen bleibt die Insel immer schwarz wie der Notch.
- Stow: Hochskalieren. Bilder 2× oder 4× (höchstens 12 000 px), Videos 2× bis höchstens 4K, Ton bleibt. Läuft auf dem Mac, kostenlos, ohne Netz. Methode: Lanczos-Vergrösserung mit leichter Schärfung. Das ist klassische Vergrösserung, keine KI, die neue Details erfindet.

## 1.5 — 08.11.2026

- Zwischenablage-Verlauf: Texte und Bilder, Suche, Anheften (Angeheftetes wird gespeichert, der Rest nur im Speicher), eigenes Fenster mit ⌃⌥⌘V.
- Bildschirmfotos: neue Screenshots erscheinen 10 Sekunden in der Insel: kopieren, in der Vorschau beschriften, teilen, im Finder zeigen, in den Papierkorb legen.
- Textbausteine (Einstellungen › Textbausteine, standardmässig aus): «;adr» wird in jeder App zum hinterlegten Text; Platzhalter {datum}, {zeit}, {wochentag}.
- Claude Code: Verlauf mit Dauer, geänderten Dateien und Token-Verbrauch (aus den Transkripten); Meldung im Notch, wenn eine Antwort länger als 2 Minuten dauerte.
- Synchronisierte Liedtexte (LRCLIB) in der Musik-Kachel, abschaltbar.
- Notion in beide Richtungen: Abgehakt, Umbenannt, Datum und neue Seiten aus Notion kommen alle 2 Minuten zurück.
- AirDrop aus der Ablage und aus dem Stow-Ergebnis.
- Mehrere Bildschirme: die Insel wechselt auf den Bildschirm, zu dessen oberer Mitte die Maus geht.
- Fokus-Regeln: «Nicht stören», Dunkelmodus, Desktop-Symbole ausblenden, Mac wach halten, danach wieder zurück.
- Kachel «Kurzbefehle»: bis zu 8 eigene Knöpfe, die Kurzbefehle der Kurzbefehle-App starten.
- Sicherung: Export und Import aller Daten und Einstellungen in eine Datei.

## 1.4 — 08.11.2026

- Neuer Insel-Stil «ARJO Verspielt» nach dem ARJO-LAB-App-Guide Verspielt V1.0 (Einstellungen › Darstellung): hell mit Off-White, Karten in Himmel (Leitton) und Pfirsich (Begleitton für Berechtigungen und Erinnerungen), Text in Schwarz/Graphit, Knöpfe in Himmel Tief, oranger Punkt nach dem Datum; dunkel mit Schwarz #090A0A, Graphit-Ebenen und Pastell als Akzent. Folgt Hell/Dunkel des Mac. Gilt für Insel, Heute, Rand-Regler und Assistent. «Notch-Schwarz» bleibt Standard.

## 1.3 — 08.11.2026

- Stow: mehrere Videos auf den Notch ziehen → «Zu einem Film verbinden». Reihenfolge per Pfeilen oder nach Namen; unterschiedliche Grössen und Hoch-/Querformat werden in das Bild des ersten Clips eingepasst (schwarze Ränder statt Verzerrung), Ton bleibt erhalten. Ergebnis: MP4 neben dem ersten Clip, «… (Film aus N Clips).mp4»; nichts wird überschrieben.

## 1.2 — 08.11.2026

- Notion: Verbindung über eine interne Notion-Integration (Schlüssel im macOS-Schlüsselbund). Aufgaben- und Termin-Datenbank wählbar; Titel, Datum und Erledigt (Checkbox oder Status) werden automatisch erkannt.
- Neue Aufgaben (Insel, Heute, Assistent, Siri) werden in Notion angelegt; Erledigt, Erinnerung und Löschen (Archivieren) werden übernommen.
- Termine: Assistent («Leg morgen um 14 Uhr einen Kundentermin an») und Siri («Termin in Vibrant+ anlegen») speichern in der Notion-Termin-Datenbank, ohne Auswahl im Apple-Kalender.
- Insel im Ruhezustand ganz unsichtbar; sie erscheint, wenn die Maus Richtung Notch geht, und öffnet sich ganz oben. Nur Dringendes (Claude wartet, Termin in 5 Minuten, Hinweis) zeigt sich von selbst.

## 1.1 — 08.11.2026

- Assistent mit Apple Intelligence direkt auf dem Mac (Foundation Models): ohne Konto, ohne Kosten, ohne Internet. Fragen per Text (Sprechblase in der Insel) oder Stimme (⌃⇧ halten), Antworten erscheinen laufend in der Insel und werden auf Wunsch vorgelesen; Folgefragen innerhalb von 5 Minuten setzen das Gespräch fort.
- Der Assistent kann handeln: Aufgabe mit Erinnerung anlegen, Timer und Fokus starten, App öffnen, Termine und Aufgaben von heute nennen.
- Diktat (⌃⌥) wird mit dem Modell bereinigt; unbekannte Sprachbefehle (⌃⌘) gehen an den Assistenten.
- Siri, Kurzbefehle und Spotlight: «Frag Vibrant+», «Aufgabe in Vibrant+ hinzufügen», «Fokus in Vibrant+ starten», «Timer in Vibrant+ starten», «Öffne die Insel in Vibrant+», «Ordne Fenster mit Vibrant+».
- Build über ein mit XcodeGen erzeugtes Xcode-Projekt (nötig für die App-Intents-Metadaten); Unit-Tests weiter mit `swift test`.

## 1.0.1 — 08.11.2026

- Insel im Ruhezustand exakt so breit wie der Notch (156 × 28 pt auf diesem MacBook Air) und damit unsichtbar; sie wächst nur, wenn etwas zu zeigen ist (Claude arbeitet oder fragt, Musik, Fokus, Timer, Termin, Hinweis). Ohne Notch im Ruhezustand unsichtbar.
- Autostart: beim ersten Start als Anmeldeobjekt registriert; abschaltbar unter Einstellungen › Allgemein.

## 1.0 — 08.11.2026

Erste Version.

- Insel am Notch mit Kacheln: Musik (Musik, Spotify), Claude Code, nächster Termin mit «Beitreten», Wetter, Uhr und Monat, Systemwerte, Aufgaben, Timer, Ablage, Zwischenablage, letzte Apps, Steuerungen. Hinweise bei wenig Platz, Speicherdruck, Akku und Wärme.
- Claude Code live: eigener Hook im App-Binary, Berechtigungen (Erlauben, Ablehnen, Immer erlauben), Fragen als Auswahl, Dateien für die nächste Nachricht, Panel mit Schritten, Dateien und Diffs, Verbinden/Trennen per Klick.
- Heute: Aufgaben mit Erinnerungen, Fokus-Timer, Notiz, Termine, Insights (7 Tage), Anpassen.
- Stow: Für Web / Senden / Drucken, JPEG, PNG, HEIC, TIFF, PDF, MP4, MOV, M4A; Werkzeuge mit ⌥; Aufräumen von Schreibtisch und Downloads mit Rückgängig.
- Rowline: Fensterreihe mit Scrollen und Breiten, Hälften/Drittel, Raster, Stapel, anderer Bildschirm, gespeicherte Anordnungen.
- Rand-Regler: Lautstärke, Stumm, Lautstärke pro App, Timer.
- Stimme (Beta): Diktieren und Befehle ohne KI-Modell.
- Tastengeräusche (3 synthetische Klänge), Tasten anzeigen, App-Raster, Themen Nacht/Papier.
- App-Icon v1A (ARJO LAB) als Icon-Composer-Datei, Designsystem aus dem Branding.

Auslieferung: `Releases/2026-11-08_v1.0/Vibrant+-1.0.zip` (Developer ID signiert, Hardened Runtime, **nicht notarisiert**; SHA-256 56d078e9…bfd0).
