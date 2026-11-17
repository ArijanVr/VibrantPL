// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ApplicationServices
import Foundation

/// Runs a program with arguments. Never through a shell, so nothing in an
/// argument can turn into a command.
nonisolated enum Run {
    struct Result: Sendable {
        var status: Int32
        var output: String
    }

    static func program(_ path: String, _ arguments: [String], timeout: TimeInterval = 10) -> Result {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = arguments
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return Result(status: -1, output: "") }
        let deadline = DispatchTime.now() + timeout
        let group = DispatchGroup()
        group.enter()
        nonisolated(unsafe) var data = Data()
        DispatchQueue.global().async {
            data = pipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        if group.wait(timeout: deadline) == .timedOut {
            p.terminate()
            return Result(status: -2, output: "")
        }
        p.waitUntilExit()
        return Result(status: p.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }

    /// Off the main thread.
    static func async(_ path: String, _ arguments: [String], timeout: TimeInterval = 10) async -> Result {
        await Task.detached(priority: .utility) { program(path, arguments, timeout: timeout) }.value
    }
}

/// Quits Vibrant+ and opens it again (after a backup import, or for a new Screen Recording permission).
/// The new copy starts only after this one has ended: two copies at once would fight over the hook
/// socket and the hot keys. A detached `/bin/sh` waits one second, because a process cannot open
/// anything after it has quit. This is the one place Vibrant+ uses a shell; the app path goes in as an
/// argument (`$1`), never into the script text, so nothing in it can become a command.
enum AppRelaunch {
    /// Quits and opens the app again. `removing` is an old bundle the updater moved aside:
    /// it is deleted only after this process has ended, never while it still maps its code.
    static func now(removing old: URL? = nil) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        let script = old == nil ? "sleep 1; /usr/bin/open \"$1\"" : "sleep 1; /usr/bin/open \"$1\"; /bin/rm -rf \"$2\""
        p.arguments = ["-c", script, "sh", Bundle.main.bundlePath] + (old.map { [$0.path] } ?? [])
        try? p.run()
        NSApp.terminate(nil)
    }
}

/// Saving can fail (disk full, data folder gone or not writable). Instead of losing data silently,
/// the island says so: once per kind of data and minute, so a failing autosave does not flood it.
enum SaveReport {
    private static var lastShown: [String: Date] = [:]

    static func attempt(_ what: String, _ save: () throws -> Void) {
        do { try save() } catch {
            let now = Date.now
            if let last = lastShown[what], now.timeIntervalSince(last) < 60 { return }
            lastShown[what] = now
            IslandModel.shared.show(Toast(symbol: "exclamationmark.triangle",
                                          text: "\(what) konnte nicht gespeichert werden", warm: true), seconds: 8)
        }
    }
}

/// AppleScript for apps that offer nothing else (Music, Spotify, System Events, Finder).
enum Script {
    enum Failure: Error {
        case notAllowed
        case failed(Int, String)
    }

    /// Runs on the main thread (NSAppleScript is not thread-safe). Scripts are short.
    /// `timeout` bounds how long a busy or hung app may hold the main thread; without it,
    /// AppleScript waits up to two minutes for an answer.
    @discardableResult
    static func run(_ source: String, timeout seconds: Int = 3) throws -> NSAppleEventDescriptor {
        let bounded = "with timeout of \(max(1, seconds)) seconds\n\(source)\nend timeout"
        guard let script = NSAppleScript(source: bounded) else { throw Failure.failed(0, "compile") }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            // -1743: the person has not allowed Automation for this target.
            if code == -1743 { throw Failure.notAllowed }
            throw Failure.failed(code, error[NSAppleScript.errorMessage] as? String ?? "")
        }
        return result
    }

    /// True when the app is running. Scripting an app that is not running would launch it.
    static func isRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}

/// Permissions Vibrant+ can ask for, each only when a module needs it.
enum Permission: String, CaseIterable, Identifiable {
    case accessibility, calendar, reminders, microphone, speech, screenRecording, automation, audioCapture

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accessibility: "Bedienungshilfen"
        case .calendar: "Kalender"
        case .reminders: "Erinnerungen"
        case .microphone: "Mikrofon"
        case .speech: "Spracherkennung"
        case .screenRecording: "Bildschirmaufnahme"
        case .automation: "Automation"
        case .audioCapture: "Systemaudio-Aufnahme"
        }
    }

    var reason: String {
        switch self {
        case .accessibility: "Für Rowline, Tastengeräusche, Tasten anzeigen und das Einfügen von Diktaten."
        case .calendar: "Für den nächsten Termin und die Termine von heute. Nur lesen."
        case .reminders: "Für fällige Erinnerungen in der Insel und zum Abhaken. Nachrichten lassen sich nicht anbinden: Apple gibt dafür keine Schnittstelle frei."
        case .microphone: "Nur solange du die Stimm-Tasten hältst."
        case .speech: "Wandelt das Gesagte in Text, wenn möglich auf dem Mac."
        case .screenRecording: "Für Bildschirmfotos aus Vibrant+ (Kurzbefehle, Insel, Kurzbefehle-App). Nach dem Erlauben Vibrant+ neu starten."
        case .automation: "Für Musik (Spotify, Musik), den Dunkelmodus (System Events) und den Papierkorb (Finder)."
        case .audioCapture: "Für die Lautstärke pro App im Mixer. Es wird nichts aufgenommen."
        }
    }

    var settingsURL: URL {
        let anchor = switch self {
        case .accessibility: "Privacy_Accessibility"
        case .calendar: "Privacy_Calendars"
        case .reminders: "Privacy_Reminders"
        case .microphone: "Privacy_Microphone"
        case .speech: "Privacy_SpeechRecognition"
        case .screenRecording: "Privacy_ScreenCapture"
        case .automation: "Privacy_Automation"
        case .audioCapture: "Privacy_AudioCapture"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
    }

    static var accessibilityTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that leads to System Settings.
    static func requestAccessibility() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func openSettings() { NSWorkspace.shared.open(settingsURL) }
}

/// Spoken notes for VoiceOver. The island is a panel that never takes focus by itself,
/// so what appears there has to be announced or VoiceOver users never hear of it.
enum Announce {
    static func say(_ text: String, urgent: Bool = false) {
        guard NSWorkspace.shared.isVoiceOverEnabled, !text.isEmpty else { return }
        let priority: NSAccessibilityPriorityLevel = urgent ? .high : .medium
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: priority.rawValue])
    }
}

/// A one-line note that slides out of the notch for a few seconds.
struct Toast: Equatable, Identifiable {
    let id = UUID()
    var symbol: String
    var text: String
    var warm = false
}

extension Timer {
    /// A repeating timer on the main run loop with 10 % tolerance. macOS can then fire it
    /// together with other wakeups instead of waking the CPU for each one, which matters on
    /// a MacBook Air on battery (Apple's Energy Efficiency Guide: at least 10 %). Every
    /// repeating timer in Vibrant+ goes through here.
    static func repeating(every seconds: TimeInterval, _ block: @escaping @Sendable (Timer) -> Void) -> Timer {
        let timer = Timer(timeInterval: seconds, repeats: true, block: block)
        timer.tolerance = seconds * 0.1
        // `.common`, not the default mode: otherwise every timer stops while a menu is open,
        // an alert runs or a window is dragged, and the whole app looks dead until it is over.
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
