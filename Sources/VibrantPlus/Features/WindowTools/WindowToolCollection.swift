// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ApplicationServices
import Observation
import ScreenCaptureKit
import SwiftUI
import VibrantPlusKit

struct WindowToolItem: Identifiable {
    let app: NSRunningApplication
    let element: AXUIElement?
    let title: String
    let frame: CGRect?
    var id: String { "\(app.processIdentifier):\(element.map { CFHash($0) } ?? 0)" }
    var appName: String { app.localizedName ?? "App" }
    var windowName: String { title.isEmpty ? appName : title }
}

@Observable
final class WindowToolCollection {
    var query = ""
    var currentDisplayOnly = false
    var selection: String?
    private(set) var items: [WindowToolItem] = []
    private(set) var preview: NSImage?
    private(set) var previewMessage: String?
    @ObservationIgnored private var previewTask: Task<Void, Never>?
    @ObservationIgnored private var previousFrames: [String: CGRect] = [:]
    @ObservationIgnored var limitToPID: pid_t?

    var visible: [WindowToolItem] {
        items.filter { item in
            guard WindowToolRules.matches(query: query, app: item.appName, title: item.title) else { return false }
            if currentDisplayOnly, let frame = item.frame, let screen = NSScreen.withMouse {
                return WindowManager.axRect(of: screen).intersects(frame)
            }
            return true
        }
    }
    var selected: WindowToolItem? { visible.first { $0.id == selection } ?? visible.first }

    func reload(pid: pid_t? = nil) {
        limitToPID = pid
        let own = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != own
            && (pid == nil || $0.processIdentifier == pid)
            && !WindowToolPreferences.shared.excludes($0.bundleIdentifier)
        }
        items = apps.flatMap { app -> [WindowToolItem] in
            if Permission.accessibilityTrusted {
                let element = AXUIElementCreateApplication(app.processIdentifier)
                AXUIElementSetMessagingTimeout(element, 0.15)
                let windows = WindowManager.array(element, kAXWindowsAttribute).filter {
                    WindowManager.string($0, kAXSubroleAttribute) == kAXStandardWindowSubrole as String
                }
                if !windows.isEmpty {
                    return windows.map { WindowToolItem(app: app, element: $0, title: WindowManager.string($0, kAXTitleAttribute) ?? "", frame: WindowManager.frame($0)) }
                }
            }
            return [WindowToolItem(app: app, element: nil, title: "", frame: nil)]
        }.sorted { ($0.appName, $0.windowName) < ($1.appName, $1.windowName) }
        if !visible.contains(where: { $0.id == selection }) { selection = visible.first?.id }
        loadPreview()
    }

    func loadPreview() {
        previewTask?.cancel(); preview = nil; previewMessage = nil
        guard WindowToolPreferences.shared.previewImagesEnabled else { return }
        guard ScreenCapture.allowed else { previewMessage = "Fensterbilder brauchen Bildschirmaufnahme. Die App-Liste funktioniert ohne diese Freigabe."; return }
        guard let selected, selected.element != nil else { return }
        let selectedID = selected.id
        previewTask = Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                guard !Task.isCancelled else { return }
                let matches = content.windows.filter { $0.owningApplication?.processID == selected.app.processIdentifier && ($0.title ?? "") == selected.title }
                let window: SCWindow?
                if matches.count == 1 { window = matches.first }
                else if let frame = selected.frame {
                    window = matches.min { Self.distance($0.frame, frame) < Self.distance($1.frame, frame) }
                } else { window = nil }
                guard let window, window.frame.width > 0, window.frame.height > 0 else {
                    previewMessage = "Dieses Fenster ist nicht sichtbar oder minimiert."; return
                }
                let config = SCStreamConfiguration()
                let scale = min(640 / window.frame.width, 400 / window.frame.height)
                config.width = max(1, Int(window.frame.width * scale))
                config.height = max(1, Int(window.frame.height * scale))
                config.showsCursor = false
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                guard !Task.isCancelled, self.selected?.id == selectedID else { return }
                preview = NSImage(cgImage: image, size: .zero)
            } catch {
                guard !Task.isCancelled else { return }
                previewMessage = "Fenstervorschau gerade nicht verfügbar."
            }
        }
    }
    private static func distance(_ a: CGRect, _ b: CGRect) -> CGFloat { abs(a.minX - b.minX) + abs(a.minY - b.minY) + abs(a.width - b.width) + abs(a.height - b.height) }
    func clearPreview() { previewTask?.cancel(); previewTask = nil; preview = nil; previewMessage = nil }
    func clear() { clearPreview(); items = []; previousFrames = [:] }
    func activate(_ item: WindowToolItem) {
        item.app.unhide()
        if let window = item.element {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
        item.app.activate()
    }
    func minimize(_ item: WindowToolItem) {
        guard let window = item.element else { return }
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }
    func close(_ item: WindowToolItem) {
        guard let window = item.element, let button = WindowTools.attribute(window, kAXCloseButtonAttribute) else { return }
        // Standard close preserves the application's own save prompts.
        AXUIElementPerformAction(button, kAXPressAction as CFString)
    }
    func snap(_ item: WindowToolItem, to snap: RowlineMath.Snap) {
        guard let window = item.element, let frame = item.frame else { return }
        let screen = NSScreen.screens.max { WindowManager.axRect(of: $0).intersection(frame).windowToolArea < WindowManager.axRect(of: $1).intersection(frame).windowToolArea }
        guard let screen else { return }
        previousFrames[item.id] = frame
        let win = WindowManager.Win(element: window, pid: item.app.processIdentifier, bundleID: item.app.bundleIdentifier ?? "", appPath: item.app.bundleURL?.path, title: item.title, frame: frame)
        WindowManager.shared.set(win, to: RowlineMath.snap(snap, in: WindowManager.axRect(of: screen, visible: true), gap: Prefs.shared.rowGap))
    }
    func restore(_ item: WindowToolItem) {
        guard let window = item.element, let previous = previousFrames.removeValue(forKey: item.id) else { return }
        if let frame = item.frame { previousFrames[item.id] = frame }
        let win = WindowManager.Win(element: window, pid: item.app.processIdentifier, bundleID: item.app.bundleIdentifier ?? "", appPath: item.app.bundleURL?.path, title: item.title, frame: previous)
        WindowManager.shared.set(win, to: previous)
    }
    func moveToNextDisplay(_ item: WindowToolItem) {
        guard let window = item.element, let frame = item.frame, NSScreen.screens.count > 1 else { return }
        let current = NSScreen.screens.max { WindowManager.axRect(of: $0).intersection(frame).windowToolArea < WindowManager.axRect(of: $1).intersection(frame).windowToolArea }
        guard let current, let index = NSScreen.screens.firstIndex(where: { $0 === current }) else { return }
        let target = NSScreen.screens[(index + 1) % NSScreen.screens.count]
        previousFrames[item.id] = frame
        let win = WindowManager.Win(element: window, pid: item.app.processIdentifier, bundleID: item.app.bundleIdentifier ?? "", appPath: item.app.bundleURL?.path, title: item.title, frame: frame)
        WindowManager.shared.set(win, to: WindowToolRules.movedToNextDisplay(frame: frame, from: WindowManager.axRect(of: current, visible: true), to: WindowManager.axRect(of: target, visible: true)))
    }
}

