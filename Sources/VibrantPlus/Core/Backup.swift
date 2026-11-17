// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Export and import of everything Vibrant+ keeps: tasks, note, snippets, pinned clips,
/// saved window layouts, Claude history and the settings. One .vibrantbackup file (a ZIP).
/// The Notion secret is not included (it stays in the Keychain); neither is the clipboard history.
nonisolated enum Backup {
    struct Manifest: Codable {
        var app = "Vibrant+"
        var format = 1
        var created = Date()
        var files: [String]
    }

    enum Failure: LocalizedError {
        case notABackup, failed(String)
        var errorDescription: String? {
            switch self {
            case .notABackup: "Das ist keine Vibrant+-Sicherung."
            case .failed(let s): "Das hat nicht geklappt: \(s)"
            }
        }
    }

    static let dataFiles = ["today.json", "layouts.json", "snippets.json", "scratchpad.json", "quick-tools.json", "pinned-clips.json", "agent-history.json"]
    /// Settings that belong to this Mac or to a connection, not to a backup.
    static let skippedKeys: Set<String> = ["launchAtLogin.configured", "onboarded", "setup.step", "setup.selection"]

    /// Writes the backup. `domain` is the UserDefaults domain holding the settings.
    static func export(to destination: URL, dataDirectory: URL, defaults: UserDefaults, domain: String) throws {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appending(path: "vp-backup-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }
        var included: [String] = []
        for name in dataFiles {
            let src = dataDirectory.appending(path: name)
            if fm.fileExists(atPath: src.path) { try fm.copyItem(at: src, to: work.appending(path: name)); included.append(name) }
        }
        let prefs = (defaults.persistentDomain(forName: domain) ?? [:]).filter { !skippedKeys.contains($0.key) }
        let plist = try PropertyListSerialization.data(fromPropertyList: prefs, format: .xml, options: 0)
        try plist.write(to: work.appending(path: "settings.plist"))
        included.append("settings.plist")
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        try enc.encode(Manifest(files: included)).write(to: work.appending(path: "manifest.json"))
        try? fm.removeItem(at: destination)
        let r = Run.program("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", work.path, destination.path], timeout: 60)
        guard r.status == 0 else { throw Failure.failed("ZIP konnte nicht erstellt werden") }
    }

    /// Restores a backup over the current data. The current files are kept next to the data folder
    /// in `VibrantPlus-vor-Import` so nothing is lost.
    static func importBackup(from source: URL, dataDirectory: URL, defaults: UserDefaults, domain: String) throws -> Int {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appending(path: "vp-restore-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }
        let r = Run.program("/usr/bin/ditto", ["-x", "-k", source.path, work.path], timeout: 60)
        guard r.status == 0 else { throw Failure.notABackup }
        // Only a plain archive with our manifest is accepted; no path may leave the folder.
        guard let data = try? Data(contentsOf: work.appending(path: "manifest.json")) else { throw Failure.notABackup }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let manifest = try? dec.decode(Manifest.self, from: data), manifest.app == "Vibrant+", manifest.format == 1 else { throw Failure.notABackup }
        let allowed = Set(dataFiles + ["settings.plist"])
        let names = manifest.files.filter { allowed.contains($0) && fm.fileExists(atPath: work.appending(path: $0).path) }

        let safety = dataDirectory.deletingLastPathComponent().appending(path: "VibrantPlus-vor-Import", directoryHint: .isDirectory)
        try? fm.removeItem(at: safety)
        try fm.createDirectory(at: safety, withIntermediateDirectories: true)
        var restored = 0
        for name in names where name != "settings.plist" {
            let dst = dataDirectory.appending(path: name)
            if fm.fileExists(atPath: dst.path) { try? fm.copyItem(at: dst, to: safety.appending(path: name)); try fm.removeItem(at: dst) }
            try fm.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
            try fm.copyItem(at: work.appending(path: name), to: dst)
            restored += 1
        }
        if names.contains("settings.plist"),
           let plist = try? PropertyListSerialization.propertyList(from: Data(contentsOf: work.appending(path: "settings.plist")), format: nil) as? [String: Any] {
            if let old = defaults.persistentDomain(forName: domain),
               let oldData = try? PropertyListSerialization.data(fromPropertyList: old, format: .xml, options: 0) {
                try? oldData.write(to: safety.appending(path: "settings.plist"))
            }
            for (k, v) in plist where !skippedKeys.contains(k) { defaults.set(v, forKey: k) }
            restored += 1
        }
        return restored
    }
}
