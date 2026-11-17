// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UniformTypeIdentifiers

/// What a person wants from a link.
public enum DownloadFormat: String, CaseIterable, Codable, Sendable {
    case video, audio, image
}

/// Sound format when only the audio is wanted.
public enum AudioFormat: String, CaseIterable, Codable, Sendable {
    case m4a, mp3
}

/// What kind of link it is, which decides how it is loaded.
public enum LinkKind: Equatable, Sendable {
    /// A file (picture, video, sound) by its extension: loaded directly.
    case direct(DownloadFormat)
    /// A video or music platform: needs yt-dlp.
    case platform
    /// A streaming service with copy protection (DRM): not loaded.
    case protected
    /// Unknown web address: try directly, a web page goes on to yt-dlp.
    case other
}

/// Progress or result lines from yt-dlp, from the templates in `DownloadPlan.ytDlpArguments`.
public enum YtLine: Equatable, Sendable {
    case progress(done: Int64, total: Int64?)
    case title(String)
    case file(String)
    case thumbnail(String)
}

/// Rules for the link downloader. Pure, so it is tested.
public enum DownloadPlan {
    /// Hosts yt-dlp handles well (and subdomains of them). Short links and mobile hosts
    /// (vm.tiktok.com, youtu.be, instagr.am …) go to the same platforms.
    static let platforms = ["youtube.com", "youtu.be", "youtube-nocookie.com", "instagram.com", "instagr.am",
                            "tiktok.com", "vm.tiktok.com", "vt.tiktok.com",
                            "vimeo.com", "x.com", "twitter.com", "facebook.com", "fb.watch", "soundcloud.com",
                            "twitch.tv", "dailymotion.com", "reddit.com", "redd.it", "bandcamp.com", "srf.ch",
                            "mixcloud.com", "threads.net", "pinterest.com", "pin.it", "bsky.app", "linkedin.com"]
    /// Services that protect their content with DRM. Vibrant+ does not try.
    static let protectedHosts = ["spotify.com", "netflix.com", "disneyplus.com", "music.apple.com", "tv.apple.com",
                                 "primevideo.com", "deezer.com", "tidal.com", "play.max.com", "hbomax.com", "zattoo.com"]

    static let extensions: [String: DownloadFormat] = [
        "jpg": .image, "jpeg": .image, "png": .image, "gif": .image, "webp": .image, "heic": .image, "heif": .image,
        "avif": .image, "tif": .image, "tiff": .image, "bmp": .image, "svg": .image,
        "mp4": .video, "m4v": .video, "mov": .video, "webm": .video, "mkv": .video, "avi": .video,
        "mp3": .audio, "m4a": .audio, "aac": .audio, "wav": .audio, "flac": .audio, "ogg": .audio, "opus": .audio,
        "aiff": .audio, "aif": .audio,
    ]

