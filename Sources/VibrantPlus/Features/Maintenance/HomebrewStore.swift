// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation
import Observation
import VibrantPlusKit

nonisolated enum MaintenanceCommand {
    struct Result: Sendable { let status: Int32; let output: String }
    /// No shell, no inherited input. Package scripts are run only by Homebrew after an explicit action.
    static func run(_ path: String, _ arguments: [String], environment: [String: String] = [:]) async -> Result {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, value in value }
            process.standardInput = FileHandle.nullDevice
            let pipe = Pipe()
            process.standardOutput = pipe
            let structured = arguments.contains { $0.hasPrefix("--json") || $0 == "-plist" }
            process.standardError = structured ? FileHandle.nullDevice : pipe
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                return Result(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
            } catch { return Result(status: -1, output: error.localizedDescription) }
        }.value
    }
}

struct BrewPackage: Identifiable, Sendable {
    enum Kind: String, Sendable { case formula, cask }
    var id: String { kind.rawValue + "/" + token }
    let token: String
    let name: String
    let installed: String
    let available: String?
    let homepage: String?
    let kind: Kind
}

@Observable
final class HomebrewStore {
    static let shared = HomebrewStore()
    private(set) var installed: [BrewPackage] = []
    private(set) var outdated: [BrewPackage] = []
    private(set) var searchResults: [BrewPackage] = []
    private(set) var busy = false
    private(set) var log = ""
    private(set) var message: String?
    var query = ""
    var executable: String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    private let environment = ["HOMEBREW_NO_AUTO_UPDATE": "1", "HOMEBREW_NO_ANALYTICS": "1", "HOMEBREW_NO_ENV_HINTS": "1", "NONINTERACTIVE": "1"]

