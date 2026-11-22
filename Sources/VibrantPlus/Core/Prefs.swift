// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Observation
import VibrantPlusKit

/// The modules a person can turn on and off. A module that is off runs
/// nothing and asks for no permission.
enum Module: String, CaseIterable, Identifiable, Codable {
    case island, agent, assistant, screenshots, downloads, snippets, today, stow, rowline, dial, voice, keys, appGrid, devBar, clipboard, links, mouse, finder, quitProtection, autoQuit, audioDevices, ocr, scratchpad, processes, windowTools, cleaner, uninstaller, homebrew, appUpdates, diskInstaller, systemMonitor, keepAwakeRules, quickTools, cleaning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .windowTools: "Fenster und Dock"
        case .cleaner: "Bereinigen"
        case .uninstaller: "Apps entfernen"
        case .homebrew: "Homebrew"
        case .appUpdates: "App-Updates"
        case .diskInstaller: "DMG-Installation"
        case .systemMonitor: "Systemmonitor"
        case .keepAwakeRules: "Wachhalten mit Regeln"
        case .quickTools: "Schnellwerkzeuge"
        case .cleaning: "Reinigungsmodus"
        case .mouse: "Maus und Eingabe"
        case .finder: "Finder und Einfügen"
        case .quitProtection: "Schutz vor versehentlichem Beenden"
        case .autoQuit: "Nach letztem Fenster beenden"
        case .audioDevices: "Audiogeräte"
        case .ocr: "Text und QR erkennen"
        case .scratchpad: "Notizblock"
        case .processes: "Prozesse und Ports"
        case .island: "Insel"
        case .agent: "Claude Code"
        case .assistant: "Assistent"
        case .screenshots: "Bildschirmfotos"
        case .downloads: "Herunterladen"
        case .snippets: "Textbausteine"
        case .today: "Heute"
        case .stow: "Stow"
        case .rowline: "Rowline"
        case .dial: "Rand-Regler"
        case .voice: "Stimme"
        case .keys: "Tastatur"
        case .appGrid: "App-Raster"
        case .devBar: "Entwicklerleiste"
        case .clipboard: "Zwischenablage"
        case .links: "Links bereinigen"
        }
    }

    var subtitle: String {
        switch self {
        case .windowTools: "Fensterwechsler, Dock-Vorschau, Randsnap, Fokus und Gesten"
        case .cleaner: "Caches und Logs prüfen und ausgewählte Dateien in den Papierkorb legen"
        case .uninstaller: "Apps und genau zugeordnete Reste prüfen und entfernen"
        case .homebrew: "Pakete suchen, installieren, entfernen und aktualisieren"
        case .appUpdates: "Paketupdates prüfen und App Store öffnen"
        case .diskInstaller: "App aus einem Disk-Image in Programme installieren"
        case .systemMonitor: "CPU, RAM, Laufwerk, Netzwerk, Strom und Wärmezustand. Keine GPU-Gradzahlen."
        case .keepAwakeRules: "Timer, Apps, Stromquelle und externe Bildschirme"
        case .quickTools: "Befehlsleiste, Palette und Radialmenü mit Favoriten"
        case .cleaning: "Tastatur für 60 Sekunden sperren, dreimal Esc gibt sie frei"
        case .mouse: "Scrollrichtung, Geschwindigkeit, Seitentasten und Entprellen"
        case .finder: "Ausschneiden, Umbenennen und reinen Text einfügen"
        case .quitProtection: "⌘Q oder ⌘W erst nach einem zweiten Tastendruck ausführen"
        case .autoQuit: "Ausgewählte Apps nach dem letzten geschlossenen Fenster beenden"
        case .audioDevices: "Ausgang und Mikrofon wählen, Eingangspegel und Stummschaltung"
        case .ocr: "Bildschirmbereich oder Bilddatei lokal lesen"
        case .scratchpad: "Mehrere lokale Notizen mit Vorschau und Export"
        case .processes: "Laufende Apps und lokale Server prüfen und gezielt beenden"
        case .island: "Musik, Termine, Wetter und mehr im Notch"
        case .agent: "Claude Code live im Notch, Berechtigungen beantworten"
        case .assistant: "Gespräche mit Apple Intelligence, direkt auf dem Mac"
        case .screenshots: "Bildschirmfotos aufnehmen und in der Insel kopieren, beschriften, teilen, löschen"
        case .downloads: "Video, Bild oder Musik per Link laden"
        case .snippets: "Kürzel wie «;adr» werden in jeder App zu deinem Text"
        case .today: "Aufgaben, Fokus, Notiz und Termine von heute"
        case .stow: "Dateien auf den Notch ziehen und umwandeln"
        case .rowline: "Fenster in einer Reihe und auf Tastendruck"
        case .dial: "Lautstärke, Mixer pro App und Timer am Bildschirmrand"
        case .voice: "Diktieren und Befehle per Stimme (Beta)"
        case .keys: "Tastengeräusche und gedrückte Tasten anzeigen"
        case .appGrid: "Alle Apps im Vollbild"
        case .devBar: "Git-Branch und laufende Server in der Menüleiste"
        case .clipboard: "Verlauf suchen und Texte anheften, auch ohne Insel"
        case .links: "Tracking-Parameter aus Weblinks entfernen, ohne sie aufzurufen"
        }
    }

    var symbol: String {
        switch self {
        case .windowTools: "macwindow"
        case .cleaner: "sparkles"
        case .uninstaller: "trash"
        case .homebrew: "shippingbox"
        case .appUpdates: "arrow.down.app"
        case .diskInstaller: "externaldrive"
        case .systemMonitor: "gauge.with.dots.needle.50percent"
        case .keepAwakeRules: "cup.and.saucer"
        case .quickTools: "command"
        case .cleaning: "keyboard"
        case .mouse: "computermouse"
        case .finder: "folder"
        case .quitProtection: "hand.raised"
        case .autoQuit: "xmark.app"
        case .audioDevices: "hifispeaker"
        case .ocr: "text.viewfinder"
        case .scratchpad: "note.text"
        case .processes: "terminal"
        case .island: "capsule.tophalf.filled"
        case .agent: "sparkles"
        case .assistant: "bubble.left.and.text.bubble.right"
        case .screenshots: "camera.viewfinder"
        case .downloads: "arrow.down.circle"
        case .snippets: "text.insert"
        case .today: "checklist"
        case .stow: "tray.and.arrow.down"
        case .rowline: "rectangle.split.3x1"
        case .dial: "dial.medium"
        case .voice: "waveform"
        case .keys: "keyboard"
        case .appGrid: "square.grid.3x3"
        case .devBar: "arrow.triangle.branch"
        case .clipboard: "doc.on.clipboard"
        case .links: "link"
        }
    }

    /// Where a module lives, for grouped lists (welcome window).
    enum Group: String, CaseIterable {
        case notch = "Im Notch", mac = "Auf dem ganzen Mac"
    }

    var group: Group {
        switch self {
        case .island, .agent, .assistant, .today, .screenshots, .downloads: .notch
        case .snippets, .stow, .rowline, .dial, .voice, .keys, .appGrid, .devBar, .clipboard, .links, .mouse, .finder, .quitProtection, .autoQuit, .audioDevices, .ocr, .scratchpad, .processes, .windowTools, .cleaner, .uninstaller, .homebrew, .appUpdates, .diskInstaller, .systemMonitor, .keepAwakeRules, .quickTools, .cleaning: .mac
        }
    }

    /// Modules on after the first launch: the calm basics.
    static let defaultsOn: Set<Module> = [.island, .agent, .assistant, .screenshots, .downloads, .today, .stow]
}

