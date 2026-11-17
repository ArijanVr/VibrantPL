// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct TaskItem: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var created: Date
    public var done: Date?
    public var remindAt: Date?
    /// The Notion page this task was saved to, when Notion is connected.
    public var notionPageID: String?

    public init(title: String, created: Date = .now) {
        id = UUID()
        self.title = title
        self.created = created
    }

    public var isDone: Bool { done != nil }
}

public struct FocusEntry: Codable, Sendable, Equatable {
    public var day: Date
    public var minutes: Int
}

/// Everything on the Today page that is saved: tasks, the note, focus minutes, card layout.
public struct TodayData: Codable, Sendable, Equatable {
    public enum Card: String, Codable, CaseIterable, Sendable, Identifiable {
        case tasks, focus, note, events
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .tasks: "Aufgaben"
            case .focus: "Fokus"
            case .note: "Notiz"
            case .events: "Termine"
            }
        }
    }

    public var tasks: [TaskItem] = []
    public var note: String = ""
    public var focus: [FocusEntry] = []
    public var cards: [Card] = Card.allCases
    public var hiddenCards: Set<Card> = []
    public var focusMinutes: Int = 25

    public init() {}

    public static func cleanTitle(_ raw: String) -> String {
        raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    @discardableResult
    public mutating func addTask(_ raw: String, now: Date = .now) -> TaskItem? {
        let title = Self.cleanTitle(raw)
        guard !title.isEmpty else { return nil }
        let task = TaskItem(title: title, created: now)
        tasks.append(task)
        return task
    }

    public mutating func toggle(_ id: UUID, now: Date = .now) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].done = tasks[i].done == nil ? now : nil
        if tasks[i].done != nil { tasks[i].remindAt = nil }
    }

    public mutating func remind(_ id: UUID, at date: Date?) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].remindAt = date
    }

    /// Open tasks whose reminder time has come.
    public func due(at now: Date) -> [TaskItem] {
        tasks.filter { !$0.isDone && ($0.remindAt.map { $0 <= now } ?? false) }
    }

    public mutating func addFocus(minutes: Int, on day: Date, calendar: Calendar = .current) {
        guard minutes > 0 else { return }
        let start = calendar.startOfDay(for: day)
        if let i = focus.firstIndex(where: { calendar.isDate($0.day, inSameDayAs: start) }) {
            focus[i].minutes += minutes
        } else {
            focus.append(FocusEntry(day: start, minutes: minutes))
        }
    }

    /// Tasks done more than a week ago leave the list; insights keep their counts in `focus` only.
    public mutating func pruneOldDone(now: Date) {
        tasks.removeAll { ($0.done.map { now.timeIntervalSince($0) > 7 * 86400 }) ?? false }
    }
}

/// The last seven days for the Insights chart.
public struct DayInsight: Sendable, Equatable, Identifiable {
    public var id: Date { day }
    public var day: Date
    public var added: Int
    public var done: Int
    public var focusMinutes: Int
}

public enum Insights {
    public static func lastSevenDays(_ data: TodayData, now: Date, calendar: Calendar = .current) -> [DayInsight] {
        let today = calendar.startOfDay(for: now)
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let added = data.tasks.filter { calendar.isDate($0.created, inSameDayAs: day) }.count
            let done = data.tasks.filter { $0.done.map { calendar.isDate($0, inSameDayAs: day) } ?? false }.count
            let focus = data.focus.filter { calendar.isDate($0.day, inSameDayAs: day) }.reduce(0) { $0 + $1.minutes }
            return DayInsight(day: day, added: added, done: done, focusMinutes: focus)
        }
    }
}

/// Saves a Codable value as JSON in one file, atomically.
public struct JSONFile<Value: Codable> {
    public let url: URL

    public init(url: URL) { self.url = url }

    public func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Value.self, from: data)
    }

    public func save(_ value: Value) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
