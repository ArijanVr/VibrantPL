// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import VibrantPlusKit

struct PulsiLinesTests {
    @Test func linesStayShortAndSwiss() {
        #expect(PulsiLines.agentDone(project: "Vibrant+") == "Vibrant+ ist fertig.")
        #expect(PulsiLines.agentDone(project: "  ") == "Claude ist fertig.")
        #expect(PulsiLines.stowOffer(count: 1) == "Eine Datei liegt bereit. Soll ich sie umwandeln?")
        #expect(PulsiLines.stowOffer(count: 3).hasPrefix("3 Dateien"))
        #expect(PulsiLines.stowDone(count: 1, failed: false) == "Die Datei ist umgewandelt.")
        #expect(PulsiLines.stowDone(count: 2, failed: true) == "Die Umwandlung ist fehlgeschlagen.")
    }
}
