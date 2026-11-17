// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import CoreGraphics
import Observation
import ScreenCaptureKit
import VibrantPlusKit

@Observable
final class ScrollingCapture {
    static let shared = ScrollingCapture()
    private(set) var running = false
    private(set) var message: String?

    func capture() async {
        guard !running, !ScreenCapture.shared.running else { message = "Eine Aufnahme läuft bereits."; return }
        guard ScreenCapture.allowed else {
            ScreenCapture.requestAccess(); Permission.screenRecording.openSettings()
            message = "Bildschirmaufnahme erlauben."; return
        }
        guard Permission.accessibilityTrusted else {
            message = "Bedienungshilfen erlauben, damit das Fenster geblättert werden kann."; return
        }
        running = true; message = nil
        defer { running = false }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            let front = NSWorkspace.shared.frontmostApplication
            guard let front, front.bundleIdentifier != Bundle.main.bundleIdentifier else {
                message = "Wechsle in das Fenster, das aufgenommen werden soll."; return
            }
            let matches = content.windows.filter { $0.owningApplication?.processID == front.processIdentifier && $0.frame.width > 80 && $0.frame.height > 80 }
            guard let window = matches.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }) else {
                message = "Kein sichtbares Fenster der vorderen App gefunden."; return
            }
            front.activate()
            var frames: [CGImage] = []
            var lastHash: UInt64?
            for step in 0..<8 {
                let config = SCStreamConfiguration()
                config.width = max(2, Int(window.frame.width))
                config.height = max(2, Int(window.frame.height))
                config.showsCursor = false
                let image = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config)
                let hash = Self.fingerprint(image)
                if ScrollCapture.shouldStop(previous: lastHash, current: hash, frames: frames.count + 1) {
                    if lastHash != hash { frames.append(image) }
                    break
                }
                frames.append(image)
                lastHash = hash
                if step < 7 {
                    InputTools.postKey(121)
                    try await Task.sleep(for: .milliseconds(400))
                }
            }
            guard let stitched = Self.stitch(frames) else { message = "Die Streifen konnten nicht zusammengefügt werden."; return }
            let url = CapturePlan.freeURL(in: ScreenCapture.folder, name: CapturePlan.fileName(at: .now).replacingOccurrences(of: ".png", with: " scroll.png"))
            let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
            guard let dest else { message = "Datei konnte nicht geschrieben werden."; return }
            CGImageDestinationAddImage(dest, stitched, nil)
            guard CGImageDestinationFinalize(dest) else { message = "PNG konnte nicht gespeichert werden."; return }
            ScreenshotShelf.shared.show(url, copied: false)
            message = "\(frames.count) Streifen zusammengefügt."
        } catch {
            message = "Scrollaufnahme nicht möglich: \(error.localizedDescription)"
        }
    }

    static func fingerprint(_ image: CGImage) -> UInt64 {
        guard let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return 0 }
        let length = CFDataGetLength(data)
        var hash: UInt64 = 14695981039346656037
        var i = 0
        while i < length {
            hash ^= UInt64(bytes[i])
            hash &*= 1099511628211
            i += max(1, length / 2048)
        }
        return hash
    }

    static func stitch(_ images: [CGImage]) -> CGImage? {
        guard let first = images.first else { return nil }
        if images.count == 1 { return first }
        var rows: [(image: CGImage, overlap: Int)] = [(first, 0)]
        for index in 1..<images.count {
            let previous = images[index - 1], next = images[index]
            let height = min(80, previous.height, next.height)
            let overlap = ScrollCapture.overlap(rowHashes(previous, last: height), rowHashes(next, first: height))
            rows.append((next, overlap))
        }
        let width = images.map(\.width).min() ?? first.width
        let total = rows.reduce(0) { $0 + $1.image.height - $1.overlap }
        guard total > 0, width > 0, let context = CGContext(data: nil, width: width, height: min(total, 16_000), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        var y = context.height
        for row in rows {
            let h = min(row.image.height - row.overlap, y)
            y -= h
            context.draw(row.image, in: CGRect(x: 0, y: y - row.overlap, width: width, height: row.image.height))
        }
        return context.makeImage()
    }

    private static func rowHashes(_ image: CGImage, first: Int = 0, last: Int = 0) -> [UInt64] {
        let count = first > 0 ? min(first, image.height) : min(last, image.height)
        let start = first > 0 ? 0 : max(0, image.height - count)
        guard let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return [] }
        let stride = max(image.bytesPerRow, image.width * 4)
        return (0..<count).map { row in
            let offset = (start + row) * stride
            var hash: UInt64 = 14695981039346656037
            var x = 0
            while x < image.width * 4 && offset + x < CFDataGetLength(data) {
                hash ^= UInt64(bytes[offset + x])
                hash &*= 1099511628211
                x += 16
            }
            return hash
        }
    }
}
