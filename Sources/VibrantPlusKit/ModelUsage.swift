// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Which assistant the tokens belong to.
public enum AIProvider: String, Sendable, Codable, CaseIterable {
    case claude, codex, opencode, copilot

    public var title: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .opencode: "OpenCode"
        case .copilot: "GitHub Copilot"
        }
    }

    /// The folder the tool itself writes, below the home directory.
    public var dataRoot: String {
        switch self {
        case .claude: ".claude/projects"
        case .codex: ".codex/sessions"
        case .opencode: ".local/share/opencode/opencode.db"
        case .copilot: ".copilot/session-state"
        }
    }
}

extension AIProvider {
    /// The command line tool's name, for finding it on this Mac.
    public var binaryName: String {
        switch self {
        case .claude: "claude"
        case .codex: "codex"
        case .opencode: "opencode"
        case .copilot: "copilot"
        }
    }

    /// What the settings say about this tool, honest about what is known: only local data is read,
    /// so "installed" and "has data" are told apart.
    public func statusText(installed: Bool, hasData: Bool) -> String {
        switch (installed, hasData) {
        case (true, true): "Erkannt, Verbrauch wird aus den lokalen Daten gelesen"
        case (true, false): "Installiert, noch keine Sitzungen in den letzten 7 Tagen"
        case (false, true): "Nicht installiert, aber Daten früherer Sitzungen vorhanden"
        case (false, false): "\(title) ist auf diesem Mac nicht installiert"
        }
    }
}

/// Tokens of one model of one provider, over the report window.
public struct ModelUsage: Sendable, Identifiable, Equatable {
    public var provider: AIProvider
    public var model: String
    public var tokens: Int
    public var lastActive: Date

    public init(provider: AIProvider, model: String, tokens: Int, lastActive: Date) {
        self.provider = provider
        self.model = model
        self.tokens = tokens
        self.lastActive = lastActive
    }

    public var id: String { provider.rawValue + "/" + model }
}

/// What a provider did most recently, so the island can say «arbeitet gerade».
public struct ProviderActivity: Sendable, Equatable {
    public var provider: AIProvider
    public var detail: String
    public var when: Date
    /// Fresh enough to count as running right now.
    public var live: Bool

    public init(provider: AIProvider, detail: String, when: Date, live: Bool) {
        self.provider = provider
        self.detail = detail
        self.when = when
        self.live = live
    }
}

/// A quota window a provider reports itself (Codex writes one into every session).
public struct UsageQuota: Sendable, Equatable, Identifiable {
    public var provider: AIProvider
    public var window: String
    public var usedPercent: Double
    public var resets: Date?
    public var account: String?

    public init(provider: AIProvider, window: String, usedPercent: Double, resets: Date?, account: String? = nil) {
        self.provider = provider
        self.window = window
        self.usedPercent = usedPercent
        self.resets = resets
        self.account = account
    }

    public var id: String { provider.rawValue + "/" + (account.map { $0 + "/" } ?? "") + window }
}

/// Everything the ring and the status rows need.
public struct UsageReport: Sendable, Equatable {
    public var models: [ModelUsage] = []
    public var activity: [ProviderActivity] = []
    public var quotas: [UsageQuota] = []

    public init(models: [ModelUsage] = [], activity: [ProviderActivity] = [], quotas: [UsageQuota] = []) {
        self.models = models
        self.activity = activity
        self.quotas = quotas
    }

    public var total: Int { models.reduce(0) { $0 + $1.tokens } }

    /// Share of one model between 0 and 1.
    public func share(_ m: ModelUsage) -> Double {
        total > 0 ? Double(m.tokens) / Double(total) : 0
    }
}

// MARK: - Claude Code

/// What one log file yielded: tokens per model, the newest moment, and a quota when the
/// file carries one (Codex). File-level so a caller can cache by size and modification date.
public struct FileScan: Sendable, Equatable {
    public var models: [String: Int] = [:]
    public var newest: Date?
    public var detail: String = ""
    public var quotas: [UsageQuota] = []
    public var activityLive: Bool?
    public var quotaStamp = Date.distantPast

    public init() {}
}

