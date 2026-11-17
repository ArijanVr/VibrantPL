// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Synchronised lyrics in LRC format ("[01:23.45] text"), as LRCLIB delivers them.
public struct SyncedLyrics: Sendable, Equatable {
    public struct Line: Sendable, Equatable {
        public var time: TimeInterval
        public var text: String
    }

    public var lines: [Line]

    public init(lines: [Line]) { self.lines = lines }

    /// Reads LRC text. Lines may carry several time tags; metadata tags ([ar:...]) are skipped.
    public init?(lrc: String) {
        var out: [Line] = []
        for raw in lrc.split(whereSeparator: \.isNewline) {
            var rest = Substring(raw)
            var times: [TimeInterval] = []
            while rest.first == "[", let close = rest.firstIndex(of: "]") {
                let tag = rest[rest.index(after: rest.startIndex)..<close]
                rest = rest[rest.index(after: close)...]
                guard let t = Self.time(String(tag)) else { times = []; break }
                times.append(t)
            }
            let text = rest.trimmingCharacters(in: .whitespaces)
            for t in times { out.append(Line(time: t, text: text)) }
        }
        guard !out.isEmpty else { return nil }
        lines = out.sorted { $0.time < $1.time }
    }

    /// "01:23.45" or "1:23" -> seconds; nil for metadata tags.
    static func time(_ tag: String) -> TimeInterval? {
        let parts = tag.split(separator: ":")
        guard parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1].replacingOccurrences(of: ",", with: ".")) else { return nil }
        return m * 60 + s
    }

    /// The line sung at `position`, or nil before the first line.
    public func line(at position: TimeInterval) -> Line? {
        var lo = 0, hi = lines.count - 1, found: Int?
        while lo <= hi {
            let mid = (lo + hi) / 2
            if lines[mid].time <= position { found = mid; lo = mid + 1 } else { hi = mid - 1 }
        }
        return found.map { lines[$0] }
    }

    /// The request URL for LRCLIB. Only title, artist, album and length are sent.
    public static func requestURL(title: String, artist: String, album: String, duration: TimeInterval) -> URL? {
        var c = URLComponents(string: "https://lrclib.net/api/get")
        var items = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: artist)]
        if !album.isEmpty { items.append(URLQueryItem(name: "album_name", value: album)) }
        if duration > 0 { items.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded())))) }
        c?.queryItems = items
        return c?.url
    }

    public static func parseResponse(_ data: Data) -> SyncedLyrics? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lrc = obj["syncedLyrics"] as? String, !lrc.isEmpty else { return nil }
        return SyncedLyrics(lrc: lrc)
    }
}
