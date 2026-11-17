# Vibrant+ Designsystem

Quelle: Brandguide Vibrant+ V1.0 (14.11.2026, Kapitel 04 bis 12), Grundlage App-Guide Seriös V1.1 von ARJO LAB. Tokens im Code: `Sources/VibrantPlus/DesignSystem/Tokens.swift`, Akzente in `UI/Theme.swift`, Wortmarke in `DesignSystem/Wordmark.swift`.

Leitsatz: «Grau trägt. Puls zeigt.» Grau für Flächen und Text, ein einziger Akzent (Puls) für Ereignisse, Fokus und Status. Pastell gehört nur ins Icon.

## Farben

| Token | Wert | Verwendung |
|---|---|---|
| `Brand.puls` | #D63C7A | Akzent: Ereignis-Punkt, Fokus, Status, Titel-Punkt. Gleich in Hell und Dunkel. Nie Fliesstext. |
| `Brand.offWhite` | #FDFDFC | Hintergrund hell, Karte hell, Text dunkel |
| `Brand.grouped` | #F0F0EE | Gruppenfläche, Seitenleiste hell |
| `Brand.hairline` | #D9DAD8 | Trennlinie hell, Hover hell |
| `Brand.black` | #090A0A | Insel (immer), Hintergrund dunkel, Text hell |
| `Brand.graphite` | #2A2C2C | Karte dunkel, Ebenen |
| `Brand.grey` | #6B6E6D | Sekundärtext hell, Rand Bedienelement |
| `Brand.lightGrey` | #D9DAD8 | Sekundärtext dunkel |

Die Insel ist immer Schwarz (`IslandPalette.notch`), in Hell und Dunkel, offen wie geschlossen. Karten darin sind Graphit (55 %, Hover 85 %).

Kontrast (WCAG 2.2): Puls auf Off-White 4,31 : 1, Puls auf Schwarz 4,52 : 1 (UI ok, Text ok nur auf Schwarz). Text Schwarz auf Off-White 19,48 : 1.

**Pastell:** Himmel #CFE1F4, Pfirsich #FFD9C8, Rosé #F7D5DD nur im App-Icon und in Werbebildern. Keine Pastellfläche in der Oberfläche.

Akzent der Fenster: «System» folgt der Mac-Akzentfarbe; ist sie «Mehrfarbig», erscheint Puls (`ThemeStore.brand`). Zusätzlich wählbar: Puls und die Systemfarben. Fenster-Status (Fehler, Vorsicht, Diff) bleiben Systemfarben, damit Hell, Dunkel und «Kontrast erhöhen» greifen.

**Kontrast erhöhen:** Jede Insel-Palette hat `increasedContrast()` (Nebentext 90 %, Hinweise 78 %, Linien 35 % der Hauptfarbe), live umgeschaltet.

## Insel-Stil

- «Notch-Schwarz» (Standard): die Insel in Schwarz, Graphit-Karten, Off-White-Text, Puls als Akzent.
- «Liquid Glass»: `glassEffect(.regular)` von macOS 26. Hell: Text Schwarz, Karten Grau 9 %; dunkel: Text Off-White. Akzent Puls. «Transparenz reduzieren» ersetzt das Glas durch eine feste Fläche (Off-White hell, Schwarz dunkel).
- Der frühere Stil «ARJO Verspielt» (Pastellkarten) ist entfallen. Gespeicherte Auswahl fällt auf «Notch-Schwarz» zurück.

## Typografie

Die Brand-Schrift ist Geist (Geist Mono für Befehle). Im Code noch SF Pro (System), damit Dynamic Type und Bedienungshilfen greifen. Geist ist nicht eingebunden; Einbinden ist offen (Lizenz SIL OFL 1.1). Insel: Titel 13 semibold, Text 12, Hinweis 11, Label 10 medium, Zahlen 28 semibold rounded, Timer 22, Code 11 monospaced (`islandCode`). Untergrenze 10 pt (`islandMicro`).

## Raster, Radien, Schatten

- 4-pt-Raster (`Space`: 4, 8, 12, 16, 20, 24, 32; Ränder 20).
- Radien nach Brandguide 06: Klein 6 (Chip, Badge), Bedienelement 8 (`Radius.control`), Karte 12 (`Radius.card`), Sheet 20. Insel 24 (Notch-Form, `Radius.island`).
- Ein Schatten: Insel offen, Schwarz 32 %, Radius 20, y 8.
- Karten in der Insel tragen eine 1-pt-Haarlinie, oben 10 %, unten 2 %. Nicht in «Liquid Glass» und nicht bei «Kontrast erhöhen».

