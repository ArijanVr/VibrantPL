// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation
import Observation
import VibrantPlusKit

/// Checks GitHub Releases, then an optional local folder (`PROJEKTELAB_RELEASES`). No Sparkle.
@Observable
final class AppUpdater {
    static let shared = AppUpdater()

    enum Status: Equatable {
        case idle, checking, upToDate, available(String), downloading, failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var foundVersion: String?
    private(set) var notesURL: URL?
    @ObservationIgnored private var zipURL: URL?
    @ObservationIgnored private var checkingTask: Task<Void, Never>?

    var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func check(automatic: Bool = false) {
        guard ProcessInfo.processInfo.environment["APP_SNAPSHOT"] == nil, !Paths.isOverridden else { return }
        if automatic, let last = Prefs.shared.appUpdateLastCheck, Date.now.timeIntervalSince(last) < 20 * 3_600 { return }
        if checkingTask != nil { return }
        status = .checking
        checkingTask = Task { await self.runCheck(automatic: automatic) }
    }

    func install() {
        guard case .available = status, let zipURL else { return }
        let alert = NSAlert()
        alert.messageText = "Vibrant+ \(foundVersion ?? "") laden?"
        alert.informativeText = "Die App in /Applications wird ersetzt und neu gestartet. Die Datei ist Developer-ID-signiert."
        alert.addButton(withTitle: "Aktualisieren")
        alert.addButton(withTitle: "Später")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        status = .downloading
        Task { await self.runInstall(zip: zipURL) }
    }

    private func runCheck(automatic: Bool) async {
        defer { checkingTask = nil }
        Prefs.shared.appUpdateLastCheck = Date.now
        let current = AppVersion.parse(current)
        if let remote = await githubLatest(), let version = remote.version, let asset = remote.zipAsset(),
           let now = current, version > now {
            foundVersion = version.display
            zipURL = asset.browserDownloadURL
            notesURL = URL(string: remote.htmlURL)
            status = .available(version.display)
            if automatic {
                IslandModel.shared.show(Toast(symbol: "arrow.down.app", text: "Vibrant+ \(version.display) ist bereit"), seconds: 8)
            }
            return
        }
        if let local = localLatest(), let now = current, local.version > now {
            foundVersion = local.version.display
            zipURL = local.zip
            notesURL = nil
            status = .available(local.version.display)
            if automatic {
                IslandModel.shared.show(Toast(symbol: "arrow.down.app", text: "Vibrant+ \(local.version.display) liegt in den Releases"), seconds: 8)
            }
            return
        }
        if case .failed = status { return }
        status = .upToDate
        if !automatic {
            IslandModel.shared.show(Toast(symbol: "checkmark.circle", text: "Vibrant+ ist aktuell"))
        }
    }

    private func githubLatest() async -> GitHubRelease? {
        var request = URLRequest(url: AppUpdatePlan.apiLatest)
        request.setValue("VibrantPlus", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else {
                if code == 404 { return nil }
                status = .failed("GitHub antwortet mit \(code).")
                return nil
            }
            return try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            return nil
        }
    }

    private func localLatest() -> (version: AppVersion, zip: URL)? {
        // Optional local ZIP folder for maintainers (set PROJEKTELAB_RELEASES). No default path in the public tree.
        guard let override = ProcessInfo.processInfo.environment["PROJEKTELAB_RELEASES"], !override.isEmpty else { return nil }
        let root = URL(fileURLWithPath: override, isDirectory: true)
        guard let folders = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return nil }
        var best: (AppVersion, URL)?
        for folder in folders {
            guard let version = AppUpdatePlan.newestICloud(folderNames: [folder.lastPathComponent]) else { continue }
            let zip = folder.appendingPathComponent("Dateien/macOS").appendingPathComponent(AppUpdatePlan.zipName(version: version.display))
            guard FileManager.default.fileExists(atPath: zip.path) else { continue }
            if best == nil || version > best!.0 { best = (version, zip) }
        }
        return best.map { ($0.0, $0.1) }
    }

    private func runInstall(zip: URL) async {
        do {
            let work = FileManager.default.temporaryDirectory.appendingPathComponent("VibrantPlus-update-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: work) }
            let archive = work.appendingPathComponent("update.zip")
            if zip.isFileURL {
                try FileManager.default.copyItem(at: zip, to: archive)
            } else {
                guard AppUpdatePlan.isAllowedDownload(zip) else { throw Failure.badURL }
                let (tmp, _) = try await URLSession.shared.download(from: zip)
                try FileManager.default.moveItem(at: tmp, to: archive)
            }
            let unpacked = work.appendingPathComponent("out", isDirectory: true)
            try FileManager.default.createDirectory(at: unpacked, withIntermediateDirectories: true)
            let ditto = await MaintenanceCommand.run("/usr/bin/ditto", ["-xk", archive.path, unpacked.path])
            guard ditto.status == 0 else { throw Failure.unpack }
            guard let app = findApp(in: unpacked) else { throw Failure.missingApp }
            let ident = Bundle(url: app)?.bundleIdentifier
            guard ident == "ch.arjo.vibrantplus" || ident == Bundle.main.bundleIdentifier else { throw Failure.wrongApp }
            let verify = await MaintenanceCommand.run("/usr/bin/codesign", ["--verify", app.path])
            guard verify.status == 0 else { throw Failure.unsigned }
            let dest = URL(fileURLWithPath: "/Applications/Vibrant+.app")
            // Never write into the bundle that is still running: rewriting a mapped
            // executable leaves the old process pointing at deleted code pages, and the next
            // page-in kills it with SIGBUS. Move the old bundle aside, put the new one in its
            // place, and let the relaunch delete the old copy once this process has ended.
            let old = URL(fileURLWithPath: "/Applications/.Vibrant+-old-\(UUID().uuidString).app")
            try FileManager.default.moveItem(at: dest, to: old)
            let place = await MaintenanceCommand.run("/usr/bin/ditto", [app.path, dest.path])
            guard place.status == 0 else {
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.moveItem(at: old, to: dest)
                throw Failure.unpack
            }
            IslandModel.shared.show(Toast(symbol: "checkmark.circle", text: "Update installiert, Neustart…"))
            AppRelaunch.now(removing: old, opening: dest)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func findApp(in dir: URL) -> URL? {
        let found = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        if let direct = found?.first(where: { $0.lastPathComponent == "Vibrant+.app" }) { return direct }
        for child in found ?? [] {
            if child.hasDirectoryPath, let nested = findApp(in: child) { return nested }
        }
        return nil
    }

    private enum Failure: LocalizedError {
        case badURL, unpack, missingApp, wrongApp, unsigned
        var errorDescription: String? {
            switch self {
            case .badURL: "Die Download-Adresse ist nicht GitHub."
            case .unpack: "Das Archiv liess sich nicht entpacken."
            case .missingApp: "Im Archiv fehlt Vibrant+.app."
            case .wrongApp: "Das Archiv ist nicht Vibrant+."
            case .unsigned: "Die Signatur der neuen App stimmt nicht."
            }
        }
    }
}
