# Vibrant+ Designsystem

Quelle: Brandguide Vibrant+ V1.0 (14.11.2026, Kapitel 04 bis 12), Grundlage App-Guide Seriös V1.1 von ARJO LAB. Tokens im Code: `Sources/VibrantPlus/DesignSystem/Tokens.swift`, Akzente in `UI/Theme.swift`, Wortmarke in `DesignSystem/Wordmark.swift`.

Leitsatz: «Grau trägt. Puls zeigt.» Grau für Flächen und Text, ein einziger Akzent (Puls) für Ereignisse, Fokus und Status. Pastell gehört nur ins Icon.

## Farben

| Token | Wert | Verwendung |
|---|---|---|
| `Brand.pulsLight` | #EC6FA2 | Puls als Text und Symbol auf Graphit (5,1 : 1) |
| `Brand.pulsGlass` | #FFB8D5 | Puls als Text und Symbol auf Rauchglas (mindestens 4,6 : 1) |
| `Brand.pulsInk` | #C9326F | Puls-Fläche, die Text trägt (`accentFill`, 4,95 : 1) |
| `Brand.puls` | #D63C7A | Akzent: Ereignis-Punkt, Fokus, Status, Titel-Punkt. Gleich in Hell und Dunkel. Nie Fliesstext. |
| `Brand.offWhite` | #FDFDFC | Hintergrund hell, Karte hell, Text dunkel |
| `Brand.grouped` | #F0F0EE | Gruppenfläche, Seitenleiste hell |
| `Brand.hairline` | #D9DAD8 | Trennlinie hell, Hover hell |
| `Brand.black` | #090A0A | Insel (immer), Hintergrund dunkel, Text hell |
| `Brand.graphite` | #2A2C2C | Karte dunkel, Ebenen |
| `Brand.grey` | #6B6E6D | Sekundärtext hell, Rand Bedienelement |
| `Brand.lightGrey` | #D9DAD8 | Sekundärtext dunkel |

Die Insel ist immer Schwarz (`IslandPalette.notch`), in Hell und Dunkel, offen wie geschlossen. Karten darin sind Graphit 55 %; Hover legt einen Schleier darüber (`hoverVeil`), damit Knöpfe auf der Karte sichtbar bleiben.

Kontrast (WCAG 2.2): Puls auf Off-White 4,31 : 1, Puls auf Schwarz 4,52 : 1 (UI ok, Text ok nur auf Schwarz). Text Schwarz auf Off-White 19,48 : 1.

**Pastell:** Himmel #CFE1F4, Pfirsich #FFD9C8, Rosé #F7D5DD nur im App-Icon und in Werbebildern. Keine Pastellfläche in der Oberfläche.

Akzent der Fenster: «System» folgt der Mac-Akzentfarbe; ist sie «Mehrfarbig», erscheint Puls (`ThemeStore.brand`). Zusätzlich wählbar: Puls und die Systemfarben. Fenster-Status (Fehler, Vorsicht, Diff) bleiben Systemfarben, damit Hell, Dunkel und «Kontrast erhöhen» greifen.

**Kontrast erhöhen:** Jede Insel-Palette hat `increasedContrast()` (Nebentext 90 %, Hinweise 78 %, Linien 35 % der Hauptfarbe), live umgeschaltet.

## Insel-Stil

- «Notch-Schwarz» (Standard): die Insel in Schwarz, Graphit-Karten mit Lichtkante, Off-White-Text, Puls als Akzent.
- «Liquid Glass»: Rauchglas, in Hell und Dunkel gleich. Das Band neben dem Notch bleibt deckend Schwarz und läuft über `Glass.melt` (24 pt) in Rauch (`Glass.smoke`, 65 %) auf `glassEffect(.regular)` aus. Geschlossen immer Schwarz.
- Es gibt genau eine Glasschicht, den Inselkörper. Kacheln sind Scheiben darin: Füllung Weiss 8 %, Schimmer oben (`Glass.sheen`), Lichtkante von oben links. Nie `glassEffect` in einer Kachel (kein Glas auf Glas).
- «Transparenz reduzieren» und «Kontrast erhöhen» ersetzen das Glas durch die schwarze Fassung (`IslandTheme.drawsGlass`).
- Lesbarkeit gilt gegen den schlimmsten Grund, ein weisses Fenster hinter dem Glas: alle Textstufen mindestens 4,5 : 1. Wer `smoke`, `sheen` oder eine Textfarbe ändert, misst neu.
- Der frühere Stil «ARJO Verspielt» (Pastellkarten) ist entfallen. Gespeicherte Auswahl fällt auf «Notch-Schwarz» zurück.

## Typografie

Die Brand-Schrift ist Geist (Geist Mono für Befehle). Im Code noch SF Pro (System), damit Dynamic Type und Bedienungshilfen greifen. Geist ist nicht eingebunden; Einbinden ist offen (Lizenz SIL OFL 1.1). Insel: Titel 13 semibold, Text 12, Hinweis 11, Label 10 medium, Zahlen 28 semibold rounded, Timer 22, Code 11 monospaced (`islandCode`). Untergrenze 10 pt (`islandMicro`).

