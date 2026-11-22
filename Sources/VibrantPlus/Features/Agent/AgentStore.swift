// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Observation
import VibrantPlusKit

/// Claude Code sessions, pending permission requests and questions.
@Observable
final class AgentStore {
    static let shared = AgentStore()

    struct Pending: Identifiable {
        let id: String
        let event: HookEvent
        let received: Date
        let expires: Date
        let respond: @Sendable (HookReply) -> Void

        var questions: [AgentQuestion] { AgentQuestion.parse(event.toolInput) }
        /// Everything the card shows, in full: command, path, URL or tool input.
        var permission: PermissionDetail { PermissionDetail(tool: event.toolName ?? "", input: event.toolInput) }
    }

    private(set) var sessions: [String: AgentSession] = [:]
    private(set) var pending: [Pending] = []
    /// Files dropped "for Claude": they go with the next prompt.
    private(set) var filesForClaude: [URL] = []
    private(set) var history: [AgentHistoryEntry] = []
    private(set) var serverRunning = false
    private(set) var hooksInstalled = false
    /// Hooks are in settings.json but point at another copy of the app (moved, or a release copy).
    private(set) var hooksOutdated = false
    var lastError: String?
    /// Session -> the project folder it had when the person chose «Dateien automatisch», until the app quits.
    /// What that allows is decided by AutoAllowRules alone. The folder stays fixed: a later `cd` cannot widen it.
    private(set) var autoAllowRoots: [String: String] = [:]

    /// The folder «Dateien automatisch» would cover, when this request is one it may allow.
    func autoAllowRoot(for p: Pending) -> String? {
        guard p.event.eventName == "PermissionRequest", let root = p.event.cwd,
              AutoAllowRules.mayAllow(tool: p.event.toolName, input: p.event.toolInput, root: root) else { return nil }
        return root
    }

    func startAutoAllow(_ p: Pending) {
        guard let root = autoAllowRoot(for: p) else { return }
        autoAllowRoots[p.event.sessionID] = root
        answer(p, .allow)
    }

    func stopAutoAllow(for sessionID: String) {
        autoAllowRoots[sessionID] = nil
    }

    /// Called when something needs the person (opens the island).
    @ObservationIgnored var onAttention: (() -> Void)?
    /// Called when the last pending request is gone (answered, sent back or expired): the island
    /// can fold away what the request opened.
    @ObservationIgnored var onPendingEmpty: (() -> Void)?
    @ObservationIgnored private var server: AgentServer?
    @ObservationIgnored private var expiryTimer: Timer?

    var sortedSessions: [AgentSession] {
        sessions.values.filter { $0.status != .ended }.sorted { $0.updated > $1.updated }
    }

    /// The session to show in the notch: one that waits on the person, else the busiest.
    var headline: AgentSession? {
        sortedSessions.first { $0.status == .needsPermission || $0.status == .asking }
            ?? sortedSessions.first { $0.status == .working }
            ?? sortedSessions.first
    }

    var isWorking: Bool { sortedSessions.contains { $0.status == .working } }

    // MARK: Server

    func start() {
        guard server == nil else { return }
        Paths.ensureDataDirectory()
        history = JSONFile<[AgentHistoryEntry]>(url: Paths.agentHistory).load() ?? []
        let s = AgentServer(path: Paths.agentSocket.path) { [weak self] request, respond in
            self?.receive(request, respond: respond)
        }
        serverRunning = s.start()
        server = serverRunning ? s : nil
        if !serverRunning { lastError = "Der Agent-Socket konnte nicht geöffnet werden." }
        refreshHookStatus()
        refreshCodexStatus()
        expiryTimer = Timer.repeating(every: 2) { [weak self] _ in
            MainActor.assumeIsolated { self?.expirePending() }
        }
    }

    func stop() {
        server?.stop()
        server = nil
        serverRunning = false
        expiryTimer?.invalidate()
        expiryTimer = nil
        for p in pending { p.respond(.none) }
        pending = []
        pendingChanged()
    }

