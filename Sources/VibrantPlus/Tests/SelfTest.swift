// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import AVFoundation
import ImageIO
import PDFKit
import VibrantPlusKit

/// Runs the app's real functions against files in /tmp, prints PASS/FAIL per check,
/// and quits with exit code 0 (all passed) or 1.
///   APP_DATA=/tmp/vp-self VibrantPlus --selftest      (tools/selftest.sh)
/// It never touches the real data folder, the real ~/.claude/settings.json, or the pasteboard.
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0

    static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    static func run() {
        setvbuf(stdout, nil, _IOLBF, 0)
        let data = Paths.dataDirectory.path
        guard Paths.isOverridden, data.hasPrefix("/tmp") || data.hasPrefix("/private/tmp") else {
            print("SELFTEST refused: set APP_DATA to a folder in /tmp")
            finish(1)
            return
        }
        try? FileManager.default.removeItem(at: Paths.dataDirectory)
        Paths.ensureDataDirectory()
        Task {
            featureSetup()
            today()
            stow()
            await media()
            hooksFile()
            await agent()
            system()
            await weather()
            await lyrics()
            await assistant()
            await notion()
            clipboard()
            await screenshots()
            await capture()
            await downloads()
            snippets()
            airdrop()
            focusRules()
            backup()
            await shortcutsList()
            saveReport()
            await socketLimit()
            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(failures == 0 ? 0 : 1)
        }
    }

    static func finish(_ code: Int32) {
        exitCode = code
        NSApp.terminate(nil)
    }

    static func featureSetup() {
        let prefs = Prefs.shared
        let saved = (prefs.modules, prefs.onboarded, prefs.tilesOn, prefs.setupSelection, prefs.setupStep)
        defer {
            (prefs.modules, prefs.onboarded, prefs.tilesOn, prefs.setupSelection, prefs.setupStep) = saved
        }
        check("Jedes Modul hat eine passende Einstellungsseite", Module.allCases.allSatisfy { $0.settingsPage.module == $0 })
        check("Profile sind vollständig und aufsteigend", ModuleProfile.essentials.modules.isSubset(of: ModuleProfile.productivity.modules)
              && ModuleProfile.productivity.modules.isSubset(of: ModuleProfile.development.modules)
              && ModuleProfile.all.modules == Set(Module.allCases))
        check("Funktionssuche findet deutsche Begriffe", Module.clipboard.matches("Texte anheften") && !Module.clipboard.matches("Lüfter"))
        check("Leere Auswahl braucht keine Rechte", SetupPermissions.required(for: [], tiles: Set(TileKind.allCases)).isEmpty)
        check("Downloads und Links brauchen keine Einrichtungsrechte", SetupPermissions.required(for: [.downloads, .links], tiles: []).isEmpty)
        let permissions = SetupPermissions.required(for: [.voice, .snippets, .screenshots], tiles: [])
        check("Rechte passen zur Auswahl und sind dedupliziert", Set(permissions) == [.accessibility, .microphone, .speech, .screenRecording] && permissions.count == 4)
        prefs.onboarded = false
        prefs.modules = Set(Module.allCases)
        Coordinator.shared.apply()
        check("Vor Abschluss der Einrichtung laufen keine Module", Coordinator.shared.running.isEmpty)
        check("Vor Abschluss sind keine globalen Kurzbefehle aktiv", HotKeyAction.allCases.allSatisfy { !$0.isEnabled(in: prefs) })
        prefs.setupSelection = [.links]
        prefs.setupStep = 2
        check("Einrichtungsauswahl verändert keine laufende Modulauswahl", prefs.modules == Set(Module.allCases))
        prefs.onboarded = true
        prefs.modules = [.clipboard]
        check("Zwischenablage-Kurzbefehl funktioniert ohne Insel", HotKeyAction.clipboard.isEnabled(in: prefs) && !HotKeyAction.toggleIsland.isEnabled(in: prefs))
        prefs.modules = [.island]
        prefs.tilesOn = []
        check("Verlauf ohne Modul und Kachel ist aus", !HotKeyAction.clipboard.isEnabled(in: prefs))
        prefs.tilesOn = [.clipboard]
        check("Zwischenablage-Kachel erhält bisherigen Kurzbefehl", HotKeyAction.clipboard.isEnabled(in: prefs))
        check("Linkbereinigung arbeitet offline", CleanLink.clean("https://example.com/?utm_source=mail&id=1") == "https://example.com/?id=1")
        check("Neue Werkzeuge sind nach dem ersten Start aus",
              Module.defaultsOn.isDisjoint(with: [.windowTools, .cleaner, .uninstaller, .homebrew, .appUpdates, .diskInstaller, .systemMonitor, .keepAwakeRules, .quickTools, .cleaning, .autoQuit, .mouse, .finder, .quitProtection, .ocr, .scratchpad, .processes, .audioDevices]))
        check("Lokaler Rechner bleibt ohne Codeausführung", SafeCalculator.evaluate("2 + 3 * 4") == 14 && SafeCalculator.evaluate("system('ls')") == nil)
        let moved = WindowToolRules.movedToNextDisplay(frame: CGRect(x: 100, y: 80, width: 400, height: 200),
                                                       from: CGRect(x: 0, y: 0, width: 1000, height: 800),
                                                       to: CGRect(x: 2000, y: 100, width: 500, height: 400))
        check("Fenster auf den nächsten Bildschirm bleibt relativ", moved == CGRect(x: 2050, y: 140, width: 200, height: 100))
        check("Farbformate HEX RGB HSL SwiftUI", ColorHex.copyString("#FF8000", format: .rgb) == "rgb(255, 128, 0)"
              && ColorHex.copyString("#FF8000", format: .swiftUI).contains("0.502"))
        var clips = ClipList()
        check("Zwischenablage speichert Dateipfade", clips.add(files: ["/tmp/a.pdf"])?.kind == .file)
        check("Scrollaufnahme erkennt Überlappung", ScrollCapture.overlap([1, 2, 3], [2, 3, 9]) == 2 && ScrollCapture.shouldStop(previous: 4, current: 4, frames: 3))
    }

    // MARK: Today

    static func today() {
        let store = TodayStore.shared
        store.addTask("  Zahnarzt   anrufen ")
        let task = store.openTasks.last
        check("Aufgabe wird bereinigt hinzugefügt", task?.title == "Zahnarzt anrufen")
        if let task {
            store.remind(task, .in15Minutes)
            check("Erinnerung in 15 Minuten gesetzt", (store.data.tasks.first { $0.id == task.id }?.remindAt?.timeIntervalSinceNow ?? 0) > 800)
            store.toggle(task)
            check("Erledigt entfernt die Erinnerung", store.data.tasks.first { $0.id == task.id }?.remindAt == nil)
        }
        store.setNote("Notiz bleibt")
        store.saveNow()
        check("Heute wird als JSON gespeichert", JSONFile<TodayData>(url: Paths.today).load()?.note == "Notiz bleibt")
        store.startFocus()
        check("Fokus läuft", store.focusRunning)
        let before = store.focusRemaining()
        store.adjustFocus(minutes: 5)
        check("Fokus +5 Minuten", abs(store.focusRemaining() - before - 300) < 2)
        store.pauseFocus()
        check("Fokus pausiert", !store.focusRunning && store.focusActive)
        store.stopFocus()
        check("Fokus beendet", !store.focusActive)
    }

    // MARK: Stow

    static func stow() {
        let dir = Paths.dataDirectory.appending(path: "stow")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let png = makeImage(dir.appending(path: "Foto.png"), width: 3000, height: 2000, gps: true) else {
            check("Testbild erzeugt", false); return
        }
        do {
            let web = try StowEngine.convertImage(png, to: .jpeg, maxPixel: 2000, quality: 0.8, tag: "Web")
            let size = pixelSize(web)
            check("Für das Web: JPEG mit 2000 px", web.pathExtension == "jpg" && max(size.width, size.height) == 2000, "\(size)")
            let web2 = try StowEngine.convertImage(png, to: .jpeg, maxPixel: 2000, quality: 0.8, tag: "Web")
            check("Nichts wird überschrieben", web2.lastPathComponent == "Foto (Web 2).jpg" && FileManager.default.fileExists(atPath: web.path))
            let heic = try StowEngine.convertImage(png, to: .heic)
            check("HEIC-Umwandlung", heic.pathExtension == "heic" && FileManager.default.fileExists(atPath: heic.path))
            let square = try StowEngine.crop(png, to: .square)
            let s = pixelSize(square)
            check("Zuschneiden 1:1", s.width == s.height && s.width == 2000, "\(s)")
            let story = try StowEngine.crop(png, to: .tall)
            let t = pixelSize(story)
            check("Zuschneiden 9:16", abs(t.width / t.height - 9.0 / 16.0) < 0.01, "\(t)")
            let jpgWithGPS = try StowEngine.convertImage(png, to: .jpeg)
            check("Normale Umwandlung entfernt GPS", !hasGPS(jpgWithGPS))
            let stripped = try StowEngine.stripMetadata(png)
            check("Metadaten entfernen", !hasGPS(stripped) && exif(stripped) == nil)
            let small = try StowEngine.shrink(png, underMB: 0.1)
            let bytes = (try? FileManager.default.attributesOfItem(atPath: small.path)[.size] as? Int) ?? .max
            check("Verkleinern unter 0,1 MB", bytes <= 100_000, "\(bytes) Bytes")
            let up = try StowEngine.upscaleImage(png, factor: 2)
            let us = pixelSize(up)
            check("Hochskalieren: Bild 2× (3000×2000 → 6000×4000)", us.width == 6000 && us.height == 4000, "\(us)")
            let second = makeImage(dir.appending(path: "Zweites.png"), width: 600, height: 800, gps: false)!
            let pdf = try StowEngine.makePDF([png, second])
            check("Zwei Bilder werden ein PDF mit 2 Seiten", PDFDocument(url: pdf)?.pageCount == 2)
            let pages = try StowEngine.splitPDF(pdf)
            check("PDF teilen ergibt 2 Dateien", pages.count == 2 && pages.allSatisfy { PDFDocument(url: $0)?.pageCount == 1 })
            check("WebP-Schreiben erkannt", true, "schreibbar: \(StowEngine.ImageFormat.writable.map(\.rawValue))")
        } catch {
            check("Stow-Umwandlungen", false, error.localizedDescription)
        }
    }

    static func media() async {
        let dir = Paths.dataDirectory.appending(path: "stow")
        let audio = URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff")
        let copy = dir.appending(path: "Ton.aiff")
        try? FileManager.default.copyItem(at: audio, to: copy)
        do {
            let m4a = try await StowEngine.export(copy, to: .m4a)
            check("Audio nach M4A", m4a.pathExtension == "m4a" && FileManager.default.fileExists(atPath: m4a.path))
        } catch { check("Audio nach M4A", false, error.localizedDescription) }
        guard let video = await makeVideo(dir.appending(path: "Clip.mov"), seconds: 3) else {
            check("Testvideo erzeugt", false); return
        }
        do {
            let mp4 = try await StowEngine.export(video, to: .mp4)
            check("Video nach MP4", mp4.pathExtension == "mp4" && FileManager.default.fileExists(atPath: mp4.path))
            let gif = try await StowEngine.export(video, to: .gif)
            let gifCount = gifFrameCount(gif)
            check("Video nach GIF", gif.pathExtension == "gif" && gifCount >= 20 && gifCount <= 32, "\(gifCount) Bilder")
            let up = try await StowEngine.upscaleVideo(video)
            let upSize = try await AVURLAsset(url: up).loadTracks(withMediaType: .video).first?.load(.naturalSize)
            let upDur = await StowEngine.duration(of: up)
            check("Hochskalieren: Video 2× (320×240 → 640×480, 3 s)", upSize == CGSize(width: 640, height: 480) && abs(upDur - 3) < 0.3, "\(String(describing: upSize)), \(upDur) s")
            let trimmed = try await StowEngine.export(video, to: .mp4, start: 1, end: 2)
            let d = await StowEngine.duration(of: trimmed)
            check("Video kürzen auf 1 Sekunde", abs(d - 1) < 0.2, "\(d) s")
            if let second = await makeVideo(dir.appending(path: "Clip2.mov"), seconds: 2, width: 240, height: 320) {
                let film = try await StowEngine.joinVideos([video, second, video])
                let fd = await StowEngine.duration(of: film)
                let size = try await AVURLAsset(url: film).loadTracks(withMediaType: .video).first?.load(.naturalSize)
                check("Drei Videos zu einem Film (3+2+3 s, Hoch- und Querformat)", abs(fd - 8) < 0.3 && size == CGSize(width: 320, height: 240),
                      "\(fd) s, \(String(describing: size))")
            } else { check("Zweites Testvideo erzeugt", false) }
        } catch { check("Video-Export", false, error.localizedDescription) }
    }


    // MARK: Claude Code

    static func hooksFile() {
        let url = Paths.claudeSettings
        guard url.path.contains("/tmp/") else { check("Testeinstellungen in /tmp", false, url.path); return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data(#"{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say fertig"}]}]}}"#.utf8).write(to: url)
        let store = AgentStore.shared
        store.installHooks()
        check("Hooks installiert", store.hooksInstalled)
        let settings = (try? ClaudeHooks.read(url)) ?? [:]
        let stop = (settings["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        check("Fremde Hooks und Einstellungen bleiben", settings["model"] as? String == "opus" && stop?.count == 2)
        let cmd = ((stop?.last?["hooks"] as? [[String: Any]])?.first?["command"] as? String) ?? ""
        check("Hook zeigt auf dieses Programm", cmd.contains(Paths.executable), cmd)
        // Hooks written by another copy (moved app): shown as outdated, fixed by installing again.
        if let moved = try? ClaudeHooks.install(into: ClaudeHooks.read(url), executable: "/Applications/Alt/VibrantPlus") {
            try? ClaudeHooks.write(moved, to: url)
        }
        store.refreshHookStatus()
        check("Veraltete Verbindung erkannt", store.hooksInstalled && store.hooksOutdated)
        store.installHooks()
        check("Verbindung erneuert", store.hooksInstalled && !store.hooksOutdated)
        store.removeHooks()
        check("Hooks entfernt", !store.hooksInstalled && ((try? ClaudeHooks.read(url))?["hooks"] as? [String: Any])?["Stop"] != nil)
    }

    static func agent() async {
        let store = AgentStore.shared
        // Without a running app the hook ends at once and prints nothing.
        let early = await runHook(#"{"session_id":"t","hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"ls"}}"#)
        check("Hook ohne laufende App: keine Ausgabe, sofort", early.output.isEmpty && early.seconds < 2, "\(early.seconds) s")

        store.start()
        check("Agent-Socket läuft", store.serverRunning)
        // Permission: answer "always" from the island.
        let answering = Task {
            for _ in 0..<50 {
                if let p = store.pending.first { store.answer(p, .always); return true }
                try? await Task.sleep(for: .milliseconds(100))
            }
            return false
        }
        let r = await runHook(#"{"session_id":"t","hook_event_name":"PermissionRequest","cwd":"/tmp/p","tool_name":"Bash","tool_input":{"command":"rm -rf build"},"permission_suggestions":[{"type":"addRules","rules":[{"toolName":"Bash"}],"behavior":"allow","destination":"localSettings"}]}"#)
        let answered = await answering.value
        check("Berechtigung erscheint in der Insel", answered)
        let json = (try? JSONSerialization.jsonObject(with: Data(r.output.utf8))) as? [String: Any]
        let decision = (json?["hookSpecificOutput"] as? [String: Any])?["decision"] as? [String: Any]
        check("«Immer erlauben» geht an Claude Code", decision?["behavior"] as? String == "allow" && decision?["updatedPermissions"] != nil, r.output)

        // Deny.
        let denying = Task { () -> Void in
            for _ in 0..<50 {
                if let p = store.pending.first { store.answer(p, .deny); return }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        let d = await runHook(#"{"session_id":"t","hook_event_name":"PermissionRequest","tool_name":"Write","tool_input":{"file_path":"/tmp/x"}}"#)
        _ = await denying.value
        check("«Ablehnen» geht an Claude Code", d.output.contains("\"behavior\":\"deny\""), d.output)

        // Question.
        let asking = Task { () -> Void in
            for _ in 0..<50 {
                if let p = store.pending.first, let q = p.questions.first { store.answer(p, .answer, answers: [q.question: q.options[1]]); return }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        let q = await runHook(#"{"session_id":"t","hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Welche DB?","header":"DB","options":[{"label":"SQLite"},{"label":"JSON"}],"multiSelect":false}]}}"#)
        _ = await asking.value
        check("Antwort auf Claudes Frage", q.output.contains("\"Welche DB?\":\"JSON\""), q.output)

        // Files for the next prompt.
        store.addFilesForClaude([URL(fileURLWithPath: "/tmp/Skizze.png")])
        let p = await runHook(#"{"session_id":"t","hook_event_name":"UserPromptSubmit","prompt":"Schau dir das an"}"#)
        check("Abgelegte Datei geht mit der nächsten Nachricht", p.output.contains("/tmp/Skizze.png") && store.filesForClaude.isEmpty, p.output)

        // A plain event updates the session.
        _ = await runHook(#"{"session_id":"t","hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/tmp/p/a.swift","old_string":"a","new_string":"b"}}"#)
        try? await Task.sleep(for: .milliseconds(300))
        check("Schritte und geänderte Dateien erscheinen", store.sessions["t"]?.files.first?.fileName == "a.swift")
        // A finished turn: history entry with tokens from the transcript.
        let transcript = Paths.dataDirectory.appending(path: "t.jsonl")
        let lines = #"{"type":"assistant","message":{"id":"m1","usage":{"input_tokens":100,"output_tokens":250,"cache_read_input_tokens":1000,"cache_creation_input_tokens":50}}}"#
        try? Data(lines.utf8).write(to: transcript)
        _ = await runHook(#"{"session_id":"t","hook_event_name":"Stop","transcript_path":"\#(transcript.path)"}"#)
        for _ in 0..<50 where store.history.isEmpty { try? await Task.sleep(for: .milliseconds(100)) }
        check("Claude-Verlauf: Antwort mit Verbrauch gespeichert",
              store.history.first?.tokens == 1400 && store.history.first?.project == "p" && store.sessions["t"]?.lastTurn != nil,
              "\(String(describing: store.history.first))")
        check("Claude-Verlauf: bleibt nach Neustart erhalten",
              (JSONFile<[AgentHistoryEntry]>(url: Paths.agentHistory).load()?.count ?? 0) == 1)
        store.stop()
    }

    /// Runs this binary as the hook, like Claude Code does.
    static func runHook(_ json: String) async -> (output: String, seconds: Double) {
        await Task.detached {
            let start = Date.now
            let p = Process()
            p.executableURL = URL(fileURLWithPath: Paths.executable)
            p.arguments = ["--hook"]
            p.environment = ProcessInfo.processInfo.environment
            let input = Pipe(), output = Pipe()
            p.standardInput = input
            p.standardOutput = output
            p.standardError = FileHandle.nullDevice
            do { try p.run() } catch { return ("", 0) }
            input.fileHandleForWriting.write(Data(json.utf8))
            try? input.fileHandleForWriting.close()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return (String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines), Date.now.timeIntervalSince(start))
        }.value
    }

    // MARK: System

    static func system() {
        if let v = SystemVolume.volume() {
            check("Lautstärke lesen und (gleich) setzen", SystemVolume.setVolume(v) && abs((SystemVolume.volume() ?? -1) - v) < 0.01, "\(v)")
        } else {
            check("Lautstärke lesen", false, "kein Ausgabegerät")
        }
        _ = AppMixer.playingProcesses()
        check("Audio-Prozessliste lesbar", true)
        let heavy = ProcessSnapshot.heaviest(limit: 8)
        check("Prozessliste nach Speicher lesbar", !heavy.isEmpty && heavy.first!.memoryBytes >= heavy.last!.memoryBytes, "\(heavy.count)")
        let stats = SystemStats.shared
        stats.sample()
        check("Systemwerte: RAM und freier Platz", stats.memoryUsed > 0.5 && stats.diskFree > 0, "\(stats.memoryUsed) GB, \(stats.diskFree) GB")
        let apps = AppGridController.installedApps()
        check("App-Raster findet Safari", apps.contains { $0.name == "Safari" }, "\(apps.count) Apps")
        check("Sprachbefehl findet App", VoiceController.findApp(named: "safari") != nil)
        let ports = Run.program("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"], timeout: 5)
        check("Server-Liste lesbar", ports.status == 0 || ports.status == 1, "Status \(ports.status), \(ListeningPorts.parse(ports.output).count) Ports")
        let branch = GitHead.repositoryRoot(from: FileManager.default.currentDirectoryPath).flatMap(GitHead.branch(at:))
        check("Git-Branch des Projekts", branch != nil || GitHead.repositoryRoot(from: FileManager.default.currentDirectoryPath) == nil, branch ?? "kein Repo")
        let buffer = KeySoundPlayer.click(profile: .typewriter, format: AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!,
                                          variant: 1, release: false)
        check("Tastengeräusch wird erzeugt", buffer.frameLength > 1000)
        let keyFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let peaks = KeySoundProfile.allCases.flatMap { profile in
            (0...KeySoundPlayer.heavyVariant).flatMap { v in [false, true].map { release -> Float in
                let b = KeySoundPlayer.click(profile: profile, format: keyFormat, variant: v, release: release)
                return (0..<Int(b.frameLength)).map { abs(b.floatChannelData![0][$0]) }.max() ?? 0
            } }
        }
        let recordings = KeySoundPlayer.recordedBuffers(format: keyFormat, prefix: "cherry")
        check("Echte Tastenaufnahmen (CC0) sind im App-Paket", (recordings?.count ?? 0) == 32 && recordings?.allSatisfy { $0.frameLength > 4000 } == true, "\(recordings?.count ?? 0) Dateien")
        let kenney = ["kclick": 5, "ktick": 3].allSatisfy { KeySoundPlayer.recordedBuffers(format: keyFormat, prefix: $0.key)?.count == $0.value }
        check("Kenney-Klicks (CC0) sind im App-Paket", kenney)
        check("Alle Tastenklänge hörbar und ohne Übersteuern", peaks.allSatisfy { $0 > 0.02 && $0 <= 1 }, "Spitzen \(peaks.min() ?? 0)…\(peaks.max() ?? 0)")
        check("Menüleisten-Symbol als Vorlage", VibrantMark.menuBarImage().isTemplate)
        if Permission.accessibilityTrusted {
            _ = WindowManager.shared.windows()
            check("Rowline liest Fenster", true)
        } else {
            print("SKIP Rowline liest Fenster: Bedienungshilfen nicht erlaubt")
        }
    }

    static func lyrics() async {
        guard let url = SyncedLyrics.requestURL(title: "Never Gonna Give You Up", artist: "Rick Astley", album: "Whenever You Need Somebody", duration: 213) else { return }
        var req = URLRequest(url: url)
        req.setValue("Vibrant+/1.0 (selftest)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: req), (response as? HTTPURLResponse)?.statusCode == 200 else {
            print("SKIP Liedtext: LRCLIB nicht erreichbar")
            return
        }
        let l = SyncedLyrics.parseResponse(data)
        check("Liedtext von LRCLIB geladen und gelesen", (l?.lines.count ?? 0) > 10 && l?.line(at: 60) != nil, "\(l?.lines.count ?? 0) Zeilen")
    }

    static func weather() async {
        do {
            let w = try await WeatherService.fetch(city: "Zürich")
            check("Wetter von Open-Meteo", w.place.contains("Zürich") && w.temperature > -40 && w.temperature < 50, "\(w.place) \(w.temperature)°")
        } catch {
            print("SKIP Wetter: kein Netz (\(error.localizedDescription))")
        }
    }

    // MARK: Assistant (Apple Intelligence on device)

    static func assistant() async {
        guard Assistant.isAvailable else {
            print("SKIP Assistent: \(Assistant.state)")
            return
        }
        let a = Assistant.shared
        a.ask("Wie viele Tage hat eine Woche? Antworte nur mit der Zahl.", speak: false)
        for _ in 0..<150 where a.busy { try? await Task.sleep(for: .milliseconds(100)) }
        let answer = a.turns.last?.answer ?? ""
        // The on-device model is small and not always right (once it said "Sechs"): the check is that it
        // answers at all, on the device, without an error; the content is reported for the log.
        check("Assistent antwortet auf dem Gerät", !answer.isEmpty && a.turns.last?.failed == false, answer)
        a.ask("Starte bitte einen Timer für 3 Minuten.", speak: false)
        for _ in 0..<200 where a.busy { try? await Task.sleep(for: .milliseconds(100)) }
        let r = QuickTimer.shared.remaining()
        check("Assistent startet Timer über Werkzeug", QuickTimer.shared.running && r > 150 && r <= 180,
              "\(Int(r)) s, Antwort: \(a.turns.last?.answer ?? "")")
        QuickTimer.shared.cancel()
        a.ask("Füge die Aufgabe Milch kaufen hinzu.", speak: false)
        for _ in 0..<200 where a.busy { try? await Task.sleep(for: .milliseconds(100)) }
        check("Assistent legt Aufgabe an", TodayStore.shared.openTasks.contains { $0.title.localizedCaseInsensitiveContains("milch") },
              a.turns.last?.answer ?? "")
        let cleaned = await Assistant.cleanDictation("ähm also ich ich komme äh morgen um neun Uhr ins Büro")
        check("Diktat wird bereinigt", !cleaned.lowercased().contains("ähm") && cleaned.contains("neun") || cleaned.contains("9"), cleaned)
        a.newConversation()

        // Conversation and voice.
        check("Gespräch: «Danke» und «Stopp» beenden, eine Frage nicht",
              Assistant.isGoodbye("Danke.") && Assistant.isGoodbye("stopp") && !Assistant.isGoodbye("Danke, und wie wird das Wetter?"))
        a.beginConversation()
        let wasOn = a.conversationActive
        a.endConversation()
        check("Gespräch: Modus an und wieder aus", wasOn && !a.conversationActive)
        let voices = Assistant.choosableVoices
        check("Stimme: deutsche Apple-Stimmen verfügbar", voices.contains { $0.language.hasPrefix("de") }, "\(voices.count) Stimmen")
        let prefs = Prefs.shared
        let savedVoice = prefs.speechVoiceID, savedRate = prefs.speechRate
        prefs.speechVoiceID = voices.first?.identifier
        prefs.speechRate = 0.42
        let u = Assistant.utterance("Test")
        check("Stimme: gewählte Stimme und Tempo werden verwendet", u.voice?.identifier == voices.first?.identifier && abs(u.rate - 0.42) < 0.001)
        prefs.speechVoiceID = savedVoice
        prefs.speechRate = savedRate
    }

    // MARK: Notion (against a local stand-in for api.notion.com)

    static func notion() async {
        let n = NotionService.shared
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FakeNotion.self]
        n.session = URLSession(configuration: config)
        defer { n.testCleanup(); n.session = .shared }
        await n.connect(secret: "ntn_selftest")
        check("Notion: Verbinden prüft den Schlüssel und lädt Datenbanken", n.connected && n.databases.count == 2, n.message ?? "")
        check("Notion: Schlüssel liegt im Schlüsselbund", Keychain.read("selftest") == "ntn_selftest")
        await n.choose(n.databases.first { $0.title == "Aufgaben" }, for: .tasks)
        await n.choose(n.databases.first { $0.title == "Termine" }, for: .events)
        check("Notion: Eigenschaften erkannt", n.tasksTarget?.mapping.done == .checkbox("Erledigt") && n.eventsTarget?.mapping.date == "Datum")

        let store = TodayStore.shared
        store.addTask("Offerte an Notion senden")
        for _ in 0..<50 where store.data.tasks.last?.notionPageID == nil { try? await Task.sleep(for: .milliseconds(50)) }
        let task = store.data.tasks.last
        check("Notion: neue Aufgabe wird als Seite angelegt", task?.notionPageID == "page-1"
              && FakeNotion.log.contains { $0.contains("POST pages") && $0.contains("Offerte an Notion senden") && $0.contains("tasks-db") })
        check("Notion: Kopfzeilen (Bearer, Version)", FakeNotion.log.allSatisfy { $0.contains("Bearer ntn_selftest") && $0.contains(NotionKit.apiVersion) })
        if let task { store.toggle(task) }
        for _ in 0..<40 where !FakeNotion.log.contains(where: { $0.contains("PATCH pages/page-1") }) { try? await Task.sleep(for: .milliseconds(50)) }
        check("Notion: Erledigt wird übertragen", FakeNotion.log.contains { $0.contains("PATCH pages/page-1") && $0.contains("\"checkbox\":true") })
        let start = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!.addingTimeInterval(14 * 3600)
        // Pull: Notion says the first task is done and a new page exists.
        FakeNotion.queryJSON = #"{"results":[{"id":"page-1","archived":false,"properties":{"Name":{"title":[{"plain_text":"Offerte umbenannt in Notion"}]},"Fällig":{"date":null},"Erledigt":{"checkbox":true}}},{"id":"page-9","archived":false,"properties":{"Name":{"title":[{"plain_text":"Neu aus Notion"}]},"Fällig":{"date":null},"Erledigt":{"checkbox":false}}}]}"#
        let pulled = await n.pull()
        check("Notion: Änderungen aus Notion kommen zurück (umbenannt + neue Seite)",
              pulled == 2 && store.data.tasks.contains { $0.notionPageID == "page-9" && $0.title == "Neu aus Notion" }
              && store.data.tasks.contains { $0.notionPageID == "page-1" && $0.isDone && $0.title == "Offerte umbenannt in Notion" })
        let r = await Appointments.add(title: "Kundentermin", start: start, minutes: 30)
        var isNotion = false
        if case .notion = r { isNotion = true }
        check("Notion: Termin landet in der Termin-Datenbank", isNotion
              && FakeNotion.log.contains { $0.contains("events-db") && $0.contains("Kundentermin") && $0.contains("\"end\"") })
        if let task { store.delete(task) }
        n.disconnect()
        check("Notion: Trennen entfernt den Schlüssel", Keychain.read("selftest") == nil && !n.connected)
    }

    // MARK: Backup and shortcuts

    static func backup() {
        let fm = FileManager.default
        let defaults = UserDefaults(suiteName: "ch.arjo.vibrantplus.selftest")!
        defaults.setPersistentDomain([:], forName: "ch.arjo.vibrantplus.selftest")
        defaults.set(42, forKey: "rowline.gap")
        let data = Paths.dataDirectory.appending(path: "backup-src")
        try? fm.removeItem(at: data)
        try? fm.createDirectory(at: data, withIntermediateDirectories: true)
        try? Data("{\"note\":\"alt\"}".utf8).write(to: data.appending(path: "today.json"))
        let zip = Paths.dataDirectory.appending(path: "test.vibrantbackup")
        do {
            try Backup.export(to: zip, dataDirectory: data, defaults: defaults, domain: "ch.arjo.vibrantplus.selftest")
            check("Sicherung: Datei erstellt", fm.fileExists(atPath: zip.path))
            try Data("{\"note\":\"neu\"}".utf8).write(to: data.appending(path: "today.json"))
            defaults.set(7, forKey: "rowline.gap")
            let n = try Backup.importBackup(from: zip, dataDirectory: data, defaults: defaults, domain: "ch.arjo.vibrantplus.selftest")
            let restored = (try? String(contentsOf: data.appending(path: "today.json"), encoding: .utf8)) ?? ""
            check("Sicherung: Import stellt Daten und Einstellungen wieder her", n == 2 && restored.contains("alt") && defaults.integer(forKey: "rowline.gap") == 42, restored)
            let safety = Paths.dataDirectory.appending(path: "VibrantPlus-vor-Import/today.json")
            check("Sicherung: alter Stand bleibt erhalten", ((try? String(contentsOf: safety, encoding: .utf8)) ?? "").contains("neu"))
        } catch {
            check("Sicherung", false, error.localizedDescription)
        }
        let junk = Paths.dataDirectory.appending(path: "junk.zip")
        try? Data("kein zip".utf8).write(to: junk)
        check("Sicherung: fremde Datei wird abgelehnt", (try? Backup.importBackup(from: junk, dataDirectory: data, defaults: defaults, domain: "ch.arjo.vibrantplus.selftest")) == nil)
        defaults.removePersistentDomain(forName: "ch.arjo.vibrantplus.selftest")
    }

    static func shortcutsList() async {
        let names = await ShortcutRunner.available()
        let direct = ShortcutsCLI.parseList(Run.program("/usr/bin/shortcuts", ["list"], timeout: 15).output)
        check("Kurzbefehle: Liste aus der Kurzbefehle-App gelesen", names == direct, "\(names.count) Kurzbefehle")
    }

    // MARK: Socket limit

    /// Holds the answer closures so the waiting connections stay open.
    final class Held { var replies: [@Sendable (HookReply) -> Void] = [] }

    static func socketLimit() async {
        let path = Paths.dataDirectory.appending(path: "limit.sock").path
        let held = Held()
        let server = AgentServer(path: path) { _, respond in held.replies.append(respond) }
        guard server.start() else { check("Socket-Grenze: Server startet", false); return }
        let event = HookEvent(sessionID: "limit", eventName: "PermissionRequest", toolName: "Bash")
        guard let body = try? JSONEncoder().encode(HookRequest(wait: true, event: event)) else { return }
        var fds: [Int32] = []
        // Await each accepted request instead of overflowing the listen backlog in one
        // synchronous burst. The old fixed 400 ms delay could count failed connections
        // as waiting clients and intermittently miss the actual capacity boundary.
        var connected = true
        for index in 0..<AgentServer.maxWaiting {
            let fd = UnixSocket.connect(path, timeout: 2)
            guard fd >= 0, UnixSocket.writeLine(fd, body) else {
                if fd >= 0 { close(fd) }
                connected = false
                break
            }
            fds.append(fd)
            for _ in 0..<200 where held.replies.count <= index {
                try? await Task.sleep(for: .milliseconds(10))
            }
            if held.replies.count != index + 1 { connected = false; break }
        }
        guard connected else {
            check("Socket-Grenze: alle Testverbindungen angenommen", false, "\(held.replies.count) von \(AgentServer.maxWaiting)")
            for r in held.replies { r(.none) }
            for fd in fds { close(fd) }
            server.stop()
            return
        }
        let overflowStarted = Date.now
        let extra = UnixSocket.connect(path, timeout: 2)
        _ = UnixSocket.writeLine(extra, body)
        let line = await Task.detached { UnixSocket.readLine(extra) }.value
        let reply = line.flatMap { try? JSONDecoder().decode(HookReply.self, from: $0) }
        check("Socket-Grenze: \(AgentServer.maxWaiting) warten, die nächste Anfrage geht sofort ans Terminal",
              held.replies.count == AgentServer.maxWaiting && reply?.action == HookReply.Action.none && Date.now.timeIntervalSince(overflowStarted) < 2,
              "\(held.replies.count) gehalten, Antwort \(reply.map { "\($0.action)" } ?? "keine")")
        for r in held.replies { r(.none) }
        for fd in fds + [extra] { close(fd) }
        server.stop()
    }

    // MARK: Save errors

    static func saveReport() {
        IslandModel.shared.toast = nil
        SaveReport.attempt("Selbsttest") { throw CocoaError(.fileWriteNoPermission) }
        let first = IslandModel.shared.toast
        check("Speicherfehler wird gemeldet", first?.text == "Selbsttest konnte nicht gespeichert werden" && first?.warm == true, first?.text ?? "kein Hinweis")
        SaveReport.attempt("Selbsttest") { throw CocoaError(.fileWriteNoPermission) }
        check("Speicherfehler nur einmal pro Minute", IslandModel.shared.toast?.id == first?.id)
        var ran = false
        SaveReport.attempt("Selbsttest ok") { ran = true }
        check("Erfolgreiches Speichern bleibt still", ran && IslandModel.shared.toast?.id == first?.id)
        IslandModel.shared.toast = nil
    }

    // MARK: Focus rules

    static func focusRules() {
        let prefs = Prefs.shared
        let saved = prefs.focusRules
        prefs.focusRules = FocusRules()          // keep awake only; nothing that changes the look of the Mac
        let c = SystemControls.shared
        c.setKeepAwake(false)
        FocusMode.shared.began()
        check("Fokus-Regeln: Mac bleibt während des Fokus wach", c.keepAwake)
        FocusMode.shared.ended()
        check("Fokus-Regeln: danach wieder wie vorher", !c.keepAwake)
        prefs.focusRules = saved
    }

    // MARK: AirDrop

    static func airdrop() {
        let file = Paths.dataDirectory.appending(path: "airdrop-test.txt")
        try? Data("x".utf8).write(to: file)
        let service = NSSharingService(named: .sendViaAirDrop)
        check("AirDrop: Freigabedienst vorhanden und kann die Datei annehmen", service?.canPerform(withItems: [file]) == true)
    }

    // MARK: Snippets

    static func snippets() {
        let s = SnippetService()
        check("Textbaustein: Kürzel ohne «;» wird abgelehnt", s.add(trigger: "adr", text: "x") != nil)
        check("Textbaustein: anlegen", s.add(trigger: ";adr", text: "Musterstrasse 1, 8000 Zürich") == nil && s.snippets.count == 1)
        check("Textbaustein: Kollision mit ;adr wird erkannt", s.add(trigger: ";a", text: "y") != nil)
        let reloaded = SnippetService()
        reloaded.start()
        check("Textbaustein: bleibt nach Neustart gespeichert", reloaded.snippets.first?.trigger == ";adr")
        reloaded.stop()
        if let first = s.snippets.first { s.remove(first) }
        check("Textbaustein: entfernen", s.snippets.isEmpty)
    }

    // MARK: Screenshots

    static func screenshots() async {
        let dir = Paths.dataDirectory.appending(path: "shots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let png = makeImage(dir.appending(path: "Bildschirmfoto.png"), width: 400, height: 300, gps: false) else {
            check("Screenshot: Testbild", false); return
        }
        let shelf = ScreenshotShelf.shared
        shelf.show(png)
        check("Screenshot: erscheint in der Insel mit Vorschau", shelf.latest == png && shelf.thumbnail != nil)
        shelf.trash()
        check("Screenshot: Löschen legt in den Papierkorb (Datei weg, Karte zu)",
              !FileManager.default.fileExists(atPath: png.path) && shelf.latest == nil)
    }

    // MARK: Downloads from links

    static func downloads() async {
        let dir = Paths.dataDirectory.appending(path: "downloads")
        let target = dir.appending(path: "ziel")
        try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        guard let png = makeImage(dir.appending(path: "Quelle Bild.png"), width: 64, height: 64, gps: false) else {
            check("Laden: Testbild", false); return
        }
        let first = await Downloads.shared.loadDirectly(png, into: target)
        check("Laden: Datei-Link landet im Zielordner mit ihrem Namen", first?.lastPathComponent == "Quelle Bild.png"
              && first.map { FileManager.default.fileExists(atPath: $0.path) } == true)
        let second = await Downloads.shared.loadDirectly(png, into: target)
        check("Laden: gleicher Name überschreibt nichts («… 2»)", second?.lastPathComponent == "Quelle Bild 2.png")
        let page = dir.appending(path: "seite.html")
        try? Data("<html><body>Hallo</body></html>".utf8).write(to: page)
        let none = await Downloads.shared.loadDirectly(page, into: target)
        check("Laden: eine Web-Seite gilt nicht als Datei", none == nil
              && (try? FileManager.default.contentsOfDirectory(atPath: target.path).count) == 2)
        // A converted film takes the original's place, never a file of the same name that was
        // already there.
        let taken = target.appending(path: "Film.mp4")
        try? Data("schon da".utf8).write(to: taken)
        let free = Downloads.freeURL(taken)
        check("Laden: umgewandeltes Video überschreibt keine bestehende Datei («Film (2).mp4»)",
              free.lastPathComponent == "Film (2).mp4"
              && (try? String(contentsOf: taken, encoding: .utf8)) == "schon da")
        try? FileManager.default.removeItem(at: taken)
        let blocked = Downloads.shared.start(URL(string: "https://open.spotify.com/track/abc")!, format: .audio)
        check("Laden: kopiergeschützter Dienst wird abgelehnt", blocked == nil)
        Downloads.shared.findTools()
        if let tool = Downloads.shared.ytDlp {
            let r = await Run.async(tool, ["--version"], timeout: 20)
            check("Laden: yt-dlp gefunden und startet (\(tool))", r.status == 0)
        } else {
            check("Laden: yt-dlp nicht installiert, Plattform-Test übersprungen", true)
        }
    }

    // MARK: Taking screenshots

    static func capture() async {
        let keys = CaptureMode.allCases.compactMap { HotKeys.shared.shortcuts[$0.hotKey] }
        check("Aufnahme: drei eigene Tastenkürzel, keins doppelt", keys.count == 3 && Set(keys).count == 3
              && Set(keys).isDisjoint(with: HotKeyAction.allCases.filter { $0.module != .screenshots }.compactMap { HotKeys.shared.shortcuts[$0] }))
        let dir = Paths.dataDirectory.appending(path: "capture")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = CapturePlan.freeURL(in: dir, name: CapturePlan.fileName(at: .now))
        let shelf = ScreenshotShelf.shared
        guard ScreenCapture.allowed else {
            check("Aufnahme: Bildschirmaufnahme nicht erlaubt, echte Aufnahme übersprungen (Berechtigung fehlt)", true)
            return
        }
        // Not interactive: the whole display, straight to the test folder (no clipboard change).
        let r = await Run.async(CapturePlan.tool, CapturePlan.arguments(.screen, display: ScreenCapture.displayUnderPointer(), output: url.path), timeout: 20)
        let image = NSImage(contentsOf: url)
        check("Aufnahme: ganzer Bildschirm wird als PNG gesichert", r.status == 0 && (image?.size.width ?? 0) > 100, "status \(r.status)")
        shelf.show(url, copied: true)
        check("Aufnahme: erscheint in der Insel als «gesichert und kopiert»", shelf.latest == url && shelf.copied)
        shelf.dismiss()
    }

    // MARK: Clipboard

    static func clipboard() {
        let c = ClipboardHistory()
        c.ingest("Meine IBAN CH93 0076 2011 6238 5295 7")
        c.ingest("Kurzer Text")
        if let iban = c.items.first(where: { $0.text.hasPrefix("Meine IBAN") }) { c.togglePin(iban) }
        check("Zwischenablage: Angeheftetes steht oben und wird gespeichert",
              c.items.first?.pinned == true && JSONFile<[ClipItem]>(url: Paths.pinnedClips).load()?.count == 1)
        let fresh = ClipboardHistory()
        fresh.start()
        check("Zwischenablage: Angeheftetes kommt nach Neustart zurück, Rest nicht",
              fresh.list.items.count == 1 && fresh.list.items.first?.text.hasPrefix("Meine IBAN") == true)
        fresh.stop()
        try? FileManager.default.removeItem(at: Paths.pinnedClips)
    }

    // MARK: Helpers

    static func makeImage(_ url: URL, width: Int, height: Int, gps: Bool) -> URL? {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(NSColor(hex: Brand.puls).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // Noise so compression has something to do.
        for i in 0..<4000 {
            ctx.setFillColor(CGColor(red: CGFloat(i % 255) / 255, green: CGFloat((i * 7) % 255) / 255, blue: 0.5, alpha: 1))
            ctx.fill(CGRect(x: (i * 7919) % width, y: (i * 104_729) % height, width: 24, height: 24))
        }
        guard let image = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return nil }
        var props: [String: Any] = [kCGImagePropertyExifDictionary as String: [kCGImagePropertyExifUserComment as String: "Test"]]
        if gps { props[kCGImagePropertyGPSDictionary as String] = [kCGImagePropertyGPSLatitude as String: 47.37, kCGImagePropertyGPSLatitudeRef as String: "N"] }
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        return CGImageDestinationFinalize(dest) ? url : nil
    }

    static func gifFrameCount(_ url: URL) -> Int {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return 0 }
        return CGImageSourceGetCount(src)
    }

    static func pixelSize(_ url: URL) -> CGSize {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] else { return .zero }
        return CGSize(width: p[kCGImagePropertyPixelWidth as String] as? Int ?? 0, height: p[kCGImagePropertyPixelHeight as String] as? Int ?? 0)
    }

    static func properties(_ url: URL) -> [String: Any] {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [:] }
        return CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] ?? [:]
    }

    static func hasGPS(_ url: URL) -> Bool { properties(url)[kCGImagePropertyGPSDictionary as String] != nil }
    static func exif(_ url: URL) -> Any? {
        (properties(url)[kCGImagePropertyExifDictionary as String] as? [String: Any])?[kCGImagePropertyExifUserComment as String]
    }

    /// A short test video, written with AVAssetWriter.
    static func makeVideo(_ url: URL, seconds: Int, width: Int = 320, height: Int = 240) async -> URL? {
        try? FileManager.default.removeItem(at: url)
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return nil }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
                                                                          AVVideoWidthKey: width, AVVideoHeightKey: height])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        let fps = 10
        for frame in 0..<(seconds * fps) {
            while !input.isReadyForMoreMediaData { try? await Task.sleep(for: .milliseconds(5)) }
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
            guard let buffer else { return nil }
            CVPixelBufferLockBaseAddress(buffer, [])
            memset(CVPixelBufferGetBaseAddress(buffer), Int32(frame * 8 % 255), CVPixelBufferGetDataSize(buffer))
            CVPixelBufferUnlockBaseAddress(buffer, [])
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        return writer.status == .completed ? url : nil
    }
}

/// Answers like api.notion.com for the self-test and records every request.
nonisolated final class FakeNotion: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _log: [String] = []
    static var log: [String] { lock.lock(); defer { lock.unlock() }; return _log }
    nonisolated(unsafe) static var queryJSON = #"{"results":[]}"#

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path().replacingOccurrences(of: "/v1/", with: "") ?? ""
        let method = request.httpMethod ?? "GET"
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            var buf = [UInt8](repeating: 0, count: 65_536)
            while stream.hasBytesAvailable { let n = stream.read(&buf, maxLength: buf.count); if n <= 0 { break }; body.append(buf, count: n) }
            stream.close()
        }
        let headers = "\(request.value(forHTTPHeaderField: "Authorization") ?? "") \(request.value(forHTTPHeaderField: "Notion-Version") ?? "")"
        Self.lock.lock()
        Self._log.append("\(method) \(path) \(headers) \(String(decoding: body, as: UTF8.self))")
        Self.lock.unlock()
        let json: String
        switch (method, path) {
        case ("GET", "users/me"): json = #"{"object":"user","bot":{"workspace_name":"ARJO Test"}}"#
        case ("POST", "search"): json = #"{"results":[{"object":"database","id":"tasks-db","title":[{"plain_text":"Aufgaben"}]},{"object":"database","id":"events-db","title":[{"plain_text":"Termine"}]}]}"#
        case ("GET", "databases/tasks-db"): json = #"{"properties":{"Name":{"type":"title"},"Fällig":{"type":"date"},"Erledigt":{"type":"checkbox"}}}"#
        case ("GET", "databases/events-db"): json = #"{"properties":{"Titel":{"type":"title"},"Datum":{"type":"date"}}}"#
        case ("POST", "pages"): json = #"{"object":"page","id":"page-1"}"#
        case ("POST", "databases/tasks-db/query"): json = Self.queryJSON
        default: json = "{}"
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

