// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Pure parts of the Notion integration: request bodies, schema detection,
/// response parsing. Networking lives in the app (NotionService).
/// API reference: https://developers.notion.com (version header 2022-06-28).
public enum NotionKit {
    public static let apiVersion = "2022-06-28"
    public static let baseURL = URL(string: "https://api.notion.com/v1/")!

    /// A database the integration can see.
    public struct Database: Equatable, Sendable, Identifiable, Codable {
        public var id: String
        public var title: String
        public init(id: String, title: String) { self.id = id; self.title = title }
    }

    /// Which property of a database Vibrant+ writes to.
    public struct Mapping: Equatable, Sendable, Codable {
        public var title: String
        public var date: String?
        public enum Done: Equatable, Sendable, Codable {
            case checkbox(String)
            case status(property: String, done: String, open: String?)
        }
        public var done: Done?

        public init(title: String, date: String?, done: Done?) {
            self.title = title
            self.date = date
            self.done = done
        }
    }

    // MARK: Parsing

    public static func parseDatabases(_ data: Data) -> [Database] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return [] }
        return results.compactMap { r in
            guard r["object"] as? String == "database", let id = r["id"] as? String else { return nil }
            let title = ((r["title"] as? [[String: Any]]) ?? []).compactMap { $0["plain_text"] as? String }.joined()
            return Database(id: id, title: title.isEmpty ? "Ohne Titel" : title)
        }
    }

    /// Picks the title, a date and a "done" property from a database schema.
    public static func mapping(fromDatabase data: Data) -> Mapping? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let props = json["properties"] as? [String: [String: Any]] else { return nil }
        guard let title = props.first(where: { $0.value["type"] as? String == "title" })?.key else { return nil }

        // Most specific names first: "Fällig" beats a generic "Datum".
        let dateNames = ["fällig", "faellig", "due", "deadline", "termin", "datum", "date", "wann", "zeit", "when"]
        let dates = props.filter { $0.value["type"] as? String == "date" }.map(\.key).sorted()
        let date = dateNames.lazy.compactMap { key in dates.first { $0.lowercased().contains(key) } }.first ?? dates.first

        let doneNames = ["erledigt", "done", "fertig", "complete", "abgeschlossen"]
        var done: Mapping.Done?
        let checkboxes = props.filter { $0.value["type"] as? String == "checkbox" }.map(\.key).sorted()
        if let cb = checkboxes.first(where: { n in doneNames.contains { n.lowercased().contains($0) } }) ?? checkboxes.first {
            done = .checkbox(cb)
        } else if let status = props.first(where: { $0.value["type"] as? String == "status" }) {
            let options = ((status.value["status"] as? [String: Any])?["options"] as? [[String: Any]] ?? [])
                .compactMap { $0["name"] as? String }
            let doneOption = options.first { o in doneNames.contains { o.lowercased().contains($0) } } ?? options.last
            let openOption = options.first { o in ["nicht", "not", "offen", "to do", "todo"].contains { o.lowercased().contains($0) } }
                ?? options.first
            if let d = doneOption { done = .status(property: status.key, done: d, open: openOption == d ? nil : openOption) }
        }
        return Mapping(title: title, date: date, done: done)
    }

    public static func pageID(fromCreateResponse data: Data) -> String? {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["id"] as? String
    }

    // MARK: Request bodies

    static func isoDate(_ date: Date, allDay: Bool, timeZone: TimeZone) -> String {
        if allDay {
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .gregorian)
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = timeZone
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: date)
        }
        let f = ISO8601DateFormatter()
        f.timeZone = timeZone
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }

    static func dateValue(start: Date, end: Date?, allDay: Bool, timeZone: TimeZone) -> [String: Any] {
        var d: [String: Any] = ["start": isoDate(start, allDay: allDay, timeZone: timeZone)]
        if let end { d["end"] = isoDate(end, allDay: allDay, timeZone: timeZone) }
        return ["date": d]
    }

    /// POST /v1/pages body for a new entry.
    public static func createPageBody(database: String, mapping: Mapping, title: String, start: Date? = nil, end: Date? = nil,
                                      allDay: Bool = false, done: Bool = false, timeZone: TimeZone = .current) -> [String: Any] {
        var props: [String: Any] = [
            mapping.title: ["title": [["type": "text", "text": ["content": String(title.prefix(2000))]]]],
        ]
        if let start, let dateProp = mapping.date {
            props[dateProp] = dateValue(start: start, end: end, allDay: allDay, timeZone: timeZone)
        }
        if let doneProps = doneProperty(mapping, done: done) { props.merge(doneProps) { $1 } }
        return ["parent": ["database_id": database], "properties": props]
    }

    /// PATCH /v1/pages/{id} body to mark an entry done or open.
    public static func doneBody(mapping: Mapping, done: Bool) -> [String: Any]? {
        doneProperty(mapping, done: done).map { ["properties": $0] }
    }

    /// PATCH body to set or clear the date.
    public static func dateBody(mapping: Mapping, date: Date?, timeZone: TimeZone = .current) -> [String: Any]? {
        guard let prop = mapping.date else { return nil }
        let value: Any = date.map { dateValue(start: $0, end: nil, allDay: false, timeZone: timeZone) } ?? ["date": NSNull()]
        return ["properties": [prop: value]]
    }

    static func doneProperty(_ mapping: Mapping, done: Bool) -> [String: Any]? {
        switch mapping.done {
        case .checkbox(let name): return [name: ["checkbox": done]]
        case .status(let name, let doneName, let openName):
            if done { return [name: ["status": ["name": doneName]]] }
            return openName.map { [name: ["status": ["name": $0]]] }
        case nil: return nil
        }
    }

    /// Notion error JSON -> readable German text.
    public static func errorMessage(status: Int, body: Data) -> String {
        let code = (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["code"] as? String
        switch (status, code) {
        case (401, _): return "Der Notion-Schlüssel ist ungültig."
        case (403, _): return "Vibrant+ darf diese Notion-Seite nicht bearbeiten. Teile die Datenbank mit der Integration."
        case (404, _): return "Datenbank nicht gefunden. Ist sie mit der Integration geteilt?"
        case (429, _): return "Notion bremst gerade. Versuch es gleich nochmals."
        case (400, "validation_error"): return "Notion hat die Daten abgelehnt (Eigenschaften passen nicht)."
        default: return "Notion antwortet mit Fehler \(status)."
        }
    }
}

