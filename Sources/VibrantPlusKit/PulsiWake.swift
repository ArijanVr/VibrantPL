// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Wake phrase for Pulsi. Swiss spelling, no ß. Loose enough for speech recognition.
public enum PulsiWakePhrase {
    public static func heard(_ text: String) -> Bool {
        let folded = text.lowercased()
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ä", with: "a")
            .replacingOccurrences(of: "ö", with: "o")
        let compact = folded.filter(\.isLetter)
        if ["heypulsi", "heipulsi", "hallopulsi", "halopulsi", "hipulsi", "hupulsi"].contains(where: compact.contains) { return true }
        // Speech often splits the name: «Hey Puls i», «Hey Pulse».
        return ["heypuls", "heipuls", "hallopuls", "hipuls"].contains(where: compact.contains)
    }
}

/// Three original Pulsi cries, generated as samples (no stock macOS sounds).
public enum PulsiCry: String, CaseIterable, Sendable {
    case tap, drag, land

    public var duration: Double {
        switch self {
        case .tap: 0.16
        case .drag: 0.24
        case .land: 0.18
        }
    }

    public func samples(sampleRate: Double = 44_100) -> [Float] {
        let n = max(64, Int(sampleRate * duration))
        return (0..<n).map { i in
            let t = Double(i) / sampleRate
            let p = t / duration
            let env = sin(min(1, p * 8) * .pi / 2) * exp(-p * (self == .drag ? 3.2 : 6.5))
            let freq: Double = switch self {
            case .tap: 640 + 420 * p
            case .drag: 500 + 180 * sin(p * .pi * 4)
            case .land: 380 - 140 * p
            }
            let s = sin(2 * .pi * freq * t) + 0.32 * sin(4 * .pi * freq * t)
            return Float(s * env * 0.42)
        }
    }
}
