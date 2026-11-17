// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct NetworkTotals: Equatable, Sendable {
    public var received: UInt64
    public var sent: UInt64
    public init(received: UInt64, sent: UInt64) { self.received = received; self.sent = sent }
    public func rate(since previous: Self, seconds: TimeInterval) -> (received: Double, sent: Double) {
        guard seconds > 0 else { return (0, 0) }
        return (received >= previous.received ? Double(received - previous.received) / seconds : 0,
                sent >= previous.sent ? Double(sent - previous.sent) / seconds : 0)
    }
}

public enum AwakeRule {
    public static func wanted(manualUntil: Date?, now: Date, onPower: Bool, requirePower: Bool,
                              externalDisplay: Bool, requireDisplay: Bool,
                              runningApps: Set<String>, selectedApps: Set<String>) -> Bool {
        if let manualUntil, manualUntil > now { return true }
        return requirePower && onPower || requireDisplay && externalDisplay || !runningApps.isDisjoint(with: selectedApps)
    }
}

public enum ThermalLabel {
    public static func german(_ raw: Int) -> String {
        switch raw {
        case 0: "Normal"
        case 1: "Erhöht"
        case 2: "Stark"
        case 3: "Kritisch"
        default: "Unbekannt"
        }
    }
}

public struct SustainedThreshold: Sendable {
    private var since: Date?
    public init() {}
    public mutating func evaluate(exceeded: Bool, now: Date, duration: TimeInterval) -> Bool {
        guard exceeded else { since = nil; return false }
        if since == nil { since = now }
        return now.timeIntervalSince(since ?? now) >= max(0, duration)
    }
}

public struct FavoriteToolAction: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable { case application, file, shortcut }
    public var id: UUID
    public var title: String
    public var kind: Kind
    public var target: String
    public init(id: UUID = UUID(), title: String, kind: Kind, target: String) {
        self.id = id; self.title = title; self.kind = kind; self.target = target
    }
}
