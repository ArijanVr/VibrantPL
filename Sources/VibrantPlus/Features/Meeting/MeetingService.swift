// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import AVFoundation
import CoreMedia
import ScreenCaptureKit
import VibrantPlusKit

/// Writes a meeting down: the microphone is «Ich», the sound the Mac plays (Teams, Zoom, FaceTime …) is «Andere».
/// Speech to text runs on the Mac. At the end the transcript becomes a Markdown file and, if wanted, an Apple Notes note.
@Observable
final class MeetingService {
    static let shared = MeetingService()

    /// Apps that usually mean a call; the tile offers to write it down while one of them runs.
    static let meetingApps = ["com.microsoft.teams2", "com.microsoft.teams", "us.zoom.xos", "com.cisco.webexmeetingsapp", "com.apple.FaceTime"]

    private(set) var isRunning = false
    private(set) var starting = false
    @ObservationIgnored private var stopping = false
    private(set) var lines: [TranscriptLine] = []
    private(set) var live = ""
    private(set) var started: Date?
    private(set) var savedFile: URL?
    var message: String?

    @ObservationIgnored private var mic: SpeechChannel?
    @ObservationIgnored private var system: SpeechChannel?
    @ObservationIgnored private var tap: MicrophoneTap?
    @ObservationIgnored private var stream: SCStream?
    @ObservationIgnored private var audioSink: SystemAudioSink?
    @ObservationIgnored private var readers: [Task<Void, Never>] = []

    /// The name of a running call app, if any.
    var runningMeetingApp: String? {
        NSWorkspace.shared.runningApplications.first { Self.meetingApps.contains($0.bundleIdentifier ?? "") }?.localizedName
    }

    func toggle() {
        Task { isRunning ? await stop() : await start() }
    }

    func start() async {
        guard !isRunning, !starting, !stopping else { return }
        starting = true
        defer { starting = false }
        message = nil
        guard await MicrophoneTap.requestAccess() else {
            message = "Mikrofon erlauben: Systemeinstellungen › Datenschutz › Mikrofon."
            return
        }
        do {
            let mic = try await SpeechChannel.open()
            self.mic = mic
            let tap = MicrophoneTap()
            try tap.start(into: mic)
            self.tap = tap
            started = .now
            lines = []
            live = ""
            savedFile = nil
            readers.append(read(mic, speaker: "Ich"))
            await startSystemAudio()
            isRunning = true
        } catch {
            message = "Aufnahme nicht möglich: \(error.localizedDescription)"
            await teardown()
        }
    }

    /// The other side of a call comes out of the speakers: record it with ScreenCaptureKit (audio only).
    private func startSystemAudio() async {
        guard ScreenCapture.allowed else {
            message = "Nur dein Mikrofon: Für den Ton der anderen fehlt «Bildschirmaufnahme» in den Systemeinstellungen."
            return
        }
        do {
            let system = try await SpeechChannel.open()
            self.system = system
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { return }
            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = true
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            let sink = SystemAudioSink(channel: system)
            let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []), configuration: config, delegate: nil)
            try stream.addStreamOutput(sink, type: .audio, sampleHandlerQueue: DispatchQueue(label: "ch.arjo.vibrantplus.meeting-audio"))
            try await stream.startCapture()
            self.stream = stream
            audioSink = sink
            readers.append(read(system, speaker: "Andere"))
        } catch {
            message = "Nur dein Mikrofon: Der Ton der anderen liess sich nicht aufnehmen."
            await system?.finish()
            system = nil
        }
    }

    private func read(_ channel: SpeechChannel, speaker: String) -> Task<Void, Never> {
        Task {
            // The recognizer's running text only grows; a pause of 1.5 s closes a line.
            var consumed = ""
            var quiet: Task<Void, Never>?
            for await piece in channel.results {
                let fresh = SpokenText.fresh(piece.text, after: consumed)
                guard !fresh.isEmpty else {
                    if piece.isFinal { consumed = "" }
                    continue
                }
                live = "\(speaker): \(fresh)"
                quiet?.cancel()
                let whole = piece.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if piece.isFinal {
                    commit(fresh, speaker: speaker)
                    consumed = ""
                } else {
                    quiet = Task {
                        try? await Task.sleep(for: .milliseconds(1500))
                        guard !Task.isCancelled else { return }
                        consumed = whole
                        commit(fresh, speaker: speaker)
                    }
                }
            }
            quiet?.cancel()
        }
    }

    private func commit(_ text: String, speaker: String) {
        guard let started else { return }
        lines.append(TranscriptLine(offset: Date.now.timeIntervalSince(started), speaker: speaker, text: text))
        live = ""
    }

    func stop() async {
        guard isRunning else { return }
        stopping = true
        defer { stopping = false }
        isRunning = false
        await teardown()
        guard let started, !lines.isEmpty else {
            message = "Nichts gehört, nichts gesichert."
            return
        }
        lines.sort { $0.offset < $1.offset }
        save(start: started)
    }

    private func teardown() async {
        tap?.stop()
        tap = nil
        try? await stream?.stopCapture()
        stream = nil
        audioSink = nil
        await mic?.finish()
        await system?.finish()
        for r in readers { await r.value }
        readers = []
        mic = nil
        system = nil
    }

    private func save(start: Date) {
        let title = "Besprechung"
        let markdown = MeetingNote.markdown(title: title, start: start, lines: lines)
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Vibrant+ Besprechungen")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = CapturePlan.freeURL(in: folder, name: MeetingNote.fileName(start: start))
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            savedFile = url
            message = "Gesichert in Dokumente › Vibrant+ Besprechungen."
        } catch {
            message = "Das Gespräch liess sich nicht sichern."
            return
        }
        if Prefs.shared.meetingToNotes { addNote(title: title, start: start) }
    }

    /// An Apple Notes note: the title, then one paragraph per line. Needs the Automation permission for Notes.
    private func addNote(title: String, start: Date) {
        func html(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        let heading = "\(title) \(f.string(from: start))"
        let body = "<h1>\(html(heading))</h1>" + lines.map { "<p><b>\(html($0.speaker)):</b> \(html($0.text))</p>" }.joined()
        func quoted(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\"" }
        do {
            try Script.run("tell application \"Notes\" to make new note with properties {body:\(quoted(body))}", timeout: 20)
            message = "Gesichert als Notiz und Datei."
        } catch Script.Failure.notAllowed {
            message = "Datei gesichert. Für die Notiz: Systemeinstellungen › Datenschutz › Automation › Notizen erlauben."
        } catch {
            message = "Datei gesichert, die Notiz liess sich nicht anlegen."
        }
    }
}

/// Receives the Mac's audio from ScreenCaptureKit and hands it to a speech channel.
nonisolated final class SystemAudioSink: NSObject, SCStreamOutput, @unchecked Sendable {
    private let channel: SpeechChannel

    init(channel: SpeechChannel) { self.channel = channel }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid, let buffer = Self.pcm(sampleBuffer) else { return }
        channel.feed(buffer)
    }

    private static func pcm(_ sb: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let description = sb.formatDescription, var asbd = description.audioStreamBasicDescription,
              let format = AVAudioFormat(streamDescription: &asbd) else { return nil }
        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sb))
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(sb, at: 0, frameCount: Int32(frames), into: buffer.mutableAudioBufferList)
        return status == noErr ? buffer : nil
    }
}
