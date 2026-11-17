// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Observation
import VibrantPlusKit

@Observable
final class SystemToolPreferences {
    static let shared = SystemToolPreferences()
    @ObservationIgnored private let defaults: UserDefaults = Paths.isOverridden
        ? UserDefaults(suiteName: "ch.arjo.vibrantplus.systemtools.test." + Paths.dataDirectory.lastPathComponent)!
        : .standard
    /// @Observable setters fire during init; save() must not re-enter the monitor start path.
    @ObservationIgnored private var ready = false
    var monitorCPU = false { didSet { save() } }
    var monitorMemory = false { didSet { save() } }
    var monitorDisk = false { didSet { save() } }
    var monitorNetwork = false { didSet { save() } }
    var monitorDevices = false { didSet { save() } }
    var monitorPower = false { didSet { save() } }
    var notify = false { didSet { save() } }
    var alertCPU = false { didSet { save() } }
    var alertMemory = false { didSet { save() } }
    var alertDisk = false { didSet { save() } }
    var alertBattery = false { didSet { save() } }
    var awakeOnPower = false { didSet { save() } }
    var awakeOnDisplay = false { didSet { save() } }
    var awakeApps: Set<String> = [] { didSet { save() } }
    var preventDisplaySleep = false { didSet { save() } }

    private init() {
        func flag(_ name: String, fallback: Bool = false) -> Bool {
            defaults.object(forKey: "systemtools." + name) as? Bool ?? fallback
        }
        monitorCPU = flag("cpu", fallback: true); monitorMemory = flag("memory")
        monitorDevices = flag("devices")
        monitorDisk = flag("disk"); monitorNetwork = flag("network"); monitorPower = flag("power")
        notify = flag("notify")
        alertCPU = flag("alertCPU"); alertMemory = flag("alertMemory"); alertDisk = flag("alertDisk"); alertBattery = flag("alertBattery")
        awakeOnPower = flag("awakePower"); awakeOnDisplay = flag("awakeDisplay")
        awakeApps = Set(defaults.stringArray(forKey: "systemtools.awakeApps") ?? [])
        preventDisplaySleep = flag("awakeDisplaySleep")
        ready = true
    }
    private func save() {
        guard ready else { return }
        for (key, value) in ["cpu": monitorCPU, "memory": monitorMemory, "disk": monitorDisk,
                             "network": monitorNetwork, "devices": monitorDevices, "power": monitorPower, "notify": notify, "alertCPU": alertCPU,
                             "alertMemory": alertMemory, "alertDisk": alertDisk, "alertBattery": alertBattery,
                             "awakePower": awakeOnPower, "awakeDisplay": awakeOnDisplay, "awakeDisplaySleep": preventDisplaySleep] {
            defaults.set(value, forKey: "systemtools." + key)
        }
        defaults.set(Array(awakeApps), forKey: "systemtools.awakeApps")
        ExtendedSystemMonitor.shared.preferencesChanged()
        KeepAwakeRulesService.shared.preferencesChanged()
    }
}
