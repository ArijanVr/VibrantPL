// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import AVFoundation
import Foundation
import Observation
import VibrantPlusKit

extension DownloadFormat {
    var title: String {
        switch self {
        case .video: "Video"
        case .audio: "Audio"
        case .image: "Bild"
        }
    }

    var symbol: String {
        switch self {
        case .video: "film"
        case .audio: "music.note"
        case .image: "photo"
        }
    }
}

/// One download in the list.
@Observable
final class DownloadItem: Identifiable {
    enum State: Equatable {
        case preparing
        case loading(Double?)
        case done(URL)
        case failed(String)
        case cancelled
    }

    let id = UUID()
    let link: URL
    let format: DownloadFormat
    var title: String
    var state: State = .preparing
    var bytes: Int64 = 0
    @ObservationIgnored var cancelAction: (() -> Void)?

    init(link: URL, format: DownloadFormat) {
        self.link = link
        self.format = format
        title = link.host ?? link.absoluteString
    }

    var isRunning: Bool {
        switch state {
        case .preparing, .loading: true
        default: false
        }
    }
}

/// Loads a picture, video or sound from a link. Direct file links with URLSession; links to platforms
/// (YouTube, Instagram, Vimeo …) with yt-dlp, if the person installed it. Vibrant+ does not bundle yt-dlp and
/// never tries to get around copy protection (DRM). Content behind a login only with the person's own
/// Instagram login (`InstagramLogin`).
@Observable
final class Downloads {
    static let shared = Downloads()

    private(set) var items: [DownloadItem] = []
    private(set) var ytDlp: String?
    private(set) var ffmpeg: String?

    private init() { findTools() }

    /// The download that is under way right now (the newest one), for the progress beside the notch.
    var running: DownloadItem? { items.first(where: \.isRunning) }

    /// For snapshots: one download at 42 %.
    func loadSample() {
        let item = DownloadItem(link: URL(string: "https://example.com/film.mp4")!, format: .video)
        item.state = .loading(0.42)
        items = [item]
    }
    func clearSample() { items = [] }

    /// Where files land: the chosen folder, else Downloads.
    var folder: URL {
        let path = Prefs.shared.downloadFolder
        var isDir: ObjCBool = false
        if !path.isEmpty, FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
    }

