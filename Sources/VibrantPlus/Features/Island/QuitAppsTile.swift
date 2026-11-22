// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// Island tile «Apps beenden»: every open app with «Beenden» (the app may ask to save)
/// and «Sofort» (force quit: unsaved work is lost).
struct QuitAppsTile: View {
    @State private var apps = QuitAppsTile.running()

    private static func running() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated
                && $0.bundleIdentifier != Bundle.main.bundleIdentifier && $0.bundleIdentifier != "com.apple.finder" }
            .sorted { ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }
    }

    var body: some View {
        IslandCard(width: Metrics.wideTileWidth - 64) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack {
                    CardHeader(title: "Apps beenden", symbol: "xmark.app")
                    Spacer()
                    if !apps.isEmpty {
                        Button("Andere") {
                            let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
                            for app in apps where app.processIdentifier != front { app.terminate() }
                        }
                        .buttonStyle(.plain).font(TypeStyle.islandLabel).foregroundStyle(IslandColor.accentText)
                        .help("Beendet alle aufgelisteten Apps ausser der vorderen.")
                    }
                }
                if apps.isEmpty {
                    Text("Keine App offen.").font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: Space.xs) {
                            ForEach(apps, id: \.processIdentifier) { app in row(app) }
                        }
                        .padding(.bottom, Space.lg)
                    }
                    // A list that goes on fades out instead of ending in half a row.
                    .mask {
                        VStack(spacing: 0) {
                            Color.black
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: Space.lg)
                        }
                    }
                }
            }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in apps = Self.running() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in apps = Self.running() }
    }

    /// Force quit loses unsaved work, so it asks first.
    private func confirmForceQuit(_ app: NSRunningApplication, _ name: String) {
        let alert = NSAlert()
        alert.messageText = "\(name) sofort beenden?"
        alert.informativeText = "Nicht gesicherte Änderungen gehen verloren."
        alert.addButton(withTitle: "Sofort beenden")
        alert.addButton(withTitle: "Abbrechen")
        alert.buttons.first?.hasDestructiveAction = true
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn { app.forceTerminate() }
    }

    private func row(_ app: NSRunningApplication) -> some View {
        let name = app.localizedName ?? "App"
        return HStack(spacing: Space.sm) {
            Image(nsImage: app.icon ?? NSImage()).resizable().frame(width: 20, height: 20)
            Text(name).font(TypeStyle.islandBody).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            IslandIconButton(symbol: "xmark", label: "\(name) beenden", size: 22) { app.terminate() }
            IslandIconButton(symbol: "bolt.fill", label: "\(name) sofort beenden", size: 22) { confirmForceQuit(app, name) }
        }
        .help("\(name): × beendet, Blitz erzwingt das Beenden (nicht Gesichertes geht verloren)")
    }
}
