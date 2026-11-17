// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import VibrantPlusKit

struct ProcessSnapshotTests {
    @Test func heaviestIncludesThisProcess() {
        let rows = ProcessSnapshot.heaviest(limit: 32)
        #expect(!rows.isEmpty)
        #expect(rows.first!.memoryBytes >= rows.last!.memoryBytes)
    }

    @Test func compressorShareAndBatteryStayInRange() {
        #expect(MemoryPressurePlan.compressorShare(compressor: 25, wired: 25, internalPages: 50) == 0.25)
        #expect(MemoryPressurePlan.compressorShare(compressor: 0, wired: 0, internalPages: 0) == 0)
        #expect(BatteryHealthPlan.percent(maxCapacity: 4500, designCapacity: 5000) == 90)
        #expect(BatteryHealthPlan.percent(maxCapacity: nil, designCapacity: 5000) == nil)
    }

    @Test func zoomRectStaysInsideDisplay() {
        let display = CGRect(x: 100, y: 50, width: 800, height: 600)
        let rect = ZoomPlan.sourceRect(display: display, mouse: CGPoint(x: 100, y: 50), fraction: 0.5)
        #expect(rect.width == 400 && rect.height == 300)
        #expect(rect.minX >= 0 && rect.minY >= 0)
        #expect(rect.maxX <= 800 && rect.maxY <= 600)
    }

    @Test func tiltIgnoresTrackpads() {
        #expect(TiltWheel.direction(vertical: 0, horizontal: 3, continuous: false) == 1)
        #expect(TiltWheel.direction(vertical: 0, horizontal: -3, continuous: false) == -1)
        #expect(TiltWheel.direction(vertical: 0, horizontal: 3, continuous: true) == 0)
        #expect(TiltWheel.direction(vertical: 5, horizontal: 1, continuous: false) == 0)
    }
}
