// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import AVFoundation
import Observation
import os
import Speech
import SwiftUI
import VibrantPlusKit

/// Hold ⌃⌥ to dictate into any text field; hold ⌃⌘ for a voice command.
/// Speech recognition is macOS's own, on the Mac when the language allows it.
/// Audio is never saved.
@Observable
final class VoiceController {
    static let shared = VoiceController()

    enum Mode { case dictate, command, ask, reply }

    private(set) var listening: Mode?
    private(set) var partial = ""
    private(set) var message: String?
    @ObservationIgnored fileprivate var failure: String?

    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "de-CH"))

    func start() {
        guard monitor == nil else { return }
        // flagsChanged in other apps needs Accessibility (Input Monitoring).
        guard Permission.accessibilityTrusted else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] e in
            let flags = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
            MainActor.assumeIsolated { self?.flagsChanged(flags) }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        finish(insert: false)
    }

    private func flagsChanged(_ flags: NSEvent.ModifierFlags) {
        let relevant = flags.intersection([.control, .option, .command, .shift])
        if listening == nil {
            if !relevant.isEmpty { handsFree = false }
            if relevant == [.control, .option] { begin(.dictate) }
            else if relevant == [.control, .command] { begin(.command) }
            else if relevant == [.control, .shift], Prefs.shared.isOn(.assistant) { begin(.ask) }
        } else if !relevant.contains(.control) {
            finish(insert: true)
        }
    }

    /// Hands-free listening (microphone button, conversation mode): ends by itself after a short
    /// pause in speech, or when the button is tapped again.
    private(set) var handsFree = false
    @ObservationIgnored private var lastHeard = Date.distantPast
    @ObservationIgnored private var startedAt = Date.distantPast
    @ObservationIgnored private var silenceTimer: Timer?

    /// Microphone button in the island: tap to talk, tap again to stop.
    func toggleTalk() {
        if listening != nil { finish(insert: true); return }
        Assistant.shared.stopSpeaking()
        IslandModel.shared.sticky = true
        listen(handsFree: true)
    }

    /// Listens once and hands the words to `handler` (used to answer Claude by voice). Nothing is typed or sent elsewhere.
    @ObservationIgnored private var replyHandler: ((String) -> Void)?
    func listenForReply(_ handler: @escaping (String) -> Void) {
        guard listening == nil else { return }
        replyHandler = handler
        IslandModel.shared.sticky = true
        handsFree = true
        begin(.reply)
    }

    func listen(handsFree: Bool) {
        self.handsFree = handsFree
        begin(.ask)
    }

    private func begin(_ mode: Mode) {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            AudioCallbacks.requestSpeech { status in
                guard status == .authorized else { return }
                Task { @MainActor in VoiceController.shared.begin(mode) }
            }
            return
        case .authorized: break
        default:
            show("Erlaube die Spracherkennung in den Systemeinstellungen.")
            return
        }
        guard let recognizer, recognizer.isAvailable else { show("Spracherkennung ist gerade nicht verfügbar."); return }
        AudioCallbacks.requestMicrophone { granted in
            Task { @MainActor in
                guard granted else { VoiceController.shared.show("Erlaube das Mikrofon in den Systemeinstellungen."); return }
                VoiceController.shared.record(mode)
            }
        }
    }

    private func record(_ mode: Mode) {
        guard listening == nil, let recognizer else { return }
        PulsiWake.shared.pause()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        req.addsPunctuation = true
        request = req
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        AudioCallbacks.feed(input, format: format, into: req)
        audioLevel.reset()
        failure = nil
        Log.voice.notice("record: format=\(format.description, privacy: .public) onDevice=\(recognizer.supportsOnDeviceRecognition)")
        engine.prepare()
        do { try engine.start() } catch { PulsiWake.shared.resume(); show("Das Mikrofon lässt sich nicht starten."); return }
        listening = mode
        partial = ""
        startedAt = .now
        lastHeard = .now
        if handsFree {
            silenceTimer?.invalidate()
            silenceTimer = Timer.repeating(every: 0.25) { _ in
                MainActor.assumeIsolated { VoiceController.shared.checkSilence() }
            }
        }
        IslandModel.shared.show(Toast(symbol: "waveform", text: mode == .dictate ? "Ich höre zu…" : (mode == .ask ? "Frag mich…" : "Befehl…")), seconds: 30)
        task = AudioCallbacks.recognize(recognizer, req, { text in
            Task { @MainActor in
                if let text, text != VoiceController.shared.partial {
                    VoiceController.shared.partial = text
                    VoiceController.shared.lastHeard = .now
                }
            }
        }, failed: { reason in
            Task { @MainActor in
                guard VoiceController.shared.partial.isEmpty else { return }
                let off = reason.localizedCaseInsensitiveContains("disabled")
                VoiceController.shared.failure = off
                    ? "Diktierfunktion ist aus: Systemeinstellungen › Tastatur › Diktieren einschalten."
                    : "Spracherkennung meldet: \(reason)"
            }
        })
    }

    /// Hands-free: 1.3 s without new words ends the turn; 7 s of nothing at the start gives up.
    private func checkSilence() {
        guard listening != nil, handsFree else { silenceTimer?.invalidate(); silenceTimer = nil; return }
        let quiet = Date.now.timeIntervalSince(lastHeard)
        if !partial.isEmpty, quiet > 1.3 { finish(insert: true) }
        else if partial.isEmpty, Date.now.timeIntervalSince(startedAt) > 7 {
            Assistant.shared.endConversation()
            finish(insert: false)
        }
    }

    private func finish(insert: Bool) {
        guard let mode = listening else { return }
        listening = nil
        Log.voice.notice("finish: \(audioLevel.summary, privacy: .public) partial=\(self.partial.count) chars")
        silenceTimer?.invalidate()
        silenceTimer = nil
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        // Give the recognizer a moment for the last words.
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            let text = partial.trimmingCharacters(in: .whitespacesAndNewlines)
            task?.cancel()
            task = nil
            request = nil
            IslandModel.shared.toast = nil
            let failure = self.failure
            self.failure = nil
            PulsiWake.shared.resume()
            guard insert, !text.isEmpty else {
                if let failure { show(failure) }
                else if insert { show("Ich habe nichts gehört.") }
                return
            }
            switch mode {
            case .dictate:
                let clean = Prefs.shared.assistantCleansDictation && Prefs.shared.isOn(.assistant)
                    ? await Assistant.cleanDictation(text) : DictationCleaner.clean(text)
                Self.type(clean)
            case .command: perform(text)
            case .ask: askAssistant(text)
            case .reply:
                let handler = replyHandler
                replyHandler = nil
                handler?(text)
            }
        }
    }

    private func perform(_ text: String) {
        guard let cmd = VoiceCommand.parse(text) else {
            // Not a fixed command: the on-device model may understand it.
            if Prefs.shared.isOn(.assistant), Assistant.isAvailable { askAssistant(text) }
            else { show("Nicht verstanden: «\(text)»") }
            return
        }
        switch cmd {
        case .openApp(let name):
            if let url = Self.findApp(named: name) {
                NSWorkspace.shared.openApplication(at: url, configuration: .init())
                show("Öffne \(url.deletingPathExtension().lastPathComponent)")
            } else {
                show("Keine App «\(name)» gefunden")
            }
        case .searchYouTube, .searchWeb:
            if let url = cmd.url { NSWorkspace.shared.open(url) }
        case .addTask(let t):
            TodayStore.shared.addTask(t)
            show("Zur Liste: \(t)")
        case .startFocus:
            TodayStore.shared.startFocus()
            show("Fokus gestartet")
        case .darkMode(let on):
            SystemControls.shared.setDarkMode(on)
        }
    }

    private func askAssistant(_ text: String) {
        // "Danke", "Stopp", "Tschüss" end a spoken conversation.
        if Assistant.isGoodbye(text) {
            Assistant.shared.endConversation(sayGoodbye: true)
            return
        }
        let conversation = Prefs.shared.conversationMode
        if conversation { Assistant.shared.beginConversation() }
        Assistant.shared.ask(text, speak: conversation || Prefs.shared.assistantSpeaks)
        withAnimation(Motion.respecting(Motion.island)) { IslandController.shared.open(sticky: true) }
    }

    private func show(_ text: String) {
        message = text
        IslandModel.shared.show(Toast(symbol: "waveform", text: text))
    }

    static func findApp(named name: String) -> URL? {
        let wanted = name.lowercased()
        let apps = AppGridController.installedApps()
        return apps.first { $0.name.lowercased() == wanted }?.url ?? apps.first { $0.name.lowercased().hasPrefix(wanted) }?.url
    }

    /// Inserts text into the focused field: puts it on the pasteboard, presses ⌘V,
    /// then restores what was there before. Needs Accessibility.
    static func type(_ text: String) {
        guard Permission.accessibilityTrusted else { Permission.requestAccessibility(); return }
        let pb = NSPasteboard.general
        let saved = pb.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let copy = NSPasteboardItem()
            for t in item.types { if let d = item.data(forType: t) { copy.setData(d, forType: t) } }
            return copy
        } ?? []
        pb.clearContents()
        pb.setString(text, forType: .string)
        // Marked transient so clipboard managers skip it.
        pb.setData(Data(), forType: .init("org.nspasteboard.TransientType"))
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            pb.clearContents()
            if !saved.isEmpty { pb.writeObjects(saved) }
        }
    }
}

