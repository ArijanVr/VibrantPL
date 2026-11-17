// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// A small drop/drag panel at the pointer, so the shelf is usable without opening the island.
final class ShelfPalette {
    static let shared = ShelfPalette()
    private var panel: NSPanel?

    var isOpen: Bool { panel?.isVisible == true }

    func toggle() {
        if isOpen { close(); return }
        guard Prefs.shared.isOn(.island) else { return }
        Shelf.shared.prune()
        let size = NSSize(width: 280, height: 220)
        let panel = IslandPanel(contentRect: NSRect(origin: .zero, size: size),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hasShadow = true
        let host = NSHostingView(rootView: ShelfPaletteView().themed())
        host.sizingOptions = []
        panel.contentView = host
        if let screen = NSScreen.withMouse {
            let mouse = NSEvent.mouseLocation, room = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: min(max(room.minX, mouse.x - 16), max(room.minX, room.maxX - size.width)),
                y: min(max(room.minY, mouse.y - size.height + 16), max(room.minY, room.maxY - size.height))
            ))
        } else {
            panel.center()
        }
        self.panel = panel
        panel.orderFrontRegardless()
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}

struct ShelfPaletteView: View {
    private var shelf = Shelf.shared
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text("Ablage").font(TypeStyle.islandLabel)
                Spacer()
                Button("Schliessen") { ShelfPalette.shared.close() }
                    .buttonStyle(.plain).font(TypeStyle.islandLabel).foregroundStyle(IslandColor.accentText)
            }
            if shelf.files.isEmpty {
                Text("Dateien hierher ziehen, später wieder herausziehen.")
                    .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: Space.sm)], spacing: Space.sm) {
                        ForEach(shelf.files, id: \.self) { url in
                            VStack(spacing: 2) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable().frame(width: 40, height: 40)
                                Text(url.lastPathComponent).font(TypeStyle.islandMicro).lineLimit(2)
                            }
                            .frame(width: 64)
                            .draggable(url)
                            .accessibilityLabel(url.lastPathComponent)
                        }
                    }
                }
            }
        }
        .padding(Space.md)
        .frame(width: 280, height: 220, alignment: .topLeading)
        .islandBackground(RoundedRectangle(cornerRadius: Radius.island, style: .continuous), open: true)
        .overlay(RoundedRectangle(cornerRadius: Radius.island, style: .continuous)
            .strokeBorder(targeted ? IslandColor.accent : IslandColor.separator))
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            Task {
                var urls: [URL] = []
                for p in providers {
                    if let d = try? await p.loadItem(forTypeIdentifier: UTType.fileURL.identifier) as? Data,
                       let u = URL(dataRepresentation: d, relativeTo: nil) { urls.append(u) }
                }
                await MainActor.run { shelf.add(urls) }
            }
            return true
        }
        .foregroundStyle(IslandColor.primaryText)
        .environment(\.colorScheme, IslandColor.scheme)
    }
}