/// Island tiles, in the order a person chose.
/// The groups the tile strips are split into, one island page each.
enum TileCategory: String, CaseIterable, Identifiable {
    case start, mac, ai, tools
    var id: String { rawValue }
    var title: String {
        switch self {
        case .start: "Start"
        case .mac: "Mac"
        case .ai: "KI"
        case .tools: "Werkzeuge"
        }
    }
}

enum TileKind: String, CaseIterable, Identifiable, Codable {
    case nowPlaying, agent, nextEvent, weather, clock, system, todo, timer, shelf, clipboard, recentApps, controls, shortcuts
    case quickNote, converter, colorPicker, mirror, usage, reminders
    case quitApps, meeting, teleprompter, commands, browserTab

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nowPlaying: "Musik"
        case .agent: "Claude Code"
        case .nextEvent: "Nächster Termin"
        case .weather: "Wetter"
        case .clock: "Uhr und Monat"
        case .system: "Systemwerte"
        case .todo: "Aufgaben"
        case .timer: "Timer"
        case .shelf: "Ablage"
        case .clipboard: "Zwischenablage"
        case .recentApps: "Letzte Apps"
        case .controls: "Steuerungen"
        case .shortcuts: "Kurzbefehle"
        case .quickNote: "Schnellnotiz"
        case .converter: "Umrechner"
        case .colorPicker: "Farbpipette"
        case .mirror: "Spiegel"
        case .usage: "KI-Verbrauch"
        case .reminders: "Erinnerungen"
        case .quitApps: "Apps beenden"
        case .meeting: "Besprechung"
        case .teleprompter: "Teleprompter"
        case .commands: "Befehle"
        case .browserTab: "Browser-Tab"
        }
    }

    var symbol: String {
        switch self {
        case .nowPlaying: "music.note"
        case .agent: "sparkles"
        case .nextEvent: "calendar"
        case .weather: "cloud.sun"
        case .clock: "clock"
        case .system: "gauge.with.dots.needle.50percent"
        case .todo: "checklist"
        case .timer: "timer"
        case .shelf: "tray"
        case .clipboard: "doc.on.clipboard"
        case .recentApps: "square.stack"
        case .controls: "switch.2"
        case .shortcuts: "bolt.fill"
        case .quickNote: "square.and.pencil"
        case .converter: "arrow.left.arrow.right"
        case .colorPicker: "eyedropper"
        case .mirror: "person.crop.square"
        case .usage: "chart.pie"
        case .reminders: "checklist"
        case .quitApps: "xmark.app"
        case .meeting: "text.bubble"
        case .teleprompter: "text.alignleft"
        case .commands: "terminal"
        case .browserTab: "safari"
        }
    }

    /// Which island page the tile lives on. Start stays short; the rest is grouped by what it is for.
    var category: TileCategory {
        switch self {
        case .nowPlaying, .nextEvent, .weather, .todo, .reminders, .clock: .start
        case .system, .recentApps, .controls, .shortcuts, .clipboard, .shelf, .quitApps: .mac
        case .agent, .usage: .ai
        case .timer, .quickNote, .converter, .colorPicker, .mirror, .meeting, .teleprompter, .commands, .browserTab: .tools
        }
    }

    static let defaultOrder: [TileKind] = [.nowPlaying, .agent, .nextEvent, .weather, .todo, .clock, .system, .timer, .shelf, .clipboard, .recentApps, .controls, .shortcuts,
                                           .quickNote, .converter, .colorPicker, .mirror, .usage, .reminders, .quitApps, .meeting, .teleprompter, .commands, .browserTab]
    /// Tiles that arrived in 3.3: switched on once for people who set up an earlier version.
    static let added33: [TileKind] = [.quickNote, .converter, .colorPicker, .mirror]
    /// Tiles that arrived in 3.5: switched on once, like 3.3.
    static let added35: [TileKind] = [.usage, .reminders]
    /// Tiles that arrived in 3.8: switched on once, like 3.3.
    static let added38: [TileKind] = [.quitApps, .meeting]
    /// Teleprompter arrived after 1.0: switched on once, like 3.3.
    static let added11: [TileKind] = [.teleprompter]
    static let added12: [TileKind] = [.commands, .browserTab]
    /// Cards that are 312 pt wide anyway: «Breit» changes nothing for them.
    static let alwaysWide: Set<TileKind> = [.nowPlaying, .agent, .controls, .usage]
    var canWiden: Bool { !Self.alwaysWide.contains(self) }
    static let defaultOn: Set<TileKind> = [.nowPlaying, .agent, .nextEvent, .weather, .todo, .shelf, .controls]
}

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system, night, paper
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "Wie der Mac"
        case .night: "Nacht"
        case .paper: "Papier"
        }
    }
}

