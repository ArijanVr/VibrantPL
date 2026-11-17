// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ApplicationServices
import Observation
import SwiftUI
import VibrantPlusKit

/// Public AX/window APIs only. It never changes Mission Control spaces or uses SkyLight.
@Observable
final class WindowTools {
    static let shared = WindowTools()
    let switcher = WindowToolCollection()
    let dock = WindowToolCollection()
    private(set) var active = false
    private(set) var message: String?
    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private var switcherPanel: NSPanel?
    @ObservationIgnored private var dockPanel: NSPanel?
    @ObservationIgnored private var hoverTask: Task<Void, Never>?
    @ObservationIgnored private var focusTask: Task<Void, Never>?
    @ObservationIgnored private var hoverPID: pid_t?
    @ObservationIgnored private var focusedHoverWindow: AXUIElement?
    @ObservationIgnored private var dockMouseDownPID: pid_t?
    @ObservationIgnored private var dockWasFrontmost = false
    @ObservationIgnored private var drag: (window: WindowManager.Win, origin: CGPoint, original: CGRect)?
    @ObservationIgnored private var draggedWindow: WindowManager.Win?
    @ObservationIgnored private var lastMove = Date.distantPast
    @ObservationIgnored private var dockCycle: [pid_t: Int] = [:]
    @ObservationIgnored private var zoomFrames: [CFHashCode: CGRect] = [:]
    @ObservationIgnored private var consumedZoomDown = false

    var needsPointerTap: Bool { active && (WindowToolPreferences.shared.greenButtonMaximizes || WindowToolPreferences.shared.modifierDragEnabled) }
    var needsZoomTap: Bool { needsPointerTap }

    func start() {
        guard !active else { return }
        active = true
        configure()
        observe()
    }
    func stop() {
        active = false
        if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil
        hoverTask?.cancel(); focusTask?.cancel(); hoverTask = nil; focusTask = nil
        switcherPanel?.orderOut(nil); dockPanel?.orderOut(nil)
        switcherPanel = nil; dockPanel = nil; hoverPID = nil; focusedHoverWindow = nil
        drag = nil; draggedWindow = nil; consumedZoomDown = false; zoomFrames = [:]
        switcher.clear(); dock.clear()
        SpacesOrderController.restore()
    }
    private func observe() {
        guard active else { return }
        withObservationTracking {
            let p = WindowToolPreferences.shared
            _ = p.dockPreviewEnabled; _ = p.dockClickAction; _ = p.focusFollowsMouse
            _ = p.edgeSnapEnabled; _ = p.modifierDragEnabled; _ = p.fixedSpaces
            _ = p.previewImagesEnabled; _ = p.greenButtonMaximizes; _ = p.switcherEnabled; _ = p.excludedApps; _ = p.hoverDelay
        } onChange: {
            Task { @MainActor in
                guard WindowTools.shared.active else { return }
                WindowTools.shared.configure(); WindowTools.shared.observe()
                // Parent's shared input tap is optional. Asking it to re-evaluate uses its normal module gate.
                InputTools.shared.update()
            }
        }
    }
    private func configure() {
        guard active else { return }
        SpacesOrderController.setEnabled(WindowToolPreferences.shared.fixedSpaces)
        if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil
        let p = WindowToolPreferences.shared
        if !p.switcherEnabled { closeSwitcher(); switcher.clear() }
        if !p.dockPreviewEnabled { hoverTask?.cancel(); hoverPID = nil; dockPanel?.orderOut(nil); dock.clear() }
        if !p.focusFollowsMouse { focusTask?.cancel(); focusedHoverWindow = nil }
        if !p.modifierDragEnabled { drag = nil }
        if p.previewImagesEnabled { switcher.loadPreview(); dock.loadPreview() }
        else { switcher.clearPreview(); dock.clearPreview() }
        guard p.dockPreviewEnabled || p.dockClickAction != .none || p.focusFollowsMouse || p.edgeSnapEnabled || p.modifierDragEnabled else { return }
        guard Permission.accessibilityTrusted else { message = "Fenster- und Dock-Eingriffe brauchen Bedienungshilfen."; return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }
        message = nil
    }
    /// Re-evaluate after returning from the permission pane; no automatic permission prompt.
    func refreshPermissions() { if active { configure() } }

