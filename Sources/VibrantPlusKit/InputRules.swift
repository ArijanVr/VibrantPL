// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum ExtraMouseAction: String, Codable, CaseIterable, Sendable {
    case none, missionControl, applicationWindows, showDesktop, nextSpace, previousSpace
    public var title: String {
        switch self {
        case .none: "Keine Zusatzaktion"
        case .missionControl: "Mission Control"
        case .applicationWindows: "App-Fenster"
        case .showDesktop: "Schreibtisch zeigen"
        case .nextSpace: "Nächster Space"
        case .previousSpace: "Vorheriger Space"
        }
    }
}

public struct InputRules: Codable, Equatable, Sendable {
    public var smoothScroll = false
    public var linearScroll = false
    public var commandScrollZoom = false
    public var rightControlSuperKey = false
    public var invertVertical = false
    public var invertHorizontal = false
    public var shiftScrollsSideways = false
    public var scrollMultiplier: Double = 1
    public var sideButtonsNavigate = false
    public var finderCutPaste = false
    public var finderRename = false
    public var plainPaste = false
    public var protectQuit = false
    public var protectClose = false
    public var debounceKeys = false
    public var debounceClicks = false
    public var disableMouseAcceleration = false
    public var extraButton5 = ExtraMouseAction.none
    public var extraButton6 = ExtraMouseAction.none
    public var tiltLeft = ExtraMouseAction.none
    public var tiltRight = ExtraMouseAction.none
    public var blockMusicLaunch = false
    public var excludedApps: Set<String> = []
    public init() {}

    enum CodingKeys: String, CodingKey {
        case smoothScroll, linearScroll, commandScrollZoom, rightControlSuperKey, invertVertical, invertHorizontal
        case shiftScrollsSideways, scrollMultiplier, sideButtonsNavigate, finderCutPaste, finderRename, plainPaste
        case protectQuit, protectClose, debounceKeys, debounceClicks, disableMouseAcceleration, extraButton5, extraButton6
        case tiltLeft, tiltRight, blockMusicLaunch, excludedApps
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        smoothScroll = try c.decodeIfPresent(Bool.self, forKey: .smoothScroll) ?? false
        linearScroll = try c.decodeIfPresent(Bool.self, forKey: .linearScroll) ?? false
        commandScrollZoom = try c.decodeIfPresent(Bool.self, forKey: .commandScrollZoom) ?? false
        rightControlSuperKey = try c.decodeIfPresent(Bool.self, forKey: .rightControlSuperKey) ?? false
        invertVertical = try c.decodeIfPresent(Bool.self, forKey: .invertVertical) ?? false
        invertHorizontal = try c.decodeIfPresent(Bool.self, forKey: .invertHorizontal) ?? false
        shiftScrollsSideways = try c.decodeIfPresent(Bool.self, forKey: .shiftScrollsSideways) ?? false
        scrollMultiplier = try c.decodeIfPresent(Double.self, forKey: .scrollMultiplier) ?? 1
        sideButtonsNavigate = try c.decodeIfPresent(Bool.self, forKey: .sideButtonsNavigate) ?? false
        finderCutPaste = try c.decodeIfPresent(Bool.self, forKey: .finderCutPaste) ?? false
        finderRename = try c.decodeIfPresent(Bool.self, forKey: .finderRename) ?? false
        plainPaste = try c.decodeIfPresent(Bool.self, forKey: .plainPaste) ?? false
        protectQuit = try c.decodeIfPresent(Bool.self, forKey: .protectQuit) ?? false
        protectClose = try c.decodeIfPresent(Bool.self, forKey: .protectClose) ?? false
        debounceKeys = try c.decodeIfPresent(Bool.self, forKey: .debounceKeys) ?? false
        debounceClicks = try c.decodeIfPresent(Bool.self, forKey: .debounceClicks) ?? false
        disableMouseAcceleration = try c.decodeIfPresent(Bool.self, forKey: .disableMouseAcceleration) ?? false
        extraButton5 = try c.decodeIfPresent(ExtraMouseAction.self, forKey: .extraButton5) ?? .none
        extraButton6 = try c.decodeIfPresent(ExtraMouseAction.self, forKey: .extraButton6) ?? .none
        tiltLeft = try c.decodeIfPresent(ExtraMouseAction.self, forKey: .tiltLeft) ?? .none
        tiltRight = try c.decodeIfPresent(ExtraMouseAction.self, forKey: .tiltRight) ?? .none
        blockMusicLaunch = try c.decodeIfPresent(Bool.self, forKey: .blockMusicLaunch) ?? false
        excludedApps = try c.decodeIfPresent(Set<String>.self, forKey: .excludedApps) ?? []
    }

    public func scroll(vertical: Double, horizontal: Double, shift: Bool) -> (vertical: Double, horizontal: Double) {
        let speed = min(5, max(0.1, scrollMultiplier.isFinite ? scrollMultiplier : 1))
        var y = vertical * speed * (invertVertical ? -1 : 1)
        var x = horizontal * speed * (invertHorizontal ? -1 : 1)
        if shift && shiftScrollsSideways { x += y; y = 0 }
        return (y, x)
    }
}

/// Debouncing ignores hardware chatter, never deliberate key repeats.
public struct InputDebounce: Sendable {
    private var last: [Int: TimeInterval] = [:]
    public init() {}
    public mutating func accept(code: Int, time: TimeInterval, repeating: Bool, threshold: TimeInterval = 0.04) -> Bool {
        if repeating { return true }
        defer { last[code] = time }
        guard let previous = last[code], time >= previous else { return true }
        return time - previous >= threshold
    }
}
