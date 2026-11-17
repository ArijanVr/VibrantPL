// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers
import VibrantPlusKit

@Observable
final class QuickToolsStore {
    static let shared = QuickToolsStore()
    private(set) var favorites: [FavoriteToolAction]
    var message: String?
    @ObservationIgnored private let file = JSONFile<[FavoriteToolAction]>(url: Paths.dataDirectory.appending(path: "quick-tools.json"))
    init() { favorites = file.load() ?? [] }
    func add(kind: FavoriteToolAction.Kind) {
        guard favorites.count < 16 else { message = "Bis zu 16 Favoriten sind möglich."; return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = kind == .file
        panel.canChooseFiles = true
        if kind == .application { panel.allowedContentTypes = [.applicationBundle] }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        favorites.append(FavoriteToolAction(title: FileManager.default.displayName(atPath: url.path), kind: kind, target: url.path))
        save()
    }
    func addShortcut(_ name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, favorites.count < 16 else { return }
        favorites.append(FavoriteToolAction(title: name, kind: .shortcut, target: name)); save()
    }
    func remove(_ action: FavoriteToolAction) { favorites.removeAll { $0.id == action.id }; save() }
    func move(_ action: FavoriteToolAction, by offset: Int) {
        guard let index = favorites.firstIndex(where: { $0.id == action.id }), favorites.indices.contains(index + offset) else { return }
        favorites.swapAt(index, index + offset); save()
    }
    private func save() { SaveReport.attempt("Werkzeugfavoriten") { try file.save(favorites) } }
    func perform(_ action: FavoriteToolAction) {
        QuickToolsController.shared.close()
        switch action.kind {
        case .application:
            let url = URL(fileURLWithPath: action.target)
            guard url.pathExtension.lowercased() == "app", FileManager.default.fileExists(atPath: url.path) else { message = "Die App ist nicht mehr vorhanden."; return }
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        case .file:
            let url = URL(fileURLWithPath: action.target)
            guard FileManager.default.fileExists(atPath: url.path) else { message = "Die Datei ist nicht mehr vorhanden."; return }
            NSWorkspace.shared.open(url)
        case .shortcut:
            ShortcutRunner.run(ShortcutButton(name: action.target))
        }
    }
}

final class QuickToolsController {
    static let shared = QuickToolsController()
    enum Mode: String, CaseIterable { case command, palette, radial }
    private var panel: NSPanel?
    private(set) var enabled = false
    func start() { enabled = true }
    func stop() { enabled = false; close() }
    func open(_ mode: Mode = .command) {
        guard enabled else { return }
        close()
        if mode == .command {
            CommandSearch.shared.configure(source: NSWorkspace.shared.frontmostApplication.flatMap(CommandAppIdentity.init))
        }
        let size = mode == .radial ? NSSize(width: 480, height: 440) : NSSize(width: 560, height: 480)
        let panel = IslandPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = mode == .command ? "Befehlsleiste" : mode == .palette ? "Schnellpalette" : "Radialmenü"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = NSHostingView(rootView: QuickToolsView(mode: mode).themed())
        host.sizingOptions = []
        panel.contentView = host
        panel.setContentSize(size)
        if mode != .command, let screen = NSScreen.withMouse {
            let mouse = NSEvent.mouseLocation, room = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: min(max(room.minX, mouse.x - size.width / 2), max(room.minX, room.maxX - size.width)),
                                         y: min(max(room.minY, mouse.y - size.height / 2), max(room.minY, room.maxY - size.height))))
        } else { panel.center() }
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
    }
    func close() {
        CommandSearch.shared.stop()
        panel?.orderOut(nil); panel = nil
    }
}

