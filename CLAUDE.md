# Vibrant+

Native macOS-Menüleisten-App (SwiftUI + AppKit, Swift 6, macOS 26, arm64) von ARJO LAB. Keine Drittanbieter-Swift-Pakete. Oberflächensprache Deutsch (Schweizer Rechtschreibung, kein ß). Lizenz: GPL-3.0-or-later.

## Aufbau

- `Sources/VibrantPlusKit/` reine Logik, getestet in `Tests/VibrantPlusKitTests/`.
- `Sources/VibrantPlus/` die App (XcodeGen / `./build.sh`), Standard-Isolation MainActor. Siehe `ARCHITECTURE.md`.
- Design Tokens nur aus `DesignSystem/Tokens.swift`.

## Bauen und prüfen

- `./build.sh` (Release → `/Applications/Vibrant+.app`), `--debug` für Selbsttest/Snapshots, `--open` startet neu.
- `swift test --scratch-path ~/Library/Developer/VibrantPlus/test-build`
- `tools/selftest.sh` — Debug-Build, Prüfungen gegen /tmp.
- `tools/snap.sh` — PNGs nach /tmp/VibrantPlus-shots.
- Nie gegen den echten Datenordner oder die echte `~/.claude/settings.json` testen (`APP_DATA`, `APP_CLAUDE_SETTINGS`).

## Regeln

- Fenster/Panels mit SwiftUI-Inhalt nie während eines SwiftUI-Layout-Durchlaufs verschieben; `NSHostingView` in Panels mit `sizingOptions = []`.
- Keine privaten APIs. Prozesse nur mit festem Pfad und Argument-Array. Ausnahme: `AppRelaunch` (`Core/System.swift`).
- Module starten nur eingeschaltet; Berechtigungen erst bei Bedarf.
- Release: `SIGN_IDENTITY` und `NOTARY_PROFILE` setzen, dann `tools/release.sh`.

## Releases

- `tools/release.sh` baut, signiert, notarisiert und legt das ZIP ab (`PROJEKTELAB_RELEASES` überschreibbar).
- GitHub Release im selben Repo (`GITHUB_RELEASES_REPO`, Standard `ArijanVr/VibrantPlus`).
- Nichts pushen ohne ausdrücklichen Auftrag.
