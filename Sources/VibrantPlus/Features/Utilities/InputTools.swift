// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Carbon.HIToolbox

import ApplicationServices
import Observation
import VibrantPlusKit

/// One public event tap, active only for explicitly enabled input modules.
@Observable
final class InputTools {
    static let shared = InputTools()
    private(set) var message: String?
    @ObservationIgnored private var tap: CFMachPort?
    @ObservationIgnored private var source: CFRunLoopSource?
    @ObservationIgnored private var keys = InputDebounce()
    @ObservationIgnored private var clicks = InputDebounce()
    @ObservationIgnored private var pendingProtection: (code: Int, app: String, date: Date)?
    @ObservationIgnored private var finderCutChange: Int?
    @ObservationIgnored private var smoothTimer: Timer?
    @ObservationIgnored private var remainingScroll = CGPoint.zero
    @ObservationIgnored private var scrollApp = ""
    @ObservationIgnored private var scrollFlags: CGEventFlags = []
    @ObservationIgnored private var superHeld = false
    @ObservationIgnored private var superUsed = false
    private static let ownEvent: Int64 = 0x56494252

    func update() {
        let prefs = Prefs.shared
        let mouse = prefs.onboarded && prefs.isOn(.mouse)
        MouseAcceleration.setDisabled(mouse && prefs.inputRules.disableMouseAcceleration)
        if mouse && prefs.inputRules.blockMusicLaunch { MusicLaunchGuard.shared.update() } else { MusicLaunchGuard.shared.stop() }
        let needed = !prefs.modules.isDisjoint(with: [.mouse, .finder, .quitProtection]) || WindowTools.shared.needsPointerTap || CleaningMode.shared.active
        guard needed && prefs.onboarded else { stop(); return }
        guard tap == nil else { return }
        guard Permission.accessibilityTrusted else { message = "Bedienungshilfen zum Steuern der Eingabe erlauben."; return }
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged, .scrollWheel, .otherMouseDown, .leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown, .rightMouseUp]
            .reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let callback: CGEventTapCallBack = { proxy, type, event, _ in
            MainActor.assumeIsolated { InputTools.shared.handle(proxy, type, event) } ? Unmanaged.passUnretained(event) : nil
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                         eventsOfInterest: mask, callback: callback, userInfo: nil) else {
            message = "Eingabeüberwachung konnte nicht gestartet werden. Prüfe die Bedienungshilfen."; return
        }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: tap, enable: true)
        message = nil
    }

    var isRunning: Bool { tap != nil }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil; tap = nil; pendingProtection = nil; finderCutChange = nil
        smoothTimer?.invalidate(); smoothTimer = nil; remainingScroll = .zero; superHeld = false; superUsed = false
        MouseAcceleration.restore()
        MusicLaunchGuard.shared.stop()
    }

    private func handle(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent) -> Bool {
        let pass = true
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }; return pass
        }
        guard event.getIntegerValueField(.eventSourceUserData) != Self.ownEvent,
              !IsSecureEventInputEnabled() else { return pass }
        if CleaningMode.shared.consumes(type, event) { return false }
        if WindowTools.shared.consumePointerEvent(type: type, event: event) { return false }
        let prefs = Prefs.shared, rules = prefs.inputRules
        let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        guard !rules.excludedApps.contains(app) else { return pass }
        if prefs.isOn(.mouse), rules.rightControlSuperKey {
            if type == .flagsChanged, event.getIntegerValueField(.keyboardEventKeycode) == 62 {
                let held = CGEventSource.keyState(.hidSystemState, key: 62)
                if held { superUsed = false }
                else if superHeld && !superUsed { Self.postKey(53) }
                superHeld = held
            }
            if superHeld {
                event.flags.formUnion([.maskCommand, .maskAlternate, .maskControl])
                if type == .keyDown { superUsed = true }
            }
        }
        let flags = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
        if type == .scrollWheel, prefs.isOn(.mouse), event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 {
            // Trackpads are continuous; these controls intentionally leave them alone.
            if rules.commandScrollZoom, flags.contains(.maskCommand) {
                let delta = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
                if delta != 0 { Self.postKey(delta > 0 ? 24 : 27, flags: .maskCommand) }
                return false
            }
            if rules.linearScroll {
                for field in [CGEventField.scrollWheelEventDeltaAxis1, .scrollWheelEventDeltaAxis2] {
                    let value = event.getIntegerValueField(field)
                    event.setIntegerValueField(field, value: value == 0 ? 0 : (value > 0 ? 3 : -3))
                }
            }
            let pixels = rules.scroll(vertical: rules.linearScroll ? Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1)) * 12 : Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)),
                                      horizontal: rules.linearScroll ? Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2)) * 12 : Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)), shift: flags.contains(.maskShift))
            if rules.smoothScroll {
                remainingScroll.x += pixels.horizontal
                remainingScroll.y += pixels.vertical
                scrollApp = app; scrollFlags = flags
                if rules.shiftScrollsSideways { scrollFlags.remove(.maskShift) }
                beginSmoothScroll()
                return false
            }
            event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(pixels.vertical.rounded()))
            event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(pixels.horizontal.rounded()))
            let transformed = rules.scroll(vertical: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1),
                                           horizontal: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2), shift: flags.contains(.maskShift))
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: transformed.vertical)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: transformed.horizontal)
            let lines = rules.scroll(vertical: Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1)),
                                     horizontal: Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2)), shift: flags.contains(.maskShift))
            event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(lines.vertical.rounded()))
            event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(lines.horizontal.rounded()))
            if rules.shiftScrollsSideways { event.flags.remove(.maskShift) }
            let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
            let tilt = TiltWheel.direction(vertical: Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1)),
                                           horizontal: Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2)),
                                           continuous: continuous)
            if tilt != 0 {
                let action = tilt < 0 ? rules.tiltLeft : rules.tiltRight
                if action != .none { Self.postExtra(action); return false }
            }
        }
        if prefs.isOn(.mouse), type == .otherMouseDown {
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            if rules.sideButtonsNavigate, button == 3 || button == 4 {
                Self.postKey(button == 3 ? 33 : 30, flags: .maskCommand); return false
            }
            if let action = (button == 5 ? rules.extraButton5 : button == 6 ? rules.extraButton6 : nil), action != .none {
                Self.postExtra(action); return false
            }
        }
        if prefs.isOn(.mouse), rules.debounceClicks, type == .leftMouseDown || type == .rightMouseDown {
            if !clicks.accept(code: Int(type.rawValue), time: ProcessInfo.processInfo.systemUptime, repeating: false) { return false }
        }
        guard type == .keyDown else { return pass }
        let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let repeating = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if prefs.isOn(.mouse), rules.debounceKeys, flags.isEmpty,
           !keys.accept(code: code, time: ProcessInfo.processInfo.systemUptime, repeating: repeating) { return false }
        if prefs.isOn(.quitProtection), flags == .maskCommand,
           (code == 12 && rules.protectQuit || code == 13 && rules.protectClose) {
            if let pendingProtection, pendingProtection.code == code, pendingProtection.app == app,
               Date.now.timeIntervalSince(pendingProtection.date) < 1.5, !repeating {
                self.pendingProtection = nil
                return pass
            }
            guard !repeating else { return false }
            pendingProtection = (code, app, .now)
            IslandModel.shared.show(Toast(symbol: "hand.raised", text: "Zum Bestätigen nochmals \(code == 12 ? "⌘Q" : "⌘W") drücken"), seconds: 2)
            return false
        }
        if prefs.isOn(.finder) {
            if rules.plainPaste, code == 9, flags == [.maskCommand, .maskAlternate, .maskShift] {
                PastePlainText.perform(); return false
            }
            if app == "com.apple.finder" {
                if rules.finderCutPaste, flags == .maskCommand, code == 7 {
                    Self.postKey(8, flags: .maskCommand)
                    // The pasteboard is written asynchronously by Finder.
                    Task { try? await Task.sleep(for: .milliseconds(150)); self.finderCutChange = NSPasteboard.general.changeCount }
                    return false
                }
                if rules.finderCutPaste, flags == .maskCommand, code == 9,
                   finderCutChange == NSPasteboard.general.changeCount {
                    finderCutChange = nil; Self.postKey(9, flags: [.maskCommand, .maskAlternate]); return false
                }
                if rules.finderRename, code == 120, flags.isEmpty { Self.postKey(36); return false }
            }
        }
        return pass
    }

    private func beginSmoothScroll() {
        guard smoothTimer == nil else { return }
        smoothTimer = Timer.repeating(every: 1.0 / 60) { _ in
            MainActor.assumeIsolated { InputTools.shared.scrollFrame() }
        }
    }
    private func scrollFrame() {
        guard Prefs.shared.isOn(.mouse), Prefs.shared.inputRules.smoothScroll,
              NSWorkspace.shared.frontmostApplication?.bundleIdentifier == scrollApp,
              !IsSecureEventInputEnabled() else {
            smoothTimer?.invalidate(); smoothTimer = nil; remainingScroll = .zero; return
        }
        let y = abs(remainingScroll.y) < 1 ? remainingScroll.y : remainingScroll.y * 0.3
        let x = abs(remainingScroll.x) < 1 ? remainingScroll.x : remainingScroll.x * 0.3
        let dy = Int32(y.rounded()), dx = Int32(x.rounded())
        remainingScroll.y -= CGFloat(dy); remainingScroll.x -= CGFloat(dx)
        if dx == 0 && dy == 0 {
            smoothTimer?.invalidate(); smoothTimer = nil; remainingScroll = .zero; return
        }
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0)
        event?.flags = scrollFlags
        event?.setIntegerValueField(.eventSourceUserData, value: Self.ownEvent)
        event?.post(tap: .cghidEventTap)
    }

    static func postExtra(_ action: ExtraMouseAction) {
        switch action {
        case .none: break
        case .missionControl: postKey(126, flags: .maskControl)
        case .applicationWindows: postKey(125, flags: .maskControl)
        case .showDesktop: postKey(103)
        case .nextSpace: postKey(124, flags: .maskControl)
        case .previousSpace: postKey(123, flags: .maskControl)
        }
    }

    static func postKey(_ code: CGKeyCode, flags: CGEventFlags = []) {
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
            event?.flags = flags
            event?.setIntegerValueField(.eventSourceUserData, value: ownEvent)
            event?.post(tap: .cghidEventTap)
        }
    }
}

/// Restores every original format unless another copy operation happened in the meantime.
enum PastePlainText {
    static func perform() {
        let pb = NSPasteboard.general
        guard let text = pb.string(forType: .string) else { return }
        let original = (pb.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in item.data(forType: type).map { (type, $0) } })
        }
        pb.clearContents(); pb.setString(text, forType: .string)
        let written = pb.changeCount
        InputTools.postKey(9, flags: .maskCommand)
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard pb.changeCount == written else { return }
            let items = original.map { formats in
                let item = NSPasteboardItem()
                for (type, data) in formats { item.setData(data, forType: type) }
                return item
            }
            pb.clearContents(); pb.writeObjects(items)
        }
    }
}
