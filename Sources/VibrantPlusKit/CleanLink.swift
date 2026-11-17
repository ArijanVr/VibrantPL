// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Offline, conservative query cleanup. Never resolves redirects or changes the destination.
public enum CleanLink {
    private static let tracking: Set<String> = [
        "fbclid", "gclid", "dclid", "msclkid", "gbraid", "wbraid", "twclid", "ttclid",
        "mc_cid", "mc_eid", "igshid", "igsh", "_hsenc", "_hsmi", "vero_id", "oly_anon_id", "oly_enc_id"
    ]

    public static func clean(_ text: String) -> String? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parts = URLComponents(string: input),
              let scheme = parts.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil,
              !input.contains(where: { $0.isWhitespace }) else { return nil }
        // Preserve the original encoding, order, duplicate parameters, path and fragment.
        // A signed URL must not be changed: even tracking-looking parameters may be signed.
        guard let queryStart = input.firstIndex(of: "?"),
              input.firstIndex(of: "#").map({ queryStart < $0 }) ?? true else { return input }
        let queryEnd = input[queryStart...].firstIndex(of: "#") ?? input.endIndex
        let query = input[input.index(after: queryStart)..<queryEnd]
        let fields = query.split(separator: "&", omittingEmptySubsequences: false)
        let keys = fields.map { String($0.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)[0]).removingPercentEncoding?.lowercased() ?? "" }
        if keys.contains(where: { $0 == "signature" || $0 == "sig" || $0 == "token" || $0.hasPrefix("x-amz-") || $0.hasPrefix("x-goog-") }) { return input }
        let kept = zip(fields, keys).filter { !($0.1.hasPrefix("utm_") || tracking.contains($0.1)) }.map { String($0.0) }
        guard kept.count != fields.count else { return input }
        return String(input[..<queryStart]) + (kept.isEmpty ? "" : "?" + kept.joined(separator: "&")) + String(input[queryEnd...])
    }
}