struct WindowToolListView: View {
    @Bindable var collection: WindowToolCollection
    var compact = false
    var dismiss: () -> Void
    var body: some View {
        VStack(spacing: Space.sm) {
            if !compact {
                HStack {
                    TextField("Apps und Fenster suchen", text: $collection.query)
                    Toggle("Dieser Bildschirm", isOn: $collection.currentDisplayOnly)
                    Button("Aktualisieren", systemImage: "arrow.clockwise") { collection.reload() }.labelStyle(.iconOnly)
                }
            }
            HStack(alignment: .top, spacing: Space.md) {
                List(collection.visible, selection: $collection.selection) { item in
                    HStack(spacing: Space.sm) {
                        if let icon = item.app.icon { Image(nsImage: icon).resizable().scaledToFit().frame(width: 24, height: 24) }
                        VStack(alignment: .leading) {
                            Text(item.windowName).lineLimit(1)
                            if !item.title.isEmpty { Text(item.appName).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Button { collection.activate(item); dismiss() } label: { Image(systemName: "arrow.up.forward.app") }
                            .buttonStyle(.borderless).help("Fenster öffnen")
                    }
                    .tag(item.id)
                    .onTapGesture(count: 2) { collection.activate(item); dismiss() }
                    .contextMenu {
                        Button("Öffnen") { collection.activate(item); dismiss() }
                        Button("Minimieren") { collection.minimize(item) }.disabled(item.element == nil)
                        Button("Fenster schliessen") { collection.close(item) }.disabled(item.element == nil)
                        Divider()
                        Button("Links anordnen") { collection.snap(item, to: .left) }.disabled(item.element == nil)
                        Button("Rechts anordnen") { collection.snap(item, to: .right) }.disabled(item.element == nil)
                        Button("Links zwei Drittel") { collection.snap(item, to: .leftTwoThirds) }.disabled(item.element == nil)
                        Button("Rechts zwei Drittel") { collection.snap(item, to: .rightTwoThirds) }.disabled(item.element == nil)
                        Button("Bildschirm ausfüllen") { collection.snap(item, to: .full) }.disabled(item.element == nil)
                        Button("Zentrieren") { collection.snap(item, to: .center) }.disabled(item.element == nil)
                        Button("Auf den nächsten Bildschirm") { collection.moveToNextDisplay(item) }.disabled(item.element == nil || NSScreen.screens.count < 2)
                        Button("Vorherige Grösse") { collection.restore(item) }.disabled(item.element == nil)
                    }
                }
                .listStyle(.plain)
                if WindowToolPreferences.shared.previewImagesEnabled {
                    VStack {
                        if let preview = collection.preview { Image(nsImage: preview).resizable().scaledToFit() }
                        else { ContentUnavailableView(collection.previewMessage ?? "Keine Fenstervorschau", systemImage: "macwindow") }
                    }.frame(width: compact ? 240 : 320)
                }
            }
            if collection.visible.isEmpty { Text("Keine passenden Apps oder Fenster.").foregroundStyle(.secondary) }
            if !Permission.accessibilityTrusted { Text("Ohne Bedienungshilfen werden Apps statt einzelner Fenster angezeigt.").font(.caption).foregroundStyle(.secondary) }
            if !compact, let selected = collection.selected {
                HStack {
                    Text("\(collection.visible.count) Einträge").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Öffnen") { collection.activate(selected); dismiss() }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(Space.md)
        .frame(width: compact ? (WindowToolPreferences.shared.previewImagesEnabled ? 600 : 360) : 760, height: compact ? 240 : 440)
        .onChange(of: collection.selection) { collection.loadPreview() }
        .onExitCommand { dismiss() }
    }
}

extension CGRect {
    var windowToolArea: CGFloat { isNull ? 0 : width * height }
}
