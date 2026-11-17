// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Carbon.HIToolbox
import os

/// Registration failures used to be invisible: a combination another app already owns simply
/// did nothing. Settings now shows them, and the log says which one and why.
private enum HotKeyLog {
    static let shared = Logger(subsystem: "ch.arjo.vibrantplus", category: "hotkeys")
}

/// A key combination. Saved as key code + Carbon modifier flags.
struct Shortcut: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let ctrlOptCmd = UInt32(controlKey | optionKey | cmdKey)

    var display: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + Shortcut.keyName(keyCode)
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var m: UInt32 = 0
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        // A global shortcut needs at least one of ⌃⌥⌘.
        guard m & UInt32(controlKey | optionKey | cmdKey) != 0 else { return nil }
        self.init(keyCode: UInt32(event.keyCode), modifiers: m)
    }

    static func keyName(_ code: UInt32) -> String {
        switch Int(code) {
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Return: return "↩"
        case kVK_Space: return "Leertaste"
        case kVK_Escape: return "⎋"
        case kVK_Delete: return "⌫"
        case kVK_Tab: return "⇥"
        default: break
        }
        // Ask the current keyboard layout for the character.
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return "?" }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var dead: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return -1 }
            return UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                  OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, 4, &length, &chars)
        }
        guard status == noErr, length > 0 else { return "?" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}

/// Every action with a global shortcut. People change them in Settings > Kurzbefehle.
enum HotKeyAction: String, CaseIterable, Identifiable, Codable {
    case toggleIsland, rowArrange, rowNext, rowPrevious, rowWidth, snapLeft, snapRight, snapLeftTwoThirds,
         snapRightTwoThirds, snapFull, snapCenter, grid, stack, otherDisplay, appGrid, clipboard,
         captureScreen, captureWindow, captureArea, windowSwitcher, commandBar, shelfPalette, toolPalette

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toggleIsland: "Insel öffnen und schliessen"
        case .rowArrange: "Rowline: Fenster in eine Reihe"
        case .rowNext: "Rowline: nächstes Fenster"
        case .rowPrevious: "Rowline: vorheriges Fenster"
        case .rowWidth: "Rowline: Breite wechseln"
        case .snapLeft: "Fenster links (½)"
        case .snapRight: "Fenster rechts (½)"
        case .snapLeftTwoThirds: "Fenster links (⅔)"
        case .snapRightTwoThirds: "Fenster rechts (⅔)"
        case .snapFull: "Fenster ganze Breite"
        case .snapCenter: "Fenster zentrieren"
        case .grid: "Fenster im Raster"
        case .stack: "Fenster gestapelt"
        case .otherDisplay: "Fenster auf den anderen Bildschirm"
        case .appGrid: "App-Raster"
        case .clipboard: "Zwischenablage-Verlauf"
        case .captureScreen: "Bildschirmfoto: ganzer Bildschirm"
        case .captureWindow: "Bildschirmfoto: Fenster"
        case .captureArea: "Bildschirmfoto: Ausschnitt"
        case .windowSwitcher: "App- und Fensterwechsler"
        case .commandBar: "Befehlsleiste"
        case .shelfPalette: "Ablage am Zeiger"
        case .toolPalette: "Schnellpalette am Zeiger"
        }
    }

    var module: Module {
        switch self {
        case .toggleIsland, .clipboard: .island
        case .appGrid: .appGrid
        case .captureScreen, .captureWindow, .captureArea: .screenshots
        case .windowSwitcher: .windowTools
        case .commandBar, .toolPalette: .quickTools
        case .shelfPalette: .island
        default: .rowline
        }
    }

    func isEnabled(in prefs: Prefs) -> Bool {
        guard prefs.onboarded else { return false }
        if self == .clipboard {
            return prefs.isOn(.clipboard) || (prefs.isOn(.island) && prefs.tilesOn.contains(.clipboard))
        }
        return prefs.isOn(module)
    }

    var defaultShortcut: Shortcut {
        let m = Shortcut.ctrlOptCmd
        return switch self {
        case .toggleIsland: Shortcut(keyCode: UInt32(kVK_ANSI_I), modifiers: m)
        case .rowArrange: Shortcut(keyCode: UInt32(kVK_ANSI_F), modifiers: m)
        case .rowNext: Shortcut(keyCode: UInt32(kVK_RightArrow), modifiers: m)
        case .rowPrevious: Shortcut(keyCode: UInt32(kVK_LeftArrow), modifiers: m)
        case .rowWidth: Shortcut(keyCode: UInt32(kVK_ANSI_W), modifiers: m)
        case .snapLeft: Shortcut(keyCode: UInt32(kVK_ANSI_1), modifiers: m)
        case .snapRight: Shortcut(keyCode: UInt32(kVK_ANSI_2), modifiers: m)
        case .snapLeftTwoThirds: Shortcut(keyCode: UInt32(kVK_ANSI_3), modifiers: m)
        case .snapRightTwoThirds: Shortcut(keyCode: UInt32(kVK_ANSI_4), modifiers: m)
        case .snapFull: Shortcut(keyCode: UInt32(kVK_Return), modifiers: m)
        case .snapCenter: Shortcut(keyCode: UInt32(kVK_ANSI_C), modifiers: m)
        case .grid: Shortcut(keyCode: UInt32(kVK_ANSI_G), modifiers: m)
        case .stack: Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: m)
        case .otherDisplay: Shortcut(keyCode: UInt32(kVK_ANSI_D), modifiers: m)
        case .appGrid: Shortcut(keyCode: UInt32(kVK_ANSI_4), modifiers: UInt32(optionKey | cmdKey))
        case .clipboard: Shortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: m)
        // ⌥⇧⌘ plus 3, 4, 5: next to the system's ⇧⌘3/4/5, without taking them.
        case .captureScreen: Shortcut(keyCode: UInt32(kVK_ANSI_3), modifiers: UInt32(optionKey | shiftKey | cmdKey))
        case .captureWindow: Shortcut(keyCode: UInt32(kVK_ANSI_4), modifiers: UInt32(optionKey | shiftKey | cmdKey))
        case .captureArea: Shortcut(keyCode: UInt32(kVK_ANSI_5), modifiers: UInt32(optionKey | shiftKey | cmdKey))
        case .windowSwitcher: Shortcut(keyCode: UInt32(kVK_Tab), modifiers: m)
        case .commandBar: Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: m)
        case .shelfPalette: Shortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: m)
        case .toolPalette: Shortcut(keyCode: UInt32(kVK_ANSI_P), modifiers: m)
        }
    }
}

