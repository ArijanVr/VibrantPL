// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// One Claude Code session as Vibrant+ shows it.
public struct AgentSession: Codable, Sendable, Identifiable, Equatable {
    public enum Status: String, Codable, Sendable {
        case working
        case needsPermission
        case asking
        case waiting      // finished a turn, waiting for the next prompt
        case ended
    }

    public var id: String
    public var cwd: String
    public var prompt: String
    public var status: Status
    public var current: String
    public var steps: [AgentStep]
    public var files: [FileChange]
    public var started: Date
    public var updated: Date
    /// When the current turn (prompt) began, and how long the last one took.
    public var turnStart: Date?
    public var lastTurn: TimeInterval?
    public var turns: Int = 0
    public var usage: TokenUsage = TokenUsage()
    public var transcriptPath: String?

    public var projectName: String {
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? "Claude Code" : name
    }

    public init(id: String, cwd: String, now: Date) {
        self.id = id
        self.cwd = cwd
        prompt = ""
        status = .working
        current = ""
        steps = []
        files = []
        started = now
        updated = now
    }
}

public struct AgentStep: Codable, Sendable, Identifiable, Equatable {
    public enum Kind: String, Codable, Sendable {
        case prompt, read, edit, run, search, web, test, plan, agent, other, failed, done
    }

    public var id: UUID
    public var time: Date
    public var kind: Kind
    public var label: String
    /// The terminal view of a step: for a shell command the command and its output. Empty for other tools.
    public var detail: String

    public init(time: Date, kind: Kind, label: String, detail: String = "") {
        id = UUID()
        self.time = time
        self.kind = kind
        self.label = label
        self.detail = detail
    }

    public var symbol: String {
        switch kind {
        case .prompt: "text.bubble"
        case .read: "doc.text"
        case .edit: "pencil"
        case .run: "terminal"
        case .search: "magnifyingglass"
        case .web: "globe"
        case .test: "checkmark.seal"
        case .plan: "list.bullet"
        case .agent: "person.2"
        case .other: "circle.dotted"
        case .failed: "exclamationmark.triangle"
        case .done: "checkmark.circle"
        }
    }
}

/// A file Claude changed, with the text before and after when the tool said so.
public struct FileChange: Codable, Sendable, Identifiable, Equatable {
    public var id: String { path }
    public var path: String
    public var edits: Int
    public var oldText: String
    public var newText: String

    public var fileName: String { (path as NSString).lastPathComponent }
}

/// Turns hook events into session state. Pure, so tests can drive it.
public enum AgentReducer {
    public static let maxSteps = 60
    public static let maxDiffCharacters = 200_000
    /// Sessions without activity for this long leave the list.
    public static let keepFor: TimeInterval = 6 * 3600

    public static func apply(_ event: HookEvent, to sessions: inout [String: AgentSession], now: Date = .now) {
        var s = sessions[event.sessionID] ?? AgentSession(id: event.sessionID, cwd: event.cwd ?? "", now: now)
        if let cwd = event.cwd, !cwd.isEmpty { s.cwd = cwd }
        if let t = event.transcriptPath, !t.isEmpty { s.transcriptPath = t }
        s.updated = now

        switch event.eventName {
        case "SessionStart":
            s.status = .waiting
            s.current = "Bereit"
        case "UserPromptSubmit":
            s.turnStart = now
            s.turns += 1
            let text = short(event.prompt ?? "", 120)
            s.prompt = text
            s.status = .working
            s.current = "Denkt nach…"
            append(&s, AgentStep(time: now, kind: .prompt, label: text))
        case "PreToolUse":
            let (kind, label) = describe(tool: event.toolName ?? "", input: event.toolInput)
            if event.isQuestion {
                s.status = .asking
                s.current = "Stellt eine Frage"
            } else {
                s.status = .working
                s.current = label
                _ = kind
            }
        case "PostToolUse":
            let (kind, label) = describe(tool: event.toolName ?? "", input: event.toolInput)
            s.status = .working
            s.current = label
            append(&s, AgentStep(time: now, kind: kind, label: label,
                                 detail: terminalText(tool: event.toolName ?? "", input: event.toolInput, response: event.toolResponse)))
            recordChange(event, into: &s)
        case "PostToolUseFailure":
            let (_, label) = describe(tool: event.toolName ?? "", input: event.toolInput)
            append(&s, AgentStep(time: now, kind: .failed, label: label,
                                 detail: terminalText(tool: event.toolName ?? "", input: event.toolInput, response: event.toolResponse)))
        case "PermissionRequest":
            let (_, label) = describe(tool: event.toolName ?? "", input: event.toolInput)
            s.status = .needsPermission
            s.current = "Möchte: \(label)"
        case "Notification":
            if let m = event.message, !m.isEmpty { s.current = short(m, 80) }
        case "Stop", "SubagentStop":
            if event.eventName == "Stop" {
                if let start = s.turnStart { s.lastTurn = now.timeIntervalSince(start) }
                s.turnStart = nil
                s.status = .waiting
                s.current = "Wartet auf deine nächste Nachricht"
                append(&s, AgentStep(time: now, kind: .done, label: "Fertig"))
            }
        case "SessionEnd":
            s.status = .ended
            s.current = "Beendet"
        default:
            break
        }
        sessions[s.id] = s
        prune(&sessions, now: now)
    }

