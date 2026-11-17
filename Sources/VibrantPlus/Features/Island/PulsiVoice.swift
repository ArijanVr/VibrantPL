// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Observation

/// Pulsi speaks with the Mac's system voice (Spoken Content / Siri) via SystemSpeechBridge.
@Observable
final class PulsiVoice {
    static let shared = PulsiVoice()
    private(set) var talking = false
    @ObservationIgnored private lazy var speaker: SystemSpeechBridge = {
        let s = SystemSpeechBridge()
        s.onFinished = { Task { @MainActor in PulsiVoice.shared.finished() } }
        return s
    }()

    var enabled: Bool { Prefs.shared.mascot && Prefs.shared.mascotSpeaks }

    func say(_ text: String) {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard enabled, !line.isEmpty, !NSWorkspace.shared.isVoiceOverEnabled else { return }
        let rate = Float(120 + (Prefs.shared.speechRate - 0.35) / 0.25 * 120)
        talking = true
        speaker.speak(line, rate: rate)
    }

    func stop() {
        speaker.stop()
        talking = false
    }

    /// System sounds (Tink, Pop, Purr…). `force` is for the settings preview.
    func play(_ name: String, force: Bool = false) {
        guard force || (Prefs.shared.mascot && Prefs.shared.mascotPlaySounds) else { return }
        let sound = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sound.isEmpty else { return }
        NSSound(named: NSSound.Name(sound))?.play()
    }

    fileprivate func finished() { talking = false }
}
