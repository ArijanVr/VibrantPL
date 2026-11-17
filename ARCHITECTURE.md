# Architektur

Swift 6.4 (Sprachmodus 6), SwiftUI + AppKit. App-Build über ein mit XcodeGen aus `project.yml` erzeugtes Xcode-Projekt (für App-Intents-Metadaten), Tests über das Swift Package, macOS 26, arm64. Keine Drittanbieter-Abhängigkeiten.

## Ziele

| Ziel | Inhalt |
|---|---|
| `VibrantPlusKit` | Reine Logik ohne UI, voll testbar: Claude-Code-Hook-Protokoll, Sitzungs-Reducer, Zeilen-Diff, settings.json-Merge, Rowline-Geometrie, Heute-Daten + Insights, Aufräumregeln, Meeting-Link-Erkennung, Port-/Git-Parser, Sprachbefehle, JSON-Datei-Speicher |
| `VibrantPlus` | Die App. Standard-Isolation `MainActor`; Hintergrundarbeit explizit `nonisolated` |
| `VibrantPlusKitTests` | Swift Testing, 28 Tests |

## Ordner

```text
Sources/VibrantPlus/
  App/            Entry (@main: --hook / --selftest / --snapshot / App), Coordinator (Module an/aus),
                  Menüleiste, Fenster (AppKit-gehostet), Willkommen
  Core/           Paths, Prefs (UserDefaults, @Observable), HotKeys (Carbon), System (Run, Script, Permission)
  DesignSystem/   Tokens (Farben, Radien, Bewegung, Metriken, Typo), VibrantMark (Logo als Shape)
  Features/
    Island/       IslandController (NSPanel am Notch), IslandRoot, Tiles, NowPlaying, IslandServices
                  (Kalender, Wetter, Systemwerte, Zwischenablage, letzte Apps, Steuerungen, Entwicklerleiste)
    Agent/        AgentSocket (Unix-Socket, HookCLI), AgentStore, AgentPanelView
    Today/        TodayStore (+ QuickTimer, Shelf), TodayView (+ Insights-Chart)
    Stow/         StowEngine (ImageIO, PDFKit, AVFoundation), StowModel, StowPanel, Tidy
    Rowline/      WindowManager (Accessibility-API)
    Mixer/        Audio (Systemlautstärke, Core-Audio-Prozess-Taps), Dial (Rand-Panel)
    Voice/        VoiceController (Speech + AVAudioEngine)
    Keys/         KeyMonitor (Tastengeräusche synthetisch, Tastenanzeige)
    AppGrid/      App-Raster, ThemeController
    Assistant/    Assistant (Foundation Models, Werkzeuge), AssistantCard, SiriIntents (App Intents + App Shortcuts)
  Settings/       Einstellungen mit Seitenleiste (13 Seiten)
  Tests/          SelfTest (--selftest), SnapshotRunner (--snapshot)
  UI/             Vorlage: Akzent-Themes, Raster, Fensterverhalten
```

## Zentrale Abläufe

**Module.** `Prefs.modules` ist die Wahrheit. `Coordinator` beobachtet sie (`withObservationTracking`) und startet bzw. stoppt Dienste. Ein ausgeschaltetes Modul hat keinen Timer, keinen Monitor, keinen Socket.

**Insel.** Ein randloses, nicht-aktivierendes `NSPanel` auf Statusleisten-Ebene, einmal oben mittig platziert und danach nie mehr verschoben oder in der Grösse verändert (AppKit wirft sonst während des Constraint-Durchlaufs eine Ausnahme). Klicks gehen durch, ausser über der offenen Insel (`ignoresMouseEvents` folgt der Mausposition). Öffnen per Hover über dem Notch, per Kurzbefehl, oder wenn etwas Aufmerksamkeit braucht (dann «sticky» bis Klick ausserhalb). Notch-Grösse aus `safeAreaInsets` und `auxiliaryTopLeft/RightArea`; ohne Notch eine Pille in der Menüleiste.

**Claude Code.** `Vibrant+ --hook` ist derselbe Binary im CLI-Modus. Claude Code startet ihn je Ereignis, er liest das JSON von stdin und schickt es als eine Zeile über `~/Library/Application Support/VibrantPlus/agent.sock`. Bei `PermissionRequest` und `AskUserQuestion` wartet er auf die Antwort aus der Insel und druckt sie im offiziellen Hook-Format; ohne laufende App oder ohne Antwort in der Frist druckt er nichts, dann fragt Claude Code wie gewohnt im Terminal. Die App prüft die Benutzer-ID des Gegenübers (`getpeereid`).

**Musik.** Verteilte Benachrichtigungen von Musik/Spotify (kein Polling); AppleScript nur für Steuerung, Cover und einen Start-Abgleich, und nur wenn der Player läuft (sonst würde AppleScript ihn starten).

**Stow.** Synchrone Arbeit in `Task.detached`, Video/Audio mit `AVAssetExportSession.export(to:as:)`. Ziel immer `OutputNaming` → «Name (Tag).ext», nie überschreiben.

**Mixer pro App.** `CATapDescription` (Stereo-Mixdown eines Prozesses, `mutedWhenTapped`) → privates Aggregate-Gerät mit dem Standard-Ausgang → IO-Proc kopiert mit Verstärkung. Nur für Apps unter 100 %.

**Assistent.** `LanguageModelSession` mit Werkzeugen (`Tool`, `@Generable`-Argumente); Werkzeuge springen per `MainActor.run` in die App. Antworten werden gestreamt. Eine Sitzung bleibt 5 Minuten für Folgefragen. Siri-/Kurzbefehl-Aktionen sind `AppIntent`s mit `@MainActor perform()`, die Sätze stehen im `AppShortcutsProvider`.

**Persistenz.** UserDefaults für Einstellungen und Kurzbefehle; JSON-Dateien (`today.json`, `layouts.json`, `tidy-log.json`) atomar geschrieben. Zwischenablage-Verlauf und Agent-Sitzungen nur im Speicher.

## Bewusste Entscheidungen

- Kein SwiftData: drei kleine JSON-Dateien sind einfacher und testbar.
- Kein Sandbox: Rowline (Bedienungshilfen), Unix-Socket, Dateien neben dem Original und `~/.claude/settings.json` wären im Sandbox nicht möglich. Hardened Runtime ist aktiv.
- Kein Sparkle, keine Lizenzprüfung, keine privaten APIs (Helligkeit, Trackpad-Rand, `_AXUIElementGetWindow`). Updates: GitHub Releases von `ArijanVr/VibrantPL` (optional lokaler Ordner über `PROJEKTELAB_RELEASES`), Schalter standardmässig aus.
- Fenster sind AppKit-`NSWindow` mit SwiftUI-Inhalt, weil eine Menüleisten-App ohne Dock-Symbol SwiftUI-Szenen nicht zuverlässig aus AppKit-Code öffnen kann.