    /// After the person answered a permission card, the session works again.
    public static func resolved(_ sessionID: String, in sessions: inout [String: AgentSession], now: Date = .now) {
        guard var s = sessions[sessionID] else { return }
        if s.status == .needsPermission || s.status == .asking {
            s.status = .working
            s.current = "Weiter…"
            s.updated = now
            sessions[sessionID] = s
        }
    }

    public static func prune(_ sessions: inout [String: AgentSession], now: Date) {
        sessions = sessions.filter { now.timeIntervalSince($0.value.updated) < keepFor }
    }

    /// Tool + input -> kind and a short German label.
    public static func describe(tool: String, input: JSONValue?) -> (AgentStep.Kind, String) {
        let path = input?["file_path"]?.string ?? input?["notebook_path"]?.string ?? input?["path"]?.string
        let file = path.map { ($0 as NSString).lastPathComponent } ?? ""
        switch tool {
        case "Read": return (.read, "Liest \(file)")
        case "Edit", "MultiEdit", "NotebookEdit": return (.edit, "Bearbeitet \(file)")
        case "Write": return (.edit, "Schreibt \(file)")
        case "Bash":
            let cmd = input?["command"]?.string ?? ""
            if isTest(cmd) { return (.test, "Testet: \(short(cmd, 50))") }
            let desc = input?["description"]?.string
            return (.run, desc.map { short($0, 60) } ?? "Führt aus: \(short(cmd, 50))")
        case "Grep": return (.search, "Sucht «\(short(input?["pattern"]?.string ?? "", 40))»")
        case "Glob": return (.search, "Sucht Dateien \(short(input?["pattern"]?.string ?? "", 40))")
        case "WebSearch": return (.web, "Sucht im Web: \(short(input?["query"]?.string ?? "", 40))")
        case "WebFetch": return (.web, "Liest \(host(input?["url"]?.string))")
        case "TodoWrite": return (.plan, "Aktualisiert den Plan")
        case "Task", "Agent": return (.agent, "Agent: \(short(input?["description"]?.string ?? "", 50))")
        case "AskUserQuestion": return (.other, "Stellt eine Frage")
        default:
            if tool.hasPrefix("mcp__") {
                let name = tool.split(separator: "__").last.map(String.init) ?? tool
                return (.other, "Werkzeug \(name)")
            }
            return (.other, tool.isEmpty ? "Arbeitet" : tool)
        }
    }

    /// The most terminal text kept per step.
    public static let maxDetailCharacters = 4_000

    /// `$ command` and what it printed, for shell commands; empty for every other tool.
    public static func terminalText(tool: String, input: JSONValue?, response: JSONValue?) -> String {
        guard tool == "Bash", let command = input?["command"]?.string else { return "" }
        let output = response?.string ?? [response?["stdout"]?.string, response?["stderr"]?.string]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        let text = output.isEmpty ? "$ \(command)" : "$ \(command)\n\(output)"
        return String(text.prefix(maxDetailCharacters))
    }

    public static func isTest(_ command: String) -> Bool {
        let patterns = ["pytest", "jest", "vitest", "swift test", "xcodebuild test", "go test",
                        "cargo test", "npm test", "npm run test", "pnpm test", "yarn test", "bun test", "make test"]
        return patterns.contains { command.contains($0) }
    }

    static func recordChange(_ event: HookEvent, into s: inout AgentSession) {
        guard let tool = event.toolName, ["Edit", "MultiEdit", "Write"].contains(tool),
              let path = event.toolInput?["file_path"]?.string else { return }
        var oldText = ""
        var newText = ""
        switch tool {
        case "Edit":
            oldText = event.toolInput?["old_string"]?.string ?? ""
            newText = event.toolInput?["new_string"]?.string ?? ""
        case "MultiEdit":
            for e in event.toolInput?["edits"]?.array ?? [] {
                oldText += (e["old_string"]?.string ?? "") + "\n"
                newText += (e["new_string"]?.string ?? "") + "\n"
            }
        default:
            newText = event.toolInput?["content"]?.string ?? ""
        }
        oldText = String(oldText.prefix(maxDiffCharacters))
        newText = String(newText.prefix(maxDiffCharacters))
        if let i = s.files.firstIndex(where: { $0.path == path }) {
            s.files[i].edits += 1
            s.files[i].oldText = oldText
            s.files[i].newText = newText
        } else {
            s.files.append(FileChange(path: path, edits: 1, oldText: oldText, newText: newText))
        }
    }

