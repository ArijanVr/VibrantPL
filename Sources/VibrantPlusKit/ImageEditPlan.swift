// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct UnitRectangle: Codable, Equatable, Sendable {
    public var x: Double, y: Double, width: Double, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        let x1 = max(0, min(1, x.isFinite ? x : 0))
        let y1 = max(0, min(1, y.isFinite ? y : 0))
        self.x = x1; self.y = y1
        self.width = max(0, min(1 - x1, width.isFinite ? width : 0))
        self.height = max(0, min(1 - y1, height.isFinite ? height : 0))
    }
    public static let full = UnitRectangle(x: 0, y: 0, width: 1, height: 1)
}

public struct ImageEditPlan: Codable, Equatable, Sendable {
    public var crop = UnitRectangle.full
    public var redactions: [UnitRectangle] = []
    public var watermark = ""
    public var padding: Int = 0
    public init() {}
}
