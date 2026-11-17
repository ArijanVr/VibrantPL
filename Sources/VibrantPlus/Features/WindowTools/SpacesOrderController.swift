// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation

/// CFPreferences is public; this uses the same Dock preference as Mission Control.
/// The original value is restored when the feature stops, including after an interrupted launch.
enum SpacesOrderController {
    private static let dockDomain = "com.apple.dock" as CFString
    private static let key = "mru-spaces" as CFString
    private static var defaults: UserDefaults {
        Paths.isOverridden
            ? UserDefaults(suiteName: "ch.arjo.vibrantplus.test.windowTools." + Paths.dataDirectory.lastPathComponent)!
            : .standard
    }
    private static let savedKey = "windowTools.spacesBackup"
    private static let hadValueKey = "windowTools.spacesHadValue"
    private static let valueKey = "windowTools.spacesValue"

    static func setEnabled(_ enabled: Bool) {
        // Tests/snapshots may render this page, but must never alter the real Dock domain.
        guard !Paths.isOverridden else { return }
        guard enabled else { restore(); return }
        if !defaults.bool(forKey: savedKey) {
            let previous = CFPreferencesCopyAppValue(key, dockDomain)
            defaults.set(previous != nil, forKey: hadValueKey)
            defaults.set((previous as? NSNumber)?.boolValue ?? true, forKey: valueKey)
            defaults.set(true, forKey: savedKey)
        }
        CFPreferencesSetAppValue(key, kCFBooleanFalse, dockDomain)
        CFPreferencesAppSynchronize(dockDomain)
    }
    static func restore() {
        guard !Paths.isOverridden, defaults.bool(forKey: savedKey) else { return }
        // Do not overwrite a new choice the person made outside Vibrant+ while this was active.
        let current = CFPreferencesCopyAppValue(key, dockDomain) as? NSNumber
        if current?.boolValue == false {
            if defaults.bool(forKey: hadValueKey) {
                CFPreferencesSetAppValue(key, defaults.bool(forKey: valueKey) ? kCFBooleanTrue : kCFBooleanFalse, dockDomain)
            } else { CFPreferencesSetAppValue(key, nil, dockDomain) }
            CFPreferencesAppSynchronize(dockDomain)
        }
        defaults.removeObject(forKey: savedKey)
        defaults.removeObject(forKey: hadValueKey)
        defaults.removeObject(forKey: valueKey)
    }
    static func restartDock() {
        let alert = NSAlert()
        alert.messageText = "Dock neu starten?"
        alert.informativeText = "Dock und Mission Control sind kurz nicht verfügbar. Laufende Apps bleiben geöffnet. Damit übernimmt Dock die neue Spaces-Einstellung sofort."
        alert.addButton(withTitle: "Dock neu starten"); alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { _ = await Run.async("/usr/bin/killall", ["Dock"]) }
    }
}
