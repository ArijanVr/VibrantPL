// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import EventKit
import Foundation
import Observation
import Security
import VibrantPlusKit

/// The Notion secret lives in the macOS Keychain, never in UserDefaults or files.
nonisolated enum Keychain {
    static let service = "ch.arjo.vibrantplus.notion"

    static func read(_ account: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    @discardableResult
    static func save(_ value: String, for account: String) -> Bool {
        delete(account)
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecValueData as String: Data(value.utf8),
                                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    static func delete(_ account: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account]
        SecItemDelete(q as CFDictionary)
    }
}

/// Saves tasks and events to the person's Notion workspace through the official API.
/// Setup: create an internal integration in Notion, paste its secret, share the databases with it.
@Observable
final class NotionService {
    static let shared = NotionService()

    struct Target: Codable, Equatable {
        var database: NotionKit.Database
        var mapping: NotionKit.Mapping
    }

    private(set) var connected = false
    private(set) var workspaceUser: String?
    private(set) var databases: [NotionKit.Database] = []
    private(set) var tasksTarget: Target? { didSet { persist() } }
    private(set) var eventsTarget: Target? { didSet { persist() } }
    private(set) var busy = false
    var message: String?
    /// The last sync problem, shown in Settings; sync never blocks the app.
    private(set) var lastError: String?

    /// Swappable for the self-test (a URLProtocol that answers like Notion).
    @ObservationIgnored var session: URLSession = .shared
    @ObservationIgnored var baseURL = NotionKit.baseURL
    @ObservationIgnored private let account: String

    var syncTasks: Bool { tasksTarget != nil && connected }
    var syncEvents: Bool { eventsTarget != nil && connected }

    init(account: String = ProcessInfo.processInfo.environment["APP_DATA"] == nil ? "default" : "selftest") {
        self.account = account
        connected = Keychain.read(account) != nil
        let d = UserDefaults.standard
        defer { if connected && tasksTarget != nil && account == "default" { startPulling() } }
        if let data = d.data(forKey: "notion.tasks.\(account)") { tasksTarget = try? JSONDecoder().decode(Target.self, from: data) }
        if let data = d.data(forKey: "notion.events.\(account)") { eventsTarget = try? JSONDecoder().decode(Target.self, from: data) }
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(tasksTarget.flatMap { try? JSONEncoder().encode($0) }, forKey: "notion.tasks.\(account)")
        d.set(eventsTarget.flatMap { try? JSONEncoder().encode($0) }, forKey: "notion.events.\(account)")
    }

    // MARK: Connection

    /// Checks the secret with Notion before saving it.
    func connect(secret raw: String) async {
        let secret = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !secret.isEmpty else { return }
        busy = true
        defer { busy = false }
        do {
            let data = try await request("GET", "users/me", body: nil, token: secret)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            workspaceUser = (json?["bot"] as? [String: Any])?["workspace_name"] as? String ?? json?["name"] as? String
            Keychain.save(secret, for: account)
            connected = true
            message = "Verbunden\(workspaceUser.map { " mit «\($0)»" } ?? "")."
            await loadDatabases()
        } catch {
            message = (error as? NotionError)?.text ?? "Notion ist nicht erreichbar."
        }
    }

    func disconnect() {
        Keychain.delete(account)
        connected = false
        databases = []
        tasksTarget = nil
        eventsTarget = nil
        stopPulling()
        workspaceUser = nil
        message = "Getrennt. Der Schlüssel wurde aus dem Schlüsselbund entfernt."
    }

    func loadDatabases() async {
        do {
            let body: [String: Any] = ["filter": ["property": "object", "value": "database"], "page_size": 100]
            databases = NotionKit.parseDatabases(try await request("POST", "search", body: body))
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            if databases.isEmpty { message = "Keine Datenbank sichtbar. Teile eine Datenbank in Notion mit der Integration (••• › Verbindungen)." }
        } catch {
            message = (error as? NotionError)?.text ?? "Datenbanken liessen sich nicht laden."
        }
    }

    enum Kind { case tasks, events }

    func choose(_ db: NotionKit.Database?, for kind: Kind) async {
        guard let db else {
            if kind == .tasks { tasksTarget = nil } else { eventsTarget = nil }
            return
        }
        do {
            let data = try await request("GET", "databases/\(db.id)", body: nil)
            guard let mapping = NotionKit.mapping(fromDatabase: data) else { message = "Diese Datenbank hat keine Titel-Eigenschaft."; return }
            let target = Target(database: db, mapping: mapping)
            if kind == .tasks { tasksTarget = target; startPulling() } else { eventsTarget = target }
            if kind == .events && mapping.date == nil {
                message = "«\(db.title)» hat keine Datums-Eigenschaft: Termine bekommen dort kein Datum."
            } else {
                message = nil
            }
        } catch {
            message = (error as? NotionError)?.text ?? "Datenbank liess sich nicht lesen."
        }
    }

    // MARK: Reading back

    private(set) var lastPull: Date?
    @ObservationIgnored private var pullTimer: Timer?

    /// While connected with a task database, Notion is read every 2 minutes: ticks, renames,
    /// reminders and new pages made in Notion show up in Vibrant+.
    func startPulling() {
        guard pullTimer == nil else { return }
        pullTimer = Timer.repeating(every: 120) { [weak self] _ in
            Task { @MainActor in await self?.pull() }
        }
        Task { await pull() }
    }

    func stopPulling() { pullTimer?.invalidate(); pullTimer = nil }

    @discardableResult
    func pull() async -> Int {
        guard syncTasks, let t = tasksTarget else { return 0 }
        do {
            let data = try await request("POST", "databases/\(t.database.id)/query", body: NotionSync.queryBody())
            let remote = NotionSync.parseQuery(data, mapping: t.mapping)
            lastPull = .now
            lastError = nil
            return TodayStore.shared.applyNotion(remote)
        } catch {
            lastError = (error as? NotionError)?.text ?? "Notion ist nicht erreichbar."
            return 0
        }
    }

    // MARK: Writing

    /// New task -> new page. Returns the page id.
    func createTask(_ task: TaskItem) async -> String? {
        guard let t = tasksTarget, connected else { return nil }
        let body = NotionKit.createPageBody(database: t.database.id, mapping: t.mapping, title: task.title,
                                           start: task.remindAt, done: task.isDone)
        return await write("POST", "pages", body: body).flatMap(NotionKit.pageID(fromCreateResponse:))
    }

    func setDone(pageID: String, _ done: Bool) async {
        guard let t = tasksTarget, connected, let body = NotionKit.doneBody(mapping: t.mapping, done: done) else { return }
        _ = await write("PATCH", "pages/\(pageID)", body: body)
    }

    func setDate(pageID: String, _ date: Date?) async {
        guard let t = tasksTarget, connected, let body = NotionKit.dateBody(mapping: t.mapping, date: date) else { return }
        _ = await write("PATCH", "pages/\(pageID)", body: body)
    }

    func archive(pageID: String) async {
        guard connected else { return }
        _ = await write("PATCH", "pages/\(pageID)", body: ["archived": true])
    }

    /// New event -> page in the events database.
    func createEvent(title: String, start: Date, end: Date?, allDay: Bool) async -> String? {
        guard let t = eventsTarget, connected else { return nil }
        let body = NotionKit.createPageBody(database: t.database.id, mapping: t.mapping, title: title, start: start, end: end, allDay: allDay)
        return await write("POST", "pages", body: body).flatMap(NotionKit.pageID(fromCreateResponse:))
    }

    private func write(_ method: String, _ path: String, body: [String: Any]) async -> Data? {
        do {
            let d = try await request(method, path, body: body)
            lastError = nil
            return d
        } catch {
            lastError = (error as? NotionError)?.text ?? "Notion ist nicht erreichbar; der Eintrag blieb nur in Vibrant+."
            return nil
        }
    }

    struct NotionError: Error { var text: String }

    private func request(_ method: String, _ path: String, body: [String: Any]?, token: String? = nil) async throws -> Data {
        guard let secret = token ?? Keychain.read(account) else { throw NotionError(text: "Nicht mit Notion verbunden.") }
        var req = URLRequest(url: baseURL.appending(path: path))
        req.httpMethod = method
        req.timeoutInterval = 20
        req.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        req.setValue(NotionKit.apiVersion, forHTTPHeaderField: "Notion-Version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw NotionError(text: NotionKit.errorMessage(status: status, body: data)) }
        return data
    }

    /// For the self-test only: pretend a secret is stored.
    func testConnect(secret: String) {
        Keychain.save(secret, for: account)
        connected = true
    }

    func testCleanup() {
        Keychain.delete(account)
        UserDefaults.standard.removeObject(forKey: "notion.tasks.\(account)")
        UserDefaults.standard.removeObject(forKey: "notion.events.\(account)")
    }
}

/// Appointments: into the Notion events database when one is chosen, else into Apple Calendar.
@MainActor
enum Appointments {
    enum Result { case notion, calendar, failed(String) }

    static func add(title: String, start: Date, minutes: Int = 60, allDay: Bool = false) async -> Result {
        let end = allDay ? nil : start.addingTimeInterval(TimeInterval(max(5, minutes) * 60))
        let notion = NotionService.shared
        if notion.syncEvents {
            if await notion.createEvent(title: title, start: start, end: end, allDay: allDay) != nil { return .notion }
            return .failed(notion.lastError ?? "Notion hat den Termin nicht angenommen.")
        }
        let store = EKEventStore()
        if EKEventStore.authorizationStatus(for: .event) != .fullAccess {
            guard (try? await store.requestFullAccessToEvents()) == true else {
                return .failed("Kein Zugriff auf den Kalender. Erlaube ihn in den Systemeinstellungen.")
            }
        }
        let e = EKEvent(eventStore: store)
        e.title = title
        e.startDate = start
        e.endDate = end ?? start.addingTimeInterval(86400)
        e.isAllDay = allDay
        e.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(e, span: .thisEvent)
            CalendarService.shared.reload()
            return .calendar
        } catch {
            return .failed("Der Termin liess sich nicht speichern: \(error.localizedDescription)")
        }
    }
}
