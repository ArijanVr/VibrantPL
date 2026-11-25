// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

#if DEBUG
import AppKit
import SwiftUI

/// Renders every screen to PNG, then quits.
///   APP_DATA=/tmp/vp-snap VibrantPlus --snapshot /tmp/VibrantPlus-shots
/// Uses sample data in APP_DATA; refuses to run on the real data folder.
@MainActor
enum SnapshotRunner {
    static var requestedDirectory: URL? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), args.indices.contains(i + 1) else { return nil }
        return URL(fileURLWithPath: args[i + 1], isDirectory: true)
    }

    static func run(into dir: URL) {
        guard Paths.isOverridden, Paths.dataDirectory.path.hasPrefix("/tmp") || Paths.dataDirectory.path.hasPrefix("/private/tmp") else {
            print("SNAPSHOT refused: set APP_DATA to a folder in /tmp")
            exit(1)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        TodayStore.shared.loadSample()
        AgentStore.shared.loadSample()
        NowPlaying.shared.loadSample()
        WeatherService.shared.loadSample()
        CalendarService.shared.loadSample()
        UsageStore.shared.loadSample()
        RemindersService.shared.loadSample()
        IslandModel.shared.notchSize = CGSize(width: 200, height: 32)
        IslandModel.shared.hasNotch = true

        Task {
            if ProcessInfo.processInfo.environment["APP_SNAPSHOT_SCOPE"] == "settings" {
                await DesignSnapshots.settings(into: dir)
                print("SNAPSHOT settings wrote \(dir.path)")
                fflush(stdout)
                exit(0)
            }
            if ProcessInfo.processInfo.environment["APP_SNAPSHOT_SCOPE"] == "island" {
                await DesignSnapshots.run(into: dir)
                print("SNAPSHOT island wrote \(dir.path)")
                fflush(stdout)
                // No terminate: nothing was started, so there is nothing to stop or restore.
                exit(0)
            }
            if ProcessInfo.processInfo.environment["APP_SNAPSHOT_SCOPE"] == "setup" {
                for dark in [false, true] {
                    let mode = dark ? "dark" : "light"
                    for step in 0...3 {
                        await shot(WelcomeView(previewStep: step), "welcome-\(step)-\(mode)", dir, size: CGSize(width: 560, height: 600), dark: dark)
                    }
                    SettingsNavigation.shared.page = .features
                    await shot(SettingsRoot(), "settings-navigation-\(mode)", dir, size: CGSize(width: 760, height: 560), dark: dark)
                    for page in [SettingsPage.general, .features, .clipboard, .links, .appGrid, .devBar, .permissions, .shortcuts] {
                        await shot(NavigationStack { SettingsPageView(page: page).navigationTitle(page.title) }.frame(width: 570, height: 560), // grid: ok same detail width as existing snapshots
                                   "settings-\(page.rawValue)-\(mode)", dir, size: CGSize(width: 570, height: 560), dark: dark) // grid: ok existing detail-column width
                    }
                }
                print("SNAPSHOT setup wrote \(dir.path)")
                NSApp.terminate(nil)
                return
            }
            // Island states (always dark). Pulsi sits at his default place, whatever the person chose; restored at the end.
            let mascotAtStart = (Prefs.shared.mascotX, Prefs.shared.mascotY)
            (Prefs.shared.mascotX, Prefs.shared.mascotY) = (-24, 30)
            let island = IslandModel.shared
            island.isOpen = true
            island.page = .home
            await shot(IslandRoot(), "island-home", dir, size: CGSize(width: 760, height: 330), dark: true)
            // Every tile on: the tile pages (Mac, KI, Werkzeuge) next to Start.
            let tilesAtStart = Prefs.shared.tilesOn
            Prefs.shared.tilesOn = Set(TileKind.allCases)
            await shot(IslandRoot(), "island-home-all-on", dir, size: CGSize(width: 760, height: 328), dark: true)
            for page in [IslandModel.Page.mac, .ai, .tools] {
                island.page = page
                await shot(IslandRoot(), "island-page-\(page.rawValue)", dir, size: CGSize(width: 760, height: 328), dark: true)
            }
            island.page = .home
            Prefs.shared.tilesOn = tilesAtStart
            IslandTheme.shared.setIncreaseContrast(true)
            await shot(IslandRoot(), "island-home-contrast", dir, size: CGSize(width: 760, height: 328), dark: true)
            IslandTheme.shared.setIncreaseContrast(NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)
            island.page = .today
            await shot(IslandRoot(), "island-today", dir, size: CGSize(width: 760, height: 330), dark: true)
            island.page = .claude
            await shot(IslandRoot(), "island-claude", dir, size: CGSize(width: 760, height: 330), dark: true)
            island.page = .files
            await shot(IslandRoot(), "island-files", dir, size: CGSize(width: 760, height: 330), dark: true)
            island.page = .downloads
            await shot(IslandRoot(), "island-downloads", dir, size: CGSize(width: 760, height: 330), dark: true)
            // Tiles that sit past the first screen of the strip (smallest text in the island).
            await shot(HStack(alignment: .top, spacing: Space.sm) { ClockTile(); SystemTile(); ControlsTile() }
                        .padding(Space.md).background(IslandColor.background).environment(\.colorScheme, IslandColor.scheme),
                       "island-tiles-small", dir, size: CGSize(width: 760, height: 180), dark: true)
            await shot(HStack(alignment: .top, spacing: Space.sm) { WeatherTile(); NextEventTile(); TimerTile(); RecentAppsTile() }
                        .padding(Space.md).background(IslandColor.background).environment(\.colorScheme, IslandColor.scheme),
                       "island-tiles-more", dir, size: CGSize(width: 760, height: 180), dark: true)
            CurrencyRates.shared.loadSample()
            ColorSamples.shared.loadSample()
            await shot(HStack(alignment: .top, spacing: Space.sm) { QuickNoteTile(); ConverterTile(); ColorPickerTile() }
                        .padding(Space.md).background(IslandColor.background).environment(\.colorScheme, IslandColor.scheme),
                       "island-tiles-new", dir, size: CGSize(width: 760, height: 180), dark: true)
            await shot(HStack(alignment: .top, spacing: Space.sm) { MirrorTile(); WeatherTile() }
                        .padding(Space.md).background(IslandColor.background).environment(\.colorScheme, IslandColor.scheme),
                       "island-tiles-mirror", dir, size: CGSize(width: 760, height: 180), dark: true)
            // The AI ring and Apple Reminders arrived in 3.5.
            await shot(HStack(alignment: .top, spacing: Space.sm) { UsageTile(); RemindersTile(); WeatherTile() }
                        .padding(Space.md).background(IslandColor.background).environment(\.colorScheme, IslandColor.scheme),
                       "island-tiles-ai", dir, size: CGSize(width: 760, height: 180), dark: true)
            // 1.0: quit apps, meetings, the controls with the recorder, and the arrange mode.
            await shot(HStack(alignment: .top, spacing: Space.sm) { QuitAppsTile(); MeetingTile(); ControlsTile() }
                        .padding(Space.md).background(IslandColor.background).environment(\.colorScheme, IslandColor.scheme),
                       "island-tiles-v1", dir, size: CGSize(width: 960, height: 180), dark: true)
            island.page = .home
            island.arranging = true
            await shot(IslandRoot(), "island-arrange", dir, size: CGSize(width: 760, height: 330), dark: true)
            island.arranging = false
            // More tiles than fit: the strip shows a soft edge, arrows and a thin scroll line.
            let tilesBefore = Prefs.shared.tilesOn
            Prefs.shared.tilesOn = Set(TileKind.allCases)
            await shot(IslandRoot(), "island-strip", dir, size: CGSize(width: 760, height: 332), dark: true)
            Prefs.shared.tilesOn = tilesBefore
            AgentStore.shared.loadSamplePending()
            await shot(IslandRoot(), "island-permission", dir, size: CGSize(width: 760, height: 260), dark: true)
            AgentStore.shared.loadSamplePending(count: 3)
            await shot(IslandRoot(), "island-permission-queue", dir, size: CGSize(width: 760, height: 260), dark: true)
            AgentStore.shared.loadSamplePending(question: true)
            await shot(IslandRoot(), "island-question", dir, size: CGSize(width: 760, height: 260), dark: true)
            AgentStore.shared.clearSample()
            AgentStore.shared.loadSample()
            if let sample = makeSampleImage() {
                StowModel.shared.load([sample])
                await shot(IslandRoot(), "island-stow", dir, size: CGSize(width: 760, height: 260), dark: true)
                StowModel.shared.clear()
            }
            if Assistant.isAvailable {
                Assistant.shared.ask("Was kannst du für mich tun? Antworte in zwei Sätzen.", speak: false)
                for _ in 0..<150 where Assistant.shared.busy { try? await Task.sleep(for: .milliseconds(100)) }
                await shot(IslandRoot(), "island-assistant", dir, size: CGSize(width: 760, height: 380), dark: true)
                Assistant.shared.visible = false
            }
            let d = Paths.dataDirectory
            if let v1 = await SelfTest.makeVideo(d.appending(path: "Ferien Teil 1.mov"), seconds: 1),
               let v2 = await SelfTest.makeVideo(d.appending(path: "Ferien Teil 2.mov"), seconds: 1) {
                StowModel.shared.load([v1, v2])
                await shot(IslandRoot(), "island-stow-videos", dir, size: CGSize(width: 760, height: 330), dark: true)
                StowModel.shared.clear()
            }
            island.dragging = true
            await shot(IslandRoot(), "island-drop", dir, size: CGSize(width: 760, height: 260), dark: true)
            island.dragging = false
            island.isOpen = false
            island.show(Toast(symbol: "sparkle", text: "arbeitet"), seconds: 30)
            await shot(IslandRoot(), "island-closed", dir, size: CGSize(width: 420, height: 40), dark: true)
            // A long note widens both wings so it stays readable.
            island.show(Toast(symbol: "sparkles", text: "Für die nächste Nachricht an Claude"), seconds: 30)
            await shot(IslandRoot(), "island-closed-long", dir, size: CGSize(width: 760, height: 40), dark: true)
            island.toast = nil
            // A timer runs: a thin line along the notch's bottom edge, no wings, nothing to open.
            QuickTimer.shared.start(minutes: 25)
            await shot(IslandRoot(), "island-closed-ring", dir, size: CGSize(width: 420, height: 40), dark: true)
            QuickTimer.shared.cancel()
            // A download under way: its progress stays beside the notch.
            Downloads.shared.loadSample()
            await shot(IslandRoot(), "island-closed-download", dir, size: CGSize(width: 420, height: 40), dark: true)
            Downloads.shared.clearSample()

            for dark in [false, true] {
                IslandTheme.shared.style = .notch
                let mode = dark ? "dark" : "light"
                island.isOpen = true
                island.page = .home
                await shot(IslandRoot(), "brand-home-\(mode)", dir, size: CGSize(width: 760, height: 330), dark: dark)
                island.page = .today
                await shot(IslandRoot(), "brand-today-\(mode)", dir, size: CGSize(width: 760, height: 330), dark: dark)
                island.page = .home
                AgentStore.shared.loadSamplePending()
                await shot(IslandRoot(), "brand-permission-\(mode)", dir, size: CGSize(width: 760, height: 260), dark: dark)
                AgentStore.shared.clearSample()
                AgentStore.shared.loadSample()
                await shot(DialPanel(), "brand-dial-\(mode)", dir, size: CGSize(width: 320, height: 440), dark: dark)
                island.isOpen = false
            }
            IslandTheme.shared.style = .notch
            await shot(DialPanel().environment(\.colorScheme, .dark), "dial", dir, size: CGSize(width: 320, height: 440), dark: true)

            for dark in [false, true] {
                let mode = dark ? "dark" : "light"
                for step in 0...3 {
                    await shot(WelcomeView(previewStep: step), "welcome-\(step)-\(mode)", dir, size: CGSize(width: 560, height: 600), dark: dark)
                }
                await shot(SettingsRoot(), "settings-navigation-\(mode)", dir, size: CGSize(width: 760, height: 560), dark: dark)
                await shot(AgentPanelView().frame(width: 980, height: 600), "agent-\(mode)", dir, size: CGSize(width: 980, height: 600), dark: dark)
                for page in SettingsPage.allCases {
                    await shot(NavigationStack { SettingsPageView(page: page).navigationTitle(page.title) }.frame(width: 570, height: 560),
                               "settings-\(page.rawValue)-\(mode)", dir, size: CGSize(width: 570, height: 560), dark: dark)
                }
            }
            await shot(TodayView().padding(Space.margin).background(IslandColor.background).environment(\.colorScheme, .dark),
                       "today-window", dir, size: CGSize(width: 760, height: 260), dark: true)
            (Prefs.shared.mascotX, Prefs.shared.mascotY) = mascotAtStart
            print("SNAPSHOT wrote \(dir.path)")
            NSApp.terminate(nil)
        }
    }

    /// Renders a view in an offscreen window so materials and controls draw like on screen.
    static func shot<V: View>(_ view: V, _ name: String, _ dir: URL, size: CGSize, dark: Bool) async {
        let host = NSHostingView(rootView: view.themed().environment(\.colorScheme, dark ? .dark : .light)
            .background(Color(nsColor: dark ? NSColor(white: 0.12, alpha: 1) : .windowBackgroundColor))
            .noInitialFocus())
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: CGRect(x: -10_000, y: -10_000, width: size.width, height: size.height),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.backgroundColor = dark ? NSColor(white: 0.12, alpha: 1) : .windowBackgroundColor
        window.contentView = host
        window.title = name
        window.center()
        NSApp.unhide(nil)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        try? await Task.sleep(for: .milliseconds(450))
        host.layoutSubtreeIfNeeded()
        let destination = dir.appending(path: "\(name).png")
        let capture = Run.program("/usr/sbin/screencapture", ["-x", "-o", "-l", String(window.windowNumber), destination.path], timeout: 5)
        if capture.status == 0 {
            window.orderOut(nil)
            return
        }
        print("SNAPSHOT fallback (offscreen rendering): \(name)")
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: dir.appending(path: "\(name).png"))
        }
        window.orderOut(nil)
    }

    static func makeSampleImage() -> URL? {
        let url = Paths.dataDirectory.appending(path: "Beispiel.png")
        let image = NSImage(size: NSSize(width: 800, height: 600), flipped: false) { r in
            NSGradient(starting: NSColor(hex: Brand.schiefer), ending: NSColor(hex: Brand.black))?.draw(in: r, angle: -90)
            return true
        }
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        try? FileManager.default.createDirectory(at: Paths.dataDirectory, withIntermediateDirectories: true)
        try? png.write(to: url)
        return url
    }
}

#endif
