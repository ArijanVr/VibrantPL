// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Overlap of two vertical strips, as hashed rows. Used to stitch scrolling screenshots.
public enum ScrollCapture {
    /// Longest suffix of `upper` that equals a prefix of `lower`.
    public static func overlap(_ upper: [UInt64], _ lower: [UInt64]) -> Int {
        let n = min(upper.count, lower.count)
        guard n > 0 else { return 0 }
        for length in stride(from: n, through: 1, by: -1) {
            if upper.suffix(length).elementsEqual(lower.prefix(length)) { return length }
        }
        return 0
    }

    public static func shouldStop(previous: UInt64?, current: UInt64, frames: Int, limit: Int = 8) -> Bool {
        frames >= max(1, limit) || (previous != nil && previous == current)
    }
}
