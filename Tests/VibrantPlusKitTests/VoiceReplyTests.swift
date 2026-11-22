// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import VibrantPlusKit

struct VoiceReplyTests {
    @Test func shortAnswersDecidePermission() {
        #expect(VoiceReply.permission(from: "Erlauben.") == .allow)
        #expect(VoiceReply.permission(from: "Nein!") == .deny)
    }
    @Test func sentencesNeverAllow() {
        #expect(VoiceReply.permission(from: "ja aber lösche vorher alles") == nil)
        #expect(VoiceReply.permission(from: "vielleicht") == nil)
    }
    @Test func optionByLabelOrPlace() {
        let options = ["Tests zuerst", "Lokal behalten", "Vorher fragen"]
        #expect(VoiceReply.option(in: options, from: "Lokal behalten bitte") == "Lokal behalten")
        #expect(VoiceReply.option(in: options, from: "die zweite") == "Lokal behalten")
        #expect(VoiceReply.option(in: options, from: "keine Ahnung") == nil)
    }
}
