// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import VibrantPlusKit
struct SafeCalculatorTests {
    @Test func precedenceParenthesesAndUnary() {
        #expect(SafeCalculator.evaluate("2 + 3 * 4") == 14)
        #expect(SafeCalculator.evaluate("(2+3)*4") == 20)
        #expect(SafeCalculator.evaluate("-2^2") == -4)
        #expect(SafeCalculator.evaluate("2^-2") == 0.25)
        #expect(SafeCalculator.evaluate("2^3^2") == 512)
        #expect(SafeCalculator.evaluate("11 % 4") == 3)
        #expect(SafeCalculator.evaluate("1,5 × 2 + 6 ÷ 3") == 5)
        #expect(SafeCalculator.evaluate("1e3 + .5") == 1000.5)
    }
    @Test func rejectsCodeInvalidSyntaxAndUnsafeNumbers() {
        for expression in ["", "1/0", "3%0", "2^^3", "1 +", "2(3)", "1 2", "1e", "1e999", "2^1001",
                           "sqrt(4)", "system('ls')", "$HOME", "1;2", "NaN", "∞", "2 ** 4", "1.2.3"] {
            #expect(SafeCalculator.evaluate(expression) == nil)
        }
        #expect(SafeCalculator.evaluate(String(repeating: "(", count: 40) + "1" + String(repeating: ")", count: 40)) == nil)
        #expect(SafeCalculator.evaluate(String(repeating: "1+", count: 200) + "1") == nil)
    }
}