// MARK: - Reading back from Notion

public struct RemoteTask: Equatable, Sendable {
    public var pageID: String
    public var title: String
    public var done: Bool
    public var date: Date?
    public var archived: Bool
}

public enum NotionSync {
    /// POST /v1/databases/{id}/query body: newest edits first.
    public static func queryBody(pageSize: Int = 100) -> [String: Any] {
        ["page_size": pageSize, "sorts": [["timestamp": "last_edited_time", "direction": "descending"]]]
    }

    public static func parseQuery(_ data: Data, mapping: NotionKit.Mapping) -> [RemoteTask] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return [] }
        return results.compactMap { page in
            guard let id = page["id"] as? String, let props = page["properties"] as? [String: Any] else { return nil }
            let title = (((props[mapping.title] as? [String: Any])?["title"] as? [[String: Any]]) ?? [])
                .compactMap { $0["plain_text"] as? String }.joined()
            var done = false
            switch mapping.done {
            case .checkbox(let n): done = (props[n] as? [String: Any])?["checkbox"] as? Bool ?? false
            case .status(let n, let d, _): done = (((props[n] as? [String: Any])?["status"] as? [String: Any])?["name"] as? String) == d
            case nil: break
            }
            var date: Date?
            if let dp = mapping.date, let start = ((props[dp] as? [String: Any])?["date"] as? [String: Any])?["start"] as? String {
                date = parseDate(start)
            }
            let archived = (page["archived"] as? Bool ?? false) || (page["in_trash"] as? Bool ?? false)
            return RemoteTask(pageID: id, title: title, done: done, date: date, archived: archived)
        }
    }

    static func parseDate(_ s: String) -> Date? {
        let full = ISO8601DateFormatter()
        full.formatOptions = [.withInternetDateTime]
        if let d = full.date(from: s) { return d }
        let frac = ISO8601DateFormatter()
        frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = frac.date(from: s) { return d }
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        return day.date(from: s)
    }

    public struct Result: Equatable {
        public var tasks: [TaskItem]
        public var changed: Int
        public var added: Int
    }

    /// Merges what Notion says into the local tasks. Notion wins for tasks it knows
    /// (title, done, date); open pages that are new in Notion become local tasks;
    /// done or archived pages that Vibrant+ does not know are ignored.
    public static func merge(local: [TaskItem], remote: [RemoteTask], now: Date = .now) -> Result {
        var tasks = local
        var changed = 0, added = 0
        for r in remote {
            if let i = tasks.firstIndex(where: { $0.notionPageID == r.pageID }) {
                if r.archived { tasks.remove(at: i); changed += 1; continue }
                var t = tasks[i]
                let before = t
                if !r.title.isEmpty { t.title = r.title }
                if r.done != t.isDone { t.done = r.done ? now : nil }
                if !t.isDone { t.remindAt = r.date }
                if t != before { tasks[i] = t; changed += 1 }
            } else if !r.archived, !r.done, !r.title.isEmpty {
                var t = TaskItem(title: TodayData.cleanTitle(r.title), created: now)
                t.notionPageID = r.pageID
                t.remindAt = r.date
                tasks.append(t)
                added += 1
            }
        }
        return Result(tasks: tasks, changed: changed, added: added)
    }
}
