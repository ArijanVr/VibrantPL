// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ScreenCaptureKit
import VibrantPlusKit

/// Records the display under the pointer to a .mov in Downloads (ScreenCaptureKit, macOS's own recorder output).
/// Same permission as screenshots: Screen Recording.
@Observable
final class ScreenRecorder: NSObject {
    static let shared = ScreenRecorder()

    private(set) var isRecording = false
    private(set) var started: Date?
    private(set) var lastURL: URL?
    private(set) var exportingGIF = false
    @ObservationIgnored private var starting = false
    @ObservationIgnored private var stream: SCStream?
    /// The file of each running or finishing recording; the finish callback arrives after stop().
    @ObservationIgnored private var files: [ObjectIdentifier: URL] = [:]

    func toggle() {
        Task { isRecording ? await stop() : await start() }
    }

    func start() async {
        guard !isRecording, !starting else { return }
        starting = true
        defer { starting = false }
        guard ScreenCapture.allowed else {
            ScreenCapture.requestAccess()
            IslandModel.shared.show(Toast(symbol: "lock.shield", text: "Bildschirmaufnahme fehlt. Erlaube sie in den Einstellungen.", warm: true), seconds: 8)
            Permission.screenRecording.openSettings()
            return
        }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let mouse = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
            let number = (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            guard let display = content.displays.first(where: { $0.displayID == number }) ?? content.displays.first else { throw Failure.noDisplay }
            // Vibrant+'s own windows (the island) stay out of the film.
            let own = content.windows.filter { $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier }
            let filter = SCContentFilter(display: display, excludingWindows: own)
            let scale = screen?.backingScaleFactor ?? 2
            let config = SCStreamConfiguration()
            if Prefs.shared.recordZoomCursor, let frame = screen?.frame {
                let zoom = ZoomPlan.sourceRect(display: frame, mouse: mouse)
                config.sourceRect = zoom
                config.width = max(2, Int(zoom.width * scale) / 2 * 2)
                config.height = max(2, Int(zoom.height * scale) / 2 * 2)
            } else {
                config.width = Int(CGFloat(display.width) * scale)
                config.height = Int(CGFloat(display.height) * scale)
            }
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            config.showsCursor = true

            let file = CapturePlan.freeURL(in: ScreenCapture.folder, name: CapturePlan.recordingName(at: .now))
            let out = SCRecordingOutputConfiguration()
            out.outputURL = file
            out.outputFileType = .mov
            out.videoCodecType = .hevc
            let recording = SCRecordingOutput(configuration: out, delegate: self)
            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream.addRecordingOutput(recording)
            try await stream.startCapture()
            self.stream = stream
            files[ObjectIdentifier(recording)] = file
            started = .now
            isRecording = true
            IslandModel.shared.show(Toast(symbol: "record.circle", text: "Aufnahme läuft", warm: true))
        } catch {
            IslandModel.shared.show(Toast(symbol: "exclamationmark.triangle", text: "Aufnahme liess sich nicht starten", warm: true))
        }
    }

    func stop() async {
        guard let stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
        isRecording = false
        started = nil
    }

    func exportLastGIF() async {
        guard let url = lastURL, !exportingGIF else { return }
        exportingGIF = true
        defer { exportingGIF = false }
        do {
            let gif = try await StowEngine.export(url, to: .gif)
            IslandModel.shared.show(Toast(symbol: "checkmark.circle", text: "GIF in Downloads gesichert"))
            NSWorkspace.shared.activateFileViewerSelecting([gif])
        } catch {
            IslandModel.shared.show(Toast(symbol: "exclamationmark.triangle", text: "GIF liess sich nicht erzeugen", warm: true))
        }
    }

    private enum Failure: Error { case noDisplay }
}

extension ScreenRecorder: SCStreamDelegate, SCRecordingOutputDelegate {
    /// The file is complete only now, so it is shown here and not right after stopCapture.
    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        let id = ObjectIdentifier(recordingOutput)
        Task { @MainActor in
            guard let url = self.files.removeValue(forKey: id) else { return }
            self.lastURL = url
            IslandModel.shared.show(Toast(symbol: "checkmark.circle", text: "Aufnahme in Downloads gesichert"))
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        let id = ObjectIdentifier(recordingOutput)
        Task { @MainActor in
            self.files[id] = nil
            IslandModel.shared.show(Toast(symbol: "exclamationmark.triangle", text: "Aufnahme fehlgeschlagen", warm: true))
        }
    }

    /// macOS ended the stream (display gone, permission withdrawn): the state must follow.
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            self.stream = nil
            self.isRecording = false
            self.started = nil
        }
    }
}
