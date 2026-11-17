// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import AVFoundation
import FoundationModels
import Observation
import VibrantPlusKit

/// Conversations with Apple Intelligence's on-device language model (Foundation Models).
/// Runs entirely on this Mac: no account, no cost, no network. The model can act
/// through a few tools (tasks, timer, focus, apps, today's events).
@Observable
final class Assistant {
    static let shared = Assistant()

    struct Turn: Identifiable, Equatable {
        let id = UUID()
        var question: String
        var answer: String
        var done = false
        var failed = false
    }

    private(set) var turns: [Turn] = []
    private(set) var busy = false
    /// Show the answer card in the island.
    var visible = false

    @ObservationIgnored private var session: LanguageModelSession?
    @ObservationIgnored private var lastUse = Date.distantPast
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let speaker = AVSpeechSynthesizer()
    @ObservationIgnored private let speechDelegate = SpeechDelegate()
    /// "System voice": Spoken Content / Siri (via SystemSpeechBridge). AVSpeech cannot use Siri voices.
    static let systemVoiceTag = "system"
    @ObservationIgnored private lazy var systemSpeaker: SystemSpeechBridge = {
        let s = SystemSpeechBridge()
        s.onFinished = { Task { @MainActor in Assistant.shared.speechFinished() } }
        return s
    }()
    /// Spoken back-and-forth: after an answer is read out, Vibrant+ listens again.
    private(set) var conversationActive = false

    func beginConversation() { conversationActive = true }

    func endConversation(sayGoodbye: Bool = false) {
        conversationActive = false
        if sayGoodbye { say("Gern geschehen.") }
    }

    static func isGoodbye(_ text: String) -> Bool {
        let t = text.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        return ["danke", "danke schön", "dankeschön", "merci", "stopp", "stop", "ende", "tschüss", "tschau", "das wars", "das war's", "fertig"].contains(t)
    }

    /// Called when a read-out answer has finished.
    fileprivate func speechFinished() {
        guard conversationActive, IslandModel.shared.isOpen || visible else { conversationActive = false; return }
        VoiceController.shared.listen(handsFree: true)
    }

    /// A follow-up within five minutes continues the same conversation.
    static let conversationTimeout: TimeInterval = 300

    enum State: Equatable {
        case available
        case unavailable(String)
    }

