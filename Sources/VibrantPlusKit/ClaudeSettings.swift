// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Adds and removes Vibrant+'s hooks in Claude Code's settings.json
/// (`~/.claude/settings.json`), touching nothing else in the file.
public enum ClaudeHooks {
    public enum Failure: Error, Equatable {
        case notJSONObject
        case unexpectedHooksShape
    }

    /// Event name -> (matcher, timeout in seconds). nil matcher: event without tools.
    public static let events: [(name: String, matcher: String?, timeout: Int)] = [
        ("SessionStart", nil, 10),
        ("UserPromptSubmit", nil, 10),
        ("PreToolUse", "*", 120),
        ("PostToolUse", "*", 10),
        ("PermissionRequest", "*", 60),
        ("Notification", nil, 10),
        ("Stop", nil, 10),
        ("SessionEnd", nil, 10),
    ]

    /// The shell command Claude Code runs. The path is quoted: it contains a space or '+'.
    public static func command(executable: String) -> String {
        "\"\(executable)\" --hook"
    }

    /// True for a hook command that Vibrant+ wrote (any install path).
    public static func isOurs(_ command: String) -> Bool {
        command.contains("VibrantPlus") && command.hasSuffix("--hook")
    }

    public static func isInstalled(in settings: [String: Any]) -> Bool {
        guard let hooks = settings["hooks"] as? [String: Any] else { return false }
        return events.allSatisfy { event in
            guard let groups = hooks[event.name] as? [[String: Any]] else { return false }
            return groups.contains { group in
                ((group["hooks"] as? [[String: Any]]) ?? []).contains { isOurs($0["command"] as? String ?? "") }
            }
        }
    }

    /// True when every Vibrant+ hook runs `executable`. False after the app was moved or a copy
    /// (another path) wrote the hooks: Claude Code would then call a file that is gone or not this app.
    public static func pointsAt(_ executable: String, in settings: [String: Any]) -> Bool {
        guard let hooks = settings["hooks"] as? [String: Any] else { return false }
        let wanted = command(executable: executable)
        let ours = hooks.values.compactMap { $0 as? [[String: Any]] }.joined()
            .flatMap { ($0["hooks"] as? [[String: Any]]) ?? [] }
            .compactMap { $0["command"] as? String }
            .filter(isOurs)
        return !ours.isEmpty && ours.allSatisfy { $0 == wanted }
    }

    /// Returns settings with Vibrant+'s hooks added (old Vibrant+ entries replaced).
    public static func install(into settings: [String: Any], executable: String) throws -> [String: Any] {
        var settings = try remove(from: settings)
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        let cmd = command(executable: executable)
        for event in events {
            var groups = hooks[event.name] as? [[String: Any]] ?? []
            var group: [String: Any] = ["hooks": [["type": "command", "command": cmd, "timeout": event.timeout]]]
            if let m = event.matcher { group["matcher"] = m }
            groups.append(group)
            hooks[event.name] = groups
        }
        settings["hooks"] = hooks
        return settings
    }

    /// Returns settings without any Vibrant+ hook. Groups and events left empty are dropped.
    public static func remove(from settings: [String: Any]) throws -> [String: Any] {
        var settings = settings
        guard let raw = settings["hooks"] else { return settings }
        guard var hooks = raw as? [String: Any] else { throw Failure.unexpectedHooksShape }
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
        if hooks.isEmpty { settings.removeValue(forKey: "hooks") } else { settings["hooks"] = hooks }
        return settings
    }

    /// Reads settings.json. A missing or empty file is an empty object.
    public static func read(_ url: URL) throws -> [String: Any] {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return [:] }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.notJSONObject }
        return obj
    }

    /// Writes settings.json atomically, after a one-time backup of the original.
    /// Nothing is written when the content would stay the same, so the file keeps the
    /// person's own formatting and key order unless Vibrant+ really changes something.
    public static func write(_ settings: [String: Any], to url: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path), let current = try? read(url),
           NSDictionary(dictionary: current).isEqual(to: settings) { return }
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let backup = url.deletingLastPathComponent().appending(path: url.lastPathComponent + ".vibrantplus-backup")
        if fm.fileExists(atPath: url.path), !fm.fileExists(atPath: backup.path) {
            try fm.copyItem(at: url, to: backup)
        }
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: url, options: .atomic)
    }
}
