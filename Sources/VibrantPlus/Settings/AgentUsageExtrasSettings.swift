// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Observation
import SwiftUI
import VibrantPlusKit

@Observable
final class AgentUsageExtrasPreferences {
    static let shared = AgentUsageExtrasPreferences()
    @ObservationIgnored private let defaults: UserDefaults = Paths.isOverridden
        ? UserDefaults(suiteName: "ch.arjo.vibrantplus.test.usageExtras." + Paths.dataDirectory.lastPathComponent)!
        : .standard
    var copilotEnabled: Bool { didSet { defaults.set(copilotEnabled, forKey: "usage.copilot") } }
    var codexHomes: [CodexHome] { didSet { defaults.set(try? JSONEncoder().encode(codexHomes), forKey: "usage.codexHomes") } }
    private init() {
        copilotEnabled = defaults.bool(forKey: "usage.copilot")
        codexHomes = defaults.data(forKey: "usage.codexHomes").flatMap { try? JSONDecoder().decode([CodexHome].self, from: $0) } ?? []
    }
}

struct AgentUsageExtrasSettings: View {
    @State private var prefs = AgentUsageExtrasPreferences.shared
    @State private var name = ""
    @State private var message: String?
    @State private var usage = UsageStore.shared

    var body: some View {
        Section("GitHub Copilot") {
            Toggle("Lokale Copilot-Sitzungen auswerten", isOn: $prefs.copilotEnabled)
                .onChange(of: prefs.copilotEnabled) { usage.refresh() }
            Text("Liest ausschliesslich Ereignisse unter ~/.copilot/session-state. Token stehen erst fest, wenn Copilot seine kumulierten Modellmetriken schreibt, normalerweise beim Sitzungsende. Keine Anmeldung, keine Zugangstoken und keine Netzabfrage; das ist kein Nachweis des verbleibenden Copilot-Kontingents.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section {
            LabeledContent("Standard", value: "~/.codex")
            ForEach(prefs.codexHomes) { root in
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack {
                        Text(root.label); Spacer()
                        Button("Entfernen") { prefs.codexHomes.removeAll { $0.id == root.id }; usage.refresh() }
                    }
                    Text(root.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            TextField("Eindeutiger Kontoname", text: $name)
            Button("Codex-Datenordner hinzufügen…") { addHome() }
            if let message { Text(message).foregroundStyle(.secondary) }
        } header: { Text("Weitere CODEX_HOME-Ordner") }
          footer: { Text("Wähle den gewünschten CODEX_HOME-Ordner oder direkt dessen sessions-Ordner. Nur die Sitzungsdateien werden gelesen, keine auth.json. Derselbe kanonische Ordner wird nicht doppelt gezählt. Ein gesetztes CODEX_HOME der App wird ebenfalls berücksichtigt.") }
        if !usage.report.quotas.isEmpty {
            Section("Lokal gemeldete Codex-Limits") {
                ForEach(usage.report.quotas) { quota in
                    VStack(alignment: .leading, spacing: Space.xs) {
                        LabeledContent("\(quota.account ?? "Standard") · \(quota.window)", value: quota.usedPercent.formatted(.number.precision(.fractionLength(0))) + " %")
                        if let resets = quota.resets { Text("Zurücksetzung: \(resets.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                Text("Die Werte stammen aus dem jeweils neuesten lokalen Codex-Ereignis und können veraltet sein. Vibrant+ ruft keine Kontoseite ab und löst keinen Kontingent-Reset aus.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func addHome() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.message = "CODEX_HOME oder sessions wählen; Zugangsdaten werden nicht gelesen."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let sessions = url.lastPathComponent == "sessions" ? url : url.appending(path: "sessions")
        var directory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: sessions.path, isDirectory: &directory), directory.boolValue else {
            message = "Dieser Ordner enthält keinen sessions-Ordner."; return
        }
        let canonical = sessions.standardizedFileURL.resolvingSymlinksInPath()
        let existing = CodexHomes.resolved(home: FileManager.default.homeDirectoryForCurrentUser,
                                          environmentHome: ProcessInfo.processInfo.environment["CODEX_HOME"], additional: prefs.codexHomes)
        guard !existing.contains(where: { $0.sessions.path == canonical.path }) else { message = "Dieser Datenordner ist bereits enthalten."; return }
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, label != "Standard", !prefs.codexHomes.contains(where: { $0.label == label }) else {
            message = "Gib einen eindeutigen Kontonamen ein."; return
        }
        prefs.codexHomes.append(CodexHome(label: String(label.prefix(60)), path: url.path))
        name = ""; message = nil; usage.refresh()
    }
}