enum KeySoundProfile: String, CaseIterable, Identifiable, Codable {
    case soft, click, typewriter, thock, blue, bubble, cherry, kenneyClick, kenneyTick
    case marimba, crystal, raindrop, stones, bricks, arcade, marbles, cockpit
    var id: String { rawValue }
    /// File prefix in Resources/KeySounds when the profile plays recordings; nil when it is synthesized.
    nonisolated var recordingPrefix: String? {
        switch self {
        case .cherry: "cherry"
        case .kenneyClick: "kclick"
        case .kenneyTick: "ktick"
        default: nil
        }
    }
    var title: String {
        switch self {
        case .soft: "Weich"
        case .click: "Klick"
        case .typewriter: "Schreibmaschine"
        case .thock: "Thock (linear)"
        case .blue: "Blauer Schalter"
        case .bubble: "Blubb"
        case .cherry: "Echte Aufnahme (Cherry)"
        case .kenneyClick: "Klick (Kenney)"
        case .kenneyTick: "Tick (Kenney)"
        case .marimba: "Marimba"
        case .crystal: "Kristall"
        case .raindrop: "Regentropfen"
        case .stones: "Flusssteine"
        case .bricks: "Bausteine"
        case .arcade: "Arcade (8-Bit)"
        case .marbles: "Glasmurmeln"
        case .cockpit: "Raumschiff-Cockpit"
        }
    }
}

