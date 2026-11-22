// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import AVFoundation
import Observation
import SwiftUI
import VibrantPlusKit

// MARK: Weather curve

/// The temperature of the next hours as a small curve under the weather.
struct TemperatureCurve: View {
    var hours: [Double]

    var body: some View {
        let points = Sparkline.normalized(hours)
        GeometryReader { geo in
            let line = path(points, in: geo.size, closed: false)
            ZStack {
                path(points, in: geo.size, closed: true)
                    .fill(LinearGradient(colors: [IslandColor.accent.opacity(0.28), IslandColor.accent.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                line.stroke(IslandColor.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: 16)
        .accessibilityElement()
        .accessibilityLabel("Temperatur der nächsten \(hours.count) Stunden")
        .accessibilityValue("von \(Int((hours.min() ?? 0).rounded())) bis \(Int((hours.max() ?? 0).rounded())) Grad")
    }

    /// The curve leaves 2 pt at the top and bottom, so the stroke is never cut.
    private func path(_ points: [Double], in size: CGSize, closed: Bool) -> Path {
        var p = Path()
        guard points.count > 1 else { return p }
        let step = size.width / CGFloat(points.count - 1)
        func point(_ i: Int) -> CGPoint {
            CGPoint(x: CGFloat(i) * step, y: 2 + (size.height - 4) * (1 - points[i]))
        }
        p.move(to: point(0))
        for i in 1..<points.count { p.addLine(to: point(i)) }
        if closed {
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.addLine(to: CGPoint(x: 0, y: size.height))
            p.closeSubpath()
        }
        return p
    }
}

// MARK: Quick note

/// A thought, typed and gone: Return puts it at the end of the Today note, or it becomes a task.
struct QuickNoteTile: View {
    private var today = TodayStore.shared
    private var prefs = Prefs.shared
    @State private var saved: String?

    /// The draft sits in Prefs, so it survives the island folding away or another card
    /// taking over: nothing half-written is lost.
    private var draft: Binding<String> {
        Binding(get: { prefs.noteDraft }, set: { prefs.noteDraft = $0 })
    }

    private var trimmed: String { prefs.noteDraft.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        IslandCard(width: Metrics.wideTileWidth - 64) {
            VStack(alignment: .leading, spacing: Space.xs) {
                CardHeader(title: "Schnellnotiz", symbol: "square.and.pencil")
                TextField("Gedanke festhalten", text: draft)
                    .textFieldStyle(.plain).font(TypeStyle.islandBody)
                    .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
                    .background(IslandColor.field, in: RoundedRectangle(cornerRadius: Radius.chip))
                    .onSubmit(saveNote)
                    .accessibilityLabel("Schnellnotiz")
                Text(saved ?? "↩ legt es in die Notiz von Heute.")
                    .font(TypeStyle.islandCaption).foregroundStyle(saved == nil ? IslandColor.tertiaryText : IslandColor.accentText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                HStack(spacing: Space.xs) {
                    IslandPillButton(title: "Zur Notiz", kind: .primary, action: saveNote)
                    IslandPillButton(title: "Als Aufgabe", action: saveTask)
                }
                .disabled(trimmed.isEmpty)
            }
        }
    }

    private func saveNote() {
        guard !trimmed.isEmpty else { return }
        today.setNote(QuickNote.append(trimmed, to: today.data.note))
        saved = "In der Notiz: \(trimmed)"
        prefs.noteDraft = ""
    }

    private func saveTask() {
        guard !trimmed.isEmpty else { return }
        today.addTask(trimmed)
        saved = "Aufgabe: \(trimmed)"
        prefs.noteDraft = ""
    }
}

// MARK: Converter

/// Exchange rates of the European Central Bank, through frankfurter.dev. Asked only when someone
/// types a currency, at most every twelve hours. The request carries no amount and nothing personal.
@Observable
final class CurrencyRates {
    static let shared = CurrencyRates()

    /// How much of each currency one euro buys.
    private(set) var rates: [String: Double]
    /// The day the rates are from ("2026-11-13").
    private(set) var day: String
    private(set) var failed = false
    @ObservationIgnored private var fetched: Date
    @ObservationIgnored private var loading = false
    /// A failed attempt is not repeated on every keystroke: at most once a minute.
    @ObservationIgnored private var lastAttempt = Date.distantPast
    @ObservationIgnored private let d = UserDefaults.standard

    private init() {
        rates = (d.dictionary(forKey: "rates.eur") as? [String: Double]) ?? [:]
        day = d.string(forKey: "rates.day") ?? ""
        fetched = d.object(forKey: "rates.fetched") as? Date ?? .distantPast
    }

    /// For snapshots.
    func loadSample() {
        rates = ["CHF": 0.9266, "USD": 1.1052, "GBP": 0.8342]
        day = "2026-11-13"
        fetched = .now
    }

    /// Never called while a view draws: the tile asks once when it appears (`.task`), and a
    /// failed attempt waits a minute before the next one.
    func refreshIfNeeded() {
        guard !loading, Date.now.timeIntervalSince(lastAttempt) > 60 else { return }
        guard rates.isEmpty || Date.now.timeIntervalSince(fetched) > 12 * 3600 else { return }
        loading = true
        lastAttempt = .now
        Task {
            defer { loading = false }
            struct Answer: Decodable { var date: String; var rates: [String: Double] }
            guard let url = URL(string: "https://api.frankfurter.dev/v1/latest?base=EUR"),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let answer = try? JSONDecoder().decode(Answer.self, from: data), !answer.rates.isEmpty else {
                failed = rates.isEmpty
                return
            }
            rates = answer.rates
            day = answer.date
            fetched = .now
            failed = false
            d.set(answer.rates, forKey: "rates.eur")
            d.set(answer.date, forKey: "rates.day")
            d.set(fetched, forKey: "rates.fetched")
        }
    }
}

/// One field for money, units and time zones: «100 chf in eur», «5 km in mi», «15:00 zürich in tokio».
struct ConverterTile: View {
    private var rates = CurrencyRates.shared
    private var prefs = Prefs.shared

    /// Like the note: the query stays while the island is away.
    private var draft: Binding<String> {
        Binding(get: { prefs.converterDraft }, set: { prefs.converterDraft = $0 })
    }

    private struct Answer {
        var value: String
        var detail: String
    }

    var body: some View {
        let answer = self.answer
        IslandCard(width: Metrics.wideTileWidth - 64) {
            VStack(alignment: .leading, spacing: Space.xs) {
                CardHeader(title: "Umrechner", symbol: "arrow.left.arrow.right")
                TextField("100 chf in eur", text: draft)
                    .textFieldStyle(.plain).font(TypeStyle.islandBody)
                    .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
                    .background(IslandColor.field, in: RoundedRectangle(cornerRadius: Radius.chip))
                    .onSubmit { copy(answer?.value) }
                    .accessibilityLabel("Umrechnen")
                Spacer(minLength: 0)
                if let answer {
                    Button { copy(answer.value) } label: {
                        Text(answer.value).font(TypeStyle.islandTimer).lineLimit(1).minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(IslandPressStyle())
                    .help("Kopieren")
                    .accessibilityLabel("Ergebnis \(answer.value), kopieren")
                }
                Text(answer?.detail ?? hint)
                    .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText).lineLimit(2)
            }
        }
        // Rates are asked for when the tile appears, never from inside the body.
        .task { rates.refreshIfNeeded() }
    }

    private var hint: String {
        prefs.converterDraft.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Geld, Masse, Zeit: «5 km in mi», «15:00 zürich in tokio»"
            : "So: Zahl, Einheit, «in», Einheit"
    }

    private var answer: Answer? {
        guard let query = Converter.parse(prefs.converterDraft) else { return nil }
        switch query {
        case .unit(let value, let from, let to):
            guard let result = Converter.convertUnit(value, from: from, to: to) else { return nil }
            return Answer(value: "\(Converter.format(result)) \(Converter.label(to))",
                          detail: "\(Converter.format(value)) \(Converter.label(from))")
        case .currency(let amount, let from, let to):
            guard let result = Converter.convertCurrency(amount, from: from, to: to, eurRates: rates.rates) else {
                let text = rates.rates.isEmpty ? (rates.failed ? "Kurse nicht erreichbar" : "Kurse werden geladen …")
                                               : "Für \(from) oder \(to) gibt es keinen Kurs"
                return Answer(value: "–", detail: text)
            }
            return Answer(value: "\(Converter.format(result, money: true)) \(to)",
                          detail: "\(Converter.format(amount, money: true)) \(from) · Kurs der EZB vom \(shortDay(rates.day))")
        case .time(let hour, let minute, let from, let to):
            guard let there = Converter.convertTime(hour: hour, minute: minute, from: from, to: to, on: .now) else { return nil }
            let offset = there.dayOffset > 0 ? "am Tag danach" : (there.dayOffset < 0 ? "am Tag davor" : "am selben Tag")
            return Answer(value: String(format: "%02d:%02d", there.hour, there.minute),
                          detail: "\(place(to)), \(offset)")
        }
    }

    /// "2026-11-13" -> "13.11."
    private func shortDay(_ iso: String) -> String {
        let parts = iso.split(separator: "-")
        return parts.count == 3 ? "\(parts[2]).\(parts[1])." : iso
    }

    /// "America/New_York" -> "New York"
    private func place(_ zone: String) -> String {
        (zone.split(separator: "/").last.map(String.init) ?? zone).replacingOccurrences(of: "_", with: " ")
    }

    private func copy(_ value: String?) {
        guard let value, value != "–" else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        IslandModel.shared.show(Toast(symbol: "doc.on.doc", text: "Kopiert: \(value)"))
    }
}

// MARK: Color picker

/// The colors picked from the screen, newest first. Only the hex values are kept.
@Observable
final class ColorSamples {
    static let shared = ColorSamples()

    private(set) var recent: [String]
    @ObservationIgnored private var sampler: NSColorSampler?

    private init() { recent = UserDefaults.standard.stringArray(forKey: "colors.recent") ?? [] }

    /// For snapshots.
    func loadSample() { recent = ["#245483", "#CFE1F4", "#FFD9C8", "#B23A12", "#F16F41"] }

    /// The system's loupe: click a point on the screen, its color lands in the clipboard as hex.
    func pick() {
        // The island would sit in the way of what you want to pick.
        IslandController.shared.close()
        let sampler = NSColorSampler()
        self.sampler = sampler
        sampler.show { @Sendable color in
            // Read the color where the system hands it over; only the text crosses to the main actor.
            let hex = color?.usingColorSpace(.sRGB).map {
                ColorHex.string(red: Double($0.redComponent), green: Double($0.greenComponent), blue: Double($0.blueComponent))
            }
            Task { @MainActor in
                ColorSamples.shared.sampler = nil
                if let hex { ColorSamples.shared.add(hex) }
            }
        }
    }

    func add(_ hex: String) {
        recent.removeAll { $0 == hex }
        recent.insert(hex, at: 0)
        if recent.count > 5 { recent.removeLast(recent.count - 5) }
        UserDefaults.standard.set(recent, forKey: "colors.recent")
        copy(hex)
    }

    func copy(_ hex: String) {
        let text = ColorHex.copyString(hex, format: Prefs.shared.colorCopyFormat)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        IslandModel.shared.show(Toast(symbol: "eyedropper", text: "\(text) kopiert"))
    }
}

struct ColorPickerTile: View {
    private var colors = ColorSamples.shared

    var body: some View {
        IslandCard {
            VStack(alignment: .leading, spacing: Space.xs) {
                CardHeader(title: "Farbpipette", symbol: "eyedropper")
                if colors.recent.isEmpty {
                    Text("Nimm eine Farbe vom Bildschirm auf.")
                        .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText).lineLimit(2)
                } else {
                    HStack(spacing: Space.xs) {
                        ForEach(colors.recent, id: \.self) { hex in
                            Button { colors.copy(hex) } label: {
                                Circle().fill(Color(hexString: hex))
                                    .overlay(Circle().strokeBorder(IslandColor.separator))
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(IslandPressStyle())
                            .help("\(hex) kopieren")
                            .accessibilityLabel("Farbe \(hex) kopieren")
                        }
                    }
                    let code = ColorHex.copyString(colors.recent[0], format: Prefs.shared.colorCopyFormat)
                    HStack(spacing: Space.xs) {
                        Text(code).font(TypeStyle.islandCode).foregroundStyle(IslandColor.secondaryText)
                            .lineLimit(1).truncationMode(.tail).help(code)
                        Spacer(minLength: 0)
                        Picker("Format", selection: Binding(get: { Prefs.shared.colorCopyFormat }, set: { Prefs.shared.colorCopyFormat = $0 })) {
                            ForEach(ColorHex.CopyFormat.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                        .controlSize(.mini)
                        .fixedSize()
                    }
                }
                Spacer(minLength: 0)
                IslandPillButton(title: "Aufnehmen", kind: .primary) { colors.pick() }
            }
        }
    }
}

extension Color {
    /// "#RRGGBB" as a color; anything else is clear.
    init(hexString: String) {
        guard hexString.count == 7, let value = UInt32(hexString.dropFirst(), radix: 16) else { self = .clear; return }
        self.init(hex: value)
    }
}

// MARK: Mirror

/// The Mac's camera as a mirror. It runs only after you switch it on, and stops when the island closes.
@Observable
final class MirrorCamera {
    static let shared = MirrorCamera()

    enum State: Equatable { case off, on, denied, missing }
    private(set) var state: State = .off

    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private var configured = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: run()
        case .notDetermined:
            Task {
                // Asked only now, the first time someone wants the mirror.
                if await AVCaptureDevice.requestAccess(for: .video) { self.run() } else { self.state = .denied }
            }
        default: state = .denied
        }
    }

    private func run() {
        if !configured {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
                state = .missing
                return
            }
            session.sessionPreset = .medium
            session.addInput(input)
            configured = true
        }
        state = .on
        // Starting and stopping block for a moment: never on the main thread.
        nonisolated(unsafe) let session = session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    func stop() {
        guard state == .on else { return }
        state = .off
        nonisolated(unsafe) let session = session
        DispatchQueue.global(qos: .utility).async { session.stopRunning() }
    }
    func stopIfUnused() {
        if Windows.isOpen(.camera) { return }
        if IslandController.shared.model.isOpen { return }
        stop()
    }
}

/// The camera picture, mirrored left to right like a real mirror.
struct MirrorPreview: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: MirrorCamera.shared.session)
        layer.videoGravity = .resizeAspectFill
        if let connection = layer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

struct MirrorTile: View {
    private var camera = MirrorCamera.shared
    /// Three to two: wide enough for a face, no wider than needed.
    private let width: CGFloat = 192

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        Group {
            if camera.state == .on {
                MirrorPreview()
                    .frame(width: width, height: Metrics.tileHeight)
                    .clipShape(shape)
                    .overlay(alignment: .topTrailing) {
                        IslandIconButton(symbol: "xmark", label: "Spiegel ausschalten", size: 24) { camera.stop() }
                            .padding(Space.sm)
                    }
                    .accessibilityLabel("Spiegel, Kamerabild")
            } else {
                IslandCard(width: width) {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        CardHeader(title: "Spiegel", symbol: "person.crop.square")
                        Text(message).font(TypeStyle.islandCaption).foregroundStyle(camera.state == .off ? IslandColor.secondaryText : IslandColor.warm)
                            .lineLimit(3)
                        Spacer(minLength: 0)
                        if camera.state == .denied {
                            IslandPillButton(title: "Einstellungen öffnen") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        } else {
                            IslandPillButton(title: "Einschalten", kind: .primary) { camera.start() }
                        }
                    }
                }
            }
        }
        .onDisappear { camera.stopIfUnused() }
    }

    private var message: String {
        switch camera.state {
        case .off, .on: "Die Kamera läuft nur, solange der Spiegel an ist."
        case .denied: "Vibrant+ darf die Kamera nicht nutzen. Erlaube sie unter Datenschutz › Kamera."
        case .missing: "Keine Kamera gefunden."
        }
    }
}

struct CameraPreviewView: View {
    var body: some View {
        VStack(spacing: Space.sm) {
            MirrorPreview()
                .frame(minWidth: 320, minHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            Text("Die Kamera läuft nur, solange dieses Fenster offen ist. Nichts wird aufgezeichnet.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(Space.md)
        .onAppear { MirrorCamera.shared.start() }
    }
}
