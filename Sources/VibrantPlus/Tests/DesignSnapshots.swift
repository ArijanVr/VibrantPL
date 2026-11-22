// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

#if DEBUG
import AppKit
import SwiftUI
import VibrantPlusKit

/// Renders only the island, in every look, over a busy ground so glass and legibility can be judged.
///   APP_DATA=/tmp/vp-design APP_SNAPSHOT_SCOPE=island VibrantPlus --snapshot <dir>
/// Windows are ordered behind everything and never take the focus.
@MainActor
enum DesignSnapshots {
    private struct Look {
        let name: String
        let style: IslandStyle
        let dark: Bool
    }

    private static let looks = [
        Look(name: "black", style: .notch, dark: true),
        Look(name: "glass-light", style: .glass, dark: false),
        Look(name: "glass-dark", style: .glass, dark: true),
    ]

    static func run(into dir: URL) async {
        let island = IslandModel.shared, prefs = Prefs.shared
        CurrencyRates.shared.loadSample()
        ColorSamples.shared.loadSample()
        prefs.modules.formUnion([.island, .agent, .today, .assistant, .downloads, .screenshots, .stow])
        prefs.tilesOn = Set(TileKind.allCases)
        // Pulsi would cover the lower right corner in every picture.
        prefs.mascot = false

        for look in looks {
            IslandTheme.shared.style = look.style
            island.isOpen = true
            for page in IslandModel.Page.available {
                island.page = page
                await shot("\(look.name)-page-\(page.rawValue)", dir, dark: look.dark)
            }
            // Every tile once: two at a time, so none hides behind the scroll edge.
            for page in [IslandModel.Page.home, .mac, .ai, .tools] {
                guard let category = page.category else { continue }
                prefs.tilesOn = Set(TileKind.allCases)
                let tiles = prefs.visibleTiles(in: category)
                for start in stride(from: 0, to: tiles.count, by: 2) {
                    prefs.tilesOn = Set(tiles[start..<min(start + 2, tiles.count)])
                    island.page = page
                    await shot("\(look.name)-tiles-\(page.rawValue)-\(start)", dir, dark: look.dark)
                }
            }
            prefs.tilesOn = Set(TileKind.allCases)
            island.page = .home
            island.arranging = true
            await shot("\(look.name)-arrange", dir, dark: look.dark)
            island.arranging = false
            island.dragging = true
            await shot("\(look.name)-drop", dir, dark: look.dark)
            island.dragging = false
            AgentStore.shared.loadSamplePending()
            await shot("\(look.name)-permission", dir, dark: look.dark)
            AgentStore.shared.loadSamplePending(question: true)
            await shot("\(look.name)-question", dir, dark: look.dark)
            AgentStore.shared.clearSample()
            AgentStore.shared.loadSample()
            AppUpdater.shared.loadSample()
            await shot("\(look.name)-update", dir, dark: look.dark)
            AppUpdater.shared.clearSample()
            island.isOpen = false
            island.near = true
            await shot("\(look.name)-closed-near", dir, dark: look.dark)
            island.near = false
            island.show(Toast(symbol: "checkmark.circle", text: "fertig"), seconds: 30)
            await shot("\(look.name)-closed-toast", dir, dark: look.dark)
            island.toast = nil
        }
        await edgeCases(into: dir)
    }

    /// What the plain pages do not show: wide and narrow notches, other navigation, accessibility, light.
    private static func edgeCases(into dir: URL) async {
        let island = IslandModel.shared, prefs = Prefs.shared, theme = IslandTheme.shared
        theme.style = .glass
        island.isOpen = true
        island.page = .tools
        island.notchSize = CGSize(width: 220, height: 38) // grid: ok a real notch size
        await shot("edge-wide-notch", dir, dark: true)
        island.notchSize = CGSize(width: 185, height: 32) // grid: ok a real notch size
        var custom = IslandNavigation()
        custom.order = ["home", "mac", "files", "ai", "tools", "today", "claude", "downloads", "assistant"]
        custom.hidden = ["assistant"]
        prefs.islandNavigation = custom
        await shot("edge-custom-order", dir, dark: true)
        await shot("edge-hovered-tab", dir, dark: true) { _, _ in island.hoveredPage = .downloads }
        island.hoveredPage = nil
        custom.placement = .aboveTiles
        custom.labels = .all
        prefs.islandNavigation = custom
        await shot("edge-tabs-above", dir, dark: true)
        prefs.islandNavigation = IslandNavigation()
        theme.setReduceTransparency(true)
        await shot("edge-reduce-transparency", dir, dark: false)
        theme.setReduceTransparency(false)
        theme.setIncreaseContrast(true)
        await shot("edge-increase-contrast", dir, dark: false)
        theme.setIncreaseContrast(false)

        // The widest permission card: voice, automatic files and «Immer erlauben» together.
        prefs.modules.insert(.voice)
        let event = HookEvent(sessionID: "demo", eventName: "PermissionRequest", cwd: "/private/tmp/projekt", toolName: "Write",
                              toolInput: .object(["file_path": .string("/private/tmp/projekt/Neu.swift"), "content": .string("let x = 1")]),
                              permissionSuggestions: .array([.object(["type": .string("setMode")])]))
        let pending = AgentStore.Pending(id: "design", event: event, received: .now, expires: .now.addingTimeInterval(50)) { _ in }
        await shot("edge-permission-widest", dir, dark: true,
                   content: AgentRequestCard(pending: pending)
                       .frame(width: Metrics.islandCardWidth - Metrics.islandPadding * 2)
                       .background(Color(hex: Brand.black))
                       .environment(\.colorScheme, .dark))
        prefs.modules.remove(.voice)

        // A list under the pointer scrolls; a swipe there must not close the island.
        prefs.tilesOn = [.quitApps]
        island.page = .mac
        await shot("edge-scroll-list", dir, dark: true) { host, window in
            let middle = CGPoint(x: window.frame.width / 2, y: window.frame.height - 112)
            let edge = CGPoint(x: 12, y: 12)
            print("SCROLL list=\(IslandController.scrollsVertically(at: middle, in: host)) outside=\(IslandController.scrollsVertically(at: edge, in: host))")
        }
        prefs.tilesOn = Set(TileKind.allCases)

        // The light on an island with nothing to show, and on the open one.
        island.page = .home
        await shot("edge-glow-open", dir, dark: true) { _, _ in GlowCenter.shared.fire() }
        island.isOpen = false
        AgentStore.shared.clearSample()
        await shot("edge-glow-idle", dir, dark: true) { _, _ in GlowCenter.shared.fire() }
    }