## Bewegung

Quelle der Wahrheit ist `Motion` in `Tokens.swift`. Brandguide 12 nennt Dauern von 120 bis 400 ms und die Kurve (0,2 ; 0 ; 0 ; 1); der Code folgt weiterhin den Werten unten. Angleichen ist offen.

- Insel öffnen: Feder (response 0.3, damping 0.84). Schliessen schneller: response 0.18, damping 1.0.
- Kleine Zustände (Hover, Zähler): easeOut 0.14 s. Ein-/Ausblenden: easeInOut 0.24 s.
- Inhalt der Insel: ein 0.18 s nach 0.06 s, aus 0.08 s. Panels: ein 0.18 s, aus 0.14 s.
- Knöpfe: gedrückt 0.97 und etwas dunkler, 0.1 s; bei «Bewegung reduzieren» nur dunkler.
- Alles über `Motion.respecting(_:)`: bei «Bewegung reduzieren» ohne Animation. Keine Daueranimation ausser dem Puls «Claude arbeitet» und dem Equalizer; beide stehen bei «Bewegung reduzieren» still.

## Interaktionszustände

Hover hebt Karten von 55 % auf 85 % Graphit; Primär = Puls-Fläche mit Off-White-Text, Warm = Puls, Gefahr = Puls 35 %. Tastatur: ⌘↩ = Erlauben (nie ↩ allein), Esc = Ablehnen in der Berechtigungskarte.

## Layout-Metriken

Insel offen so gross wie ihr Inhalt: Seiten 648 pt breit, eine einzelne Karte 520 pt; Höhe nach Inhalt (max. 520). Kachel 152 × 128, breite Kachel 312, Heute-Karte 152 × 148. Das Band neben dem Notch ist so hoch wie der Notch (mindestens 32). Rand-Regler: Lasche 6 × 132, Panel 300 breit.

## Seiten-Tabs der Insel

`IslandPageTabs` sitzen im Band links neben dem Notch, rechts davon Datum und Einstellungen. Je Seite ein Symbol, die gewählte Seite als Pille mit Namen (hell: Kartenfarbe, dunkel und Glas: Hover-Ton); ist das Band zu schmal, nur Symbole. ⌘1–⌘6 wählen die Seite, Esc schliesst die Insel.

## Öffnen mit der Maus

Die Insel öffnet erst, wenn der Zeiger ganz oben am Bildschirmrand im Notch liegt (oberste 12 pt, `NotchGeometry.isOnTopEdge`) und dort 40 ms bleibt. Dateien an den Notch ziehen öffnet wie bisher.

## Icon und Marke

- App-Icon (`Icon/AppIcon.icon`, Master `Assets/full.svg`, Brandguide 10): Ebenen 1 Hintergrund (Verlauf Himmel #CFE1F4 nach Pfirsich #FFD9C8), 2 Glow (Puls, oben rechts, weich), 3 Glasebene (Schimmer nur auf der Linie), 4 Symbol (Pulslinie Graphite #2A2C2C nach Black #090A0A, Strich 100 px, runde Enden, 80 % Breite), 5 Glanz (oben, bis 38 % Weiss). Vollflächig, ohne Maske, ohne Text. macOS ergänzt Glas, Schatten und Maske. Resources (`Assets.car`, `AppIcon.icns`) entstehen mit `tools/make_icon.sh` (`build.sh` ruft es auf).
- Menüleiste: `VibrantMark` zeichnet dieselbe Pulslinie als Vorlagenbild.
- Das ARJO-LAB-Logo ist nie das App-Icon. Es erscheint nur in der Absenderzeile.
- Wortmarke: `Wordmark` zeichnet «Vibrant» in Geist Medium aus `Design/Wortmarke/Vibrant-Plus_Wortmarke_*_v1.svg` (Pfade unverändert) und das «+» in Puls, runde Enden, um -8° gekippt, oben bündig mit der Versalhöhe (Strich 92 / 1000 em). Das «+» ist eine eigene Form und nimmt den Akzent.
- Absenderzeile: «Ein Produkt von ARJO LAB» in Über und Einstellungen.
