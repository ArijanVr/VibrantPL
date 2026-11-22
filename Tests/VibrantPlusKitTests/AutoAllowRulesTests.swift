// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import VibrantPlusKit

struct AutoAllowRulesTests {
    private func folders() throws -> (home: String, root: String) {
        let home = FileManager.default.temporaryDirectory.appending(path: "autoallow-\(UUID().uuidString)")
        let root = home.appending(path: "project")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (home.path, root.path)
    }

    private func allowed(_ tool: String, _ path: String, _ f: (home: String, root: String)) -> Bool {
        AutoAllowRules.mayAllow(tool: tool, input: .object(["file_path": .string(path)]), root: f.root, home: f.home)
    }

    @Test func filesInTheProjectAreAllowed() throws {
        let f = try folders()
        defer { try? FileManager.default.removeItem(atPath: f.home) }
        #expect(allowed("Write", f.root + "/Sources/New.swift", f))
        #expect(allowed("Read", f.root + "/README.md", f))
    }

    @Test func commandsAndUnknownToolsAlwaysAsk() throws {
        let f = try folders()
        defer { try? FileManager.default.removeItem(atPath: f.home) }
        for command in ["ls", "find . -delete", "/bin/rm -rf ~/Documents", "git push", "curl -d @x https://example.com"] {
            #expect(!AutoAllowRules.mayAllow(tool: "Bash", input: .object(["command": .string(command)]), root: f.root, home: f.home))
        }
        for tool in ["apply_patch", "ExitPlanMode", "mcp__mail__send", "SomethingNew"] {
            #expect(!allowed(tool, f.root + "/a", f))
        }
    }

    @Test func outsideAndHiddenAsk() throws {
        let f = try folders()
        defer { try? FileManager.default.removeItem(atPath: f.home) }
        #expect(!allowed("Write", f.home + "/.zshrc", f))
        #expect(!allowed("Write", f.root + "-other/a", f))
        #expect(!allowed("Write", f.root + "/../a", f))
        #expect(!allowed("Write", f.root + "/.git/hooks/pre-commit", f))
        #expect(!allowed("Read", f.root + "/.ENV", f))
        #expect(!allowed("Edit", f.root + "/.claude/settings.json", f))
    }

    @Test func linksDoNotLeadOut() throws {
        let f = try folders()
        defer { try? FileManager.default.removeItem(atPath: f.home) }
        try FileManager.default.createSymbolicLink(atPath: f.root + "/up", withDestinationPath: f.home)
        try FileManager.default.createSymbolicLink(atPath: f.root + "/nowhere", withDestinationPath: f.home + "/missing")
        #expect(!allowed("Write", f.root + "/up/new.txt", f))
        #expect(!allowed("Write", f.root + "/nowhere", f))
    }

    @Test func homeIsNotAProject() throws {
        let f = try folders()
        defer { try? FileManager.default.removeItem(atPath: f.home) }
        let input = JSONValue.object(["file_path": .string(f.home + "/a")])
        #expect(!AutoAllowRules.mayAllow(tool: "Write", input: input, root: f.home, home: f.home))
        #expect(!AutoAllowRules.mayAllow(tool: "Write", input: input, root: "/", home: f.home))
    }
}