    /// Looks again for yt-dlp and ffmpeg (cheap: a few file checks). Called before each platform download.
    func findTools() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fm = FileManager.default
        ytDlp = DownloadPlan.toolCandidates("yt-dlp", home: home).first { fm.isExecutableFile(atPath: $0) }
        ffmpeg = DownloadPlan.toolCandidates("ffmpeg", home: home).first { fm.isExecutableFile(atPath: $0) }
    }

    /// The link in the clipboard, if it holds one.
    static var clipboardLink: URL? {
        let pb = NSPasteboard.general
        if let s = pb.string(forType: .URL) ?? pb.string(forType: .string) { return DownloadPlan.link(from: s) }
        return nil
    }

    /// From the menu bar: loads the copied link and says so in the island.
    func startFromClipboard(_ format: DownloadFormat) {
        guard let url = Self.clipboardLink else {
            IslandModel.shared.show(Toast(symbol: "link", text: "Kein Link in der Zwischenablage", warm: true))
            return
        }
        start(url, format: format)
        if Prefs.shared.isOn(.island) { IslandController.shared.open(page: .downloads) }
    }

    /// Starts a download. Returns nil (and says why) when the link is not loaded at all.
    @discardableResult
    func start(_ url: URL, format: DownloadFormat) -> DownloadItem? {
        let kind = DownloadPlan.classify(url)
        if kind == .protected {
            IslandModel.shared.show(Toast(symbol: "lock", text: "Kopiergeschützter Dienst (DRM): Vibrant+ lädt hier nichts", warm: true), seconds: 6)
            return nil
        }
        let item = DownloadItem(link: url, format: format)
        // A new try replaces earlier failed or cancelled rows of the same link, so «Nochmals» adds no duplicates.
        items.removeAll { old in
            switch old.state {
            case .failed, .cancelled: old.link == url
            default: false
            }
        }
        items.insert(item, at: 0)
        if items.count > 20 { items.removeLast(items.count - 20) }
        switch kind {
        case .direct: direct(item, url: url, fallback: false)
        case .platform: platform(item)
        case .other: direct(item, url: url, fallback: true)
        case .protected: break
        }
        return item
    }

    func cancel(_ item: DownloadItem) {
        item.cancelAction?()
        item.cancelAction = nil
        if item.isRunning { item.state = .cancelled }
    }

    func remove(_ item: DownloadItem) {
        cancel(item)
        items.removeAll { $0.id == item.id }
    }

    func clearFinished() { items.removeAll { !$0.isRunning } }

    func cancelAll() { items.filter(\.isRunning).forEach(cancel) }

    // MARK: Direct links

    /// `fallback`: a web page instead of a file goes on to yt-dlp (many sites embed their video).
    private func direct(_ item: DownloadItem, url: URL, fallback: Bool) {
        item.state = .loading(nil)
        let transfer = DirectTransfer(url: url, folder: folder) { [weak item] done, total in
            Task { @MainActor in
                guard let item, item.isRunning else { return }
                item.bytes = done
                item.state = .loading(total > 0 ? min(1, Double(done) / Double(total)) : nil)
            }
        } finished: { [weak self, weak item] result in
            Task { @MainActor in
                guard let self, let item, item.state != .cancelled else { return }
                item.cancelAction = nil
                switch result {
                case .file(let file): self.finish(item, file)
                case .notMedia:
                    if fallback { self.platform(item) } else { self.fail(item, "Unter diesem Link liegt keine Datei") }
                case .failed(let reason): self.fail(item, reason)
                }
            }
        }
        item.cancelAction = { transfer.cancel() }
        transfer.start()
    }

    // MARK: Platforms (yt-dlp)

    /// `asImage`: loads the picture(s) of the post, also when the person asked for a video of a picture post.
    private func platform(_ item: DownloadItem, asImage: Bool = false) {
        findTools()
        guard let tool = ytDlp else {
            fail(item, "Für diesen Link braucht es yt-dlp: im Terminal «brew install yt-dlp ffmpeg»")
            return
        }
        let format = asImage ? .image : item.format
        let audio = Prefs.shared.downloadAudio
        if DownloadPlan.needsFFmpeg(format, audio: audio), ffmpeg == nil {
            fail(item, "MP3 braucht ffmpeg: im Terminal «brew install ffmpeg» oder M4A wählen")
            return
        }
        item.state = .preparing
        let login = InstagramLogin.shared
        let useLogin = DownloadPlan.isInstagram(item.link) && login.signedIn
        let prepare = Task { [weak self, weak item] in
            // The person's own Instagram login, as a private file only for this run.
            let cookies = useLogin ? await login.cookieFolder() : nil
            guard let self, let item, item.isRunning else {
                if let cookies { try? FileManager.default.removeItem(at: cookies) }
                return
            }
            self.run(tool, item: item, format: format, audio: audio, cookies: cookies)
        }
        item.cancelAction = { prepare.cancel() }
    }

    private func run(_ tool: String, item: DownloadItem, format: DownloadFormat, audio: AudioFormat, cookies: URL?) {
        let args = DownloadPlan.ytDlpArguments(url: item.link, format: format, audio: audio, folder: folder,
                                               ffmpeg: ffmpeg, cookies: cookies?.appending(path: "cookies.txt").path,
                                               quality: Prefs.shared.downloadQuality)
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = DownloadPlan.toolPath
        let process = LineProcess(path: tool, arguments: args, environment: env)
        nonisolated(unsafe) var file: String?
        nonisolated(unsafe) var thumbs: [String] = []
        do {
            try process.run { [weak item] line in
                guard let parsed = DownloadPlan.parse(line) else { return }
                switch parsed {
                case .file(let f): file = f
                case .thumbnail(let t): thumbs.append(t)
                default: break
                }
                Task { @MainActor [weak item] in
                    guard let item, item.isRunning else { return }
                    switch parsed {
                    case .progress(let done, let total):
                        item.bytes = done
                        item.state = .loading(total.map { $0 > 0 ? min(1, Double(done) / Double($0)) : 0 })
                    case .title(let t): item.title = t
                    case .file, .thumbnail: break
                    }
                }
            } onExit: { [weak self, weak item] status, errors in
                // yt-dlp writes the cookie file back at the end: delete the copy only now, on every outcome.
                if let cookies { try? FileManager.default.removeItem(at: cookies) }
                let file = file, thumbs = thumbs.compactMap(URL.init(string:))
                Task { @MainActor in
                    guard let self, let item, item.state != .cancelled else { return }
                    item.cancelAction = nil
                    self.finishRun(item, format: format, status: status, errors: errors, file: file, thumbs: thumbs,
                                   usedLogin: cookies != nil)
                }
            }
        } catch {
            if let cookies { try? FileManager.default.removeItem(at: cookies) }
            fail(item, "yt-dlp liess sich nicht starten")
            return
        }
        item.cancelAction = { process.cancel() }
    }

    private func finishRun(_ item: DownloadItem, format: DownloadFormat, status: Int32, errors: String, file: String?,
                           thumbs: [URL], usedLogin: Bool) {
        if status == 0, let file, FileManager.default.fileExists(atPath: file) {
            if format == .video { makePlayable(item, URL(fileURLWithPath: file)) } else { finish(item, URL(fileURLWithPath: file)) }
        } else if format == .image, !thumbs.isEmpty {
            images(item, thumbs)
        } else if format != .image, DownloadPlan.isPictureOnly(error: errors) {
            // A picture post: load its picture(s) in full size instead.
            platform(item, asImage: true)
        } else if status == 0, format == .image {
            pageImage(item, otherwise: "yt-dlp hat nichts geliefert")
        } else if status == 0 {
            fail(item, "yt-dlp hat nichts geliefert")
        } else if !usedLogin, DownloadPlan.mayUsePageImage(format: format, error: errors) {
            pageImage(item, otherwise: DownloadPlan.reason(fromError: errors))
        } else {
            var reason = DownloadPlan.reason(fromError: errors)
            if usedLogin, errors.lowercased().contains("failed to parse json") {
                // Instagram answers an expired or blocked session with an empty page.
                reason = "Instagram hat die Anmeldung nicht angenommen: Einstellungen › Herunterladen › Neu anmelden"
            } else if DownloadPlan.isInstagram(item.link),
                      DownloadPlan.needsLogin(error: errors) || (!usedLogin && DownloadPlan.isInstagramStoryLike(item.link)) {
                reason += usedLogin ? ". Auch dein Konto sieht diesen Beitrag nicht"
                                    : ". Anmelden: Einstellungen › Herunterladen › Bei Instagram anmelden"
            }
            fail(item, reason)
        }
    }

    /// The pictures of a post: the first into `item`, every further one (carousel) as its own row.
    private func images(_ item: DownloadItem, _ urls: [URL]) {
        if item.format != .image {
            IslandModel.shared.show(Toast(symbol: "photo", text: "Kein Video im Beitrag, Bild geladen"), seconds: 4)
        }
        direct(item, url: urls[0], fallback: false)
        let index = items.firstIndex { $0.id == item.id } ?? 0
        for (offset, url) in urls.dropFirst().enumerated() {
            let extra = DownloadItem(link: item.link, format: .image)
            extra.title = "\(item.title) (\(offset + 2))"
            items.insert(extra, at: min(items.count, index + 1 + offset))
            direct(extra, url: url, fallback: false)
        }
        if items.count > 30 { items.removeLast(items.count - 30) }
    }

    // MARK: Public preview picture

    /// When yt-dlp finds no video (Instagram picture posts) or no picture: loads the public page without
    /// cookies and takes the preview picture it names for link previews. Otherwise shows `otherwise`.
    private func pageImage(_ item: DownloadItem, otherwise reason: String) {
        item.state = .loading(nil)
        let wantedVideo = item.format != .image
        let task = Task { [weak self, weak item] in
            let html = await Self.publicPage(item?.link)
            guard let self, let item, item.isRunning else { return }
            guard let html, let image = DownloadPlan.pageImage(fromHTML: html, base: item.link) else {
                self.fail(item, reason)
                return
            }
            if wantedVideo {
                IslandModel.shared.show(Toast(symbol: "photo", text: "Kein Video im Beitrag, Bild geladen"), seconds: 4)
            }
            self.direct(item, url: image, fallback: false)
        }
        item.cancelAction = { task.cancel() }
    }

    /// The page as text: no cookies, 20 s, at most 3 MB. nil on any error.
    @concurrent nonisolated private static func publicPage(_ url: URL?) async -> String? {
        guard let url else { return nil }
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 20
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        do {
            let (bytes, response) = try await session.bytes(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            var data = Data()
            data.reserveCapacity(1 << 20)
            for try await byte in bytes {
                data.append(byte)
                if data.count >= 3 << 20 { break }
            }
            return String(decoding: data, as: UTF8.self)
        } catch {
            return nil
        }
    }

    // MARK: Results

    // MARK: QuickTime

    /// Some platforms (Instagram) only hand out VP9 or AV1, also inside an MP4. QuickTime Player refuses
    /// those, so such a video is converted once to H.264 with ffmpeg. Without ffmpeg, or when the
    /// conversion fails, the file stays as it was loaded.
    private func makePlayable(_ item: DownloadItem, _ file: URL) {
        guard let ffmpeg else { finish(item, file); return }
        item.state = .loading(nil)
        Task { [weak self, weak item] in
            let codecs = await Self.codecs(of: file)
            guard let self, let item, item.state != .cancelled else { return }
            guard DownloadPlan.needsQuickTimeConversion(fileExtension: file.pathExtension, videoCodec: codecs.video) else {
                self.finish(item, file)
                return
            }
            IslandModel.shared.show(Toast(symbol: "film", text: "Wird für QuickTime umgewandelt …"), seconds: 30)
            let temp = file.deletingLastPathComponent().appending(path: ".vibrant-\(UUID().uuidString).mp4")
            let r = await Run.async(ffmpeg, DownloadPlan.quickTimeArguments(input: file.path, output: temp.path,
                                                                            copyAudio: ["mp4a", "aac"].contains(codecs.audio ?? "")), timeout: 1800)
            let fm = FileManager.default
            guard r.status == 0, fm.fileExists(atPath: temp.path), item.state != .cancelled else {
                try? fm.removeItem(at: temp)
                if item.state != .cancelled { self.finish(item, file) }
                return
            }
            // The converted file takes the original's place (as .mp4, also when a .webm arrived).
            // A file of that name that is already there belongs to someone else: it is never
            // overwritten, the converted film gets «(2)» instead.
            let target = file.deletingPathExtension().appendingPathExtension("mp4")
            let destination = target == file ? target : Self.freeURL(target)
            if destination == file { try? fm.removeItem(at: file) }
            do {
                try fm.moveItem(at: temp, to: destination)
                if destination != file { try? fm.removeItem(at: file) }
                self.finish(item, destination)
            } catch {
                self.finish(item, temp)
            }
        }
    }

    /// A free name next to `url`: «Film (2).mp4» instead of a file that is already there.
    nonisolated static func freeURL(_ url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }
        let dir = url.deletingLastPathComponent()
        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        for i in 2...999 {
            let candidate = dir.appendingPathComponent("\(name) (\(i))").appendingPathExtension(ext)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
        }
        return url
    }

    /// The four-character codes of the first video and sound track ("avc1", "vp09", "mp4a"), nil when unreadable.
    private nonisolated static func codecs(of file: URL) async -> (video: String?, audio: String?) {
        let asset = AVURLAsset(url: file)
        func code(_ type: AVMediaType) async -> String? {
            guard let track = try? await asset.loadTracks(withMediaType: type).first,
                  let description = try? await track.load(.formatDescriptions).first else { return nil }
            let c = description.mediaSubType.rawValue
            let bytes = [UInt8(c >> 24 & 0xFF), UInt8(c >> 16 & 0xFF), UInt8(c >> 8 & 0xFF), UInt8(c & 0xFF)]
            return String(bytes: bytes, encoding: .ascii)?.trimmingCharacters(in: .whitespaces)
        }
        return (await code(.video), await code(.audio))
    }

    private func finish(_ item: DownloadItem, _ file: URL) {
        item.state = .done(file)
        item.title = file.lastPathComponent
        IslandModel.shared.show(Toast(symbol: "arrow.down.circle", text: "Geladen: \(file.lastPathComponent)"))
    }

    private func fail(_ item: DownloadItem, _ reason: String) {
        item.state = .failed(reason)
        IslandModel.shared.show(Toast(symbol: "exclamationmark.triangle", text: reason, warm: true), seconds: 6)
    }

    // MARK: Self test

    /// Loads `url` straight into `folder` and returns the file. For the self test (file URLs work too).
    func loadDirectly(_ url: URL, into folder: URL) async -> URL? {
        await withCheckedContinuation { cont in
            let t = DirectTransfer(url: url, folder: folder, progress: { _, _ in }) { result in
                if case .file(let f) = result { cont.resume(returning: f) } else { cont.resume(returning: nil) }
            }
            t.start()
        }
    }
}

