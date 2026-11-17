// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Persisted navigation is independent of enabled services and the tile layout.
public struct IslandNavigation: Codable, Equatable, Sendable {
    public enum Placement: String, Codable, CaseIterable, Sendable {
        case besideNotch, aboveTiles
    }
    public enum Labels: String, Codable, CaseIterable, Sendable {
        case selected, icons, all
    }
    public var order: [String] = []
    public var hidden: Set<String> = []
    public var placement: Placement = .besideNotch
    public var labels: Labels = .icons
    public var showsDate = true
    public var showsSettings = true
    public var titles: [String: String] = [:]

    public init() {}

    public func ordered(_ known: [String]) -> [String] {
        var seen: Set<String> = []
        return (order + known).filter { known.contains($0) && seen.insert($0).inserted }
    }

    public func visible(_ available: [String]) -> [String] {
        let result = ordered(available).filter { !hidden.contains($0) }
        // A stale configuration or disabled module must never strand the person.
        return result.isEmpty ? Array(available.prefix(1)) : result
    }

    public func title(for id: String, fallback: String) -> String {
        let value = titles[id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? fallback : String(value.prefix(40))
    }
}

/// How wide each page symbol can be so every visible page stays a tap, even beside a wide notch.
public enum IslandNavLayout {
    public static let preferredTab: CGFloat = 28
    public static let minimumTab: CGFloat = 18

    /// One side of the band: island minus padding minus the notch, split evenly so the hole stays centred.
    public static func bandSlotWidth(islandWidth: CGFloat, padding: CGFloat, notchWidth: CGFloat) -> CGFloat {
        max(0, (max(0, islandWidth) - max(0, padding) * 2 - max(0, notchWidth)) / 2)
    }

    public static func tabMinWidth(count: Int, available: CGFloat) -> CGFloat {
        let n = max(1, count)
        let room = max(0, available)
        return min(preferredTab, max(minimumTab, (room / CGFloat(n)).rounded(.down)))
    }
}