    func receive(_ request: HookRequest, respond: @escaping @Sendable (HookReply) -> Void) {
        let event = request.event
        AgentReducer.apply(event, to: &sessions)

        if event.eventName == "UserPromptSubmit" {
            // The dropped files belong to Claude Code's next prompt, never to Codex's.
            let context = event.isCodex || filesForClaude.isEmpty ? nil :
                "Vom Benutzer für diese Nachricht bereitgelegte Dateien:\n" + filesForClaude.map(\.path).joined(separator: "\n")
            if !event.isCodex { filesForClaude = [] }
            respond(HookReply(action: .none, context: context))
            return
        }

        if request.wait, event.eventName == "PermissionRequest", let root = autoAllowRoots[event.sessionID],
           AutoAllowRules.mayAllow(tool: event.toolName, input: event.toolInput, root: root) {
            respond(HookReply(action: .allow))
            AgentReducer.resolved(event.sessionID, in: &sessions)
            return
        }
        if request.wait && event.needsAnswer {
            let timeout: TimeInterval = event.isQuestion ? 105 : 50
            pending.append(Pending(id: request.id, event: event, received: .now,
                                   expires: .now.addingTimeInterval(timeout), respond: respond))
            playSound()
            onAttention?()
            let project = sessions[event.sessionID]?.projectName ?? "Claude Code"
            let line = event.isQuestion
                         ? "\(event.agentName) fragt in \(project). Antworten in der Insel."
                         : "\(event.agentName) möchte in \(project): \(PermissionDetail(tool: event.toolName ?? "", input: event.toolInput).title). Befehl+Return erlaubt, Escape lehnt ab."
            Announce.say(line, urgent: true)
            PulsiVoice.shared.say(line)
            return
        }
        respond(.none)
        if event.eventName == "Stop" {
            playSound()
            finishTurn(event.sessionID)
        }
    }

    /// A turn ended: read the tokens from the transcript, write the history, and say so
    /// in the notch when it took a while.
    private func finishTurn(_ sessionID: String) {
        guard let s = sessions[sessionID] else { return }
        PulsiVoice.shared.say(PulsiLines.agentDone(project: s.projectName))
        if AgentHistory.isLong(s.lastTurn), let d = s.lastTurn {
            IslandModel.shared.show(Toast(symbol: "checkmark.circle", text: "\(s.projectName): fertig nach \(AgentHistory.durationText(d))"), seconds: 8)
        }
        let path = s.transcriptPath
        Task.detached(priority: .utility) {
            let usage = path.map { Self.readUsage(path: $0) } ?? TokenUsage()
            await MainActor.run { self.record(sessionID, usage: usage) }
        }
    }

    private func record(_ sessionID: String, usage: TokenUsage) {
        guard var s = sessions[sessionID] else { return }
        if usage.total > 0 { s.usage = usage }
        sessions[sessionID] = s
        history = AgentHistory.adding(AgentHistoryEntry(session: s, date: .now), to: history)
        SaveReport.attempt("Claude-Verlauf") { try JSONFile<[AgentHistoryEntry]>(url: Paths.agentHistory).save(history) }
    }

    /// Reads at most the last 16 MB of the transcript.
    nonisolated static func readUsage(path: String) -> TokenUsage {
        guard path.hasSuffix(".jsonl"), let h = FileHandle(forReadingAtPath: path) else { return TokenUsage() }
        defer { try? h.close() }
        let size = (try? h.seekToEnd()) ?? 0
        let limit: UInt64 = 16 << 20
        try? h.seek(toOffset: size > limit ? size - limit : 0)
        guard var data = try? h.readToEnd() else { return TokenUsage() }
        // A cut file starts mid-line: drop the first partial line.
        if size > limit, let nl = data.firstIndex(of: 0x0A) { data = data[data.index(after: nl)...] }
        return TokenUsage.parse(transcript: data)
    }

    func clearHistory() {
        history = []
        try? FileManager.default.removeItem(at: Paths.agentHistory)
    }

    func answer(_ p: Pending, _ action: HookReply.Action, answers: [String: String]? = nil) {
        p.respond(HookReply(action: action, answers: answers))
        pending.removeAll { $0.id == p.id }
        AgentReducer.resolved(p.event.sessionID, in: &sessions)
        pendingChanged()
    }

    /// Lets the terminal ask instead.
    func answerInTerminal(_ p: Pending) {
        p.respond(.none)
        pending.removeAll { $0.id == p.id }
        pendingChanged()
    }

    private func expirePending() {
        let now = Date.now
        for p in pending where p.expires <= now { p.respond(.none) }
        pending.removeAll { $0.expires <= now }
        AgentReducer.prune(&sessions, now: now)
        pendingChanged()
    }

    /// Every path that empties the queue reports it in one place.
    private func pendingChanged() {
        guard pending.isEmpty else { return }
        onPendingEmpty?()
    }

    func addFilesForClaude(_ urls: [URL]) {
        for u in urls where !filesForClaude.contains(u) { filesForClaude.append(u) }
    }

    func removeFileForClaude(_ url: URL) { filesForClaude.removeAll { $0 == url } }

    func clearEnded() { sessions = sessions.filter { $0.value.status != .ended } }

    private func playSound() {
        guard Prefs.shared.agentSound else { return }
        NSSound(named: NSSound.Name(Prefs.shared.agentSoundName))?.play()
    }

    // MARK: Hooks in ~/.claude/settings.json

    func refreshHookStatus() {
        let settings = (try? ClaudeHooks.read(Paths.claudeSettings)) ?? [:]
        hooksInstalled = ClaudeHooks.isInstalled(in: settings)
        hooksOutdated = hooksInstalled && !ClaudeHooks.pointsAt(Paths.executable, in: settings)
    }

