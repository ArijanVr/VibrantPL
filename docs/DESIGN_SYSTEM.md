# Vibrant+ Designsystem

Leitsatz: «Porzellan trägt, Tinte spricht, Puls zeigt.» Tokens im Code: `Sources/VibrantPlus/DesignSystem/Tokens.swift`, Akzente in `UI/Theme.swift`, Wortmarke in `DesignSystem/Wordmark.swift`.

Porzellan ist der Haupthintergrund. Tinte trägt den Text. Puls (#C2306A, dunkel #F07AA8) erscheint nur bei Aktivem: Auswahl, Fokus, Primärknopf, Statuspunkt. Kein Pastell, kein Neon, kein bunter Verlauf.

## Farben

Hell, auf Porzellan #F6F5F1. Dunkel, auf Graphitnacht #141414. Text und Status mindestens 4,5 : 1.

| Token | Hell | Dunkel | Verwendung |
|---|---|---|---|
| `porzellan` / `graphitNacht` | #F6F5F1 | #141414 | Fenstergrund |
| `kreide` / `graphit` | #FCFCFA | #1E1E1D | Karten, Popover |
| `leinen` / `schiefer` | #EDECE7 | #282827 | Gruppen |
| `naht` / `nahtDunkel` | #DEDCD5 | #3A3A38 | 1-px-Linie |
| `tinte` / `porzellan` | #1D1D1F | #F6F5F1 | Haupttext (15,4 : 1 / 16,9 : 1) |
| `stein` / `sand` | #5E5D59 | #B4B2AC | Nebentext |
| `kiesel` / `kieselDunkel` | #6E6D68 | #8E8C87 | Hinweis (4,75 : 1 / 5,48 : 1) |
| `puls` | #C2306A | #C2306A | Primärfläche. Weiss darauf 5,35 : 1 |
| `pulsHell` | | #F07AA8 | Akzenttext dunkel, Insel-Akzent auf Schwarz 7,59 : 1 |
| `pulsGlass` | | #FFB8D5 | Akzenttext auf Rauchglas |
| `erfolg` | #1E7F45 | #4FD07F | Verbunden, abgeschlossen |
| `bernsteinText` / `bernsteinHell` | #9A5B00 | #F5B03E | Warntext. Glow hell #D98218, dunkel #F5B03E |
| `gefahr` | #C8312C | #FF6B63 | Fehlertext |
| `hinweis` | #0060C8 | #5EA8FF | Links |
| `black` | #090A0A | #090A0A | Insel, immer |

Die Insel ist immer Tiefschwarz (`IslandPalette.notch`), in Hell und Dunkel, offen wie geschlossen. `primaryText` ist Porzellan, `accentText` ist `pulsHell`, `accentFill` ist `puls`. Karten darin sind Schiefer. Hover legt einen Schleier darüber (`hoverVeil`), damit Knöpfe auf der Karte sichtbar bleiben.

Akzent der Fenster: «System» folgt der Mac-Akzentfarbe. Ist sie «Mehrfarbig», erscheint Puls (`ThemeStore.brand`, hell `pulsHell`, Fläche `puls`). Fenster-Status nutzen die Paare oben (`Palette.danger`, `caution`, `success`, `info`).

Seitenleiste und schwebende Flächen nutzen Apples Material (`.regularMaterial`). Inhaltskarten bleiben deckend, kein Glas auf Glas. Die Insel selbst bleibt schwarz, ausser im Stil «Liquid Glass».

**Kontrast erhöhen:** Jede Insel-Palette hat `increasedContrast()` (Nebentext 90 %, Hinweise 78 %, Linien 35 % der Hauptfarbe), live umgeschaltet.

## Insel-Stil

- «Notch-Schwarz» (Standard): die Insel in Schwarz, Graphit-Karten mit Lichtkante, Off-White-Text, Puls als Akzent.
- «Liquid Glass»: Rauchglas, in Hell und Dunkel gleich. Das Band neben dem Notch bleibt deckend Schwarz und läuft über `Glass.melt` (24 pt) in Rauch (`Glass.smoke`, 65 %) auf `glassEffect(.regular)` aus. Geschlossen immer Schwarz.
- Es gibt genau eine Glasschicht, den Inselkörper. Kacheln sind Scheiben darin: Füllung Weiss 8 %, Schimmer oben (`Glass.sheen`), Lichtkante von oben links. Nie `glassEffect` in einer Kachel (kein Glas auf Glas).
- «Transparenz reduzieren» und «Kontrast erhöhen» ersetzen das Glas durch die schwarze Fassung (`IslandTheme.drawsGlass`).
- Lesbarkeit gilt gegen den schlimmsten Grund, ein weisses Fenster hinter dem Glas: alle Textstufen mindestens 4,5 : 1. Wer `smoke`, `sheen` oder eine Textfarbe ändert, misst neu.
- Der frühere Stil «ARJO Verspielt» (Pastellkarten) ist entfallen. Gespeicherte Auswahl fällt auf «Notch-Schwarz» zurück.

## Typografie

Die Oberfläche nutzt durchgehend SF Pro (`Font.system`), damit Dynamic Type und Bedienungshilfen greifen. Die Wortmarke «Vibrant» bleibt Geist Medium, nur als Vektorpfade (SIL OFL 1.1), nie als gesetzter Text und nie in SF Pro. Insel: Titel 13 semibold, Text 12, Hinweis 11, Label 10 medium, Zahlen 28 semibold rounded, Timer 22, Code 11 monospaced (`islandCode`). Fenster: Large Title 26 bold, Title 20 semibold (`TypeStyle`). Untergrenze 10 pt (`islandMicro`).

## Raster, Radien, Schatten

- Grundraster 8 pt (`8, 16, 24, 32`). 4 pt nur für Mikroabstände (`Space.xs`). Der Inselrand bleibt 12 pt, weil Kartenradius 12 plus Rand 12 den Inselradius 24 ergibt.
- Radien: Karte 12 (`Radius.card`), Sheet 16 (`Radius.sheet`), Bedienelement und Chip 8, Insel 24 (`Radius.island`).
- Schatten: Karte y 1, Blur 3, Schwarz 6 %. Schwebend (offene Insel) y 12, Blur 30, Schwarz 10 %. Im Dunkelmodus der Insel eine 1-pt-Lichtkante in Porzellan mit 8 % (`rimLight`).
- Karten tragen diese Lichtkante (`rimLight`, `rimShade`), bei «Kontrast erhöhen» eine gleichmässige Linie.
- Konzentrisch: Kartenradius 12 + Inselrand 12 = Inselradius 24. Kartenkopf immer 20 pt hoch (`Metrics.cardHeaderHeight`).

## Bewegung

Quelle der Wahrheit ist `Motion` in `Tokens.swift`. Brandguide 12 nennt Dauern von 120 bis 400 ms und die Kurve (0,2 ; 0 ; 0 ; 1); der Code folgt weiterhin den Werten unten. Angleichen ist offen.

- Insel öffnen: Feder (response 0.36, damping 0.86), Start bei 94 %. Schliessen schneller: response 0.22, damping 1.0.
- Seitenwechsel: Feder (response 0.28, damping 1.0, kein Nachfedern). Die neue Seite kommt 16 pt aus der Richtung ihres Tabs.
- Kleine Zustände (Hover, Zähler): easeOut 0.14 s. Ein-/Ausblenden: easeInOut 0.24 s.
- Inhalt der Insel: ein 0.2 s nach 0.04 s, aus 0.08 s. Panels: ein 0.18 s, aus 0.14 s.
- Knöpfe: gedrückt 0.97 und etwas dunkler, 0.1 s; bei «Bewegung reduzieren» nur dunkler.
- Alles über `Motion.respecting(_:)`: bei «Bewegung reduzieren» ohne Animation. Keine Daueranimation ausser dem Atem des Lichtsaums, solange Claude arbeitet (2,4 s, Deckkraft 0,20 bis 0,30), und dem Equalizer. Der Saum liegt nur am Aussenrand, nie über Text. Am Ende ein kurzer Puls (etwa 0,45 s) und ein Ausblenden in 0,3 s. Fehler und wartende Anfragen leuchten ruhig in Bernstein bei 0,24, ohne Blinken. «Bewegung reduzieren» hält den Saum statisch bei 0,24.

## Interaktionszustände

Hover hellt auf und senkt nie den Kontrast; Primär = `accentFill` mit Off-White-Text, Warm = Puls 22 % (nie auffälliger als Primär), Gefahr = Puls 35 %. Leere Karten zeigen `IslandEmpty`. Tastatur: ⌘↩ = Erlauben (nie ↩ allein), Esc = Ablehnen in der Berechtigungskarte.

## Layout-Metriken

Insel offen so gross wie ihr Inhalt: Seiten 656 pt breit (632 Inhalt), eine einzelne Karte 520 pt; Höhe nach Inhalt (max. 520). Kachel 152 × 128, breite Kachel 312, Heute-Karte 152 × 148. Das Band neben dem Notch ist so hoch wie der Notch (mindestens 32). Rand-Regler: Lasche 6 × 132, Panel 300 breit.

## Navigation der Insel

- Links vom Notch «Wohin kann ich»: ein Symbol je Seite (`IslandPageTabs`), die gewählte in Puls auf einer Pille. Die Klickfläche ist so hoch wie das Band.
- Rechts vom Notch «Wo bin ich»: Seitenname, dann Datum und Einstellungen. Liegt der Zeiger auf einem Symbol, steht dort dessen Name; Hover wählt nie. Fehlt Platz, weicht zuerst das Datum.
- Beim Anordnen steht rechts «Kacheln anordnen» mit «Fertig».
- Wege: Klick, ⌘1 bis ⌘9, ← und →, Wischen seitwärts am Rand der Reihe. Zurück: Esc, Klick daneben, Wischen nach unten (nicht über scrollbarem Inhalt, nicht bei wartender Anfrage).
- Namen, je einer pro Seite: Start, Mac, KI, Werkzeuge, Heute, Claude, Ablage, Downloads (nicht «Laden»), Assistent (nicht «Fragen»).

## Öffnen mit der Maus

Die Insel öffnet erst, wenn der Zeiger ganz oben am Bildschirmrand im Notch liegt (oberste 4 pt, `NotchGeometry.isOnTopEdge`) und dort 200 ms bleibt. Dateien an den Notch ziehen öffnet wie bisher.

## Icon und Marke

- App-Icon A «Porzellan-Puls» (`Icon/AppIcon.icon`, Master `Assets/full.svg` und `full.png`): vollflächig, ohne Aussenmaske und ohne Text, damit macOS Squircle und Schatten setzt (`icon.json`, `glass: false`). Hintergrund #FDFCFA nach #ECEAE4, Glanz oben höchstens 60 % Weiss. Pulslinie `232,540 … 736,540`, Strich 64, rund, Verlauf #3A3A3D nach #141415, Schatten dy 16, Blur 12, 16 % Schwarz. Puls-Punkt bei (806, 540), Radius 44, #C2306A mit Glanz #F48AB4. `docs/media/app-icon.png` ist die maskierte Fassung für README und Releases. `./build.sh` kompiliert `Icon/AppIcon.icon` mit Xcode. `tools/make_icon.sh` schreibt auf einem Mac `Resources/Assets.car` und `Resources/AppIcon.icns`.
- Menüleiste: `VibrantMark` zeichnet dieselbe Pulslinie als Vorlagenbild. Der rosa Punkt bleibt im Icon, nicht in der Vorlage.
- Das ARJO-LAB-Logo ist nie das App-Icon. Es erscheint nur in der Absenderzeile.
- Wortmarke: `Wordmark` zeichnet «Vibrant» in Geist Medium (Pfade unverändert) und ein freies Kreuz in Puls, runde Enden, um 8° nach links gekippt, oben bündig mit der Versalhöhe (Strich 92 / 1000 em). Hell #C2306A, dunkel #F07AA8. Keine schwarze Notch-Kachel hinter dem Plus. Dateien: `docs/media/logo-wortmarke.svg` (hell), `logo-dunkel.svg`, `logo-symbol.svg`.
- Pulsi (Porzellan): Fotos in `Resources/Pulsi/` für Willkommen, Leerzustände und Erfolg. Die gezeichnete Figur am Notch bleibt optional. Nie auf Einstellungsformularen, nie als App-Icon.
- Absenderzeile: «Ein Produkt von ARJO LAB» in Über und Einstellungen.

## Einstellungen

- Seitenleiste nach Aufgaben: Allgemein, Insel, KI und Stimme, Dateien und Text, Mac, Wartung. Eine Gruppe ohne eingeschaltetes Modul verschwindet ganz.
- Die Insel hat drei Seiten: «Insel» (Verhalten, Navigation, Kalender), «Kacheln» (Szenen, Kacheln, Kurzbefehle, Wetter), «Leuchten» (Leuchtumriss). Sie erscheinen nur, solange die Insel eingeschaltet ist (`SettingsPage.requires`).
- Seitenleiste 220 pt breit, kein Name wird abgeschnitten. Kein `.toolbar(removing: .sidebarToggle)`: in diesem Fenster setzt es die Spaltenbreite ausser Kraft.
- Die Suche findet Seiten über Titel, Gruppe, Modul und Stichwörter (`SettingsPage.keywords`), auch wenn das Modul aus ist.
- Namen: «Downloads» (nicht «Herunterladen»), «Updates anderer Apps» für Homebrew und App Store; Updates von Vibrant+ selbst stehen unter «Über».

