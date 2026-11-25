// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers
import VibrantPlusKit

@Observable
final class Scratchpad {
    static let shared = Scratchpad()
    private(set) var notes: [ScratchNote]
    var selected: UUID?
    @ObservationIgnored private let file = JSONFile<[ScratchNote]>(url: Paths.dataDirectory.appending(path: "scratchpad.json"))
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    init() { notes = file.load() ?? []; selected = notes.first?.id }
    var current: ScratchNote? { notes.first { $0.id == selected } }
    func add() { let note = ScratchNote(); notes.append(note); selected = note.id; save() }
    func update(title: String? = nil, text: String? = nil) {
        guard let index = notes.firstIndex(where: { $0.id == selected }) else { return }
        if let title { notes[index].title = title }
        if let text { notes[index].text = text }
        notes[index].modified = .now
        saveTask?.cancel()
        saveTask = Task { try? await Task.sleep(for: .milliseconds(400)); guard !Task.isCancelled else { return }; save() }
    }
    func removeCurrent() {
        guard let current else { return }
        let alert = NSAlert()
        alert.messageText = "Notiz «\(current.title)» löschen?"
        alert.informativeText = "Die Notiz wird als Markdown in den Papierkorb verschoben."
        alert.addButton(withTitle: "In den Papierkorb"); alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            let backup = Paths.dataDirectory.appending(path: "Notiz-\(current.id).md")
            try current.text.write(to: backup, atomically: true, encoding: .utf8)
            try FileManager.default.trashItem(at: backup, resultingItemURL: nil)
            notes.removeAll { $0.id == current.id }; selected = notes.first?.id; save()
        } catch { IslandModel.shared.show(Toast(symbol: "exclamationmark.triangle", text: "Notiz konnte nicht gelöscht werden")) }
    }
    func save() { SaveReport.attempt("Notizblock") { try file.save(notes) } }
    func export() {
        guard let note = current else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.plainText]; panel.nameFieldStringValue = "Notiz.md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        SaveReport.attempt("Notiz-Export") { try note.text.write(to: url, atomically: true, encoding: .utf8) }
    }
}

struct ScratchpadView: View {
    @State private var store = Scratchpad.shared
    @State private var preview = false
    var body: some View {
        VStack(spacing: Space.sm) {
            HStack {
                Picker("Notiz", selection: $store.selected) {
                    ForEach(store.notes) { note in Text(note.title.isEmpty ? "Notiz" : note.title).tag(Optional(note.id)) }
                }
                Button("Neue Notiz", systemImage: "plus") { store.add() }.labelStyle(.iconOnly)
                Toggle("Vorschau", isOn: $preview).toggleStyle(.button)
                Button("Exportieren…") { store.export() }.disabled(store.current == nil)
                Button("Löschen…", systemImage: "trash") { store.removeCurrent() }.labelStyle(.iconOnly).disabled(store.current == nil)
            }
            if store.current != nil {
                TextField("Titel", text: Binding(get: { store.current?.title ?? "" }, set: { store.update(title: $0) }))
                if preview {
                    ScrollView { Text(.init(store.current?.text ?? "")).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                } else {
                    TextEditor(text: Binding(get: { store.current?.text ?? "" }, set: { store.update(text: $0) }))
                        .font(.body)
                }
            } else {
                PulsiEmpty(title: "Dein Notizblock", text: "Lege deine erste Notiz an.")
            }
        }
        .padding(Space.margin).frame(width: 640, height: 480)
        .onDisappear { store.save() }
    }
}
