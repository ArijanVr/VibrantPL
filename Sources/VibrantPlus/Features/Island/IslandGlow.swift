// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import IOKit.ps
import Observation
import SwiftUI
import VibrantPlusKit

/// How the Puls outline moves around the island.
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

/// Anything that wants the outline to light up once calls `fire()`.
@Observable
final class GlowCenter {
    static let shared = GlowCenter()
    private(set) var tick = 0
    func fire() { if Prefs.shared.islandGlow { tick += 1 } }
}

/// The Puls outline around the island: runs once on an event, and stays lit while Claude waits for the person.
struct IslandGlow: View {
    var shape: IslandShape
    var status: AgentSession.Status?
    private var center = GlowCenter.shared

    init(shape: IslandShape, status: AgentSession.Status?) {
        self.shape = shape
        self.status = status
    }

    private var holds: Bool { status == .needsPermission || status == .asking }

    @State private var statusTick = 0

    var body: some View {
        if Prefs.shared.islandGlow {
            GlowOutline(shape: shape, style: Prefs.shared.glowStyle, tick: center.tick &+ statusTick, holds: holds)
                .onChange(of: status) { _, new in
                    if new == .working || new == .waiting || new == .needsPermission || new == .asking { statusTick += 1 }
                }
        }
    }
}

/// The outline itself: every change of `tick` runs the chosen movement once; `holds` keeps it lit.
struct GlowOutline<S: Shape>: View {
    var shape: S
    var style: GlowStyle
    var tick: Int
    var holds = false
    @State private var lap: CGFloat = 0
    @State private var flash = 0.0
    @State private var grow: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let puls = Color(hex: Brand.puls)
        ZStack {
            if style == .portal {
                shape.stroke(puls, lineWidth: 2)
                    .shadow(color: puls.opacity(0.9), radius: 8)
                    .scaleEffect(grow, anchor: .top)
                    .opacity(flash)
            } else {
                shape.trim(from: lap, to: min(lap + (style == .comet ? 0.34 : 0.22), 1))
                    .stroke(puls, style: StrokeStyle(lineWidth: style == .comet ? 3 : 2, lineCap: .round))
                    .shadow(color: puls.opacity(0.9), radius: style == .comet ? 9 : 6)
                    .opacity(flash)
            }
            // A question or permission keeps the whole outline lit until it is answered.
            shape.stroke(puls, lineWidth: 1.5)
                .shadow(color: puls.opacity(0.7), radius: 5)
                .opacity(holds ? 1 : 0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: tick) { run() }
        .animation(reduceMotion ? nil : Motion.fade, value: holds)
    }

    private func run() {
        guard !reduceMotion else { return }
        lap = 0; flash = 1; grow = 1
        switch style {
        case .wave:
            withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.9)) { lap = 0.78 }
            withAnimation(.easeOut(duration: 0.4).delay(0.6)) { flash = 0 }
        case .comet:
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.7)) { lap = 0.66 }
            withAnimation(.easeOut(duration: 0.3).delay(0.45)) { flash = 0 }
        case .portal:
            withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.5)) { grow = 1.05 }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) { flash = 0 }
        }
    }
}

/// A small island in the settings that plays the movement, so it can be judged without waiting for an event.
struct GlowPreview: View {
    var style: GlowStyle
    @State private var tick = 0
    @State private var holds = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                IslandShape(radius: 20, shoulder: 8).fill(Color.black)
                GlowOutline(shape: IslandShape(radius: 20, shoulder: 8), style: style, tick: tick, holds: holds)
                Text("Vibrant+").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
            }
            .frame(width: 220, height: 56)
            HStack {
                Button("Abspielen") { tick += 1 }
                Toggle("Wartet auf mich", isOn: $holds).toggleStyle(.checkbox)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { tick += 1 } }
        .onChange(of: style) { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { tick += 1 } }
    }
}

/// Lights the outline when the Mac is plugged in.
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
