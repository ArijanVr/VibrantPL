// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ApplicationServices
import Observation
import VibrantPlusKit

nonisolated struct CommandAppIdentity: Sendable, Equatable {
    let pid: pid_t
    let bundleID: String
    let name: String
    let launched: Date?
    @MainActor init?(_ app: NSRunningApplication) {
        guard app.bundleIdentifier != Bundle.main.bundleIdentifier, app.activationPolicy == .regular else { return nil }
        pid = app.processIdentifier; bundleID = app.bundleIdentifier ?? ""; name = app.localizedName ?? "App"; launched = app.launchDate
    }
    @MainActor var currentApp: NSRunningApplication? {
        guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated,
              app.bundleIdentifier == bundleID, app.launchDate == launched else { return nil }
        return app
    }
}

nonisolated struct CommandWindowResult: Identifiable, Sendable {
    let source: CommandAppIdentity
    let index: Int
    let title: String
    let identifier: String?
    var id: String { "\(source.pid):\(index):\(title)" }
}
nonisolated struct CommandMenuResult: Identifiable, Sendable {
    struct Step: Sendable { let index: Int; let title: String }
    let source: CommandAppIdentity
    let steps: [Step]
    let title: String
    let breadcrumb: String
    let enabled: Bool
    var id: String { "\(source.pid):" + steps.map { String($0.index) }.joined(separator: ".") }
}

