// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// One event that Claude Code passes to a command hook on stdin.
/// Field names follow the public Claude Code hooks reference.
public struct HookEvent: Codable, Sendable, Equatable {
    public var sessionID: String
    public var eventName: String
    public var cwd: String?
    public var transcriptPath: String?
    public var toolName: String?
    public var toolInput: JSONValue?
    public var toolResponse: JSONValue?
    public var prompt: String?
    public var message: String?
    public var permissionSuggestions: JSONValue?
    /// Which tool sent the event: nil for Claude Code, "codex" for Codex.
    public var agent: String?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case eventName = "hook_event_name"
        case cwd
        case transcriptPath = "transcript_path"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case toolResponse = "tool_response"
        case prompt
        case message
        case permissionSuggestions = "permission_suggestions"
        case agent
    }

    public init(sessionID: String, eventName: String, cwd: String? = nil, transcriptPath: String? = nil, toolName: String? = nil,
                toolInput: JSONValue? = nil, toolResponse: JSONValue? = nil, prompt: String? = nil,
                message: String? = nil, permissionSuggestions: JSONValue? = nil, agent: String? = nil) {
        self.sessionID = sessionID
        self.eventName = eventName
        self.cwd = cwd
        self.transcriptPath = transcriptPath
        self.toolName = toolName
        self.toolInput = toolInput
        self.toolResponse = toolResponse
        self.prompt = prompt
        self.message = message
        self.permissionSuggestions = permissionSuggestions
        self.agent = agent
    }

    /// True when the hook should wait for an answer from the person:
    /// a permission request, or a question Claude asks with AskUserQuestion.
    public var needsAnswer: Bool {
        if eventName == "PermissionRequest" { return true }
        return isQuestion
    }

    public var isCodex: Bool { agent == "codex" }

    /// "Claude" or "Codex", for the words on the island.
    public var agentName: String { isCodex ? "Codex" : "Claude" }

    public var isQuestion: Bool {
        eventName == "PreToolUse" && toolName == "AskUserQuestion"
    }

    /// Claude Code offers "always allow" only when it sends suggestions.
    public var offersAlways: Bool {
        guard let s = permissionSuggestions?.array else { return false }
        return !s.isEmpty
    }
}

/// What travels from the hook process to the app over the socket: one JSON line.
public struct HookRequest: Codable, Sendable {
    public var id: String
    public var wait: Bool
    public var event: HookEvent

    public init(id: String = UUID().uuidString, wait: Bool, event: HookEvent) {
        self.id = id
        self.wait = wait
        self.event = event
    }
}

/// What the app answers. One JSON line.
public struct HookReply: Codable, Sendable, Equatable {
    public enum Action: String, Codable, Sendable {
        /// Nothing to say: Claude Code continues as without the hook.
        case none
        case allow
        case always
        case deny
        /// Answers to AskUserQuestion: question text -> chosen label(s).
        case answer
    }

    public var action: Action
    public var answers: [String: String]?
    /// Extra text for the next prompt (files dropped for Claude).
    public var context: String?

    public init(action: Action, answers: [String: String]? = nil, context: String? = nil) {
        self.action = action
        self.answers = answers
        self.context = context
    }

    public static let none = HookReply(action: .none)
}

/// Builds the JSON the hook prints on stdout for Claude Code.
public enum HookOutput {
    public static let denyMessage = "Abgelehnt in Vibrant+."

    /// nil means: print nothing, Claude Code decides as usual (asks in the terminal).
    public static func json(for event: HookEvent, reply: HookReply) -> String? {
        var output: [String: Any]?
        switch (event.eventName, reply.action) {
        case ("PermissionRequest", .allow), ("PermissionRequest", .always):
            var decision: [String: Any] = ["behavior": "allow"]
            if reply.action == .always, let s = event.permissionSuggestions, event.offersAlways {
                decision["updatedPermissions"] = s.foundation
            }
            output = ["hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": decision]]
        case ("PermissionRequest", .deny):
            output = ["hookSpecificOutput": ["hookEventName": "PermissionRequest",
                                             "decision": ["behavior": "deny", "message": denyMessage]]]
        case ("PreToolUse", .answer) where event.isQuestion:
            var input = event.toolInput?.object ?? [:]
            input["answers"] = .object((reply.answers ?? [:]).mapValues { .string($0) })
            output = ["hookSpecificOutput": ["hookEventName": "PreToolUse",
                                             "permissionDecision": "allow",
                                             "updatedInput": JSONValue.object(input).foundation]]
        case ("UserPromptSubmit", _):
            if let context = reply.context, !context.isEmpty {
                output = ["hookSpecificOutput": ["hookEventName": "UserPromptSubmit",
                                                 "additionalContext": context]]
            }
        default:
            output = nil
        }
        guard let output,
              let data = try? JSONSerialization.data(withJSONObject: output, options: [.sortedKeys, .withoutEscapingSlashes]) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}

/// Questions inside an AskUserQuestion tool input.
public struct AgentQuestion: Sendable, Equatable, Identifiable {
    public var id: String { question }
    public var question: String
    public var header: String
    public var options: [String]
    public var multiSelect: Bool
    /// Option label -> the explanation Claude gave for it (may be missing).
    public var descriptions: [String: String] = [:]

    public static func parse(_ input: JSONValue?) -> [AgentQuestion] {
        guard let list = input?["questions"]?.array else { return [] }
        return list.compactMap { q in
            guard let text = q["question"]?.string else { return nil }
            var descriptions: [String: String] = [:]
            let options = (q["options"]?.array ?? []).compactMap { o -> String? in
                guard let label = o["label"]?.string ?? o.string else { return nil }
                if let d = o["description"]?.string, !d.isEmpty { descriptions[label] = d }
                return label
            }
            return AgentQuestion(question: text, header: q["header"]?.string ?? "",
                                 options: options, multiSelect: q["multiSelect"]?.bool ?? false,
                                 descriptions: descriptions)
        }
    }

    /// The answer text for the chosen labels: one label, or several in the order Claude
    /// offered them, separated by ", " (how Claude Code reads a multi-select answer).
    public func answer(_ chosen: Set<String>) -> String {
        options.filter(chosen.contains).joined(separator: ", ")
    }
}
