// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation
import IOKit

/// Public IOHID parameter APIs. The older IOHIDSetMouseAcceleration entry is deprecated;
/// Copy/SetCFTypeParameter is the documented replacement.
enum MouseAcceleration {
    private static let key = "HIDMouseAcceleration" as CFString
    private static let backupKey = "mouse.accelerationBackup"
    private static let hadKey = "mouse.accelerationHadValue"
    private static var defaults: UserDefaults {
        Paths.isOverridden
            ? UserDefaults(suiteName: "ch.arjo.vibrantplus.test.mouse." + Paths.dataDirectory.lastPathComponent)!
            : .standard
    }

    static func setDisabled(_ disabled: Bool) {
        guard !Paths.isOverridden else { return }
        guard disabled else { restore(); return }
        var connect: io_connect_t = 0
        guard open(&connect) else { return }
        defer { IOServiceClose(connect) }
        if defaults.object(forKey: backupKey) == nil {
            if let current = value(connect) {
                defaults.set(current, forKey: backupKey)
                defaults.set(true, forKey: hadKey)
            } else {
                defaults.set(false, forKey: hadKey)
            }
        }
        _ = set(connect, -1)
    }

    static func restore() {
        guard !Paths.isOverridden, defaults.object(forKey: backupKey) != nil || defaults.object(forKey: hadKey) != nil else { return }
        var connect: io_connect_t = 0
        guard open(&connect) else { return }
        defer { IOServiceClose(connect) }
        if defaults.bool(forKey: hadKey) {
            _ = set(connect, defaults.double(forKey: backupKey))
        }
        defaults.removeObject(forKey: backupKey)
        defaults.removeObject(forKey: hadKey)
    }

    private static func open(_ connect: inout io_connect_t) -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        return IOServiceOpen(service, mach_task_self_, 1, &connect) == KERN_SUCCESS && connect != 0
    }

    private static func value(_ connect: io_connect_t) -> Double? {
        var parameter: Unmanaged<CFTypeRef>?
        guard IOHIDCopyCFTypeParameter(connect, key, &parameter) == KERN_SUCCESS, let value = parameter?.takeRetainedValue() else { return nil }
        return (value as? NSNumber)?.doubleValue
    }

    private static func set(_ connect: io_connect_t, _ value: Double) -> Bool {
        let number = NSNumber(value: value)
        return IOHIDSetCFTypeParameter(connect, key, number) == KERN_SUCCESS
    }
}

/// Quits Music only when a media-key press caused a fresh launch.
final class MusicLaunchGuard {
    static let shared = MusicLaunchGuard()
    private var monitor: Any?
    private var observer: NSObjectProtocol?
    private var armedUntil: Date?

    func update() {
        let on = Prefs.shared.onboarded && Prefs.shared.isOn(.mouse) && Prefs.shared.inputRules.blockMusicLaunch
        guard on else { stop(); return }
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { event in
            MainActor.assumeIsolated { MusicLaunchGuard.shared.noteMediaKey(event) }
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { note in
            let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            Task { @MainActor in
                guard bundleID == "com.apple.Music" else { return }
                MusicLaunchGuard.shared.handleLaunch(NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").first)
            }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        monitor = nil; observer = nil; armedUntil = nil
    }

    private func noteMediaKey(_ event: NSEvent) {
        guard event.subtype.rawValue == 8 else { return }
        let key = (event.data1 >> 16) & 0xFFFF
        let down = ((event.data1 >> 8) & 0xFF) == 0xA
        guard down, key == 16 || key == 17 || key == 18 else { return }
        let running = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.Music" }
        if !running { armedUntil = Date.now.addingTimeInterval(2) }
    }

    private func handleLaunch(_ app: NSRunningApplication?) {
        guard let app, app.bundleIdentifier == "com.apple.Music", let armedUntil, Date.now < armedUntil else { return }
        self.armedUntil = nil
        app.terminate()
    }
}
