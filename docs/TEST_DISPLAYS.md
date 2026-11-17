# Testplan: Bildschirme, Skalierung, Leistung

Von Hand vor jedem Release. Build: `./build.sh --open`. Jeder Punkt: erwartetes Ergebnis in Klammern.

## 1. Skalierung (ohne zusätzliche Hardware)

Systemeinstellungen › Displays › eingebauter Bildschirm › alle Stufen von «Grösserer Text» bis «Mehr Platz» durchgehen. Bei jeder Stufe:

- Insel per Hover über dem Notch und per Kurzbefehl öffnen (genau mittig unter dem Notch, Form passt zum Notch, nichts abgeschnitten).
- Rand-Regler am Bildschirmrand anfahren (Lasche sitzt am Rand, Panel ganz sichtbar).
- Einstellungen, Heute, Claude Code, Zwischenablage öffnen (Fenster passt auf den Bildschirm, Inhalt nicht abgeschnitten, Claude-Code-Fenster lässt sich verkleinern).
- Stufe wechseln, während die App läuft (Insel und Lasche wandern ohne Neustart an die richtige Stelle).

Für eine Liste aller Auflösungen: «Erweitert…» › «Auflösungen als Liste anzeigen».

## 2. Notch und Menüleiste

- MacBook mit Notch: viele Menüleisten-Symbole anderer Apps einschalten, bis die Leiste voll ist. Prüfen, ob das Vibrant+-Symbol noch sichtbar ist. Wenn nicht: macOS blendet Symbole hinter dem Notch aus, keine App kann das verhindern. Vibrant+ bleibt dann über die Insel (Hover, Kurzbefehl) erreichbar; unter Systemeinstellungen › Menüleiste lassen sich andere Symbole ausblenden. Notieren.
- App mit vielen Menüs vorne (z. B. Xcode): Insel öffnet nicht, solange ein Menü offen ist.
- Menüleiste automatisch ausblenden (Systemeinstellungen › Kontrollzentrum): Insel weiterhin am Notch.
- Hell/Dunkel umschalten (Symbol in der Menüleiste bleibt scharf und passt sich an).

## 3. Externe Monitore

Mit Full HD, 4K (skaliert), 5K/Studio Display, Pro Display XDR testen, was verfügbar ist:

- Monitor anstecken, abziehen, während die App läuft (keine Insel/Lasche ausserhalb des Bildschirms, kein Absturz).
- MacBook zugeklappt (Clamshell): Insel als Pille in der Menüleiste des Monitors.
- Maus oben in die Mitte des anderen Bildschirms (Insel wechselt dorthin).
- App-Raster (⌥⌘4) und Tastenanzeige erscheinen auf dem Bildschirm mit dem Mauszeiger.
- Monitor links/rechts/oberhalb anordnen (Systemeinstellungen › Displays › Anordnen) und alles wiederholen.
- Systemeinstellungen › Schreibtisch & Dock › «Monitore verwenden verschiedene Spaces» an und aus.

## 4. Vollbild, Spaces, Stage Manager

- Eine App im Vollbild: Insel und Lasche sind da.
- Stage Manager an: Insel über allem, Fenster von Vibrant+ lassen sich normal in Gruppen ziehen.
- Spaces wechseln (Insel bleibt, folgt auf alle Spaces).

## 5. ProMotion und Leistung

- MacBook Pro 14"/16": Systemeinstellungen › Displays › Bildwiederholrate «ProMotion» und «60 Hertz». Insel öffnen/schliessen, Karten-Hover, Equalizer (flüssig in beiden).
- Quartz Debug (Additional Tools for Xcode) › «Frame Meter»: beim Öffnen der Insel nahe 120 fps.
- Leerlauf: Aktivitätsanzeige › Energie, Vibrant+ 10 min mit geschlossener Insel (Energieauswirkung nahe 0, «Verhindert Ruhezustand» Nein). CPU-Spalte: unter 1 %.
- Instruments › «Energy Log» oder `top -pid $(pgrep VibrantPlus) -stats cpu,idlew,mem` (Idle Wakeups niedrig, Speicher stabil über 30 min).

## 6. Bedienungshilfen

Systemeinstellungen › Bedienungshilfen › Anzeige:

- «Bewegung reduzieren»: Insel, Regler, App-Raster erscheinen ohne Bewegung; Equalizer und Puls stehen still.
- «Kontrast erhöhen» und «Transparenz reduzieren»: Texte lesbar, Abdunklung ohne Glas.
- VoiceOver (⌘F5): Menüleisten-Symbol, Insel-Karten, Berechtigungskarte haben verständliche Namen; Hinweise werden angesagt.
- Nur Tastatur: Insel per Kurzbefehl, ⌘1–5, Tab, Esc, ⌘↩; Einstellungen ganz mit Tab bedienbar (Systemeinstellungen › Tastatur › «Tastaturnavigation» an).

## 7. Fremder Mac (Gatekeeper)

- `tools/release.sh`, ZIP auf einen anderen Mac (oder anderen Benutzer) kopieren, per AirDrop oder Browser, damit das Quarantäne-Attribut gesetzt ist.
- Doppelklick (öffnet ohne Warnung «nicht verifizierter Entwickler»).
- Prüfen: `spctl -a -vv Vibrant+.app` (accepted, source=Notarized Developer ID) und `xcrun stapler validate Vibrant+.app`.

## 8. Hook-Schnittstelle

- `echo '{"hook_event_name":"Notification","session_id":"t","message":"x"}' | /Applications/Vibrant+.app/Contents/MacOS/VibrantPlus --hook` (Exit 0, ohne laufende App keine Ausgabe).
- `tools/selftest.sh` (SELFTEST PASS).
