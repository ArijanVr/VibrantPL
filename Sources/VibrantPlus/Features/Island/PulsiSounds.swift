// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import Foundation
import VibrantPlusKit

/// Pulsi's own voice: three short cries synthesized on the Mac. No sampled library, no stock Tink.
nonisolated final class PulsiSounds: @unchecked Sendable {
    static let shared = PulsiSounds()
    private let engine = AVAudioEngine()
    private var player: AVAudioPlayerNode?
    private var buffers: [PulsiCry: AVAudioPCMBuffer] = [:]
    private let lock = NSLock()

    @MainActor
    func prepare() {
        lock.lock(); defer { lock.unlock() }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        if player == nil {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            player = node
        }
        if buffers.isEmpty {
            for cry in PulsiCry.allCases { buffers[cry] = Self.buffer(cry, format: format) }
        }
        if !engine.isRunning { try? engine.start() }
        if let player, !player.isPlaying { player.play() }
    }

    @MainActor
    func play(_ cry: PulsiCry, force: Bool = false) {
        guard force || (Prefs.shared.mascot && Prefs.shared.mascotPlaySounds) else { return }
        prepare()
        lock.lock(); defer { lock.unlock() }
        guard let player, let buffer = buffers[cry] else { return }
        player.volume = 0.55
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    @MainActor
    func shutdown() {
        lock.lock(); defer { lock.unlock() }
        engine.stop()
    }

    static func buffer(_ cry: PulsiCry, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let samples = cry.samples(sampleRate: format.sampleRate)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buf.frameLength = AVAudioFrameCount(samples.count)
        guard let data = buf.floatChannelData?[0] else { return buf }
        samples.withUnsafeBufferPointer { data.update(from: $0.baseAddress!, count: samples.count) }
        return buf
    }
}
