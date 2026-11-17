// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import IOKit.pwr_mgt
import Observation
import VibrantPlusKit

@Observable
final class KeepAwakeRulesService {
    static let shared = KeepAwakeRulesService()
    private(set) var running = false
    private(set) var active = false
    private(set) var manualUntil: Date?
    private(set) var reason = "Keine aktive Regel"
    private(set) var error: String?
    @ObservationIgnored private var assertion = IOPMAssertionID(0)
    @ObservationIgnored private var assertionKeepsDisplay = false
    @ObservationIgnored private var timer: Timer?

    func start() {
        guard !running else { return }
        running = true
        timer = Timer.repeating(every: 5) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } }
        refresh()
    }
    func stop() { running = false; timer?.invalidate(); timer = nil; manualUntil = nil; release(); reason = "Ausgeschaltet" }
    func preferencesChanged() { if running { refresh() } }
    func keepAwake(minutes: Int) {
        guard running else { return }
        manualUntil = .now.addingTimeInterval(TimeInterval(min(1440, max(1, minutes))) * 60)
        refresh()
    }
    func cancelTimer() { manualUntil = nil; refresh() }
    private func release() {
        if assertion != 0 { IOPMAssertionRelease(assertion); assertion = 0 }
        active = false
    }
    func refresh() {
        guard running else { return }
        let p = SystemToolPreferences.shared, now = Date.now
        if let manualUntil, manualUntil <= now { self.manualUntil = nil }
        let power = ExtendedSystemMonitor.onExternalPower()
        let external = NSScreen.screens.contains { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) == 0
        }
        let apps = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let wanted = AwakeRule.wanted(manualUntil: manualUntil, now: now, onPower: power, requirePower: p.awakeOnPower,
                                     externalDisplay: external, requireDisplay: p.awakeOnDisplay, runningApps: apps, selectedApps: p.awakeApps)
        if !wanted { release(); reason = "Keine aktive Regel"; return }
        reason = manualUntil != nil ? "Timer läuft" : p.awakeOnPower && power ? "Am Netzteil" : p.awakeOnDisplay && external ? "Externer Bildschirm" : "Ausgewählte App läuft"
        if assertion != 0, assertionKeepsDisplay != p.preventDisplaySleep { release() }
        if assertion == 0 {
            let type = p.preventDisplaySleep ? kIOPMAssertionTypePreventUserIdleDisplaySleep : kIOPMAssertionTypePreventUserIdleSystemSleep
            let status = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "Vibrant+ Wachhalteregeln" as CFString, &assertion)
            error = status == kIOReturnSuccess ? nil : "Wachhalten konnte nicht aktiviert werden (\(status))."
            assertionKeepsDisplay = p.preventDisplaySleep
        }
        active = assertion != 0
    }
}
