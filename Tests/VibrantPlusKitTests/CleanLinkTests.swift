// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import VibrantPlusKit

struct CleanLinkTests {
    @Test func removesTrackingPreservingFunctionalQueryAndFragment() {
        #expect(CleanLink.clean("https://example.com/a%2Fb?utm_source=mail&q=a%20b&tag=1&tag=2&fbclid=x#part") == "https://example.com/a%2Fb?q=a%20b&tag=1&tag=2#part")
    }
    @Test func noEmptyQueryAfterCleaning() {
        #expect(CleanLink.clean("https://example.com/?gclid=x&utm_campaign=y#top") == "https://example.com/#top")
    }
    @Test func encodedAndMixedCaseTrackingKeys() {
        #expect(CleanLink.clean("https://example.com/?%75tm_source=a&FBCLID=b&ref=book") == "https://example.com/?ref=book")
    }
    @Test func leavesSignedURLsUntouched() {
        for query in ["sig=abc&utm_source=a", "X-Amz-Signature=abc&gclid=b", "token=abc&fbclid=x", "X-Goog-Credential=a&utm_medium=b"] {
            let url = "https://example.com/?" + query
            #expect(CleanLink.clean(url) == url)
        }
    }
    @Test func rejectsNonWebAndCredentials() {
        for input in ["file:///etc/passwd", "javascript:alert(1)", "https://u:p@example.com/", "example.com", "https://", "https://example.com/a b"] {
            #expect(CleanLink.clean(input) == nil)
        }
    }
    @Test func preservesOrdinaryLinksAndFragmentQuery() {
        for url in ["https://example.com/", "https://example.com/?q=foo+bar&ref=home", "https://example.com/#page?utm_source=x"] {
            #expect(CleanLink.clean(url) == url)
        }
    }
}
