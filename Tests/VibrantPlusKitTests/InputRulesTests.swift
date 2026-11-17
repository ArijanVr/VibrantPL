// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import VibrantPlusKit
struct InputRulesTests {
    @Test func axesRemainIndependent() {
        var rules = InputRules()
        rules.invertVertical = true
        rules.scrollMultiplier = 2
        let result = rules.scroll(vertical: 3, horizontal: 1, shift: false)
        #expect(result.vertical == -6 && result.horizontal == 2)
        rules.shiftScrollsSideways = true
        let sideways = rules.scroll(vertical: 3, horizontal: 1, shift: true)
        #expect(sideways.vertical == 0 && sideways.horizontal == -4)
    }
    @Test func chatterIsRemovedButRepeatAndOtherKeysArePreserved() {
        var debounce = InputDebounce()
        let first = debounce.accept(code: 1, time: 1, repeating: false)
        let chatter = debounce.accept(code: 1, time: 1.01, repeating: false)
        let other = debounce.accept(code: 2, time: 1.02, repeating: false)
        let repeatKey = debounce.accept(code: 1, time: 1.03, repeating: true)
        let deliberate = debounce.accept(code: 1, time: 1.1, repeating: false)
        #expect(first && !chatter && other && repeatKey && deliberate)
    }
    @Test func olderSavedRulesKeepNewFieldsOff() throws {
        let json = #"{"invertVertical":true,"scrollMultiplier":2}"#.data(using: .utf8)!
        let rules = try JSONDecoder().decode(InputRules.self, from: json)
        #expect(rules.invertVertical && rules.scrollMultiplier == 2 && !rules.disableMouseAcceleration && rules.extraButton5 == .none && rules.tiltLeft == .none && !rules.blockMusicLaunch)
    }
}
