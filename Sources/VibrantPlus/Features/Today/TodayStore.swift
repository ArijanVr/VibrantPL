// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Observation
import VibrantPlusKit

/// The Today page: tasks with reminders, the focus timer, the note. Saved as JSON.
@Observable
final class TodayStore {
    static let shared = TodayStore()

    private(set) var data: TodayData
    /// Reminders that are due now; the island shows them until done or snoozed.
    private(set) var due: [TaskItem] = []

    // Focus timer
    private(set) var focusEnd: Date?
    private(set) var focusPausedRemaining: TimeInterval?
    private(set) var focusLength: TimeInterval
    /// Shown once in the notch when a focus session ends.
    @ObservationIgnored var onFocusDone: (() -> Void)?
    @ObservationIgnored var onFocusStarted: (() -> Void)?
    @ObservationIgnored var onFocusEnded: (() -> Void)?
    @ObservationIgnored var onReminder: ((TaskItem) -> Void)?

    @ObservationIgnored private let file = JSONFile<TodayData>(url: Paths.today)
    @ObservationIgnored private var tick: Timer?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    var focusRunning: Bool { focusEnd != nil }
    var focusActive: Bool { focusEnd != nil || focusPausedRemaining != nil }

    func focusRemaining(at now: Date = .now) -> TimeInterval {
        if let end = focusEnd { return max(0, end.timeIntervalSince(now)) }
        return focusPausedRemaining ?? focusLength
    }

    func focusProgress(at now: Date = .now) -> Double {
        guard focusLength > 0 else { return 0 }
        return 1 - focusRemaining(at: now) / focusLength
    }

    private init() {
        var d = file.load() ?? TodayData()
        d.pruneOldDone(now: .now)
        data = d
        focusLength = TimeInterval(d.focusMinutes * 60)
    }

    func start() {
        guard tick == nil else { return }
        tick = Timer.repeating(every: 1) { [weak self] _ in
            MainActor.assumeIsolated { self?.onTick() }
        }
        onTick()
    }

    func stop() { tick?.invalidate(); tick = nil }

    private func onTick() {
        let now = Date.now
        let newlyDue = data.due(at: now)
        for t in newlyDue where !due.contains(where: { $0.id == t.id }) { onReminder?(t) }
        due = newlyDue
        if let end = focusEnd, end <= now { finishFocus(completed: true) }
    }

    // MARK: Tasks

    func addTask(_ title: String) {
        guard let task = data.addTask(title) else { return }
        save()
        pushToNotion(task)
    }

    // MARK: Notion

    /// Saves a new task to Notion and remembers the page; Vibrant+ keeps working without it.
    private func pushToNotion(_ task: TaskItem) {
        guard NotionService.shared.syncTasks else { return }
        Task {
            guard let page = await NotionService.shared.createTask(task),
                  let i = data.tasks.firstIndex(where: { $0.id == task.id }) else { return }
            data.tasks[i].notionPageID = page
            save()
            // Changes made while the page was being created.
            let current = data.tasks[i]
            if current.isDone { await NotionService.shared.setDone(pageID: page, true) }
            if current.remindAt != task.remindAt { await NotionService.shared.setDate(pageID: page, current.remindAt) }
        }
    }

    /// Applies what Notion says. Returns how many tasks changed or arrived.
    func applyNotion(_ remote: [RemoteTask]) -> Int {
        let result = NotionSync.merge(local: data.tasks, remote: remote)
        guard result.changed + result.added > 0 else { return 0 }
        data.tasks = result.tasks
        due.removeAll { d in !data.tasks.contains { $0.id == d.id } }
        save()
        return result.changed + result.added
    }

    private func notionPage(_ id: UUID) -> String? {
        data.tasks.first { $0.id == id }?.notionPageID
    }

    func toggle(_ task: TaskItem) {
        data.toggle(task.id)
        if let page = notionPage(task.id), let done = data.tasks.first(where: { $0.id == task.id })?.isDone {
            Task { await NotionService.shared.setDone(pageID: page, done) }
        }
        due.removeAll { $0.id == task.id }
        save()
    }

    func delete(_ task: TaskItem) {
        if let page = notionPage(task.id) { Task { await NotionService.shared.archive(pageID: page) } }
        data.tasks.removeAll { $0.id == task.id }
        due.removeAll { $0.id == task.id }
        save()
    }

    func remind(_ task: TaskItem, _ preset: ReminderPreset?) {
        let date = preset?.date(from: .now)
        data.remind(task.id, at: date)
        save()
        if let page = notionPage(task.id) { Task { await NotionService.shared.setDate(pageID: page, date) } }
    }

    func remindAt(_ task: TaskItem, _ date: Date) {
        data.remind(task.id, at: date)
        save()
        if let page = notionPage(task.id) { Task { await NotionService.shared.setDate(pageID: page, date) } }
    }

    func snooze(_ task: TaskItem, minutes: Int = 10) {
        data.remind(task.id, at: .now.addingTimeInterval(TimeInterval(minutes * 60)))
        due.removeAll { $0.id == task.id }
        save()
    }

