// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// A scene is a ready-made set of tiles in a chosen order. Choosing one saves the layout you had,
/// so «Mein Layout» brings it back.
struct TileScene: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tiles: [TileKind]

    static let all: [TileScene] = [
        TileScene(id: "focus", title: "Fokus", detail: "Musik, Timer, Aufgaben, Notiz", symbol: "scope",
                  tiles: [.nowPlaying, .timer, .todo, .quickNote, .nextEvent]),
        TileScene(id: "develop", title: "Entwickeln", detail: "Claude Code, Verbrauch, Zwischenablage, Systemwerte", symbol: "chevron.left.forwardslash.chevron.right",
                  tiles: [.agent, .usage, .clipboard, .shortcuts, .system, .timer]),
        TileScene(id: "meeting", title: "Besprechung", detail: "Besprechung, Termine, Erinnerungen, Notiz", symbol: "person.2",
                  tiles: [.meeting, .nextEvent, .reminders, .quickNote]),
        TileScene(id: "day", title: "Alltag", detail: "Musik, Wetter, Termine, Uhr, Ablage", symbol: "sun.max",
                  tiles: [.nowPlaying, .weather, .nextEvent, .clock, .shelf]),
        TileScene(id: "record", title: "Aufnahme", detail: "Teleprompter, Spiegel, Timer, Steuerungen", symbol: "video",
                  tiles: [.teleprompter, .mirror, .timer, .controls]),
        TileScene(id: "calm", title: "Ruhe", detail: "Uhr, Wetter, Musik", symbol: "moon",
                  tiles: [.clock, .weather, .nowPlaying]),
    ]

    private static let defaults = UserDefaults.standard

    /// The layout from before the first scene, or nil when no scene has been chosen.
    static var hasSavedLayout: Bool { defaults.stringArray(forKey: "scenes.saved.order") != nil }
    static var activeID: String? { defaults.string(forKey: "scenes.active") }

    @MainActor static func apply(_ scene: TileScene) {
        let prefs = Prefs.shared
        if !hasSavedLayout {
            defaults.set(prefs.tileOrder.map(\.rawValue), forKey: "scenes.saved.order")
            defaults.set(prefs.tilesOn.map(\.rawValue), forKey: "scenes.saved.on")
        }
        prefs.tilesOn = Set(scene.tiles)
        prefs.tileOrder = scene.tiles + prefs.tileOrder.filter { !scene.tiles.contains($0) }
        defaults.set(scene.id, forKey: "scenes.active")
    }

    @MainActor static func restoreSaved() {
        guard let order = defaults.stringArray(forKey: "scenes.saved.order") else { return }
        let prefs = Prefs.shared
        let kinds = order.compactMap(TileKind.init)
        prefs.tileOrder = kinds + TileKind.defaultOrder.filter { !kinds.contains($0) }
        prefs.tilesOn = Set((defaults.stringArray(forKey: "scenes.saved.on") ?? []).compactMap(TileKind.init))
        defaults.removeObject(forKey: "scenes.saved.order")
        defaults.removeObject(forKey: "scenes.saved.on")
        defaults.removeObject(forKey: "scenes.active")
    }
}

struct SceneSettings: View {
    @State private var active = TileScene.activeID
    @State private var hasSaved = TileScene.hasSavedLayout

    var body: some View {
        Section {
            ForEach(TileScene.all) { scene in
                Button {
                    TileScene.apply(scene)
                    active = scene.id
                    hasSaved = true
                } label: {
                    HStack {
                        Image(systemName: scene.symbol).frame(width: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(scene.title)
                            Text(scene.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if active == scene.id { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
                .buttonStyle(.plain)
            }
            Button("Mein Layout wiederherstellen") {
                TileScene.restoreSaved()
                active = nil
                hasSaved = false
            }
            .disabled(!hasSaved)
        } header: {
            Text("Szenen")
        } footer: {
            Text("Eine Szene schaltet passende Kacheln ein und ordnet sie. Dein bisheriges Layout wird vorher gesichert und bleibt über «Mein Layout» erreichbar. Jede Kachel bleibt einzeln änderbar.")
        }
    }
}
