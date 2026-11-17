// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Observation
import VibrantPlusKit

/// The files dropped on the Stow zone and what happens to them.
@Observable
final class StowModel {
    static let shared = StowModel()

    private(set) var files: [URL] = []
    private(set) var busy = false
    private(set) var results: [URL] = []
    private(set) var error: String?
    /// ⌥ held: show the tools row.
    var showTools = false

    var isEmpty: Bool { files.isEmpty }
    var kinds: Set<StowEngine.Kind> { Set(files.map(StowEngine.kind(of:))) }
    var allImages: Bool { !files.isEmpty && kinds == [.image] }
    var allMedia: Bool { !files.isEmpty && kinds.isSubset(of: [.video, .audio]) }
    var hasVideo: Bool { kinds.contains(.video) }
    /// Two or more videos and nothing else: they can become one film.
    var canJoinVideos: Bool { files.count >= 2 && kinds == [.video] }

    /// Changes the order of the clips before joining.
    func move(from: Int, to: Int) {
        guard files.indices.contains(from), files.indices.contains(to) else { return }
        files.swapAt(from, to)
    }

    func sortByName() {
        files.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    func joinVideos() {
        let urls = files
        busy = true
        error = nil
        Task {
            do { finish([try await StowEngine.joinVideos(urls)], nil) }
            catch { finish([], error.localizedDescription) }
        }
    }
    var singlePDF: Bool { files.count == 1 && kinds == [.pdf] }
    var imagesOrPDF: Bool { !files.isEmpty && kinds.isSubset(of: [.image, .pdf]) }

    func load(_ urls: [URL]) {
        files = urls.filter { StowEngine.kind(of: $0) != .other }
        results = []
        error = urls.isEmpty || !files.isEmpty ? nil : "Stow kann diese Dateien nicht umwandeln."
        PulsiVoice.shared.say(error ?? PulsiLines.stowOffer(count: files.count))
    }

    func clear() {
        files = []
        results = []
        error = nil
        busy = false
    }

    // MARK: Actions

    func preset(_ p: StowEngine.Preset) {
        switch p {
        case .web: perform { urls in try urls.map { try StowEngine.convertImage($0, to: .jpeg, maxPixel: 2000, quality: 0.8, tag: "Web") } }
        case .send: perform { urls in try urls.map { try StowEngine.convertImage($0, to: .jpeg, maxPixel: 1600, quality: 0.7, tag: "Senden") } }
        case .print: perform { urls in [try StowEngine.makePDF(urls)] }
        }
    }

    func convert(to format: StowEngine.ImageFormat) {
        perform { urls in try urls.map { try StowEngine.convertImage($0, to: format) } }
    }

    func upscaleImages(_ factor: Int) { perform { urls in try urls.map { try StowEngine.upscaleImage($0, factor: factor) } } }

    func upscaleVideos() {
        let urls = files
        busy = true
        error = nil
        Task {
            var outs: [URL] = []
            do {
                for u in urls { outs.append(try await StowEngine.upscaleVideo(u)) }
                finish(outs, nil)
            } catch { finish(outs, error.localizedDescription) }
        }
    }

    func makePDF() { perform { urls in [try StowEngine.makePDF(urls)] } }
    func crop(_ ratio: StowEngine.Ratio) { perform { urls in try urls.map { try StowEngine.crop($0, to: ratio) } } }
    func stripMetadata() { perform { urls in try urls.map(StowEngine.stripMetadata) } }
    func shrink(underMB mb: Double) { perform { urls in try urls.map { try StowEngine.shrink($0, underMB: mb) } } }
    func splitPDF() { perform { urls in try urls.flatMap(StowEngine.splitPDF) } }

    func export(_ target: StowEngine.MediaTarget, start: Double? = nil, end: Double? = nil) {
        let urls = files
        busy = true
        error = nil
        Task {
            var outs: [URL] = []
            do {
                for u in urls { outs.append(try await StowEngine.export(u, to: target, start: start, end: end)) }
                finish(outs, nil)
            } catch {
                finish(outs, error.localizedDescription)
            }
        }
    }

    private func perform(_ work: @escaping @Sendable ([URL]) throws -> [URL]) {
        let urls = files
        busy = true
        error = nil
        Task.detached(priority: .userInitiated) {
            do {
                let outs = try work(urls)
                await self.finish(outs, nil)
            } catch {
                await self.finish([], error.localizedDescription)
            }
        }
    }

    private func finish(_ outs: [URL], _ message: String?) {
        busy = false
        results = outs
        error = message
        PulsiVoice.shared.say(PulsiLines.stowDone(count: outs.count, failed: message != nil))
    }

    func revealResults() {
        guard !results.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(results)
    }
}