    var openTasks: [TaskItem] { data.tasks.filter { !$0.isDone } }
    var doneToday: [TaskItem] { data.tasks.filter { $0.done.map(Calendar.current.isDateInToday) ?? false } }

    // MARK: Note and cards

    func setNote(_ text: String) {
        data.note = text
        save()
    }

    func setCards(_ cards: [TodayData.Card], hidden: Set<TodayData.Card>) {
        data.cards = cards
        data.hiddenCards = hidden
        save()
    }

    func setFocusMinutes(_ m: Int) {
        data.focusMinutes = max(5, min(180, m))
        if !focusActive { focusLength = TimeInterval(data.focusMinutes * 60) }
        save()
    }

    // MARK: Focus

    func startFocus() {
        if let remaining = focusPausedRemaining {
            focusEnd = .now.addingTimeInterval(remaining)
            focusPausedRemaining = nil
        } else if focusEnd == nil {
            focusLength = TimeInterval(data.focusMinutes * 60)
            focusEnd = .now.addingTimeInterval(focusLength)
            onFocusStarted?()
        }
    }

    func pauseFocus() {
        guard let end = focusEnd else { return }
        focusPausedRemaining = max(0, end.timeIntervalSinceNow)
        focusEnd = nil
    }

    /// ±5 minutes with one click. Never below one minute.
    func adjustFocus(minutes: Int) {
        let delta = TimeInterval(minutes * 60)
        if let end = focusEnd {
            let newEnd = max(Date.now.addingTimeInterval(60), end.addingTimeInterval(delta))
            focusLength += newEnd.timeIntervalSince(end)
            focusEnd = newEnd
        } else if let r = focusPausedRemaining {
            let n = max(60, r + delta)
            focusLength += n - r
            focusPausedRemaining = n
        } else {
            setFocusMinutes(data.focusMinutes + minutes)
        }
    }

    func stopFocus() { finishFocus(completed: false) }

    private func finishFocus(completed: Bool) {
        let done = focusLength - focusRemaining()
        data.addFocus(minutes: Int((done / 60).rounded()), on: .now)
        focusEnd = nil
        focusPausedRemaining = nil
        focusLength = TimeInterval(data.focusMinutes * 60)
        save()
        onFocusEnded?()
        if completed {
            NSSound(named: "Glass")?.play()
            onFocusDone?()
        }
    }

    var insights: [DayInsight] { Insights.lastSevenDays(data, now: .now) }

    // MARK: Saving

    /// Debounced: typing in the note saves once after a short pause.
    private func save() {
        saveTask?.cancel()
        let snapshot = data
        let file = file
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            SaveReport.attempt("Heute") { try file.save(snapshot) }
        }
    }

    func saveNow() {
        saveTask?.cancel()
        SaveReport.attempt("Heute") { try file.save(data) }
    }

    func loadSample() {
        data = TodayData()
        data.addTask("Offerte der Druckerei beantworten")
        if let t = data.addTask("Logo-Dateien an Marta senden") { data.toggle(t.id) }
        if let t = data.addTask("Rechnung Studio bezahlen") { data.remind(t.id, at: .now.addingTimeInterval(3600)) }
        data.note = "Idee: Rowline mit drei Arbeitsbereichen testen."
        let cal = Calendar.current
        for i in 0..<7 {
            let day = cal.date(byAdding: .day, value: -i, to: .now)!
            data.addFocus(minutes: [25, 50, 0, 75, 25, 100, 50][i], on: day)
        }
    }
}

/// A quick timer from the Timer tile and the edge dial.
@Observable
final class QuickTimer {
    static let shared = QuickTimer()
    private(set) var end: Date?
    private(set) var length: TimeInterval = 0
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored var onDone: (() -> Void)?

    var running: Bool { end != nil }

    func remaining(at now: Date = .now) -> TimeInterval { end.map { max(0, $0.timeIntervalSince(now)) } ?? 0 }

    func start(minutes: Double) {
        length = minutes * 60
        end = .now.addingTimeInterval(length)
        timer?.invalidate()
        timer = Timer.repeating(every: 0.5) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let end = self.end, end <= .now else { return }
                self.cancel()
                NSSound(named: "Glass")?.play()
                self.onDone?()
            }
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        end = nil
    }
}

/// Files parked on the island's shelf. They stay where they are on disk;
/// the shelf only keeps references and lets you drag them out again.
@Observable
final class Shelf {
    static let shared = Shelf()
    private(set) var files: [URL] = []

    func add(_ urls: [URL]) {
        for u in urls where !files.contains(u) { files.append(u) }
    }

    func remove(_ url: URL) { files.removeAll { $0 == url } }
    func clear() { files = [] }

    /// Hands files to AirDrop: macOS shows its own picker for the nearby devices.
    @discardableResult
    static func airDrop(_ urls: [URL]) -> Bool {
        guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else { return false }
        service.perform(withItems: urls)
        return true
    }

    /// Drops files that were moved or deleted in the meantime.
    func prune() { files.removeAll { !FileManager.default.fileExists(atPath: $0.path) } }
}
