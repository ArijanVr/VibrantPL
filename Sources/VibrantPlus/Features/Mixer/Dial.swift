// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Observation
import SwiftUI
import VibrantPlusKit

/// A slim tab on the screen edge. Hovering it slides out the dial panel:
/// volume, a mixer for each app, and a timer.
final class DialController {
    static let shared = DialController()

    private var tab: NSPanel?
    private var panel: NSPanel?
    private var monitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var closeTask: Task<Void, Never>?
    /// True from the start of the slide-in to the start of the slide-out.
    private var shown = false

    func start() {
        guard tab == nil else { return }
        let t = makePanel(size: CGSize(width: Metrics.dialTabWidth, height: Metrics.dialTabHeight))
        t.contentView = Self.host(DialTab())
        t.ignoresMouseEvents = true
        tab = t
        let p = makePanel(size: CGSize(width: Metrics.dialPanelWidth, height: 420))
        p.contentView = Self.host(DialPanel().themed())
        panel = p
        relayout()
        t.orderFrontRegardless()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved() }
        }
        // A display plugged in or out, a new resolution or scaling, the Dock moved: put the
        // tab back on the edge. Without this it stays where the old layout had it.
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.relayout() }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        tab?.orderOut(nil); tab = nil
        shown = false
        panel?.orderOut(nil); panel = nil
        AppMixer.shared.resetAll()
    }

    /// A hosting view that never resizes its window (Vibrant+ places its panels itself).
    static func host<V: View>(_ view: V) -> NSHostingView<V> {
        let h = NSHostingView(rootView: view)
        h.sizingOptions = []
        return h
    }

    private func makePanel(size: CGSize) -> NSPanel {
        let p = IslandPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        p.hidesOnDeactivate = false
        p.hasShadow = true
        return p
    }

    /// The display the tab sits on, so tab, edge test and panel always agree. `NSScreen.main`
    /// follows the key window, which jumps between displays as the person works; it is only
    /// the fallback when the tab has no display yet (first start, its display was unplugged).
    private var screen: NSScreen? { tab?.screen ?? NSScreen.main }

    func relayout() {
        guard let screen, let tab, let panel else { return }
        let left = Prefs.shared.dialLeftEdge
        let v = screen.visibleFrame
        tab.setFrameOrigin(CGPoint(x: left ? v.minX : v.maxX - Metrics.dialTabWidth, y: v.midY - Metrics.dialTabHeight / 2))
        panel.setFrameOrigin(restingOrigin(panel, in: v, left: left))
    }

    private func restingOrigin(_ panel: NSPanel, in v: CGRect, left: Bool) -> CGPoint {
        let size = panel.frame.size
        return CGPoint(x: left ? v.minX + 4 : v.maxX - size.width - 4, y: v.midY - size.height / 2)
    }

    /// The panel comes from the edge its tab sits on and goes back there.
    /// With Reduce motion it only appears and disappears.
    private var slide: CGFloat {
        let d: CGFloat = Motion.reduceMotion ? 0 : 12
        return Prefs.shared.dialLeftEdge ? -d : d
    }

    private func show(_ panel: NSPanel) {
        guard let screen else { return }
        let rest = restingOrigin(panel, in: screen.visibleFrame, left: Prefs.shared.dialLeftEdge)
        shown = true
        panel.setFrameOrigin(CGPoint(x: rest.x + slide, y: rest.y))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Motion.duration(Motion.panelIn)
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(rest)
            panel.animator().alphaValue = 1
        }
    }

    private func hide(_ panel: NSPanel) {
        shown = false
        let rest = panel.frame.origin
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Motion.duration(Motion.panelOut)
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrameOrigin(CGPoint(x: rest.x + slide, y: rest.y))
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                // Opened again while it was going: leave it.
                if !DialController.shared.shown { panel.orderOut(nil) }
            }
        }
    }

    private func mouseMoved() {
        guard let tab, let panel, let screen else { return }
        let p = NSEvent.mouseLocation
        let left = Prefs.shared.dialLeftEdge
        let atEdge = left ? p.x <= screen.frame.minX + 2 : p.x >= screen.frame.maxX - 3
        let nearTab = atEdge && abs(p.y - tab.frame.midY) < Metrics.dialTabHeight / 2
        if !shown, nearTab {
            closeTask?.cancel()
            AppMixer.shared.refresh()
            AudioDevices.shared.refresh()
            DialState.shared.refresh()
            relayout()
            show(panel)
        } else if shown, !panel.frame.insetBy(dx: -16, dy: -16).contains(p) {
            closeTask?.cancel()
            closeTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled, self.shown, !panel.frame.insetBy(dx: -16, dy: -16).contains(NSEvent.mouseLocation) else { return }
                self.hide(panel)
            }
        }
    }
}

