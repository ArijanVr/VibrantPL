// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// Small, pure rules used across features. Each has unit tests.

/// Finds the video-call link in an event's URL, location, or notes.
public enum MeetingLinks {
    public enum Service: String, Sendable { case zoom = "Zoom", meet = "Google Meet", teams = "Teams", webex = "Webex", facetime = "FaceTime" }

    private static let patterns: [(Service, String)] = [
        (.zoom, #"https://[a-z0-9.-]*zoom\.us/(j|my|w)/[^\s<>"]+"#),
        (.meet, #"https://meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}[^\s<>"]*"#),
        (.teams, #"https://teams\.(microsoft|live)\.com/[^\s<>"]+"#),
        (.webex, #"https://[a-z0-9.-]*webex\.com/[^\s<>"]+"#),
        (.facetime, #"https://facetime\.apple\.com/join[^\s<>"]+"#),
    ]

    public static func find(in texts: [String?]) -> (Service, URL)? {
        for text in texts.compactMap({ $0 }) {
            for (service, pattern) in patterns {
                if let r = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
                   let url = URL(string: String(text[r])) {
                    return (service, url)
                }
            }
        }
        return nil
    }
}

/// Never overwrite: the copy goes next to the original with a free name.
public enum OutputNaming {
    public static func url(for source: URL, tag: String, ext: String, exists: (URL) -> Bool) -> URL {
        let dir = source.deletingLastPathComponent()
        let base = source.deletingPathExtension().lastPathComponent
        var candidate = dir.appending(path: "\(base) (\(tag)).\(ext)")
        var n = 2
        while exists(candidate) {
            candidate = dir.appending(path: "\(base) (\(tag) \(n)).\(ext)")
            n += 1
        }
        return candidate
    }
}

/// Reminder times for a task's bell.
public enum ReminderPreset: String, CaseIterable, Codable, Sendable, Identifiable {
    case in15Minutes, inOneHour, thisEvening, tomorrowMorning
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .in15Minutes: "In 15 Minuten"
        case .inOneHour: "In einer Stunde"
        case .thisEvening: "Heute Abend (18 Uhr)"
        case .tomorrowMorning: "Morgen früh (9 Uhr)"
        }
    }

    public func date(from now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .in15Minutes: return now.addingTimeInterval(15 * 60)
        case .inOneHour: return now.addingTimeInterval(3600)
        case .thisEvening:
            let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now)!
            // After 18:00 "this evening" means in an hour, never in the past.
            return evening > now ? evening : now.addingTimeInterval(3600)
        case .tomorrowMorning:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
        }
    }
}

/// Parses `lsof -nP -iTCP -sTCP:LISTEN -Fpcn` output into listening servers.
public enum ListeningPorts {
    public struct Server: Hashable, Sendable, Identifiable {
        public var id: Int { port }
        public var pid: Int32
        public var command: String
        public var port: Int
    }

    public static func parse(_ output: String) -> [Server] {
        var result: Set<Server> = []
        var pid: Int32 = 0
        var command = ""
        for line in output.split(separator: "\n") {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())
            switch tag {
            case "p": pid = Int32(value) ?? 0
            case "c": command = value
            case "n":
                // "*:3000", "127.0.0.1:5173", "[::1]:8080"
                if let colon = value.lastIndex(of: ":"), let port = Int(value[value.index(after: colon)...]) {
                    result.insert(Server(pid: pid, command: command, port: port))
                }
            default: break
            }
        }
        return result.sorted { $0.port < $1.port }
    }
}