/// All settings, saved in UserDefaults. Services observe it and start or stop.
@Observable
final class Prefs {
    static let shared = Prefs()
    @ObservationIgnored private let d: UserDefaults = Paths.isOverridden
        ? UserDefaults(suiteName: "ch.arjo.vibrantplus.test." + Paths.dataDirectory.lastPathComponent)!
        : .standard

    var autoCleanLinks: Bool { didSet { d.set(autoCleanLinks, forKey: "links.auto") } }
    var clipboardClearAfter: Double { didSet { d.set(clipboardClearAfter, forKey: "clipboard.clearAfter") } }
    var clipboardClearOnSleep: Bool { didSet { d.set(clipboardClearOnSleep, forKey: "clipboard.clearSleep") } }
    var clipboardDirectPaste: Bool { didSet { d.set(clipboardDirectPaste, forKey: "clipboard.directPaste") } }
    var colorCopyFormat: ColorHex.CopyFormat { didSet { d.set(colorCopyFormat.rawValue, forKey: "colors.format") } }
    var inputRules: InputRules { didSet { d.set(try? JSONEncoder().encode(inputRules), forKey: "input.rules") } }
    var autoQuitApps: Set<String> { didSet { d.set(Array(autoQuitApps), forKey: "apps.autoQuit") } }
    var islandNavigation: IslandNavigation { didSet { d.set(try? JSONEncoder().encode(islandNavigation), forKey: "island.navigation") } }
    var setupStep: Int { didSet { d.set(setupStep, forKey: "setup.step") } }
    var setupSelection: Set<Module> { didSet { d.set(setupSelection.map(\.rawValue), forKey: "setup.selection") } }
    var onboarded: Bool { didSet { d.set(onboarded, forKey: "onboarded") } }
    var modules: Set<Module> { didSet { d.set(modules.map(\.rawValue), forKey: "modules") } }
    var tileOrder: [TileKind] { didSet { d.set(tileOrder.map(\.rawValue), forKey: "tiles.order") } }
    var tilesOn: Set<TileKind> { didSet { d.set(tilesOn.map(\.rawValue), forKey: "tiles.on") } }
    /// Tiles set to the wide width (312 pt) instead of their own.
    var wideTiles: Set<TileKind> { didSet { d.set(wideTiles.map(\.rawValue), forKey: "tiles.wide") } }
    /// A finished meeting transcript is also written as an Apple Notes note.
    /// Pulsi, the mascot on the notch.
    var mascot: Bool { didSet { d.set(mascot, forKey: "island.mascot") } }
    /// A Puls outline lights up around the island when Claude starts, waits for the person or finishes.
    var islandGlow: Bool { didSet { d.set(islandGlow, forKey: "island.glow") } }
    var glowStyle: GlowStyle { didSet { d.set(glowStyle.rawValue, forKey: "island.glowStyle") } }
    /// The outline lights up on copy, paste, cut and undo (needs the keyboard permission).
    var shortcutEcho: Bool { didSet { d.set(shortcutEcho, forKey: "island.shortcutEcho") } }
    /// The outline lights up when the charger is plugged in.
    var chargeGlow: Bool { didSet { d.set(chargeGlow, forKey: "island.chargeGlow") } }
    /// Pulsi reads notices with the system voice (Siri / Spoken Content). Off: toasts only.
    var mascotSpeaks: Bool { didSet { d.set(mascotSpeaks, forKey: "island.mascotSpeaks") } }
    var mascotPlaySounds: Bool { didSet { d.set(mascotPlaySounds, forKey: "island.mascotSounds") } }
    var mascotTapSound: String { didSet { d.set(mascotTapSound, forKey: "island.mascotTapSound") } }
    var mascotDragSound: String { didSet { d.set(mascotDragSound, forKey: "island.mascotDragSound") } }
    var mascotHeyPulsi: Bool { didSet { d.set(mascotHeyPulsi, forKey: "island.heyPulsi") } }
    var appAutoUpdate: Bool { didSet { d.set(appAutoUpdate, forKey: "app.autoUpdate") } }
    var appUpdateLastCheck: Date? {
        didSet { d.set(appUpdateLastCheck?.timeIntervalSince1970, forKey: "app.updateLastCheck") }
    }
    /// Where Pulsi hangs on the open island: distance from the bottom right corner (x to the left is negative, y down is positive).
    var mascotX: Double { didSet { d.set(mascotX, forKey: "island.mascotX") } }
    var mascotY: Double { didSet { d.set(mascotY, forKey: "island.mascotY") } }
    var meetingToNotes: Bool { didSet { d.set(meetingToNotes, forKey: "meeting.notes") } }
    var weatherCity: String { didSet { d.set(weatherCity, forKey: "weather.city") } }
    var openOnHover: Bool { didSet { d.set(openOnHover, forKey: "island.hover") } }
    var showMeetingCountdown: Bool { didSet { d.set(showMeetingCountdown, forKey: "island.meeting") } }
    var healthNotes: Bool { didSet { d.set(healthNotes, forKey: "island.health") } }
    var agentSound: Bool { didSet { d.set(agentSound, forKey: "agent.sound") } }
    var agentSoundName: String { didSet { d.set(agentSoundName, forKey: "agent.soundName") } }
    var rowGap: Double { didSet { d.set(rowGap, forKey: "rowline.gap") } }
    var rowExcluded: [String] { didSet { d.set(rowExcluded, forKey: "rowline.excluded") } }
    var dialLeftEdge: Bool { didSet { d.set(dialLeftEdge, forKey: "dial.left") } }
    var keySounds: Bool { didSet { d.set(keySounds, forKey: "keys.sounds") } }
    var keySoundProfile: KeySoundProfile { didSet { d.set(keySoundProfile.rawValue, forKey: "keys.profile") } }
    var keySoundVolume: Double { didSet { d.set(keySoundVolume, forKey: "keys.volume") } }
    var showKeys: Bool { didSet { d.set(showKeys, forKey: "keys.show") } }
    var showAllKeys: Bool { didSet { d.set(showAllKeys, forKey: "keys.showAll") } }
    var theme: AppTheme { didSet { d.set(theme.rawValue, forKey: "appearance.theme") } }
    var themeSwitchesMac: Bool { didSet { d.set(themeSwitchesMac, forKey: "appearance.mac") } }
    var nightWallpaper: String? { didSet { d.set(nightWallpaper, forKey: "appearance.wallNight") } }
    var paperWallpaper: String? { didSet { d.set(paperWallpaper, forKey: "appearance.wallPaper") } }
    var devProject: String? { didSet { d.set(devProject, forKey: "dev.project") } }
    var lyricsEnabled: Bool { didSet { d.set(lyricsEnabled, forKey: "music.lyrics") } }
    var selectedCalendarIDs: Set<String> { didSet { d.set(Array(selectedCalendarIDs), forKey: "island.calendars") } }
    var clockAnalog: Bool { didSet { d.set(clockAnalog, forKey: "island.clockAnalog") } }
    var islandKeepNotices: Bool { didSet { d.set(islandKeepNotices, forKey: "island.keepNotices") } }
    var recordZoomCursor: Bool { didSet { d.set(recordZoomCursor, forKey: "capture.zoomCursor") } }
    var mixerMemory: MixerMemory { didSet { d.set(try? JSONEncoder().encode(mixerMemory), forKey: "mixer.memory") } }
    var focusRules: FocusRules { didSet { d.set(try? JSONEncoder().encode(focusRules), forKey: "focus.rules") } }
    var shortcutButtons: [ShortcutButton] { didSet { d.set(try? JSONEncoder().encode(shortcutButtons), forKey: "tiles.shortcuts") } }
    var dimAround: Bool { didSet { d.set(dimAround, forKey: "island.dimAround") } }
    /// The bars next to the notch move while music plays. Off: they stand still.
    var equalizerMoves: Bool { didSet { d.set(equalizerMoves, forKey: "island.equalizer") } }
    var conversationMode: Bool { didSet { d.set(conversationMode, forKey: "assistant.conversation") } }
    var speechVoiceID: String? { didSet { d.set(speechVoiceID, forKey: "assistant.voice") } }
    var speechRate: Double { didSet { d.set(speechRate, forKey: "assistant.rate") } }
    var assistantSpeaks: Bool { didSet { d.set(assistantSpeaks, forKey: "assistant.speaks") } }
    var assistantCleansDictation: Bool { didSet { d.set(assistantCleansDictation, forKey: "assistant.cleanDictation") } }
    /// Folder for downloads from links; empty: ~/Downloads.
    var downloadFolder: String { didSet { d.set(downloadFolder, forKey: "downloads.folder") } }
    var downloadAudio: AudioFormat { didSet { d.set(downloadAudio.rawValue, forKey: "downloads.audio") } }
    var downloadQuality: VideoQuality { didSet { d.set(downloadQuality.rawValue, forKey: "downloads.quality") } }
    /// What was typed but not saved yet. A draft outlives the tile: a request or a reminder that
    /// takes the island over must never swallow a half-written thought.
    /// The script and speed (points per second) of the teleprompter.
    var teleprompterText: String { didSet { d.set(teleprompterText, forKey: "island.teleprompterText") } }
    var teleprompterSpeed: Double { didSet { d.set(teleprompterSpeed, forKey: "island.teleprompterSpeed") } }
    /// Shell commands saved in the «Befehle» tile; they run only when the person presses their button.
    var savedCommands: [String] { didSet { d.set(savedCommands, forKey: "island.savedCommands") } }
    var noteDraft: String { didSet { d.set(noteDraft, forKey: "island.noteDraft") } }
    var converterDraft: String { didSet { d.set(converterDraft, forKey: "island.converterDraft") } }