/// System callbacks that arrive on TCC, audio or recognizer threads. They are built outside any actor,
/// so Swift 6 does not assert main-actor isolation on those threads (which crashed the app on the
/// microphone permission prompt and on the first audio buffer).
nonisolated let audioLevel = AudioLevel()
nonisolated final class AudioLevel: @unchecked Sendable {
    private let lock = NSLock()
    private var buffers = 0, peak: Float = 0, last: Float = 0
    func reset() { lock.lock(); buffers = 0; peak = 0; last = 0; lock.unlock() }
    func record(peak p: Float) {
        lock.lock(); buffers += 1; peak = max(peak, p); last = p; lock.unlock()
    }
    /// How loud the newest piece of sound was (0 … 1), for the level beside the notch.
    var latest: Float { lock.lock(); defer { lock.unlock() }; return last }
    var summary: String { lock.lock(); defer { lock.unlock() }; return "buffers=\(buffers) peak=\(peak)" }
}

nonisolated enum Log { static let voice = Logger(subsystem: "ch.arjo.vibrantplus", category: "voice") }

enum AudioCallbacks {
    nonisolated static func requestSpeech(_ done: @escaping @Sendable (SFSpeechRecognizerAuthorizationStatus) -> Void) {
        SFSpeechRecognizer.requestAuthorization { done($0) }
    }

    nonisolated static func requestMicrophone(_ done: @escaping @Sendable (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { done($0) }
    }

    nonisolated static func feed(_ input: AVAudioInputNode, format: AVAudioFormat, into req: SFSpeechAudioBufferRecognitionRequest) {
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            var p: Float = 0
            if let ch = buffer.floatChannelData?[0] { for i in 0..<Int(buffer.frameLength) { p = max(p, abs(ch[i])) } }
            audioLevel.record(peak: p)
            req.append(buffer)
        }
    }

    nonisolated static func recognize(_ recognizer: SFSpeechRecognizer, _ req: SFSpeechAudioBufferRecognitionRequest,
                                      _ partial: @escaping @Sendable (String?) -> Void,
                                      failed: @escaping @Sendable (String) -> Void) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: req) { result, error in
            if let error {
                Log.voice.error("recognizer error: \(error.localizedDescription, privacy: .public)")
                failed(error.localizedDescription)
            }
            partial(result?.bestTranscription.formattedString)
        }
    }
}
