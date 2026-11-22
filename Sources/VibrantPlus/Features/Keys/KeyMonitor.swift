// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import AVFoundation
import Observation
import SwiftUI

/// Key sounds and the on-screen key display. One global key monitor for both.
/// Keys are never logged or saved.
@Observable
final class KeyMonitor {
    static let shared = KeyMonitor()

    private(set) var shown: String?
    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private var overlay: NSPanel?
    @ObservationIgnored private var hideTask: Task<Void, Never>?
    @ObservationIgnored private let sounds = KeySoundPlayer()

    /// Starts or stops depending on the settings.
    func update() {
        let p = Prefs.shared
        let need = p.isOn(.keys) && (p.keySounds || p.showKeys) || p.isOn(.island) && p.islandGlow && p.shortcutEcho
        if need && monitor == nil {
            // A global monitor made before the permission exists never gets keys: wait for the grant.
            guard Permission.accessibilityTrusted else { return }
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] e in
                let isDown = e.type == .keyDown, repeatKey = e.isARepeat
                let flags = e.modifierFlags, code = e.keyCode, chars = e.charactersIgnoringModifiers ?? ""
                MainActor.assumeIsolated { self?.key(down: isDown, repeatKey: repeatKey, code: code, flags: flags, chars: chars) }
            }
        } else if !need {
            stop()
        }
        if p.isOn(.keys), p.keySounds { sounds.prepare(profile: p.keySoundProfile) }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        overlay?.orderOut(nil)
        overlay = nil
        sounds.shutdown()
    }

    private func key(down: Bool, repeatKey: Bool, code: UInt16, flags: NSEvent.ModifierFlags, chars: String) {
        let p = Prefs.shared
        if down, !repeatKey, p.shortcutEcho, flags.intersection([.command, .control, .option, .shift]) == .command,
           ["c", "v", "x", "z"].contains(chars.lowercased()) { GlowCenter.shared.fire() }
        if p.isOn(.keys), p.keySounds, !repeatKey { sounds.play(down: down, keyCode: code, volume: Float(p.keySoundVolume)) }
        guard down, p.isOn(.keys), p.showKeys else { return }
        let mods = flags.intersection([.command, .control, .option])
        // By default only shortcuts are shown, never typed text.
        guard p.showAllKeys || !mods.isEmpty else { return }
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        s += Shortcut.keyName(UInt32(code))
        _ = chars
        show(s)
    }

    private func show(_ text: String) {
        shown = text
        if overlay == nil {
            let p = IslandPanel(contentRect: CGRect(x: 0, y: 0, width: 360, height: 72), styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            p.isOpaque = false
            p.backgroundColor = .clear
            p.level = .statusBar
            p.ignoresMouseEvents = true
            p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            p.contentView = DialController.host(KeyOverlay())
            overlay = p
        }
        if let screen = NSScreen.withMouse, let overlay {
            overlay.setFrameOrigin(CGPoint(x: screen.frame.midX - 180, y: screen.visibleFrame.minY + 80))
            overlay.orderFrontRegardless()
        }
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.respecting(Motion.fade)) { self.shown = nil }
        }
    }
}

struct KeyOverlay: View {
    private var monitor = KeyMonitor.shared

    var body: some View {
        ZStack {
            if let s = monitor.shown {
                Text(s)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(IslandColor.primaryText)
                    .padding(.horizontal, Space.xl).padding(.vertical, Space.sm)
                    .background(IslandColor.background.opacity(0.85), in: Capsule())
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, IslandColor.scheme)
    }
}

/// Key clicks synthesized at start (no recorded samples): a short noise burst
/// through a resonant filter, shaped per profile. Played with low latency.
nonisolated final class KeySoundPlayer: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var downBuffers: [AVAudioPCMBuffer] = []
    private var upBuffer: AVAudioPCMBuffer?
    private var recorded = false
    private var next = 0
    private var profile: KeySoundProfile?
    private let lock = NSLock()