    private init() {
        autoCleanLinks = d.bool(forKey: "links.auto")
        clipboardClearAfter = d.double(forKey: "clipboard.clearAfter")
        clipboardClearOnSleep = d.bool(forKey: "clipboard.clearSleep")
        clipboardDirectPaste = d.bool(forKey: "clipboard.directPaste")
        colorCopyFormat = ColorHex.CopyFormat(rawValue: d.string(forKey: "colors.format") ?? "") ?? .hex
        inputRules = d.data(forKey: "input.rules").flatMap { try? JSONDecoder().decode(InputRules.self, from: $0) } ?? InputRules()
        autoQuitApps = Set(d.stringArray(forKey: "apps.autoQuit") ?? [])
        islandNavigation = d.data(forKey: "island.navigation").flatMap { try? JSONDecoder().decode(IslandNavigation.self, from: $0) } ?? IslandNavigation()
        setupStep = min(3, max(0, d.integer(forKey: "setup.step")))
        setupSelection = Set((d.stringArray(forKey: "setup.selection") ?? Module.defaultsOn.map(\.rawValue)).compactMap(Module.init))
        onboarded = d.bool(forKey: "onboarded")
        var mods = Set((d.stringArray(forKey: "modules") ?? Module.defaultsOn.map(\.rawValue)).compactMap(Module.init))
        // The assistant arrived in 1.1: on once for people who set up 1.0.
        if !d.bool(forKey: "modules.assistantMigrated") { mods.insert(.assistant); d.set(true, forKey: "modules.assistantMigrated") }
        if !d.bool(forKey: "modules.screenshotsMigrated") { mods.insert(.screenshots); d.set(true, forKey: "modules.screenshotsMigrated") }
        // The link downloader arrived in 3.1: on once, like the screenshots.
        if !d.bool(forKey: "modules.downloadsMigrated") { mods.insert(.downloads); d.set(true, forKey: "modules.downloadsMigrated") }
        modules = mods
        // didSet does not run inside init: save the migrated set here.
        d.set(mods.map(\.rawValue), forKey: "modules")
        let order = (d.stringArray(forKey: "tiles.order") ?? []).compactMap(TileKind.init)
        // New tiles from a later version join at the end.
        tileOrder = order + TileKind.defaultOrder.filter { !order.contains($0) }
        var tiles = Set((d.stringArray(forKey: "tiles.on") ?? TileKind.defaultOn.map(\.rawValue)).compactMap(TileKind.init))
        // Schnellnotiz, Umrechner, Farbpipette and Spiegel arrived in 3.3: on once, so they are found.
        if !d.bool(forKey: "tiles.added33Migrated") {
            tiles.formUnion(TileKind.added33)
            d.set(true, forKey: "tiles.added33Migrated")
            d.set(tiles.map(\.rawValue), forKey: "tiles.on")
        }
        // KI-Verbrauch and Erinnerungen arrived in 3.5: on once, so they are found.
        if !d.bool(forKey: "tiles.added35Migrated") {
            tiles.formUnion(TileKind.added35)
            d.set(true, forKey: "tiles.added35Migrated")
            d.set(tiles.map(\.rawValue), forKey: "tiles.on")
        }
        if !d.bool(forKey: "tiles.added11Migrated") {
            tiles.formUnion(TileKind.added11)
            d.set(true, forKey: "tiles.added11Migrated")
            d.set(tiles.map(\.rawValue), forKey: "tiles.on")
        }
        if !d.bool(forKey: "tiles.added12Migrated") {
            tiles.formUnion(TileKind.added12)
            d.set(true, forKey: "tiles.added12Migrated")
            d.set(tiles.map(\.rawValue), forKey: "tiles.on")
        }
        // Apps beenden and Besprechung arrived in 3.8: on once, so they are found.
        if !d.bool(forKey: "tiles.added38Migrated") {
            tiles.formUnion(TileKind.added38)
            d.set(true, forKey: "tiles.added38Migrated")
            d.set(tiles.map(\.rawValue), forKey: "tiles.on")
        }
        tilesOn = tiles
        wideTiles = Set((d.stringArray(forKey: "tiles.wide") ?? []).compactMap(TileKind.init))
        mascot = d.object(forKey: "island.mascot") as? Bool ?? true
        islandGlow = d.object(forKey: "island.glow") as? Bool ?? true
        glowStyle = GlowStyle(rawValue: d.string(forKey: "island.glowStyle") ?? "") ?? .wave
        shortcutEcho = d.object(forKey: "island.shortcutEcho") as? Bool ?? false
        chargeGlow = d.object(forKey: "island.chargeGlow") as? Bool ?? true
        mascotSpeaks = d.bool(forKey: "island.mascotSpeaks")
        mascotPlaySounds = d.object(forKey: "island.mascotSounds") as? Bool ?? true
        mascotTapSound = d.string(forKey: "island.mascotTapSound") ?? "Tink"
        mascotDragSound = d.string(forKey: "island.mascotDragSound") ?? "Purr"
        mascotHeyPulsi = d.bool(forKey: "island.heyPulsi")
        appAutoUpdate = d.bool(forKey: "app.autoUpdate")
        if d.object(forKey: "app.updateLastCheck") != nil {
            appUpdateLastCheck = Date(timeIntervalSince1970: d.double(forKey: "app.updateLastCheck"))
        }
        mascotX = d.object(forKey: "island.mascotX") as? Double ?? -24
        mascotY = d.object(forKey: "island.mascotY") as? Double ?? 30
        meetingToNotes = d.object(forKey: "meeting.notes") as? Bool ?? false
        weatherCity = d.string(forKey: "weather.city") ?? ""
        downloadFolder = d.string(forKey: "downloads.folder") ?? ""
        downloadAudio = AudioFormat(rawValue: d.string(forKey: "downloads.audio") ?? "") ?? .m4a
        downloadQuality = VideoQuality(rawValue: d.string(forKey: "downloads.quality") ?? "") ?? .standard
        noteDraft = d.string(forKey: "island.noteDraft") ?? ""
        savedCommands = d.stringArray(forKey: "island.savedCommands") ?? []
        teleprompterText = d.string(forKey: "island.teleprompterText") ?? ""
        let speed = d.double(forKey: "island.teleprompterSpeed")
        teleprompterSpeed = speed > 0 ? speed : 24
        converterDraft = d.string(forKey: "island.converterDraft") ?? ""
        openOnHover = d.object(forKey: "island.hover") as? Bool ?? true
        showMeetingCountdown = d.object(forKey: "island.meeting") as? Bool ?? true
        healthNotes = d.object(forKey: "island.health") as? Bool ?? true
        agentSound = d.object(forKey: "agent.sound") as? Bool ?? true
        agentSoundName = d.string(forKey: "agent.soundName") ?? "Glass"
        rowGap = d.object(forKey: "rowline.gap") as? Double ?? 8
        rowExcluded = d.stringArray(forKey: "rowline.excluded") ?? ["com.apple.finder"]
        dialLeftEdge = d.object(forKey: "dial.left") as? Bool ?? true
        keySounds = d.bool(forKey: "keys.sounds")
        keySoundProfile = KeySoundProfile(rawValue: d.string(forKey: "keys.profile") ?? "") ?? .click
        keySoundVolume = d.object(forKey: "keys.volume") as? Double ?? 0.5
        showKeys = d.bool(forKey: "keys.show")
        showAllKeys = d.bool(forKey: "keys.showAll")
        theme = AppTheme(rawValue: d.string(forKey: "appearance.theme") ?? "") ?? .system
        themeSwitchesMac = d.bool(forKey: "appearance.mac")
        nightWallpaper = d.string(forKey: "appearance.wallNight")
        paperWallpaper = d.string(forKey: "appearance.wallPaper")
        devProject = d.string(forKey: "dev.project")
        // Off until the person turns it on: it sends the song title and artist to LRCLIB.
        lyricsEnabled = d.object(forKey: "music.lyrics") as? Bool ?? false
        selectedCalendarIDs = Set(d.stringArray(forKey: "island.calendars") ?? [])
        clockAnalog = d.bool(forKey: "island.clockAnalog")
        islandKeepNotices = d.bool(forKey: "island.keepNotices")
        recordZoomCursor = d.bool(forKey: "capture.zoomCursor")
        mixerMemory = d.data(forKey: "mixer.memory").flatMap { try? JSONDecoder().decode(MixerMemory.self, from: $0) } ?? MixerMemory()
        focusRules = d.data(forKey: "focus.rules").flatMap { try? JSONDecoder().decode(FocusRules.self, from: $0) } ?? FocusRules()
        shortcutButtons = d.data(forKey: "tiles.shortcuts").flatMap { try? JSONDecoder().decode([ShortcutButton].self, from: $0) } ?? []
        dimAround = d.object(forKey: "island.dimAround") as? Bool ?? true
        equalizerMoves = d.object(forKey: "island.equalizer") as? Bool ?? true
        conversationMode = d.object(forKey: "assistant.conversation") as? Bool ?? true
        speechVoiceID = d.string(forKey: "assistant.voice")
        speechRate = d.object(forKey: "assistant.rate") as? Double ?? 0.5
        assistantSpeaks = d.object(forKey: "assistant.speaks") as? Bool ?? true
        assistantCleansDictation = d.object(forKey: "assistant.cleanDictation") as? Bool ?? true
    }

    func isOn(_ m: Module) -> Bool { modules.contains(m) }

    func set(_ m: Module, _ on: Bool) {
        if on { modules.insert(m) } else { modules.remove(m) }
    }

    /// Moves `tile` into the place of `other`.
    func moveTile(_ tile: TileKind, onto other: TileKind) {
        tileOrder = Arrange.move(tile, onto: other, in: tileOrder)
    }

    func toggleWide(_ tile: TileKind) {
        if wideTiles.contains(tile) { wideTiles.remove(tile) } else { wideTiles.insert(tile) }
    }

    func visibleTiles(in category: TileCategory) -> [TileKind] {
        visibleTiles.filter { $0.category == category }
    }

    var visibleTiles: [TileKind] {
        tileOrder.filter { tilesOn.contains($0) && (($0 != .agent) || isOn(.agent)) && (($0 != .todo && $0 != .quickNote) || isOn(.today)) }
    }
}
