// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppIntents
import Foundation
import UniformTypeIdentifiers
import VibrantPlusKit

// Actions Vibrant+ offers to Siri, Spotlight and the Shortcuts app.
// They run inside Vibrant+ (launched by the system if needed).

struct AskAssistantIntent: AppIntent {
    static let title: LocalizedStringResource = "Vibrant+ fragen"
    static let description = IntentDescription("Stellt dem Vibrant+-Assistenten eine Frage. Er antwortet mit Apple Intelligence direkt auf dem Mac.")

    @Parameter(title: "Frage", requestValueDialog: "Was möchtest du wissen?")
    var question: String

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let answer = try await Assistant.answerOnce(question)
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
}

struct AddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Aufgabe hinzufügen"
    static let description = IntentDescription("Fügt eine Aufgabe zur Heute-Liste von Vibrant+ hinzu.")

    @Parameter(title: "Aufgabe", requestValueDialog: "Welche Aufgabe?")
    var title: String

    @Parameter(title: "Erinnern in Minuten", default: 0)
    var remindInMinutes: Int

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = TodayStore.shared
        store.addTask(title)
        if remindInMinutes > 0, let task = store.openTasks.last {
            store.remindAt(task, .now.addingTimeInterval(TimeInterval(remindInMinutes * 60)))
        }
        store.saveNow()
        return .result(dialog: IntentDialog(stringLiteral: remindInMinutes > 0
            ? "«\(title)» ist auf der Liste. Ich erinnere dich in \(remindInMinutes) Minuten."
            : "«\(title)» ist auf der Liste."))
    }
}

struct AddEventIntent: AppIntent {
    static let title: LocalizedStringResource = "Termin anlegen"
    static let description = IntentDescription("Legt einen Termin an: in Notion, wenn verbunden, sonst im Apple-Kalender.")

    @Parameter(title: "Titel", requestValueDialog: "Wie heisst der Termin?")
    var title: String

    @Parameter(title: "Beginn", requestValueDialog: "Wann?")
    var start: Date

    @Parameter(title: "Dauer in Minuten", default: 60)
    var minutes: Int

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let when = start.formatted(.dateTime.weekday().day().month().hour().minute())
        switch await Appointments.add(title: title, start: start, minutes: minutes) {
        case .notion: return .result(dialog: IntentDialog(stringLiteral: "«\(title)» am \(when) ist in Notion gespeichert."))
        case .calendar: return .result(dialog: IntentDialog(stringLiteral: "«\(title)» am \(when) ist im Kalender gespeichert."))
        case .failed(let why): return .result(dialog: IntentDialog(stringLiteral: why))
        }
    }
}

struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Fokus starten"
    static let description = IntentDescription("Startet eine Fokus-Sitzung in Vibrant+.")

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        TodayStore.shared.startFocus()
        return .result(dialog: IntentDialog(stringLiteral: "Fokus läuft, \(TodayStore.shared.data.focusMinutes) Minuten."))
    }
}

struct StartTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Timer starten"
    static let description = IntentDescription("Startet einen Timer im Notch.")

    @Parameter(title: "Minuten", inclusiveRange: (1, 600), requestValueDialog: "Wie viele Minuten?")
    var minutes: Int

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        QuickTimer.shared.start(minutes: Double(minutes))
        return .result(dialog: IntentDialog(stringLiteral: "Timer für \(minutes) Minuten läuft."))
    }
}

struct OpenIslandIntent: AppIntent {
    static let title: LocalizedStringResource = "Insel öffnen"
    static let description = IntentDescription("Öffnet die Vibrant+-Insel unter dem Notch.")

    @MainActor func perform() async throws -> some IntentResult {
        IslandController.shared.open(sticky: true)
        return .result()
    }
}

struct ArrangeWindowsIntent: AppIntent {
    static let title: LocalizedStringResource = "Fenster in eine Reihe"
    static let description = IntentDescription("Ordnet die sichtbaren Fenster mit Rowline nebeneinander.")

    @MainActor func perform() async throws -> some IntentResult {
        WindowManager.shared.arrangeRow()
        return .result()
    }
}

