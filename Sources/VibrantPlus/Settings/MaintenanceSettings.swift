// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

struct CleanerSettings: View {
    var enabled = true
    @State private var store = CleanerStore.shared
    var body: some View {
        Section("Caches und Logs") {
            Stepper("Älter als \(store.olderThanDays) Tage", value: $store.olderThanDays, in: 1...365)
            Button("Alte Ordner suchen") { store.scan() }.disabled(store.busy)
            if store.busy { ProgressView("Arbeitet…") }
            if let message = store.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            Text("Nur vollständig lesbare Unterordner deiner Library/Caches und Library/Logs. Keine Systemordner, keine symbolischen Links, keine automatische Auswahl.")
                .font(.caption).foregroundStyle(.secondary)
        }.disabled(!enabled)
        if !store.items.isEmpty {
            Section("Gefundene Ordner") {
                ForEach(store.items) { item in
                    Toggle(isOn: Binding(get: { store.selected.contains(item.id) }, set: { on in
                        if on { store.selected.insert(item.id) } else { store.selected.remove(item.id) }
                    })) {
                        Text(item.url.lastPathComponent + " · " + item.sizeText)
                        Text(item.url.path).font(.caption)
                    }
                }
                Button("Auswahl in den Papierkorb…") { store.trashSelected() }.disabled(store.selected.isEmpty || store.busy)
            }.disabled(!enabled)
        }
        if !store.trashResults.isEmpty {
            Section { Button("Im Papierkorb zeigen") { store.revealTrash() } }
        }
    }
}

struct UninstallerSettings: View {
    var enabled = true
    @State private var store = UninstallerStore.shared
    var body: some View {
        Section("App prüfen") {
            Button("App auswählen…") { store.chooseApp() }.disabled(store.busy)
            if let app = store.app { Text(app.path).textSelection(.enabled).font(.caption) }
            if let message = store.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            if store.busy { ProgressView("Arbeitet…") }
        }.disabled(!enabled)
        if !store.items.isEmpty {
            Section {
                ForEach(store.items) { item in
                    Toggle(isOn: Binding(get: { store.selected.contains(item.id) }, set: { on in
                        if on { store.selected.insert(item.id) } else { store.selected.remove(item.id) }
                    })) {
                        Text(item.url.lastPathComponent + " · " + item.sizeText + (item.complete ? "" : " (Grösse unvollständig)"))
                        Text(item.url.path).font(.caption)
                    }
                }
                Button("Auswahl in den Papierkorb…") { store.trashSelected() }.disabled(store.selected.isEmpty || store.busy)
            } header: { Text("Einzeln auswählbare Bestandteile") }
              footer: { Text("Keine Vendor-Suche und keine pauschale Löschung von Application Support. Nicht eindeutig zuordenbare Reste bleiben erhalten. Laufende Apps zuerst beenden. Container können persönliche Dokumente enthalten.") }
            .disabled(!enabled)
        }
    }
}

struct HomebrewSettings: View {
    var enabled = true
    @State private var store = HomebrewStore.shared
    var body: some View {
        if store.executable == nil {
            Section {
                Text("Homebrew ist auf diesem Mac nicht installiert. Vibrant+ installiert keinen Paketmanager automatisch.")
                Link("Offizielle Homebrew-Website", destination: URL(string: "https://brew.sh")!)
            }
        } else {
            Section("Pakete") {
                TextField("Paket suchen", text: $store.query).onSubmit { if enabled { store.search() } }
                HStack {
                    Button("Suchen") { store.search() }
                    Button("Installierte laden") { store.loadInstalled() }
                }.disabled(store.busy)
                if store.busy { ProgressView("Homebrew arbeitet…") }
                if let message = store.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            }.disabled(!enabled)
            if !store.searchResults.isEmpty {
                Section("Suchergebnisse") {
                    ForEach(store.searchResults) { package in
                        HStack {
                            Text(package.token).textSelection(.enabled)
                            Text(package.kind == .cask ? "App" : "Formel").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Info") { store.info(package) }
                            Button("Installieren…") { store.change(package, action: "install") }
                        }
                    }
                }.disabled(!enabled || store.busy)
            }
            if !store.installed.isEmpty {
                Section("Installiert") {
                    ForEach(store.installed) { package in
                        HStack {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text(package.name)
                                Text(package.installed).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Info") { store.info(package) }
                            Button("Entfernen…") { store.change(package, action: "uninstall") }
                        }
                    }
                }.disabled(!enabled || store.busy)
            }
            BrewLogView(log: store.log)
        }
    }
}

struct AppUpdateSettings: View {
    var enabled = true
    @State private var store = HomebrewStore.shared
    var body: some View {
        Section("Updates") {
            Button("Homebrew-Updates prüfen") { store.checkUpdates() }.disabled(store.busy || store.executable == nil)
            Link("App-Store-Updates öffnen", destination: URL(string: "macappstore://showUpdatesPage")!)
            Text("Homebrew-Pakete lassen sich hier aktualisieren. Updates aus dem App Store führt der App Store aus. Für andere Apps den integrierten Hersteller-Updater verwenden; Vibrant+ führt keine unbekannten Feed-Skripte aus.")
                .font(.caption).foregroundStyle(.secondary)
            if store.busy { ProgressView("Homebrew arbeitet…") }
            if let message = store.message { Text(message).font(.caption).foregroundStyle(.secondary) }
        }.disabled(!enabled)
        if !store.outdated.isEmpty {
            Section("Verfügbare Homebrew-Updates") {
                ForEach(store.outdated) { package in
                    HStack {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text(package.name)
                            Text(package.installed + " → " + (package.available ?? "neu")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Aktualisieren…") { store.change(package, action: "upgrade") }
                    }
                }
                Button("Alle angezeigten aktualisieren…") { store.upgradeListed() }
            }.disabled(!enabled || store.busy)
        }
        BrewLogView(log: store.log)
    }
}

private struct BrewLogView: View {
    let log: String
    var body: some View {
        if !log.isEmpty {
            Section("Protokoll") {
                Text(log).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            }
        }
    }
}

struct DiskInstallerSettings: View {
    var enabled = true
    @State private var store = DiskImageInstaller.shared
    var body: some View {
        Section("App aus Disk-Image") {
            Toggle("Nur für meinen Benutzer installieren (~/Applications)", isOn: $store.installForCurrentUser)
            Button("Disk-Image auswählen…") { store.chooseDiskImage() }.disabled(store.busy || !store.ownedMounts.isEmpty)
            Text("Das Image wird schreibgeschützt geöffnet. Nur App-Bundles im obersten Ordner werden angeboten. Kein Ausführen von .pkg-Installern oder Skripten, kein Überschreiben vorhandener Apps und kein automatischer Start.")
                .font(.caption).foregroundStyle(.secondary)
            if store.busy { ProgressView("Arbeitet…") }
            if let message = store.message { Text(message).font(.caption).foregroundStyle(.secondary) }
        }.disabled(!enabled)
        if !store.apps.isEmpty {
            Section("Apps im Image") {
                ForEach(store.apps, id: \.path) { app in
                    HStack { Text(app.deletingPathExtension().lastPathComponent); Spacer(); Button("Installieren…") { store.install(app) } }
                }
            }.disabled(!enabled || store.busy)
        }
        if !store.ownedMounts.isEmpty {
            Section { Button("Von Vibrant+ geöffnetes Image auswerfen") { store.eject() }.disabled(store.busy) }
        }
        if store.installedApp != nil {
            Section { Button("Installierte App im Finder zeigen") { store.revealInstalled() } }
        }
    }
}
