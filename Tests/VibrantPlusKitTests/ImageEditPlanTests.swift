// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import VibrantPlusKit
struct ImageEditPlanTests {
    @Test func clampsToImageBoundsWithoutInvalidNumbers() {
        let rect = UnitRectangle(x: -2, y: 0.75, width: 8, height: 5)
        #expect(rect.x == 0 && rect.y == 0.75 && rect.width == 1 && rect.height == 0.25)
        let bad = UnitRectangle(x: .nan, y: .infinity, width: .nan, height: .infinity)
        #expect(bad == UnitRectangle(x: 0, y: 0, width: 0, height: 0))
    }
}

struct ScrollCaptureTests {
    @Test func overlapFindsSharedSuffixPrefix() {
        #expect(ScrollCapture.overlap([1, 2, 3, 4], [3, 4, 5, 6]) == 2)
        #expect(ScrollCapture.overlap([1, 2], [3, 4]) == 0)
        #expect(ScrollCapture.overlap([9, 8, 7], [9, 8, 7]) == 3)
        #expect(ScrollCapture.shouldStop(previous: 10, current: 10, frames: 2))
        #expect(!ScrollCapture.shouldStop(previous: 10, current: 11, frames: 2))
        #expect(ScrollCapture.shouldStop(previous: 1, current: 2, frames: 8))
    }
}
