// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Local Copilot CLI/app `events.jsonl` metadata. Never reads auth files or sends requests.
/// Token metrics are cumulative model snapshots, normally emitted at session shutdown.
public enum CopilotUsage {
    public static func scan(file url: URL, modified: Date) -> FileScan {
        guard let data = try? Data(contentsOf: url) else { return FileScan() }
        return scan(data: data, modified: modified)
    }

    public static func scan(data: Data, modified: Date) -> FileScan {
        var result = FileScan()
        var snapshots: [String: Int] = [:]
        var seen: Set<String> = []
        var session = ""
        var finalResponse = false
        let recognized: Set<String> = ["session.start", "session.context_changed", "session.model_change", "assistant.turn_start", "assistant.message", "assistant.turn_end", "session.shutdown"]
        for line in data.split(separator: 0x0A) {
            guard let event = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let type = event["type"] as? String, recognized.contains(type),
                  let payload = event["data"] as? [String: Any] else { continue }
            if let id = event["id"] as? String, !id.isEmpty, !seen.insert(id).inserted { continue }
            // Subagent metadata cannot overwrite the root session's task or active state.
            let isRoot = payload["agentId"] == nil && event["agentId"] == nil && payload["parentToolCallId"] == nil
            let date = (event["timestamp"] as? String).flatMap(ModelUsageTime.iso) ?? modified
            switch type {
            case "session.start":
                if isRoot {
                    session = payload["sessionId"] as? String ?? session
                    if let context = payload["context"] as? [String: Any] {
                        result.detail = (context["gitRoot"] as? String) ?? (context["cwd"] as? String) ?? result.detail
                    }
                }
            case "session.context_changed":
                if isRoot { result.detail = (payload["gitRoot"] as? String) ?? (payload["cwd"] as? String) ?? (payload["repository"] as? String) ?? result.detail }
            case "assistant.turn_start":
                if isRoot { result.activityLive = true; finalResponse = false }
            case "assistant.message":
                if isRoot {
                    result.activityLive = true
                    let phase = payload["phase"] as? String ?? ""
                    finalResponse = (payload["toolRequests"] as? [Any] ?? []).isEmpty && !["thinking", "commentary"].contains(phase)
                }
            case "assistant.turn_end":
                if isRoot && finalResponse { result.activityLive = false }
            case "session.shutdown":
                if isRoot, let metrics = payload["modelMetrics"] as? [String: Any] {
                    for (model, raw) in metrics {
                        guard let metric = raw as? [String: Any] else { continue }
                        let details = metric["tokenDetails"] as? [String: Any] ?? [:]
                        let usage = metric["usage"] as? [String: Any] ?? [:]
                        var tokens = 0
                        for (detail, fallback) in [("input", "inputTokens"), ("output", "outputTokens"), ("cache_read", "cacheReadTokens"), ("cache_write", "cacheWriteTokens")] {
                            let nested = details[detail] as? [String: Any]
                            let amount = (nested?["tokenCount"] as? NSNumber)?.intValue ?? (usage[fallback] as? NSNumber)?.intValue ?? 0
                            tokens += max(0, min(1_000_000_000_000, amount))
                        }
                        tokens += max(0, min(1_000_000_000_000, (usage["reasoningTokens"] as? NSNumber)?.intValue ?? 0))
                        let key = session + "|" + model
                        // Replayed shutdown checkpoints and resumed sessions must not double count.
                        let previous = snapshots[key] ?? 0
                        if tokens > previous { result.models[model, default: 0] += tokens - previous; snapshots[key] = tokens }
                    }
                }
                if isRoot { result.activityLive = false }
            default: break
            }
            if isRoot, result.newest.map({ date >= $0 }) ?? true { result.newest = date }
        }
        return result
    }
}

public struct CodexHome: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var label: String
    public var path: String
    public init(id: UUID = UUID(), label: String, path: String) { self.id = id; self.label = label; self.path = path }
}

public enum CodexHomes {
    /// The default root remains present. Explicit and environment roots are deduplicated by canonical path.
    public static func resolved(home: URL, environmentHome: String?, additional: [CodexHome]) -> [(label: String, sessions: URL)] {
        var candidates = [("Standard", home.appending(path: ".codex"))]
        if let environmentHome, !environmentHome.isEmpty, environmentHome.hasPrefix("/") {
            candidates.append(("CODEX_HOME", URL(fileURLWithPath: environmentHome, isDirectory: true)))
        }
        candidates += additional.filter { $0.path.hasPrefix("/") }.map { ($0.label.isEmpty ? "Codex" : $0.label, URL(fileURLWithPath: $0.path, isDirectory: true)) }
        var seen: Set<String> = []
        return candidates.compactMap { label, root in
            let sessions = (root.lastPathComponent == "sessions" ? root : root.appending(path: "sessions"))
                .standardizedFileURL.resolvingSymlinksInPath()
            guard seen.insert(sessions.path).inserted else { return nil }
            return (label, sessions)
        }
    }
}
