// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics
import Foundation

/// Window frames for Rowline. All rects use the screen's visible frame in
/// top-left coordinates (the Accessibility API's coordinate space).
public enum RowlineMath {
    public enum Width: String, Codable, CaseIterable, Sendable {
        case half, twoThirds, full, third
        public var fraction: CGFloat {
            switch self {
            case .third: 1.0 / 3.0
            case .half: 0.5
            case .twoThirds: 2.0 / 3.0
            case .full: 1.0
            }
        }
        public var next: Width {
            switch self {
            case .third: .half
            case .half: .twoThirds
            case .twoThirds: .full
            case .full: .third
            }
        }
    }

    /// Frames for windows side by side in a strip. `offset` scrolls the strip
    /// to the left (positive) so windows past the right edge come into view.
    public static func row(count: Int, widths: [Width], in area: CGRect, gap: CGFloat, offset: CGFloat = 0) -> [CGRect] {
        guard count > 0 else { return [] }
        var x = area.minX + gap - offset
        var frames: [CGRect] = []
        let usable = area.width - 2 * gap
        for i in 0..<count {
            let w = widths.indices.contains(i) ? widths[i] : .half
            // Two halves plus one gap fill the usable width exactly.
            let width = (usable + gap) * w.fraction - gap
            let frame = CGRect(x: x, y: area.minY + gap, width: width.rounded(), height: area.height - 2 * gap)
            frames.append(frame)
            x += frame.width + gap
        }
        return frames
    }

    /// The offset that brings window `index` fully into view, keeping the strip still when it already is.
    public static func offset(toShow index: Int, frames: [CGRect], area: CGRect, current: CGFloat, gap: CGFloat) -> CGFloat {
        guard frames.indices.contains(index) else { return current }
        let f = frames[index]
        if f.minX < area.minX + gap { return current - (area.minX + gap - f.minX) }
        if f.maxX > area.maxX - gap { return current + (f.maxX - (area.maxX - gap)) }
        return current
    }

    public enum Snap: String, CaseIterable, Codable, Sendable {
        case left, right, leftTwoThirds, rightTwoThirds, leftThird, rightThird, full, center
    }

    public static func snap(_ snap: Snap, in area: CGRect, gap: CGFloat) -> CGRect {
        let a = area.insetBy(dx: gap, dy: gap)
        let half = (a.width - gap) / 2
        let third = (a.width - 2 * gap) / 3
        switch snap {
        case .left: return CGRect(x: a.minX, y: a.minY, width: half, height: a.height)
        case .right: return CGRect(x: a.maxX - half, y: a.minY, width: half, height: a.height)
        case .leftTwoThirds: return CGRect(x: a.minX, y: a.minY, width: third * 2 + gap, height: a.height)
        case .rightTwoThirds: return CGRect(x: a.maxX - (third * 2 + gap), y: a.minY, width: third * 2 + gap, height: a.height)
        case .leftThird: return CGRect(x: a.minX, y: a.minY, width: third, height: a.height)
        case .rightThird: return CGRect(x: a.maxX - third, y: a.minY, width: third, height: a.height)
        case .full: return a
        case .center:
            let w = a.width * 0.6, h = a.height * 0.8
            return CGRect(x: a.midX - w / 2, y: a.midY - h / 2, width: w, height: h)
        }
    }

    /// A grid with as many cells as windows, wider than tall.
    public static func grid(count: Int, in area: CGRect, gap: CGFloat) -> [CGRect] {
        guard count > 0 else { return [] }
        let columns = Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(columns)))
        let a = area.insetBy(dx: gap, dy: gap)
        let w = (a.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let h = (a.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
        return (0..<count).map { i in
            let c = i % columns, r = i / columns
            return CGRect(x: a.minX + CGFloat(c) * (w + gap), y: a.minY + CGFloat(r) * (h + gap), width: w, height: h)
        }
    }

    /// The first window on the left half, the rest stacked on the right.
    public static func stack(count: Int, in area: CGRect, gap: CGFloat) -> [CGRect] {
        guard count > 0 else { return [] }
        if count == 1 { return [snap(.full, in: area, gap: gap)] }
        let main = snap(.left, in: area, gap: gap)
        let right = snap(.right, in: area, gap: gap)
        let n = count - 1
        let h = (right.height - CGFloat(n - 1) * gap) / CGFloat(n)
        return [main] + (0..<n).map { i in
            CGRect(x: right.minX, y: right.minY + CGFloat(i) * (h + gap), width: right.width, height: h)
        }
    }
}

