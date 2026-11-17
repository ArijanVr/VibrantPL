// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import AVFoundation
import CoreVideo
import CoreMedia
import Observation
import ScreenCaptureKit
import SwiftUI
import VibrantPlusKit

struct TrackRecordingSummary: Sendable {
    let url: URL
    let videoFrames: Int
    let systemAudioBuffers: Int
    let microphoneBuffers: Int
    let skippedBuffers: Int
}

enum TrackRecordingFailure: LocalizedError, Sendable {
    case failed(String)
    var errorDescription: String? { switch self { case .failed(let message): message } }
}

/// ScreenCaptureKit's separate output types are written to separate MOV tracks on macOS 26.
/// No macOS-27-only automatic microphone mixing and no private audio driver are required.
@Observable
final class TrackRecorder: NSObject {
    static let shared = TrackRecorder()
    var systemAudio: Bool { didSet { defaults.set(systemAudio, forKey: "capture.tracks.systemAudio") } }
    var microphone: Bool { didSet { defaults.set(microphone, forKey: "capture.tracks.microphone") } }
    var showsCursor: Bool { didSet { defaults.set(showsCursor, forKey: "capture.tracks.cursor") } }
    private(set) var isRecording = false
    private(set) var busy = false
    private(set) var started: Date?
    private(set) var message: String?
    private(set) var last: TrackRecordingSummary?
    @ObservationIgnored private let defaults: UserDefaults = Paths.isOverridden
        ? UserDefaults(suiteName: "ch.arjo.vibrantplus.capture-test." + Paths.dataDirectory.lastPathComponent)!
        : .standard
    @ObservationIgnored private var stream: SCStream?
    @ObservationIgnored private var sink: TrackRecordingSink?
    @ObservationIgnored private var startError: String?
    @ObservationIgnored private var stopRequested = false

    override init() {
        systemAudio = defaults.object(forKey: "capture.tracks.systemAudio") as? Bool ?? true
        microphone = defaults.bool(forKey: "capture.tracks.microphone")
        showsCursor = defaults.object(forKey: "capture.tracks.cursor") as? Bool ?? true
        super.init()
    }

