// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// While the island is open, the rest of the screen steps back: a soft wash that falls from the
/// notch, in the colors of the chosen island style (black for Notch-Schwarz, a blur for Liquid Glass). Purely visual: clicks pass through, and a click
/// anywhere folds the island as before.
final class ScrimController {
    static let shared = ScrimController()

    private var panel: NSPanel?
    private var effect: NSVisualEffectView?
    private var tint: NSHostingView<ScrimTint>?

    func show(on screen: NSScreen, below island: NSWindow) {
        guard Prefs.shared.dimAround else { return }
        let p = panel ?? make()
        p.setFrame(screen.frame, display: false)
        let glass = IslandTheme.shared.drawsGlass
        effect?.isHidden = !glass
        effect?.maskImage = Self.fallingMask(size: screen.frame.size)
        tint?.rootView = ScrimTint(style: IslandTheme.shared.style)
        p.order(.below, relativeTo: island.windowNumber)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Motion.duration(Motion.panelIn)
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            p.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let p = panel, p.isVisible else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Motion.duration(Motion.panelOut)
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            p.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { if p.alphaValue == 0 { p.orderOut(nil) } }
        }
    }

    private func make() -> NSPanel {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        p.alphaValue = 0
        let root = NSView()
        let e = NSVisualEffectView()
        e.material = .fullScreenUI
        e.blendingMode = .behindWindow
        e.state = .active
        e.autoresizingMask = [.width, .height]
        root.addSubview(e)
        let host = NSHostingView(rootView: ScrimTint(style: IslandTheme.shared.style))
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]
        root.addSubview(host)
        p.contentView = root
        e.frame = root.bounds
        host.frame = root.bounds
        effect = e
        tint = host
        panel = p
        return p
    }

    /// Strong at the top, gone by the middle of the screen: the blur falls from the notch.
    private static func fallingMask(size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            let g = NSGradient(colors: [.black, NSColor.black.withAlphaComponent(0.55), .clear],
                               atLocations: [0, 0.35, 1], colorSpace: .sRGB)
            g?.draw(in: rect, angle: -90)
            return true
        }
    }
}

/// The colored wash. Radial from the notch, so it reads as light falling from the island.
struct ScrimTint: View {
    var style: IslandStyle

    var body: some View {
        GeometryReader { geo in
            let color = Color.black
            let strength: Double = switch style {
            case .notch: 0.45
            case .glass: 0.18
            }
            ZStack {
                // A light veil over everything, so the island stands forward …
                color.opacity(strength * 0.35)
                // … and a stronger fall-off right under the notch.
                RadialGradient(colors: [color.opacity(strength), color.opacity(0)],
                               center: UnitPoint(x: 0.5, y: 0), startRadius: 0,
                               endRadius: max(geo.size.width, geo.size.height) * 0.62)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
