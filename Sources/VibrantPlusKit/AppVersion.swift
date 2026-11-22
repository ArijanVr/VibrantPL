// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct AppVersion: Comparable, Equatable, Sendable {
    public let parts: [Int]

    public init(parts: [Int]) { self.parts = parts.isEmpty ? [0] : parts }

    public static func parse(_ raw: String) -> AppVersion? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        let nums = s.split(separator: ".").compactMap { Int($0) }
        guard !nums.isEmpty, nums.count == s.split(separator: ".").count else { return nil }
        return AppVersion(parts: nums)
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let n = max(lhs.parts.count, rhs.parts.count)
        for i in 0..<n {
            let a = i < lhs.parts.count ? lhs.parts[i] : 0
            let b = i < rhs.parts.count ? rhs.parts[i] : 0
            if a != b { return a < b }
        }
        return false
    }

    public var display: String { parts.map(String.init).joined(separator: ".") }
}

public enum AppUpdatePlan {
    public static let repo = "ArijanVr/VibrantPL"
    public static let apiLatest = URL(string: "https://api.github.com/repos/ArijanVr/VibrantPL/releases/latest")!

    public static func zipName(version: String) -> String { "Vibrant+-\(version).zip" }

    public static func isAllowedDownload(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let ok = host == "github.com" || host.hasSuffix(".github.com") || host.hasSuffix("githubusercontent.com")
        return ok && (url.scheme == "https")
    }

    /// A found version is offered unless the person skipped it or a newer one.
    public static func shouldOffer(_ found: AppVersion, skipped: String?) -> Bool {
        guard let skipped, let last = AppVersion.parse(skipped) else { return true }
        return found > last
    }

    /// The first lines of the release notes as plain text, for a short card. Markdown marks are dropped.
    public static func summary(_ notes: String?, limit: Int = 140) -> String? {
        guard let notes else { return nil }
        let lines = notes.split(whereSeparator: \.isNewline).map { line -> String in
            var text = line.trimmingCharacters(in: .whitespaces)
            while let first = text.first, "#*->_`".contains(first) { text.removeFirst() }
            return text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
                .trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }
        let joined = lines.prefix(3).joined(separator: " · ")
        return joined.count > limit ? String(joined.prefix(limit - 1)) + "…" : joined
    }

    /// Newest `Vibrant+-x.y.z.zip` from release folder names like `2026-11-17_v1.0.3`.
    public static func newestICloud(folderNames: [String]) -> AppVersion? {
        folderNames.compactMap { name -> AppVersion? in
            guard let range = name.range(of: "_v") else { return AppVersion.parse(name) }
            return AppVersion.parse(String(name[range.upperBound...]).split(separator: "_").first.map(String.init) ?? "")
        }.max()
    }
}

public struct GitHubRelease: Decodable, Sendable {
    public var tagName: String
    public var htmlURL: String
    public var assets: [Asset]
    /// The release notes (Markdown), when the release has any.
    public var body: String?
    public enum CodingKeys: String, CodingKey { case tagName = "tag_name", htmlURL = "html_url", assets, body }
    public struct Asset: Decodable, Sendable {
        public var name: String
        public var browserDownloadURL: URL
        public enum CodingKeys: String, CodingKey { case name, browserDownloadURL = "browser_download_url" }
    }

    public var version: AppVersion? { AppVersion.parse(tagName) }

    public func zipAsset() -> Asset? {
        assets.first { $0.name.hasPrefix("Vibrant+-") && $0.name.hasSuffix(".zip") && AppUpdatePlan.isAllowedDownload($0.browserDownloadURL) }
    }
}