    func prepare(profile: KeySoundProfile) {
        lock.lock(); defer { lock.unlock() }
        guard self.profile != profile || !engine.isRunning else { return }
        self.profile = profile
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        if players.isEmpty {
            for _ in 0..<6 {
                let p = AVAudioPlayerNode()
                engine.attach(p)
                engine.connect(p, to: engine.mainMixerNode, format: format)
                players.append(p)
            }
        }
        if let prefix = profile.recordingPrefix, let recorded = Self.recordedBuffers(format: format, prefix: prefix) {
            // Real recordings hold press and release in one file: play it on key down, nothing on key up.
            downBuffers = recorded
            upBuffer = nil
            self.recorded = true
        } else {
            self.recorded = false
            let synth = profile.recordingPrefix != nil ? KeySoundProfile.click : profile
            downBuffers = (0...Self.heavyVariant).map { Self.click(profile: synth, format: format, variant: $0, release: false) }
            upBuffer = Self.click(profile: synth, format: format, variant: 0, release: true)
        }
        if !engine.isRunning { try? engine.start() }
        for p in players where !p.isPlaying { p.play() }
    }

    func play(down: Bool, keyCode: UInt16, volume: Float) {
        lock.lock(); defer { lock.unlock() }
        guard engine.isRunning, !players.isEmpty else { return }
        let buffer: AVAudioPCMBuffer?
        if !down { buffer = upBuffer }
        else if recorded { buffer = downBuffers[Int(keyCode) % downBuffers.count] }
        else { buffer = downBuffers[Self.isHeavy(keyCode) ? Self.heavyVariant : Int(keyCode) % Self.heavyVariant] }
        guard let buffer else { return }
        let p = players[next % players.count]
        next += 1
        p.volume = volume * (down ? 1 : 0.5)
        p.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    func shutdown() {
        lock.lock(); defer { lock.unlock() }
        engine.stop()
        profile = nil
    }

    /// The CC0 recordings in the app bundle (Resources/KeySounds), read once; nil if they are missing.
    static func recordedBuffers(format: AVAudioFormat, prefix: String) -> [AVAudioPCMBuffer]? {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: "KeySounds") ?? []).filter { $0.lastPathComponent.hasPrefix(prefix + "-") }.sorted { $0.path < $1.path }
        let buffers = urls.compactMap { url -> AVAudioPCMBuffer? in
            guard let file = try? AVAudioFile(forReading: url), file.processingFormat == format,
                  let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: b)) != nil else { return nil }
            return b
        }
        return buffers.isEmpty ? nil : buffers
    }

    /// Variant 4 is the heavy key (space, return, delete): lower and longer.
    static let heavyVariant = 4
    static func isHeavy(_ keyCode: UInt16) -> Bool { [49, 36, 51, 76, 56, 60].contains(keyCode) }

    /// One key sound, built from scratch: a noise transient (the contact), a few decaying body
    /// resonances (the case) and, for the clicky profiles, a second sharp tick (the click jacket).
    /// Nothing here is sampled, so the sounds belong to Vibrant+ and carry no third-party licence.
    static func click(profile: KeySoundProfile, format: AVAudioFormat, variant: Int, release: Bool) -> AVAudioPCMBuffer {
        struct Voice { var freq: Double; var decay: Double; var amp: Double }
        let heavy = variant == heavyVariant
        let jitter = 1 + Double(variant % 4 - 1) * 0.035
        let pitch = (heavy ? 0.72 : 1) * jitter * (release ? 1.25 : 1)
        // (length, body resonances, noise amount, noise decay, tick at 3 ms, loudness)
        let (length, voices, noise, noiseDecay, tick, gain): (Double, [Voice], Double, Double, Double, Double) = switch profile {
        case .soft: (0.05, [Voice(freq: 420, decay: 90, amp: 0.8), Voice(freq: 900, decay: 140, amp: 0.3)], 0.25, 260, 0, 0.7)
        case .click, .cherry, .kenneyClick, .kenneyTick: (0.04, [Voice(freq: 2600, decay: 220, amp: 0.5), Voice(freq: 1300, decay: 160, amp: 0.4)], 0.5, 300, 0.3, 0.6)
        case .typewriter: (0.09, [Voice(freq: 1400, decay: 70, amp: 0.6), Voice(freq: 640, decay: 55, amp: 0.5), Voice(freq: 3100, decay: 160, amp: 0.25)], 0.55, 140, 0.5, 0.65)
        case .thock: (0.11, [Voice(freq: 190, decay: 38, amp: 1.0), Voice(freq: 330, decay: 55, amp: 0.55), Voice(freq: 780, decay: 110, amp: 0.2)], 0.3, 380, 0, 0.9)
        case .blue: (0.07, [Voice(freq: 2300, decay: 150, amp: 0.45), Voice(freq: 980, decay: 90, amp: 0.45), Voice(freq: 3900, decay: 260, amp: 0.2)], 0.4, 450, 0.9, 0.7)
        case .bubble: (0.08, [Voice(freq: 520, decay: 48, amp: 0.9), Voice(freq: 1040, decay: 70, amp: 0.35)], 0.1, 500, 0, 0.8)
        case .marimba: (0.16, [Voice(freq: 660, decay: 22, amp: 0.9), Voice(freq: 2640, decay: 60, amp: 0.2)], 0.05, 600, 0, 0.85)
        case .crystal: (0.18, [Voice(freq: 3200, decay: 20, amp: 0.55), Voice(freq: 4800, decay: 30, amp: 0.35), Voice(freq: 7100, decay: 45, amp: 0.15)], 0.08, 700, 0.2, 0.6)
        case .raindrop: (0.09, [Voice(freq: 900, decay: 70, amp: 0.8), Voice(freq: 1800, decay: 110, amp: 0.25)], 0.12, 420, 0, 0.8)
        case .stones: (0.06, [Voice(freq: 340, decay: 120, amp: 0.7), Voice(freq: 760, decay: 160, amp: 0.4)], 0.8, 200, 0, 0.8)
        case .bricks: (0.05, [Voice(freq: 1100, decay: 160, amp: 0.5), Voice(freq: 2200, decay: 220, amp: 0.3)], 0.7, 260, 0.7, 0.7)
        case .arcade: (0.07, [Voice(freq: 880, decay: 40, amp: 0.7), Voice(freq: 2640, decay: 50, amp: 0.3), Voice(freq: 4400, decay: 60, amp: 0.18)], 0, 300, 0, 0.55)
        case .marbles: (0.07, [Voice(freq: 2100, decay: 85, amp: 0.55), Voice(freq: 3300, decay: 130, amp: 0.3)], 0.3, 500, 0.6, 0.65)
        case .cockpit: (0.14, [Voice(freq: 1320, decay: 28, amp: 0.6), Voice(freq: 1980, decay: 34, amp: 0.4)], 0.04, 500, 0, 0.6)
        }
        let rate = format.sampleRate
        let len = (release ? length * 0.55 : length) * (heavy ? 1.3 : 1)
        let frames = AVAudioFrameCount(rate * len)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let data = buffer.floatChannelData![0]
        var seed: UInt32 = 0x1234_5678 &+ UInt32(variant) &* 7919
        var lowpass = 0.0
        let tickAt = Int(rate * 0.003)
        for i in 0..<Int(frames) {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let white = Double(Int32(bitPattern: seed)) / Double(Int32.max)
            lowpass += 0.35 * (white - lowpass)   // darker noise: less hiss, more thump
            let t = Double(i) / rate
            var body = 0.0
            for v in voices { body += v.amp * sin(2 * .pi * v.freq * pitch * t) * exp(-t * v.decay) }
            var out = body * (1 - noise) + lowpass * noise * 2 * exp(-t * noiseDecay)
            if tick > 0, !release, i >= tickAt {
                let u = Double(i - tickAt) / rate
                out += tick * sin(2 * .pi * 4200 * pitch * u) * exp(-u * 900)
            }
            let fadeIn = min(1, t / 0.0004)   // 0.4 ms ramp: no pop at the start
            data[i] = Float(out * gain * fadeIn * (release ? 0.45 : 0.8))
        }
        return buffer
    }
}
