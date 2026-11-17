// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Remembered mixer levels and per-app output devices, keyed by bundle ID.
public struct MixerMemory: Codable, Equatable, Sendable {
    public var favorites: [String]
    public var outputs: [String: String]
    public var gains: [String: Float]

    public init(favorites: [String] = [], outputs: [String: String] = [:], gains: [String: Float] = [:]) {
        self.favorites = favorites
        self.outputs = outputs
        self.gains = gains
    }
}

/// When a process tap must exist: gain away from 100 %, or a chosen output device.
public enum MixerPlan {
    public static func clampedGain(_ value: Float) -> Float { max(0, min(2, value.isFinite ? value : 1)) }

    /// Empty or whitespace means the system default output.
    public static func storedOutput(_ uid: String?) -> String? {
        let trimmed = uid?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func needsTap(gain: Float, outputUID: String?) -> Bool {
        abs(clampedGain(gain) - 1) >= 0.02 || storedOutput(outputUID) != nil
    }

    public static func togglingFavorite(_ bundleID: String, in memory: MixerMemory) -> MixerMemory {
        var next = memory
        if let i = next.favorites.firstIndex(of: bundleID) {
            next.favorites.remove(at: i)
        } else if !bundleID.isEmpty {
            next.favorites.append(bundleID)
        }
        return next
    }
}
