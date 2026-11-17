// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A bounded arithmetic grammar. No scripting engine, reflection or executable expressions.
public enum SafeCalculator {
    public static func evaluate(_ source: String) -> Double? {
        let normalized = source.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty, normalized.count <= 256 else { return nil }
        var parser = Parser(characters: Array(normalized))
        guard let result = parser.expression(depth: 0), result.isFinite else { return nil }
        parser.skipSpaces()
        return parser.index == parser.characters.count ? result : nil
    }

    private struct Parser {
        let characters: [Character]
        var index = 0
        mutating func skipSpaces() { while index < characters.count && characters[index].isWhitespace { index += 1 } }
        mutating func take(_ character: Character) -> Bool {
            skipSpaces()
            guard index < characters.count, characters[index] == character else { return false }
            index += 1; return true
        }
        mutating func expression(depth: Int) -> Double? {
            guard depth < 32, var value = term(depth: depth + 1) else { return nil }
            while true {
                if take("+") { guard let rhs = term(depth: depth + 1) else { return nil }; value += rhs }
                else if take("-") { guard let rhs = term(depth: depth + 1) else { return nil }; value -= rhs }
                else { return value.isFinite ? value : nil }
                guard value.isFinite else { return nil }
            }
        }
        mutating func term(depth: Int) -> Double? {
            guard depth < 32, var value = unary(depth: depth + 1) else { return nil }
            while true {
                if take("*") { guard let rhs = unary(depth: depth + 1) else { return nil }; value *= rhs }
                else if take("/") { guard let rhs = unary(depth: depth + 1), rhs != 0 else { return nil }; value /= rhs }
                else if take("%") { guard let rhs = unary(depth: depth + 1), rhs != 0 else { return nil }; value.formTruncatingRemainder(dividingBy: rhs) }
                else { return value.isFinite ? value : nil }
                guard value.isFinite else { return nil }
            }
        }
        mutating func unary(depth: Int) -> Double? {
            guard depth < 32 else { return nil }
            if take("+") { return unary(depth: depth + 1) }
            if take("-") { return unary(depth: depth + 1).map { -$0 } }
            return power(depth: depth + 1)
        }
        mutating func power(depth: Int) -> Double? {
            guard depth < 32, let value = atom(depth: depth + 1) else { return nil }
            if take("^") {
                guard let exponent = unary(depth: depth + 1), abs(exponent) <= 1000 else { return nil }
                let result = pow(value, exponent)
                return result.isFinite ? result : nil
            }
            return value
        }
        mutating func atom(depth: Int) -> Double? {
            guard depth < 32 else { return nil }
            if take("(") {
                guard let value = expression(depth: depth + 1), take(")") else { return nil }
                return value
            }
            skipSpaces()
            let start = index
            var digits = 0, dots = 0
            while index < characters.count {
                let character = characters[index]
                if character.isASCII && character.isNumber { digits += 1; index += 1 }
                else if character == "." && dots == 0 { dots += 1; index += 1 }
                else { break }
            }
            guard digits > 0 else { return nil }
            // Scientific notation is part of a numeric literal, never a function name.
            if index < characters.count, characters[index] == "e" || characters[index] == "E" {
                index += 1
                if index < characters.count, characters[index] == "+" || characters[index] == "-" { index += 1 }
                let exponentStart = index
                while index < characters.count && characters[index].isASCII && characters[index].isNumber { index += 1 }
                guard index > exponentStart else { return nil }
            }
            return Double(String(characters[start..<index])).flatMap { $0.isFinite ? $0 : nil }
        }
    }
}
