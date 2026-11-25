// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import CoreImage
import Observation
import SwiftUI
import VibrantPlusKit

/// What plays in Apple Music or Spotify. Track changes arrive as distributed
/// notifications (no polling); AppleScript is used only for controls,
/// the cover, and one read at start, and only while the player runs.
@Observable
final class NowPlaying {
    static let shared = NowPlaying()

    enum Player: String {
        case music = "com.apple.Music"
        case spotify = "com.spotify.client"
        var name: String { self == .music ? "Music" : "Spotify" }
        var title: String { self == .music ? "Musik" : "Spotify" }
    }

    private(set) var player: Player?
    private(set) var title = ""
    private(set) var artist = ""
    private(set) var album = ""
    private(set) var isPlaying = false
    private(set) var duration: TimeInterval = 0
    private(set) var cover: NSImage?
    /// Average color of the cover, for the tile tint.
    private(set) var coverColor: Color?
    private(set) var automationDenied = false
    /// Synchronised lyrics for the current song, when LRCLIB has them and the setting is on.
    private(set) var lyrics: SyncedLyrics?
    private(set) var upcoming: [String] = []

    @ObservationIgnored private var position: TimeInterval = 0
    @ObservationIgnored private var positionStamp = Date.now
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var coverKey = ""

    var hasTrack: Bool { player != nil && !title.isEmpty }

    func currentPosition(at now: Date = .now) -> TimeInterval {
        let p = isPlaying ? position + now.timeIntervalSince(positionStamp) : position
        return duration > 0 ? min(p, duration) : p
    }

    func start() {
        guard observers.isEmpty else { return }
        let center = DistributedNotificationCenter.default()
        observers.append(center.addObserver(forName: Notification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main) { [weak self] note in
            let info = PlayerInfo(note.userInfo ?? [:])
            MainActor.assumeIsolated { self?.update(from: .music, info: info) }
        })
        observers.append(center.addObserver(forName: Notification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main) { [weak self] note in
            let info = PlayerInfo(note.userInfo ?? [:])
            MainActor.assumeIsolated { self?.update(from: .spotify, info: info) }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated {
                if let self, id == self.player?.rawValue { self.clear() }
            }
        })
        readInitialStateSoon()
    }

