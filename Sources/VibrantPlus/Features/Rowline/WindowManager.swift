// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ApplicationServices
import Observation
import VibrantPlusKit

/// Rowline: moves other apps' windows through the public Accessibility API.
@Observable
final class WindowManager {
    static let shared = WindowManager()

    struct Win {
        let element: AXUIElement
        let pid: pid_t
        let bundleID: String
        let appPath: String?
        let title: String
        var frame: CGRect
    }

    private(set) var layouts: [WindowLayout] = JSONFile<[WindowLayout]>(url: Paths.layouts).load() ?? []
    private(set) var lastMessage: String?
    @ObservationIgnored private var rowOffset: CGFloat = 0
    /// Width per window in the row, by "pid:title".
    @ObservationIgnored private var widths: [String: RowlineMath.Width] = [:]
    @ObservationIgnored private var rowOrder: [String] = []

    var trusted: Bool { Permission.accessibilityTrusted }

    func start() {} // Permission is requested by the first window action, or explicitly during setup.

    func stop() {}

    private func needTrust() -> Bool {
        guard trusted else {
            lastMessage = "Rowline braucht die Bedienungshilfen-Berechtigung."
            IslandModel.shared.show(Toast(symbol: "hand.raised", text: "Bedienungshilfen für Rowline erlauben", warm: true))
            Permission.requestAccessibility()
            return false
        }
        return true
    }

    // MARK: Reading windows

    /// Standard, visible windows on the given screen, left to right.
    func windows(on screen: NSScreen? = nil) -> [Win] {
        let excluded = Set(Prefs.shared.rowExcluded)
        var result: [Win] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && !app.isHidden {
            guard let bid = app.bundleIdentifier, !excluded.contains(bid), bid != Bundle.main.bundleIdentifier else { continue }
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(axApp, 0.3)
            for w in Self.array(axApp, kAXWindowsAttribute) {
                guard Self.string(w, kAXSubroleAttribute) == kAXStandardWindowSubrole as String,
                      Self.bool(w, kAXMinimizedAttribute) != true,
                      let frame = Self.frame(w) else { continue }
                if let screen, !Self.axRect(of: screen).intersects(frame) { continue }
                result.append(Win(element: w, pid: app.processIdentifier, bundleID: bid, appPath: app.bundleURL?.path,
                                  title: Self.string(w, kAXTitleAttribute) ?? "", frame: frame))
            }
        }
        return result.sorted { $0.frame.minX < $1.frame.minX }
    }

    func focusedWindow() -> Win? {
        guard let app = NSWorkspace.shared.frontmostApplication, let bid = app.bundleIdentifier else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let v = value, CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        let w = unsafeDowncast(v as AnyObject, to: AXUIElement.self)
        guard let frame = Self.frame(w) else { return nil }
        return Win(element: w, pid: app.processIdentifier, bundleID: bid, appPath: app.bundleURL?.path,
                   title: Self.string(w, kAXTitleAttribute) ?? "", frame: frame)
    }

    /// The screen under the focused window, or the main screen.
    private func screen(for frame: CGRect?) -> NSScreen {
        guard let frame else { return NSScreen.main ?? NSScreen.screens[0] }
        return NSScreen.screens.max { Self.axRect(of: $0).intersection(frame).area < Self.axRect(of: $1).intersection(frame).area }
            ?? NSScreen.main ?? NSScreen.screens[0]
    }

    /// The usable area of a screen in Accessibility coordinates (origin top-left of the main screen).
    static func axRect(of screen: NSScreen, visible: Bool = false) -> CGRect {
        let f = visible ? screen.visibleFrame : screen.frame
        let mainHeight = NSScreen.screens.first?.frame.height ?? f.height
        return CGRect(x: f.minX, y: mainHeight - f.maxY, width: f.width, height: f.height)
    }

    // MARK: Moving

    func set(_ w: Win, to frame: CGRect) {
        var origin = frame.origin
        var size = frame.size
        if let pos = AXValueCreate(.cgPoint, &origin) { AXUIElementSetAttributeValue(w.element, kAXPositionAttribute as CFString, pos) }
        if let sz = AXValueCreate(.cgSize, &size) { AXUIElementSetAttributeValue(w.element, kAXSizeAttribute as CFString, sz) }
        // Some apps clamp the size after a move: set the position once more.
        if let pos = AXValueCreate(.cgPoint, &origin) { AXUIElementSetAttributeValue(w.element, kAXPositionAttribute as CFString, pos) }
    }