/// Reads the current Git branch without running git.
public enum GitHead {
    /// The repository folder that contains `path`, or nil.
    public static func repositoryRoot(from path: String, fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)) -> String? {
        var dir = (path as NSString).standardizingPath
        while !dir.isEmpty && dir != "/" {
            if fileExists((dir as NSString).appendingPathComponent(".git")) { return dir }
            dir = (dir as NSString).deletingLastPathComponent
        }
        return nil
    }

    /// Branch name from the contents of HEAD, or a short hash when detached.
    public static func branch(fromHEAD head: String) -> String? {
        let text = head.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("ref: refs/heads/") { return String(text.dropFirst("ref: refs/heads/".count)) }
        if text.count >= 7, text.allSatisfy(\.isHexDigit) { return String(text.prefix(7)) }
        return nil
    }

    public static func branch(at root: String) -> String? {
        let gitPath = (root as NSString).appendingPathComponent(".git")
        var headPath = (gitPath as NSString).appendingPathComponent("HEAD")
        // A worktree or submodule has a .git file: "gitdir: <path>".
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDir), !isDir.boolValue,
           let text = try? String(contentsOfFile: gitPath, encoding: .utf8),
           text.hasPrefix("gitdir: ") {
            var dir = text.dropFirst("gitdir: ".count).trimmingCharacters(in: .whitespacesAndNewlines)
            if !dir.hasPrefix("/") { dir = (root as NSString).appendingPathComponent(dir) }
            headPath = (dir as NSString).appendingPathComponent("HEAD")
        }
        guard let head = try? String(contentsOfFile: headPath, encoding: .utf8) else { return nil }
        return branch(fromHEAD: head)
    }
}

/// WMO weather codes (Open-Meteo) -> SF Symbol and German text.
public enum WeatherCode {
    public static func describe(_ code: Int, isDay: Bool = true) -> (symbol: String, text: String) {
        switch code {
        case 0: return (isDay ? "sun.max.fill" : "moon.stars.fill", "Klar")
        case 1, 2: return (isDay ? "cloud.sun.fill" : "cloud.moon.fill", "Leicht bewölkt")
        case 3: return ("cloud.fill", "Bedeckt")
        case 45, 48: return ("cloud.fog.fill", "Nebel")
        case 51, 53, 55, 56, 57: return ("cloud.drizzle.fill", "Nieselregen")
        case 61, 63, 65, 66, 67, 80, 81, 82: return ("cloud.rain.fill", "Regen")
        case 71, 73, 75, 77, 85, 86: return ("cloud.snow.fill", "Schnee")
        case 95, 96, 99: return ("cloud.bolt.rain.fill", "Gewitter")
        default: return ("cloud.fill", "–")
        }
    }
}

/// When to show a short note in the notch about the Mac itself.
public enum HealthAlerts {
    public enum Alert: String, Sendable, Equatable {
        case diskAlmostFull, memoryPressure, batteryLow, hot

        public var text: String {
            switch self {
            case .diskAlmostFull: "Speicherplatz fast voll"
            case .memoryPressure: "Arbeitsspeicher unter Druck"
            case .batteryLow: "Batterie fast leer"
            case .hot: "Dein Mac ist sehr warm"
            }
        }

        public var symbol: String {
            switch self {
            case .diskAlmostFull: "internaldrive"
            case .memoryPressure: "memorychip"
            case .batteryLow: "battery.25percent"
            case .hot: "thermometer.high"
            }
        }
    }

    public static let diskLimitGB = 10.0
    public static let batteryLimit = 10

    /// thermal: ProcessInfo.ThermalState raw value (0 nominal … 3 critical).
    public static func alerts(freeDiskGB: Double, memoryPressureCritical: Bool,
                              battery: Int?, charging: Bool, thermal: Int) -> [Alert] {
        var list: [Alert] = []
        if freeDiskGB < diskLimitGB { list.append(.diskAlmostFull) }
        if memoryPressureCritical { list.append(.memoryPressure) }
        if let b = battery, b <= batteryLimit, !charging { list.append(.batteryLow) }
        if thermal >= 2 { list.append(.hot) }
        return list
    }
}

/// "12:05", "1:02:05": durations for timers.
public enum Clock {
    public static func format(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }
}
