// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import VibrantPlusKit

struct SystemToolRulesTests {
    @Test func thermalLabelsStayInRange() {
        #expect(ThermalLabel.german(0) == "Normal")
        #expect(ThermalLabel.german(3) == "Kritisch")
        #expect(ThermalLabel.german(9) == "Unbekannt")
    }
    @Test func networkCountersCanResetWithoutNegativeTraffic() {
        let previous = NetworkTotals(received: 100, sent: 200)
        let normal = NetworkTotals(received: 300, sent: 300).rate(since: previous, seconds: 2)
        #expect(normal.received == 100 && normal.sent == 50)
        let reset = NetworkTotals(received: 2, sent: 4).rate(since: previous, seconds: 2)
        #expect(reset.received == 0 && reset.sent == 0)
    }
    @Test func keepAwakeRulesAreIndependentAndTimerExpires() {
        let now = Date(timeIntervalSince1970: 1000)
        #expect(AwakeRule.wanted(manualUntil: now.addingTimeInterval(1), now: now, onPower: false, requirePower: false,
                                externalDisplay: false, requireDisplay: false, runningApps: [], selectedApps: []))
        #expect(!AwakeRule.wanted(manualUntil: now, now: now, onPower: true, requirePower: false,
                                 externalDisplay: true, requireDisplay: false, runningApps: [], selectedApps: []))
        #expect(AwakeRule.wanted(manualUntil: nil, now: now, onPower: true, requirePower: true,
                                externalDisplay: false, requireDisplay: false, runningApps: [], selectedApps: []))
        #expect(AwakeRule.wanted(manualUntil: nil, now: now, onPower: false, requirePower: false,
                                externalDisplay: false, requireDisplay: false, runningApps: ["a"], selectedApps: ["a"]))
    }
    @Test func thresholdNeedsContinuousLoad() {
        var threshold = SustainedThreshold()
        let now = Date(timeIntervalSince1970: 1000)
        let initial = threshold.evaluate(exceeded: true, now: now, duration: 20)
        let sustained = threshold.evaluate(exceeded: true, now: now.addingTimeInterval(21), duration: 20)
        let reset = threshold.evaluate(exceeded: false, now: now.addingTimeInterval(22), duration: 20)
        let next = threshold.evaluate(exceeded: true, now: now.addingTimeInterval(23), duration: 20)
        #expect(!initial && sustained && !reset && !next)
    }
}
