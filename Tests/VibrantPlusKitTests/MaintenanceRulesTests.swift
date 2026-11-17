// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import VibrantPlusKit

struct MaintenanceRulesTests {
    @Test func bundleIDsCannotEscapeAndAppleIsExcluded() {
        for id in ["../com.app", "com/app", "com..app", "com.app;rm", "", "com.app\nother"] {
            #expect(!MaintenanceRules.validBundleID(id))
        }
        let home = URL(fileURLWithPath: "/tmp/vp-maintenance-test")
        #expect(MaintenanceRules.relatedPaths(bundleID: "com.example.editor", home: home).count == 6)
        #expect(MaintenanceRules.relatedPaths(bundleID: "com.apple.finder", home: home).isEmpty)
        #expect(!MaintenanceRules.relatedPaths(bundleID: "com.example.editor", home: home).contains { $0.path.hasSuffix("Application Support/Editor") })
    }
    @Test func cleanerAcceptsOnlyImmediateChildren() {
        let root = URL(fileURLWithPath: "/tmp/vp-test/Library/Caches")
        #expect(MaintenanceRules.isCleanerCandidate(root.appending(path: "com.example.app"), roots: [root]))
        #expect(!MaintenanceRules.isCleanerCandidate(root, roots: [root]))
        #expect(!MaintenanceRules.isCleanerCandidate(root.appending(path: "../Preferences"), roots: [root]))
        #expect(!MaintenanceRules.isCleanerCandidate(root.appending(path: "App/child"), roots: [root]))
    }
    @Test func brewTokensCannotBeOptionsPathsOrShellCommands() {
        for token in ["ffmpeg", "visual-studio-code", "python@3.13", "homebrew/cask/firefox", "libc++"] {
            #expect(MaintenanceRules.validBrewToken(token))
        }
        for token in ["--force", "/tmp/pkg", "foo bar", "$(id)", "foo;id", "../../x", "a//b", "foo\nbar", "foo/bar"] {
            #expect(!MaintenanceRules.validBrewToken(token))
        }
    }
    @Test func uninstallerCannotSelectSystemOwnOrNestedBundles() {
        let roots = [URL(fileURLWithPath: "/Applications")]
        let own = "ch.arjo.vibrantplus"
        #expect(MaintenanceRules.isInstallableApp(URL(fileURLWithPath: "/Applications/Editor.app"), roots: roots, bundleID: "com.example.editor", ownBundleID: own))
        #expect(!MaintenanceRules.isInstallableApp(URL(fileURLWithPath: "/System/Applications/Notes.app"), roots: roots, bundleID: "com.apple.Notes", ownBundleID: own))
        #expect(!MaintenanceRules.isInstallableApp(URL(fileURLWithPath: "/Applications/Vibrant+.app"), roots: roots, bundleID: own, ownBundleID: own))
        #expect(!MaintenanceRules.isInstallableApp(URL(fileURLWithPath: "/Applications/Editor.app/Helper.app"), roots: roots, bundleID: "com.example.helper", ownBundleID: own))
    }
}