    static func append(_ s: inout AgentSession, _ step: AgentStep) {
        s.steps.append(step)
        if s.steps.count > maxSteps { s.steps.removeFirst(s.steps.count - maxSteps) }
    }

    public static func short(_ text: String, _ n: Int) -> String {
        let t = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return t.count <= n ? t : String(t.prefix(n - 1)) + "…"
    }

    static func host(_ url: String?) -> String {
        guard let url, let h = URL(string: url)?.host() else { return "eine Webseite" }
        return h
    }
}

/// A simple line diff for the panel: lines only in old are removed, only in new are added.
public enum LineDiff {
    public enum Line: Equatable, Sendable {
        case same(String), removed(String), added(String)
    }

    /// Longest-common-subsequence diff. Inputs are capped to keep it fast.
    public static func lines(old: String, new: String, cap: Int = 600) -> [Line] {
        let a = Array(old.components(separatedBy: "\n").prefix(cap))
        let b = Array(new.components(separatedBy: "\n").prefix(cap))
        if a == [""] { return b.map { .added($0) } }
        let n = a.count, m = b.count
        var table = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                table[i][j] = a[i] == b[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }
        var out: [Line] = []
        var i = 0, j = 0
        while i < n && j < m {
            if a[i] == b[j] { out.append(.same(a[i])); i += 1; j += 1 }
            else if table[i + 1][j] >= table[i][j + 1] { out.append(.removed(a[i])); i += 1 }
            else { out.append(.added(b[j])); j += 1 }
        }
        while i < n { out.append(.removed(a[i])); i += 1 }
        while j < m { out.append(.added(b[j])); j += 1 }
        return out
    }
}

/// Tokens a session used, summed from Claude Code's transcript file.
public struct TokenUsage: Codable, Sendable, Equatable {
    public var input = 0
    public var output = 0
    public var cacheRead = 0
    public var cacheWrite = 0
    public var messages = 0

    public init() {}
    public var total: Int { input + output + cacheRead + cacheWrite }

    /// Reads a transcript (JSON lines). Claude Code writes a message several times while it
    /// streams, so only the last entry of each message id counts.
    public static func parse(transcript data: Data) -> TokenUsage {
        var last: [String: [String: Any]] = [:]
        var order: [String] = []
        var anon = 0
        for line in data.split(separator: 0x0A) {
            guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  obj["type"] as? String == "assistant",
                  let message = obj["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else { continue }
            let id = (message["id"] as? String) ?? { anon += 1; return "anon-\(anon)" }()
            if last[id] == nil { order.append(id) }
            last[id] = usage
        }
        var total = TokenUsage()
        for id in order {
            guard let u = last[id] else { continue }
            total.input += (u["input_tokens"] as? Int) ?? 0
            total.output += (u["output_tokens"] as? Int) ?? 0
            total.cacheRead += (u["cache_read_input_tokens"] as? Int) ?? 0
            total.cacheWrite += (u["cache_creation_input_tokens"] as? Int) ?? 0
            total.messages += 1
        }
        return total
    }

    /// "12,4 Tsd." / "1,2 Mio."
    public static func format(_ n: Int) -> String {
        switch n {
        case ..<1_000: return "\(n)"
        case ..<1_000_000: return String(format: "%.1f", Double(n) / 1_000).replacingOccurrences(of: ".", with: ",") + " Tsd."
        default: return String(format: "%.1f", Double(n) / 1_000_000).replacingOccurrences(of: ".", with: ",") + " Mio."
        }
    }
}

/// One finished turn in the history.
public struct AgentHistoryEntry: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var sessionID: String
    public var project: String
    public var prompt: String
    public var date: Date
    public var duration: TimeInterval
    public var files: [String]
    public var tokens: Int

    public init(session: AgentSession, date: Date) {
        id = UUID()
        sessionID = session.id
        project = session.projectName
        prompt = session.prompt
        self.date = date
        duration = session.lastTurn ?? 0
        files = session.files.map(\.fileName)
        tokens = session.usage.total
    }
}

public enum AgentHistory {
    public static let limit = 200

    /// Newest first, capped.
    public static func adding(_ entry: AgentHistoryEntry, to list: [AgentHistoryEntry]) -> [AgentHistoryEntry] {
        Array(([entry] + list).prefix(limit))
    }

    /// A finished turn that took long enough to deserve a note in the notch.
    public static func isLong(_ duration: TimeInterval?) -> Bool { (duration ?? 0) >= 120 }

    public static func durationText(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        if s < 60 { return "\(s) Sek." }
        if s < 3600 { return "\(s / 60) Min. \(s % 60) Sek." }
        return "\(s / 3600) Std. \((s % 3600) / 60) Min."
    }
}