    func openSwitcher() {
        guard active, WindowToolPreferences.shared.switcherEnabled else {
            message = "Fensterwechsler zuerst in den Fensterwerkzeugen einschalten."; return
        }
        switcher.query = ""; switcher.reload()
        if switcherPanel == nil {
            switcherPanel = Self.panel(WindowToolListView(collection: switcher, dismiss: { WindowTools.shared.closeSwitcher() }), title: "Apps und Fenster", activating: true)
        }
        guard let panel = switcherPanel else { return }
        panel.center(); NSApp.activate(); panel.makeKeyAndOrderFront(nil)
    }
    func closeSwitcher() { switcherPanel?.orderOut(nil) }

    private func handle(_ event: NSEvent) {
        guard active, Permission.accessibilityTrusted else { return }
        let p = WindowToolPreferences.shared
        let location = NSEvent.mouseLocation
        let point = Self.axPoint(location)
        if event.type == .mouseMoved {
            guard Date.now.timeIntervalSince(lastMove) >= 0.08 else { return }
            lastMove = .now
            if let panel = dockPanel, panel.isVisible, panel.frame.contains(location) { return }
            if p.dockPreviewEnabled, let app = Self.dockApplication(at: point) {
                if hoverPID != app.processIdentifier {
                    hoverTask?.cancel(); hoverPID = app.processIdentifier
                    let pid = app.processIdentifier
                    hoverTask = Task {
                        try? await Task.sleep(for: .seconds(p.hoverDelay))
                        guard !Task.isCancelled, self.active, self.hoverPID == pid else { return }
                        self.showDock(pid: pid, at: location)
                    }
                }
            } else {
                hoverTask?.cancel(); hoverTask = nil; hoverPID = nil; dockPanel?.orderOut(nil); dock.clear()
            }
            if p.focusFollowsMouse { scheduleFocus(at: point) }
            return
        }
        if event.type == .leftMouseDown {
            if p.dockClickAction != .none, let app = Self.dockApplication(at: point), !p.excludes(app.bundleIdentifier) {
                dockMouseDownPID = app.processIdentifier
                dockWasFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
            } else { dockMouseDownPID = nil }
            if p.edgeSnapEnabled || p.modifierDragEnabled,
               let win = Self.window(at: point), !p.excludes(win.bundleID) {
                draggedWindow = win
            }
        } else if event.type == .leftMouseUp {
            if let pid = dockMouseDownPID, dockWasFrontmost, let app = NSRunningApplication(processIdentifier: pid) {
                performDockClick(app)
            }
            dockMouseDownPID = nil
            if p.edgeSnapEnabled, let win = draggedWindow, let currentFrame = WindowManager.frame(win.element),
               abs(currentFrame.minX - win.frame.minX) + abs(currentFrame.minY - win.frame.minY) > 8,
               let screen = NSScreen.screens.first(where: { WindowManager.axRect(of: $0).insetBy(dx: -12, dy: -12).contains(point) }),
               let target = WindowToolRules.edge(at: point, screen: WindowManager.axRect(of: screen)) {
                WindowManager.shared.set(win, to: RowlineMath.snap(target, in: WindowManager.axRect(of: screen, visible: true), gap: Prefs.shared.rowGap))
            }
            drag = nil; draggedWindow = nil
        }
    }