    static var state: State {
        switch SystemLanguageModel.default.availability {
        case .available: return .available
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                return .unavailable("Apple Intelligence ist ausgeschaltet. Schalte es in den Systemeinstellungen › Apple Intelligence & Siri ein.")
            case .deviceNotEligible:
                return .unavailable("Dieser Mac unterstützt Apple Intelligence nicht.")
            case .modelNotReady:
                return .unavailable("Das Sprachmodell wird noch geladen. Versuch es in ein paar Minuten wieder.")
            @unknown default:
                return .unavailable("Das Sprachmodell ist gerade nicht verfügbar.")
            }
        }
    }

    static var isAvailable: Bool { state == .available }

    static var instructions: String { baseInstructions + "\nJetzt ist " + Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute().locale(Locale(identifier: "de_CH"))) + "." }

    static let baseInstructions = """
    Du bist der Assistent von Vibrant+, einer Mac-App im Notch. Antworte auf Deutsch in Schweizer Rechtschreibung \
    (ss statt ß), kurz und freundlich, höchstens drei Sätze, ausser jemand will mehr. Antworte in der Sprache der Frage, \
    wenn sie nicht Deutsch ist. Nutze die Werkzeuge, wenn jemand eine Aufgabe, eine Erinnerung, einen Timer, Fokus, \
    eine App, einen neuen Termin oder die Termine von heute möchte. Termine speicherst du mit addEvent. Erfinde keine Fakten; sag ehrlich, wenn du etwas nicht weisst. \
    Du hast keinen Zugang zum Internet.
    """

    func newConversation() {
        task?.cancel()
        session = nil
        turns = []
        busy = false
        stopSpeaking()
    }

    func ask(_ raw: String, speak: Bool = Prefs.shared.assistantSpeaks) {
        let question = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        visible = true
        if case .unavailable(let why) = Self.state {
            turns.append(Turn(question: question, answer: why, done: true, failed: true))
            return
        }
        if session == nil || Date.now.timeIntervalSince(lastUse) > Self.conversationTimeout {
            session = LanguageModelSession(tools: [AddTaskTool(), AddEventTool(), TimerTool(), FocusTool(), OpenAppTool(), TodayEventsTool()],
                                           instructions: Self.instructions)
            turns = []
        }
        lastUse = .now
        guard let session, !session.isResponding else { return }
        turns.append(Turn(question: question, answer: ""))
        let index = turns.count - 1
        busy = true
        stopSpeaking()
        task = Task {
            do {
                for try await partial in session.streamResponse(to: question) {
                    guard turns.indices.contains(index) else { return }
                    turns[index].answer = partial.content
                }
                turns[index].done = true
                if speak { say(turns[index].answer) }
            } catch is CancellationError {
            } catch {
                guard turns.indices.contains(index) else { return }
                turns[index].answer = Self.message(for: error)
                turns[index].failed = true
                turns[index].done = true
            }
            busy = false
            lastUse = .now
        }
    }

    /// One question, one answer, without the island (Siri and Shortcuts).
    static func answerOnce(_ question: String) async throws -> String {
        if case .unavailable(let why) = state { return why }
        let session = LanguageModelSession(tools: [AddTaskTool(), AddEventTool(), TimerTool(), FocusTool(), OpenAppTool(), TodayEventsTool()],
                                           instructions: instructions)
        return try await session.respond(to: question).content
    }

    /// Cleans up dictated text (filler words, false starts) in the same language.
    /// Falls back to the rule-based cleaner when the model is not available.
    static func cleanDictation(_ text: String) async -> String {
        let basic = DictationCleaner.clean(text)
        guard isAvailable, text.count > 12 else { return basic }
        let session = LanguageModelSession(instructions: """
        Schreibe das Diktat als sauberen Text in derselben Sprache. Entferne Füllwörter, Versprecher und Wiederholungen. \
        Ändere den Inhalt nicht, beantworte nichts und füge nichts hinzu. Gib nur den bereinigten Text zurück.
        """)
        do {
            let r = try await session.respond(to: text)
            let out = r.content.trimmingCharacters(in: .whitespacesAndNewlines)
            // Guard against the model answering instead of rewriting.
            return out.isEmpty || out.count > text.count * 2 ? basic : out
        } catch {
            return basic
        }
    }

    func say(_ text: String) {
        if Prefs.shared.speechVoiceID == Self.systemVoiceTag {
            let rate = Float(120 + (Prefs.shared.speechRate - 0.35) / 0.25 * 120)
            systemSpeaker.speak(text, rate: rate)
            return
        }
        speaker.delegate = speechDelegate
        speaker.speak(Self.utterance(text))
    }

    /// The chosen Apple voice and rate, else the best voice for the Mac's language.
    static func utterance(_ text: String) -> AVSpeechUtterance {
        let u = AVSpeechUtterance(string: text)
        u.voice = Prefs.shared.speechVoiceID.flatMap(AVSpeechSynthesisVoice.init(identifier:)) ?? defaultVoice
        u.rate = Float(Prefs.shared.speechRate)
        return u
    }

    static var defaultVoice: AVSpeechSynthesisVoice? {
        let lang = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == lang || $0.language == "de-CH" || $0.language.hasPrefix("de") }
        // Highest quality first (premium > enhanced > default).
        return candidates.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: lang)
    }

    /// Voices for the settings: German first, then the Mac's language; best quality first.
    static var choosableVoices: [AVSpeechSynthesisVoice] {
        let lang = String(Locale.current.identifier.prefix(2))
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("de") || $0.language.hasPrefix(lang) }
            .sorted { ($0.quality.rawValue, $0.name) > ($1.quality.rawValue, $1.name) }
    }

    func stopSpeaking() {
        speaker.stopSpeaking(at: .immediate)
        systemSpeaker.stop()
    }

    func copyLastAnswer() {
        guard let a = turns.last?.answer, !a.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(a, forType: .string)
    }

    static func message(for error: Error) -> String {
        if let e = error as? LanguageModelSession.GenerationError {
            switch e {
            case .exceededContextWindowSize: return "Das Gespräch ist zu lang geworden. Starte ein neues Gespräch."
            case .guardrailViolation: return "Dazu kann ich nichts sagen."
            case .unsupportedLanguageOrLocale: return "Diese Sprache unterstützt das Modell nicht."
            default: break
            }
        }
        return "Das hat nicht geklappt: \(error.localizedDescription)"
    }
}

// MARK: - Tools the model may call

struct AddTaskTool: Tool {
    let name = "addTask"
    let description = "Fügt eine Aufgabe zur Heute-Liste hinzu, optional mit Erinnerung in einigen Minuten."

    @Generable
    struct Arguments {
        @Guide(description: "Titel der Aufgabe, kurz")
        var title: String
        @Guide(description: "Erinnerung in so vielen Minuten ab jetzt, 0 für keine Erinnerung")
        var remindInMinutes: Int
    }