/// Global shortcuts through Carbon's RegisterEventHotKey: works in every app
/// and needs no Accessibility permission.
@Observable
final class HotKeys {
    static let shared = HotKeys()

    private(set) var shortcuts: [HotKeyAction: Shortcut] = [:]
    /// Combinations that could not be registered: another app or a stale second copy holds them.
    private(set) var unavailable: Set<HotKeyAction> = []
    @ObservationIgnored private var refs: [HotKeyAction: EventHotKeyRef] = [:]
    @ObservationIgnored private var handlers: [HotKeyAction: () -> Void] = [:]
    @ObservationIgnored private var installed = false
    /// While the Settings page records a new shortcut, hot keys pause.
    @ObservationIgnored var paused = false

    private init() {
        let saved = (try? JSONDecoder().decode([String: Shortcut].self,
                                               from: UserDefaults.standard.data(forKey: "hotkeys") ?? Data())) ?? [:]
        for action in HotKeyAction.allCases {
            shortcuts[action] = saved[action.rawValue] ?? action.defaultShortcut
        }
    }

    func setHandler(_ action: HotKeyAction, _ handler: @escaping () -> Void) {
        handlers[action] = handler
    }

    func change(_ action: HotKeyAction, to shortcut: Shortcut) {
        // One combination, one action: a duplicate moves to the new action.
        for (a, s) in shortcuts where s == shortcut && a != action { shortcuts[a] = nil }
        shortcuts[action] = shortcut
        save()
        refresh()
    }

    func reset() {
        for action in HotKeyAction.allCases { shortcuts[action] = action.defaultShortcut }
        save()
        refresh()
    }

    private func save() {
        let dict = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
        UserDefaults.standard.set(try? JSONEncoder().encode(dict), forKey: "hotkeys")
    }

    /// Registers the shortcuts of modules that are on; unregisters the rest.
    func refresh() {
        installHandlerOnce()
        for (_, ref) in refs { UnregisterEventHotKey(ref) }
        refs = [:]
        var failed: Set<HotKeyAction> = []
        let prefs = Prefs.shared
        for (index, action) in HotKeyAction.allCases.enumerated() {
            guard action.isEnabled(in: prefs), let s = shortcuts[action] else { continue }
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: OSType(0x5642_504C), id: UInt32(index)) // 'VBPL'
            let status = RegisterEventHotKey(s.keyCode, s.modifiers, id, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                refs[action] = ref
            } else {
                failed.insert(action)
                HotKeyLog.shared.error("shortcut \(action.rawValue, privacy: .public) \(s.display, privacy: .public) not registered (OSStatus \(status))")
            }
        }
        unavailable = failed
    }

    fileprivate func fire(index: UInt32) {
        guard !paused, HotKeyAction.allCases.indices.contains(Int(index)) else { return }
        handlers[HotKeyAction.allCases[Int(index)]]?()
    }

    private func installHandlerOnce() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let index = id.id
            MainActor.assumeIsolated { HotKeys.shared.fire(index: index) }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
