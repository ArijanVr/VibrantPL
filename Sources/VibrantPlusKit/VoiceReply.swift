// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Turns spoken words into an answer for Claude Code.
public enum VoiceReply {
    public enum Verdict { case allow, deny }

    /// Only whole short answers count, so a sentence that happens to contain «ja» never allows a command.
    public static func permission(from spoken: String) -> Verdict? {
        let words = normalize(spoken)
        let allow: Set<String> = ["erlauben", "erlaube", "ja", "okay", "ok", "mach es", "mach das", "genehmigt", "freigeben"]
        let deny: Set<String> = ["ablehnen", "lehne ab", "nein", "stopp", "stop", "abbrechen", "verweigern"]
        if allow.contains(words) { return .allow }
        if deny.contains(words) { return .deny }
        return nil
    }

    /// The option whose label was said: the longest label found in the words wins; «erste/zweite/dritte» pick by place.
    public static func option(in options: [String], from spoken: String) -> String? {
        let words = normalize(spoken)
        let ordinals = ["erste": 0, "erster": 0, "erstes": 0, "eins": 0, "zweite": 1, "zweiter": 1, "zweites": 1, "zwei": 1,
                        "dritte": 2, "dritter": 2, "drittes": 2, "drei": 2, "vierte": 3, "vier": 3]
        let hits = options.filter { words.contains(normalize($0)) && !normalize($0).isEmpty }
        if let best = hits.max(by: { $0.count < $1.count }) { return best }
        for (word, index) in ordinals where words.split(separator: " ").contains(Substring(word)) && index < options.count {
            return options[index]
        }
        return nil
    }

    public static func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: [.diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