    @concurrent func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            let store = TodayStore.shared
            store.addTask(arguments.title)
            if arguments.remindInMinutes > 0, let task = store.openTasks.last {
                store.remindAt(task, Date.now.addingTimeInterval(TimeInterval(arguments.remindInMinutes * 60)))
            }
            return arguments.remindInMinutes > 0
                ? "Aufgabe «\(arguments.title)» hinzugefügt, Erinnerung in \(arguments.remindInMinutes) Minuten."
                : "Aufgabe «\(arguments.title)» hinzugefügt."
        }
    }
}

struct TimerTool: Tool {
    let name = "startTimer"
    let description = "Startet einen Timer mit einer Dauer in Minuten."

    @Generable
    struct Arguments {
        @Guide(description: "Dauer in Minuten", .range(1...600))
        var minutes: Int
    }

    @concurrent func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            QuickTimer.shared.start(minutes: Double(arguments.minutes))
            return "Timer für \(arguments.minutes) Minuten läuft."
        }
    }
}

struct FocusTool: Tool {
    let name = "startFocus"
    let description = "Startet eine Fokus-Sitzung mit der eingestellten Dauer."

    @Generable
    struct Arguments {
        @Guide(description: "Immer true")
        var start: Bool
    }

    @concurrent func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            TodayStore.shared.startFocus()
            return "Fokus läuft, \(TodayStore.shared.data.focusMinutes) Minuten."
        }
    }
}

struct OpenAppTool: Tool {
    let name = "openApp"
    let description = "Öffnet eine auf dem Mac installierte App nach Namen."

    @Generable
    struct Arguments {
        @Guide(description: "Name der App, zum Beispiel Safari oder Musik")
        var name: String
    }

    @concurrent func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            guard let url = VoiceController.findApp(named: arguments.name) else { return "Keine App namens «\(arguments.name)» gefunden." }
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
            return "\(url.deletingPathExtension().lastPathComponent) wird geöffnet."
        }
    }
}

struct TodayEventsTool: Tool {
    let name = "todayEvents"
    let description = "Liest die Termine von heute aus dem Kalender und die offenen Aufgaben."

    @Generable
    struct Arguments {
        @Guide(description: "Immer true")
        var include: Bool
    }

    @concurrent func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            let cal = CalendarService.shared
            var lines: [String] = []
            if !cal.granted {
                lines.append("Kein Kalenderzugriff erlaubt.")
            } else if cal.today.isEmpty {
                lines.append("Heute keine Termine.")
            } else {
                for e in cal.today {
                    lines.append("\(e.allDay ? "ganztägig" : e.start.formatted(.dateTime.hour().minute())): \(e.title)")
                }
            }
            let tasks = TodayStore.shared.openTasks.map(\.title)
            lines.append(tasks.isEmpty ? "Keine offenen Aufgaben." : "Offene Aufgaben: " + tasks.joined(separator: ", "))
            return lines.joined(separator: "\n")
        }
    }
}

struct AddEventTool: Tool {
    let name = "addEvent"
    let description = "Legt einen Termin an (in Notion, falls verbunden, sonst im Apple-Kalender)."

    @Generable
    struct Arguments {
        @Guide(description: "Titel des Termins")
        var title: String
        @Guide(description: "Datum im Format JJJJ-MM-TT")
        var date: String
        @Guide(description: "Uhrzeit im Format HH:mm, leer für ganztägig")
        var time: String
        @Guide(description: "Dauer in Minuten, 60 wenn unbekannt")
        var durationMinutes: Int
    }

    @concurrent func call(arguments: Arguments) async throws -> String {
        guard let start = AddEventTool.parse(date: arguments.date, time: arguments.time) else {
            return "Datum «\(arguments.date) \(arguments.time)» nicht verstanden."
        }
        let allDay = arguments.time.trimmingCharacters(in: .whitespaces).isEmpty
        let result = await Appointments.add(title: arguments.title, start: start, minutes: arguments.durationMinutes, allDay: allDay)
        let when = start.formatted(allDay ? .dateTime.weekday().day().month() : .dateTime.weekday().day().month().hour().minute())
        switch result {
        case .notion: return "Termin «\(arguments.title)» am \(when) in Notion gespeichert."
        case .calendar: return "Termin «\(arguments.title)» am \(when) im Kalender gespeichert."
        case .failed(let why): return why
        }
    }

    nonisolated static func parse(date: String, time: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        let t = time.trimmingCharacters(in: .whitespaces)
        f.dateFormat = t.isEmpty ? "yyyy-MM-dd" : "yyyy-MM-dd HH:mm"
        return f.date(from: t.isEmpty ? date.trimmingCharacters(in: .whitespaces) : "\(date.trimmingCharacters(in: .whitespaces)) \(t)")
    }
}

/// Tells the assistant when a spoken answer is done, so a conversation can listen again.
final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in Assistant.shared.speechFinished() }
    }
}


