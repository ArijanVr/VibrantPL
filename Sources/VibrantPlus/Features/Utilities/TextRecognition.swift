// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Observation
import UniformTypeIdentifiers
import Vision
import VibrantPlusKit

@Observable
final class TextRecognition {
    static let shared = TextRecognition()
    private(set) var text = ""
    private(set) var codes: [String] = []
    private(set) var working = false
    private(set) var message: String?

    func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        recognize(url)
    }
    func captureArea() {
        Task {
            if case .saved(let url) = await ScreenCapture.shared.capture(.area) { recognize(url) }
        }
    }
    func recognize(_ url: URL) {
        guard !working else { return }
        working = true; message = nil
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) { try Self.read(url) }.value
                text = result.text; codes = result.codes
                if text.isEmpty && codes.isEmpty { message = "Kein lesbarer Text und kein QR-Code gefunden." }
            } catch { message = "Das Bild konnte nicht gelesen werden: \(error.localizedDescription)" }
            working = false
        }
    }
    nonisolated static func read(_ url: URL) throws -> (text: String, codes: [String]) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let barcode = VNDetectBarcodesRequest()
        barcode.symbologies = [.qr]
        let handler = VNImageRequestHandler(url: url, options: [:])
        try handler.perform([request, barcode])
        let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        let codes = (barcode.results ?? []).compactMap(\.payloadStringValue)
        return (text, codes)
    }
}
