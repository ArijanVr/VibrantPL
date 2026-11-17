// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Observation
import VibrantPlusKit

/// How far back the ring looks.
private let usageWindow: TimeInterval = 7 * 24 * 3600

/// Collects what Claude Code, Codex and OpenCode used, from the data the tools
/// themselves write. Nothing is sent anywhere; the numbers never leave the Mac.
@Observable
final class UsageStore {
    static let shared = UsageStore()

    private(set) var report = UsageReport()
    private(set) var updated: Date?
    private(set) var scanning = false
    /// Which tools have data on this Mac at all.
    private(set) var present: Set<AIProvider> = []

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var task: Task<Void, Never>?

    func start() {
        guard timer == nil else { return }
        timer = Timer.repeating(every: 5 * 60) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        task?.cancel()
        task = nil
        scanning = false
    }

    /// Fictional usage for snapshots and marketing images.
    func loadSample() {
        report = UsageReport(
            models: [
                ModelUsage(provider: .claude, model: "claude-opus-5-5", tokens: 12_400_000, lastActive: .now),
                ModelUsage(provider: .claude, model: "claude-sonnet-5-5", tokens: 5_100_000, lastActive: .now),
                ModelUsage(provider: .codex, model: "gpt-6.1-sol", tokens: 3_800_000, lastActive: .now.addingTimeInterval(-3600)),
                ModelUsage(provider: .opencode, model: "kimi-k3", tokens: 900_000, lastActive: .now.addingTimeInterval(-7200)),
            ],
            activity: [ProviderActivity(provider: .claude, detail: "~/Developer/VibrantPlus", when: .now, live: true)],
            quotas: [UsageQuota(provider: .codex, window: "5-Stunden-Fenster", usedPercent: 34, resets: .now.addingTimeInterval(3 * 3600))])
        updated = .now
        present = [.claude, .codex, .opencode]
    }

    /// Reads again when the last read is older than a minute (e.g. the island opens).
    /// Only while the tile is on: nobody home, nobody counts.
    func refreshIfStale() {
        guard timer != nil else { return }
        if updated.map({ Date.now.timeIntervalSince($0) > 60 }) ?? true { refresh() }
    }

    func refresh() {
        guard task == nil else { return }
        scanning = true
        let home = FileManager.default.homeDirectoryForCurrentUser
        let extras = AgentUsageExtrasPreferences.shared
        let codexHomes = extras.codexHomes
        let copilotEnabled = extras.copilotEnabled
        let environmentCodexHome = ProcessInfo.processInfo.environment["CODEX_HOME"]
        let since = Date.now.addingTimeInterval(-usageWindow)
        task = Task.detached(priority: .utility) {
            let report = Self.scan(home: home, since: since, codexHomes: codexHomes, environmentCodexHome: environmentCodexHome, includeCopilot: copilotEnabled)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.report = report
                self.present = Set(report.models.map(\.provider) + report.activity.map(\.provider))
                self.updated = .now
                self.scanning = false
                self.task = nil
            }
        }
    }

    /// One pass over all three tools. Off the main thread; pure file reads plus one sqlite3 call.
    /// Files that did not change since the last pass come from the cache, not from disk again
    /// (a week of transcripts is hundreds of megabytes).
    nonisolated static func scan(home: URL, since: Date, codexHomes: [CodexHome] = [], environmentCodexHome: String? = nil, includeCopilot: Bool = false) -> UsageReport {
        var merged = UsageReport()
        let claude = scanCached(provider: .claude, root: home.appendingPathComponent(AIProvider.claude.dataRoot),
                                depth: 2, prefix: nil, since: since) { url, _ in ClaudeUsage.scan(file: url) }
        merged.models = claude.models
        merged.activity = claude.activity
        for root in CodexHomes.resolved(home: home, environmentHome: environmentCodexHome, additional: codexHomes) {
            var report = scanCached(provider: .codex, root: root.sessions,
                                    depth: 4, prefix: "rollout-", since: since) { url, modified in CodexUsage.scan(file: url, modified: modified) }
            report.quotas = report.quotas.map { quota in
                var quota = quota; quota.account = root.label; return quota
            }
            merged.models += report.models
            merged.activity += report.activity
            merged.quotas += report.quotas
        }
        if includeCopilot {
            let report = scanCached(provider: .copilot, root: home.appending(path: AIProvider.copilot.dataRoot),
                                    depth: 3, prefix: "events", since: since) { url, modified in CopilotUsage.scan(file: url, modified: modified) }
            merged.models += report.models
            merged.activity += report.activity
        }

        let db = home.appendingPathComponent(AIProvider.opencode.dataRoot).path
        if FileManager.default.fileExists(atPath: db) {
            let uri = "file:" + db + "?mode=ro"
            let sinceMs = Int(since.timeIntervalSince1970 * 1000)
            let rows = Run.program("/usr/bin/sqlite3", ["-readonly", "-separator", "\t", uri,
                "select coalesce(model,''), sum(tokens_input+tokens_output), max(time_updated) from session_v2 where time_updated > \(sinceMs) group by model;"], timeout: 15)
            if rows.status == 0 {
                merged.models += OpenCodeUsage.parseRows(rows.output)
            }
            let last = Run.program("/usr/bin/sqlite3", ["-readonly", "-separator", "\t", uri,
                "select coalesce(title,''), coalesce(directory,''), time_updated from session_v2 order by time_updated desc limit 1;"], timeout: 15)
            if last.status == 0, let activity = OpenCodeUsage.parseActivity(last.output) {
                merged.activity.append(activity)
            }
        }
        // Accounts get separate limit cards, while the model ring retains one segment per model.
        var models: [String: ModelUsage] = [:]
        for model in merged.models {
            if var previous = models[model.id] {
                previous.tokens += model.tokens
                previous.lastActive = max(previous.lastActive, model.lastActive)
                models[model.id] = previous
            } else { models[model.id] = model }
        }
        merged.models = Array(models.values)
        merged.models.sort { $0.tokens > $1.tokens }
        merged.activity.sort { $0.when > $1.when }
        return merged
    }

    /// The per-file cache: keyed by path, valid while size and modification date match.
    /// Only the scan task touches it, and only one scan runs at a time.
    nonisolated(unsafe) private static var cache: [String: (size: Int, modified: Date, scan: FileScan)] = [:]

    nonisolated private static func scanCached(provider: AIProvider, root: URL, depth: Int, prefix: String?, since: Date,
                                               parse: (URL, Date) -> FileScan) -> UsageReport {
        let files = jsonlFiles(in: root, depth: depth, since: since, prefix: prefix)
        // Files that fell out of the window leave the cache, so it cannot grow without end.
        let rootKey = provider.rawValue + "|" + root.standardizedFileURL.resolvingSymlinksInPath().path + "|"
        let alive = Set(files.map { rootKey + $0.url.path })
        cache = cache.filter { !($0.key.hasPrefix(rootKey) && !alive.contains($0.key)) }
        return merge(provider: provider, files: files) { url, modified in
            let key = rootKey + url.path
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if let hit = cache[key], hit.size == size, hit.modified == modified { return hit.scan }
            let scan = parse(url, modified)
            cache[key] = (size, modified, scan)
            return scan
        }
    }
}
