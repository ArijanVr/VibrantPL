// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import Speech

/// One audio source turned into text with the on-device SpeechAnalyzer (macOS 26).
/// Feed it buffers from any thread; read `results` for volatile and final text.
nonisolated final class SpeechChannel: @unchecked Sendable {
    struct Piece: Sendable {
        var text: String
        var isFinal: Bool
    }

    let results: AsyncStream<Piece>
    private let analyzer: SpeechAnalyzer
    private let format: AVAudioFormat
    private let input: AsyncStream<AnalyzerInput>.Continuation
    private let pieces: AsyncStream<Piece>.Continuation
    private var converter: AVAudioConverter?
    private var reader: Task<Void, Never>?

    enum Failure: Error { case languageUnsupported, noFormat }

    /// Downloads the language model on first use.
    static func open(locale: Locale = .current) async throws -> SpeechChannel {
        var found = await SpeechTranscriber.supportedLocale(equivalentTo: locale)
        if found == nil { found = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "de-DE")) }
        guard let supported = found else { throw Failure.languageUnsupported }
        let transcriber = SpeechTranscriber(locale: supported, transcriptionOptions: [], reportingOptions: [.volatileResults, .fastResults], attributeOptions: [])
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else { throw Failure.noFormat }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let (inputStream, input) = AsyncStream<AnalyzerInput>.makeStream()
        try await analyzer.start(inputSequence: inputStream)
        return SpeechChannel(analyzer: analyzer, transcriber: transcriber, format: format, input: input)
    }

    private init(analyzer: SpeechAnalyzer, transcriber: SpeechTranscriber, format: AVAudioFormat, input: AsyncStream<AnalyzerInput>.Continuation) {
        self.analyzer = analyzer
        self.format = format
        self.input = input
        (results, pieces) = AsyncStream<Piece>.makeStream()
        let out = pieces
        reader = Task {
            do {
                for try await r in transcriber.results { out.yield(Piece(text: String(r.text.characters), isFinal: r.isFinal)) }
            } catch {}
            out.finish()
        }
    }

    /// Converts to the analyzer's format and hands the audio over.
    func feed(_ buffer: AVAudioPCMBuffer) {
        guard let converted = convert(buffer) else { return }
        input.yield(AnalyzerInput(buffer: converted))
    }

    /// Ends the input, lets the analyzer finish what it heard, and closes `results`.
    func finish() async {
        input.finish()
        try? await analyzer.finalizeAndFinishThroughEndOfInput()
        await reader?.value
    }

    private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if buffer.format == format { return buffer }
        if converter?.inputFormat != buffer.format { converter = AVAudioConverter(from: buffer.format, to: format) }
        guard let converter else { return nil }
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var delivered = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if delivered { status.pointee = .noDataNow; return nil }
            delivered = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil ? out : nil
    }
}

/// The Mac's microphone into a `SpeechChannel`. Survives a changed input (AirPods, another default device).
nonisolated final class MicrophoneTap: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var observer: NSObjectProtocol?
    private var channel: SpeechChannel?
    private var gate: @Sendable () -> Bool = { true }

    /// `gate` is asked per buffer; return false to drop the audio (for example while Vibrant+ speaks itself).
    func start(into channel: SpeechChannel, gate: @escaping @Sendable () -> Bool = { true }) throws {
        self.channel = channel
        self.gate = gate
        try install()
        observer = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
            // The engine stopped because the input changed: tap the new format and go on.
            self?.engine.inputNode.removeTap(onBus: 0)
            try? self?.install()
        }
    }

    private func install() throws {
        guard let channel else { return }
        let gate = self.gate
        let node = engine.inputNode
        node.installTap(onBus: 0, bufferSize: 4096, format: node.outputFormat(forBus: 0)) { buffer, _ in
            if gate() { channel.feed(buffer) }
        }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        channel = nil
    }

    static func requestAccess() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
}
