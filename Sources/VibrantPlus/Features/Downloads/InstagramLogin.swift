// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import WebKit
import VibrantPlusKit

/// The person's own Instagram login for downloads. The real login page runs in a web view with a data store
/// of its own (apart from Safari). Vibrant+ never reads the form or the password. For one yt-dlp run it copies
/// the instagram.com cookies into a private temporary file, which the caller deletes right after the run.
@Observable
final class InstagramLogin: NSObject, NSWindowDelegate, WKNavigationDelegate {
    static let shared = InstagramLogin()

    private(set) var signedIn = false

    /// Fixed, so the login survives a restart.
    private static let storeID = UUID(uuidString: "6A1F3C2E-9B4D-4E7A-8C21-5D0B7E3F9A14")!
    private static let loginPage = URL(string: "https://www.instagram.com/accounts/login/")!

    @ObservationIgnored private lazy var store = WKWebsiteDataStore(forIdentifier: Self.storeID)
    @ObservationIgnored private var window: NSWindow?

    // MARK: Status

    func refresh() async {
        signedIn = DownloadPlan.hasSession(await cookies())
    }

    private func cookies() async -> [DownloadPlan.Cookie] {
        await store.httpCookieStore.allCookies()
            .filter { $0.domain.lowercased().hasSuffix("instagram.com") }
            .map { DownloadPlan.Cookie(domain: $0.domain, path: $0.path, secure: $0.isSecure,
                                       expires: $0.expiresDate, name: $0.name, value: $0.value) }
    }

    // MARK: Sign in and out

    func open() {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(); return }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = store
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 440, height: 640), configuration: config)
        web.navigationDelegate = self
        web.load(URLRequest(url: Self.loginPage))
        let w = NSWindow(contentRect: web.frame, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        w.title = "Bei Instagram anmelden"
        w.contentView = web
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func signOut() async {
        window?.close()
        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        await refresh()
    }

    func windowWillClose(_ notification: Notification) {
        (window?.contentView as? WKWebView)?.navigationDelegate = nil
        window = nil
        Task { await refresh() }
    }

    /// Closes the window once Instagram shows anything past its login and confirmation pages.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task {
            await refresh()
            guard signedIn, let path = webView.url?.path,
                  !path.hasPrefix("/accounts/"), !path.hasPrefix("/challenge") else { return }
            window?.close()
            IslandModel.shared.show(Toast(symbol: "person.crop.circle.badge.checkmark", text: "Bei Instagram angemeldet"))
        }
    }

    // MARK: Cookies for one yt-dlp run

    /// A private folder with `cookies.txt` (0600) for yt-dlp, or nil when not signed in. Delete the folder after the run.
    func cookieFolder() async -> URL? {
        let cookies = await cookies()
        guard DownloadPlan.hasSession(cookies) else { signedIn = false; return nil }
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appending(path: "VibrantPlus-login-\(UUID().uuidString)")
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            let file = folder.appending(path: "cookies.txt")
            guard fm.createFile(atPath: file.path, contents: Data(DownloadPlan.netscapeCookies(cookies).utf8),
                                attributes: [.posixPermissions: 0o600]) else {
                try? fm.removeItem(at: folder)
                return nil
            }
            return folder
        } catch {
            try? fm.removeItem(at: folder)
            return nil
        }
    }
}
