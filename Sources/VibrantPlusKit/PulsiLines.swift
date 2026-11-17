// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Short spoken lines for Pulsi. Swiss German spelling, no ß.
public enum PulsiLines {
    public static func agentDone(project: String) -> String {
        let name = project.trimmingCharacters(in: .whitespacesAndNewlines)
        return (name.isEmpty ? "Claude" : name) + " ist fertig."
    }

    public static func stowOffer(count: Int) -> String {
        if count <= 0 { return "Diese Dateien kann ich nicht umwandeln." }
        if count == 1 { return "Eine Datei liegt bereit. Soll ich sie umwandeln?" }
        return "\(count) Dateien liegen bereit. Soll ich sie umwandeln?"
    }

    public static func stowDone(count: Int, failed: Bool) -> String {
        if failed { return "Die Umwandlung ist fehlgeschlagen." }
        return count == 1 ? "Die Datei ist umgewandelt." : "Die Dateien sind umgewandelt."
    }
}