    /// A web link from pasted text, or nil. Only http and https; «www.…» gets https.
    public static func link(from text: String) -> URL? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, !s.contains(where: { $0.isWhitespace }) else { return nil }
        if s.lowercased().hasPrefix("www.") { s = "https://" + s }
        guard let url = URL(string: s), let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host, host.contains(".") else { return nil }
        return url
    }

    static func host(_ url: URL, isIn list: [String]) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return list.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    public static func classify(_ url: URL) -> LinkKind {
        if host(url, isIn: protectedHosts) { return .protected }
        if host(url, isIn: platforms) { return .platform }
        if let f = extensions[url.pathExtension.lowercased()] { return .direct(f) }
        return .other
    }

    /// Kind of file by its MIME type («image/png»), nil for web pages and the unknown.
    public static func format(mime: String?) -> DownloadFormat? {
        guard let m = mime?.lowercased() else { return nil }
        if m.hasPrefix("image/") { return .image }
        if m.hasPrefix("video/") || m == "application/vnd.apple.mpegurl" { return .video }
        if m.hasPrefix("audio/") { return .audio }
        return nil
    }

    /// A safe file name: the server's suggestion, else the link's last part, with an extension from the MIME type
    /// when it has none. No slashes, colons or leading dots, at most 120 characters before the extension.
    public static func fileName(suggested: String?, url: URL?, mime: String?) -> String {
        var name = suggested?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.isEmpty || name == "Unknown" { name = url?.lastPathComponent ?? "" }
        name = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        name = String(name.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
        while name.hasPrefix(".") { name.removeFirst() }
        if name.isEmpty || name == "-" { name = "Download" }
        var base = (name as NSString).deletingPathExtension
        var ext = (name as NSString).pathExtension
        if ext.isEmpty || extensions[ext.lowercased()] == nil,
           let m = mime, let t = UTType(mimeType: m), let e = t.preferredFilenameExtension {
            ext = e
        }
        if base.isEmpty { base = "Download" }
        if base.count > 120 { base = String(base.prefix(120)) }
        return ext.isEmpty ? base : "\(base).\(ext)"
    }

    /// Where yt-dlp and ffmpeg usually live (Homebrew on Apple chips and Intel, pip, MacPorts).
    public static func toolCandidates(_ tool: String, home: URL) -> [String] {
        ["/opt/homebrew/bin/\(tool)", "/usr/local/bin/\(tool)", home.appendingPathComponent(".local/bin/\(tool)").path,
         "/opt/local/bin/\(tool)"]
    }

    /// PATH for yt-dlp: it looks for ffmpeg and a JavaScript runtime (Deno) there. Apps start with a short PATH.
    public static let toolPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    static let progressTemplate = "download:vp|%(progress.downloaded_bytes)s|%(progress.total_bytes)s|%(progress.total_bytes_estimate)s"

    /// Arguments for yt-dlp. Ignores the person's own yt-dlp config, so the result is predictable, loads one
    /// item (not the whole playlist) and puts the link after `--`, so it can never be read as an option.
    /// For `.image` it only asks for the preview picture's address, which Vibrant+ then loads itself.
    /// `cookies`: a Netscape cookie file with the person's own login, only for the sites they signed in to.
    public static func ytDlpArguments(url: URL, format: DownloadFormat, audio: AudioFormat, folder: URL,
                                      ffmpeg: String?, cookies: String? = nil,
                                      quality: VideoQuality = .standard) -> [String] {
        var a = ["--ignore-config", "--no-playlist", "--newline", "--no-mtime"]
        if let ffmpeg { a += ["--ffmpeg-location", ffmpeg] }
        switch format {
        case .image:
            // Picture posts have no video: without this flag yt-dlp stops before it prints the picture.
            a += ["--ignore-no-formats-error", "--skip-download",
                  "--print", "vpthumb|%(thumbnail)s", "--print", "vptitle|%(title)s"]
            if let cookies { a += ["--cookies", cookies] }
            return a + ["--", url.absoluteString]
        case .video:
            // H.264 first: plays in QuickTime and on every Apple device.
            if ffmpeg != nil {
                // Only formats that say they are H.264. «ext=mp4» is no promise: Instagram puts VP9 into
                // MP4, which QuickTime refuses. Whatever else arrives is converted afterwards.
                let h264 = "bv*[vcodec^=avc1]+ba[ext=m4a]/bv*[vcodec^=avc1]+ba/b[vcodec^=avc1]/bv*+ba/b"
                // 4K exists only as VP9 or AV1: take that first when asked for, it is converted afterwards.
                a += ["-f", quality == .uhd ? "bv*[height>1080]+ba/" + h264 : h264,
                      "--merge-output-format", "mp4"]
            } else {
                a += ["-f", "b[ext=mp4]/b"]
            }
            // The largest picture up to this height (yt-dlp takes the next larger one if there is none).
            if let height = quality.maxHeight { a += ["-S", "res:\(height)"] }
        case .audio:
            if ffmpeg != nil {
                a += ["-f", "ba/b", "-x", "--audio-format", audio.rawValue, "--audio-quality", "0"]
            } else {
                a += ["-f", "ba[ext=m4a]/ba"]
            }
        }
        a += ["-o", folder.appendingPathComponent("%(title).120B.%(ext)s").path,
              "--progress", "--progress-template", progressTemplate,
              "--print", "before_dl:vptitle|%(title)s", "--print", "after_move:vpfile|%(filepath)s"]
        if let cookies { a += ["--cookies", cookies] }
        return a + ["--", url.absoluteString]
    }

    /// Video codecs QuickTime Player opens in an MP4 or MOV (as the track's four-character code).
    static let quickTimeVideo: Set<String> = ["avc1", "avc3", "hvc1"]

    /// A loaded video has to be converted when QuickTime Player would refuse it: another container
    /// (WebM, MKV) or another codec (VP9 `vp09`, AV1 `av01`, HEVC tagged `hev1`). `videoCodec` is the
    /// video track's four-character code, nil when it could not be read (then the file is left alone).
    public static func needsQuickTimeConversion(fileExtension: String, videoCodec: String?) -> Bool {
        let ext = fileExtension.lowercased()
        if ["webm", "mkv"].contains(ext) { return true }
        guard ["mp4", "m4v", "mov"].contains(ext), let videoCodec else { return false }
        return !quickTimeVideo.contains(videoCodec.lowercased())
    }

    /// Arguments for ffmpeg: H.264 with the Mac's hardware encoder, the sound kept as it is when it is
    /// already AAC, the index at the front so the file starts playing at once.
    public static func quickTimeArguments(input: String, output: String, copyAudio: Bool) -> [String] {
        ["-nostdin", "-y", "-loglevel", "error", "-i", input,
         "-map", "0:v:0", "-map", "0:a:0?",
         "-c:v", "h264_videotoolbox", "-q:v", "50", "-pix_fmt", "yuv420p", "-tag:v", "avc1"]
            + (copyAudio ? ["-c:a", "copy"] : ["-c:a", "aac", "-b:a", "192k"])
            + ["-movflags", "+faststart", output]
    }

    /// MP3 needs ffmpeg to convert; everything else works without (lower quality or one file).
    public static func needsFFmpeg(_ format: DownloadFormat, audio: AudioFormat) -> Bool {
        format == .audio && audio == .mp3
    }

    public static func parse(_ line: String) -> YtLine? {
        let parts = line.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
        guard let tag = parts.first, parts.count >= 2 else { return nil }
        switch tag {
        case "vp":
            guard parts.count == 4, let done = Int64(parts[1]) else { return nil }
            let total = Int64(parts[2]) ?? Double(parts[3]).map { Int64($0) }
            return .progress(done: done, total: total)
        case "vptitle": return parts[1] == "NA" ? nil : .title(parts[1...].joined(separator: "|"))
        case "vpfile": return .file(parts[1...].joined(separator: "|"))
        case "vpthumb": return parts[1] == "NA" ? nil : .thumbnail(parts[1...].joined(separator: "|"))
        default: return nil
        }
    }

    /// The preview picture a public page names for link previews (`og:image`, else `twitter:image`), absolute
    /// against `base`. Only http and https.
    public static func pageImage(fromHTML html: String, base: URL) -> URL? {
        var found: [String: String] = [:]
        let tag = /<meta\s[^>]*>/.ignoresCase()
        let attr = /([a-zA-Z:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/
        for match in html.matches(of: tag) {
            var key: String?
            var content: String?
            for a in match.output.matches(of: attr) {
                let name = a.output.1.lowercased()
                let value = String(a.output.2 ?? a.output.3 ?? "")
                if name == "property" || name == "name" { key = value.lowercased() }
                if name == "content" { content = value }
            }
            if let key, let content, found[key] == nil { found[key] = content }
        }
        for key in ["og:image:secure_url", "og:image", "og:image:url", "twitter:image", "twitter:image:src"] {
            guard let raw = found[key] else { continue }
            let text = decodeEntities(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, let url = URL(string: text, relativeTo: base)?.absoluteURL,
                  let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { continue }
            return url
        }
        return nil
    }

    /// The HTML entities that show up in attribute values: named basics and numeric ones.
    static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var out = ""
        var rest = Substring(s)
        let named = ["amp": "&", "quot": "\"", "apos": "'", "lt": "<", "gt": ">", "nbsp": " "]
        while let amp = rest.firstIndex(of: "&") {
            out += rest[..<amp]
            let after = rest[rest.index(after: amp)...]
            if let semi = after.prefix(10).firstIndex(of: ";") {
                let name = after[..<semi]
                var replacement: String?
                if name.hasPrefix("#x") || name.hasPrefix("#X") {
                    replacement = UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String($0) }
                } else if name.hasPrefix("#") {
                    replacement = UInt32(name.dropFirst()).flatMap(Unicode.Scalar.init).map { String($0) }
                } else {
                    replacement = named[name.lowercased()]
                }
                if let replacement {
                    out += replacement
                    rest = after[after.index(after: semi)...]
                    continue
                }
            }
            out += "&"
            rest = after
        }
        return out + rest
    }

    /// The post needs a login (restricted, age-gated, private, «sign in»).
    public static func needsLogin(error: String) -> Bool {
        let lower = error.lowercased()
        let words = ["private", "sign in", "login", "log in", "cookies", "isn't available to everyone",
                     "certain audiences", "restricted", "inappropriate", "empty media response"]
        return words.contains(where: lower.contains) || lower.range(of: #"\bage\b"#, options: .regularExpression) != nil
    }

    /// yt-dlp found no video because the post is a picture (or a set of pictures).
    public static func isPictureOnly(error: String) -> Bool {
        let lower = error.lowercased()
        return lower.contains("no video formats") || lower.contains("there is no video in this post")
    }

    /// Whether the public page's preview picture may stand in after yt-dlp failed. Never when the post needs
    /// a login, is private, age-gated or copy-protected: without a login Vibrant+ loads only what is public.
    public static func mayUsePageImage(format: DownloadFormat, error: String) -> Bool {
        if error.lowercased().contains("drm") || needsLogin(error: error) { return false }
        return format == .image || isPictureOnly(error: error)
    }

    public static func isInstagram(_ url: URL) -> Bool { host(url, isIn: ["instagram.com", "instagr.am"]) }

    /// A story, reel or highlight needs a signed-in session more often than a normal post.
    public static func isInstagramStoryLike(_ url: URL) -> Bool {
        guard isInstagram(url) else { return false }
        let path = url.path.lowercased()
        return path.contains("/stories/") || path.contains("/reel/") || path.contains("/reels/")
            || path.contains("/s/") || path.contains("/highlights/")
    }

    /// One cookie for yt-dlp's cookie file.
    public struct Cookie: Sendable, Equatable {
        public var domain: String
        public var path: String
        public var secure: Bool
        public var expires: Date?
        public var name: String
        public var value: String
        public init(domain: String, path: String, secure: Bool, expires: Date?, name: String, value: String) {
            self.domain = domain; self.path = path; self.secure = secure; self.expires = expires
            self.name = name; self.value = value
        }
    }

    /// A Netscape cookie file (the format of `--cookies`). Cookies with tabs or line breaks are left out.
    public static func netscapeCookies(_ cookies: [Cookie]) -> String {
        var lines = ["# Netscape HTTP Cookie File"]
        for c in cookies {
            let fields = [c.domain, c.path, c.name, c.value]
            guard !c.domain.isEmpty, !c.name.isEmpty,
                  !fields.contains(where: { $0.contains("\t") || $0.contains("\n") || $0.contains("\r") }) else { continue }
            let expiry = c.expires.map { String(Int($0.timeIntervalSince1970)) } ?? "0"
            lines.append([c.domain, c.domain.hasPrefix(".") ? "TRUE" : "FALSE", c.path.isEmpty ? "/" : c.path,
                          c.secure ? "TRUE" : "FALSE", expiry, c.name, c.value].joined(separator: "\t"))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The person is signed in when the session cookie is there and has not run out.
    public static func hasSession(_ cookies: [Cookie], now: Date = Date()) -> Bool {
        cookies.contains { $0.name == "sessionid" && !$0.value.isEmpty && ($0.expires.map { $0 > now } ?? true) }
    }

    /// A short German reason from yt-dlp's error output.
    public static func reason(fromError output: String) -> String {
        let lower = output.lowercased()
        if lower.contains("drm") { return "Kopiergeschützt (DRM), lässt sich nicht laden" }
        if lower.contains("isn't available to everyone") || lower.contains("certain audiences")
            || lower.contains("restricted") || lower.contains("inappropriate")
            || lower.range(of: #"\bage\b"#, options: .regularExpression) != nil {
            return "Nur mit Anmeldung sichtbar (Altersgrenze oder eingeschränktes Publikum)"
        }
        if lower.contains("unsupported url") { return "Diesen Link kennt yt-dlp nicht" }
        if lower.contains("private") { return "Privater Inhalt, nicht öffentlich" }
        if lower.contains("sign in") || lower.contains("login") || lower.contains("log in") || lower.contains("cookies")
            || lower.contains("empty media response") {
            return "Nur mit Anmeldung sichtbar"
        }
        if lower.contains("javascript runtime") || lower.contains("deno") {
            return "yt-dlp braucht Deno: im Terminal «brew install deno»"
        }
        if lower.contains("ffmpeg") { return "Dafür braucht yt-dlp ffmpeg: im Terminal «brew install ffmpeg»" }
        if lower.contains("no video in this post") { return "Kein Video in diesem Beitrag" }
        if lower.contains("no video formats") || lower.contains("requested format is not available") {
            return "In diesem Format nicht verfügbar"
        }
        if lower.contains("http error 404") || lower.contains("not found") { return "Nicht gefunden (404)" }
        if lower.contains("unable to download") || lower.contains("timed out") || lower.contains("network") {
            return "Keine Verbindung zum Server"
        }
        if let line = output.split(separator: "\n").last(where: { $0.hasPrefix("ERROR:") }) {
            let text = line.dropFirst("ERROR:".count).trimmingCharacters(in: .whitespaces)
            return text.count > 90 ? String(text.prefix(89)) + "…" : text
        }
        return "yt-dlp ist gescheitert. Vielleicht hilft «brew upgrade yt-dlp»"
    }
}
