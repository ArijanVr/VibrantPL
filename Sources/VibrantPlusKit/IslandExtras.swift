// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// How large a video from a platform may be. H.264 ends at 1080p on most platforms; anything
/// above arrives as VP9 or AV1 and is converted for QuickTime after loading.
public enum VideoQuality: String, CaseIterable, Sendable {
    case standard, uhd, hd720, small

    /// The tallest picture yt-dlp should prefer, nil: whatever is best.
    public var maxHeight: Int? {
        switch self {
        case .standard: nil
        case .uhd: 2160
        case .hd720: 720
        case .small: 480
        }
    }
}

/// The next hours of an hourly forecast (Open-Meteo: local ISO times like "2026-11-14T09:00").
public enum WeatherHours {
    /// The values from the hour of `now` on, at most `count`. ISO times sort like text, so the hour
    /// is found by comparing strings. Empty when the lists do not match or `now` is past the end.
    public static func next(times: [String], values: [Double], now: String, count: Int = 12) -> [Double] {
        guard times.count == values.count, now.count >= 13 else { return [] }
        let hour = String(now.prefix(13))
        guard let start = times.firstIndex(where: { $0.prefix(13) >= hour }) else { return [] }
        return Array(values[start...].prefix(count))
    }
}

/// A small curve: values scaled into 0 … 1 (lowest 0, highest 1). A flat line sits in the middle.
public enum Sparkline {
    public static func normalized(_ values: [Double]) -> [Double] {
        guard let low = values.min(), let high = values.max() else { return [] }
        guard high - low > 0.0001 else { return values.map { _ in 0.5 } }
        return values.map { ($0 - low) / (high - low) }
    }
}

/// A thought typed into the island lands at the end of the Today note, on its own line.
public enum QuickNote {
    public static func append(_ line: String, to note: String) -> String {
        let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return note }
        if note.isEmpty { return line }
        return note.hasSuffix("\n") ? note + line : note + "\n" + line
    }
}

/// A screen color as web hex (sRGB components 0 … 1).
public enum ColorHex {
    public enum CopyFormat: String, CaseIterable, Codable, Sendable {
        case hex, rgb, hsl, swiftUI
        public var title: String {
            switch self {
            case .hex: "HEX"
            case .rgb: "RGB"
            case .hsl: "HSL"
            case .swiftUI: "SwiftUI"
            }
        }
    }

