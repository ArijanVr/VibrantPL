// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import EventKit
import Foundation
import Observation

/// Apple Reminders, read through EventKit. Checking one off writes exactly that one change back.
@Observable
final class RemindersService {
    static let shared = RemindersService()

    struct Item: Identifiable, Equatable {
        var id: String
        var title: String
        var due: Date?
        var list: String

        static func == (a: Item, b: Item) -> Bool { a.id == b.id && a.title == b.title && a.due == b.due }
    }

    /// Overdue and due today first, then the next ones (at most 5).
    private(set) var items: [Item] = []
    private(set) var access: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    private(set) var failed = false

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var reminders: [String: EKReminder] = [:]

    var granted: Bool { access == .fullAccess }

    func start() {
        guard timer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        timer = Timer.repeating(every: 5 * 60) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        reload()
    }

    func stop() {
        timer?.invalidate(); timer = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    func requestAccess() {
        Task {
            _ = try? await store.requestFullAccessToReminders()
            self.access = EKEventStore.authorizationStatus(for: .reminder)
            self.reload()
        }
    }

    func reload() {
        access = EKEventStore.authorizationStatus(for: .reminder)
        guard granted else { items = []; return }
        let predicate = store.predicateForReminders(in: nil)
        // EventKit calls this on a background queue: the closure must not be main-actor isolated.
        store.fetchReminders(matching: predicate) { @Sendable [weak self] found in
            guard let self, let found else { return }
            let open = found.filter { !$0.isCompleted }
            let cal = Calendar.current
            let now = Date.now
            func dueDate(_ r: EKReminder) -> Date? { r.dueDateComponents.flatMap { cal.date(from: $0) } }
            let overdue = open.filter { dueDate($0).map({ $0 < now }) ?? false }
                .sorted { (dueDate($0) ?? .distantFuture) < (dueDate($1) ?? .distantFuture) }
            let upcoming = open.filter { dueDate($0).map({ $0 >= now }) ?? true }
                .sorted { (dueDate($0) ?? .distantFuture) < (dueDate($1) ?? .distantFuture) }
            let shown = Array((overdue + upcoming).prefix(5))
            // EventKit callbacks are off the main actor; mark the reminder map for the hop.
            nonisolated(unsafe) let byID = Dictionary(uniqueKeysWithValues: found.map { ($0.calendarItemIdentifier, $0) })
            let rows = shown.map { Item(id: $0.calendarItemIdentifier, title: $0.title ?? "Ohne Titel",
                                                              due: dueDate($0), list: $0.calendar.title) }
            DispatchQueue.main.async {
                self.reminders = byID
                self.items = rows
            }
        }
    }

    /// Checks one reminder off. Only this reminder is written back.
    func complete(_ item: Item) {
        guard let reminder = reminders[item.id] else { return }
        reminder.isCompleted = true
        do {
            try store.save(reminder, commit: true)
            items.removeAll { $0.id == item.id }
        } catch {
            failed = true
        }
    }

    /// Fictional reminders for snapshots and marketing images.
    func loadSample() {
        access = .fullAccess
        let now = Date.now
        items = [
            Item(id: "r1", title: "Rechnung an Atelier Nord", due: now.addingTimeInterval(-2 * 3600), list: "Arbeit"),
            Item(id: "r2", title: "Rahmen abholen", due: now, list: "Privat"),
            Item(id: "r3", title: "Release-Notizen lesen", due: now.addingTimeInterval(26 * 3600), list: "Arbeit"),
        ]
    }

    /// «überfällig», «heute» or the date — one short word for the tile.
    static func dueText(_ due: Date?, now: Date = .now) -> String {
        guard let due else { return "irgendwann" }
        let cal = Calendar.current
        if due < now && !cal.isDateInToday(due) { return "überfällig" }
        if cal.isDateInToday(due) { return due < now ? "überfällig" : due.formatted(date: .omitted, time: .shortened) }
        if cal.isDateInTomorrow(due) { return "morgen" }
        return due.formatted(date: .abbreviated, time: .omitted)
    }
}
