// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// All apps full screen. ⌥⌘4 (changeable) opens and closes it, Esc closes.
final class AppGridController {
    static let shared = AppGridController()
    private var panel: NSPanel?

    struct AppEntry: Identifiable, Hashable {
        var id: URL { url }
        var url: URL
        var name: String
    }

    func toggle() { panel == nil ? open() : close() }

    func open() {
        guard panel == nil, let screen = NSScreen.withMouse else { return }
        let p = IslandPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .modalPanel
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = DialController.host(AppGridView(apps: Self.installedApps()).themed())
        p.setFrame(screen.frame, display: true)
        panel = p
        p.alphaValue = 0
        p.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Motion.duration(Motion.panelIn)
            p.animator().alphaValue = 1
        }
    }

    /// Fades out a little quicker than it came in, then leaves the screen.
    func close() {
        guard let p = panel else { return }
        panel = nil
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Motion.duration(Motion.panelOut)
            p.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { p.orderOut(nil) }
        }
    }

    func launch(_ app: AppEntry) {
        close()
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
    }

    /// Apps in /Applications, /System/Applications and ~/Applications (one level of subfolders).
    static func installedApps() -> [AppEntry] {
        let fm = FileManager.default
        let roots = ["/Applications", "/System/Applications", "/System/Applications/Utilities",
                     fm.homeDirectoryForCurrentUser.appending(path: "Applications").path]
        var seen: Set<String> = []
        var apps: [AppEntry] = []
        func add(_ url: URL) {
            let name = fm.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            guard seen.insert(url.resolvingSymlinksInPath().path).inserted else { return }
            apps.append(AppEntry(url: url, name: name))
        }
        for root in roots {
            // Not .skipsHiddenFiles: Safari is a hidden-flagged link into the system cryptex.
            guard let items = try? fm.contentsOfDirectory(at: URL(fileURLWithPath: root), includingPropertiesForKeys: nil) else { continue }
            for item in items where !item.lastPathComponent.hasPrefix(".") {
                if item.pathExtension == "app" { add(item) }
                else if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                        let sub = try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                    sub.filter { $0.pathExtension == "app" }.forEach(add)
                }
            }
        }
        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

struct AppGridView: View {
    var apps: [AppGridController.AppEntry]
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    private var music = NowPlaying.shared

    private var filtered: [AppGridController.AppEntry] {
        query.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: Space.xl) {
            HStack(spacing: Space.md) {
                TextField("Apps suchen", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                    .focused($searchFocused)
                    .onSubmit { if let first = filtered.first { AppGridController.shared.launch(first) } }
                if music.hasTrack {
                    Button {
                        AppGridController.shared.close()
                        music.openPlayer()
                    } label: {
                        Label("Läuft gerade: \(music.title)", systemImage: "music.note").lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.top, 60)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: Space.xl)], spacing: Space.xl) {
                    ForEach(filtered) { app in
                        Button { AppGridController.shared.launch(app) } label: {
                            VStack(spacing: Space.sm) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path)).resizable().frame(width: 72, height: 72)
                                Text(app.name).font(.callout).lineLimit(1).foregroundStyle(.primary)
                            }
                            .frame(width: 112)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(app.name)
                    }
                }
                .padding(.horizontal, 80)
                .padding(.bottom, 60)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .contentShape(Rectangle())
        .onTapGesture { AppGridController.shared.close() }
        .onKeyPress(.escape) { AppGridController.shared.close(); return .handled }
        .onAppear { searchFocused = true }
    }
}

/// Dark Matte / White Matte equivalent: "Nacht" and "Papier".
final class ThemeController {
    static let shared = ThemeController()

    func apply(_ theme: AppTheme, switchMac: Bool) {
        switch theme {
        case .system: NSApp.appearance = nil
        case .night: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .paper: NSApp.appearance = NSAppearance(named: .aqua)
        }
        guard switchMac, theme != .system else { return }
        SystemControls.shared.setDarkMode(theme == .night)
        let wallpaper = theme == .night ? Prefs.shared.nightWallpaper : Prefs.shared.paperWallpaper
        applyWallpaper(wallpaper)
    }

    func applyWallpaper(_ path: String?) {
        guard let path, FileManager.default.fileExists(atPath: path) else { return }
        for screen in NSScreen.screens {
            try? NSWorkspace.shared.setDesktopImageURL(URL(fileURLWithPath: path), for: screen, options: [:])
        }
    }
}
