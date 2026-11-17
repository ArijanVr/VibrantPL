// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Pulsi: a small Puls-pink creature that lives on the notch. Its eyes follow the mouse and it blinks.
/// Drawn from shapes in the brand colors (Puls, Off-White, Black), so it needs no assets.
struct PulsMascot: View {
    /// Where the mascot sits on screen (AppKit coordinates, origin bottom left): the eyes look from there to the mouse.
    var anchor: CGPoint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let size = CGSize(width: 46, height: 38)

    enum Mood { case normal, happy, lifted }
    var mood: Mood = .normal

    var body: some View {
        // 24 frames per second are enough for eyes; the view exists only while the mascot is shown.
        TimelineView(.animation(minimumInterval: 1.0 / 24)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            face(look: look(), blink: t.truncatingRemainder(dividingBy: 4.2) < 0.12)
                .offset(y: reduceMotion ? 0 : sin(t * 2.2) * 1.2)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .accessibilityHidden(true)
    }

    /// The direction to the mouse, at most one unit long. AppKit's y points up, SwiftUI's down.
    private func look() -> CGSize {
        let m = NSEvent.mouseLocation
        let dx = m.x - anchor.x, dy = anchor.y - m.y
        let length = max(1, hypot(dx, dy))
        let strength = min(1, length / 120)
        return CGSize(width: dx / length * strength, height: dy / length * strength)
    }

    private func face(look: CGSize, blink: Bool) -> some View {
        let puls = Color(hex: Brand.puls), ink = Color(hex: Brand.pulsInk)
        return ZStack {
            HStack(spacing: 20) {
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(ink).frame(width: 10, height: 11).rotationEffect(.degrees(-14))
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(ink).frame(width: 10, height: 11).rotationEffect(.degrees(14))
            }
            .offset(y: -15)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [puls, ink], startPoint: .top, endPoint: .bottom))
                .frame(width: 40, height: 32)
            // The brand's pulse line across the forehead.
            PulseLine()
                .stroke(Color(hex: Brand.offWhite).opacity(0.9), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .frame(width: 16, height: 6)
                .offset(y: -9)
            HStack(spacing: 7) { eye(look, blink); eye(look, blink) }.offset(y: 1)
            mouth.offset(y: 10)
        }
    }

    @ViewBuilder private var mouth: some View {
        let ink = Color(hex: Brand.black).opacity(0.75)
        switch mood {
        case .normal:
            Smile().stroke(ink, style: StrokeStyle(lineWidth: 1.4, lineCap: .round)).frame(width: 8, height: 3)
        case .happy:
            Smile().fill(ink).frame(width: 11, height: 5)
        case .lifted:
            Ellipse().fill(ink).frame(width: 5, height: 6)
        }
    }

    @ViewBuilder private func eye(_ look: CGSize, _ blink: Bool) -> some View {
        if mood == .happy {
            // Happy eyes: a small arch.
            HappyEye().stroke(Color(hex: Brand.black), style: StrokeStyle(lineWidth: 2, lineCap: .round)).frame(width: 9, height: 5).frame(width: 11, height: 11)
        } else {
            openEye(look, blink)
        }
    }

    private func openEye(_ look: CGSize, _ blink: Bool) -> some View {
        ZStack {
            Ellipse().fill(Color(hex: Brand.offWhite)).frame(width: mood == .lifted ? 12 : 11, height: blink ? 1.5 : (mood == .lifted ? 12 : 11))
            if !blink {
                Circle().fill(Color(hex: Brand.black)).frame(width: 5, height: 5).offset(x: look.width * 2.6, y: look.height * 2.6)
            }
        }
    }
}

private nonisolated struct PulseLine: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let points: [(CGFloat, CGFloat)] = [(0, 0.5), (0.25, 0.5), (0.36, 0), (0.5, 1), (0.62, 0.25), (0.72, 0.5), (1, 0.5)]
        p.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.5))
        for (x, y) in points.dropFirst() { p.addLine(to: CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y)) }
        return p
    }
}

private nonisolated struct Smile: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY * 1.6))
        return p
    }
}

private nonisolated struct HappyEye: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height * 0.6))
        return p
    }
}
