// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// What a permission card shows, so the person sees exactly what they allow.
/// The body is never cut: the card scrolls instead. Claude's own description of a
/// command is only a note under it, never the headline (it can make a command sound harmless).
public struct PermissionDetail: Equatable, Sendable {
    /// Plain German: what the tool will do ("Befehl ausführen", "Datei schreiben").
    public var title: String
    /// The full command, path, URL or tool input, monospaced in the card.
    public var body: String
    /// Claude's description of a command, shown as «Laut Claude: …».
    public var note: String?
    /// Parts of a command worth a second look (deletes, sudo, piping a download into a shell).
    public var warnings: [String]

    /// The longest written file content shown in the card; the rest is named, not hidden.
    public static let maxContentLines = 40

    public init(tool: String, input: JSONValue?) {
        let path = input?["file_path"]?.string ?? input?["notebook_path"]?.string ?? input?["path"]?.string
        note = nil
        warnings = []
        switch tool {
        case "Bash":
            let command = input?["command"]?.string ?? ""
            title = "Befehl ausführen"
            body = command
            if let d = input?["description"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty { note = d }
            warnings = Self.warnings(for: command)
        case "Write":
            title = "Datei schreiben"
            body = Self.join(path, Self.preview(input?["content"]?.string ?? ""))
        case "Edit", "MultiEdit", "NotebookEdit":
            title = "Datei bearbeiten"
            var new = input?["new_string"]?.string ?? input?["new_source"]?.string ?? ""
            if new.isEmpty, let edits = input?["edits"]?.array {
                new = edits.compactMap { $0["new_string"]?.string }.joined(separator: "\n…\n")
            }
            body = Self.join(path, Self.preview(new))
        case "Read":
            title = "Datei lesen"
            body = path ?? ""
        case "WebFetch":
            title = "Webseite lesen"
            body = input?["url"]?.string ?? ""
        case "WebSearch":
            title = "Im Web suchen"
            body = input?["query"]?.string ?? ""
        default:
            if tool.hasPrefix("mcp__") {
                let parts = tool.split(separator: "__", omittingEmptySubsequences: true).dropFirst()
                title = "Werkzeug " + parts.joined(separator: " · ")
            } else {
                title = tool.isEmpty ? "Werkzeug" : "Werkzeug \(tool)"
            }
            body = Self.pretty(input)
        }
    }

    static func join(_ path: String?, _ text: String) -> String {
        [path, text.isEmpty ? nil : text].compactMap { $0 }.joined(separator: "\n\n")
    }

    /// The first lines of written text, and how many more there are.
    static func preview(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        guard lines.count > maxContentLines else { return text }
        return lines.prefix(maxContentLines).joined(separator: "\n") + "\n… \(lines.count - maxContentLines) weitere Zeilen"
    }

    /// Tool input as indented JSON with sorted keys; "{}" when there is none.
    static func pretty(_ input: JSONValue?) -> String {
        guard let input,
              let data = try? JSONSerialization.data(withJSONObject: input.foundation,
                                                     options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed])
        else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    /// What «Immer erlauben» would add, from Claude Code's `permission_suggestions`, one line each:
    /// "Bash(swift build:*) · dieses Projekt". Unknown entries are named by their type, never dropped.
    public static func alwaysRules(_ suggestions: JSONValue?) -> [String] {
        func place(_ s: JSONValue) -> String? {
            switch s["destination"]?.string {
            case "localSettings": "dieses Projekt, nur für dich"
            case "projectSettings": "dieses Projekt"
            case "userSettings": "alle Projekte"
            case "session": "diese Sitzung"
            case let other?: other
            case nil: nil
            }
        }
        func line(_ text: String, _ s: JSONValue) -> String {
            place(s).map { "\(text) · \($0)" } ?? text
        }
        return (suggestions?.array ?? []).flatMap { s -> [String] in
            switch s["type"]?.string ?? "" {
            case "addRules", "replaceRules":
                let rules = (s["rules"]?.array ?? []).map { r -> String in
                    let tool = r["toolName"]?.string ?? "?"
                    let content = r["ruleContent"]?.string ?? ""
                    return content.isEmpty ? tool : "\(tool)(\(content))"
                }
                return (rules.isEmpty ? ["Regel"] : rules).map { line($0, s) }
            case "setMode":
                let mode = s["mode"]?.string ?? ""
                let text = switch mode {
                case "acceptEdits": "Dateiänderungen ohne Nachfrage"
                case "bypassPermissions": "alles ohne Nachfrage"
                case "plan": "Planmodus"
                case "default": "normaler Modus"
                default: "Modus \(mode)"
                }
                return [line(text, s)]
            case "addDirectories":
                let dirs = (s["directories"]?.array ?? []).compactMap(\.string)
                return dirs.map { line("Zugriff auf \($0)", s) }
            case let type:
                return [line(type.isEmpty ? "unbekannte Regel" : type, s)]
            }
        }
    }

    /// A short, readable list. Not a security filter: it only points the eye.
    public static func warnings(for command: String) -> [String] {
        let c = " " + command.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ") + " "
        var out: [String] = []
        func has(_ any: String...) -> Bool { any.contains { c.contains($0) } }
        if has(" rm ", " rmdir ", " trash ") { out.append("löscht Dateien") }
        if has(" sudo ") { out.append("mit Administratorrechten") }
        if (has("curl ", "wget ")) && has("| sh", "| bash", "| zsh", "|sh", "|bash", "|zsh") { out.append("führt ein heruntergeladenes Skript aus") }
        if has(" git push --force", " git push -f ", " git reset --hard", " git clean -") { out.append("überschreibt Git-Stand") }
        if has(" > ~/", " >~/", " >> ~/", " > /etc/", " chmod ", " chown ") { out.append("ändert Dateien oder Rechte ausserhalb des Projekts") }
        if has(" dd ", " mkfs", " diskutil erase") { out.append("schreibt direkt auf ein Laufwerk") }
        return out
    }
}
