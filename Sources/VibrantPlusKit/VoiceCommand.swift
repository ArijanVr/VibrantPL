// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Voice commands that work without an AI model. German and English.
public enum VoiceCommand: Equatable, Sendable {
    case openApp(String)
    case searchYouTube(String)
    case searchWeb(String)
    case addTask(String)
    case startFocus
    case darkMode(Bool)

    public static func parse(_ raw: String) -> VoiceCommand? {
        // "Füge zur Liste hinzu: X" and "Füge zur Liste hinzu X" mean the same.
        let text = raw.replacingOccurrences(of: ":", with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let lower = text.lowercased()

        func rest(after prefixes: [String]) -> String? {
            for p in prefixes where lower.hasPrefix(p) {
                let r = String(text.dropFirst(p.count)).trimmingCharacters(in: .whitespaces.union(.punctuationCharacters))
                return r.isEmpty ? nil : r
            }
            return nil
        }

        if let q = rest(after: ["suche auf youtube nach ", "such auf youtube nach ", "search youtube for ", "youtube "]) {
            return .searchYouTube(q)
        }
        if let t = rest(after: ["füge zur liste hinzu ", "füge hinzu ", "neue aufgabe ", "notiere ", "erinnere mich an ",
                                "add to my list ", "add task ", "remind me to "]) {
            return .addTask(t)
        }
        if let q = rest(after: ["suche nach ", "suche ", "google ", "search for ", "search "]) {
            return .searchWeb(q)
        }
        if let app = rest(after: ["öffne ", "starte ", "open ", "launch ", "start "]) {
            return .openApp(app)
        }
        if ["fokus starten", "starte fokus", "start focus", "fokus"].contains(lower) { return .startFocus }
        if ["dunkelmodus an", "dark mode on", "dunkler modus"].contains(lower) { return .darkMode(true) }
        if ["dunkelmodus aus", "dark mode off", "heller modus"].contains(lower) { return .darkMode(false) }
        return nil
    }

    public var url: URL? {
        var c = URLComponents()
        switch self {
        case .searchYouTube(let q):
            c = URLComponents(string: "https://www.youtube.com/results")!
            c.queryItems = [URLQueryItem(name: "search_query", value: q)]
        case .searchWeb(let q):
            c = URLComponents(string: "https://duckduckgo.com/")!
            c.queryItems = [URLQueryItem(name: "q", value: q)]
        default: return nil
        }
        return c.url
    }
}

/// Removes filler words from raw dictation when no language model is available.
public enum DictationCleaner {
    static let fillers = ["ähm", "äh", "ehm", "öhm", "hm", "um", "uh", "erm"]

    public static func clean(_ text: String) -> String {
        let words = text.split(separator: " ").filter { word in
            let w = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            return !fillers.contains(w)
        }
        var out = words.joined(separator: " ")
        if let first = out.first, first.isLowercase { out = first.uppercased() + out.dropFirst() }
        return out
    }
}
