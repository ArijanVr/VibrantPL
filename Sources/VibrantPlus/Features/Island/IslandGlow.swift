// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import IOKit.ps
import Observation
import SwiftUI
import VibrantPlusKit

/// Kept so a saved «island.glowStyle» still decodes. The rim itself is one warm light, not three motions.
enum GlowStyle: String, CaseIterable, Identifiable {
    case wave, comet, portal
    var id: String { rawValue }
    var title: String {
        switch self {
        case .wave: "Lichtwelle"
        case .comet: "Komet"
        case .portal: "Portal"
        }
    }
}

/// Anything that wants the rim to light up once calls `fire()`.
@Observable
final class GlowCenter {
    static let shared = GlowCenter()
    private(set) var tick = 0
    func fire() { if Prefs.shared.islandGlow { tick += 1 } }
}

/// A warm rim on the outside of the island. It sits behind the black body, so it never covers text.
struct IslandGlow: View {
    var shape: IslandShape
    var status: AgentSession.Status?
    /// The island is open. With «Dauerlauf» the rim keeps breathing on the edge.
    var open = false
    private var center = GlowCenter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var event = 0.0
    @State private var pulsing = false

    init(shape: IslandShape, status: AgentSession.Status?, open: Bool = false) {
        self.shape = shape
        self.status = status
        self.open = open
    }

    private var attention: Bool { status == .needsPermission || status == .asking }

    /// Claude is working, or the person asked the rim to stay on while the island is open.
    private var breathes: Bool {
        guard !attention else { return false }
        if status == .working { return true }
        return open && Prefs.shared.glowWhileOpen
    }

    var body: some View {
        let _ = center.tick
        let color = attention ? Color(hex: Brand.bernsteinHell) : Color(hex: Brand.pulsHell)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !breathes || pulsing)) { timeline in
            rim(color, opacity(at: timeline.date))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: center.tick) {
            guard status != .working, !attention else { return }
            playPulse()
        }
        .onChange(of: status) { old, new in
            // End of a turn: one short pulse, then the rim leaves (or the open-island breath returns).
            if old == .working, new == .waiting || new == .ended || new == nil { playPulse() }
        }
    }

    private func opacity(at date: Date) -> Double {
        if pulsing { return reduceMotion ? GlowSpec.opacityStatic : event }
        if attention || breathes {
            if reduceMotion || attention { return GlowSpec.opacityStatic }
            let t = date.timeIntervalSinceReferenceDate
            return 0.25 + 0.05 * sin(2 * .pi * t / GlowSpec.breathPeriod)
        }
        return 0
    }

    /// Rise to 0.30 and fade out. Together about 0.45 s. Reduce motion holds 0.24, with no breath.
    private func playPulse() {
        if reduceMotion {
            pulsing = true
            event = GlowSpec.opacityStatic
            DispatchQueue.main.asyncAfter(deadline: .now() + GlowSpec.successPulseDuration) {
                event = 0
                pulsing = false
            }
            return
        }
        pulsing = true
        event = GlowSpec.opacityMin
        withAnimation(.easeIn(duration: 0.15)) { event = GlowSpec.opacityMax }
        withAnimation(.easeOut(duration: GlowSpec.fadeOutDuration).delay(0.15)) { event = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + GlowSpec.successPulseDuration) {
            pulsing = false
        }
    }

    private func rim(_ color: Color, _ opacity: Double) -> some View {
        let outline = IslandOutline(island: shape)
        return outline
            .stroke(color, style: StrokeStyle(lineWidth: GlowSpec.saumWidth, lineCap: .round, lineJoin: .round))
            .blur(radius: GlowSpec.blurRadius)
            .opacity(opacity)
            // Only the light outside the body remains. Text sits on the black fill, not on this rim.
            .mask {
                // The mask reaches past the frame, or the light outside the island is cut off with a hard edge.
                ZStack {
                    Rectangle().padding(-(GlowSpec.saumWidth + GlowSpec.blurRadius * 2))
                    shape.fill(Color.black).blendMode(.destinationOut)
                }
                .compositingGroup()
            }
    }
}

extension View {
    /// A soft light under a card. The card's own fill stays in front, so the light never covers its text.
    func cardUnderGlow(_ color: Color, active: Bool = true) -> some View {
        background {
            if active {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(color, lineWidth: GlowSpec.saumWidth)
                    .blur(radius: GlowSpec.blurRadius)
                    .opacity(GlowSpec.opacityStatic)
                    .offset(y: 6)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// A small island in settings, so the rim can be judged without waiting for Claude.
struct GlowPreview: View {
    @State private var tick = 0
    @State private var holds = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = IslandShape(radius: 20, shoulder: 8)
        VStack(spacing: 8) {
            ZStack {
                shape.fill(Color(hex: Brand.black))
                Text("Vibrant+").font(.caption.weight(.semibold)).foregroundStyle(Color(hex: Brand.porzellan))
            }
            .background {
                IslandGlow(shape: shape,
                           status: holds ? .needsPermission : (tick > 0 ? .working : nil),
                           open: Prefs.shared.glowWhileOpen)
            }
            .frame(width: 220, height: 56)
            HStack {
                Button("Abspielen") { tick += 1 }
                Toggle("Wartet auf mich", isOn: $holds).toggleStyle(.checkbox)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

/// Lights the rim when the Mac is plugged in.
final class ChargeGlow {
    static let shared = ChargeGlow()
    private var source: CFRunLoopSource?
    private var wasOnAC = ChargeGlow.onAC()

    static func onAC() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return type as String == kIOPSACPowerValue
    }

    func start() {
        guard source == nil else { return }
        wasOnAC = Self.onAC()
        let callback: IOPowerSourceCallbackType = { _ in
            DispatchQueue.main.async { ChargeGlow.shared.changed() }
        }
        guard let s = IOPSNotificationCreateRunLoopSource(callback, nil)?.takeRetainedValue() else { return }
        source = s
        CFRunLoopAddSource(CFRunLoopGetMain(), s, .commonModes)
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
    }

    private func changed() {
        let now = Self.onAC()
        defer { wasOnAC = now }
        if now && !wasOnAC && Prefs.shared.chargeGlow { GlowCenter.shared.fire() }
    }
}
