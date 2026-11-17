// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Conservative, exact ownership rules shared by previews and destructive actions.
public enum MaintenanceRules {
    public static func validBundleID(_ value: String) -> Bool {
        let pieces = value.split(separator: ".", omittingEmptySubsequences: false)
        return pieces.count >= 2 && pieces.allSatisfy { !$0.isEmpty && $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") } }
    }

    public static func validBrewToken(_ value: String) -> Bool {
        guard !value.isEmpty, value.count < 160, !value.hasPrefix("-"), !value.hasPrefix("/"), !value.hasSuffix("/") else { return false }
        let pieces = value.split(separator: "/", omittingEmptySubsequences: false)
        guard pieces.count == 1 || pieces.count == 3 else { return false }
        return pieces.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." && $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "+-_.@".contains($0)) } }
    }

    /// Only immediate children of the supplied cache/log roots are cleaner candidates.
    public static func isCleanerCandidate(_ candidate: URL, roots: [URL]) -> Bool {
        let path = candidate.standardizedFileURL
        return roots.contains { path.deletingLastPathComponent().path == $0.standardizedFileURL.path && path.path != $0.standardizedFileURL.path }
    }

    /// No vendor-name guesses, prefix matching or broad preferences-folder deletion.
    public static func relatedPaths(bundleID: String, home: URL) -> [URL] {
        guard validBundleID(bundleID), !bundleID.hasPrefix("com.apple.") else { return [] }
        return [
            "Library/Caches/\(bundleID)", "Library/Logs/\(bundleID)",
            "Library/Preferences/\(bundleID).plist", "Library/Saved Application State/\(bundleID).savedState",
            "Library/Application Support/\(bundleID)", "Library/Containers/\(bundleID)"
        ].map { home.appendingPathComponent($0) }
    }

    public static func isInstallableApp(_ app: URL, roots: [URL], bundleID: String, ownBundleID: String) -> Bool {
        let app = app.standardizedFileURL
        return app.pathExtension.lowercased() == "app" && app.deletingLastPathComponent().pathExtension.lowercased() != "app"
            && roots.contains { app.deletingLastPathComponent().path == $0.standardizedFileURL.path }
            && validBundleID(bundleID) && bundleID != ownBundleID && !bundleID.hasPrefix("com.apple.")
    }
}
