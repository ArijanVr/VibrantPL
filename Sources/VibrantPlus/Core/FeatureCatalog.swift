// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Observation
import SwiftUI

/// Shared by setup and Settings; profiles change module availability, never tile layout or styling.
enum ModuleProfile: String, CaseIterable, Identifiable {
    case essentials, productivity, development, all
    var id: String { rawValue }
    var title: String {
        switch self {
        case .essentials: "Alltag"
        case .productivity: "Produktiv"
        case .development: "Entwicklung"
        case .all: "Alle Werkzeuge"
        }
    }
    var detail: String {
        switch self {
        case .essentials: "Insel, Heute, Bildschirmfotos, Downloads und Dateien"
        case .productivity: "Zusätzlich Fenster, Zwischenablage, Textbausteine und Links"
        case .development: "Produktiv mit Claude Code und Entwicklerleiste"
        case .all: "Alle Module einschalten; Berechtigungen bleiben freiwillig"
        }
    }
    var modules: Set<Module> {
        let basic: Set<Module> = [.island, .today, .screenshots, .downloads, .stow]
        let productive = basic.union([.rowline, .clipboard, .snippets, .links, .dial, .appGrid])
        switch self {
        case .essentials: return basic
        case .productivity: return productive
        case .development: return productive.union([.agent, .devBar])
        case .all: return Set(Module.allCases)
        }
    }
}

extension Module {
    var settingsPage: SettingsPage {
        switch self {
        case .windowTools: .windowTools
        case .cleaner: .cleaner
        case .uninstaller: .uninstaller
        case .homebrew: .homebrew
        case .appUpdates: .appUpdates
        case .diskInstaller: .diskInstaller
        case .systemMonitor: .systemMonitor
        case .keepAwakeRules: .keepAwakeRules
        case .quickTools: .quickTools
        case .cleaning: .cleaning
        case .mouse: .mouse
        case .finder: .finder
        case .quitProtection: .quitProtection
        case .autoQuit: .autoQuit
        case .audioDevices: .audioDevices
        case .ocr: .ocr
        case .scratchpad: .scratchpad
        case .processes: .processes
        case .island: .island
        case .agent: .agent
        case .assistant: .assistant
        case .screenshots: .screenshots
        case .downloads: .downloads
        case .snippets: .snippets
        case .today: .today
        case .stow: .stow
        case .rowline: .rowline
        case .dial: .dial
        case .voice: .voice
        case .keys: .keys
        case .appGrid: .appGrid
        case .devBar: .devBar
        case .clipboard: .clipboard
        case .links: .links
        }
    }

    func matches(_ query: String) -> Bool {
        let terms = query.split(whereSeparator: \.isWhitespace)
        let text = title + " " + subtitle + " " + rawValue
        return terms.allSatisfy { text.localizedStandardContains(String($0)) }
    }
}

/// One route for menu shortcuts and the catalog, including an already open Settings window.
@Observable
final class SettingsNavigation {
    static let shared = SettingsNavigation()
    var page = SettingsRoot.initialPage
}

enum SetupPermissions {
    static func required(for modules: Set<Module>, tiles: Set<TileKind>) -> [Permission] {
        var result: Set<Permission> = []
        if !modules.isDisjoint(with: [.rowline, .voice, .keys, .snippets, .mouse, .finder, .quitProtection, .autoQuit, .windowTools, .cleaning]) { result.insert(.accessibility) }
        if modules.contains(.today) || (modules.contains(.island) && tiles.contains(.nextEvent)) { result.insert(.calendar) }
        if modules.contains(.island) && tiles.contains(.reminders) { result.insert(.reminders) }
        if modules.contains(.voice) { result.formUnion([.microphone, .speech]) }
        if modules.contains(.screenshots) || modules.contains(.ocr) { result.insert(.screenRecording) }
        if modules.contains(.dial) { result.insert(.audioCapture) }
        return Permission.allCases.filter { result.contains($0) }
    }
}

struct ModuleSelection: View {
    @Binding var selection: Set<Module>
    var query = ""

    var body: some View {
        ForEach(Module.Group.allCases, id: \.self) { group in
            let modules = Module.allCases.filter { $0.group == group && $0.matches(query) }
            if !modules.isEmpty {
                Section(group.rawValue) {
                    ForEach(modules) { module in
                        Toggle(isOn: Binding(get: { selection.contains(module) }, set: { on in
                            if on { selection.insert(module) } else { selection.remove(module) }
                        })) {
                            Label {
                                Text(module.title)
                                Text(module.subtitle)
                            } icon: {
                                Image(systemName: module.symbol).foregroundStyle(Palette.accentText).frame(width: 24)
                            }
                        }
                    }
                }
            }
        }
    }
}
