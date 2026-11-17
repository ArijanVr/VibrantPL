// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics
import Foundation

/// A small reader for SVG path data, enough for the brand artwork Vibrant+ draws in code
/// (the wordmark): M, L, H, V, Q, Z, absolute and relative, and A for half circles,
/// the only arcs the artwork uses. Anything else returns nil, so a changed artwork fails
/// loudly in the tests instead of drawing something wrong.
public enum SVGPath {
    public static func parse(_ d: String) -> CGPath? {
        guard let regex = try? NSRegularExpression(pattern: #"[A-Za-z]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?"#) else { return nil }
        let ns = d as NSString
        let tokens = regex.matches(in: d, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }

        let path = CGMutablePath()
        var i = 0
        var command: Character = " "
        var current = CGPoint.zero
        var start = CGPoint.zero

        func isCommand(_ t: String) -> Bool { t.count == 1 && t.first!.isLetter }
        func number() -> CGFloat? {
            guard i < tokens.count, !isCommand(tokens[i]), let v = Double(tokens[i]) else { return nil }
            i += 1
            return CGFloat(v)
        }
        func point(relative: Bool) -> CGPoint? {
            guard let x = number(), let y = number() else { return nil }
            return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
        }

        while i < tokens.count {
            if isCommand(tokens[i]) {
                command = tokens[i].first!
                i += 1
            } else if command == " " {
                return nil
            }
            let relative = command.isLowercase
            switch command.uppercased().first! {
            case "M":
                guard let p = point(relative: relative) else { return nil }
                path.move(to: p)
                current = p
                start = p
                // Further pairs after a move are lines.
                command = relative ? "l" : "L"
            case "L":
                guard let p = point(relative: relative) else { return nil }
                path.addLine(to: p)
                current = p
            case "H":
                guard let x = number() else { return nil }
                current = CGPoint(x: relative ? current.x + x : x, y: current.y)
                path.addLine(to: current)
            case "V":
                guard let y = number() else { return nil }
                current = CGPoint(x: current.x, y: relative ? current.y + y : y)
                path.addLine(to: current)
            case "Q":
                guard let c = point(relative: relative), let p = point(relative: relative) else { return nil }
                path.addQuadCurve(to: p, control: c)
                current = p
            case "A":
                guard let rx = number(), let ry = number(), let _ = number(),
                      let large = number(), let sweep = number(), let p = point(relative: relative) else { return nil }
                guard addHalfCircle(path, from: current, to: p, radius: (rx + ry) / 2,
                                    large: large != 0, sweep: sweep != 0) else { return nil }
                current = p
            case "Z":
                path.closeSubpath()
                current = start
                command = " "
            default:
                return nil
            }
        }
        return path
    }

    /// A half circle between two points `2 × radius` apart, drawn as two tangent arcs
    /// (independent of whether the y axis points up or down). `sweep` follows SVG: in
    /// y-down coordinates it turns clockwise on screen.
    static func addHalfCircle(_ path: CGMutablePath, from a: CGPoint, to b: CGPoint, radius r: CGFloat,
                              large: Bool, sweep: Bool) -> Bool {
        let dx = b.x - a.x, dy = b.y - a.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard r > 0, abs(length - 2 * r) < 0.01 * r, !large || abs(length - 2 * r) < 0.01 * r else { return false }
        // Unit normal on the side the arc bulges to.
        let side: CGFloat = sweep ? 1 : -1
        let n = CGPoint(x: side * dy / length * r, y: -side * dx / length * r)
        let center = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let top = CGPoint(x: center.x + n.x, y: center.y + n.y)
        path.addArc(tangent1End: CGPoint(x: a.x + n.x, y: a.y + n.y), tangent2End: top, radius: r)
        path.addArc(tangent1End: CGPoint(x: b.x + n.x, y: b.y + n.y), tangent2End: b, radius: r)
        return true
    }
}