/// AX objects remain on the worker that creates them. Only value descriptors cross actors.
nonisolated enum CommandAXSearch {
    static func windows(in apps: [CommandAppIdentity], matching query: String) -> [CommandWindowResult] {
        var found: [CommandWindowResult] = []
        let deadline = Date.now.addingTimeInterval(4)
        for source in apps {
            guard !Task.isCancelled, Date.now < deadline else { break }
            let app = AXUIElementCreateApplication(source.pid)
            AXUIElementSetMessagingTimeout(app, 0.1)
            for (index, element) in children(app, attribute: kAXWindowsAttribute).enumerated() {
                guard !Task.isCancelled, Date.now < deadline else { break }
                let title = string(element, kAXTitleAttribute) ?? ""
                guard !title.isEmpty, (source.name + " " + title).localizedStandardContains(query) else { continue }
                found.append(CommandWindowResult(source: source, index: index, title: title, identifier: string(element, kAXIdentifierAttribute)))
                if found.count >= 20 { return found }
            }
        }
        return found
    }
    static func menu(in source: CommandAppIdentity?, matching query: String) -> [CommandMenuResult] {
        guard let source else { return [] }
        let app = AXUIElementCreateApplication(source.pid)
        AXUIElementSetMessagingTimeout(app, 0.1)
        guard let bar = element(app, kAXMenuBarAttribute) else { return [] }
        let deadline = Date.now.addingTimeInterval(4)
        var found: [CommandMenuResult] = [], visited = 0
        func walk(_ node: AXUIElement, steps: [CommandMenuResult.Step], names: [String], depth: Int) {
            guard depth < 8, visited < 800, found.count < 30, !Task.isCancelled, Date.now < deadline else { return }
            for (index, child) in children(node).enumerated() {
                guard visited < 800, found.count < 30, !Task.isCancelled, Date.now < deadline else { return }
                visited += 1
                let title = string(child, kAXTitleAttribute) ?? ""
                let nextSteps = steps + [.init(index: index, title: title)]
                let nextNames = title.isEmpty ? names : names + [title]
                let descendants = children(child)
                if descendants.isEmpty, !title.isEmpty, (nextNames.joined(separator: " ")).localizedStandardContains(query),
                   string(child, kAXRoleAttribute) == kAXMenuItemRole {
                    found.append(CommandMenuResult(source: source, steps: nextSteps, title: title,
                                                   breadcrumb: nextNames.dropLast().joined(separator: " › "), enabled: boolean(child, kAXEnabledAttribute) ?? true))
                } else if !descendants.isEmpty { walk(child, steps: nextSteps, names: nextNames, depth: depth + 1) }
            }
        }
        walk(bar, steps: [], names: [], depth: 0)
        return found
    }
    static func children(_ object: AXUIElement, attribute: String = kAXChildrenAttribute) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(object, attribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }
    static func string(_ object: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(object, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
    static func boolean(_ object: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(object, attribute as CFString, &value) == .success else { return nil }
        return value as? Bool
    }
    static func element(_ object: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(object, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value as AnyObject, to: AXUIElement.self)
    }
}

@Observable
final class CommandSearch {
    static let shared = CommandSearch()
    struct FileResult: Identifiable { let url: URL; var id: String { url.path } }
    private(set) var files: [FileResult] = []
    private(set) var windows: [CommandWindowResult] = []
    private(set) var menus: [CommandMenuResult] = []
    private(set) var working = false
    private(set) var message: String?
    private(set) var source: CommandAppIdentity?
    @ObservationIgnored private var metadata: NSMetadataQuery?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var worker: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()

    func configure(source: CommandAppIdentity?) { stop(); self.source = source; message = nil }
    func stop() {
        generation = UUID(); worker?.cancel(); worker = nil
        metadata?.stop(); metadata = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []; files = []; windows = []; menus = []; working = false
    }
    func search(_ raw: String) {
        stop(); message = nil
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2, query.count <= 200 else { return }
        startFiles(query)
        guard Permission.accessibilityTrusted else { return }
        working = true
        let token = generation, source = source
        let apps = NSWorkspace.shared.runningApplications.compactMap(CommandAppIdentity.init)
        worker = Task {
            let task = Task.detached(priority: .userInitiated) {
                let windows = CommandAXSearch.windows(in: apps, matching: query)
                let menu = CommandAXSearch.menu(in: source, matching: query)
                return (windows, menu)
            }
            let result = await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
            guard !Task.isCancelled, generation == token else { return }
            windows = result.0; menus = result.1; working = false
        }
    }
    private func startFiles(_ query: String) {
        let metadata = NSMetadataQuery()
        metadata.searchScopes = [NSMetadataQueryUserHomeScope]
        metadata.predicate = NSPredicate(format: "kMDItemFSName CONTAINS[cd] %@", query)
        metadata.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false)]
        for name in [Notification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: metadata, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateFiles() }
            })
        }
        self.metadata = metadata
        if !metadata.start() { message = "Die lokale Spotlight-Suche konnte nicht gestartet werden." }
    }
    private func updateFiles() {
        guard let metadata else { return }
        metadata.disableUpdates(); defer { metadata.enableUpdates() }
        var found: [FileResult] = [], seen: Set<String> = []
        for case let item as NSMetadataItem in metadata.results.prefix(100) {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  seen.insert(path).inserted else { continue }
            found.append(FileResult(url: URL(fileURLWithPath: path)))
            if found.count >= 20 { break }
        }
        files = found
    }
    func openFile(_ item: FileResult) {
        guard FileManager.default.fileExists(atPath: item.url.path) else { message = "Diese Datei ist nicht mehr vorhanden."; return }
        QuickToolsController.shared.close(); NSWorkspace.shared.open(item.url)
    }
    func focusWindow(_ result: CommandWindowResult) {
        guard Permission.accessibilityTrusted, let app = result.source.currentApp else { message = "Fenster oder Bedienungshilfen sind nicht mehr verfügbar."; return }
        let element = AXUIElementCreateApplication(result.source.pid)
        AXUIElementSetMessagingTimeout(element, 0.2)
        let windows = CommandAXSearch.children(element, attribute: kAXWindowsAttribute)
        let match = windows.enumerated().first { index, window in
            let title = CommandAXSearch.string(window, kAXTitleAttribute) ?? ""
            if let identifier = result.identifier, !identifier.isEmpty {
                return CommandAXSearch.string(window, kAXIdentifierAttribute) == identifier && title == result.title
            }
            return index == result.index && title == result.title
        }?.element
        guard let match else { message = "Dieses Fenster hat sich geändert. Bitte erneut suchen."; return }
        QuickToolsController.shared.close(); app.activate()
        _ = AXUIElementSetAttributeValue(match, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        if AXUIElementPerformAction(match, kAXRaiseAction as CFString) != .success { message = "Das Fenster konnte nicht aktiviert werden." }
    }
    func performMenu(_ result: CommandMenuResult) {
        guard result.enabled, Permission.accessibilityTrusted, let app = result.source.currentApp else { message = "Der Menübefehl ist nicht mehr verfügbar."; return }
        let application = AXUIElementCreateApplication(result.source.pid)
        AXUIElementSetMessagingTimeout(application, 0.2)
        guard var item = CommandAXSearch.element(application, kAXMenuBarAttribute) else { message = "Das App-Menü ist nicht erreichbar."; return }
        for step in result.steps {
            let children = CommandAXSearch.children(item)
            guard children.indices.contains(step.index), (CommandAXSearch.string(children[step.index], kAXTitleAttribute) ?? "") == step.title else {
                message = "Das Menü hat sich geändert. Bitte erneut suchen."; return
            }
            item = children[step.index]
        }
        guard CommandAXSearch.boolean(item, kAXEnabledAttribute) != false,
              CommandAXSearch.string(item, kAXTitleAttribute) == result.title else { message = "Dieser Befehl ist jetzt nicht verfügbar."; return }
        // This method is only called by an explicit menu-result Button, never by search or Return.
        QuickToolsController.shared.close(); app.activate()
        if AXUIElementPerformAction(item, kAXPressAction as CFString) != .success { message = "Der Menübefehl konnte nicht ausgeführt werden." }
    }
}
