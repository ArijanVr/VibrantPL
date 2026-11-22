// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Notices files that arrive by AirDrop: new items in ~/Downloads whose quarantine record names the sharing
/// service. Only the file name and the record are read, never the content.
@MainActor
final class AirDropArrival {
    static let shared = AirDropArrival()
    private var source: DispatchSourceFileSystemObject?
    private var started = Date()
    private var seen: Set<String> = []
    private let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

    func start() {
        guard source == nil, let folder else { return }
        started = Date()
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let s = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        s.setEventHandler { [weak self] in
            // The transfer writes the file for a moment: look a little later.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { MainActor.assumeIsolated { self?.scan() } }
        }
        s.setCancelHandler { close(fd) }
        s.resume()
        source = s
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func scan() {
        guard Prefs.shared.airDropArrival, let folder,
              let items = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey]) else { return }
        for url in items where !url.lastPathComponent.hasPrefix(".") && !seen.contains(url.path) {
            guard let created = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate,
                  created > started.addingTimeInterval(-1) else { continue }
            seen.insert(url.path)
            if Self.isAirDrop(url) { ScreenshotShelf.shared.show(url, airDrop: true) }
        }
    }

    /// The quarantine record is «flags;time;agent;id»; AirDrop names the sharing service as the agent.
    nonisolated static func isAirDrop(_ url: URL) -> Bool {
        let size = getxattr(url.path, "com.apple.quarantine", nil, 0, 0, 0)
        guard size > 0 else { return false }
        var buffer = [UInt8](repeating: 0, count: size)
        guard getxattr(url.path, "com.apple.quarantine", &buffer, size, 0, 0) == size else { return false }
        return String(decoding: buffer, as: UTF8.self).contains("sharingd")
    }
}