    private func performDockClick(_ app: NSRunningApplication) {
        dock.reload(pid: app.processIdentifier)
        switch WindowToolPreferences.shared.dockClickAction {
        case .none: break
        case .hide: app.hide()
        case .minimize:
            if let item = dock.items.first(where: { $0.element != nil && WindowManager.bool($0.element!, kAXMinimizedAttribute) != true }) { dock.minimize(item) }
        case .cycle:
            let windows = dock.items.filter { $0.element != nil }
            let index = WindowToolRules.nextIndex(current: dockCycle[app.processIdentifier], count: windows.count)
            if let index { dockCycle[app.processIdentifier] = index; dock.activate(windows[index]) }
        }
    }
    private func showDock(pid: pid_t, at point: CGPoint) {
        dock.reload(pid: pid)
        guard !dock.items.isEmpty else { return }
        dockPanel?.orderOut(nil)
        let panel = Self.panel(WindowToolListView(collection: dock, compact: true, dismiss: { WindowTools.shared.dockPanel?.orderOut(nil) }), title: "Dock-Fenster", activating: false)
        dockPanel = panel
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let x = max(visible.minX, min(visible.maxX - panel.frame.width, point.x - panel.frame.width / 2))
        let y = max(visible.minY, min(visible.maxY - panel.frame.height, point.y + 24))
        panel.setFrameOrigin(CGPoint(x: x, y: y)); panel.orderFrontRegardless()
    }
    private func scheduleFocus(at point: CGPoint) {
        guard let win = Self.window(at: point), !WindowToolPreferences.shared.excludes(win.bundleID),
              win.pid != ProcessInfo.processInfo.processIdentifier else { focusTask?.cancel(); focusedHoverWindow = nil; return }
        if let current = focusedHoverWindow, CFEqual(current, win.element) { return }
        focusTask?.cancel(); focusedHoverWindow = win.element
        focusTask = Task {
            try? await Task.sleep(for: .seconds(WindowToolPreferences.shared.hoverDelay))
            guard !Task.isCancelled, self.active, WindowToolPreferences.shared.focusFollowsMouse,
                  let current = Self.window(at: Self.axPoint(NSEvent.mouseLocation)), CFEqual(current.element, win.element) else { return }
            AXUIElementPerformAction(win.element, kAXRaiseAction as CFString)
            NSRunningApplication(processIdentifier: win.pid)?.activate()
        }
    }

