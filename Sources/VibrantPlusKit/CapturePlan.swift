// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// What a screenshot taken by Vibrant+ shows.
public enum CaptureMode: String, CaseIterable, Codable, Sendable {
    /// The display the pointer is on.
    case screen
    /// One window the person clicks.
    case window
    /// An area the person drags; the space bar switches to window mode, as in macOS.
    case area
}

/// Builds the call to /usr/sbin/screencapture and the file name. Pure, so it is tested.
public enum CapturePlan {
    public static let tool = "/usr/sbin/screencapture"

    /// Arguments for `screencapture`. `display` is 1-based, in the order of the active display list.
    public static func arguments(_ mode: CaptureMode, display: Int?, output: String) -> [String] {
        var args: [String] = []
        switch mode {
        case .screen:
            if let display, display > 0 { args += ["-D", String(display)] } else { args.append("-m") }
        case .window:
            args += ["-i", "-W"]
        case .area:
            args += ["-i", "-s"]
        }
        // The usual camera sound plays, as with ⇧⌘3.
        args += ["-t", "png", output]
        return args
    }

    /// «Bildschirmfoto 2026-11-09 um 19.30.12.png», like macOS in German.
    public static func fileName(at date: Date, timeZone: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        func two(_ v: Int?) -> String { String(format: "%02d", v ?? 0) }
        return "Bildschirmfoto \(c.year ?? 0)-\(two(c.month))-\(two(c.day)) um \(two(c.hour)).\(two(c.minute)).\(two(c.second)).png"
    }

    /// «Bildschirmaufnahme 2026-11-09 um 19.30.12.mov»
    public static func recordingName(at date: Date, timeZone: TimeZone = .current) -> String {
        (fileName(at: date, timeZone: timeZone) as NSString).deletingPathExtension
            .replacingOccurrences(of: "Bildschirmfoto", with: "Bildschirmaufnahme") + ".mov"
    }

    /// A free file URL in `folder`: adds « 2», « 3» … when a file with that name exists.
    public static func freeURL(in folder: URL, name: String) -> URL {
        let base = (name as NSString).deletingPathExtension, ext = (name as NSString).pathExtension
        var url = folder.appendingPathComponent(name)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base) \(n).\(ext)")
            n += 1
        }
        return url
    }
}