/// Reads Claude Code transcripts (~/.claude/projects/*/<session>.jsonl).
/// A message streams in several lines; only the last line of each message id counts.
public enum ClaudeUsage {
    public static func scan(file url: URL) -> FileScan {
        var scan = FileScan()
        guard let data = try? Data(contentsOf: url) else { return scan }
        var last: [String: (model: String, usage: [String: Any])] = [:]
        var order: [String] = []
        var anon = 0
        for raw in data.split(separator: 0x0A) {
            guard let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else { continue }
            if let c = obj["cwd"] as? String, !c.isEmpty { scan.detail = c }
            if let ts = obj["timestamp"] as? String, let when = ModelUsageTime.iso(ts) {
                if scan.newest.map({ when > $0 }) ?? true { scan.newest = when }
            }
            guard obj["type"] as? String == "assistant",
                  let message = obj["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else { continue }
            let id = (message["id"] as? String) ?? { anon += 1; return "anon-\(anon)" }()
            if last[id] == nil { order.append(id) }
            last[id] = ((message["model"] as? String) ?? "claude", usage)
        }
        for id in order {
            guard let entry = last[id] else { continue }
            let u = entry.usage
            scan.models[entry.model, default: 0] += ((u["input_tokens"] as? Int) ?? 0) + ((u["output_tokens"] as? Int) ?? 0)
                + ((u["cache_read_input_tokens"] as? Int) ?? 0) + ((u["cache_creation_input_tokens"] as? Int) ?? 0)
        }
        return scan
    }

    public static func scan(projectsRoot: URL, since: Date) -> UsageReport {
        merge(provider: .claude, files: jsonlFiles(in: projectsRoot, depth: 2, since: since, prefix: nil)) { url, _ in scan(file: url) }
    }
}

// MARK: - Codex

/// Reads Codex session rollouts (~/.codex/sessions/**/rollout-*.jsonl).
/// `turn_context` names the model, `token_usage_record` carries the tokens of one answer,
/// `token_count` carries the account quotas Codex itself reports.
public enum CodexUsage {
    public static func scan(file url: URL, modified: Date) -> FileScan {
        var scan = FileScan()
        guard let data = try? Data(contentsOf: url) else { return scan }
        var model = "codex"
        for raw in data.split(separator: 0x0A) {
            guard let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else { continue }
            // Two shapes: wrapped (`event_msg` with payload.type) and direct (outer type, payload without type).
            let payload = obj["payload"] as? [String: Any] ?? [:]
            guard let kind = (payload["type"] as? String) ?? (obj["type"] as? String) else { continue }
            let stamp = (obj["timestamp"] as? String).flatMap(ModelUsageTime.iso) ?? modified
            switch kind {
            case "turn_context":
                if let m = payload["model"] as? String, !m.isEmpty { model = m }
                if let c = payload["cwd"] as? String, !c.isEmpty { scan.detail = c }
                if scan.newest.map({ stamp > $0 }) ?? true { scan.newest = stamp }
            case "token_usage_record":
                guard let usage = payload["usage"] as? [String: Any],
                      let tokens = usage["total_tokens"] as? Int, tokens > 0 else { continue }
                scan.models[model, default: 0] += tokens
                if scan.newest.map({ stamp > $0 }) ?? true { scan.newest = stamp }
            case "token_count":
                guard stamp > scan.quotaStamp, let limits = payload["rate_limits"] as? [String: Any] else { continue }
                scan.quotaStamp = stamp
                scan.quotas = Self.quotas(from: limits)
            default: continue
            }
        }
        return scan
    }

    public static func scan(sessionsRoot: URL, since: Date) -> UsageReport {
        merge(provider: .codex, files: jsonlFiles(in: sessionsRoot, depth: 4, since: since, prefix: "rollout-")) { scan(file: $0, modified: $1) }
    }

