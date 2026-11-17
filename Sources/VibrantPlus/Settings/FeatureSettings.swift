// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct FeatureSettings: View {
    @State private var prefs = Prefs.shared
    @State private var query = ""
    @State private var activeOnly = false
    @State private var previous: Set<Module>?

    private var modules: [Module] {
        Module.allCases.filter { $0.matches(query) && (!activeOnly || prefs.isOn($0)) }
    }

    var body: some View {
        Section {
            TextField("Funktionen suchen", text: $query)
            Toggle("Nur eingeschaltete Funktionen", isOn: $activeOnly)
            Text("\(prefs.modules.count) von \(Module.allCases.count) Modulen eingeschaltet")
                .font(.caption).foregroundStyle(.secondary)
        }
        if query.isEmpty && !activeOnly {
            Section {
                ForEach(ModuleProfile.allCases) { profile in
                    Button {
                        previous = prefs.modules
                        prefs.modules = profile.modules
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text(profile.title).foregroundStyle(Color.primary)
                                Text(profile.detail).font(.caption).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            if prefs.modules == profile.modules { Image(systemName: "checkmark.circle.fill") }
                        }
                    }
                }
                if let previous {
                    Button("Profilwechsel rückgängig machen") { prefs.modules = previous; self.previous = nil }
                }
            } header: { Text("Profile") }
              footer: { Text("Ein Profil ersetzt die Modulauswahl. Kacheln, Farben und persönliche Einstellungen bleiben erhalten.") }
        }
        if modules.isEmpty {
            ContentUnavailableView("Keine passenden Funktionen", systemImage: "magnifyingglass", description: Text("Ändere den Suchbegriff oder den Filter."))
        }
        ForEach(Module.Group.allCases, id: \.self) { group in
            let items = modules.filter { $0.group == group }
            if !items.isEmpty {
                Section(group.rawValue) {
                    ForEach(items) { module in
                        VStack(alignment: .leading, spacing: Space.sm) {
                            Toggle(isOn: Binding(get: { prefs.isOn(module) }, set: { prefs.set(module, $0) })) {
                                Label { Text(module.title); Text(module.subtitle) } icon: {
                                    Image(systemName: module.symbol).frame(width: 24)
                                }
                            }
                            Button("\(module.title) konfigurieren…") { AppActions.openSettings(module.settingsPage) }
                                .font(.caption)
                        }
                    }
                }
            }
        }
        Section {
            Text("Ausgeschaltete Module stoppen ihre Dienste und verschwinden aus dem Menü. Ihre Einstellungen bleiben für später gespeichert. Die Zwischenablage-Kachel kann den Verlauf ebenfalls einschalten.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct ClipboardSettings: View {
    @State private var prefs = Prefs.shared
    var body: some View {
        Section("Systemzwischenablage automatisch leeren") {
            Picker("Nach", selection: $prefs.clipboardClearAfter) {
                Text("Nie").tag(0.0)
                Text("30 Sekunden").tag(30.0)
                Text("1 Minute").tag(60.0)
                Text("5 Minuten").tag(300.0)
                Text("15 Minuten").tag(900.0)
            }
            Toggle("Vor dem Ruhezustand leeren", isOn: $prefs.clipboardClearOnSleep)
            Toggle("Ausgewählten Eintrag direkt in die vordere App einfügen", isOn: $prefs.clipboardDirectPaste)
            Text("Gespeicherter Verlauf und angeheftete Texte bleiben erhalten. Dateien aus der Zwischenablage erscheinen als Pfade. Diese Regeln laufen nur, solange das Zwischenablage-Modul oder die entsprechende Insel-Kachel eingeschaltet ist. Direktes Einfügen sendet ⌘V an die vordere App.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Verlauf") {
            Button("Zwischenablage öffnen…") { Windows.show(.clipboard) }
                .disabled(!prefs.isOn(.clipboard))
            Text("Texte, Bilder und Dateipfade suchen, Texte anheften und Einträge kopieren oder einfügen. Der Verlauf läuft auch ohne Insel. Als vertraulich markierte Inhalte werden übersprungen. Nur angeheftete Texte werden auf dem Mac gespeichert.")
                .foregroundStyle(.secondary)
            if prefs.isOn(.island) && prefs.tilesOn.contains(.clipboard) {
                Text("Auch die eingeschaltete Zwischenablage-Kachel der Insel nutzt diesen Verlauf.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct AppGridSettings: View {
    @State private var prefs = Prefs.shared
    var body: some View {
        Section("Apps") {
            Button("App-Raster öffnen") { AppGridController.shared.open() }.disabled(!prefs.isOn(.appGrid))
            Text("Öffne installierte Apps im Vollbild. Den Kurzbefehl kannst du unter Kurzbefehle ändern.").foregroundStyle(.secondary)
        }
    }
}

struct DevBarSettings: View {
    @State private var prefs = Prefs.shared
    var body: some View {
        Section("Projekt") {
            TextField("Lokaler Projektordner", text: Binding(get: { prefs.devProject ?? "" }, set: { prefs.devProject = $0.isEmpty ? nil : $0 }))
            Text("Die Menüleiste zeigt den Git-Branch dieses Ordners und laufende lokale Entwicklungsserver.").foregroundStyle(.secondary)
        }
    }
}
