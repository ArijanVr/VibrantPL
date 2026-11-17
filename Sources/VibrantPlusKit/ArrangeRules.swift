// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Reordering for the island's tile strip. Pure, so it is tested.
public enum Arrange {
    /// `item` takes the place of `target`; the others make room. Unknown items leave the list as it was.
    public static func move<T: Equatable>(_ item: T, onto target: T, in list: [T]) -> [T] {
        guard item != target, let from = list.firstIndex(of: item), let to = list.firstIndex(of: target) else { return list }
        var out = list
        out.remove(at: from)
        out.insert(item, at: to)
        return out
    }
}

/// One spoken sentence of a meeting.
public struct TranscriptLine: Codable, Sendable, Equatable {
    public var offset: TimeInterval
    public var speaker: String
    public var text: String

    public init(offset: TimeInterval, speaker: String, text: String) {
        self.offset = offset
        self.speaker = speaker
        self.text = text
    }
}

/// Turns a transcript into a note.
public enum MeetingNote {
    /// Markdown: title, start, then «[mm:ss] Sprecher: Text» per line.
    public static func markdown(title: String, start: Date, lines: [TranscriptLine]) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateStyle = .long
        f.timeStyle = .short
        var out = "# \(title)\n\n\(f.string(from: start))\n\n"
        for l in lines where !l.text.isEmpty {
            let s = Int(l.offset.rounded())
            out += String(format: "[%02d:%02d] ", s / 60, s % 60) + "\(l.speaker): \(l.text)\n\n"
        }
        return out
    }

    /// «Besprechung 2026-11-16 14.05.md»
    public static func fileName(start: Date, timeZone: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: start)
        return String(format: "Besprechung %04d-%02d-%02d %02d.%02d.md", c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    }
}

/// The recognizer's running text grows while someone talks. Only the part not handled yet is new.
public enum SpokenText {
    /// `text` without the `consumed` start. If the recognizer rewrote the start, all of `text` counts as new.
    public static func fresh(_ text: String, after consumed: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !consumed.isEmpty, t.hasPrefix(consumed) else { return t }
        return String(t.dropFirst(consumed.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