    func start() {
        guard !busy, !isRecording, !ScreenRecorder.shared.isRecording else {
            message = "Eine Aufnahme läuft bereits oder wird vorbereitet."; return
        }
        guard ScreenCapture.allowed else {
            ScreenCapture.requestAccess(); Permission.screenRecording.openSettings()
            message = "Bildschirmaufnahme erlauben und Vibrant+ bei Bedarf neu starten."; return
        }
        busy = true; message = nil; startError = nil; stopRequested = false
        let includeSystem = systemAudio, includeMic = microphone, cursor = showsCursor
        Task {
            if includeMic {
                let status = AVCaptureDevice.authorizationStatus(for: .audio)
                var granted = status == .authorized
                if status == .notDetermined { granted = await AVCaptureDevice.requestAccess(for: .audio) }
                guard granted else { message = "Mikrofonfreigabe fehlt. Deaktiviere die Mikrofonspur oder erlaube sie in den Systemeinstellungen."; busy = false; return }
            }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                let mouse = NSEvent.mouseLocation
                let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
                let displayID = (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
                guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
                    throw TrackRecordingFailure.failed("Kein aufnehmbarer Bildschirm gefunden.")
                }
                let ownWindows = content.windows.filter { $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier }
                let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
                let scale = screen?.backingScaleFactor ?? 1
                let logical = screen?.frame.size ?? CGSize(width: display.width, height: display.height)
                let width = max(2, Int(logical.width * scale) / 2 * 2)
                let height = max(2, Int(logical.height * scale) / 2 * 2)
                let configuration = SCStreamConfiguration()
                configuration.width = width; configuration.height = height
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                configuration.showsCursor = cursor
                configuration.capturesAudio = includeSystem
                configuration.excludesCurrentProcessAudio = true
                configuration.sampleRate = 48_000; configuration.channelCount = 2
                configuration.captureMicrophone = includeMic
                let file = CapturePlan.freeURL(in: ScreenCapture.folder, name: "Mehrspur-" + CapturePlan.recordingName(at: .now))
                let sink = try TrackRecordingSink(url: file, width: width, height: height, systemAudio: includeSystem, microphone: includeMic)
                let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
                try stream.addStreamOutput(sink, type: .screen, sampleHandlerQueue: sink.queue)
                if includeSystem { try stream.addStreamOutput(sink, type: .audio, sampleHandlerQueue: sink.queue) }
                if includeMic { try stream.addStreamOutput(sink, type: .microphone, sampleHandlerQueue: sink.queue) }
                self.sink = sink; self.stream = stream
                try await stream.startCapture()
                if let startError { throw TrackRecordingFailure.failed(startError) }
                if stopRequested { try await stream.stopCapture(); throw TrackRecordingFailure.failed("Aufnahme vor dem Start abgebrochen.") }
                isRecording = true; started = .now; last = nil
                message = "Mehrspur-Aufnahme läuft. Systemton und Mikrofon werden nicht miteinander vermischt."
            } catch {
                self.stream = nil
                if let sink = self.sink { _ = await sink.finish() }
                self.sink = nil
                message = "Aufnahme konnte nicht starten: " + error.localizedDescription
            }
            busy = false
        }
    }

    func stop() {
        if busy { if !isRecording { stopRequested = true }; return }
        guard let stream, let sink else { return }
        busy = true
        self.stream = nil; self.sink = nil; isRecording = false; started = nil
        Task {
            do { try await stream.stopCapture() }
            catch { message = "Der Aufnahme-Stream wurde unterbrochen: " + error.localizedDescription }
            let result = await sink.finish()
            switch result {
            case .success(let summary):
                last = summary
                message = "MOV gesichert: \(summary.videoFrames) Videobilder, \(summary.systemAudioBuffers) Systemton- und \(summary.microphoneBuffers) Mikrofon-Puffer. Übersprungen: \(summary.skippedBuffers)."
            case .failure(let error): message = "Die Aufnahme konnte nicht abgeschlossen werden: " + error.localizedDescription
            }
            busy = false
        }
    }
    func revealLast() { if let last { NSWorkspace.shared.activateFileViewerSelecting([last.url]) } }

    func exportLastGIF() {
        guard let last, !busy else { return }
        busy = true
        message = "GIF wird erzeugt…"
        Task {
            do {
                let gif = try await StowEngine.export(last.url, to: .gif)
                message = "GIF gesichert: \(gif.lastPathComponent)"
                NSWorkspace.shared.activateFileViewerSelecting([gif])
            } catch {
                message = "GIF liess sich nicht erzeugen."
            }
            busy = false
        }
    }
}

extension TrackRecorder: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        let text = error.localizedDescription
        let identity = ObjectIdentifier(stream)
        Task { @MainActor in
            guard let current = self.stream, ObjectIdentifier(current) == identity else { return }
            if !self.isRecording { self.startError = text; return }
            self.message = "Aufnahme-Stream unterbrochen: " + text
            // Finalize available samples rather than leaving an unplayable MOV behind.
            self.busy = false
            self.stop()
        }
    }
}

