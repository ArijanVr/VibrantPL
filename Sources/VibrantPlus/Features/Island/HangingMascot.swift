// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// Pulsi on the open island: a click makes it jump, wiggle or pop (always with hearts), a drag moves it
/// anywhere on the island, and it lands with a squash. The position is kept.
struct HangingMascot: View {
    /// The window's size: the island is centered in it, at the top.
    var container: CGSize
    private var model = IslandModel.shared
    private var prefs = Prefs.shared
    private var voice = PulsiVoice.shared
    private var wake = PulsiWake.shared
    @State private var drag: CGSize = .zero
    @State private var dragging = false
    @State private var mood: PulsMascot.Mood = .normal
    @State private var hop: CGFloat = 0
    @State private var squash: CGFloat = 1
    @State private var wiggle: Double = 0
    @State private var burst = 0
    @State private var taps = 0
    @State private var lastDragSound = Date.distantPast
    @State private var lastDragPoint = CGSize.zero
    @State private var calm: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var position: CGPoint { CGPoint(x: prefs.mascotX + drag.width, y: prefs.mascotY + drag.height) }

    var body: some View {
        PulsMascot(anchor: IslandController.shared.mascotAnchor(open: true, dx: position.x, dy: position.y),
                   mood: dragging ? .lifted : (voice.talking ? .happy : mood))
            .scaleEffect(x: 1 + (1 - squash) * 0.5, y: squash, anchor: .bottom)
            .rotationEffect(.degrees(wiggle), anchor: .bottom)
            .overlay(alignment: .top) { HeartBurst(trigger: burst).allowsHitTesting(false) }
            .overlay(alignment: .bottomTrailing) {
                if wake.running {
                    Image(systemName: "ear")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(IslandColor.accentText)
                        .padding(3)
                        .background(Circle().fill(IslandColor.card))
                        .accessibilityLabel("Pulsi hört auf «Hey Pulsi» (Beta)")
                }
            }
            .contentShape(Rectangle())
            .position(x: container.width / 2 + model.openWidth / 2 + position.x - PulsMascot.size.width / 2,
                      y: model.openHeight - PulsMascot.size.height / 2 + position.y + hop)
            .onTapGesture { react() }
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        if !dragging {
                            PulsiSounds.shared.play(.drag)
                            lastDragSound = .now
                            lastDragPoint = .zero
                        }
                        dragging = true
                        drag = value.translation
                        let moved = hypot(value.translation.width - lastDragPoint.width, value.translation.height - lastDragPoint.height)
                        if Date.now.timeIntervalSince(lastDragSound) > 0.22, moved > 10 {
                            PulsiSounds.shared.play(.drag)
                            lastDragSound = .now
                            lastDragPoint = value.translation
                        }
                    }
                    .onEnded { value in
                        prefs.mascotX = clampX(prefs.mascotX + value.translation.width)
                        prefs.mascotY = clampY(prefs.mascotY + value.translation.height)
                        drag = .zero
                        dragging = false
                        land()
                    }
            )
            .contextMenu {
                Button("Position zurücksetzen", systemImage: "arrow.uturn.backward") { prefs.mascotX = -24; prefs.mascotY = 30 }
                Button(prefs.mascotSpeaks ? "Pulsi verstummen" : "Pulsi sprechen lassen", systemImage: prefs.mascotSpeaks ? "speaker.slash" : "speaker.wave.2") {
                    prefs.mascotSpeaks.toggle()
                    if !prefs.mascotSpeaks { PulsiVoice.shared.stop() }
                }
                Button("Pulsi-Einstellungen…", systemImage: "gearshape") { AppActions.openSettings(.pulsi) }
                Button("Maskottchen entfernen", systemImage: "eye.slash") { prefs.mascot = false }
            }
            .help("Pulsi: anklicken oder ziehen")
    }

    /// Pulsi stays on the island and inside the window.
    private func clampX(_ x: Double) -> Double { min(8, max(-(model.openWidth - PulsMascot.size.width), x)) }
    private func clampY(_ y: Double) -> Double { min(36, max(-(model.openHeight - PulsMascot.size.height), y)) }

    // MARK: Play

    /// Three little reactions in turn, so it never does the same thing twice in a row.
    private func react() {
        taps += 1
        burst += 1
        mood = .happy
        PulsiSounds.shared.play(.tap)
        haptic(.alignment)
        if !reduceMotion {
            switch taps % 3 {
            case 0: pop()
            case 1: jump()
            default: shake()
            }
        }
        calm?.cancel()
        calm = Task {
            try? await Task.sleep(for: .milliseconds(1100))
            if !Task.isCancelled { mood = .normal }
        }
    }

    private func jump() {
        withAnimation(.easeOut(duration: 0.16)) { hop = -16; squash = 1.12 }
        Task {
            try? await Task.sleep(for: .milliseconds(160))
            withAnimation(.interpolatingSpring(stiffness: 260, damping: 9)) { hop = 0; squash = 1 }
        }
    }

    private func shake() {
        Task {
            for angle in [-14.0, 12, -8, 5, 0] {
                withAnimation(.easeInOut(duration: 0.09)) { wiggle = angle }
                try? await Task.sleep(for: .milliseconds(90))
            }
        }
    }

    private func pop() {
        withAnimation(.easeIn(duration: 0.1)) { squash = 0.7 }
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 7)) { squash = 1 }
        }
    }

    /// After a drag: a squash on landing.
    private func land() {
        PulsiSounds.shared.play(.land)
        haptic(.levelChange)
        guard !reduceMotion else { return }
        withAnimation(.easeIn(duration: 0.08)) { squash = 0.8 }
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.interpolatingSpring(stiffness: 260, damping: 8)) { squash = 1 }
        }
    }

    private func haptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}

/// Hearts and sparkles that fly up from Pulsi and fade.
private struct HeartBurst: View {
    var trigger: Int
    @State private var progress: CGFloat = 1

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let angle = -Double.pi + (Double(i) + 0.5) / 6 * Double.pi
                Image(systemName: i % 2 == 0 ? "heart.fill" : "sparkle")
                    .font(.system(size: i % 2 == 0 ? 10 : 9))
                    .foregroundStyle(i % 2 == 0 ? Color(hex: Brand.puls) : Color(hex: Brand.offWhite))
                    .offset(x: cos(angle) * 34 * progress, y: sin(angle) * 38 * progress - 4)
                    .opacity(1 - progress)
            }
        }
        .onChange(of: trigger) {
            progress = 0
            withAnimation(.easeOut(duration: 0.85)) { progress = 1 }
        }
    }
}
