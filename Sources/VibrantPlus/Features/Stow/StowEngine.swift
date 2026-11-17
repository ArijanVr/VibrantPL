// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import VibrantPlusKit

/// File conversions on this Mac. The result always lands next to the
/// original with a new name; nothing is ever overwritten.
nonisolated enum StowEngine {
    enum Kind { case image, video, audio, pdf, other }

    enum Failure: LocalizedError {
        case unreadable, unsupported, exportFailed(String)
        var errorDescription: String? {
            switch self {
            case .unreadable: "Die Datei lässt sich nicht lesen."
            case .unsupported: "Diese Umwandlung ist für diese Datei nicht möglich."
            case .exportFailed(let s): "Umwandlung fehlgeschlagen: \(s)"
            }
        }
    }

    enum ImageFormat: String, CaseIterable, Identifiable, Sendable {
        case jpeg = "JPEG", png = "PNG", heic = "HEIC", tiff = "TIFF", webp = "WebP"
        var id: String { rawValue }
        var type: UTType {
            switch self {
            case .jpeg: .jpeg
            case .png: .png
            case .heic: .heic
            case .tiff: .tiff
            case .webp: .webP
            }
        }
        var ext: String { self == .jpeg ? "jpg" : (type.preferredFilenameExtension ?? rawValue.lowercased()) }

        /// WebP writing depends on the macOS version; offer only what ImageIO can write.
        static var writable: [ImageFormat] {
            let ids = (CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? []
            return allCases.filter { ids.contains($0.type.identifier) }
        }
    }

    enum Preset: String, CaseIterable, Identifiable, Sendable {
        case web, send, print
        var id: String { rawValue }
        var title: String {
            switch self {
            case .web: "Für das Web"
            case .send: "Zum Senden"
            case .print: "Zum Drucken"
            }
        }
        var subtitle: String {
            switch self {
            case .web: "JPEG, 2000 px"
            case .send: "Klein, 1600 px"
            case .print: "PDF"
            }
        }
        var symbol: String {
            switch self {
            case .web: "globe"
            case .send: "paperplane"
            case .print: "printer"
            }
        }
    }

    enum Ratio: String, CaseIterable, Identifiable, Sendable {
        case square = "1:1", portrait = "4:5", wide = "16:9", tall = "9:16"
        var id: String { rawValue }
        var value: CGFloat {
            switch self {
            case .square: 1
            case .portrait: 4.0 / 5.0
            case .wide: 16.0 / 9.0
            case .tall: 9.0 / 16.0
            }
        }
    }

    static func kind(of url: URL) -> Kind {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return .other }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .audio) { return .audio }
        return .other
    }

    static func output(for source: URL, tag: String, ext: String) -> URL {
        OutputNaming.url(for: source, tag: tag, ext: ext) { FileManager.default.fileExists(atPath: $0.path) }
    }

    // MARK: Images

    /// Decodes an image, applying its orientation, at most `maxPixel` on the long side.
    static func cgImage(_ url: URL, maxPixel: Int? = nil) throws -> (CGImage, [String: Any]) {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw Failure.unreadable }
        let props = (CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any]) ?? [:]
        let w = props[kCGImagePropertyPixelWidth as String] as? Int ?? 0
        let h = props[kCGImagePropertyPixelHeight as String] as? Int ?? 0
        let longSide = max(w, h)
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maxPixel ?? longSide, max(longSide, 1)),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { throw Failure.unreadable }
        return (image, props)
    }

    /// Metadata to keep: EXIF/IPTC without GPS. Orientation is already applied.
    static func keptMetadata(_ props: [String: Any]) -> [String: Any] {
        var p = props
        for key in [kCGImagePropertyGPSDictionary, kCGImagePropertyOrientation, kCGImagePropertyPixelWidth,
                    kCGImagePropertyPixelHeight] { p.removeValue(forKey: key as String) }
        if var tiff = p[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            tiff.removeValue(forKey: kCGImagePropertyTIFFOrientation as String)
            p[kCGImagePropertyTIFFDictionary as String] = tiff
        }
        return p
    }

    static func write(_ image: CGImage, to url: URL, format: ImageFormat, quality: Double, metadata: [String: Any]?) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, format.type.identifier as CFString, 1, nil) else {
            throw Failure.unsupported
        }
        var props = metadata ?? [:]
        props[kCGImageDestinationLossyCompressionQuality as String] = quality
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw Failure.exportFailed(format.rawValue) }
    }

    static func convertImage(_ url: URL, to format: ImageFormat, maxPixel: Int? = nil, quality: Double = 0.85,
                             tag: String? = nil, stripMetadata: Bool = false) throws -> URL {
        let (image, props) = try cgImage(url, maxPixel: maxPixel)
        let out = output(for: url, tag: tag ?? format.rawValue, ext: format.ext)
        try write(image, to: out, format: format, quality: quality, metadata: stripMetadata ? nil : keptMetadata(props))
        return out
    }

    /// Center crop to an aspect ratio, same format as the source when possible.
    static func crop(_ url: URL, to ratio: Ratio) throws -> URL {
        let (image, props) = try cgImage(url)
        let w = CGFloat(image.width), h = CGFloat(image.height)
        var rect = CGRect(x: 0, y: 0, width: w, height: h)
        if w / h > ratio.value { rect.size.width = (h * ratio.value).rounded(); rect.origin.x = ((w - rect.width) / 2).rounded() }
        else { rect.size.height = (w / ratio.value).rounded(); rect.origin.y = ((h - rect.height) / 2).rounded() }
        guard let cropped = image.cropping(to: rect) else { throw Failure.unsupported }
        let format = sameFormat(url)
        let out = output(for: url, tag: ratio.rawValue.replacingOccurrences(of: ":", with: "x"), ext: format.ext)
        try write(cropped, to: out, format: format, quality: 0.9, metadata: keptMetadata(props))
        return out
    }

    /// Re-encodes without any metadata (EXIF, GPS, camera, IPTC).
    static func stripMetadata(_ url: URL) throws -> URL {
        let format = sameFormat(url)
        return try convertImage(url, to: format, quality: 0.92, tag: "ohne Metadaten", stripMetadata: true)
    }

    /// JPEG under `megabytes`: lowers quality, then size, until it fits.
    static func shrink(_ url: URL, underMB megabytes: Double) throws -> URL {
        let limit = Int(megabytes * 1_000_000)
        var (image, props) = try cgImage(url)
        let out = output(for: url, tag: "unter \(megabytes.formatted()) MB", ext: "jpg")
        for _ in 0..<8 {
            for q in [0.85, 0.7, 0.55, 0.4] {
                let data = NSMutableData()
                guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { throw Failure.unsupported }
                var p = keptMetadata(props)
                p[kCGImageDestinationLossyCompressionQuality as String] = q
                CGImageDestinationAddImage(dest, image, p as CFDictionary)
                CGImageDestinationFinalize(dest)
                if data.length <= limit {
                    try (data as Data).write(to: out)
                    return out
                }
            }
            // Still too big: 80 % of the size, try again.
            (image, props) = try cgImage(url, maxPixel: Int(Double(max(image.width, image.height)) * 0.8))
        }
        throw Failure.exportFailed("zu gross")
    }

    static func sameFormat(_ url: URL) -> ImageFormat {
        switch url.pathExtension.lowercased() {
        case "png": .png
        case "heic", "heif": .heic
        case "tif", "tiff": .tiff
        case "webp" where ImageFormat.writable.contains(.webp): .webp
        default: .jpeg
        }
    }

    // MARK: PDF

    /// Images and PDFs into one PDF, in the given order.
    static func makePDF(_ urls: [URL]) throws -> URL {
        let doc = PDFDocument()
        for url in urls {
            if kind(of: url) == .pdf, let other = PDFDocument(url: url) {
                for i in 0..<other.pageCount { if let p = other.page(at: i) { doc.insert(p, at: doc.pageCount) } }
            } else {
                let (image, _) = try cgImage(url)
                let ns = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                guard let page = PDFPage(image: ns) else { throw Failure.unsupported }
                doc.insert(page, at: doc.pageCount)
            }
        }
        guard doc.pageCount > 0, let first = urls.first else { throw Failure.unreadable }
        let out = output(for: first, tag: urls.count > 1 ? "\(urls.count) Dateien" : "PDF", ext: "pdf")
        guard doc.write(to: out) else { throw Failure.exportFailed("PDF") }
        return out
    }

    /// One PDF per page, next to the original.
    static func splitPDF(_ url: URL) throws -> [URL] {
        guard let doc = PDFDocument(url: url), doc.pageCount > 0 else { throw Failure.unreadable }
        var outs: [URL] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let single = PDFDocument()
            guard let copy = page.copy() as? PDFPage else { continue }
            single.insert(copy, at: 0)
            let out = output(for: url, tag: "Seite \(i + 1)", ext: "pdf")
            guard single.write(to: out) else { throw Failure.exportFailed("PDF") }
            outs.append(out)
        }
        return outs
    }

    // MARK: Video and audio

    enum MediaTarget: String, CaseIterable, Identifiable, Sendable {
        case mp4 = "MP4", mov = "MOV", m4a = "M4A", gif = "GIF", web = "Web (1080p)", send = "Senden (720p)"
        var id: String { rawValue }
    }

    static func export(_ url: URL, to target: MediaTarget, start: Double? = nil, end: Double? = nil) async throws -> URL {
        if target == .gif { return try await exportGIF(url, start: start, end: end) }
        let asset = AVURLAsset(url: url)
        let (preset, fileType, ext, tag): (String, AVFileType, String, String) = switch target {
        case .mp4: (AVAssetExportPresetHighestQuality, .mp4, "mp4", "MP4")
        case .mov: (AVAssetExportPresetHighestQuality, .mov, "mov", "MOV")
        case .m4a: (AVAssetExportPresetAppleM4A, .m4a, "m4a", "Audio")
        case .gif: (AVAssetExportPresetHighestQuality, .mp4, "gif", "GIF")
        case .web: (AVAssetExportPreset1920x1080, .mp4, "mp4", "Web")
        case .send: (AVAssetExportPreset1280x720, .mp4, "mp4", "Senden")
        }
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else { throw Failure.unsupported }
        if start != nil || end != nil {
            let duration = try await asset.load(.duration).seconds
            let s = max(0, start ?? 0), e = min(duration, end ?? duration)
            guard e > s else { throw Failure.exportFailed("Ende vor Anfang") }
            session.timeRange = CMTimeRange(start: CMTime(seconds: s, preferredTimescale: 600),
                                            end: CMTime(seconds: e, preferredTimescale: 600))
        }
        let out = output(for: url, tag: start != nil || end != nil ? "gekürzt" : tag, ext: ext)
        do {
            try await session.export(to: out, as: fileType)
        } catch {
            throw Failure.exportFailed(error.localizedDescription)
        }
        return out
    }

    /// Frames via AVAssetImageGenerator, written with ImageIO. Long films are capped.
    @concurrent
    static func exportGIF(_ url: URL, start: Double? = nil, end: Double? = nil) async throws -> URL {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw Failure.unsupported }
        let duration = try await asset.load(.duration).seconds
        let times = GIFPlan.frameTimes(duration: duration, start: start, end: end)
        guard !times.isEmpty else { throw Failure.exportFailed("Kein Bild für das GIF") }
        let (natural, transform) = try await track.load(.naturalSize, .preferredTransform)
        let shown = natural.applying(transform)
        let scaled = GIFPlan.scaledSize(width: Int(abs(shown.width).rounded()), height: Int(abs(shown.height).rounded()))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: scaled.width, height: scaled.height)
        var frames: [CGImage] = []
        frames.reserveCapacity(times.count)
        for t in times {
            try Task.checkCancellation()
            let image = try await generator.image(at: CMTime(seconds: t, preferredTimescale: 600)).image
            frames.append(image)
        }
        let out = output(for: url, tag: "GIF", ext: "gif")
        guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
            throw Failure.exportFailed("GIF")
        }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: GIFPlan.delay]] as CFDictionary
        for frame in frames { CGImageDestinationAddImage(dest, frame, frameProps) }
        guard CGImageDestinationFinalize(dest) else { throw Failure.exportFailed("GIF schreiben") }
        return out
    }

    // MARK: Upscaling

    /// Lanczos resampling followed by a gentle sharpening: the classic high-quality way to enlarge,
    /// on the Mac, free, with no network. It does not invent detail the way AI upscalers do.
    nonisolated static func enlarge(_ image: CIImage, scale: Double) -> CIImage {
        let lanczos = CIFilter(name: "CILanczosScaleTransform")!
        lanczos.setValue(image, forKey: kCIInputImageKey)
        lanczos.setValue(scale, forKey: kCIInputScaleKey)
        lanczos.setValue(1.0, forKey: kCIInputAspectRatioKey)
        var out = lanczos.outputImage ?? image
        let sharpen = CIFilter(name: "CISharpenLuminance")!
        sharpen.setValue(out, forKey: kCIInputImageKey)
        sharpen.setValue(0.45, forKey: kCIInputSharpnessKey)
        sharpen.setValue(1.2, forKey: "inputRadius")
        out = sharpen.outputImage ?? out
        return out
    }

    /// Enlarges a picture by 2× or 4× (less when it would pass 12 000 px). Same format as the original.
    static func upscaleImage(_ url: URL, factor: Int) throws -> URL {
        let (image, props) = try cgImage(url)
        let plan = UpscalePlan.imageSize(width: image.width, height: image.height, factor: factor)
        guard plan.factor > 1.01 else { throw Failure.exportFailed("Das Bild ist schon sehr gross") }
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let big = enlarge(CIImage(cgImage: image), scale: plan.factor)
        let target = CGRect(x: 0, y: 0, width: plan.width, height: plan.height)
        guard let rendered = context.createCGImage(big, from: target.intersection(big.extent)) else { throw Failure.exportFailed("Skalieren") }
        let format = sameFormat(url)
        let out = output(for: url, tag: "\(factor)x", ext: format.ext)
        try write(rendered, to: out, format: format, quality: 0.92, metadata: keptMetadata(props))
        return out
    }

    /// Enlarges a video 2× (at most to 4K), frame by frame; the sound is carried over.
    static func upscaleVideo(_ url: URL) async throws -> URL {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw Failure.unreadable }
        let (natural, transform) = try await track.load(.naturalSize, .preferredTransform)
        let shown = natural.applying(transform)
        let w = Int(abs(shown.width).rounded()), h = Int(abs(shown.height).rounded())
        guard let plan = UpscalePlan.videoSize(width: w, height: h) else { throw Failure.exportFailed("Das Video ist schon in 4K oder grösser") }
        let size = CGSize(width: plan.width, height: plan.height)
        let scale = plan.factor
        let filtered = try await AVVideoComposition.videoComposition(with: asset, applyingCIFiltersWithHandler: { request in
            let big = enlarge(request.sourceImage.clampedToExtent(), scale: scale)
            request.finish(with: big.cropped(to: CGRect(origin: .zero, size: size)), context: nil)
        })
        var config = AVVideoComposition.Configuration()
        config.renderSize = size
        config.frameDuration = filtered.frameDuration
        config.instructions = filtered.instructions
        config.customVideoCompositorClass = filtered.customVideoCompositorClass
        let composition = AVVideoComposition(configuration: config)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { throw Failure.unsupported }
        session.videoComposition = composition
        let out = output(for: url, tag: "hochskaliert", ext: "mp4")
        do { try await session.export(to: out, as: .mp4) } catch { throw Failure.exportFailed(error.localizedDescription) }
        return out
    }

    /// Joins several videos, in the given order, into one film (MP4, H.264/AAC).
    /// Different sizes and orientations are fitted into the first clip's frame
    /// (black bars where needed); clips without sound get silence.
    static func joinVideos(_ urls: [URL]) async throws -> URL {
        guard urls.count >= 2, let first = urls.first else { throw Failure.unsupported }
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw Failure.unsupported }

        struct Segment { var range: CMTimeRange; var transform: CGAffineTransform; var natural: CGSize }
        var segments: [Segment] = []
        var cursor = CMTime.zero
        var renderSize = CGSize.zero
        var frameRate: Float = 30

        for url in urls {
            let asset = AVURLAsset(url: url)
            guard let v = try await asset.loadTracks(withMediaType: .video).first else {
                throw Failure.exportFailed("\(url.lastPathComponent) enthält kein Video")
            }
            let duration = try await asset.load(.duration)
            let (natural, transform, fps) = try await v.load(.naturalSize, .preferredTransform, .nominalFrameRate)
            let range = CMTimeRange(start: .zero, duration: duration)
            try videoTrack.insertTimeRange(range, of: v, at: cursor)
            if let a = try await asset.loadTracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(range, of: a, at: cursor)
            }
            let shown = natural.applying(transform)
            if url == first {
                renderSize = CGSize(width: abs(shown.width).rounded(), height: abs(shown.height).rounded())
                if fps > 0 { frameRate = fps }
            }
            segments.append(Segment(range: CMTimeRange(start: cursor, duration: duration), transform: transform, natural: natural))
            cursor = cursor + duration
        }
        // An empty audio track makes the export stop: drop it when no clip has sound.
        if audioTrack.segments.isEmpty { composition.removeTrack(audioTrack) }
        // Encoders want even sizes.
        renderSize = CGSize(width: max(2, (renderSize.width / 2).rounded() * 2), height: max(2, (renderSize.height / 2).rounded() * 2))

        var config = AVVideoComposition.Configuration()
        config.renderSize = renderSize
        config.frameDuration = CMTime(value: 1, timescale: CMTimeScale(max(1, frameRate.rounded())))
        config.instructions = segments.map { seg in
            var layerConfig = AVVideoCompositionLayerInstruction.Configuration(assetTrack: videoTrack)
            layerConfig.setTransform(fitTransform(natural: seg.natural, preferred: seg.transform, into: renderSize), at: seg.range.start)
            var instructionConfig = AVVideoCompositionInstruction.Configuration()
            instructionConfig.timeRange = seg.range
            instructionConfig.layerInstructions = [AVVideoCompositionLayerInstruction(configuration: layerConfig)]
            return AVVideoCompositionInstruction(configuration: instructionConfig)
        }
        let videoComposition = AVVideoComposition(configuration: config)

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw Failure.unsupported
        }
        session.videoComposition = videoComposition
        let out = output(for: first, tag: "Film aus \(urls.count) Clips", ext: "mp4")
        do {
            try await session.export(to: out, as: .mp4)
        } catch {
            throw Failure.exportFailed(error.localizedDescription)
        }
        return out
    }

    /// Rotates a clip upright, then scales and centers it inside the render size.
    nonisolated static func fitTransform(natural: CGSize, preferred: CGAffineTransform, into size: CGSize) -> CGAffineTransform {
        let rect = CGRect(origin: .zero, size: natural).applying(preferred)
        // Move the rotated clip back to the origin.
        let upright = preferred.concatenating(CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
        let scale = min(size.width / rect.width, size.height / rect.height)
        let w = rect.width * scale, h = rect.height * scale
        return upright
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: (size.width - w) / 2, y: (size.height - h) / 2))
    }

    static func duration(of url: URL) async -> Double {
        (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0
    }
}

import AppKit
