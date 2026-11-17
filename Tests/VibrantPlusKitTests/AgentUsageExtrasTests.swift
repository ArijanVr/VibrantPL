// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import Foundation
@testable import VibrantPlusKit

struct AgentUsageExtrasTests {
    @Test func copilotShutdownSnapshotsDoNotDoubleCount() throws {
        let lines = [
            #"{"id":"start","type":"session.start","timestamp":"2026-11-17T10:00:00Z","data":{"sessionId":"test","context":{"cwd":"/tmp/project"}}}"#,
            #"{"id":"a","type":"session.shutdown","timestamp":"2026-11-17T10:01:00Z","data":{"modelMetrics":{"model-a":{"usage":{"inputTokens":100,"outputTokens":20}}}}}"#,
            #"{"id":"b","type":"session.shutdown","timestamp":"2026-11-17T10:02:00Z","data":{"modelMetrics":{"model-a":{"tokenDetails":{"input":{"tokenCount":130},"output":{"tokenCount":30}}}}}}"#,
            #"{"id":"a","type":"session.shutdown","timestamp":"2026-11-17T10:01:00Z","data":{"modelMetrics":{"model-a":{"usage":{"inputTokens":100,"outputTokens":20}}}}}"#
        ].joined(separator: "\n")
        let result = CopilotUsage.scan(data: Data(lines.utf8), modified: .now)
        #expect(result.models["model-a"] == 160)
        #expect(result.detail == "/tmp/project")
        #expect(result.activityLive == false)
    }
    @Test func toolOutputAndSubagentsCannotForgeRootActivity() {
        let lines = [
            #"{"type":"session.start","data":{"context":{"cwd":"/tmp/root"}}}"#,
            #"{"type":"assistant.turn_start","data":{}}"#,
            #"{"type":"tool.execution_complete","data":{"output":{"type":"session.shutdown","data":{"modelMetrics":{"fake":{"usage":{"inputTokens":999999}}}}}}}"#,
            #"{"type":"session.context_changed","data":{"agentId":"sub","cwd":"/tmp/sub"}}"#,
            #"{"type":"assistant.turn_end","data":{"agentId":"sub"}}"#
        ].joined(separator: "\n")
        let scan = CopilotUsage.scan(data: Data(lines.utf8), modified: .now)
        #expect(scan.models.isEmpty)
        #expect(scan.detail == "/tmp/root")
        #expect(scan.activityLive == true)
    }
    @Test func codexRootsDeduplicateEquivalentLocations() {
        let home = URL(fileURLWithPath: "/tmp/test-home", isDirectory: true)
        let roots = CodexHomes.resolved(home: home, environmentHome: "/tmp/test-home/.codex", additional: [
            CodexHome(label: "Duplikat", path: "/tmp/test-home/.codex/sessions"),
            CodexHome(label: "Arbeit", path: "/tmp/work-codex"),
            CodexHome(label: "Ungültig", path: "relative")
        ])
        #expect(roots.count == 2)
        #expect(roots[1].label == "Arbeit")
        #expect(roots[1].sessions.path == "/tmp/work-codex/sessions" || roots[1].sessions.path == "/private/tmp/work-codex/sessions")
    }
    @Test func quotasHaveIndependentAccountIdentities() {
        let first = UsageQuota(provider: .codex, window: "5 h", usedPercent: 10, resets: nil, account: "Privat")
        let second = UsageQuota(provider: .codex, window: "5 h", usedPercent: 20, resets: nil, account: "Arbeit")
        #expect(first.id != second.id)
    }
}
