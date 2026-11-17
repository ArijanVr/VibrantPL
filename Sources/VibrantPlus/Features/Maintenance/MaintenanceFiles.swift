// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Observation
import UniformTypeIdentifiers
import VibrantPlusKit

struct MaintenanceFile: Identifiable, Sendable {
    var id: String { url.path }
    let url: URL
    let bytes: Int64
    let inode: UInt64
    let device: UInt64
    let modified: Date
    let complete: Bool
    var sizeText: String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
}

nonisolated enum MaintenanceFiles {
    static func inspect(_ url: URL, limit: Int = 100_000) -> MaintenanceFile? {
        let fm = FileManager.default
        guard let root = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .contentModificationDateKey, .isDirectoryKey, .fileAllocatedSizeKey]),
              root.isSymbolicLink != true,
              let attributes = try? fm.attributesOfItem(atPath: url.path),
              let inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
              let device = (attributes[.systemNumber] as? NSNumber)?.uint64Value else { return nil }
        var bytes = Int64(root.fileAllocatedSize ?? 0)
        var modified = root.contentModificationDate ?? .distantPast
        var complete = true
        if root.isDirectory == true {
            let keys: Set<URLResourceKey> = [.isSymbolicLinkKey, .fileAllocatedSizeKey, .contentModificationDateKey]
            var count = 0
            if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in complete = false; return false }) {
                while let child = enumerator.nextObject() as? URL {
                    count += 1
                    if count > limit { complete = false; break }
                    guard let values = try? child.resourceValues(forKeys: keys) else { complete = false; continue }
                    if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
                    bytes += Int64(values.fileAllocatedSize ?? 0)
                    modified = max(modified, values.contentModificationDate ?? .distantPast)
                }
            } else { complete = false }
        }
        return MaintenanceFile(url: url, bytes: bytes, inode: inode, device: device, modified: modified, complete: complete)
    }

    static func sameItem(_ item: MaintenanceFile) -> Bool {
        guard let values = try? item.url.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink != true,
              let attributes = try? FileManager.default.attributesOfItem(atPath: item.url.path) else { return false }
        return (attributes[.systemFileNumber] as? NSNumber)?.uint64Value == item.inode
            && (attributes[.systemNumber] as? NSNumber)?.uint64Value == item.device
    }
}

@Observable
final class CleanerStore {
    static let shared = CleanerStore()
    private(set) var items: [MaintenanceFile] = []
    var selected: Set<String> = []
    var olderThanDays = 7
    private(set) var busy = false
    private(set) var message: String?
    private(set) var trashResults: [URL] = []
    private var roots: [URL] {
        let library = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library")
        return [library.appending(path: "Caches"), library.appending(path: "Logs")]
    }
    func scan() {
        guard !busy else { return }
        busy = true; selected = []; message = nil
        let roots = roots, cutoff = Date.now.addingTimeInterval(-Double(olderThanDays) * 86_400)
        Task {
            items = await Task.detached(priority: .utility) {
                roots.flatMap { root in
                    ((try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey])) ?? [])
                        .filter { MaintenanceRules.isCleanerCandidate($0, roots: roots) }
                        .compactMap { MaintenanceFiles.inspect($0) }
                        .filter { $0.complete && $0.modified < cutoff }
                }.sorted { $0.bytes > $1.bytes }
            }.value
            message = "\(items.count) vollständig lesbare, alte Cache-/Log-Ordner gefunden. Nichts vorausgewählt."
            busy = false
        }
    }
    func trashSelected() {
        let chosen = items.filter { selected.contains($0.id) }
        guard !busy, !chosen.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "\(chosen.count) Cache-/Log-Ordner in den Papierkorb?"
        alert.informativeText = "Beende betroffene Apps zuerst. Dateien werden nicht endgültig gelöscht.\n\n" + chosen.map(\.url.path).joined(separator: "\n")
        alert.addButton(withTitle: "In den Papierkorb"); alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        busy = true
        var succeeded: Set<String> = [], errors: [String] = []
        for item in chosen {
            guard MaintenanceRules.isCleanerCandidate(item.url, roots: roots),
                  roots.map({ $0.resolvingSymlinksInPath().path }).contains(item.url.deletingLastPathComponent().resolvingSymlinksInPath().path),
                  MaintenanceFiles.sameItem(item) else { errors.append(item.url.lastPathComponent + " wurde verändert"); continue }
            do {
                var trashed: NSURL?
                try FileManager.default.trashItem(at: item.url, resultingItemURL: &trashed)
                if let trashed { trashResults.append(trashed as URL) }
                succeeded.insert(item.id)
            } catch { errors.append(item.url.lastPathComponent + ": " + error.localizedDescription) }
        }
        items.removeAll { succeeded.contains($0.id) }; selected.subtract(succeeded)
        message = "\(succeeded.count) Ordner im Papierkorb." + (errors.isEmpty ? "" : " Nicht verschoben: " + errors.joined(separator: "; "))
        busy = false
    }
    func revealTrash() {
        if let last = trashResults.last { NSWorkspace.shared.activateFileViewerSelecting([last]) }
        else { NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appending(path: ".Trash")) }
    }
}