// MARK: - Transfer helpers (off the main thread)

/// One direct download with URLSession: progress, then the file moved into the folder under a safe, free name.
nonisolated final class DirectTransfer: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    enum Outcome: Sendable {
        case file(URL)
        case notMedia
        case failed(String)
    }

    private let url: URL
    private let folder: URL
    private let progress: @Sendable (Int64, Int64) -> Void
    private let finished: @Sendable (Outcome) -> Void
    private let lock = NSLock()
    private var outcome: Outcome?
    private var lastReport = Date.distantPast
    private var session: URLSession?
    private var task: URLSessionDownloadTask?

    init(url: URL, folder: URL, progress: @escaping @Sendable (Int64, Int64) -> Void,
         finished: @escaping @Sendable (Outcome) -> Void) {
        self.url = url
        self.folder = folder
        self.progress = progress
        self.finished = finished
    }

    func start() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.downloadTask(with: url)
        lock.withLock { self.session = session; self.task = task }
        task.resume()
    }

    func cancel() {
        lock.withLock { task }?.cancel()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let now = Date()
        let report = lock.withLock {
            guard now.timeIntervalSince(lastReport) > 0.1 else { return false }
            lastReport = now
            return true
        }
        if report { progress(totalBytesWritten, totalBytesExpectedToWrite) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let response = downloadTask.response
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            set(.failed(http.statusCode == 404 ? "Nicht gefunden (404)" : "Server antwortet mit Fehler \(http.statusCode)"))
            return
        }
        let mime = response?.mimeType
        let byExtension = DownloadPlan.classify(url) != .other
        guard DownloadPlan.format(mime: mime) != nil || (byExtension && mime != "text/html") else {
            set(.notMedia)
            return
        }
        let name = DownloadPlan.fileName(suggested: response?.suggestedFilename, url: response?.url ?? url, mime: mime)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let dest = CapturePlan.freeURL(in: folder, name: name)
            try FileManager.default.moveItem(at: location, to: dest)
            set(.file(dest))
        } catch {
            set(.failed("Speichern im Ordner «\(folder.lastPathComponent)» ging nicht"))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            let code = (error as? URLError)?.code
            if code != .cancelled { set(.failed(code == .notConnectedToInternet ? "Keine Internetverbindung" : "Laden fehlgeschlagen")) }
        }
        let result = lock.withLock { () -> Outcome? in
            let o = outcome
            outcome = nil
            return o
        }
        session.finishTasksAndInvalidate()
        finished(result ?? .failed("Laden fehlgeschlagen"))
        lock.withLock { self.session = nil; self.task = nil }
    }

    private func set(_ o: Outcome) {
        lock.withLock { if outcome == nil { outcome = o } }
    }
}

