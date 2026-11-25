// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Pulsi: a small porcelain creature that lives on the notch. Its eyes follow the mouse and it blinks.
/// Body in Kreide with a Naht edge, face in Tinte, the forehead pulse in Puls. Photos are for welcome,
/// empty states and success. This drawing is the optional companion on the notch.
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
        let body = Color(hex: Brand.kreide)
        let edge = Color(hex: Brand.naht)
        return ZStack {
            HStack(spacing: 20) {
                ear(-14)
                ear(14)
            }
            .offset(y: -15)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(body)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(edge, lineWidth: 0.8))
                .frame(width: 40, height: 32)
            HStack(spacing: 14) {
                Ellipse().fill(Color(hex: Brand.puls).opacity(0.28)).frame(width: 6, height: 3.5)
                Ellipse().fill(Color(hex: Brand.puls).opacity(0.28)).frame(width: 6, height: 3.5)
            }
            .offset(y: 6)
            PulseLine()
                .stroke(Color(hex: Brand.puls), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .frame(width: 16, height: 6)
                .offset(y: -9)
            HStack(spacing: 7) { eye(look, blink); eye(look, blink) }.offset(y: 1)
            mouth.offset(y: 10)
        }
    }

    /// A porcelain ear with a soft Puls tip.
    private func ear(_ degrees: Double) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(hex: Brand.kreide))
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Color(hex: Brand.naht), lineWidth: 0.6))
            Capsule().fill(Color(hex: Brand.pulsHell)).frame(height: 4)
        }
        .frame(width: 10, height: 11)
        .rotationEffect(.degrees(degrees))
    }

    @ViewBuilder private var mouth: some View {
        let ink = Color(hex: Brand.tinte)
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
            HappyEye().stroke(Color(hex: Brand.tinte), style: StrokeStyle(lineWidth: 2, lineCap: .round)).frame(width: 9, height: 5).frame(width: 11, height: 11)
        } else {
            openEye(look, blink)
        }
    }

    private func openEye(_ look: CGSize, _ blink: Bool) -> some View {
        ZStack {
            Ellipse().fill(Color(hex: Brand.tinte))
                .frame(width: mood == .lifted ? 12 : 11, height: blink ? 1.5 : (mood == .lifted ? 12 : 11))
            if !blink {
                Circle().fill(Color.white).frame(width: 2.4, height: 2.4)
                    .offset(x: -2.2 + look.width * 1.4, y: -2.2 + look.height * 1.4)
            }
        }
    }
}

/// Porcelain Pulsi from the brand photos. Welcome, empty states and success only.
struct PulsiImage: View {
    enum Pose: String {
        case frontal = "pulsi-frontal"
        case willkommen = "pulsi-willkommen"
        case leerzustand = "pulsi-leerzustand"
        case erfolg = "pulsi-erfolg"
        case badge = "pulsi-badge"
    }

    var pose: Pose
    var height: CGFloat
    var fallbackSymbol: String = "sparkle"

    var body: some View {
        Group {
            if let image = Self.load(pose) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: height * 0.45, weight: .medium))
                    .foregroundStyle(IslandColor.tertiaryText)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    static func load(_ pose: Pose) -> NSImage? {
        let name = pose.rawValue
        if let url = Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "Pulsi"),
           let image = NSImage(contentsOf: url) { return image }
        if let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
           let image = NSImage(contentsOf: url) { return image }
        return nil
    }
}

/// An empty window: Pulsi, a title, one sentence. Not for search misses or settings forms.
struct PulsiEmpty: View {
    var title: String
    var text: String
    var pose: PulsiImage.Pose = .leerzustand

    var body: some View {
        VStack(spacing: Space.lg) {
            PulsiImage(pose: pose, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            Text(title).font(TypeStyle.title)
            Text(text)
                .font(TypeStyle.body)
                .foregroundStyle(Surface.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