    /// `primary` is the short window (hours), `secondary` the long one (days).
    static func quotas(from limits: [String: Any]) -> [UsageQuota] {
        func quota(_ key: String, _ window: String) -> UsageQuota? {
            guard let q = limits[key] as? [String: Any], let used = q["used_percent"] as? Double else { return nil }
            let minutes = (q["window_minutes"] as? Int) ?? 0
            let label = minutes >= 24 * 60 ? "\(minutes / (24 * 60))-Tage-Fenster" : "\(minutes / 60)-Stunden-Fenster"
            let resets = (q["resets_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
            return UsageQuota(provider: .codex, window: label, usedPercent: used, resets: resets)
        }
        return [quota("primary", "primary"), quota("secondary", "secondary")].compactMap { $0 }
    }
}

// MARK: - OpenCode

/// OpenCode keeps its data in a SQLite database. The app reads it with the system `sqlite3`
/// (fixed path, argument list, never a shell); here the rows become models and activity.
public enum OpenCodeUsage {
    /// Rows from `select model, tokens_input+tokens_output, time_updated from session_v2 …`,
    /// one per line, tab-separated.
    public static func parseRows(_ text: String) -> [ModelUsage] {
        var byModel: [String: (tokens: Int, last: Date)] = [:]
        for line in text.split(separator: "\n") {
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard cols.count >= 3 else { continue }
            let model = modelName(from: String(cols[0]))
            let tokens = Int(cols[1]) ?? 0
            // OpenCode stores milliseconds.
            let stamp = (Double(cols[2]) ?? 0) / 1000
            guard stamp > 0 else { continue }
            var slot = byModel[model] ?? (0, .distantPast)
            slot.tokens += tokens
            slot.last = max(slot.last, Date(timeIntervalSince1970: stamp))
            byModel[model] = slot
        }
        return byModel.map { ModelUsage(provider: .opencode, model: $0.key, tokens: $0.value.tokens, lastActive: $0.value.last) }
    }

    /// Row of `select title, directory, time_updated from session_v2 order by time_updated desc limit 1`.
    public static func parseActivity(_ text: String) -> ProviderActivity? {
        let cols = text.split(separator: "\n").first?.split(separator: "\t", omittingEmptySubsequences: false)
        guard let cols, cols.count >= 3, let stamp = Double(cols[2]) else { return nil }
        let when = Date(timeIntervalSince1970: stamp / 1000)
        let detail = cols[0].isEmpty ? String(cols[1]) : String(cols[0])
        return ProviderActivity(provider: .opencode, detail: detail, when: when, live: Date.now.timeIntervalSince(when) < 120)
    }

    /// OpenCode writes the model as JSON: {"id":"…","providerID":"…"}.
    static func modelName(from raw: String) -> String {
        guard raw.hasPrefix("{"), let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = obj["id"] as? String, !id.isEmpty else { return raw.isEmpty ? "opencode" : raw }
        return id
    }
}

// MARK: - Helpers

/// Combines what single files yielded into one report. The quota with the newest stamp wins.
public func merge(provider: AIProvider, files: [(url: URL, modified: Date)], scan: (URL, Date) -> FileScan) -> UsageReport {
    var byModel: [String: (tokens: Int, last: Date)] = [:]
    var newest: (when: Date, detail: String, live: Bool?)?
    var quotas: [UsageQuota] = []
    var quotaStamp = Date.distantPast
    for file in files {
        let one = scan(file.url, file.modified)
        for (model, tokens) in one.models {
            var slot = byModel[model] ?? (0, .distantPast)
            slot.tokens += tokens
            slot.last = max(slot.last, one.newest ?? file.modified)
            byModel[model] = slot
        }
        if let when = one.newest, newest.map({ when > $0.when }) ?? true { newest = (when, one.detail, one.activityLive) }
        if one.quotaStamp > quotaStamp { quotaStamp = one.quotaStamp; quotas = one.quotas }
    }
    var report = UsageReport()
    // Models with zero tokens (synthetic lines) would only take a legend row.
    report.models = byModel.filter { $0.value.tokens > 0 }
        .map { ModelUsage(provider: provider, model: provider == .claude ? shortName($0.key) : $0.key,
                          tokens: $0.value.tokens, lastActive: $0.value.last) }
    report.quotas = quotas
    if let n = newest {
        report.activity = [ProviderActivity(provider: provider, detail: n.detail, when: n.when, live: n.live ?? (Date.now.timeIntervalSince(n.when) < 120))]
    }
    return report
}

/// Walks a data root without following links and returns files that changed lately.
public func jsonlFiles(in root: URL, depth: Int, since: Date, prefix: String?) -> [(url: URL, modified: Date)] {
    let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isRegularFileKey]
    guard let walk = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys),
                                                    options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
    var found: [(URL, Date)] = []
    for case let url as URL in walk {
        guard url.pathExtension == "jsonl", prefix.map({ url.lastPathComponent.hasPrefix($0) }) ?? true else { continue }
        guard walk.level <= depth + 1, let values = try? url.resourceValues(forKeys: keys),
              values.isRegularFile == true, let modified = values.contentModificationDate,
              modified >= since else { continue }
        found.append((url, modified))
    }
    return found.sorted { $0.1 > $1.1 }
}

/// "claude-opus-4-5-20251101" → "claude-opus-4-5".
func shortName(_ model: String) -> String {
    var parts = model.split(separator: "-").map(String.init)
    if let last = parts.last, last.count == 8, last.allSatisfy(\.isNumber) { parts.removeLast() }
    return parts.joined(separator: "-")
}

enum ModelUsageTime {
    // ISO8601FormatStyle is value type and Sendable; the formatter class is not.
    static func iso(_ s: String) -> Date? {
        if let d = try? Date(s, strategy: .iso8601.year().month().day()
            .time(includingFractionalSeconds: true).timeZone(separator: .omitted)) { return d }
        return try? Date(s, strategy: .iso8601)
    }
}
