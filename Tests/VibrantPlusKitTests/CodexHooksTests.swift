// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import VibrantPlusKit

struct CodexHooksTests {
    let exe = "/Applications/Vibrant+.app/Contents/MacOS/VibrantPlus"

    @Test func installsEveryEventAndKeepsForeignHooks() throws {
        let foreign: [String: Any] = ["hooks": ["Stop": [["hooks": [["type": "command", "command": "/usr/bin/true"]]]]]]
        let file = try CodexHooks.install(into: foreign, executable: exe)
        #expect(CodexHooks.isInstalled(in: file))
        #expect(CodexHooks.pointsAt(exe, in: file))
        let stop = (file["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        #expect(stop?.count == 2)
    }
    @Test func removeLeavesOnlyForeignHooks() throws {
        let foreign: [String: Any] = ["hooks": ["Stop": [["hooks": [["type": "command", "command": "/usr/bin/true"]]]]]]
        let removed = try CodexHooks.remove(from: try CodexHooks.install(into: foreign, executable: exe))
        #expect(!CodexHooks.isInstalled(in: removed))
        #expect(NSDictionary(dictionary: removed).isEqual(to: foreign))
    }
    @Test func installIsIdempotent() throws {
        let once = try CodexHooks.install(into: [:], executable: exe)
        let twice = try CodexHooks.install(into: once, executable: exe)
        #expect(NSDictionary(dictionary: once).isEqual(to: twice))
    }
    @Test func claudeAndCodexHooksDoNotTouchEachOther() throws {
        let claude = try ClaudeHooks.install(into: [:], executable: exe)
        #expect(!CodexHooks.isInstalled(in: claude))
        let codex = try CodexHooks.install(into: [:], executable: exe)
        #expect(!ClaudeHooks.isInstalled(in: codex))
        #expect(!CodexHooks.isOurs(ClaudeHooks.command(executable: exe)))
        #expect(!ClaudeHooks.isOurs(CodexHooks.command(executable: exe)))
    }
    @Test func codexPermissionPayloadDecodesAndAnswersAllow() throws {
        let json = #"{"session_id":"s1","turn_id":"t1","hook_event_name":"PermissionRequest","cwd":"/p","model":"x","tool_name":"Bash","tool_input":{"command":"ls","description":null}}"#
        var event = try JSONDecoder().decode(HookEvent.self, from: Data(json.utf8))
        event.agent = "codex"
        #expect(event.needsAnswer && event.isCodex && event.agentName == "Codex")
        let out = HookOutput.json(for: event, reply: HookReply(action: .allow))
        #expect(out?.contains("\"behavior\":\"allow\"") == true)
        #expect(out?.contains("updatedPermissions") == false)
    }
}
