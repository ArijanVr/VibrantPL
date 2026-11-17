// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import CoreGraphics
@testable import VibrantPlusKit

struct WindowToolRulesTests {
    @Test func edgeTargetsRespectDisplayCoordinates() {
        let screen = CGRect(x: -1440, y: 100, width: 1440, height: 900)
        #expect(WindowToolRules.edge(at: CGPoint(x: -1440, y: 500), screen: screen) == .left)
        #expect(WindowToolRules.edge(at: CGPoint(x: -1, y: 500), screen: screen) == .right)
        #expect(WindowToolRules.edge(at: CGPoint(x: -700, y: 101), screen: screen) == .full)
        #expect(WindowToolRules.edge(at: CGPoint(x: -700, y: 500), screen: screen) == nil)
        #expect(WindowToolRules.edge(at: CGPoint(x: 100, y: 500), screen: screen) == nil)
    }
    @Test func cyclesWrapAndEmptyCollectionsStayEmpty() {
        #expect(WindowToolRules.nextIndex(current: 2, count: 3) == 0)
        #expect(WindowToolRules.nextIndex(current: nil, count: 3) == 0)
        #expect(WindowToolRules.nextIndex(current: 0, count: 0) == nil)
    }
    @Test func searchCombinesAppAndWindowTerms() {
        #expect(WindowToolRules.matches(query: "safari rechnung", app: "Safari", title: "Rechnung November"))
        #expect(!WindowToolRules.matches(query: "mail", app: "Safari", title: "Rechnung"))
    }
    @Test func excludedIdentifiersAreLineOrCommaSeparated() {
        #expect(WindowToolRules.excludedIdentifiers("com.apple.Safari\n com.apple.mail,com.apple.Notes") == ["com.apple.Safari", "com.apple.mail", "com.apple.Notes"])
        #expect(WindowToolRules.excludedIdentifiers("  \n, ").isEmpty)
    }
    @Test func nextDisplayKeepsRelativePlacement() {
        let from = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let to = CGRect(x: 2000, y: 100, width: 500, height: 400)
        let moved = WindowToolRules.movedToNextDisplay(frame: CGRect(x: 100, y: 80, width: 400, height: 200), from: from, to: to)
        #expect(moved.origin.x == 2050)
        #expect(moved.origin.y == 140)
        #expect(moved.size.width == 200)
        #expect(moved.size.height == 100)
    }
}
