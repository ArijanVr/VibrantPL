// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import VibrantPlusKit

struct AppUpdateOfferTests {
    @Test func skippedVersionIsNotOfferedAgainButANewerOneIs() {
        let v110 = AppVersion.parse("1.1.0")!
        #expect(AppUpdatePlan.shouldOffer(v110, skipped: nil))
        #expect(!AppUpdatePlan.shouldOffer(v110, skipped: "1.1.0"))
        #expect(!AppUpdatePlan.shouldOffer(v110, skipped: "1.2"))
        #expect(AppUpdatePlan.shouldOffer(AppVersion.parse("1.1.1")!, skipped: "1.1.0"))
        #expect(AppUpdatePlan.shouldOffer(v110, skipped: "kaputt"))
    }

    @Test func notesBecomeOneShortLine() {
        #expect(AppUpdatePlan.summary("## Neu\n\n- **Licht** über der Insel\n- `Codex` verbunden\n- drei\n- vier") == "Neu · Licht über der Insel · Codex verbunden")
        #expect(AppUpdatePlan.summary(nil) == nil)
        #expect(AppUpdatePlan.summary("  \n# \n") == nil)
        #expect(AppUpdatePlan.summary(String(repeating: "a", count: 300), limit: 20)?.count == 20)
    }

    @Test func releaseNotesDecodeAndMayBeMissing() throws {
        let json = #"{"tag_name":"v1.1.0","html_url":"https://github.com/x/y","assets":[],"body":"Neu"}"#
        #expect(try JSONDecoder().decode(GitHubRelease.self, from: Data(json.utf8)).body == "Neu")
        let bare = #"{"tag_name":"v1.1.0","html_url":"https://github.com/x/y","assets":[]}"#
        #expect(try JSONDecoder().decode(GitHubRelease.self, from: Data(bare.utf8)).body == nil)
    }
}
