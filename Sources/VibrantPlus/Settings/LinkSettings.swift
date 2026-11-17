// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI
import VibrantPlusKit

struct LinkSettings: View {
    @State private var input = ""
    @State private var message: String?
    @State private var prefs = Prefs.shared
    private var cleaned: String? { CleanLink.clean(input) }

    var body: some View {
        Section("Automatik") {
            Toggle("Neu kopierte Weblinks automatisch bereinigen", isOn: $prefs.autoCleanLinks)
                .disabled(!prefs.isOn(.links))
            Text("Nur vollständige Weblinks. Als vertraulich oder temporär markierte Zwischenablagen werden übersprungen.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Weblink") {
            TextField("https://…", text: $input, axis: .vertical)
                .lineLimit(2...5)
            Button("Aus Zwischenablage übernehmen") {
                input = NSPasteboard.general.string(forType: .string) ?? ""
                message = nil
            }.disabled(!prefs.isOn(.links))
            if let cleaned {
                Text(cleaned).textSelection(.enabled)
                Button("Bereinigten Link kopieren") {
                    LinkActions.copy(cleaned)
                    message = cleaned == input.trimmingCharacters(in: .whitespacesAndNewlines) ? "Link kopiert; keine entfernbaren Tracking-Parameter." : "Bereinigter Link kopiert."
                }.disabled(!prefs.isOn(.links))
            } else if !input.isEmpty {
                Text("Gib einen vollständigen HTTP- oder HTTPS-Link ohne Zugangsdaten ein.").foregroundStyle(.secondary)
            }
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
        }
        Section("Lokal und auf Wunsch") {
            Text("Entfernt bekannte Tracking-Parameter wie utm_source, fbclid und gclid. Der Link wird nicht aufgerufen. Funktionale Parameter, Fragmente und signierte Links bleiben erhalten. Kurzlinks werden nicht aufgelöst.")
                .foregroundStyle(.secondary)
        }
    }
}

enum LinkActions {
    static func cleanClipboard() {
        guard Prefs.shared.isOn(.links), let input = NSPasteboard.general.string(forType: .string),
              let cleaned = CleanLink.clean(input) else {
            AppActions.openSettings(.links)
            return
        }
        copy(cleaned)
        IslandModel.shared.show(Toast(symbol: "link", text: cleaned == input ? "Link enthält keine entfernbaren Tracking-Parameter" : "Bereinigter Link kopiert"), seconds: 4)
    }

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