    /// One read at start, after the first frame, so the island is on screen before AppleScript
    /// runs. AppleScript stays on the main thread (NSAppleScript is not thread-safe), so the read
    /// is bounded by a short timeout instead.
    private func readInitialStateSoon() {
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, player == nil else { return }
            readInitialState()
        }
    }

    func stop() {
        for o in observers {
            DistributedNotificationCenter.default().removeObserver(o)
            NSWorkspace.shared.notificationCenter.removeObserver(o)
        }
        observers = []
        clear()
    }

    private func clear() {
        player = nil
        title = ""
        artist = ""
        album = ""
        isPlaying = false
        duration = 0
        position = 0
        positionStamp = .now
        cover = nil
        coverColor = nil
        lyrics = nil
        upcoming = []
    }

    private func update(from player: Player, info: PlayerInfo) {
        let state = info.state ?? ""
        if state == "Stopped" {
            if self.player == player { clear() }
            return
        }
        // A paused player does not replace one that plays.
        if state != "Playing", let current = self.player, current != player, isPlaying { return }
        self.player = player
        title = info.name ?? title
        artist = info.artist ?? artist
        album = info.album ?? album
        isPlaying = state == "Playing"
        if let ms = info.duration { duration = ms / 1000 }          // Spotify: ms
        if let total = info.totalTime { duration = total / 1000 }  // Music: ms
        if let pos = info.position { position = pos; positionStamp = .now }
        else { position = readPosition() ?? position; positionStamp = .now }
        let key = "\(player.rawValue)|\(title)|\(album)"
        if key != coverKey {
            coverKey = key
            loadCover()
            loadLyrics()
            loadQueue()
        }
    }

    private func readInitialState() {
        for p in [Player.spotify, .music] where Script.isRunning(p.rawValue) {
            let source = """
            tell application "\(p.name)"
              if player state is stopped then return ""
              set t to current track
              return (name of t) & "\n" & (artist of t) & "\n" & (album of t) & "\n" & (player state as text) & "\n" & (duration of t as text) & "\n" & (player position as text)
            end tell
            """
            guard let text = try? Script.run(source, timeout: 2).stringValue, !text.isEmpty else { continue }
            let parts = text.components(separatedBy: "\n")
            guard parts.count >= 6 else { continue }
            var duration = Double(parts[4].replacingOccurrences(of: ",", with: ".")) ?? 0
            if p == .spotify { duration /= 1000 }
            update(from: p, info: PlayerInfo(state: parts[3] == "playing" ? "Playing" : "Paused", name: parts[0], artist: parts[1],
                                             album: parts[2], totalTime: duration * 1000,
                                             position: Double(parts[5].replacingOccurrences(of: ",", with: ".")) ?? 0))
            if parts[3] == "playing" { return }
        }
    }

    private func readPosition() -> Double? {
        guard let p = player, Script.isRunning(p.rawValue),
              let s = try? Script.run("tell application \"\(p.name)\" to return player position as text", timeout: 1).stringValue else { return nil }
        return Double(s.replacingOccurrences(of: ",", with: "."))
    }

    // MARK: Controls

    /// Only flips what the player confirmed: a refused or failed script must not show a pause
    /// symbol while the music keeps playing.
    func playPause() {
        guard send("playpause") else { return }
        isPlaying.toggle()
        position = currentPosition()
        positionStamp = .now
    }
    func next() { send("next track") }

    private func loadQueue() {
        upcoming = []
        guard player == .music, Script.isRunning(Player.music.rawValue) else { return }
        let source = """
        tell application "Music"
          if player state is stopped then return ""
          set cur to current track
          set pl to current playlist
          set i to index of cur
          set lastIndex to count of tracks of pl
          if i >= lastIndex then return ""
          set hi to i + 5
          if hi > lastIndex then set hi to lastIndex
          set out to ""
          repeat with n from (i + 1) to hi
            set row to (name of track n of pl)
            try
              set row to row & " — " & (artist of track n of pl)
            end try
            if out is "" then
              set out to row
            else
              set out to out & linefeed & row
            end if
          end repeat
          return out
        end tell
        """
        guard let text = try? Script.run(source, timeout: 2).stringValue, !text.isEmpty else { return }
        upcoming = text.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
    }
    func previous() { send("previous track") }

    @discardableResult
    private func send(_ command: String) -> Bool {
        guard let p = player, Script.isRunning(p.rawValue) else { return false }
        do {
            try Script.run("tell application \"\(p.name)\" to \(command)")
            return true
        } catch Script.Failure.notAllowed {
            automationDenied = true
            return false
        } catch {
            return false
        }
    }

    /// Opens the player app.
    func openPlayer() {
        guard let p = player, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: p.rawValue) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    /// A fictional song with a generated cover, for snapshots and marketing images.
    func loadSample() {
        player = .music
        title = "Slow Morning"
        artist = "Mira Lane"
        album = "Light Hours"
        isPlaying = true
        duration = 214
        position = 81
        positionStamp = .now
        let image = NSImage(size: NSSize(width: 400, height: 400), flipped: false) { r in
            NSGradient(starting: NSColor(hex: Brand.schiefer), ending: NSColor(hex: Brand.black))?.draw(in: r, angle: -60)
            NSColor(hex: Brand.porzellan).withAlphaComponent(0.85).setFill()
            NSBezierPath(ovalIn: NSRect(x: 230, y: 230, width: 110, height: 110)).fill()
            return true
        }
        cover = image
        coverColor = NowPlaying.averageColor(image)
        lyrics = SyncedLyrics(lrc: "[00:00.00] Morgenlicht auf dem Fenster\n[01:10.00] Wir lassen den Tag langsam kommen\n[01:40.00] Alles still, nur wir zwei")
    }

    // MARK: Lyrics

    /// The line sung right now.
    func currentLyric(at now: Date = .now) -> String? {
        guard let line = lyrics?.line(at: currentPosition(at: now)) else { return nil }
        return line.text.isEmpty ? "♪" : line.text
    }

    /// Asks LRCLIB (title, artist, album, length only) for synced lyrics.
    private func loadLyrics() {
        lyrics = nil
        guard Prefs.shared.lyricsEnabled, !title.isEmpty,
              let url = SyncedLyrics.requestURL(title: title, artist: artist, album: album, duration: duration) else { return }
        let key = coverKey
        Task {
            var req = URLRequest(url: url)
            req.setValue("Vibrant+/1.0 (https://arjolab.ch)", forHTTPHeaderField: "User-Agent")
            req.timeoutInterval = 8
            guard let (data, response) = try? await URLSession.shared.data(for: req),
                  (response as? HTTPURLResponse)?.statusCode == 200, key == self.coverKey else { return }
            self.lyrics = SyncedLyrics.parseResponse(data)
        }
    }

    // MARK: Cover

    private func loadCover() {
        cover = nil
        coverColor = nil
        guard let p = player, Script.isRunning(p.rawValue) else { return }
        switch p {
        case .music:
            let d = try? Script.run("tell application \"Music\" to if (count of artworks of current track) > 0 then return raw data of artwork 1 of current track", timeout: 1)
            if let data = d?.data, let image = NSImage(data: data) { setCover(image) }
        case .spotify:
            guard let s = try? Script.run("tell application \"Spotify\" to return artwork url of current track", timeout: 1).stringValue,
                  let url = URL(string: s), url.scheme == "https" else { return }
            let key = coverKey
            Task {
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let image = NSImage(data: data), key == self.coverKey else { return }
                self.setCover(image)
            }
        }
    }

    private func setCover(_ image: NSImage) {
        cover = image
        coverColor = Self.averageColor(image)
    }

    static func averageColor(_ image: NSImage) -> Color? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let input = CIImage(cgImage: cg)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: input,
                                                                       kCIInputExtentKey: CIVector(cgRect: input.extent)]),
              let output = filter.outputImage else { return nil }
        var px = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(output, toBitmap: &px, rowBytes: 4,
                                                                  bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                                                                  format: .RGBA8, colorSpace: nil)
        return Color(red: Double(px[0]) / 255, green: Double(px[1]) / 255, blue: Double(px[2]) / 255)
    }
}


/// The fields Vibrant+ reads from a player notification, copied out so they can cross threads.
nonisolated struct PlayerInfo: Sendable {
    var state: String?
    var name: String?
    var artist: String?
    var album: String?
    var duration: Double?
    var totalTime: Double?
    var position: Double?

    init(state: String?, name: String?, artist: String?, album: String?, duration: Double? = nil,
         totalTime: Double? = nil, position: Double? = nil) {
        self.state = state; self.name = name; self.artist = artist; self.album = album
        self.duration = duration; self.totalTime = totalTime; self.position = position
    }

    init(_ d: [AnyHashable: Any]) {
        state = d["Player State"] as? String
        name = d["Name"] as? String
        artist = d["Artist"] as? String
        album = d["Album"] as? String
        duration = (d["Duration"] as? NSNumber)?.doubleValue
        totalTime = (d["Total Time"] as? NSNumber)?.doubleValue
        position = (d["Playback Position"] as? NSNumber)?.doubleValue
    }
}
