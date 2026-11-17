// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

struct VibrantPlusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
        } label: {
            Image(nsImage: VibrantMark.menuBarImage())
                .accessibilityLabel("Vibrant+")
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Vibrant+ has no Dock icon, so its windows are AppKit windows hosting SwiftUI,
/// opened from the menu, the island and hot keys alike.
@MainActor
enum Windows {
    enum Kind: String {
        case welcome, today, agent, settings, clipboard, scratchpad, imageEditor, camera

        var title: String {
            switch self {
            case .camera: "Kamera-Spiegel"
            case .imageEditor: "Bild bearbeiten"
            case .scratchpad: "Notizblock"
            case .welcome: "Willkommen bei Vibrant+"
            case .today: "Heute"
            case .agent: "Claude Code"
            case .settings: "Vibrant+ Einstellungen"
            case .clipboard: "Zwischenablage"
            }
        }
    }

    private static var open: [Kind: NSWindow] = [:]
    private static let delegate = WindowDelegate()

    static func show(_ kind: Kind) {
        if let w = open[kind] {
            NSApp.activate()
            w.makeKeyAndOrderFront(nil)
            return
        }
        let root: AnyView = switch kind {
        case .camera: AnyView(CameraPreviewView())
        case .imageEditor: AnyView(ImageEditorView())
        case .scratchpad: AnyView(ScratchpadView())
        case .welcome: AnyView(WelcomeView())
        case .today: AnyView(IslandSurface { TodayView().padding(Space.margin) })
        case .agent: AnyView(AgentPanelView().frame(minWidth: 820, minHeight: 460))
        case .settings: AnyView(SettingsRoot())
        case .clipboard: AnyView(ClipboardView())
        }
        let host = NSHostingController(rootView: root.themed().noInitialFocus())
        let w = NSWindow(contentViewController: host)
        w.title = kind == .settings ? SettingsRoot.initialPage.title : kind.title
        w.identifier = NSUserInterfaceItemIdentifier(kind.rawValue)
        w.isReleasedWhenClosed = false
        w.delegate = delegate
        switch kind {
        case .agent:
            w.styleMask.insert(.resizable)
            // The preferred size, but never more than the display offers (13" Air at
            // «Larger Text» has about 1024 × 610 points to spare below the menu bar).
            let room = (NSScreen.withMouse?.visibleFrame.size ?? NSSize(width: 980, height: 600))
            w.setContentSize(NSSize(width: min(980, room.width - 40), height: min(600, room.height - 60)))
            w.setFrameAutosaveName("agent")
        case .welcome:
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.styleMask.insert(.fullSizeContentView)
            w.styleMask.remove(.miniaturizable)
        case .settings:
            w.toolbarStyle = .unified
            w.styleMask.remove(.miniaturizable)
        case .today, .clipboard, .scratchpad, .imageEditor, .camera:
            if kind == .clipboard { w.styleMask.insert(.resizable) }
            if kind == .camera { w.setContentSize(NSSize(width: 360, height: 270)) }
        }
        open[kind] = w
        w.center()
        NSApp.activate()
        w.makeKeyAndOrderFront(nil)
    }

    static func close(_ kind: Kind) { open[kind]?.close() }
    static func isOpen(_ kind: Kind) -> Bool { open[kind] != nil }

    static func retitle(_ kind: Kind, _ title: String) { open[kind]?.title = title }

    fileprivate static func closed(_ w: NSWindow) {
        guard let id = w.identifier?.rawValue, let kind = Kind(rawValue: id) else { return }
        open[kind] = nil
        if kind == .camera { MirrorCamera.shared.stopIfUnused() }
    }

    final class WindowDelegate: NSObject, NSWindowDelegate {
        func windowWillClose(_ notification: Notification) {
            guard let w = notification.object as? NSWindow else { return }
            MainActor.assumeIsolated { Windows.closed(w) }
        }
    }
}

@MainActor
enum AppActions {
    static func openSettings(_ page: SettingsPage? = nil) {
        if let page { SettingsNavigation.shared.page = page }
        Windows.show(.settings)
    }
    static func openAgentPanel() { Windows.show(.agent) }
    static func openToday() { Windows.show(.today) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if let dir = SnapshotRunner.requestedDirectory {
            SnapshotRunner.run(into: dir)
            return
        }
        #endif
        if SelfTest.requested {
            SelfTest.run()
            return
        }
        // A second copy would fight with this one over the agent socket and the global
        // shortcuts, and the copy that loses registers no hot key at all. LaunchServices
        // refuses a second launch; this catches copies started by path. A copy that is only
        // still shutting down (relaunch after an update) gets a moment before this one steps aside.
        if Self.otherCopyIsRunning {
            Task { @MainActor in
                for _ in 0..<15 {
                    if !Self.otherCopyIsRunning { Coordinator.shared.start(); return }
                    try? await Task.sleep(for: .milliseconds(100))
                }
                NSRunningApplication.runningApplications(withBundleIdentifier: "ch.arjo.vibrantplus")
                    .first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }?
                    .activate()
                NSApp.terminate(nil)
            }
            return
        }
        Coordinator.shared.start()
    }

    private static var otherCopyIsRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: "ch.arjo.vibrantplus")
            .contains { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Coordinator.shared.stopAll()
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// Island colors and color scheme as a live surface (Today window).
struct IslandSurface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.background(IslandColor.background).environment(\.colorScheme, IslandColor.scheme)
    }
}
