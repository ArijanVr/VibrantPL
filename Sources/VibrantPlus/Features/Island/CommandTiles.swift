// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI
import VibrantPlusKit

/// Befehle: shell commands the person saved. Each runs only when its button is pressed, never by itself,
/// with a 60 second limit; the island shows the exit state, the time and the last line of output.
struct CommandsTile: View {
    private var prefs = Prefs.shared
    @State private var draft = ""
    @State private var running: String?
    @State private var result: (command: String, ok: Bool, seconds: Double, line: String)?

    var body: some View {
        IslandCard(width: Metrics.wideTileWidth - 64) {
            VStack(alignment: .leading, spacing: Space.xs) {
                CardHeader(title: "Befehle", symbol: "terminal")
                if prefs.savedCommands.isEmpty {
                    Text("Eigene Befehle speichern und mit einem Knopf ausführen.")
                        .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Space.xs) {
                            ForEach(prefs.savedCommands, id: \.self) { cmd in
                                IslandPillButton(title: running == cmd ? "läuft…" : cmd) { run(cmd) }
                                    .disabled(running != nil)
                                    .contextMenu { Button("Entfernen") { prefs.savedCommands.removeAll { $0 == cmd } } }
                                    .help(cmd)
                            }
                        }
                    }
                }
                if let r = result {
                    HStack(spacing: Space.xs) {
                        Image(systemName: r.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(r.ok ? IslandColor.accentText : IslandColor.warm)
                        Text(String(format: "%.1f s", r.seconds)).font(TypeStyle.islandCaption.monospacedDigit())
                        Text(r.line).font(TypeStyle.islandCaption).lineLimit(1).foregroundStyle(IslandColor.secondaryText)
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: Space.xs) {
                    TextField("Befehl, z. B. git status -sb", text: $draft)
                        .textFieldStyle(.plain).font(TypeStyle.islandCaption)
                        .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
                        .background(IslandColor.field, in: RoundedRectangle(cornerRadius: Radius.chip))
                        .onSubmit(save)
                    IslandPillButton(title: "Sichern", action: save)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || prefs.savedCommands.count >= 4)
                }
            }
        }
    }

    private func save() {
        let c = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty, prefs.savedCommands.count < 4, !prefs.savedCommands.contains(c) else { return }
        prefs.savedCommands.append(c)
        draft = ""
    }

    private func run(_ command: String) {
        running = command
        let start = Date()
        Task.detached(priority: .userInitiated) {
            let r = Run.program("/bin/zsh", ["-lc", command + " 2>&1"], timeout: 60)
            let line = r.output.split(whereSeparator: \.isNewline).last.map(String.init) ?? (r.status == -2 ? "Zeitlimit 60 s" : "")
            await MainActor.run {
                result = (command, r.status == 0, Date().timeIntervalSince(start), line)
                running = nil
            }
        }
    }
}

/// Browser-Tab: reads the front tab of Chrome or Safari once, when asked (macOS asks for the permission then).
struct BrowserTabTile: View {
    @State private var tab: (title: String, url: String)?
    @State private var note = "Zeigt den vorderen Tab von Chrome oder Safari."

    var body: some View {
        IslandCard(width: Metrics.wideTileWidth - 64) {
            VStack(alignment: .leading, spacing: Space.xs) {
                CardHeader(title: "Browser-Tab", symbol: "safari")
                if let tab {
                    Text(tab.title).font(TypeStyle.islandBody.weight(.medium)).lineLimit(1).help(tab.title)
                    Text(tab.url).font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText).lineLimit(1).help(tab.url)
                } else {
                    Text(note).font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText).lineLimit(2)
                }
                Spacer(minLength: 0)
                HStack(spacing: Space.xs) {
                    IslandPillButton(title: "Lesen", kind: .primary, action: read)
                    if let tab {
                        IslandIconButton(symbol: "link", label: "Link kopieren", size: 24) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(tab.url, forType: .string)
                        }
                        IslandIconButton(symbol: "sparkles.rectangle.stack", label: "Link ohne Tracking kopieren", size: 24) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(CleanLink.clean(tab.url) ?? tab.url, forType: .string)
                        }
                    }
                    Spacer(minLength: 0)
                    IslandIconButton(symbol: "playpause.fill", label: "Wiedergabe starten oder anhalten", size: 24) { MediaKey.playPause() }
                }
            }
        }
    }

    private func read() {
        let scripts = [("Google Chrome", "tell application \"Google Chrome\" to return (title of active tab of front window) & linefeed & (URL of active tab of front window)"),
                       ("Safari", "tell application \"Safari\" to return (name of front document) & linefeed & (URL of front document)")]
        let running = NSWorkspace.shared.runningApplications.compactMap(\.localizedName)
        for (name, source) in scripts where running.contains(name) {
            var error: NSDictionary?
            if let out = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue {
                let parts = out.components(separatedBy: "\n")
                if parts.count >= 2 { tab = (parts[0], parts[1]); return }
            }
            if error != nil { note = "Erlaube die Automation für \(name) in den Systemeinstellungen."; tab = nil; return }
        }
        note = "Kein geöffneter Chrome- oder Safari-Tab gefunden."
        tab = nil
    }
}

/// The system play/pause key: pauses or resumes whatever plays, including a video in a browser tab.
enum MediaKey {
    @MainActor static func playPause() {
        guard Permission.accessibilityTrusted else {
            IslandModel.shared.show(Toast(symbol: "exclamationmark.triangle", text: "Bedienungshilfen erlauben, dann Wiedergabe steuern", warm: true))
            return
        }
        for down in [true, false] {
            let flags = down ? 0xA00 : 0xB00
            let data1 = (16 << 16) | flags   // NX_KEYTYPE_PLAY
            NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
                               timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: data1, data2: -1)?
                .cgEvent?.post(tap: .cghidEventTap)
        }
    }
}

/// Nachricht: sends one iMessage or SMS through the Messages app. Nothing is read; the text goes only on the button.
struct MessageTile: View {
    @State private var to = ""
    @State private var text = ""
    @State private var note = "Über Nachrichten"

    var body: some View {
        IslandCard(width: Metrics.wideTileWidth - 64) {
            VStack(alignment: .leading, spacing: Space.xs) {
                CardHeader(title: "Nachricht", symbol: "message")
                field("Nummer oder Apple-ID", $to)
                field("Text", $text)
                HStack {
                    Text(note).font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText).lineLimit(1).help(note)
                    Spacer()
                    IslandPillButton(title: "Senden", kind: .primary, action: send)
                        .disabled(to.trimmingCharacters(in: .whitespaces).isEmpty || text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func field(_ title: String, _ value: Binding<String>) -> some View {
        TextField(title, text: value)
            .textFieldStyle(.plain).font(TypeStyle.islandCaption)
            .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
            .background(IslandColor.field, in: RoundedRectangle(cornerRadius: Radius.chip))
    }

    private func send() {
        // Quotes and backslashes are escaped so the text cannot end the AppleScript string.
        func esc(_ s: String) -> String { s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") }
        let source = """
        tell application "Messages"
            set theService to 1st account whose service type = iMessage
            set theBuddy to participant "\(esc(to.trimmingCharacters(in: .whitespaces)))" of theService
            send "\(esc(text))" to theBuddy
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if error == nil { note = "Gesendet."; text = "" } else { note = "Senden fehlgeschlagen: Automation für Nachrichten erlauben." }
    }
}