    /// Called by the app's existing event tap. Consumes complete pointer gestures so Alt-drag never edits app content.
    func consumePointerEvent(type: CGEventType, event: CGEvent) -> Bool {
        guard active, Permission.accessibilityTrusted else { return false }
        if let drag, type == .leftMouseDragged {
            let point = event.location
            let origin = CGPoint(x: drag.original.minX + point.x - drag.origin.x, y: drag.original.minY + point.y - drag.origin.y)
            WindowManager.shared.set(drag.window, to: CGRect(origin: origin, size: drag.original.size))
            return true
        }
        if let drag, type == .leftMouseUp {
            if WindowToolPreferences.shared.edgeSnapEnabled,
               let screen = NSScreen.screens.first(where: { WindowManager.axRect(of: $0).insetBy(dx: -12, dy: -12).contains(event.location) }),
               let target = WindowToolRules.edge(at: event.location, screen: WindowManager.axRect(of: screen)) {
                WindowManager.shared.set(drag.window, to: RowlineMath.snap(target, in: WindowManager.axRect(of: screen, visible: true), gap: Prefs.shared.rowGap))
            }
            self.drag = nil
            return true
        }
        if type == .leftMouseDown, WindowToolPreferences.shared.modifierDragEnabled,
           event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]) == .maskAlternate,
           let win = Self.window(at: event.location), !WindowToolPreferences.shared.excludes(win.bundleID) {
            var settable = DarwinBoolean(false)
            guard AXUIElementIsAttributeSettable(win.element, kAXPositionAttribute as CFString, &settable) == .success, settable.boolValue else { return false }
            drag = (win, event.location, win.frame)
            return true
        }
        if type == .leftMouseUp, consumedZoomDown { consumedZoomDown = false; return true }
        guard needsZoomTap, type == .leftMouseDown,
              event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty,
              let hit = Self.element(at: event.location) else { return false }
        let subrole = WindowManager.string(hit, kAXSubroleAttribute)
        guard subrole == kAXZoomButtonSubrole as String || subrole == kAXFullScreenButtonSubrole as String,
              let win = Self.window(containing: hit), !WindowToolPreferences.shared.excludes(win.bundleID),
              let screen = NSScreen.screens.max(by: { WindowManager.axRect(of: $0).intersection(win.frame).windowToolArea < WindowManager.axRect(of: $1).intersection(win.frame).windowToolArea }) else { return false }
        var positionSettable = DarwinBoolean(false), sizeSettable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(win.element, kAXPositionAttribute as CFString, &positionSettable) == .success, positionSettable.boolValue,
              AXUIElementIsAttributeSettable(win.element, kAXSizeAttribute as CFString, &sizeSettable) == .success, sizeSettable.boolValue else { return false }
        let key = CFHash(win.element)
        if let previous = zoomFrames.removeValue(forKey: key) { WindowManager.shared.set(win, to: previous) }
        else { zoomFrames[key] = win.frame; WindowManager.shared.set(win, to: RowlineMath.snap(.full, in: WindowManager.axRect(of: screen, visible: true), gap: 0)) }
        consumedZoomDown = true
        return true
    }

    func consumeZoomClick(type: CGEventType, event: CGEvent) -> Bool { consumePointerEvent(type: type, event: event) }

    static func attribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value as AnyObject, to: AXUIElement.self)
    }
    private static func element(at point: CGPoint) -> AXUIElement? {
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &hit) == .success else { return nil }
        return hit
    }
    private static func axPoint(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x, y: (NSScreen.screens.first?.frame.height ?? 0) - point.y) }
    private static func window(at point: CGPoint) -> WindowManager.Win? { element(at: point).flatMap(window(containing:)) }
    private static func window(containing element: AXUIElement) -> WindowManager.Win? {
        var current: AXUIElement? = element
        for _ in 0..<10 {
            guard let node = current else { return nil }
            if WindowManager.string(node, kAXRoleAttribute) == kAXWindowRole as String,
               let frame = WindowManager.frame(node) {
                var pid: pid_t = 0; AXUIElementGetPid(node, &pid)
                guard let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular,
                      pid != ProcessInfo.processInfo.processIdentifier else { return nil }
                return WindowManager.Win(element: node, pid: pid, bundleID: app.bundleIdentifier ?? "", appPath: app.bundleURL?.path,
                                         title: WindowManager.string(node, kAXTitleAttribute) ?? "", frame: frame)
            }
            current = attribute(node, kAXParentAttribute)
        }
        return nil
    }
    private static func dockApplication(at point: CGPoint) -> NSRunningApplication? {
        guard let hit = element(at: point) else { return nil }
        var pid: pid_t = 0; AXUIElementGetPid(hit, &pid)
        guard NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.apple.dock" else { return nil }
        var current: AXUIElement? = hit
        for _ in 0..<8 {
            guard let node = current else { return nil }
            if WindowManager.string(node, kAXRoleAttribute) == kAXDockItemRole as String {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(node, kAXURLAttribute as CFString, &value) == .success,
                   let url = value as? URL, let id = Bundle(url: url)?.bundleIdentifier {
                    return NSRunningApplication.runningApplications(withBundleIdentifier: id).first
                }
                let title = WindowManager.string(node, kAXTitleAttribute)
                let matches = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.localizedName == title }
                return matches.count == 1 ? matches.first : nil
            }
            current = attribute(node, kAXParentAttribute)
        }
        return nil
    }
    private static func panel<Content: View>(_ content: Content, title: String, activating: Bool) -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: activating ? [.titled, .closable] : [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = title; panel.isReleasedWhenClosed = false; panel.hidesOnDeactivate = false
        panel.level = .floating; panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        let host = NSHostingView(rootView: content.themed().noInitialFocus())
        host.sizingOptions = []
        let preferred = host.fittingSize
        panel.contentView = host; panel.setContentSize(preferred)
        return panel
    }
}