    // MARK: Codex

    private(set) var codexInstalled = false
    private(set) var codexOutdated = false
    var codexError: String?

    func refreshCodexStatus() {
        let file = (try? ClaudeHooks.read(Paths.codexHooks)) ?? [:]
        codexInstalled = CodexHooks.isInstalled(in: file)
        codexOutdated = codexInstalled && !CodexHooks.pointsAt(Paths.executable, in: file)
    }

    func installCodexHooks() {
        do {
            let current = try ClaudeHooks.read(Paths.codexHooks)
            try ClaudeHooks.write(try CodexHooks.install(into: current, executable: Paths.executable), to: Paths.codexHooks)
            codexError = nil
        } catch {
            codexError = "hooks.json hat eine unerwartete Form und wurde nicht verändert."
        }
        refreshCodexStatus()
    }

    func removeCodexHooks() {
        do {
            let current = try ClaudeHooks.read(Paths.codexHooks)
            try ClaudeHooks.write(try CodexHooks.remove(from: current), to: Paths.codexHooks)
            codexError = nil
        } catch {
            codexError = "hooks.json hat eine unerwartete Form und wurde nicht verändert."
        }
        refreshCodexStatus()
    }

    func installHooks() {
        do {
            let current = try ClaudeHooks.read(Paths.claudeSettings)
            try ClaudeHooks.write(try ClaudeHooks.install(into: current, executable: Paths.executable), to: Paths.claudeSettings)
            lastError = nil
        } catch {
            lastError = "settings.json hat eine unerwartete Form und wurde nicht verändert."
        }
        refreshHookStatus()
    }

    func removeHooks() {
        do {
            let current = try ClaudeHooks.read(Paths.claudeSettings)
            try ClaudeHooks.write(try ClaudeHooks.remove(from: current), to: Paths.claudeSettings)
            lastError = nil
        } catch {
            lastError = "settings.json hat eine unerwartete Form und wurde nicht verändert."
        }
        refreshHookStatus()
    }

    /// For snapshots and the self-test.
    func loadSample() {
        hooksInstalled = true
        let t = Date.now
        AgentReducer.apply(HookEvent(sessionID: "demo", eventName: "UserPromptSubmit", cwd: "/Users/demo/Projekte/vibrant",
                                     prompt: "Füge einen Dunkelmodus-Schalter hinzu"), to: &sessions, now: t)
        AgentReducer.apply(HookEvent(sessionID: "demo", eventName: "PostToolUse", toolName: "Read",
                                     toolInput: .object(["file_path": .string("/p/Settings.swift")])), to: &sessions, now: t)
        AgentReducer.apply(HookEvent(sessionID: "demo", eventName: "PostToolUse", toolName: "Edit",
                                     toolInput: .object(["file_path": .string("/p/Settings.swift"),
                                                         "old_string": .string("Toggle(\"Ton\", isOn: $sound)"),
                                                         "new_string": .string("Toggle(\"Ton\", isOn: $sound)\nToggle(\"Dunkel\", isOn: $dark)")])),
                           to: &sessions, now: t)
        AgentReducer.apply(HookEvent(sessionID: "demo", eventName: "PreToolUse", toolName: "Bash",
                                     toolInput: .object(["command": .string("swift test")])), to: &sessions, now: t)
    }

    /// Permission requests for snapshots (`count` > 1: a queue): answering them does nothing.
    func loadSamplePending(question: Bool = false, count: Int = 1) {
        let event: HookEvent
        if question {
            event = HookEvent(sessionID: "demo", eventName: "PreToolUse", toolName: "AskUserQuestion",
                              toolInput: .object(["questions": .array([.object([
                                  "question": .string("Welche Datenbank soll ich verwenden?"), "header": .string("DB"),
                                  "options": .array([.object(["label": .string("SQLite")]), .object(["label": .string("SwiftData")]),
                                                     .object(["label": .string("JSON-Dateien")])]),
                                  "multiSelect": .bool(false)])])]))
        } else {
            event = HookEvent(sessionID: "demo", eventName: "PermissionRequest", toolName: "Bash",
                              toolInput: .object(["command": .string("rm -rf .build && swift build"),
                                                  "description": .string("Build-Ordner löschen und neu bauen")]),
                              permissionSuggestions: .array([.object([
                                  "type": .string("addRules"), "behavior": .string("allow"), "destination": .string("localSettings"),
                                  "rules": .array([.object(["toolName": .string("Bash"), "ruleContent": .string("swift build:*")])])])]))
        }
        AgentReducer.apply(event, to: &sessions)
        pending = (0..<max(1, count)).map { _ in Pending(id: UUID().uuidString, event: event, received: .now, expires: .now.addingTimeInterval(50)) { _ in } }
    }

    func clearSample() {
        pending = []
        sessions = [:]
    }
}