    public static func string(red: Double, green: Double, blue: Double) -> String {
        func part(_ v: Double) -> Int { Int((min(1, max(0, v)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", part(red), part(green), part(blue))
    }

    public static func components(hex: String) -> (red: Double, green: Double, blue: Double)? {
        guard hex.count == 7, hex.first == "#", let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    public static func copyString(_ hex: String, format: CopyFormat) -> String {
        guard let c = components(hex: hex) else { return hex }
        switch format {
        case .hex: return hex
        case .rgb:
            return "rgb(\(Int((c.red * 255).rounded())), \(Int((c.green * 255).rounded())), \(Int((c.blue * 255).rounded())))"
        case .hsl:
            let hsl = hsl(c.red, c.green, c.blue)
            return "hsl(\(Int(hsl.0.rounded())), \(Int((hsl.1 * 100).rounded()))%, \(Int((hsl.2 * 100).rounded()))%)"
        case .swiftUI:
            func part(_ v: Double) -> String { String(format: "%.3f", v) }
            return "Color(red: \(part(c.red)), green: \(part(c.green)), blue: \(part(c.blue)))"
        }
    }

    /// sRGB to HSL, hue in 0…360, saturation and lightness in 0…1.
    public static func hsl(_ red: Double, _ green: Double, _ blue: Double) -> (Double, Double, Double) {
        let r = min(1, max(0, red)), g = min(1, max(0, green)), b = min(1, max(0, blue))
        let maxC = max(r, g, b), minC = min(r, g, b), d = maxC - minC
        let l = (maxC + minC) / 2
        guard d > 0 else { return (0, 0, l) }
        let s = d / (1 - abs(2 * l - 1))
        let h: Double
        if maxC == r { h = (g - b) / d + (g < b ? 6 : 0) }
        else if maxC == g { h = (b - r) / d + 2 }
        else { h = (r - g) / d + 4 }
        return (h * 60, s, l)
    }
}

/// One line like «100 chf in eur», «5 km in mi», «20 c in f» or «15:00 zürich in tokio».
public enum Converter {
    public enum Query: Equatable, Sendable {
        /// `from`/`to` are unit keys of the same kind ("km", "mi").
        case unit(value: Double, from: String, to: String)
        /// ISO codes ("CHF", "EUR"). Whether a rate exists is known only with the rates.
        case currency(amount: Double, from: String, to: String)
        /// Time zone identifiers ("Europe/Zurich").
        case time(hour: Int, minute: Int, from: String, to: String)
    }

    private struct Unit { var kind: String; var factor: Double; var label: String }

    /// Factor to the base unit of the kind (m, kg, l, m/s). Temperature has its own formula.
    private static let units: [String: Unit] = [
        "mm": .init(kind: "length", factor: 0.001, label: "mm"), "cm": .init(kind: "length", factor: 0.01, label: "cm"),
        "m": .init(kind: "length", factor: 1, label: "m"), "km": .init(kind: "length", factor: 1000, label: "km"),
        "in": .init(kind: "length", factor: 0.0254, label: "in"), "ft": .init(kind: "length", factor: 0.3048, label: "ft"),
        "yd": .init(kind: "length", factor: 0.9144, label: "yd"), "mi": .init(kind: "length", factor: 1609.344, label: "mi"),
        "mg": .init(kind: "mass", factor: 0.000001, label: "mg"), "g": .init(kind: "mass", factor: 0.001, label: "g"),
        "kg": .init(kind: "mass", factor: 1, label: "kg"), "t": .init(kind: "mass", factor: 1000, label: "t"),
        "oz": .init(kind: "mass", factor: 0.028349523125, label: "oz"), "lb": .init(kind: "mass", factor: 0.45359237, label: "lb"),
        "ml": .init(kind: "volume", factor: 0.001, label: "ml"), "cl": .init(kind: "volume", factor: 0.01, label: "cl"),
        "dl": .init(kind: "volume", factor: 0.1, label: "dl"), "l": .init(kind: "volume", factor: 1, label: "l"),
        "floz": .init(kind: "volume", factor: 0.0295735295625, label: "fl oz"), "cup": .init(kind: "volume", factor: 0.2365882365, label: "cup"),
        "gal": .init(kind: "volume", factor: 3.785411784, label: "gal"),
        "kmh": .init(kind: "speed", factor: 1 / 3.6, label: "km/h"), "mph": .init(kind: "speed", factor: 0.44704, label: "mph"),
        "ms": .init(kind: "speed", factor: 1, label: "m/s"), "kn": .init(kind: "speed", factor: 0.514444, label: "kn"),
        "c": .init(kind: "temperature", factor: 1, label: "°C"), "f": .init(kind: "temperature", factor: 1, label: "°F"),
        "k": .init(kind: "temperature", factor: 1, label: "K"),
    ]

    private static let unitAliases: [String: String] = [
        "millimeter": "mm", "zentimeter": "cm", "meter": "m", "kilometer": "km",
        "zoll": "in", "inch": "in", "inches": "in", "\"": "in", "fuss": "ft", "foot": "ft", "feet": "ft", "'": "ft",
        "yard": "yd", "yards": "yd", "meile": "mi", "meilen": "mi", "mile": "mi", "miles": "mi",
        "gramm": "g", "kilo": "kg", "kilogramm": "kg", "tonne": "t", "tonnen": "t",
        "unze": "oz", "unzen": "oz", "lbs": "lb", "pfund": "lb", "pound": "lb", "pounds": "lb",
        "milliliter": "ml", "liter": "l", "gallone": "gal", "gallonen": "gal", "gallon": "gal", "tasse": "cup",
        "km/h": "kmh", "m/s": "ms", "knoten": "kn",
        "°c": "c", "celsius": "c", "grad": "c", "°f": "f", "fahrenheit": "f", "kelvin": "k",
    ]

    private static let currencyAliases: [String: String] = [
        "fr": "CHF", "fr.": "CHF", "sfr": "CHF", "franken": "CHF", "euro": "EUR", "€": "EUR",
        "dollar": "USD", "$": "USD", "us$": "USD", "£": "GBP", "yen": "JPY", "¥": "JPY",
    ]

    private static let zones: [String: String] = [
        "zürich": "Europe/Zurich", "zurich": "Europe/Zurich", "bern": "Europe/Zurich", "basel": "Europe/Zurich",
        "genf": "Europe/Zurich", "schweiz": "Europe/Zurich", "berlin": "Europe/Berlin", "wien": "Europe/Vienna",
        "paris": "Europe/Paris", "london": "Europe/London", "lissabon": "Europe/Lisbon", "madrid": "Europe/Madrid",
        "rom": "Europe/Rome", "athen": "Europe/Athens", "istanbul": "Europe/Istanbul", "moskau": "Europe/Moscow",
        "pristina": "Europe/Belgrade", "prishtina": "Europe/Belgrade", "tirana": "Europe/Tirane",
        "dubai": "Asia/Dubai", "mumbai": "Asia/Kolkata", "delhi": "Asia/Kolkata", "bangkok": "Asia/Bangkok",
        "singapur": "Asia/Singapore", "hongkong": "Asia/Hong_Kong", "peking": "Asia/Shanghai", "shanghai": "Asia/Shanghai",
        "tokio": "Asia/Tokyo", "tokyo": "Asia/Tokyo", "seoul": "Asia/Seoul", "sydney": "Australia/Sydney",
        "auckland": "Pacific/Auckland", "new york": "America/New_York", "nyc": "America/New_York",
        "chicago": "America/Chicago", "denver": "America/Denver", "los angeles": "America/Los_Angeles",
        "la": "America/Los_Angeles", "san francisco": "America/Los_Angeles", "toronto": "America/Toronto",
        "mexiko": "America/Mexico_City", "sao paulo": "America/Sao_Paulo", "utc": "UTC", "gmt": "UTC",
    ]

    /// What a unit key looks like in a result ("km", "°C", "fl oz").
    public static func label(_ unit: String) -> String { units[unit]?.label ?? unit }

    static func unitKey(_ word: String) -> String? {
        let w = word.trimmingCharacters(in: .whitespaces)
        if units[w] != nil { return w }
        return unitAliases[w]
    }

    static func currencyCode(_ word: String) -> String? {
        let w = word.trimmingCharacters(in: .whitespaces)
        if let code = currencyAliases[w] { return code }
        guard w.count == 3, w.allSatisfy({ $0.isLetter && $0.isASCII }) else { return nil }
        return w.uppercased()
    }

    /// 1'250.50, 1’250,5 and 1250.5 all read as the same number.
    static func number(_ text: String) -> Double? {
        var t = text.filter { !" '’".contains($0) }
        guard !t.isEmpty else { return nil }
        if t.contains(",") { t = t.contains(".") ? t.replacingOccurrences(of: ",", with: "") : t.replacingOccurrences(of: ",", with: ".") }
        return Double(t)
    }

    public static func parse(_ text: String) -> Query? {
        let line = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: (String, String)?
        for word in [" in ", " nach ", " zu ", " to ", " = ", "="] {
            if let r = line.range(of: word) {
                parts = (String(line[..<r.lowerBound]), String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces))
                break
            }
        }
        guard let (left, right) = parts, !right.isEmpty else { return nil }

        // «15:00 zürich in tokio»
        if let m = left.firstMatch(of: /^(\d{1,2})[:.](\d{2})\s*(?:uhr)?\s+(.+)$/),
           let h = Int(m.1), let min = Int(m.2), h < 24, min < 60,
           let from = zones[String(m.3).trimmingCharacters(in: .whitespaces)], let to = zones[right] {
            return .time(hour: h, minute: min, from: from, to: to)
        }

        // «100 chf», «$100», «5km»
        var amountText = left, unitText = ""
        if let first = left.first, "$€£¥".contains(first) {
            amountText = String(left.dropFirst())
            unitText = String(first)
        } else if let m = left.firstMatch(of: /^(-?[0-9][0-9.,'’ ]*)\s*(.*)$/) {
            amountText = String(m.1)
            unitText = String(m.2)
        }
        guard let value = number(amountText), !unitText.isEmpty else { return nil }
        if let from = unitKey(unitText), let to = unitKey(right), units[from]?.kind == units[to]?.kind {
            return .unit(value: value, from: from, to: to)
        }
        if let from = currencyCode(unitText), let to = currencyCode(right) {
            return .currency(amount: value, from: from, to: to)
        }
        return nil
    }

    public static func convertUnit(_ value: Double, from: String, to: String) -> Double? {
        guard let a = units[from], let b = units[to], a.kind == b.kind else { return nil }
        guard a.kind == "temperature" else { return value * a.factor / b.factor }
        let celsius: Double = switch from { case "f": (value - 32) * 5 / 9; case "k": value - 273.15; default: value }
        return switch to { case "f": celsius * 9 / 5 + 32; case "k": celsius + 273.15; default: celsius }
    }

    /// `eurRates`: how much of each currency one euro buys ("CHF": 0.93). EUR itself counts as 1.
    public static func convertCurrency(_ amount: Double, from: String, to: String, eurRates: [String: Double]) -> Double? {
        func rate(_ code: String) -> Double? { code == "EUR" ? 1 : eurRates[code] }
        guard let a = rate(from), let b = rate(to), a > 0 else { return nil }
        return amount / a * b
    }

    /// The same moment in another time zone. `dayOffset` is -1, 0 or 1 against the day in `from`.
    public static func convertTime(hour: Int, minute: Int, from: String, to: String, on day: Date) -> (hour: Int, minute: Int, dayOffset: Int)? {
        guard let a = TimeZone(identifier: from), let b = TimeZone(identifier: to) else { return nil }
        var source = Calendar(identifier: .gregorian)
        source.timeZone = a
        var parts = source.dateComponents([.year, .month, .day], from: day)
        parts.hour = hour
        parts.minute = minute
        guard let moment = source.date(from: parts) else { return nil }
        var target = Calendar(identifier: .gregorian)
        target.timeZone = b
        let there = target.dateComponents([.year, .month, .day, .hour, .minute], from: moment)
        let here = source.dateComponents([.year, .month, .day], from: moment)
        guard let h = there.hour, let m = there.minute,
              let d1 = Calendar(identifier: .gregorian).date(from: DateComponents(year: here.year, month: here.month, day: here.day)),
              let d2 = Calendar(identifier: .gregorian).date(from: DateComponents(year: there.year, month: there.month, day: there.day)) else { return nil }
        return (h, m, Int((d2.timeIntervalSince(d1) / 86_400).rounded()))
    }

    /// Swiss style: 1’234.56. Money and large numbers with two decimals at most, small ones with up
    /// to four significant ones, no trailing zeros.
    public static func format(_ value: Double, money: Bool = false) -> String {
        guard value.isFinite else { return "–" }
        let size = abs(value)
        let decimals = money ? 2 : (size >= 100 ? 2 : (size >= 1 ? 3 : 4))
        var text = String(format: "%.\(decimals)f", value)
        if !money, text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        let negative = text.hasPrefix("-")
        if negative { text.removeFirst() }
        let pieces = text.split(separator: ".", maxSplits: 1).map(String.init)
        var whole = pieces.first ?? "0"
        var grouped = ""
        while whole.count > 3 {
            grouped = "’" + whole.suffix(3) + grouped
            whole.removeLast(3)
        }
        return (negative ? "-" : "") + whole + grouped + (pieces.count > 1 ? "." + pieces[1] : "")
    }
}
