// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Frame list and size cap for a GIF built from a movie. ImageIO writes the file.
public enum GIFPlan {
    public static let maxLongSide = 480
    public static let framesPerSecond = 10.0
    public static let maxDuration = 12.0
    public static let delay = 0.1

    public static func clampedRange(duration: Double, start: Double? = nil, end: Double? = nil) -> (start: Double, end: Double) {
        let length = max(0, duration.isFinite ? duration : 0)
        var from = max(0, start ?? 0)
        if !from.isFinite { from = 0 }
        var to = min(length, end ?? length)
        if !to.isFinite { to = length }
        if to <= from { to = min(length, from + delay) }
        if to - from > maxDuration { to = from + maxDuration }
        return (from, to)
    }

    public static func frameTimes(duration: Double, start: Double? = nil, end: Double? = nil) -> [Double] {
        let range = clampedRange(duration: duration, start: start, end: end)
        guard range.end > range.start else { return [] }
        let step = 1 / framesPerSecond
        var times: [Double] = []
        var t = range.start
        while t < range.end - 0.000_1 {
            times.append(t)
            t += step
        }
        if times.isEmpty { times = [range.start] }
        return times
    }

    public static func scaledSize(width: Int, height: Int) -> (width: Int, height: Int) {
        let w = max(1, width), h = max(1, height)
        let long = max(w, h)
        guard long > maxLongSide else { return (w, h) }
        let scale = Double(maxLongSide) / Double(long)
        return (max(1, Int((Double(w) * scale).rounded())), max(1, Int((Double(h) * scale).rounded())))
    }
}
