// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import VibrantPlusKit
import SwiftUI

/// The Vibrant+ menu in the menu bar.
struct MenuBarContent: View {
    @State private var prefs = Prefs.shared
    private var updater = AppUpdater.shared
    private var agent = AgentStore.shared
    private var dev = DevStatus.shared
    private var today = TodayStore.shared

    var body: some View {
        if !prefs.onboarded {
            Button("Vibrant+ einrichten…") { Windows.show(.welcome) }
        } else {
            tools
        }
        Divider()
        if case .available(let version) = updater.status {
            Button("Vibrant+ \(version) laden…") { AppActions.openSettings(.about) }
        }
        Button("Funktionen verwalten…") { AppActions.openSettings(.features) }
        Button("Einstellungen…") { AppActions.openSettings() }
            .keyboardShortcut(",")
        Button("Über Vibrant+") {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(options: [.credits: NSAttributedString(string: "ARJO LAB")])
        }
        Divider()
        Button("Vibrant+ beenden") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }

    @ViewBuilder private var tools: some View {
        if prefs.isOn(.agent) {
            Text(agentLine)
            Button("Claude-Code-Panel…") { AppActions.openAgentPanel() }
                .keyboardShortcut("k", modifiers: [.command, .option])
            Divider()
        }
        if prefs.isOn(.devBar) {
            if let p = dev.project {
                Label("\(p)\(dev.branch.map { " · \($0)" } ?? "")", systemImage: "arrow.triangle.branch")
            }
            if dev.servers.isEmpty {
                Text("Keine Server laufen")
            } else {
                Menu("Server (\(dev.servers.count))") {
                    ForEach(dev.servers) { s in
                        Button("localhost:\(s.port) · \(s.command)") { dev.open(s) }
                    }
                }
            }
            Divider()
        }
        if prefs.isOn(.island) {
            Button("Insel öffnen") {
                withAnimation(Motion.respecting(Motion.island)) { IslandController.shared.open() }
            }
        }
        if prefs.isOn(.today) {
            Button("Heute…") { AppActions.openToday() }
                .keyboardShortcut("t", modifiers: [.command, .option])
            Button(today.focusRunning ? "Fokus pausieren" : "Fokus starten") {
                today.focusRunning ? today.pauseFocus() : today.startFocus()
            }
        }
        if prefs.isOn(.rowline) {
            Menu("Rowline") {
                Button("Fenster in eine Reihe") { WindowManager.shared.arrangeRow() }
                Button("Fenster im Raster") { WindowManager.shared.arrangeGrid() }
                Button("Fenster gestapelt") { WindowManager.shared.arrangeStack() }
                if !WindowManager.shared.layouts.isEmpty {
                    Divider()
                    ForEach(WindowManager.shared.layouts) { l in
                        Button("Anordnung «\(l.name)»") { WindowManager.shared.restore(l) }
                    }
                }
            }
        }
        if prefs.isOn(.appGrid) {
            Button("App-Raster") { AppGridController.shared.open() }
        }
        if prefs.isOn(.screenshots) {
            Menu("Bildschirmfoto") {
                ForEach(CaptureMode.allCases, id: \.self) { mode in
                    Button(mode.title) { Task { await ScreenCapture.shared.capture(mode) } }
                }
            }
        }
        if prefs.isOn(.screenshots) {
            Button(ScreenRecorder.shared.isRecording ? "Bildschirmaufnahme beenden" : "Bildschirm aufnehmen") { ScreenRecorder.shared.toggle() }
        }
        Toggle("Mac wach halten", isOn: Binding(get: { SystemControls.shared.keepAwake }, set: { SystemControls.shared.setKeepAwake($0) }))
        if prefs.isOn(.downloads) {
            Menu("Herunterladen") {
                ForEach(DownloadFormat.allCases, id: \.self) { f in
                    Button("\(f.title) aus kopiertem Link") { Downloads.shared.startFromClipboard(f) }
                }
                Divider()
                if prefs.isOn(.island) {
                    Button("Seite «Laden» öffnen") {
                        withAnimation(Motion.respecting(Motion.island)) { IslandController.shared.open(page: .downloads) }
                    }
                }
                Button("Download-Ordner zeigen") { NSWorkspace.shared.open(Downloads.shared.folder) }
            }
        }
        if prefs.isOn(.clipboard) || (prefs.isOn(.island) && prefs.tilesOn.contains(.clipboard)) {
            Button("Zwischenablage…") { Windows.show(.clipboard) }
        }
        if prefs.isOn(.links) {
            Menu("Links bereinigen") {
                Button("Kopierten Link bereinigen") { LinkActions.cleanClipboard() }
                Button("Link prüfen…") { AppActions.openSettings(.links) }
            }
        }
        if prefs.isOn(.windowTools) { Button("Fensterwechsler…") { WindowTools.shared.openSwitcher() } }
        if prefs.isOn(.quickTools) {
            Menu("Schnellwerkzeuge") {
                Button("Befehlsleiste…") { QuickToolsController.shared.open(.command) }
                Button("Palette am Zeiger…") { QuickToolsController.shared.open(.palette) }
                Button("Radialmenü…") { QuickToolsController.shared.open(.radial) }
            }
        }
        if prefs.isOn(.cleaning) { Button("Tastatur reinigen…") { AppActions.openSettings(.cleaning) } }
        if prefs.isOn(.ocr) {
            Button("Text aus Bildschirmbereich…") { AppActions.openSettings(.ocr); TextRecognition.shared.captureArea() }
        }
        if prefs.isOn(.island) {
            Button("Ablage am Zeiger…") { ShelfPalette.shared.toggle() }
            Button("Kamera-Spiegel…") { Windows.show(.camera) }
        }
        if prefs.isOn(.scratchpad) { Button("Notizblock…") { Windows.show(.scratchpad) } }
        if prefs.isOn(.audioDevices) { Button("Audiogeräte…") { AppActions.openSettings(.audioDevices) } }
        if prefs.isOn(.processes) { Button("Prozesse und Ports…") { AppActions.openSettings(.processes) } }
        Menu("Werkzeug-Einstellungen") {
            ForEach(Module.allCases.filter { prefs.isOn($0) }) { module in
                Button(module.title + "…") { AppActions.openSettings(module.settingsPage) }
            }
        }
    }

    private var agentLine: String {
        let s = agent.sortedSessions
        if !agent.hooksInstalled { return "Claude Code: nicht verbunden" }
        if agent.hooksOutdated { return "Claude Code: Verbindung veraltet" }
        if s.isEmpty { return "Claude Code: keine Sitzung" }
        let waiting = s.filter { $0.status == .needsPermission || $0.status == .asking }.count
        return waiting > 0 ? "Claude Code: \(waiting) wartet auf dich" : "Claude Code: \(s.count) Sitzung\(s.count == 1 ? "" : "en")"
    }
}
