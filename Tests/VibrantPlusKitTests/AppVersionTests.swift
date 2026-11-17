// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import VibrantPlusKit

struct AppVersionTests {
    @Test func comparesAndParsesTags() {
        #expect(AppVersion.parse("v1.0.2")! < AppVersion.parse("1.1")!)
        #expect(AppVersion.parse("1.0.2")! == AppVersion.parse("v1.0.2")!)
        #expect(AppVersion.parse("1.0")! < AppVersion.parse("1.0.1")!)
        #expect(AppVersion.parse("nope") == nil)
        #expect(AppUpdatePlan.zipName(version: "1.0.3") == "Vibrant+-1.0.3.zip")
        #expect(AppUpdatePlan.isAllowedDownload(URL(string: "https://github.com/ArijanVr/VibrantPlus/releases/download/v1.0.3/Vibrant+-1.0.3.zip")!))
        #expect(!AppUpdatePlan.isAllowedDownload(URL(string: "http://evil.example/a.zip")!))
        #expect(AppUpdatePlan.newestICloud(folderNames: ["2026-01-01_v1.0.1", "2026-11-17_v1.0.3", "notes"])?.display == "1.0.3")
    }

    @Test func picksZipFromGitHubPayload() throws {
        let json = Data("""
        {"tag_name":"v1.0.3","html_url":"https://github.com/ArijanVr/VibrantPlus/releases/tag/v1.0.3","assets":[{"name":"Vibrant+-1.0.3.zip","browser_download_url":"https://github.com/ArijanVr/VibrantPlus/releases/download/v1.0.3/Vibrant+-1.0.3.zip"}]}
        """.utf8)
        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        #expect(release.version?.display == "1.0.3")
        #expect(release.zipAsset()?.name == "Vibrant+-1.0.3.zip")
    }
}
