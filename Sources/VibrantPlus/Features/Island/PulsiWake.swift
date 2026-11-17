// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import Observation
import Speech
import VibrantPlusKit

/// Listens for «Hey Pulsi» on-device. Audio is never saved. Pauses while the dictation engine runs.
@Observable
final class PulsiWake {
    static let shared = PulsiWake()
    private(set) var running = false
    private(set) var message: String?
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "de-CH"))
    @ObservationIgnored private var paused = false
    @ObservationIgnored private var lastFire = Date.distantPast

    func update() {
        let on = Prefs.shared.onboarded && Prefs.shared.mascot && Prefs.shared.mascotHeyPulsi && Prefs.shared.isOn(.island)
        if on { start() } else { stop() }
    }

    func pause() {
        paused = true
        haltEngine()
        running = false
    }

    func resume() {
        paused = false
        update()
    }

    private func start() {
        guard !running, !paused else { return }
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            AudioCallbacks.requestSpeech { status in
                guard status == .authorized else { return }
                Task { @MainActor in PulsiWake.shared.update() }
            }
            return
        case .authorized: break
        default:
            message = "«Hey Pulsi» braucht die Spracherkennung."
            return
        }
        AudioCallbacks.requestMicrophone { granted in
            Task { @MainActor in
                guard granted else { PulsiWake.shared.message = "«Hey Pulsi» braucht das Mikrofon."; return }
                PulsiWake.shared.record()
            }
        }
    }

    private func record() {
        guard !running, !paused else { return }
        guard let recognizer, recognizer.isAvailable else {
            message = "Spracherkennung ist gerade nicht verfügbar."
            return
        }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.contextualStrings = ["Pulsi", "Hey Pulsi", "Hallo Pulsi", "Hei Pulsi"]
        // On-device is quieter, but a missing model must not silently drop every phrase.
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        AudioCallbacks.feed(input, format: format, into: req)
        engine.prepare()
        do { try engine.start() } catch { message = "Das Mikrofon für «Hey Pulsi» startet nicht."; return }
        running = true
        message = "Hört zu (Beta) — sag «Hey Pulsi»."
        task = recognizer.recognitionTask(with: req) { result, error in
            let text = result?.bestTranscription.formattedString
            let done = result?.isFinal == true || error != nil
            Task { @MainActor in
                if let text, PulsiWakePhrase.heard(text) {
                    PulsiWake.shared.heardWake()
                    return
                }
                if done { PulsiWake.shared.restartAfterFailure() }
            }
        }
    }

    private func heardWake() {
        guard Date.now.timeIntervalSince(lastFire) > 2 else { return }
        lastFire = .now
        pause()
        IslandController.shared.open(sticky: true)
        IslandModel.shared.show(Toast(symbol: "ear", text: "Pulsi hört zu (Beta)"), seconds: 4)
        PulsiSounds.shared.play(.tap)
        PulsiVoice.shared.say("Ja?")
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            VoiceController.shared.listen(handsFree: true)
        }
    }

    private func restartAfterFailure() {
        haltEngine()
        running = false
        guard Prefs.shared.mascotHeyPulsi else { return }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            PulsiWake.shared.update()
        }
    }

    func stop() {
        paused = false
        haltEngine()
        running = false
    }

    private func haltEngine() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }
}