@Observable
final class UninstallerStore {
    static let shared = UninstallerStore()
    private(set) var app: URL?
    private(set) var bundleID: String?
    private(set) var items: [MaintenanceFile] = []
    var selected: Set<String> = []
    private(set) var busy = false
    private(set) var message: String?
    private var roots: [URL] { [URL(fileURLWithPath: "/Applications"), FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications")] }
    func chooseApp() {
        guard !busy else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.applicationBundle]; panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        inspectApp(url)
    }
    func inspectApp(_ url: URL) {
        guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
              MaintenanceRules.isInstallableApp(url, roots: roots, bundleID: id, ownBundleID: Bundle.main.bundleIdentifier ?? "ch.arjo.vibrantplus"),
              let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink != true else {
            message = "Wähle eine andere App direkt in /Applications oder ~/Applications. System-Apps und Vibrant+ sind geschützt."; return
        }
        app = url; bundleID = id; selected = []; busy = true; message = nil
        let candidates = [url] + MaintenanceRules.relatedPaths(bundleID: id, home: FileManager.default.homeDirectoryForCurrentUser)
        Task {
            items = await Task.detached(priority: .utility) { candidates.compactMap { MaintenanceFiles.inspect($0) } }.value
            message = "Nur exakt zur Bundle-ID «\(id)» passende Pfade. App und Daten einzeln auswählen; Container können Dokumente enthalten."
            busy = false
        }
    }
    func trashSelected() {
        guard !busy, let app, let bundleID else { return }
        guard NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty else {
            message = "Beende die ausgewählte App vor der Deinstallation."; return
        }
        let allowed = Set([app] + MaintenanceRules.relatedPaths(bundleID: bundleID, home: FileManager.default.homeDirectoryForCurrentUser))
        let chosen = items.filter { selected.contains($0.id) }
        guard !chosen.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Ausgewählte App-Bestandteile in den Papierkorb?"
        alert.informativeText = "Auch persönliche App-Daten können betroffen sein. Es wird nichts endgültig gelöscht.\n\n" + chosen.map(\.url.path).joined(separator: "\n")
        alert.addButton(withTitle: "In den Papierkorb"); alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        busy = true
        var succeeded: Set<String> = [], errors: [String] = []
        for item in chosen {
            guard allowed.contains(item.url), MaintenanceFiles.sameItem(item),
                  item.url == app || item.url.resolvingSymlinksInPath().path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().path + "/Library/") else {
                errors.append(item.url.lastPathComponent + " wurde verändert"); continue
            }
            do { try FileManager.default.trashItem(at: item.url, resultingItemURL: nil); succeeded.insert(item.id) }
            catch { errors.append(item.url.lastPathComponent + ": " + error.localizedDescription) }
        }
        items.removeAll { succeeded.contains($0.id) }; selected.subtract(succeeded)
        message = "\(succeeded.count) Bestandteile im Papierkorb." + (errors.isEmpty ? "" : " Nicht verschoben: " + errors.joined(separator: "; "))
        busy = false
    }
}
