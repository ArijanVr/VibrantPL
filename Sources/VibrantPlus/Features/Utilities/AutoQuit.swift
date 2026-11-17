// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ApplicationServices
import Observation

@Observable
final class AutoQuit {
    static let shared = AutoQuit()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var seenWindow: Set<pid_t> = []
    @ObservationIgnored private var emptySince: [pid_t: Date] = [:]

    func start() {
        guard timer == nil else { return }
        timer = Timer.repeating(every: 2) { [weak self] _ in MainActor.assumeIsolated { self?.poll() } }
    }
    func stop() { timer?.invalidate(); timer = nil; seenWindow = []; emptySince = [:] }

    private func poll() {
        guard Permission.accessibilityTrusted else { return }
        let selected = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.bundleIdentifier.map(Prefs.shared.autoQuitApps.contains) == true
            && $0.bundleIdentifier != Bundle.main.bundleIdentifier && $0.bundleIdentifier != "com.apple.finder"
        }
        let alive = Set(selected.map(\.processIdentifier))
        seenWindow.formIntersection(alive)
        emptySince = emptySince.filter { alive.contains($0.key) }
        for app in selected {
            let pid = app.processIdentifier
            let element = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(element, 0.2)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement] else { continue }
            if !windows.isEmpty { seenWindow.insert(pid); emptySince[pid] = nil; continue }
            guard seenWindow.contains(pid) else { continue }
            if let since = emptySince[pid], Date.now.timeIntervalSince(since) >= 2 {
                // Normal Quit preserves the app's save prompts. Never force terminate.
                app.terminate(); emptySince[pid] = nil; seenWindow.remove(pid)
            } else if emptySince[pid] == nil { emptySince[pid] = .now }
        }
    }
}