    func snapFocused(_ snap: RowlineMath.Snap) {
        guard needTrust(), let w = focusedWindow() else { return }
        let area = Self.axRect(of: screen(for: w.frame), visible: true)
        set(w, to: RowlineMath.snap(snap, in: area, gap: Prefs.shared.rowGap))
    }

    func moveFocusedToOtherDisplay() {
        guard needTrust(), let w = focusedWindow(), NSScreen.screens.count > 1 else { return }
        let current = screen(for: w.frame)
        let others = NSScreen.screens.filter { $0 != current }
        guard let target = others.first else { return }
        let from = Self.axRect(of: current, visible: true), to = Self.axRect(of: target, visible: true)
        set(w, to: WindowToolRules.movedToNextDisplay(frame: w.frame, from: from, to: to))
    }

    // MARK: The row

    private func key(_ w: Win) -> String { "\(w.pid):\(w.title)" }

    /// Puts the visible windows of the focused window's screen side by side.
    func arrangeRow() {
        guard needTrust() else { return }
        let scr = screen(for: focusedWindow()?.frame)
        let wins = orderedRow(windows(on: scr))
        guard !wins.isEmpty else {
            IslandModel.shared.show(Toast(symbol: "rectangle.split.3x1", text: "Keine Fenster in der Reihe"))
            return
        }
        rowOrder = wins.map(key)
        layoutRow(wins, screen: scr)
    }

    private func orderedRow(_ wins: [Win]) -> [Win] {
        // Keep the order of the last arrangement; new windows join on the right.
        let known = rowOrder.compactMap { k in wins.first { key($0) == k } }
        return known + wins.filter { !rowOrder.contains(key($0)) }
    }

    private func layoutRow(_ wins: [Win], screen: NSScreen) {
        let area = Self.axRect(of: screen, visible: true)
        let gap = Prefs.shared.rowGap
        let ws = wins.map { widths[key($0)] ?? .half }
        for (w, frame) in zip(wins, RowlineMath.row(count: wins.count, widths: ws, in: area, gap: gap, offset: rowOffset)) {
            set(w, to: frame)
        }
    }

    /// Focuses the window left or right in the row and scrolls it into view.
    func focusNeighbour(_ step: Int) {
        guard needTrust() else { return }
        let focused = focusedWindow()
        let scr = screen(for: focused?.frame)
        let wins = orderedRow(windows(on: scr))
        guard !wins.isEmpty else { return }
        let current = focused.flatMap { f in wins.firstIndex { key($0) == key(f) } } ?? 0
        let next = max(0, min(wins.count - 1, current + step))
        rowOrder = wins.map(key)
        let area = Self.axRect(of: scr, visible: true)
        let gap = Prefs.shared.rowGap
        let ws = wins.map { widths[key($0)] ?? .half }
        let frames = RowlineMath.row(count: wins.count, widths: ws, in: area, gap: gap, offset: rowOffset)
        rowOffset = RowlineMath.offset(toShow: next, frames: frames, area: area, current: rowOffset, gap: gap)
        layoutRow(wins, screen: scr)
        raise(wins[next])
    }

    /// ½ → ⅔ → full → ⅓ for the focused window, then re-lays the row.
    func cycleWidth() {
        guard needTrust(), let w = focusedWindow() else { return }
        widths[key(w)] = (widths[key(w)] ?? .half).next
        let scr = screen(for: w.frame)
        let wins = orderedRow(windows(on: scr))
        if let i = wins.firstIndex(where: { key($0) == key(w) }) {
            let area = Self.axRect(of: scr, visible: true)
            let frames = RowlineMath.row(count: wins.count, widths: wins.map { widths[key($0)] ?? .half }, in: area,
                                         gap: Prefs.shared.rowGap, offset: rowOffset)
            rowOffset = RowlineMath.offset(toShow: i, frames: frames, area: area, current: rowOffset, gap: Prefs.shared.rowGap)
        }
        layoutRow(wins, screen: scr)
    }

