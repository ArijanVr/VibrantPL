// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// Context menu on every tile; in arrange mode also drag and drop, arrows and a width button.
    func arrangeable(_ tile: TileKind, among tiles: [TileKind]) -> some View {
        modifier(TileArrange(tile: tile, tiles: tiles))
    }
}

/// Moves a tile within its island page. The menu works without dragging; arrange mode adds dragging.
private struct TileArrange: ViewModifier {
    let tile: TileKind
    let tiles: [TileKind]
    private var prefs = Prefs.shared
    private var model = IslandModel.shared
    @State private var targeted = false

    init(tile: TileKind, tiles: [TileKind]) {
        self.tile = tile
        self.tiles = tiles
    }

    private var index: Int? { tiles.firstIndex(of: tile) }
    private var wide: Bool { prefs.wideTiles.contains(tile) }

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!model.arranging)
            .overlay { if model.arranging { controls.draggable(tile.rawValue) } }
            .dropDestination(for: String.self) { items, _ in
                guard model.arranging, let moved = items.first.flatMap(TileKind.init(rawValue:)) else { return false }
                prefs.moveTile(moved, onto: tile)
                return true
            } isTargeted: { targeted = $0 }
            .contextMenu {
                Button("Nach links", systemImage: "arrow.left") { step(-1) }.disabled((index ?? 0) == 0)
                Button("Nach rechts", systemImage: "arrow.right") { step(1) }.disabled((index ?? 0) >= tiles.count - 1)
                if tile.canWiden {
                    Button(wide ? "Normale Breite" : "Breit", systemImage: wide ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                        prefs.toggleWide(tile)
                    }
                }
                Divider()
                Button(model.arranging ? "Anordnen beenden" : "Kacheln anordnen", systemImage: "square.grid.2x2") { model.arranging.toggle() }
                Button("Ausblenden", systemImage: "eye.slash") { prefs.tilesOn.remove(tile) }
            }
    }

    private func step(_ delta: Int) {
        guard let i = index, tiles.indices.contains(i + delta) else { return }
        withAnimation(Motion.respecting(Motion.quick)) { prefs.moveTile(tile, onto: tiles[i + delta]) }
    }

    private var controls: some View {
        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            .strokeBorder(IslandColor.accent, style: StrokeStyle(lineWidth: targeted ? 3 : 1.5, dash: [5, 4]))
            .background(targeted ? IslandColor.accent.opacity(0.3) : IslandColor.background.opacity(0.9), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(alignment: .bottom) {
                HStack(spacing: Space.xs) {
                    IslandIconButton(symbol: "chevron.left", label: "Nach links", size: 24) { step(-1) }
                        .disabled((index ?? 0) == 0)
                    if tile.canWiden {
                        IslandIconButton(symbol: wide ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                                         label: wide ? "Normale Breite" : "Breit", size: 24) { prefs.toggleWide(tile) }
                    }
                    IslandIconButton(symbol: "chevron.right", label: "Nach rechts", size: 24) { step(1) }
                        .disabled((index ?? 0) >= tiles.count - 1)
                }
                .padding(.bottom, Space.sm)
            }
            .overlay(alignment: .topLeading) {
                Label(tile.title, systemImage: "line.3.horizontal")
                    .font(TypeStyle.islandLabel).foregroundStyle(IslandColor.accentText)
                    .padding(Space.sm)
            }
    }
}
