// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import VibrantPlusKit

/// The full clipboard history with search, pinning and images. ⌃⌥⌘V.
struct ClipboardView: View {
    @State private var clip = ClipboardHistory.shared
    @State private var query = ""
    @FocusState private var focused: Bool

    private var rows: [ClipItem] { clip.list.visible(matching: query) }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Suchen", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .padding(Space.md)
                .onSubmit { if let first = rows.first { use(first) } }
            Divider()
            if rows.isEmpty {
                ContentUnavailableView(query.isEmpty ? "Noch nichts kopiert" : "Nichts gefunden", systemImage: "doc.on.clipboard",
                                       description: Text(query.isEmpty ? "Kopiere etwas, es erscheint hier. Angeheftetes bleibt gespeichert." : "Andere Suchbegriffe probieren."))
            } else {
                List(rows) { item in
                    HStack(spacing: Space.md) {
                        if item.kind == .image, let image = clip.images[item.id] {
                            Image(nsImage: image).resizable().scaledToFit().frame(width: 56, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else if item.kind == .file {
                            Image(systemName: "doc").frame(width: 24)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.preview).lineLimit(2)
                            Text(item.date, format: .relative(presentation: .named)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if item.kind == .text {
                            Button { clip.togglePin(item) } label: { Image(systemName: item.pinned ? "pin.fill" : "pin") }
                                .buttonStyle(.borderless).help(item.pinned ? "Lösen" : "Anheften und speichern")
                        }
                        Button { clip.remove(item) } label: { Image(systemName: "xmark") }
                            .buttonStyle(.borderless).help("Entfernen")
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { use(item) }
                    .accessibilityAction(named: Prefs.shared.clipboardDirectPaste ? "Einfügen" : "Kopieren") { use(item) }
                }
            }
            Divider()
            HStack {
                Text("\(clip.list.items.count) Einträge").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Nicht Angeheftetes löschen", role: .destructive) { clip.clearUnpinned() }
                    .disabled(clip.list.items.allSatisfy(\.pinned))
            }
            .padding(Space.md)
        }
        .frame(minWidth: 420, minHeight: 440)
        .onAppear { focused = true }
    }

    private func use(_ item: ClipItem) {
        if Prefs.shared.clipboardDirectPaste { clip.paste(item) } else { clip.copy(item) }
        Windows.close(.clipboard)
    }
}
