// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Where Vibrant+ keeps its files. Everything stays on this Mac.
///   APP_DATA=/tmp/x VibrantPlus     use another folder (self-test, snapshots)
nonisolated enum Paths {
    static var dataDirectory: URL {
        if let custom = ProcessInfo.processInfo.environment["APP_DATA"], !custom.isEmpty {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        return URL.applicationSupportDirectory.appending(path: "VibrantPlus", directoryHint: .isDirectory)
    }

    static var isOverridden: Bool {
        !(ProcessInfo.processInfo.environment["APP_DATA"] ?? "").isEmpty
    }

    /// The Unix socket between the Claude Code hook and the app.
    static var agentSocket: URL { dataDirectory.appending(path: "agent.sock") }
    static var today: URL { dataDirectory.appending(path: "today.json") }
    static var layouts: URL { dataDirectory.appending(path: "layouts.json") }
    static var snippets: URL { dataDirectory.appending(path: "snippets.json") }
    static var agentHistory: URL { dataDirectory.appending(path: "agent-history.json") }
    static var pinnedClips: URL { dataDirectory.appending(path: "pinned-clips.json") }

    static var claudeSettings: URL {
        if let custom = ProcessInfo.processInfo.environment["APP_CLAUDE_SETTINGS"], !custom.isEmpty {
            return URL(fileURLWithPath: custom)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/settings.json")
    }

    /// The running binary: the hook command points here.
    static var executable: String {
        Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
    }

    static func ensureDataDirectory() {
        // Only this user may read the folder: it holds the agent socket.
        try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
    }
}
