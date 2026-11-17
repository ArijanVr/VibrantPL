// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A text snippet: typing the trigger (";adr") anywhere replaces it with the text.
public struct Snippet: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var trigger: String
    public var text: String

    public init(trigger: String, text: String) {
        id = UUID()
        self.trigger = trigger
        self.text = text
    }
}

public enum SnippetRules {
    public static let prefix: Character = ";"
    public static let maxTriggerLength = 24

    /// A trigger starts with ";" and has at least one letter or digit after it, no spaces.
    public static func isValid(trigger: String) -> Bool {
        guard trigger.first == prefix, trigger.count >= 2, trigger.count <= maxTriggerLength else { return false }
        return !trigger.contains { $0.isWhitespace || $0.isNewline } && trigger.dropFirst().contains { $0.isLetter || $0.isNumber }
    }

    /// Typing is character by character, so a trigger that is the start of another one
    /// (";a" and ";adr") would always fire first. Returns the clashing trigger, if any.
    public static func conflict(_ trigger: String, with existing: [Snippet], ignoring id: UUID? = nil) -> String? {
        existing.filter { $0.id != id }.map(\.trigger).first {
            $0 == trigger || $0.hasPrefix(trigger) || trigger.hasPrefix($0)
        }
    }

    /// {datum} {zeit} {wochentag} in the text become the current values.
    public static func expand(_ text: String, now: Date = .now, locale: Locale = Locale(identifier: "de_CH"),
                              timeZone: TimeZone = .current) -> String {
        func f(_ format: String) -> String {
            let d = DateFormatter()
            d.locale = locale
            d.timeZone = timeZone
            d.dateFormat = format
            return d.string(from: now)
        }
        return text.replacingOccurrences(of: "{datum}", with: f("dd.MM.yyyy"))
            .replacingOccurrences(of: "{zeit}", with: f("HH:mm"))
            .replacingOccurrences(of: "{wochentag}", with: f("EEEE"))
    }
}

/// Watches typed characters and reports when the end of the text matches a trigger.
/// The buffer is short, lives in memory and is cleared on every non-text key.
public struct SnippetMatcher: Sendable {
    public private(set) var buffer = ""
    public var snippets: [Snippet]

    public init(snippets: [Snippet] = []) { self.snippets = snippets }

    public mutating func reset() { buffer = "" }

    public mutating func backspace() { if !buffer.isEmpty { buffer.removeLast() } }

    /// Feeds typed characters; returns the snippet whose trigger the text now ends with.
    /// A longer trigger wins over a shorter one that is its suffix.
    public mutating func feed(_ typed: String) -> Snippet? {
        buffer += typed
        if buffer.count > 48 { buffer = String(buffer.suffix(48)) }
        let hit = snippets.filter { buffer.hasSuffix($0.trigger) }.max { $0.trigger.count < $1.trigger.count }
        if hit != nil { buffer = "" }
        return hit
    }
}

/// A button in the island that runs a Shortcuts shortcut.
public struct ShortcutButton: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var symbol: String

    public init(name: String, symbol: String = "bolt.fill") {
        id = UUID()
        self.name = name
        self.symbol = symbol
    }
}

public enum ShortcutsCLI {
    /// `shortcuts list` prints one name per line.
    public static func parseList(_ output: String) -> [String] {
        output.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    public static let maxButtons = 8
}

/// Sizes for upscaling. Pure, so the limits are tested.
public enum UpscalePlan {
    public static let maxImageLongSide = 12_000
    public static let maxVideoWidth = 3_840
    public static let maxVideoHeight = 2_160

    /// The size after scaling by `factor`, never above `maxLongSide` on the long side (aspect kept, even numbers).
    public static func imageSize(width: Int, height: Int, factor: Int, maxLongSide: Int = maxImageLongSide) -> (width: Int, height: Int, factor: Double) {
        guard width > 0, height > 0, factor > 0 else { return (width, height, 1) }
        var f = Double(factor)
        let long = Double(max(width, height))
        if long * f > Double(maxLongSide) { f = Double(maxLongSide) / long }
        return (Int((Double(width) * f).rounded()), Int((Double(height) * f).rounded()), f)
    }

    /// Video: 2× at most, fitted inside 4K (3840 × 2160 or 2160 × 3840), even sizes. nil when the video is already that big.
    public static func videoSize(width: Int, height: Int, factor: Int = 2) -> (width: Int, height: Int, factor: Double)? {
        guard width > 0, height > 0 else { return nil }
        let boxW = width >= height ? maxVideoWidth : maxVideoHeight
        let boxH = width >= height ? maxVideoHeight : maxVideoWidth
        var f = Double(factor)
        f = min(f, Double(boxW) / Double(width), Double(boxH) / Double(height))
        guard f > 1.05 else { return nil }
        func even(_ v: Double) -> Int { max(2, Int((v / 2).rounded()) * 2) }
        return (even(Double(width) * f), even(Double(height) * f), f)
    }
}
