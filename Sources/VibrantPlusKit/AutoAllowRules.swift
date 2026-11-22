// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// What «Dateien automatisch» may allow without asking. A list of dangerous commands can never be
/// complete, so this is the other way round: only named file tools, only inside the project folder.
/// Commands, patches, plans, MCP and every tool not named here always ask.
public enum AutoAllowRules {
    static let fileTools: Set<String> = ["Read", "Write", "Edit", "MultiEdit", "NotebookEdit"]

    public static func mayAllow(tool: String?, input: JSONValue?, root: String,
                                home: String = NSHomeDirectory()) -> Bool {
        guard let tool, fileTools.contains(tool),
              let path = input?["file_path"]?.string ?? input?["notebook_path"]?.string,
              path.hasPrefix("/"), root.hasPrefix("/"),
              // «..» after a symlink does not mean what it reads as.
              !path.split(separator: "/").contains(".."),
              let base = canonical(root), let target = canonical(path), let homeFolder = canonical(home) else { return false }
        // A project is never the whole disk, the home folder, or a folder above it.
        guard base != "/", !(homeFolder.lowercased() + "/").hasPrefix(base.lowercased() + "/"),
              target.hasPrefix(base + "/") else { return false }
        // Hidden files and folders hold keys, hooks and agent settings (.env, .git, .claude, .codex).
        // Lower case: the file system usually does not tell the difference.
        let inside = target.dropFirst(base.count + 1).lowercased().split(separator: "/")
        return !inside.contains { $0.hasPrefix(".") }
    }

    /// The path with every symlink resolved, also for a file that does not exist yet.
    /// nil for a link that leads nowhere: writing through it would create a file somewhere else.
    static func canonical(_ path: String) -> String? {
        if let resolved = realpath(path, nil) {
            defer { free(resolved) }
            return String(cString: resolved)
        }
        guard errno == ENOENT, path != "/",
              (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) == nil else { return nil }
        let url = URL(fileURLWithPath: path)
        guard let parent = canonical(url.deletingLastPathComponent().path) else { return nil }
        return (parent == "/" ? "" : parent) + "/" + url.lastPathComponent
    }
}