/// All mutable writer state is confined to `queue`; SCStream callbacks use that same queue.
/// Sendable is required by Dispatch/SCStream, whose callback contracts do not express this confinement.
nonisolated final class TrackRecordingSink: NSObject, SCStreamOutput, @unchecked Sendable {
    let queue = DispatchQueue(label: "ch.arjo.vibrantplus.recording.tracks", qos: .userInitiated)
    private let writer: AVAssetWriter
    private let video: AVAssetWriterInput
    private let systemAudio: AVAssetWriterInput?
    private let microphone: AVAssetWriterInput?
    private let url: URL
    private var sessionStart: CMTime?
    private var videoFrames = 0
    private var systemBuffers = 0
    private var microphoneBuffers = 0
    private var skipped = 0
    private var finishing = false
    private var failure: String?

    init(url: URL, width: Int, height: Int, systemAudio: Bool, microphone: Bool) throws {
        self.url = url
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        video = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height])
        video.expectsMediaDataInRealTime = true
        func audioInput(channels: Int) -> AVAssetWriterInput {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: channels, AVEncoderBitRateKey: channels * 96_000])
            input.expectsMediaDataInRealTime = true
            return input
        }
        self.systemAudio = systemAudio ? audioInput(channels: 2) : nil
        self.microphone = microphone ? audioInput(channels: 1) : nil
        super.init()
        guard writer.canAdd(video) else { throw TrackRecordingFailure.failed("Videoformat wird vom MOV-Writer nicht unterstützt.") }
        writer.add(video)
        for input in [self.systemAudio, self.microphone].compactMap({ $0 }) {
            guard writer.canAdd(input) else { throw TrackRecordingFailure.failed("Eine separate Audiospur konnte nicht angelegt werden.") }
            writer.add(input)
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        append(sampleBuffer, type: type, completeFrameKnown: false)
    }

    private func append(_ sampleBuffer: CMSampleBuffer, type: SCStreamOutputType, completeFrameKnown: Bool) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard !finishing, failure == nil, CMSampleBufferIsValid(sampleBuffer), CMSampleBufferDataIsReady(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard time.isValid && time.isNumeric else { skipped += 1; return }
        if type == .screen {
            if !completeFrameKnown {
                guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                      let status = attachments.first?[.status] as? Int, status == SCFrameStatus.complete.rawValue else { return }
            }
            if sessionStart == nil {
                guard writer.startWriting() else { failure = writer.error?.localizedDescription ?? "Writer konnte nicht starten."; return }
                writer.startSession(atSourceTime: time); sessionStart = time
            }
        }
        guard let start = sessionStart, CMTimeCompare(time, start) >= 0 else { return }
        let input: AVAssetWriterInput?
        switch type {
        case .screen: input = video
        case .audio: input = systemAudio
        case .microphone: input = microphone
        @unknown default: input = nil
        }
        guard let input else { return }
        guard input.isReadyForMoreMediaData else { skipped += 1; return }
        if input.append(sampleBuffer) {
            switch type { case .screen: videoFrames += 1; case .audio: systemBuffers += 1; case .microphone: microphoneBuffers += 1; @unknown default: break }
        } else { failure = writer.error?.localizedDescription ?? "Ein Aufnahme-Puffer konnte nicht geschrieben werden." }
    }

    /// Generated frames and silent PCM only; never captures the user's screen or microphone.
    static func selfTest(url: URL) async -> Result<TrackRecordingSummary, TrackRecordingFailure> {
        guard Paths.isOverridden, url.path.hasPrefix("/tmp/") || url.path.hasPrefix("/private/tmp/") else {
            return .failure(.failed("Mehrspur-Selbsttest braucht einen /tmp-Pfad und APP_DATA."))
        }
        do {
            let sink = try TrackRecordingSink(url: url, width: 64, height: 64, systemAudio: true, microphone: true)
            await withCheckedContinuation { continuation in
                sink.queue.async {
                    for index in 0..<10 {
                        let time = CMTime(value: Int64(index), timescale: 30)
                        if let video = Self.testVideo(time: time) { sink.append(video, type: .screen, completeFrameKnown: true) }
                        if let audio = Self.testAudio(time: time, channels: 2) { sink.append(audio, type: .audio, completeFrameKnown: true) }
                        if let microphone = Self.testAudio(time: time, channels: 1) { sink.append(microphone, type: .microphone, completeFrameKnown: true) }
                    }
                    continuation.resume()
                }
            }
            return await sink.finish()
        } catch { return .failure(.failed(error.localizedDescription)) }
    }

    private static func testVideo(time: CMTime) -> CMSampleBuffer? {
        var pixel: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, 64, 64, kCVPixelFormatType_32BGRA, nil, &pixel) == kCVReturnSuccess,
              let pixel else { return nil }
        CVPixelBufferLockBaseAddress(pixel, [])
        if let base = CVPixelBufferGetBaseAddress(pixel) { memset(base, 0, CVPixelBufferGetDataSize(pixel)) }
        CVPixelBufferUnlockBaseAddress(pixel, [])
        var format: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixel, formatDescriptionOut: &format) == noErr,
              let format else { return nil }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30), presentationTimeStamp: time, decodeTimeStamp: .invalid)
        var buffer: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixel, formatDescription: format,
                                                       sampleTiming: &timing, sampleBufferOut: &buffer) == noErr else { return nil }
        return buffer
    }

    private static func testAudio(time: CMTime, channels: UInt32) -> CMSampleBuffer? {
        var description = AudioStreamBasicDescription(mSampleRate: 48_000, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsFloat | kAudioFormatFlagIsPacked, mBytesPerPacket: channels * 4,
            mFramesPerPacket: 1, mBytesPerFrame: channels * 4, mChannelsPerFrame: channels, mBitsPerChannel: 32, mReserved: 0)
        var format: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &description, layoutSize: 0, layout: nil,
            magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format) == noErr, let format else { return nil }
        var block: CMBlockBuffer?
        let frames = 1_600, byteCount = frames * Int(channels) * 4
        guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: byteCount,
            blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0, dataLength: byteCount,
            flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block) == kCMBlockBufferNoErr, let block else { return nil }
        guard CMBlockBufferFillDataBytes(with: 0, blockBuffer: block, offsetIntoDestination: 0, dataLength: byteCount) == kCMBlockBufferNoErr else { return nil }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 48_000), presentationTimeStamp: time, decodeTimeStamp: .invalid)
        var size = Int(channels) * 4
        var buffer: CMSampleBuffer?
        guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: format, sampleCount: frames,
            sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 1, sampleSizeArray: &size,
            sampleBufferOut: &buffer) == noErr else { return nil }
        return buffer
    }

    func finish() async -> Result<TrackRecordingSummary, TrackRecordingFailure> {
        await withCheckedContinuation { continuation in
            queue.async {
                guard !self.finishing else { continuation.resume(returning: .failure(.failed("Aufnahme wird bereits abgeschlossen."))); return }
                self.finishing = true
                guard self.sessionStart != nil, self.writer.status == .writing, self.failure == nil else {
                    self.writer.cancelWriting()
                    continuation.resume(returning: .failure(.failed(self.failure ?? "Keine vollständigen Videobilder empfangen.")))
                    return
                }
                self.video.markAsFinished(); self.systemAudio?.markAsFinished(); self.microphone?.markAsFinished()
                self.writer.finishWriting { @Sendable in
                    self.queue.async {
                        if self.writer.status == .completed {
                            continuation.resume(returning: .success(TrackRecordingSummary(url: self.url, videoFrames: self.videoFrames, systemAudioBuffers: self.systemBuffers, microphoneBuffers: self.microphoneBuffers, skippedBuffers: self.skipped)))
                        } else { continuation.resume(returning: .failure(.failed(self.writer.error?.localizedDescription ?? "MOV-Abschluss fehlgeschlagen."))) }
                    }
                }
            }
        }
    }
}