/// Phrases Siri understands without setup. Each must contain the app name.
struct VibrantShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AskAssistantIntent(), phrases: ["Frag \(.applicationName)", "\(.applicationName) fragen"],
                    shortTitle: "Fragen", systemImageName: "bubble.left.and.text.bubble.right")
        AppShortcut(intent: AddTaskIntent(), phrases: ["Aufgabe in \(.applicationName) hinzufügen", "Neue Aufgabe in \(.applicationName)"],
                    shortTitle: "Aufgabe hinzufügen", systemImageName: "checklist")
        AppShortcut(intent: AddEventIntent(), phrases: ["Termin in \(.applicationName) anlegen", "Neuer Termin in \(.applicationName)"],
                    shortTitle: "Termin anlegen", systemImageName: "calendar.badge.plus")
        AppShortcut(intent: StartFocusIntent(), phrases: ["Fokus in \(.applicationName) starten", "Starte Fokus mit \(.applicationName)"],
                    shortTitle: "Fokus starten", systemImageName: "scope")
        AppShortcut(intent: StartTimerIntent(), phrases: ["Timer in \(.applicationName) starten"],
                    shortTitle: "Timer starten", systemImageName: "timer")
        AppShortcut(intent: OpenIslandIntent(), phrases: ["Öffne die Insel in \(.applicationName)"],
                    shortTitle: "Insel öffnen", systemImageName: "capsule.tophalf.filled")
        AppShortcut(intent: ArrangeWindowsIntent(), phrases: ["Ordne Fenster mit \(.applicationName)"],
                    shortTitle: "Fenster ordnen", systemImageName: "rectangle.split.3x1")
        AppShortcut(intent: TakeScreenshotIntent(), phrases: ["Bildschirmfoto mit \(.applicationName)", "Screenshot mit \(.applicationName)",
                                                             "\(\.$mode) mit \(.applicationName) aufnehmen"],
                    shortTitle: "Bildschirmfoto", systemImageName: "camera.viewfinder")
    }
}

// MARK: Screenshots

enum CaptureModeEntity: String, AppEnum {
    case screen, window, area

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Aufnahme"
    static let caseDisplayRepresentations: [CaptureModeEntity: DisplayRepresentation] = [
        .screen: DisplayRepresentation(title: "Ganzer Bildschirm", image: .init(systemName: "display")),
        .window: DisplayRepresentation(title: "Fenster", image: .init(systemName: "macwindow")),
        .area: DisplayRepresentation(title: "Ausschnitt", image: .init(systemName: "rectangle.dashed")),
    ]

    var mode: CaptureMode { CaptureMode(rawValue: rawValue) ?? .area }
}

struct TakeScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Bildschirmfoto aufnehmen"
    static let description = IntentDescription("Nimmt mit Vibrant+ ein Bildschirmfoto auf: den ganzen Bildschirm, ein Fenster, das du anklickst, oder einen Ausschnitt, den du aufziehst. Das Bild landet im Screenshot-Ordner und in der Zwischenablage und wird als Datei weitergegeben.")

    @Parameter(title: "Aufnahme", default: .area)
    var mode: CaptureModeEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Bildschirmfoto: \(\.$mode)")
    }

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<IntentFile?> & ProvidesDialog {
        switch await ScreenCapture.shared.capture(mode.mode) {
        case .saved(let url):
            return .result(value: IntentFile(fileURL: url, filename: url.lastPathComponent, type: .png),
                           dialog: "Bildschirmfoto gesichert und kopiert.")
        case .cancelled:
            return .result(value: nil, dialog: "Abgebrochen, kein Bildschirmfoto.")
        case .notAllowed:
            return .result(value: nil, dialog: "Vibrant+ darf den Bildschirm noch nicht aufnehmen. Erlaube es unter Systemeinstellungen › Datenschutz & Sicherheit › Bildschirm- & Systemaudioaufnahme und starte Vibrant+ neu.")
        case .failed:
            return .result(value: nil, dialog: "Das Bildschirmfoto hat nicht geklappt.")
        }
    }
}