struct QuickToolsView: View {
    var mode: QuickToolsController.Mode
    @State private var store = QuickToolsStore.shared
    @State private var search = CommandSearch.shared
    @State private var query = ""
    @State private var apps: [AppGridController.AppEntry] = []
    @FocusState private var searchFocused: Bool
    private var favorites: [FavoriteToolAction] { store.favorites.filter { query.isEmpty || $0.title.localizedStandardContains(query) } }
    private var matchedApps: [AppGridController.AppEntry] {
        query.isEmpty ? [] : Array(apps.filter { $0.name.localizedStandardContains(query) }.prefix(12))
    }
    private var conversion: String? {
        guard case .unit(let amount, let from, let to) = Converter.parse(query), let value = Converter.convertUnit(amount, from: from, to: to) else { return nil }
        return "\(Converter.format(value)) \(Converter.label(to))"
    }
    private var calculation: String? {
        guard let value = SafeCalculator.evaluate(query) else { return nil }
        return Converter.format(value)
    }
    private var clips: [ClipItem] {
        guard Prefs.shared.isOn(.clipboard), query.count >= 2 else { return [] }
        return Array(ClipboardHistory.shared.list.visible(matching: query).prefix(8))
    }
    private var snippets: [Snippet] {
        guard Prefs.shared.isOn(.snippets), query.count >= 2 else { return [] }
        return Array(SnippetService.shared.snippets.filter {
            $0.trigger.localizedStandardContains(query) || $0.text.localizedStandardContains(query)
        }.prefix(8))
    }
    var body: some View {
        VStack(spacing: Space.md) {
            if mode != .radial {
                TextField(mode == .command ? "Apps, Dateien, Fenster, Menüs oder rechnen" : "Favoriten suchen", text: $query)
                    .textFieldStyle(.roundedBorder).focused($searchFocused)
                    .onSubmit {
                        if let conversion { copy(conversion) }
                        else if let calculation { copy(calculation) }
                        else if let action = favorites.first { store.perform(action) }
                        else if let app = matchedApps.first { launch(app) }
                        else if let file = search.files.first { search.openFile(file) }
                        else if let window = search.windows.first { search.focusWindow(window) }
                    }
            }
            if mode == .radial {
                radial
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        if let conversion { Button { copy(conversion) } label: { Label(conversion + " kopieren", systemImage: "equal.circle") } }
                        if let calculation { Button { copy(calculation) } label: { Label(calculation + " kopieren", systemImage: "function") } }
                        if favorites.isEmpty && matchedApps.isEmpty && conversion == nil && calculation == nil
                            && search.files.isEmpty && search.windows.isEmpty && search.menus.isEmpty && clips.isEmpty && snippets.isEmpty {
                            ContentUnavailableView("Keine passenden Werkzeuge", systemImage: "magnifyingglass",
                                                   description: Text("Favoriten unter Einstellungen hinzufügen oder nach einer App, Datei oder Rechnung suchen."))
                        }
                        ForEach(favorites) { action in
                            Button { store.perform(action) } label: {
                                Label(action.title, systemImage: action.kind == .shortcut ? "bolt" : action.kind == .application ? "app" : "doc")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.bordered)
                        }
                        if mode == .command {
                            ForEach(matchedApps) { app in
                                Button { launch(app) } label: { Label(app.name, systemImage: "app").frame(maxWidth: .infinity, alignment: .leading) }
                                    .buttonStyle(.bordered)
                            }
                            ForEach(search.files) { file in
                                Button { search.openFile(file) } label: { Label(file.url.lastPathComponent, systemImage: "doc").frame(maxWidth: .infinity, alignment: .leading) }
                                    .buttonStyle(.bordered)
                            }
                            ForEach(search.windows) { window in
                                Button { search.focusWindow(window) } label: {
                                    Label(window.source.name + " · " + window.title, systemImage: "macwindow").frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.bordered)
                            }
                            ForEach(search.menus) { menu in
                                Button { search.performMenu(menu) } label: {
                                    Label((menu.breadcrumb.isEmpty ? "" : menu.breadcrumb + " › ") + menu.title, systemImage: "menubar.rectangle")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.bordered).disabled(!menu.enabled)
                            }
                            ForEach(clips) { clip in
                                Button { ClipboardHistory.shared.copy(clip); QuickToolsController.shared.close() } label: {
                                    Label(clip.text, systemImage: "doc.on.clipboard").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.bordered)
                            }
                            ForEach(snippets) { snippet in
                                Button { copy(snippet.text) } label: {
                                    Label(snippet.trigger + " · " + snippet.text, systemImage: "text.insert").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.bordered)
                            }
                            if search.working { ProgressView("Sucht Fenster und Menüs…") }
                            if let message = search.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            if let message = store.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            HStack {
                Text(mode == .radial ? "Die ersten acht Favoriten" : "Alles bleibt lokal").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Favoriten anpassen…") { QuickToolsController.shared.close(); AppActions.openSettings() }
            }
        }
        .padding(Space.margin)
        .onAppear { if mode == .command { apps = AppGridController.installedApps(); searchFocused = true } }
        .onChange(of: query) { _, value in
            if mode == .command { CommandSearch.shared.search(value) }
        }
        .onExitCommand { QuickToolsController.shared.close() }
    }
    private var radial: some View {
        GeometryReader { geometry in
            ZStack {
                Image(systemName: "circle.grid.3x3").font(.largeTitle).foregroundStyle(.secondary)
                ForEach(Array(store.favorites.prefix(8).enumerated()), id: \.element.id) { index, action in
                    let angle = Double(index) * .pi / 4 - .pi / 2
                    Button(action.title) { store.perform(action) }
                        .buttonStyle(.bordered).lineLimit(2)
                        .frame(width: 112)
                        .position(x: geometry.size.width / 2 + cos(angle) * 148, // grid: ok radial geometry follows a circle
                                  y: geometry.size.height / 2 + sin(angle) * 128) // grid: ok radial geometry follows a circle
                }
                if store.favorites.isEmpty { Text("Füge zuerst Favoriten hinzu.").foregroundStyle(.secondary) }
            }
        }
    }
    private func copy(_ value: String) {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(value, forType: .string)
        QuickToolsController.shared.close()
    }
    private func launch(_ app: AppGridController.AppEntry) {
        QuickToolsController.shared.close()
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
    }
}