struct TrackRecorderSettings: View {
    var enabled = true
    @State private var recorder = TrackRecorder.shared
    var body: some View {
        Section("Mehrspur-Aufnahme") {
            Toggle("Systemton als eigene Audiospur", isOn: $recorder.systemAudio)
            Toggle("Mikrofon als eigene Audiospur", isOn: $recorder.microphone)
            Toggle("Mauszeiger aufnehmen", isOn: $recorder.showsCursor)
            Text("Nimmt den Bildschirm unter dem Mauszeiger mit 30 Bildern pro Sekunde auf. Die MOV-Datei enthält eine Videospur und bis zu zwei getrennte AAC-Audiospuren. Bei Stille kann eine Audiospur ohne Samples bleiben. Kein automatischer Upload.")
                .font(.caption).foregroundStyle(.secondary)
        }.disabled(!enabled || recorder.isRecording || recorder.busy)
        Section {
            if recorder.isRecording {
                Button("Mehrspur-Aufnahme beenden") { recorder.stop() }.disabled(recorder.busy)
            } else {
                Button("Mehrspur-Aufnahme starten") { recorder.start() }.disabled(!enabled || recorder.busy)
            }
            if recorder.busy { ProgressView("Aufnahme vorbereiten oder abschliessen…") }
            if let message = recorder.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            if recorder.last != nil {
                Button("Aufnahme im Finder zeigen") { recorder.revealLast() }
                Button("Aufnahme als GIF sichern") { recorder.exportLastGIF() }.disabled(recorder.busy)
            }
        }
    }
}
