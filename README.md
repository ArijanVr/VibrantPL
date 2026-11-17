# Vibrant+

Native macOS-Menüleisten-App von ARJO LAB. Der Notch wird zur Insel: Musik, Termine, Wetter, Aufgaben, Claude Code live mit Berechtigungen, Dateiumwandlung (Stow), Fensterreihen (Rowline), Lautstärke pro App am Bildschirmrand, Diktieren per Stimme, App-Raster und Tastengeräusche.

Vibrant+ ist freie Software unter der **GNU General Public License, Version 3 oder (nach deiner Wahl) jeder späteren Version**. Siehe `LICENSE` und `NOTICE`.

**Version 1.0.0** — frischer Start im Repo VibrantPL (Auto-Updates zeigen hierher). Sie ersetzt frühere interne Stände (1.0.x / 3.x). **Neuinstallation nötig** — kein automatisches Update ältere interne Builds (kleinere Versionsnummer). Bundle-ID bleibt `ch.arjo.vibrantplus`; lokale Daten bleiben erhalten, Berechtigungen können erneut nötig sein.

Der Name «Vibrant+», Logo und Icon sind Marken von ARJO LAB und nicht durch die GPL abgedeckt.

## Voraussetzungen

- macOS 26 (Tahoe) oder neuer, Apple silicon
- Zum Bauen: Xcode 26+ (getestet mit Xcode 27.2, Swift 6.4) und XcodeGen (`brew install xcodegen`)
- Optional: Claude Code, `yt-dlp`, `ffmpeg`, Homebrew (nicht mitgeliefert)

## Bauen und starten

```bash
./build.sh --open
```

Release-Build, Signatur, Installation nach `/Applications/Vibrant+.app`. Kein Dock-Symbol — Symbol in der Menüleiste.

```bash
swift test --scratch-path ~/Library/Developer/VibrantPlus/test-build
tools/selftest.sh   # Debug-Build + Selbsttest gegen /tmp
```

## Von 1.0.x umsteigen

1. Vibrant+ beenden.
2. `/Applications/Vibrant+.app` durch dieses Release ersetzen (Installer-ZIP oder `./build.sh`).
3. Starten; bei Bedarf Berechtigungen erneut erlauben.

## Kurzbedienung

| Was | Wie |
|---|---|
| Insel öffnen | Maus auf den Notch, oder ⌃⌥⌘I |
| Datei umwandeln | Datei auf den Notch ziehen |
| Claude Code | Einstellungen › Claude Code › verbinden |
| Rowline | ⌃⌥⌘F und Nachbartasten (siehe Einstellungen › Kurzbefehle) |
| Diktieren | ⌃⌥ bzw. ⌃⌘ halten und sprechen |

## Datenschutz und Netzwerk

Daten liegen lokal unter `~/Library/Application Support/VibrantPlus/`. Keine Konten, keine Analyse, keine Telemetrie.

Ins Netz (HTTPS) gehen nur, wenn du die jeweilige Funktion nutzt:

- Wetter: Open-Meteo (Stadtname)
- Spotify-Cover: Cover-URL
- Umrechner: frankfurter.dev (Kurse, kein Betrag)
- Liedtexte: LRCLIB
- Optionale Downloads: Ziele, die du angibst (`yt-dlp`)
- Optional Updates: GitHub Releases dieses Repos (Schalter standardmässig aus)

## Dokumentation

- `ARCHITECTURE.md` — Aufbau
- `CONTRIBUTING.md` — Mitwirken
- `SECURITY.md` — Sicherheitslücken melden
- `CHANGELOG.md` — Änderungen
- `docs/DESIGN_SYSTEM.md` — Design-Tokens

## Marke und Inspiration

Funktionskonzepte wurden eigenständig umgesetzt. Kein fremder proprietärer Code und keine fremden Assets.
