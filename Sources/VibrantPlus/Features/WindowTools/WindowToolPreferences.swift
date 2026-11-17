// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Observation
import VibrantPlusKit

@Observable
final class WindowToolPreferences {
    static let shared = WindowToolPreferences()
    enum DockClickAction: String, CaseIterable {
        case none, minimize, hide, cycle
        var title: String {
            switch self { case .none: "Unverändert"; case .minimize: "Vorderstes Fenster minimieren"; case .hide: "App ausblenden"; case .cycle: "Nächstes Fenster" }
        }
    }
    @ObservationIgnored private let defaults: UserDefaults = Paths.isOverridden
        ? UserDefaults(suiteName: "ch.arjo.vibrantplus.test.windowTools." + Paths.dataDirectory.lastPathComponent)!
        : .standard
    var greenButtonMaximizes: Bool { didSet { defaults.set(greenButtonMaximizes, forKey: "windowTools.greenButton") } }
    var fixedSpaces: Bool { didSet { defaults.set(fixedSpaces, forKey: "windowTools.fixedSpaces") } }
    var switcherEnabled: Bool { didSet { defaults.set(switcherEnabled, forKey: "windowTools.switcher") } }
    var dockPreviewEnabled: Bool { didSet { defaults.set(dockPreviewEnabled, forKey: "windowTools.dockPreview") } }
    var previewImagesEnabled: Bool { didSet { defaults.set(previewImagesEnabled, forKey: "windowTools.previewImages") } }
    var dockClickAction: DockClickAction { didSet { defaults.set(dockClickAction.rawValue, forKey: "windowTools.dockClick") } }
    var focusFollowsMouse: Bool { didSet { defaults.set(focusFollowsMouse, forKey: "windowTools.focusMouse") } }
    var edgeSnapEnabled: Bool { didSet { defaults.set(edgeSnapEnabled, forKey: "windowTools.edgeSnap") } }
    var modifierDragEnabled: Bool { didSet { defaults.set(modifierDragEnabled, forKey: "windowTools.modifierDrag") } }
    var excludedApps: String { didSet { defaults.set(excludedApps, forKey: "windowTools.excluded") } }
    var hoverDelay: Double { didSet { defaults.set(hoverDelay, forKey: "windowTools.hoverDelay") } }

    private init() {
        greenButtonMaximizes = defaults.bool(forKey: "windowTools.greenButton")
        fixedSpaces = defaults.bool(forKey: "windowTools.fixedSpaces")
        switcherEnabled = defaults.bool(forKey: "windowTools.switcher")
        dockPreviewEnabled = defaults.bool(forKey: "windowTools.dockPreview")
        previewImagesEnabled = defaults.bool(forKey: "windowTools.previewImages")
        dockClickAction = DockClickAction(rawValue: defaults.string(forKey: "windowTools.dockClick") ?? "") ?? .none
        focusFollowsMouse = defaults.bool(forKey: "windowTools.focusMouse")
        edgeSnapEnabled = defaults.bool(forKey: "windowTools.edgeSnap")
        modifierDragEnabled = defaults.bool(forKey: "windowTools.modifierDrag")
        excludedApps = defaults.string(forKey: "windowTools.excluded") ?? ""
        let delay = defaults.double(forKey: "windowTools.hoverDelay")
        hoverDelay = delay > 0 ? max(0.2, min(2, delay)) : 0.4
    }

    func excludes(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return WindowToolRules.excludedIdentifiers(excludedApps).contains(bundleID)
    }
}