@Observable
final class DialState {
    static let shared = DialState()
    var volume: Double = Double(SystemVolume.volume() ?? 0.5)
    var muted = SystemVolume.isMuted()
    var timerMinutes: Double = 10

    func refresh() {
        volume = Double(SystemVolume.volume() ?? Float(volume))
        muted = SystemVolume.isMuted()
    }

    func setVolume(_ v: Double) {
        volume = max(0, min(1, v))
        SystemVolume.setVolume(Float(volume))
        if muted && volume > 0 { muted = false; SystemVolume.setMuted(false) }
    }

    func toggleMute() {
        muted.toggle()
        SystemVolume.setMuted(muted)
    }
}

struct DialTab: View {
    var body: some View {
        Capsule().fill(IslandColor.accent.opacity(0.55))
            .frame(width: 4, height: Metrics.dialTabHeight - 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Rand-Regler")
    }
}

struct DialPanel: View {
    @State private var state = DialState.shared
    private var mixer = AppMixer.shared
    private var timer = QuickTimer.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.lg) {
                Dial(value: Binding(get: { state.volume }, set: { state.setVolume($0) }),
                     symbol: state.muted ? "speaker.slash.fill" : "speaker.wave.2.fill", label: "Lautstärke",
                     text: "\(Int(state.volume * 100)) %") { state.toggleMute() }
                timerDial
            }
            Divider().overlay(IslandColor.separator)
            Text("Mixer").font(TypeStyle.islandLabel).foregroundStyle(IslandColor.secondaryText)
            if mixer.apps.isEmpty {
                Text("Gerade spielt keine App Ton.").font(TypeStyle.islandCaption).foregroundStyle(IslandColor.tertiaryText)
            }
            ForEach(mixer.apps) { app in
                HStack(spacing: Space.sm) {
                    Image(nsImage: app.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)!)
                        .resizable().frame(width: 20, height: 20)
                    Text(app.name).font(TypeStyle.islandCaption).lineLimit(1).frame(width: 72, alignment: .leading)
                    Slider(value: Binding(get: { Double(mixer.level(of: app)) },
                                          set: { mixer.setLevel(Float($0), for: app) }), in: 0...2)
                        .accessibilityLabel("Lautstärke \(app.name)")
                    Text("\(Int(mixer.level(of: app) * 100)) %").font(TypeStyle.islandMicro).foregroundStyle(IslandColor.secondaryText).frame(width: 36, alignment: .trailing)
                    Button {
                        mixer.toggleFavorite(app)
                    } label: {
                        Image(systemName: mixer.isFavorite(app) ? "star.fill" : "star")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mixer.isFavorite(app) ? "Favorit entfernen" : "Als Favorit merken")
                    Menu {
                        Button("Systemstandard") { mixer.setOutput(nil, for: app) }
                        ForEach(AudioDevices.shared.devices.filter(\.output)) { device in
                            Button(device.name) { mixer.setOutput(device.uid, for: app) }
                        }
                    } label: {
                        Image(systemName: mixer.output(of: app) == nil ? "hifispeaker" : "hifispeaker.fill")
                    }
                    .accessibilityLabel("Ausgang \(app.name)")
                }
            }
            if let e = mixer.error {
                Text(e).font(TypeStyle.islandMicro).foregroundStyle(IslandColor.warm)
                Button("Systemeinstellungen öffnen") { Permission.audioCapture.openSettings() }
                    .buttonStyle(.plain).font(TypeStyle.islandLabel).foregroundStyle(IslandColor.accentText)
            }
            Text("Bildschirm- und Tastaturhelligkeit: macOS bietet dafür keine öffentliche Schnittstelle.")
                .font(TypeStyle.islandMicro).foregroundStyle(IslandColor.tertiaryText)
        }
        .padding(Space.lg)
        .frame(width: Metrics.dialPanelWidth, alignment: .topLeading)
        .islandBackground(RoundedRectangle(cornerRadius: Radius.island, style: .continuous), open: true)
        .overlay(RoundedRectangle(cornerRadius: Radius.island, style: .continuous).strokeBorder(IslandColor.separator))
        .foregroundStyle(IslandColor.primaryText)
        .environment(\.colorScheme, IslandColor.scheme)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var timerDial: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            Dial(value: Binding(get: { timer.running ? timer.remaining(at: ctx.date) / max(1, timer.length) : state.timerMinutes / 60 },
                                set: { if !timer.running { state.timerMinutes = max(1, ($0 * 60).rounded()) } }),
                 symbol: timer.running ? "stop.fill" : "play.fill", label: "Timer",
                 text: timer.running ? Clock.format(timer.remaining(at: ctx.date)) : "\(Int(state.timerMinutes)) Min.") {
                timer.running ? timer.cancel() : timer.start(minutes: state.timerMinutes)
            }
        }
    }
}

