// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import VibrantPlusKit

struct PulsiWakeTests {
    @Test func hearsHeyPulsiInGermanVariants() {
        #expect(PulsiWakePhrase.heard("Hey Pulsi"))
        #expect(PulsiWakePhrase.heard("hei pulsi, bist du da"))
        #expect(PulsiWakePhrase.heard("Hallo Pulsi"))
        #expect(PulsiWakePhrase.heard("hü pulsi"))
        #expect(PulsiWakePhrase.heard("Hey Puls i"))
        #expect(PulsiWakePhrase.heard("Hey Pulse"))
        #expect(!PulsiWakePhrase.heard("hey claude"))
        #expect(!PulsiWakePhrase.heard("Pulsi"))
        #expect(!PulsiWakePhrase.heard(""))
    }

    @Test func criesHaveAudibleEnergy() {
        for cry in PulsiCry.allCases {
            let peak = cry.samples().map { abs($0) }.max() ?? 0
            #expect(peak > 0.05)
        }
    }
}
