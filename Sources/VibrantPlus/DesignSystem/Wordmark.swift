// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import VibrantPlusKit

/// The Vibrant+ wordmark, Brandguide V1.0 (04): «Vibrant» in Geist Medium (path data copied unchanged from
/// Design/Wortmarke/Vibrant-Plus_Wortmarke_*_v1.svg), and a «+» in Puls, round ends, tilted -8°, top aligned
/// with the cap height. The «+» is its own shape, so it takes the accent color while the text takes the given one.
/// Both shapes share one box, so they line up in a ZStack.
nonisolated struct Wordmark: Shape {
    /// Only the «+», not the text.
    var plusOnly = false

    func path(in rect: CGRect) -> Path {
        guard let text = Self.text else { return Path() }
        let box = Self.box
        let s = min(rect.width / box.width, rect.height / box.height)
        let t = CGAffineTransform(translationX: rect.midX - box.midX * s, y: rect.midY - box.midY * s).scaledBy(x: s, y: s)
        let part = plusOnly ? Self.plus : text
        return Path(part.copy(using: [t]) ?? part)
    }

    /// Width / height of the drawn artwork, for frames.
    static var aspectRatio: CGFloat {
        guard box.height > 0 else { return 3.4 }
        return box.width / box.height
    }

    private static var box: CGRect {
        guard let text else { return .zero }
        return text.boundingBoxOfPath.union(plus.boundingBoxOfPath)
    }

    private nonisolated(unsafe) static let text: CGPath? = SVGPath.parse(textPath)

    /// A «+» with round ends: two capsules of stroke 92 and arm length 300 (units of the text path, 1000 per em),
    /// centred right of the «t», cap-height top, turned -8° like the text.
    private nonisolated(unsafe) static let plus: CGPath = {
        let cx: CGFloat = 3480, cy: CGFloat = -560, arm: CGFloat = 150, r: CGFloat = 46
        let p = CGMutablePath()
        p.addRoundedRect(in: CGRect(x: cx - arm, y: cy - r, width: arm * 2, height: r * 2), cornerWidth: r, cornerHeight: r)
        p.addRoundedRect(in: CGRect(x: cx - r, y: cy - arm, width: r * 2, height: arm * 2), cornerWidth: r, cornerHeight: r)
        // Rotation about (cx, cy): p' = R(p - c) + c, written out as one matrix.
        let θ: CGFloat = -8 * .pi / 180
        let (c, s) = (cos(θ), sin(θ))
        let turn = CGAffineTransform(a: c, b: s, c: -s, d: c, tx: cx - c * cx + s * cy, ty: cy - s * cx - c * cy)
        return p.copy(using: [turn]) ?? p
    }()

    private static let textPath = "M276 0 20 -710H135L344 -120L553 -710H668L411 0ZM727.0 0V-532H833.0V0ZM725.0 -609V-715H835.0V-609ZM1218.0 12Q1163.0 12 1120.5 -12.5Q1078.0 -37 1055.0 -80L1052.0 0H953.0V-710H1059.0V-457Q1080.0 -492 1121.5 -518.0Q1163.0 -544 1218.0 -544Q1287.0 -544 1338.0 -510.0Q1389.0 -476 1416.5 -413.5Q1444.0 -351 1444.0 -266Q1444.0 -181 1416.5 -118.5Q1389.0 -56 1338.0 -22.0Q1287.0 12 1218.0 12ZM1201.0 -80Q1262.0 -80 1298.0 -129.5Q1334.0 -179 1334.0 -266Q1334.0 -353 1298.0 -402.5Q1262.0 -452 1202.0 -452Q1157.0 -452 1125.0 -430.0Q1093.0 -408 1076.0 -366.5Q1059.0 -325 1059.0 -266Q1059.0 -209 1076.0 -167.0Q1093.0 -125 1125.0 -102.5Q1157.0 -80 1201.0 -80ZM1539.0 0V-532H1636.0L1640.0 -391L1631.0 -394Q1642.0 -466 1675.5 -499.0Q1709.0 -532 1766.0 -532H1817.0V-437H1766.0Q1726.0 -437 1699.0 -424.0Q1672.0 -411 1658.5 -384.0Q1645.0 -357 1645.0 -314V0ZM2032.0 12Q1949.0 12 1899.5 -26.0Q1850.0 -64 1850.0 -133Q1850.0 -202 1891.5 -240.5Q1933.0 -279 2020.0 -296L2203.0 -331Q2203.0 -393 2174.0 -423.5Q2145.0 -454 2088.0 -454Q2037.0 -454 2008.0 -431.5Q1979.0 -409 1968.0 -365L1859.0 -372Q1874.0 -452 1933.5 -498.0Q1993.0 -544 2088.0 -544Q2196.0 -544 2252.5 -486.5Q2309.0 -429 2309.0 -325V-118Q2309.0 -99 2315.5 -91.5Q2322.0 -84 2337.0 -84H2356.0V0Q2351.0 1 2340.0 2.0Q2329.0 3 2317.0 3Q2283.0 3 2258.5 -8.0Q2234.0 -19 2222.0 -44.5Q2210.0 -70 2210.0 -113L2221.0 -108Q2213.0 -73 2186.5 -46.0Q2160.0 -19 2119.5 -3.5Q2079.0 12 2032.0 12ZM2049.0 -72Q2097.0 -72 2131.0 -90.5Q2165.0 -109 2184.0 -142.0Q2203.0 -175 2203.0 -217V-251L2047.0 -221Q1999.0 -212 1979.5 -192.5Q1960.0 -173 1960.0 -143Q1960.0 -109 1983.5 -90.5Q2007.0 -72 2049.0 -72ZM2433.0 0V-532H2530.0L2534.0 -390L2521.0 -397Q2530.0 -449 2555.0 -481.0Q2580.0 -513 2616.0 -528.5Q2652.0 -544 2694.0 -544Q2754.0 -544 2793.5 -517.5Q2833.0 -491 2853.5 -445.5Q2874.0 -400 2874.0 -342V0H2768.0V-310Q2768.0 -357 2758.0 -389.0Q2748.0 -421 2725.0 -438.0Q2702.0 -455 2665.0 -455Q2609.0 -455 2574.0 -418.0Q2539.0 -381 2539.0 -310V0ZM3178.0 0Q3102.0 0 3066.0 -35.0Q3030.0 -70 3030.0 -144V-657H3136.0V-152Q3136.0 -115 3152.0 -101.0Q3168.0 -87 3201.0 -87H3277.0V0ZM2949.0 -445V-532H3277.0V-445Z"
}

extension Wordmark {
    /// The wordmark as a view: the text in `color`, the «+» in Puls. VoiceOver reads «Vibrant+».
    @MainActor static func view(height: CGFloat, color: some ShapeStyle = Color.primary) -> some View {
        ZStack {
            Wordmark().fill(color)
            Wordmark(plusOnly: true).fill(Color(hex: Brand.puls))
        }
        .frame(width: height * aspectRatio, height: height)
        .accessibilityElement()
        .accessibilityLabel("Vibrant+")
        .accessibilityAddTraits(.isImage)
    }
}
