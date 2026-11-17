// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics
import Foundation

public enum WindowToolRules {
    /// Physical screen edges, in Accessibility coordinates. The menu bar remains a full-height target.
    public static func edge(at point: CGPoint, screen: CGRect, threshold: CGFloat = 12) -> RowlineMath.Snap? {
        guard screen.insetBy(dx: -threshold, dy: -threshold).contains(point) else { return nil }
        if abs(point.y - screen.minY) <= threshold { return .full }
        if abs(point.x - screen.minX) <= threshold { return .left }
        if abs(point.x - screen.maxX) <= threshold { return .right }
        return nil
    }

    public static func nextIndex(current: Int?, count: Int) -> Int? {
        guard count > 0 else { return nil }
        guard let current, (0..<count).contains(current) else { return 0 }
        return (current + 1) % count
    }

    public static func matches(query: String, app: String, title: String) -> Bool {
        query.split(whereSeparator: \.isWhitespace).allSatisfy {
            (app + " " + title).localizedStandardContains(String($0))
        }
    }

    public static func excludedIdentifiers(_ text: String) -> Set<String> {
        Set(text.split { $0.isNewline || $0 == "," }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    }

    /// Keep the window's relative position and size when it moves to another display.
    public static func movedToNextDisplay(frame: CGRect, from: CGRect, to: CGRect) -> CGRect {
        let sx = from.width == 0 ? 1 : to.width / from.width
        let sy = from.height == 0 ? 1 : to.height / from.height
        return CGRect(
            x: to.minX + (frame.minX - from.minX) * sx,
            y: to.minY + (frame.minY - from.minY) * sy,
            width: frame.width * sx,
            height: frame.height * sy
        )
    }
}
