# Mitwirken an Vibrant+

Danke für dein Interesse. Vibrant+ steht unter **GPL-3.0-or-later**.

## Ablauf

1. Issue eröffnen oder vorhandenes kommentieren.
2. Fork / Branch von `main`.
3. Kleine, nachvollziehbare Commits (Deutsch oder Englisch).
4. `swift test --scratch-path ~/Library/Developer/VibrantPlus/test-build` und bei App-Änderungen `./build.sh`.
5. Pull Request gegen `main`.

## Code

- Swift 6, MainActor-Standard in der App, Kit ohne SwiftUI.
- Design nur über `DesignSystem/Tokens.swift`.
- Keine Drittanbieter-Swift-Pakete.
- Prozesse nur mit festem Pfad und Argument-Array (Ausnahme: `AppRelaunch`).
- SPDX-Header in neuen Quelldateien beibehalten.

## Lizenz der Beiträge

Mit dem Einreichen eines Pull Requests lizenzierst du deinen Beitrag unter derselben GPL-3.0-or-later. (DCO oder CLA kann später ergänzt werden.)

## Marke

Der Name «Vibrant+», Logo und Icon sind Marken von ARJO LAB. Die GPL gilt für den Code, nicht für die Marke.
