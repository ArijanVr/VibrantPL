// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// What starting a focus session switches, and what ending it puts back.
public struct FocusRules: Codable, Sendable, Equatable {
    public var doNotDisturb = false
    public var darkMode = false
    public var hideDesktopIcons = false
    public var keepAwake = true

    public init() {}

    public var isEmpty: Bool { !doNotDisturb && !darkMode && !hideDesktopIcons && !keepAwake }
}

/// The Mac's state before focus began, so ending focus restores exactly that.
public struct FocusSnapshot: Codable, Sendable, Equatable {
    public var darkMode: Bool
    public var desktopIconsHidden: Bool
    public var keepAwake: Bool
    public init(darkMode: Bool, desktopIconsHidden: Bool, keepAwake: Bool) {
        self.darkMode = darkMode
        self.desktopIconsHidden = desktopIconsHidden
        self.keepAwake = keepAwake
    }
}

public enum FocusPlan {
    public enum Action: Equatable, Sendable {
        case toggleDoNotDisturb
        case setDarkMode(Bool)
        case setDesktopIconsHidden(Bool)
        case setKeepAwake(Bool)
    }

    /// Only what actually changes: a rule that is already satisfied does nothing (and is not undone later).
    public static func start(_ rules: FocusRules, current: FocusSnapshot) -> [Action] {
        var a: [Action] = []
        if rules.doNotDisturb { a.append(.toggleDoNotDisturb) }
        if rules.darkMode && !current.darkMode { a.append(.setDarkMode(true)) }
        if rules.hideDesktopIcons && !current.desktopIconsHidden { a.append(.setDesktopIconsHidden(true)) }
        if rules.keepAwake && !current.keepAwake { a.append(.setKeepAwake(true)) }
        return a
    }

    /// Puts back what `start` changed, based on the snapshot taken before.
    public static func end(_ rules: FocusRules, before: FocusSnapshot) -> [Action] {
        var a: [Action] = []
        if rules.doNotDisturb { a.append(.toggleDoNotDisturb) }
        if rules.darkMode && !before.darkMode { a.append(.setDarkMode(false)) }
        if rules.hideDesktopIcons && !before.desktopIconsHidden { a.append(.setDesktopIconsHidden(false)) }
        if rules.keepAwake && !before.keepAwake { a.append(.setKeepAwake(false)) }
        return a
    }
}
