// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Observation
import VibrantPlusKit

@Observable
final class ProcessTools {
    static let shared = ProcessTools()
    private(set) var apps: [NSRunningApplication] = []
    private(set) var ports: [ListeningPorts.Server] = []
    private(set) var message: String?
    private(set) var working = false
    func refresh() {
        apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        Task {
            let result = await Run.async("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"], timeout: 5)
            ports = ListeningPorts.parse(result.output)
        }
    }
    func quit(_ app: NSRunningApplication, force: Bool = false) {
        let alert = NSAlert()
        alert.messageText = force ? "«\(app.localizedName ?? "App")» sofort beenden?" : "«\(app.localizedName ?? "App")» beenden?"
        alert.informativeText = force ? "Nicht gespeicherte Änderungen können verloren gehen." : "Die App kann dich vor dem Beenden nach ungespeicherten Dokumenten fragen."
        alert.addButton(withTitle: force ? "Sofort beenden" : "Beenden"); alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let accepted = force ? app.forceTerminate() : app.terminate()
        message = accepted ? "Beenden angefordert." : "Die App konnte nicht beendet werden."
        refresh()
    }
    func terminatePort(_ server: ListeningPorts.Server) {
        let alert = NSAlert()
        alert.messageText = "Server auf Port \(server.port) beenden?"
        alert.informativeText = "\(server.command), Prozess \(server.pid). Es wird SIGTERM gesendet."
        alert.addButton(withTitle: "Server beenden"); alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task {
            // Re-read before signalling: a stale row must not target a recycled process ID.
            let result = await Run.async("/usr/sbin/lsof", ["-nP", "-a", "-p", String(server.pid), "-iTCP:\(server.port)", "-sTCP:LISTEN", "-Fpcn"], timeout: 5)
            guard ListeningPorts.parse(result.output).contains(where: { $0.pid == server.pid && $0.port == server.port && $0.command == server.command }) else {
                message = "Dieser Server läuft nicht mehr unverändert. Bitte aktualisieren."; return
            }
            let resultKill = await Run.async("/bin/kill", ["-TERM", String(server.pid)])
            message = resultKill.status == 0 ? "Beenden angefordert." : "Der Server konnte nicht beendet werden."
            refresh()
        }
    }
}
