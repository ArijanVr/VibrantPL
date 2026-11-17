// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import Foundation
@testable import VibrantPlusKit

struct IslandNavigationTests {
    @Test func restoresNewPagesAndDiscardsUnknownAndDuplicateIDs() {
        var config = IslandNavigation()
        config.order = ["files", "obsolete", "home", "files"]
        #expect(config.ordered(["home", "mac", "files"]) == ["files", "home", "mac"])
    }
    @Test func hiddenPagesDoNotDisableServicesAndFallbackRemainsReachable() {
        var config = IslandNavigation()
        config.hidden = ["home", "files"]
        #expect(config.visible(["home", "files"]) == ["home"])
        #expect(config.visible([]).isEmpty)
        #expect(config.ordered(["home", "files"]) == ["home", "files"])
    }
    @Test func savedConfigurationRoundTrips() throws {
        var config = IslandNavigation()
        config.order = ["files", "home"]
        config.placement = .aboveTiles
        config.labels = .all
        config.showsDate = false
        config.hidden = ["mac"]
        config.titles = ["files": "Meine Dateien"]
        #expect(try JSONDecoder().decode(IslandNavigation.self, from: JSONEncoder().encode(config)) == config)
        #expect(config.title(for: "files", fallback: "Ablage") == "Meine Dateien")
        config.titles["files"] = "  "
        #expect(config.title(for: "files", fallback: "Ablage") == "Ablage")
    }

    @Test func nineIconsFitBesideAWideNotchAndAMenuBarPill() {
        let wide = IslandNavLayout.bandSlotWidth(islandWidth: 648, padding: 8, notchWidth: 220)
        let pill = IslandNavLayout.bandSlotWidth(islandWidth: 648, padding: 8, notchWidth: 168)
        let cramped = IslandNavLayout.tabMinWidth(count: 9, available: wide)
        #expect(wide >= 200)
        #expect(pill > wide)
        #expect(cramped >= IslandNavLayout.minimumTab)
        #expect(CGFloat(9) * cramped <= wide)
        #expect(IslandNavLayout.tabMinWidth(count: 3, available: 200) == IslandNavLayout.preferredTab)
        #expect(IslandNavLayout.tabMinWidth(count: 9, available: 0) == IslandNavLayout.minimumTab)
    }
}
