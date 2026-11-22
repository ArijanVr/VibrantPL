// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Adds and removes Vibrant+'s hooks in Codex's user hook file (`~/.codex/hooks.json`), touching nothing else.
/// Codex runs hook commands with one JSON object on stdin, like Claude Code. Codex asks the person to review
/// and trust a new hook once (`/hooks` in the Codex CLI), so the connection works only after that.
public enum CodexHooks {
    /// Events the island uses: sessions, tools, permission requests (the island answers them), turn end.
    /// No matcher: every tool matches.
    public static let events: [(name: String, timeout: Int)] = [
        ("SessionStart", 10),
        ("UserPromptSubmit", 10),
        ("PreToolUse", 10),
        ("PermissionRequest", 60),
        ("PostToolUse", 10),
        ("Stop", 10),
        ("SessionEnd", 3),
    ]

    public static func command(executable: String) -> String { "\"\(executable)\" --hook --codex" }

    public static func isOurs(_ command: String) -> Bool {
        command.contains("VibrantPlus") && command.hasSuffix("--hook --codex")
    }

    public static func isInstalled(in file: [String: Any]) -> Bool {
        guard let hooks = file["hooks"] as? [String: Any] else { return false }
        return events.allSatisfy { event in
            ((hooks[event.name] as? [[String: Any]]) ?? []).contains { group in
                ((group["hooks"] as? [[String: Any]]) ?? []).contains { isOurs($0["command"] as? String ?? "") }
            }
        }
    }

    public static func pointsAt(_ executable: String, in file: [String: Any]) -> Bool {
        guard let hooks = file["hooks"] as? [String: Any] else { return false }
        let ours = hooks.values.compactMap { $0 as? [[String: Any]] }.joined()
            .flatMap { ($0["hooks"] as? [[String: Any]]) ?? [] }
            .compactMap { $0["command"] as? String }
            .filter(isOurs)
        return !ours.isEmpty && ours.allSatisfy { $0 == command(executable: executable) }
    }

    public static func install(into file: [String: Any], executable: String) throws -> [String: Any] {
        var file = try remove(from: file)
        var hooks = file["hooks"] as? [String: Any] ?? [:]
        let cmd = command(executable: executable)
        for event in events {
            var groups = hooks[event.name] as? [[String: Any]] ?? []
            groups.append(["hooks": [["type": "command", "command": cmd, "timeout": event.timeout]]])
            hooks[event.name] = groups
        }
        file["hooks"] = hooks
        return file
    }

    public static func remove(from file: [String: Any]) throws -> [String: Any] {
        var file = file
        guard let raw = file["hooks"] else { return file }
        guard var hooks = raw as? [String: Any] else { throw ClaudeHooks.Failure.unexpectedHooksShape }
        for (name, value) in hooks {
            guard let groups = value as? [[String: Any]] else { continue }
            var kept: [[String: Any]] = []
            for var group in groups {
                let list = (group["hooks"] as? [[String: Any]]) ?? []
                let filtered = list.filter { !isOurs($0["command"] as? String ?? "") }
                if filtered.isEmpty && !list.isEmpty { continue }
                group["hooks"] = filtered
                kept.append(group)
            }
            if kept.isEmpty { hooks.removeValue(forKey: name) } else { hooks[name] = kept }
        }
        if hooks.isEmpty { file.removeValue(forKey: "hooks") } else { file["hooks"] = hooks }
        return file
    }
}