    func loadInstalled() {
        performRead(["info", "--json=v2", "--installed"]) { result in self.installed = Self.parseInfo(result.output) }
    }
    func checkUpdates() {
        // Refresh metadata only when asked, then inspect installed package versions.
        guard !busy, let executable else { message = "Homebrew ist nicht installiert."; return }
        busy = true; message = "Homebrew-Metadaten werden aktualisiert…"
        Task {
            let update = await MaintenanceCommand.run(executable, ["update"], environment: environment)
            guard update.status == 0 else { finish(update); return }
            let result = await MaintenanceCommand.run(executable, ["outdated", "--json=v2"], environment: environment)
            outdated = Self.parseOutdated(result.output)
            finish(result)
            if result.status == 0 { message = "\(outdated.count) Homebrew-Updates verfügbar." }
        }
    }
    func search() {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard MaintenanceRules.validBrewToken(query), !query.contains("/") else {
            message = "Suche mit einem Paketnamen aus Buchstaben, Zahlen, -, _, +, . oder @."; return
        }
        guard !busy, let executable else { message = "Homebrew ist nicht installiert."; return }
        busy = true; message = nil
        Task {
            let formulas = await MaintenanceCommand.run(executable, ["search", "--formula", query], environment: environment)
            let casks = await MaintenanceCommand.run(executable, ["search", "--cask", query], environment: environment)
            searchResults = (formulas.status == 0 ? Self.parseSearch(formulas.output, kind: .formula) : []) + (casks.status == 0 ? Self.parseSearch(casks.output, kind: .cask) : [])
            finish(casks.status == 0 ? casks : formulas)
            message = "\(searchResults.count) Paketnamen gefunden. Vor der Installation die Herkunft prüfen."
        }
    }
    func info(_ package: BrewPackage) {
        guard MaintenanceRules.validBrewToken(package.token) else { return }
        performRead(["info", package.kind == .cask ? "--cask" : "--formula", package.token]) { _ in }
    }
    func change(_ package: BrewPackage, action: String) {
        guard ["install", "uninstall", "upgrade"].contains(action), MaintenanceRules.validBrewToken(package.token), !busy,
              let executable else { return }
        let title = ["install": "installieren", "uninstall": "deinstallieren", "upgrade": "aktualisieren"][action]!
        let alert = NSAlert()
        alert.messageText = "«\(package.token)» \(title)?"
        alert.informativeText = "Homebrew führt diese Aktion mit deinem Benutzerkonto aus. Pakete können eigene Installationsskripte ausführen und Abhängigkeiten mitbringen. Es wird kein sudo-Passwort entgegengenommen."
        alert.addButton(withTitle: title.prefix(1).uppercased() + title.dropFirst()); alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        busy = true; message = "Homebrew arbeitet. Bitte die App bis zum Abschluss geöffnet lassen."
        Task {
            let result = await MaintenanceCommand.run(executable, [action, package.kind == .cask ? "--cask" : "--formula", package.token], environment: environment)
            if result.status == 0 {
                let inventory = await MaintenanceCommand.run(executable, ["info", "--json=v2", "--installed"], environment: environment)
                installed = Self.parseInfo(inventory.output)
                outdated.removeAll { $0.id == package.id }
            }
            finish(result)
        }
    }
    func upgradeListed() {
        let packages = outdated
        guard !busy, !packages.isEmpty, let executable else { return }
        let alert = NSAlert()
        alert.messageText = "\(packages.count) angezeigte Homebrew-Pakete aktualisieren?"
        alert.informativeText = packages.map(\.token).joined(separator: "\n") + "\n\nPaket-Skripte können ausgeführt werden. Die Updates laufen nacheinander."
        alert.addButton(withTitle: "Alle angezeigten aktualisieren"); alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        busy = true; message = "Homebrew aktualisiert die ausgewählten Pakete…"
        Task {
            var failures: [String] = [], logs: [String] = []
            for package in packages {
                guard MaintenanceRules.validBrewToken(package.token) else { failures.append(package.token); continue }
                let result = await MaintenanceCommand.run(executable, ["upgrade", package.kind == .cask ? "--cask" : "--formula", package.token], environment: environment)
                logs.append(package.token + "\n" + result.output)
                if result.status != 0 { failures.append(package.token) }
                else { outdated.removeAll { $0.id == package.id } }
            }
            log = String(logs.joined(separator: "\n\n").suffix(128_000))
            message = failures.isEmpty ? "Alle angezeigten Updates abgeschlossen." : "Fehlgeschlagen: " + failures.joined(separator: ", ")
            busy = false
        }
    }
    private func performRead(_ arguments: [String], consume: @escaping (MaintenanceCommand.Result) -> Void) {
        guard !busy, let executable else { message = "Homebrew ist nicht installiert. Installation auf brew.sh ist optional."; return }
        busy = true; message = nil
        Task { let result = await MaintenanceCommand.run(executable, arguments, environment: environment); if result.status == 0 { consume(result) }; finish(result) }
    }
    private func finish(_ result: MaintenanceCommand.Result) {
        log = String(result.output.suffix(64_000))
        message = result.status == 0 ? "Abgeschlossen." : "Homebrew meldet Fehler \(result.status). Details stehen im Protokoll."
        busy = false
    }
    nonisolated static func parseInfo(_ text: String) -> [BrewPackage] {
        guard let data = text.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        var packages: [BrewPackage] = []
        for entry in object["formulae"] as? [[String: Any]] ?? [] {
            guard let token = entry["full_name"] as? String ?? entry["name"] as? String, MaintenanceRules.validBrewToken(token) else { continue }
            let versions = (entry["installed"] as? [[String: Any]] ?? []).compactMap { $0["version"] as? String }.joined(separator: ", ")
            packages.append(BrewPackage(token: token, name: entry["name"] as? String ?? token, installed: versions, available: (entry["versions"] as? [String: Any])?["stable"] as? String, homepage: entry["homepage"] as? String, kind: .formula))
        }
        for entry in object["casks"] as? [[String: Any]] ?? [] {
            guard let token = entry["full_token"] as? String ?? entry["token"] as? String, MaintenanceRules.validBrewToken(token) else { continue }
            let version = (entry["installed"] as? String) ?? (entry["installed"] as? [String])?.joined(separator: ", ") ?? ""
            packages.append(BrewPackage(token: token, name: (entry["name"] as? [String])?.first ?? token, installed: version, available: entry["version"] as? String, homepage: entry["homepage"] as? String, kind: .cask))
        }
        return packages.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    nonisolated static func parseOutdated(_ text: String) -> [BrewPackage] {
        guard let data = text.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return [("formulae", BrewPackage.Kind.formula), ("casks", .cask)].flatMap { key, kind in
            (object[key] as? [[String: Any]] ?? []).compactMap { entry -> BrewPackage? in
                guard let token = entry["name"] as? String, MaintenanceRules.validBrewToken(token) else { return nil }
                return BrewPackage(token: token, name: token, installed: (entry["installed_versions"] as? [String])?.joined(separator: ", ") ?? "", available: entry["current_version"] as? String, homepage: nil, kind: kind)
            }
        }
    }
    nonisolated static func parseSearch(_ text: String, kind: BrewPackage.Kind) -> [BrewPackage] {
        var seen: Set<String> = []
        let lines = text.split(separator: "\n").filter { !$0.hasPrefix("==>") && !$0.contains(":") }
        return lines.flatMap { $0.split(whereSeparator: \.isWhitespace) }.map(String.init).filter {
            $0 == $0.lowercased() && MaintenanceRules.validBrewToken($0) && seen.insert($0).inserted
        }.map { BrewPackage(token: $0, name: $0, installed: "", available: nil, homepage: nil, kind: kind) }
    }
}
