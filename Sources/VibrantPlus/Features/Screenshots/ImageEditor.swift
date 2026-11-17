// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import CoreText
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import VibrantPlusKit

/// Creates a new raster image: redacted source pixels are absent from the exported PNG.
nonisolated enum ImageEditEngine {
    static func render(_ url: URL, plan: ImageEditPlan) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let original = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw CocoaError(.fileReadCorruptFile) }
        let crop = plan.crop
        let rect = CGRect(x: crop.x * Double(original.width), y: crop.y * Double(original.height),
                          width: crop.width * Double(original.width), height: crop.height * Double(original.height)).integral
        guard rect.width >= 1, rect.height >= 1, let image = original.cropping(to: rect) else { throw CocoaError(.validationMissingMandatoryProperty) }
        let padding = max(0, min(256, plan.padding))
        let width = image.width + padding * 2, height = image.height + padding * 2
        guard width <= 16_384 && height <= 16_384,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CocoaError(.fileReadTooLarge) }
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: padding, y: padding, width: image.width, height: image.height))
        context.saveGState()
        context.clip(to: CGRect(x: padding, y: padding, width: image.width, height: image.height))
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        for redaction in plan.redactions {
            let relative = CGRect(x: redaction.x * Double(original.width) - rect.minX + Double(padding),
                                  y: Double(padding + image.height) - (redaction.y * Double(original.height) - rect.minY) - redaction.height * Double(original.height),
                                  width: redaction.width * Double(original.width), height: redaction.height * Double(original.height)).integral
            context.fill(relative)
        }
        context.restoreGState()
        if !plan.watermark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let font = CTFontCreateWithName("Helvetica" as CFString, CGFloat(max(12, min(64, image.width / 32))), nil)
            let attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1)]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: String(plan.watermark.prefix(200)), attributes: attributes))
            let bounds = CTLineGetBoundsWithOptions(line, [])
            let inset = CGFloat(max(8, padding))
            context.setFillColor(CGColor(gray: 0, alpha: 0.72))
            context.fill(CGRect(x: inset, y: inset, width: min(CGFloat(width) - inset * 2, bounds.width + 16), height: bounds.height + 16))
            context.textPosition = CGPoint(x: inset + 8, y: inset + 8 - bounds.minY)
            CTLineDraw(line, context)
        }
        guard let result = context.makeImage() else { throw CocoaError(.fileWriteUnknown) }
        return result
    }
    static func save(_ image: CGImage, to url: URL) throws {
        guard let writer = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(writer, image, nil)
        guard CGImageDestinationFinalize(writer) else { throw CocoaError(.fileWriteUnknown) }
    }
}

struct ImageEditorView: View {
    @State private var source: URL?
    @State private var original: NSImage?
    @State private var preview: NSImage?
    @State private var plan = ImageEditPlan()
    @State private var mode = "redact"
    @State private var message: String?
    @State private var rendering = false
    @State private var lastPlan: ImageEditPlan?
    var body: some View {
        VStack(spacing: Space.md) {
            HStack {
                Button("Bild öffnen…") { choose() }
                Picker("Ziehen", selection: $mode) { Text("Schwärzen").tag("redact"); Text("Zuschneiden").tag("crop") }
                    .pickerStyle(.segmented)
                Button("Rückgängig") { if let lastPlan { plan = lastPlan; self.lastPlan = nil; preview = nil } }.disabled(lastPlan == nil)
                Button("Vorschau") { render() }.disabled(source == nil || rendering)
                Button("PNG sichern…") { save() }.disabled(source == nil || rendering)
            }
            HStack {
                TextField("Wasserzeichen", text: $plan.watermark)
                Stepper("Rand \(plan.padding) px", value: $plan.padding, in: 0...256, step: 8)
            }
            if let original {
                GeometryReader { geometry in
                    Image(nsImage: preview ?? original).resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay {
                            if preview == nil {
                                let size = Self.fit(original.size, into: geometry.size)
                                ZStack {
                                    ForEach(Array(plan.redactions.enumerated()), id: \.offset) { _, rect in
                                        Rectangle().fill(.black)
                                            .frame(width: rect.width * size.width, height: rect.height * size.height)
                                            .position(x: (rect.x + rect.width / 2) * size.width, y: (rect.y + rect.height / 2) * size.height) // grid: ok image coordinates
                                    }
                                }
                                .frame(width: size.width, height: size.height)
                                .contentShape(Rectangle())
                                .gesture(DragGesture(minimumDistance: 2).onEnded { drag in
                                    let x = min(drag.startLocation.x, drag.location.x) / size.width
                                    let y = min(drag.startLocation.y, drag.location.y) / size.height
                                    let rect = UnitRectangle(x: x, y: y, width: abs(drag.translation.width) / size.width, height: abs(drag.translation.height) / size.height)
                                    guard rect.width > 0 && rect.height > 0 else { return }
                                    lastPlan = plan
                                    if mode == "redact" { plan.redactions.append(rect) } else { plan.crop = rect; render() }
                                })
                            }
                        }
                }
                if preview != nil { Button("Original weiter bearbeiten") { preview = nil } }
            } else {
                ContentUnavailableView("Bild bearbeiten", systemImage: "photo", description: Text("Öffne ein Bild. Ziehen schwärzt einen Bereich oder schneidet ihn zu. Gesichert wird eine neue PNG-Datei."))
            }
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
            Text("Schwärzen exportiert schwarze Pixel. Das Original bleibt bestehen. Prüfe die Vorschau vor dem Teilen.").font(.caption).foregroundStyle(.secondary)
        }.padding(Space.margin).frame(width: 760, height: 600)
    }
    private static func fit(_ size: CGSize, into bounds: CGSize) -> CGSize {
        let scale = min(bounds.width / max(1, size.width), bounds.height / max(1, size.height))
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
    private func choose() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }
        source = url; original = image; preview = nil; plan = ImageEditPlan(); lastPlan = nil; message = nil
    }
    private func render() {
        guard let source else { return }; rendering = true
        let current = plan
        Task {
            do {
                let image = try await Task.detached(priority: .userInitiated) { try ImageEditEngine.render(source, plan: current) }.value
                preview = NSImage(cgImage: image, size: .zero)
                message = nil
            } catch { message = error.localizedDescription }
            rendering = false
        }
    }
    private func save() {
        guard let source else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = source.deletingPathExtension().lastPathComponent + "_Vibrant.png"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do { try ImageEditEngine.save(ImageEditEngine.render(source, plan: plan), to: destination); message = "PNG gesichert." }
        catch { message = error.localizedDescription }
    }
}