## Raster, Radien, Schatten

- 4-pt-Raster (`Space`: 4, 8, 12, 16, 20, 24, 32; Ränder 20).
- Radien nach Brandguide 06: Klein 6 (Chip, Badge), Bedienelement 8 (`Radius.control`), Karte 12 (`Radius.card`), Sheet 20. Insel 24 (Notch-Form, `Radius.island`).
- Ein Schatten: Insel offen, Schwarz 32 %, Radius 20, y 8.
- Karten tragen eine 1-pt-Lichtkante (`rimLight`, `rimShade`), bei «Kontrast erhöhen» eine gleichmässige Linie.
- Konzentrisch: Kartenradius 12 + Inselrand 12 = Inselradius 24. Kartenkopf immer 20 pt hoch (`Metrics.cardHeaderHeight`).

## Bewegung

Quelle der Wahrheit ist `Motion` in `Tokens.swift`. Brandguide 12 nennt Dauern von 120 bis 400 ms und die Kurve (0,2 ; 0 ; 0 ; 1); der Code folgt weiterhin den Werten unten. Angleichen ist offen.

- Insel öffnen: Feder (response 0.36, damping 0.86), Start bei 94 %. Schliessen schneller: response 0.22, damping 1.0.
- Seitenwechsel: Feder (response 0.28, damping 1.0, kein Nachfedern). Die neue Seite kommt 16 pt aus der Richtung ihres Tabs.
- Kleine Zustände (Hover, Zähler): easeOut 0.14 s. Ein-/Ausblenden: easeInOut 0.24 s.
- Inhalt der Insel: ein 0.2 s nach 0.04 s, aus 0.08 s. Panels: ein 0.18 s, aus 0.14 s.
- Knöpfe: gedrückt 0.97 und etwas dunkler, 0.1 s; bei «Bewegung reduzieren» nur dunkler.
- Alles über `Motion.respecting(_:)`: bei «Bewegung reduzieren» ohne Animation. Keine Daueranimation ausser dem Puls «Claude arbeitet», dem Equalizer und dem Licht, das über die offene Insel fährt (hin und zurück, 2,4 s je Weg, abschaltbar); alle stehen bei «Bewegung reduzieren» still.

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

- App-Icon (`Icon/AppIcon.icon`, Master `Assets/full.svg`, Brandguide 10): Ebenen 1 Hintergrund (Verlauf Himmel #CFE1F4 nach Pfirsich #FFD9C8), 2 Glow (Puls, oben rechts, weich), 3 Glasebene (Schimmer nur auf der Linie), 4 Symbol (Pulslinie Graphite #2A2C2C nach Black #090A0A, Strich 100 px, runde Enden, 80 % Breite), 5 Glanz (oben, bis 38 % Weiss). Vollflächig, ohne Maske, ohne Text. macOS ergänzt Glas, Schatten und Maske. Resources (`Assets.car`, `AppIcon.icns`) entstehen mit `tools/make_icon.sh` (`build.sh` ruft es auf).
- Menüleiste: `VibrantMark` zeichnet dieselbe Pulslinie als Vorlagenbild.
- Das ARJO-LAB-Logo ist nie das App-Icon. Es erscheint nur in der Absenderzeile.
- Wortmarke: `Wordmark` zeichnet «Vibrant» in Geist Medium aus `Design/Wortmarke/Vibrant-Plus_Wortmarke_*_v1.svg` (Pfade unverändert) und das «+» in Puls, runde Enden, um -8° gekippt, oben bündig mit der Versalhöhe (Strich 92 / 1000 em). Das «+» ist eine eigene Form und nimmt den Akzent.
- Absenderzeile: «Ein Produkt von ARJO LAB» in Über und Einstellungen.

## Einstellungen

- Seitenleiste nach Aufgaben: Allgemein, Insel, KI und Stimme, Dateien und Text, Mac, Wartung. Eine Gruppe ohne eingeschaltetes Modul verschwindet ganz.
- Die Insel hat drei Seiten: «Insel» (Verhalten, Navigation, Kalender), «Kacheln» (Szenen, Kacheln, Kurzbefehle, Wetter), «Leuchten» (Leuchtumriss). Sie erscheinen nur, solange die Insel eingeschaltet ist (`SettingsPage.requires`).
- Seitenleiste 220 pt breit, kein Name wird abgeschnitten. Kein `.toolbar(removing: .sidebarToggle)`: in diesem Fenster setzt es die Spaltenbreite ausser Kraft.
- Die Suche findet Seiten über Titel, Gruppe, Modul und Stichwörter (`SettingsPage.keywords`), auch wenn das Modul aus ist.
- Namen: «Downloads» (nicht «Herunterladen»), «Updates anderer Apps» für Homebrew und App Store; Updates von Vibrant+ selbst stehen unter «Über».