    /// The Settings window as people see it, then every page at its full height.
    ///   APP_SNAPSHOT_SCOPE=settings
    static func settings(into dir: URL) async {
        let prefs = Prefs.shared
        prefs.onboarded = true
        // What one real person has switched on, then everything.
        let everyday: Set<Module> = [.today, .island, .keepAwakeRules, .appUpdates, .downloads, .clipboard, .stow, .screenshots,
                                     .assistant, .links, .systemMonitor, .cleaner, .cleaning, .agent]
        for (name, modules) in [("everyday", everyday), ("all", Set(Module.allCases))] {
            prefs.modules = modules
            for dark in [false, true] {
                SettingsNavigation.shared.page = .general
                await window("settings-\(name)-\(dark ? "dark" : "light")", dir, dark: dark,
                             size: CGSize(width: 760, height: 560), titled: true) { SettingsRoot() }
            }
        }
        for page in SettingsPage.allCases {
            await window("page-\(page.rawValue)", dir, dark: false, size: CGSize(width: 570, height: 1600), titled: false) {
                SettingsPageView(page: page).frame(width: 570).fixedSize(horizontal: false, vertical: true)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private static func window<V: View>(_ name: String, _ dir: URL, dark: Bool, size: CGSize, titled: Bool,
                                        @ViewBuilder content: () -> V) async {
        let host = NSHostingView(rootView: content().themed().environment(\.colorScheme, dark ? .dark : .light).noInitialFocus())
        host.sizingOptions = []
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: titled ? [.titled, .closable, .fullSizeContentView] : [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = "Vibrant+ Einstellungen"
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.backgroundColor = dark ? NSColor(white: 0.12, alpha: 1) : .windowBackgroundColor
        window.contentView = host
        window.center()
        window.orderBack(nil)
        try? await Task.sleep(for: .milliseconds(900))
        let file = dir.appending(path: "\(name).png").path
        let result = await Run.async("/usr/sbin/screencapture", ["-x", "-o", "-l", String(window.windowNumber), file], timeout: 5)
        if result.status != 0 { print("SNAPSHOT failed: \(name)") }
        window.orderOut(nil)
    }

    private static func shot(_ name: String, _ dir: URL, dark: Bool,
                             before: ((NSView, NSWindow) -> Void)? = nil) async {
        await shot(name, dir, dark: dark, content: IslandRoot(), before: before)
    }

    private static func shot<V: View>(_ name: String, _ dir: URL, dark: Bool, content: V,
                                      before: ((NSView, NSWindow) -> Void)? = nil) async {
        let size = CGSize(width: 720, height: 360)
        let view = ZStack(alignment: .top) {
            BusyGround()
            content
        }
        .frame(width: size.width, height: size.height)
        .themed()
        .environment(\.colorScheme, dark ? .dark : .light)
        .noInitialFocus()
        let host = NSHostingView(rootView: view)
        host.sizingOptions = []
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host
        window.center()
        window.orderBack(nil)
        try? await Task.sleep(for: .milliseconds(750))
        GridProbes.shared.write(to: dir.appending(path: "\(name)-layout.json").path, window: size)
        if let before {
            before(host, window)
            try? await Task.sleep(for: .milliseconds(120))
        }
        let file = dir.appending(path: "\(name).png").path
        let result = await Run.async("/usr/sbin/screencapture", ["-x", "-o", "-l", String(window.windowNumber), file], timeout: 5)
        if result.status != 0 { print("SNAPSHOT failed: \(name)") }
        window.orderOut(nil)
    }
}

/// The worst case for glass: a white document with small text on one side, a dark saturated picture on the other.
private struct BusyGround: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            let half = size.width / 2
            context.fill(Path(CGRect(x: half, y: 0, width: half, height: size.height)),
                         with: .linearGradient(Gradient(colors: [.indigo, .black, .orange]),
                                               startPoint: CGPoint(x: half, y: 0), endPoint: CGPoint(x: size.width, y: size.height)))
            for y in stride(from: CGFloat(8), to: size.height, by: 20) {
                context.draw(Text("Dokument mit kleiner Schrift, Zeile für Zeile").font(.system(size: 13)).foregroundStyle(.black),
                             at: CGPoint(x: 8, y: y), anchor: .leading)
            }
            context.fill(Path(ellipseIn: CGRect(x: half + 64, y: 48, width: 160, height: 160)), with: .color(.yellow))
        }
    }
}
#endif