    func arrangeGrid() {
        guard needTrust() else { return }
        let scr = screen(for: focusedWindow()?.frame)
        let wins = windows(on: scr)
        for (w, f) in zip(wins, RowlineMath.grid(count: wins.count, in: Self.axRect(of: scr, visible: true), gap: Prefs.shared.rowGap)) {
            set(w, to: f)
        }
    }

    func arrangeStack() {
        guard needTrust() else { return }
        let focused = focusedWindow()
        let scr = screen(for: focused?.frame)
        var wins = windows(on: scr)
        if let f = focused, let i = wins.firstIndex(where: { key($0) == key(f) }) { wins.insert(wins.remove(at: i), at: 0) }
        for (w, f) in zip(wins, RowlineMath.stack(count: wins.count, in: Self.axRect(of: scr, visible: true), gap: Prefs.shared.rowGap)) {
            set(w, to: f)
        }
    }

    private func raise(_ w: Win) {
        AXUIElementPerformAction(w.element, kAXRaiseAction as CFString)
        NSRunningApplication(processIdentifier: w.pid)?.activate()
    }

    // MARK: Saved layouts

    func saveLayout(named name: String) {
        guard needTrust() else { return }
        let entries = windows().map { WindowLayout.Entry(bundleID: $0.bundleID, appPath: $0.appPath, title: $0.title, frame: $0.frame) }
        guard !entries.isEmpty else { lastMessage = "Keine Fenster zum Sichern"; return }
        let clean = name.trimmingCharacters(in: .whitespaces)
        layouts.removeAll { $0.name == clean }
        layouts.append(WindowLayout(name: clean.isEmpty ? "Anordnung \(layouts.count + 1)" : clean, entries: entries))
        persist()
        lastMessage = "«\(layouts.last!.name)» gesichert (\(entries.count) Fenster)"
    }

    /// Puts windows back; opens apps that are not running and places them once they have a window.
    func restore(_ layout: WindowLayout) {
        guard needTrust() else { return }
        var missing: [WindowLayout.Entry] = []
        let current = windows()
        var used: Set<Int> = []
        for e in layout.entries {
            let candidates = current.enumerated().filter { $0.element.bundleID == e.bundleID && !used.contains($0.offset) }
            if let match = candidates.first(where: { $0.element.title == e.title }) ?? candidates.first {
                used.insert(match.offset)
                set(match.element, to: e.frame)
            } else {
                missing.append(e)
            }
        }
        for e in missing {
            guard let path = e.appPath ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: e.bundleID)?.path else { continue }
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: .init())
        }
        if !missing.isEmpty {
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                let now = self.windows()
                for e in missing { if let w = now.first(where: { $0.bundleID == e.bundleID }) { self.set(w, to: e.frame) } }
            }
        }
        lastMessage = "«\(layout.name)» wiederhergestellt"
    }

    func deleteLayout(_ layout: WindowLayout) {
        layouts.removeAll { $0.id == layout.id }
        persist()
    }

    private func persist() { SaveReport.attempt("Fensteranordnungen") { try JSONFile<[WindowLayout]>(url: Paths.layouts).save(layouts) } }

    // MARK: AX helpers

    static func array(_ e: AXUIElement, _ attr: String) -> [AXUIElement] {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(e, attr as CFString, &v) == .success else { return [] }
        return (v as? [AXUIElement]) ?? []
    }

    static func string(_ e: AXUIElement, _ attr: String) -> String? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(e, attr as CFString, &v) == .success else { return nil }
        return v as? String
    }

    static func bool(_ e: AXUIElement, _ attr: String) -> Bool? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(e, attr as CFString, &v) == .success else { return nil }
        return v as? Bool
    }

    static func frame(_ e: AXUIElement) -> CGRect? {
        var p: CFTypeRef?, s: CFTypeRef?
        guard AXUIElementCopyAttributeValue(e, kAXPositionAttribute as CFString, &p) == .success,
              AXUIElementCopyAttributeValue(e, kAXSizeAttribute as CFString, &s) == .success,
              let pv = p, let sv = s else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(unsafeDowncast(pv as AnyObject, to: AXValue.self), .cgPoint, &point)
        AXValueGetValue(unsafeDowncast(sv as AnyObject, to: AXValue.self), .cgSize, &size)
        return CGRect(origin: point, size: size)
    }
}

private extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }
}