/// A saved window arrangement.
public struct WindowLayout: Codable, Sendable, Identifiable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public var bundleID: String
        public var appPath: String?
        public var title: String
        public var frame: CGRect

        public init(bundleID: String, appPath: String?, title: String, frame: CGRect) {
            self.bundleID = bundleID
            self.appPath = appPath
            self.title = title
            self.frame = frame
        }
    }

    public var id: UUID
    public var name: String
    public var entries: [Entry]

    public init(name: String, entries: [Entry]) {
        id = UUID()
        self.name = name
        self.entries = entries
    }
}

/// Which display's top edge the mouse is heading for (island on several displays).
public enum ScreenPick {
    /// Frames are in AppKit screen coordinates (origin bottom-left). Returns the index of the
    /// display whose top-center zone contains the mouse, or nil.
    public static func topCenterScreen(mouse: CGPoint, frames: [CGRect], zoneWidth: CGFloat = 440, zoneHeight: CGFloat = 110) -> Int? {
        frames.firstIndex { f in
            let zone = CGRect(x: f.midX - zoneWidth / 2, y: f.maxY - zoneHeight, width: zoneWidth, height: zoneHeight)
            return zone.contains(mouse)
        }
    }

    /// The display the mouse is on. Edges count as inside: `NSEvent.mouseLocation` reaches
    /// `maxX`/`maxY` exactly on the right and top edge, which `CGRect.contains` would reject.
    /// Nil only in a gap between displays (then fall back to the main display).
    public static func screen(containing mouse: CGPoint, frames: [CGRect]) -> Int? {
        frames.firstIndex { f in
            mouse.x >= f.minX && mouse.x <= f.maxX && mouse.y >= f.minY && mouse.y <= f.maxY
        }
    }
}

/// The island's outline, derived from the measured notch so it fits every MacBook
/// (13/15" Air, 14/16" Pro, any display scaling): bottom corners like the notch,
/// small concave "shoulders" at the top where the island meets the menu bar.
public enum NotchGeometry {
    /// Bottom corner radius while closed: proportional to the notch height (real notches ≈ 0.3 × height).
    public static func closedRadius(notchHeight h: Double) -> Double { (h * 0.32).rounded() }
    /// Shoulder radius at the top: small, never more than a third of the height.
    public static func shoulder(notchHeight h: Double, open: Bool) -> Double { open ? min(12, (h * 0.4).rounded()) : (h * 0.22).rounded() }
    public static let openRadius = 24.0
    /// Without a notch the island hangs from the menu bar as a pill.
    public static func pillWidth(menuBarHeight h: Double) -> Double { (h * 7).rounded() }

    /// How close to the display's top edge the mouse has to be before the island opens, in points.
    public static let triggerEdge = 4.0
    /// The trigger zone stops this far inside the notch's left and right edge, so passing along the top beside the notch opens nothing.
    public static let triggerInset = 16.0
    /// How long the mouse has to rest there, so sliding along the menu bar past the notch opens nothing.
    public static let triggerDwellMilliseconds = 200
    /// How long the open island waits after the mouse left it before it folds away.
    public static let closeGraceMilliseconds = 300

    /// True only at the very top of the display, across the notch: the mouse was pushed all the
    /// way up into it. Heading for the menu bar or a toolbar below never counts.
    /// `screen` is in AppKit screen coordinates (origin bottom-left); the top edge itself counts.
    public static func isOnTopEdge(mouse: CGPoint, screen: CGRect, notchWidth: Double, edge: Double = triggerEdge) -> Bool {
        mouse.y >= screen.maxY - edge && mouse.y <= screen.maxY && abs(mouse.x - screen.midX) <= max(0, notchWidth / 2 - triggerInset)
    }
}
