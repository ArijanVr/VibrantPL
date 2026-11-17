// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Observation
import UniformTypeIdentifiers

@Observable
final class DiskImageInstaller {
    static let shared = DiskImageInstaller()
    private(set) var apps: [URL] = []
    private(set) var ownedMounts: [URL] = []
    private(set) var busy = false
    private(set) var message: String?
    private(set) var installedApp: URL?
    var installForCurrentUser = true

    func chooseDiskImage() {
        guard !busy, ownedMounts.isEmpty else { message = "Wirf das vorherige Image zuerst aus."; return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.diskImage]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let image = panel.url else { return }
        busy = true; apps = []; message = nil; installedApp = nil
        let existing = Set((FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil) ?? []).map(\.standardizedFileURL))
        Task {
            let result = await MaintenanceCommand.run("/usr/bin/hdiutil", ["attach", "-readonly", "-nobrowse", "-noautoopen", "-plist", image.path])
            guard result.status == 0,
                  let data = result.output.data(using: .utf8),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                message = "Das Image konnte nicht geöffnet werden. Verschlüsselte Images bitte im Finder öffnen."; busy = false; return
            }
            let mounts = (plist["system-entities"] as? [[String: Any]] ?? []).compactMap { ($0["mount-point"] as? String).map { URL(fileURLWithPath: $0).standardizedFileURL } }
            ownedMounts = mounts.filter { !existing.contains($0) }
            apps = mounts.flatMap { mount in
                ((try? FileManager.default.contentsOfDirectory(at: mount, includingPropertiesForKeys: [.isSymbolicLinkKey])) ?? []).filter {
                    $0.pathExtension.lowercased() == "app" && (try? $0.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == false && Bundle(url: $0)?.bundleIdentifier != nil
                }
            }
            message = apps.isEmpty ? "Im obersten Image-Ordner wurde keine App gefunden. Installer-Pakete werden nicht ausgeführt." : "App zum Kopieren auswählen. Es wird kein Installer-Skript ausgeführt und keine App automatisch gestartet."
            busy = false
        }
    }
    func install(_ source: URL) {
        guard !busy, apps.contains(source), source.pathExtension.lowercased() == "app" else { return }
        let folder = installForCurrentUser ? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications", directoryHint: .isDirectory) : URL(fileURLWithPath: "/Applications", isDirectory: true)
        let destination = folder.appending(path: source.lastPathComponent)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            message = "«\(source.lastPathComponent)» existiert am Ziel bereits. Die vorhandene App wird nicht überschrieben."; return
        }
        let alert = NSAlert()
        alert.messageText = "«\(source.deletingPathExtension().lastPathComponent)» installieren?"
        alert.informativeText = "Die App wird nach \(destination.path) kopiert. macOS prüft sie beim späteren Öffnen mit Gatekeeper. Eine fehlende oder unbekannte Herkunft wird hier nicht umgangen."
        alert.addButton(withTitle: "App kopieren"); alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        busy = true
        Task {
            do {
                try await Task.detached(priority: .utility) {
                    let fm = FileManager.default
                    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                    let stage = folder.appending(path: ".vibrant-install-\(UUID().uuidString)")
                    // A new same-volume staging name makes the final appearance atomic.
                    do {
                        try fm.copyItem(at: source, to: stage)
                        guard !fm.fileExists(atPath: destination.path) else { throw CocoaError(.fileWriteFileExists) }
                        try fm.moveItem(at: stage, to: destination)
                    } catch {
                        if fm.fileExists(atPath: stage.path) { try? fm.removeItem(at: stage) }
                        throw error
                    }
                }.value
                installedApp = destination
                message = "App installiert. Du kannst sie im Finder prüfen und öffnen."
            } catch { message = "App konnte nicht kopiert werden: \(error.localizedDescription)" }
            busy = false
        }
    }
    func eject() {
        guard !busy, !ownedMounts.isEmpty else { return }
        busy = true
        let mounts = ownedMounts
        Task {
            var failed: [URL] = []
            for mount in mounts {
                let result = await MaintenanceCommand.run("/usr/bin/hdiutil", ["detach", mount.path])
                if result.status != 0 { failed.append(mount) }
            }
            ownedMounts = failed
            if failed.isEmpty { apps = []; message = "Image ausgeworfen." }
            else { message = "Das Image ist noch in Benutzung. Schliesse zugehörige Finder-Fenster und versuche es erneut." }
            busy = false
        }
    }
    func revealInstalled() { if let installedApp { NSWorkspace.shared.activateFileViewerSelecting([installedApp]) } }
}