/// Runs a program (fixed path, argument array, never a shell) and hands over its output line by line.
nonisolated final class LineProcess: @unchecked Sendable {
    private let process = Process()
    private let out = Pipe()
    private let err = Pipe()
    private let lock = NSLock()
    private var buffer = Data()
    private var errors = Data()

    init(path: String, arguments: [String], environment: [String: String]) {
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = out
        process.standardError = err
    }

    func run(onLine: @escaping @Sendable (String) -> Void, onExit: @escaping @Sendable (Int32, String) -> Void) throws {
        out.fileHandleForReading.readabilityHandler = { [weak self] h in
            let chunk = h.availableData
            guard let self, !chunk.isEmpty else { return }
            for line in self.take(chunk) { onLine(line) }
        }
        err.fileHandleForReading.readabilityHandler = { [weak self] h in
            let chunk = h.availableData
            guard let self, !chunk.isEmpty else { return }
            self.lock.withLock {
                self.errors.append(chunk)
                // Only the end matters for the reason; keep memory small.
                if self.errors.count > 64_000 { self.errors.removeFirst(self.errors.count - 32_000) }
            }
        }
        // Strong on purpose: the process keeps its runner alive until it ended; the handler is cleared below.
        process.terminationHandler = { p in
            self.out.fileHandleForReading.readabilityHandler = nil
            self.err.fileHandleForReading.readabilityHandler = nil
            let rest = self.out.fileHandleForReading.readDataToEndOfFile()
            for line in self.take(rest) { onLine(line) }
            let tailErr = self.err.fileHandleForReading.readDataToEndOfFile()
            let leftover = self.lock.withLock { () -> String in
                self.errors.append(tailErr)
                let last = String(decoding: self.buffer, as: UTF8.self)
                self.buffer.removeAll()
                return last
            }
            if !leftover.isEmpty { onLine(leftover) }
            let errText = self.lock.withLock { String(decoding: self.errors, as: UTF8.self) }
            onExit(p.terminationStatus, errText)
            p.terminationHandler = nil
        }
        try process.run()
    }

    func cancel() {
        if process.isRunning { process.terminate() }
    }

    /// Complete lines from the buffer; the unfinished rest stays for the next chunk.
    private func take(_ chunk: Data) -> [String] {
        lock.withLock {
            buffer.append(chunk)
            var lines: [String] = []
            while let nl = buffer.firstIndex(of: 0x0A) {
                let line = buffer[buffer.startIndex..<nl]
                buffer.removeSubrange(buffer.startIndex...nl)
                let text = String(decoding: line, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { lines.append(text) }
            }
            return lines
        }
    }
}