/// A round dial: drag up/down or scroll to turn, click the center for its action.
struct Dial: View {
    @Binding var value: Double
    var symbol: String
    var label: String
    var text: String
    var action: () -> Void
    @State private var dragStart: Double?

    var body: some View {
        VStack(spacing: Space.xs) {
            ZStack {
                Circle().stroke(IslandColor.card, lineWidth: 8)
                Circle().trim(from: 0, to: max(0.001, min(1, value)) * 0.8)
                    .stroke(IslandColor.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(126))
                Button(action: action) {
                    Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(IslandColor.cardHover, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .frame(width: 92, height: 92)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 2).onChanged { g in
                if dragStart == nil { dragStart = value }
                value = max(0, min(1, (dragStart ?? value) - g.translation.height / 160))
            }.onEnded { _ in dragStart = nil })
            .onScrollWheel { delta in value = max(0, min(1, value + delta / 300)) }
            Text(text).font(TypeStyle.islandCaption.monospacedDigit()).foregroundStyle(IslandColor.secondaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(text)
        .accessibilityAdjustableAction { dir in
            value = max(0, min(1, value + (dir == .increment ? 0.05 : -0.05)))
        }
        .accessibilityAction(named: "Umschalten", action)
    }
}

private struct ScrollWheel: NSViewRepresentable {
    var onScroll: (Double) -> Void
    func makeNSView(context: Context) -> ScrollView { let v = ScrollView(); v.onScroll = onScroll; return v }
    func updateNSView(_ v: ScrollView, context: Context) { v.onScroll = onScroll }

    final class ScrollView: NSView {
        var onScroll: ((Double) -> Void)?
        override func scrollWheel(with event: NSEvent) { onScroll?(Double(event.scrollingDeltaY)) }
        override func hitTest(_ point: NSPoint) -> NSView? { nil == onScroll ? nil : super.hitTest(point) }
    }
}

extension View {
    func onScrollWheel(_ action: @escaping (Double) -> Void) -> some View {
        background(ScrollWheel(onScroll: action))
    }
}
