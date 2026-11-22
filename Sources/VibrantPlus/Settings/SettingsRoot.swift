// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import EventKit
import Speech
import SwiftUI
import UniformTypeIdentifiers
import VibrantPlusKit

enum SettingsPage: String, CaseIterable, Identifiable {
    case windowTools, cleaner, uninstaller, homebrew, appUpdates, diskInstaller, systemMonitor, keepAwakeRules, quickTools, cleaning, mouse, finder, quitProtection, autoQuit, audioDevices, ocr, scratchpad, processes, general, features, clipboard, links, appGrid, devBar, island, pulsi, agent, assistant, meeting, screenshots, downloads, snippets, notion, today, stow, rowline, dial, voice, keys, appearance, shortcuts, permissions, about
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
        case .general: "Allgemein"
        case .features: "Funktionen"
        case .clipboard: "Zwischenablage"
        case .links: "Links bereinigen"
        case .appGrid: "App-Raster"
        case .devBar: "Entwicklerleiste"
        case .island: "Insel"
        case .pulsi: "Pulsi"
        case .agent: "Claude Code"
        case .assistant: "Assistent"
        case .meeting: "Besprechung"
        case .screenshots: "Bildschirmfotos"
        case .downloads: "Herunterladen"
        case .snippets: "Textbausteine"
        case .notion: "Notion"
        case .today: "Heute"
        case .stow: "Stow"
        case .rowline: "Rowline"
        case .dial: "Rand-Regler"
        case .voice: "Stimme"
        case .keys: "Tastatur"
        case .appearance: "Darstellung"
        case .shortcuts: "Kurzbefehle"
        case .permissions: "Berechtigungen"
        case .about: "Über"
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
        case .general: "gearshape"
        case .features: "square.grid.2x2"
        case .clipboard: "doc.on.clipboard"
        case .links: "link"
        case .appGrid: "square.grid.3x3"
        case .devBar: "arrow.triangle.branch"
        case .island: "capsule.tophalf.filled"
        case .pulsi: "heart.fill"
        case .agent: "sparkles"
        case .assistant: "bubble.left.and.text.bubble.right"
        case .meeting: "text.bubble"
        case .screenshots: "camera.viewfinder"
        case .downloads: "arrow.down.circle"
        case .snippets: "text.insert"
        case .notion: "doc.text.below.ecg"
        case .today: "checklist"
        case .stow: "tray.and.arrow.down"
        case .rowline: "rectangle.split.3x1"
        case .dial: "dial.medium"
        case .voice: "waveform"
        case .keys: "keyboard"
        case .appearance: "paintpalette"
        case .shortcuts: "command"
        case .permissions: "hand.raised"
        case .about: "info.circle"
        }
    }

    /// Sidebar sections, in order.
    enum Group: String, CaseIterable {
        case general = "Allgemein", island = "Insel und Claude", tools = "Werkzeuge"
    }

    var group: Group {
        switch self {
        case .windowTools, .cleaner, .uninstaller, .homebrew, .appUpdates, .diskInstaller, .systemMonitor, .keepAwakeRules, .quickTools, .cleaning: .tools
        case .mouse, .finder, .quitProtection, .autoQuit, .audioDevices, .ocr, .scratchpad, .processes: .tools
        case .general, .features, .appearance, .shortcuts, .permissions, .about: .general
        case .island, .pulsi, .agent, .assistant, .meeting, .today, .screenshots, .downloads: .island
        case .clipboard, .links, .appGrid, .devBar, .snippets, .notion, .stow, .rowline, .dial, .voice, .keys: .tools
        }
    }

    var module: Module? {
        switch self {
        case .windowTools: .windowTools
        case .cleaner: .cleaner
        case .uninstaller: .uninstaller
        case .homebrew: .homebrew
        case .appUpdates: .appUpdates
        case .diskInstaller: .diskInstaller
        case .systemMonitor: .systemMonitor
        case .keepAwakeRules: .keepAwakeRules
        case .quickTools: .quickTools
        case .cleaning: .cleaning
        case .mouse: .mouse
        case .finder: .finder
        case .quitProtection: .quitProtection
        case .autoQuit: .autoQuit
        case .audioDevices: .audioDevices
        case .ocr: .ocr
        case .scratchpad: .scratchpad
        case .processes: .processes
        case .clipboard: .clipboard
        case .links: .links
        case .appGrid: .appGrid
        case .devBar: .devBar
        case .island: .island
        case .agent: .agent
        case .assistant: .assistant
        case .screenshots: .screenshots
        case .downloads: .downloads
        case .snippets: .snippets
        case .today: .today
        case .stow: .stow
        case .rowline: .rowline
        case .dial: .dial
        case .voice: .voice
        case .keys: .keys
        default: nil
        }
    }
}

/// Settings: a sidebar with one page per topic, one grouped form per page.
struct SettingsRoot: View {
    @Bindable private var navigation = SettingsNavigation.shared
    @State private var query = ""
    @State private var prefs = Prefs.shared

    private func visible(_ page: SettingsPage) -> Bool {
        let matches = page.title.localizedStandardContains(query) || (page.module?.matches(query) ?? false)
        if !query.isEmpty { return matches }
        return page.module.map { prefs.isOn($0) } ?? true
    }

    static var initialPage: SettingsPage {
        SettingsPage(rawValue: ProcessInfo.processInfo.environment["APP_SETTINGS_PAGE"] ?? "") ?? .general
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.page) {
                ForEach(SettingsPage.Group.allCases, id: \.self) { group in
                    Section(group.rawValue) {
                        ForEach(SettingsPage.allCases.filter { $0.group == group && visible($0) }) { p in
                            Label(p.title, systemImage: p.symbol).tag(p)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Einstellungen suchen")
            .overlay {
                if !query.isEmpty && !SettingsPage.allCases.contains(where: visible) {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationSplitViewColumnWidth(min: 192, ideal: 192, max: 240)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            SettingsPageView(page: navigation.page)
                .navigationTitle(navigation.page.title)
        }
        .frame(width: 760, height: 560)
        // Like System Settings: the window is named after the page it shows.
        .onChange(of: navigation.page, initial: true) { Windows.retitle(.settings, navigation.page.title) }
    }
}

struct SettingsPageView: View {
    var page: SettingsPage
    @State private var prefs = Prefs.shared

    var body: some View {
        Form {
            if let m = page.module {
                Section {
                    Toggle(isOn: Binding(get: { prefs.isOn(m) }, set: { prefs.set(m, $0) })) {
                        Text(m.title + " einschalten")
                        Text(m.subtitle)
                    }
                }
            }
            switch page {
            case .mouse: InputToolsSettings(kind: .mouse)
            case .finder: InputToolsSettings(kind: .finder)
            case .quitProtection: InputToolsSettings(kind: .quitProtection)
            case .autoQuit: AutoQuitSettings()
            case .audioDevices: AudioDeviceSettings()
            case .ocr: OCRSettings()
            case .scratchpad: ScratchpadSettings()
            case .processes: ProcessSettings()
            case .windowTools: WindowToolsSettings()
            case .cleaner: CleanerSettings(enabled: prefs.isOn(.cleaner))
            case .uninstaller: UninstallerSettings(enabled: prefs.isOn(.uninstaller))
            case .homebrew: HomebrewSettings(enabled: prefs.isOn(.homebrew))
            case .appUpdates: AppUpdateSettings(enabled: prefs.isOn(.appUpdates))
            case .diskInstaller: DiskInstallerSettings(enabled: prefs.isOn(.diskInstaller))
            case .systemMonitor: SystemMonitorSettings()
            case .keepAwakeRules: KeepAwakeRulesSettings()
            case .quickTools: QuickToolsSettings()
            case .cleaning: CleaningModeSettings()
            case .general: GeneralSettings()
            case .features: FeatureSettings()
            case .clipboard: ClipboardSettings()
            case .links: LinkSettings()
            case .appGrid: AppGridSettings()
            case .devBar: DevBarSettings()
            case .island: IslandSettings()
            case .pulsi: PulsiSettings()
            case .agent: AgentSettings()
            case .assistant: AssistantSettings()
            case .meeting: MeetingSettings()
            case .screenshots: ScreenshotSettings()
            case .downloads: DownloadSettings()
            case .snippets: SnippetSettings()
            case .notion: NotionSettings()
            case .today: TodaySettings()
            case .stow: StowSettings()
            case .rowline: RowlineSettings()
            case .dial: DialSettings()
            case .voice: VoiceSettings()
            case .keys: KeysSettings()
            case .appearance: AppearanceSettings()
            case .shortcuts: ShortcutSettings()
            case .permissions: PermissionSettings()
            case .about: AboutSettings()
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Pages

struct GeneralSettings: View {
    @State private var prefs = Prefs.shared
    @State private var login = Coordinator.launchesAtLogin
    @State private var loginError: String?

    var body: some View {
        Section("Start") {
            Toggle("Beim Anmelden öffnen", isOn: $login)
                .onChange(of: login) { loginError = Coordinator.setLaunchAtLogin(login) }
            if let loginError { Text(loginError).foregroundStyle(Palette.danger).font(.caption) }
        }
        Section("Werkzeuge") {
            Button("Funktionen verwalten…") { AppActions.openSettings(.features) }
            Button("Ersteinrichtung erneut öffnen…") {
                prefs.setupSelection = prefs.modules
                prefs.setupStep = 0
                Windows.show(.welcome)
            }
            Text("Suche Werkzeuge, wähle ein Profil oder schalte einzelne Module ein und aus.")
                .foregroundStyle(.secondary)
        }
        Section {
            HStack {
                Button("Sicherung exportieren…") { BackupUI.export() }
                Button("Sicherung importieren…") { BackupUI.importBackup() }
            }
            if let m = BackupUI.message { Text(m).foregroundStyle(.secondary) }
        } header: {
            Text("Sicherung")
        } footer: {
            Text("Eine Datei mit Aufgaben, Notiz, Textbausteinen, angehefteten Texten, Fensteranordnungen, Claude-Verlauf und allen Einstellungen. Der Notion-Schlüssel ist nicht enthalten. Beim Importieren landet der alte Stand in «VibrantPlus-vor-Import» neben dem Datenordner.")
        }
        Section("Datenschutz") {
            LabeledContent("Konto, Analyse, Tracking", value: "Keine")
            LabeledContent("Internet", value: "Wetter (Open-Meteo), Spotify-Cover, Liedtexte (LRCLIB), Notion nur auf Wunsch")
            LabeledContent("Daten", value: "~/Library/Application Support/VibrantPlus")
        }
    }
}

struct PulsiSettings: View {
    @State private var prefs = Prefs.shared
    private var wake = PulsiWake.shared
    var body: some View {
        Section("Leuchtumriss") {
            Toggle("Insel leuchtet, wenn Claude startet, wartet oder fertig ist", isOn: $prefs.islandGlow)
            Picker("Bewegung", selection: $prefs.glowStyle) {
                ForEach(GlowStyle.allCases) { Text($0.title).tag($0) }
            }
            .disabled(!prefs.islandGlow)
            Toggle("Auch bei Kopieren, Einfügen, Ausschneiden und Zurücknehmen (⌘C, ⌘V, ⌘X, ⌘Z)", isOn: $prefs.shortcutEcho)
                .disabled(!prefs.islandGlow)
                .onChange(of: prefs.shortcutEcho) { KeyMonitor.shared.update() }
            Toggle("Beim Anstecken des Netzteils", isOn: $prefs.chargeGlow)
                .disabled(!prefs.islandGlow)
            Text("Ein Puls-Umriss läuft kurz um die Insel; bei einer Frage bleibt er stehen. Das Kurzbefehl-Echo braucht die Bedienungshilfen-Berechtigung. Mit «Bewegung reduzieren» ohne Lauf.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Pulsi") {
            Toggle("Pulsi am Notch zeigen", isOn: $prefs.mascot)
                .onChange(of: prefs.mascot) {
                    if !prefs.mascot { prefs.mascotSpeaks = false; prefs.mascotHeyPulsi = false; PulsiVoice.shared.stop() }
                    PulsiWake.shared.update()
                }
            Toggle("Pulsi spricht (Systemstimme / Siri)", isOn: $prefs.mascotSpeaks)
                .disabled(!prefs.mascot)
                .onChange(of: prefs.mascotSpeaks) { if !prefs.mascotSpeaks { PulsiVoice.shared.stop() } }
            Text("Aus: Hinweise nur als Text. Ein: Pulsi sagt, wenn Claude fertig ist oder fragt, und wenn Dateien zum Umwandeln bereitliegen. Stimme: Systemeinstellungen › Bedienungshilfen › Gesprochener Inhalt.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Pulsi-Stimme") {
            Toggle("Eigene Geräusche beim Antippen und Ziehen", isOn: $prefs.mascotPlaySounds)
                .disabled(!prefs.mascot)
            HStack {
                Button("Antippen") { PulsiSounds.shared.play(.tap, force: true) }
                Button("Ziehen") { PulsiSounds.shared.play(.drag, force: true) }
                Button("Landen") { PulsiSounds.shared.play(.land, force: true) }
            }
            .disabled(!prefs.mascot)
            Text("Drei kurze Rufe, die Vibrant+ selbst erzeugt: kein Systemklang, keine fremde Datei.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Hey Pulsi · Beta") {
            Toggle("Mit «Hey Pulsi» zuhören (Beta)", isOn: $prefs.mascotHeyPulsi)
                .disabled(!prefs.mascot)
                .onChange(of: prefs.mascotHeyPulsi) {
                    PulsiWake.shared.update()
                    if prefs.mascotHeyPulsi {
                        IslandModel.shared.show(Toast(symbol: "ear", text: "Hey Pulsi (Beta): sag «Hey Pulsi»"), seconds: 5)
                    }
                }
            if PulsiWake.shared.running {
                Label("Hört jetzt zu (Beta). Sag laut «Hey Pulsi».", systemImage: "ear")
                    .foregroundStyle(Palette.accentText)
            } else if let message = PulsiWake.shared.message {
                Text(message).foregroundStyle(.secondary)
            } else if prefs.mascotHeyPulsi {
                Text("Startet das Zuhören…").foregroundStyle(.secondary)
            }
            Text("Beta: macOS-Diktat, kein Siri-Weckruf. Unklare Aussprache kann danebengehen. Wenn es klappt, öffnet sich die Insel, Pulsi piepst, sagt «Ja?» und «Frag mich…» erscheint. Braucht Mikrofon und Spracherkennung. Der Ton wird nicht gespeichert.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section {
            Button("Position zurücksetzen") { prefs.mascotX = -24; prefs.mascotY = 30 }
                .disabled(!prefs.mascot)
        }
    }
}

struct IslandSettings: View {
    @State private var prefs = Prefs.shared
    @State private var available: [String] = []
    @State private var city = Prefs.shared.weatherCity

    var body: some View {
        IslandNavigationSettings()
        SceneSettings()
        Section("Verhalten") {
            Toggle("Öffnen, wenn die Maus auf den Notch zeigt", isOn: $prefs.openOnHover)
                .task { available = await ShortcutRunner.available(); CalendarService.shared.reload() }
            Toggle("Countdown 5 Minuten vor einem Termin", isOn: $prefs.showMeetingCountdown)
            Toggle("Hinweise bei wenig Speicher, Akku oder Wärme", isOn: $prefs.healthNotes)
            Toggle("Synchronisierte Liedtexte zeigen (LRCLIB)", isOn: $prefs.lyricsEnabled)
            Toggle("Umgebung überblenden, solange die Insel offen ist", isOn: $prefs.dimAround)
            Toggle("Equalizer neben dem Notch bewegt sich, solange Musik läuft", isOn: $prefs.equalizerMoves)
            Toggle("Analoge Uhr in der Kachel Uhr und Monat", isOn: $prefs.clockAnalog)
            Toggle("Letzte Insel-Hinweise merken", isOn: $prefs.islandKeepNotices)
            Text("Zwei Finger nach unten schliesst die offene Insel. Seitwärts am Rand der Kachelreihe wechselt die Seite. Hinweise sind nur die von Vibrant+ gezeigten, keine fremden Systemmitteilungen.")
                .font(.caption).foregroundStyle(.secondary)
        }
        if CalendarService.shared.granted {
            Section("Kalender") {
                ForEach(CalendarService.shared.calendars, id: \.id) { cal in
                    Toggle(cal.title, isOn: Binding(get: {
                        Prefs.shared.selectedCalendarIDs.isEmpty || Prefs.shared.selectedCalendarIDs.contains(cal.id)
                    }, set: { on in
                        var selected = Prefs.shared.selectedCalendarIDs
                        if selected.isEmpty { selected = Set(CalendarService.shared.calendars.map(\.id)) }
                        if on { selected.insert(cal.id) } else { selected.remove(cal.id) }
                        Prefs.shared.selectedCalendarIDs = selected.count == CalendarService.shared.calendars.count ? [] : selected
                        CalendarService.shared.reload()
                    }))
                }
                Text("Keine Auswahl bedeutet alle Kalender. Nur EventKit-Lesen, keine fremden Kalender-APIs.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        Section {
            List {
                ForEach(prefs.tileOrder) { t in
                    Toggle(isOn: Binding(get: { prefs.tilesOn.contains(t) }, set: { on in
                        if on { prefs.tilesOn.insert(t) } else { prefs.tilesOn.remove(t) }
                    })) {
                        HStack {
                            Label(t.title, systemImage: t.symbol)
                            Spacer()
                            Text(t.category.title).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove { prefs.tileOrder.move(fromOffsets: $0, toOffset: $1) }
            }
        } header: {
            Text("Kacheln")
        } footer: {
            Text("Jede Kachel steht auf der Seite, die rechts genannt ist: Start, Mac, KI oder Werkzeuge. Eine Seite ohne eingeschaltete Kachel verschwindet. Ziehen zum Sortieren. In der Insel: Rechtsklick auf eine Kachel für Reihenfolge und Breite («Breit» macht sie 312 pt breit), oder «Kacheln anordnen» zum Ziehen. Jede Kachel arbeitet nur, solange sie eingeschaltet ist.")
        }
        Section {
            ForEach(prefs.shortcutButtons) { b in
                HStack {
                    Label(b.name, systemImage: b.symbol)
                    Spacer()
                    Button("Entfernen", systemImage: "minus.circle") { prefs.shortcutButtons.removeAll { $0.id == b.id } }
                        .labelStyle(.iconOnly).buttonStyle(.borderless)
                }
            }
            if prefs.shortcutButtons.count < ShortcutsCLI.maxButtons {
                Menu("Kurzbefehl hinzufügen") {
                    ForEach(available.filter { n in !prefs.shortcutButtons.contains { $0.name == n } }, id: \.self) { n in
                        Button(n) { prefs.shortcutButtons.append(ShortcutButton(name: n)) }
                    }
                }
                .disabled(available.isEmpty)
            }
        } header: {
            Text("Kurzbefehle in der Insel")
        } footer: {
            Text("Bis zu 8 Kurzbefehle aus der Kurzbefehle-App erscheinen als Knöpfe in der Kachel «Kurzbefehle». So erweiterst du die Insel ohne Programmieren: alles, was ein Kurzbefehl kann (Smart Home, Nachrichten, Dateien …), liegt dann einen Klick entfernt.")
        }
        Section {
            TextField("Stadt", text: $city, prompt: Text("z. B. Zürich"))
                .onSubmit { prefs.weatherCity = city; WeatherService.shared.refresh(force: true) }
            Button("Wetter laden") { prefs.weatherCity = city; WeatherService.shared.refresh(force: true) }
            if let w = WeatherService.shared.current { LabeledContent("Gefunden", value: "\(w.place), \(Int(w.temperature.rounded()))°") }
            if let e = WeatherService.shared.error { Text(e).foregroundStyle(Palette.danger) }
        } header: {
            Text("Wetter")
        } footer: {
            Text("Nur der Stadtname geht an Open-Meteo, nie dein Standort.")
        }
    }
}

struct AgentSettings: View {
    @State private var prefs = Prefs.shared
    private var agent = AgentStore.shared
    private var usage = UsageStore.shared
    private let sounds = ["Glass", "Ping", "Pop", "Purr", "Tink", "Hero", "Submarine"]

    var body: some View {
        Section {
            LabeledContent("Status") {
                if agent.hooksOutdated {
                    Label("Verbindung veraltet", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.caution)
                } else {
                    Label(agent.hooksInstalled ? "Verbunden" : "Nicht verbunden",
                          systemImage: agent.hooksInstalled ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(agent.hooksInstalled ? Palette.accentText : .secondary)
                }
            }
            if agent.hooksOutdated {
                Text("Claude Code ruft eine andere Kopie von Vibrant+ auf (verschoben oder aus einem anderen Ordner verbunden). «Verbindung erneuern» trägt diese Kopie ein.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                Button(agent.hooksInstalled ? "Verbindung erneuern" : "Mit Claude Code verbinden") { agent.installHooks() }
                    .buttonStyle(.borderedProminent)
                if agent.hooksInstalled {
                    Button("Trennen") { agent.removeHooks() }
                }
            }
            if let e = agent.lastError { Text(e).foregroundStyle(Palette.danger) }
            if !agent.serverRunning && prefs.isOn(.agent) { Text("Der Agent-Dienst läuft nicht.").foregroundStyle(Palette.danger) }
        } header: {
            Text("Verbindung")
        } footer: {
            Text("Trägt Vibrant+ als Hook in ~/.claude/settings.json ein (eine Sicherung des Originals liegt daneben). Andere Einträge bleiben unverändert. Ist Vibrant+ beendet oder antwortest du nicht rechtzeitig, fragt Claude Code wie gewohnt im Terminal.")
        }
        Section {
            ForEach(AIProvider.allCases, id: \.self) { provider in
                let installed = Self.installed(provider)
                let hasData = usage.present.contains(provider)
                LabeledContent(provider.title) {
                    Label(installed || hasData ? (hasData ? "Erkannt" : "Installiert") : "Nicht gefunden",
                          systemImage: hasData ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(hasData ? Palette.accentText : .secondary)
                }
                .help(provider.statusText(installed: installed, hasData: hasData))
            }
        } header: {
            Text("KI-Werkzeuge")
        } footer: {
            Text("Codex und OpenCode werden nur aus ihren eigenen Dateien auf diesem Mac gelesen (Verbrauch, Modell, letzte Sitzung); es wird nichts eingetragen oder installiert. Eine Live-Anzeige laufender Sitzungen gibt es nur für Claude Code. Codex kann auf Wunsch über `notify` in ~/.codex/config.toml ein Programm aufrufen, OpenCode über ein Plugin (session.idle): beides richtest du selbst ein.")
        }
        .onAppear { usage.refresh() }
        Section("Ton") {
            Toggle("Ton, wenn Claude fertig ist oder fragt", isOn: $prefs.agentSound)
            Picker("Klang", selection: $prefs.agentSoundName) {
                ForEach(sounds, id: \.self) { Text($0) }
            }
            .onChange(of: prefs.agentSoundName) { NSSound(named: prefs.agentSoundName)?.play() }
        }
        AgentUsageExtrasSettings()
    }
}

extension AgentSettings {
    /// The tool's binary in the usual places (an app starts with a short PATH).
    static func installed(_ provider: AIProvider) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let name = provider.binaryName
        let extra = [".opencode/bin", ".bun/bin", ".npm-global/bin", ".claude/local"].map { home.appendingPathComponent($0 + "/" + name).path }
        let apps = provider == .opencode ? ["/Applications/OpenCode.app", home.path + "/Applications/OpenCode.app"] : []
        return (DownloadPlan.toolCandidates(name, home: home) + extra)
            .contains { FileManager.default.isExecutableFile(atPath: $0) }
            || apps.contains { FileManager.default.fileExists(atPath: $0) }
    }
}

struct AssistantSettings: View {
    @State private var prefs = Prefs.shared
    @State private var question = "Was kannst du für mich tun?"

    var body: some View {
        Section {
            switch Assistant.state {
            case .available:
                Label("Apple Intelligence ist bereit", systemImage: "checkmark.circle.fill").foregroundStyle(Palette.accentText)
            case .unavailable(let why):
                Label(why, systemImage: "exclamationmark.triangle")
                Button("Systemeinstellungen öffnen") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!)
                }
            }
        } header: {
            Text("Sprachmodell")
        } footer: {
            Text("Vibrant+ nutzt das Sprachmodell von Apple Intelligence direkt auf deinem Mac: ohne Konto, ohne Kosten, ohne Internet. Es kann Aufgaben und Erinnerungen anlegen, Timer und Fokus starten, Apps öffnen und deine Termine von heute nennen.")
        }
        Section("Verwenden") {
            LabeledContent("Fragen per Stimme", value: "Mikrofon auf der Seite «Fragen» oder ⌃⇧ halten")
            LabeledContent("Fragen per Text", value: "Sprechblase in der Insel")
            Toggle("Antworten auf gesprochene Fragen vorlesen", isOn: $prefs.assistantSpeaks)
            Toggle("Gesprächsmodus: nach der Antwort wieder zuhören", isOn: $prefs.conversationMode)
            Toggle("Diktate mit dem Modell bereinigen", isOn: $prefs.assistantCleansDictation)
            Text("Sprachbefehle (⌃⌘), die Vibrant+ nicht kennt, gehen ebenfalls an den Assistenten.").foregroundStyle(.secondary)
        }
        Section {
            Picker("Stimme", selection: Binding(get: { prefs.speechVoiceID ?? "" }, set: { prefs.speechVoiceID = $0.isEmpty ? nil : $0 })) {
                Text("Automatisch (beste deutsche Stimme)").tag("")
                Text("Systemstimme (z. B. Siri Stimme 1)").tag(Assistant.systemVoiceTag)
                ForEach(Assistant.choosableVoices, id: \.identifier) { v in
                    Text("\(v.name) · \(v.language) · \(quality(v))").tag(v.identifier)
                }
            }
            Slider(value: $prefs.speechRate, in: 0.35...0.6) { Text("Tempo") } minimumValueLabel: { Text("langsam") } maximumValueLabel: { Text("schnell") }
            Button("Probehören") { Assistant.shared.say("Grüezi! So klinge ich, wenn ich dir antworte.") }
        } header: {
            Text("Stimme")
        } footer: {
            Text("Apples eigene Stimmen, gesprochen auf dem Mac. «Systemstimme» nimmt die Stimme aus Systemeinstellungen › Bedienungshilfen › Gesprochene Inhalte (dort Siri Stimme 1 wählen, erweitert laden). Bessere Stimmen (Erweitert, Premium, auch Schweizerdeutsch-nahe wie de-CH) lädst du unter Systemeinstellungen › Bedienungshilfen › Gesprochene Inhalte › Systemstimme › Stimmen verwalten; danach erscheinen sie hier.")
        }
        Section("Ausprobieren") {
            HStack {
                TextField("Frage", text: $question)
                Button("Fragen") {
                    Assistant.shared.ask(question, speak: false)
                    withAnimation(Motion.respecting(Motion.island)) { IslandController.shared.open(sticky: true) }
                }
                .disabled(!Assistant.isAvailable || !prefs.isOn(.island))
            }
        }
    }
}

struct ScreenshotSettings: View {
    private var hotkeys = HotKeys.shared
    @State private var prefs = Prefs.shared
    @State private var allowed = ScreenCapture.allowed
    @State private var resetDone = false

    var body: some View {
        Section {
            ForEach(CaptureMode.allCases, id: \.self) { mode in
                LabeledContent {
                    HStack {
                        Text(hotkeys.shortcuts[mode.hotKey]?.display ?? "–").monospaced().foregroundStyle(.secondary)
                        Button("Aufnehmen") { Task { await ScreenCapture.shared.capture(mode) } }
                    }
                } label: {
                    Label(mode.title, systemImage: mode.symbol)
                }
            }
            LabeledContent("Bildschirmaufnahme") {
                HStack {
                    Image(systemName: allowed ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(allowed ? Palette.accentText : .secondary)
                        .accessibilityLabel(allowed ? "Erlaubt" : "Nicht erlaubt")
                    if !allowed {
                        Button("Erlauben…") { ScreenCapture.requestAccess(); Permission.screenRecording.openSettings() }
                    }
                }
            }
            if !allowed {
                LabeledContent {
                    HStack {
                        Button("Erlaubnis neu einrichten") { Task { resetDone = await ScreenCapture.resetAccess() } }
                        Button("Vibrant+ neu starten") { ScreenCapture.relaunch() }
                    }
                } label: {
                    Text("Schalter ist an, und es geht trotzdem nicht?")
                    Text(resetDone ? "Erledigt. Jetzt im Fenster von macOS erlauben, dann Vibrant+ neu starten." : "Löscht den alten Eintrag von Vibrant+ in macOS und fragt neu. Danach erlauben und Vibrant+ neu starten.")
                }
            }
        } header: {
            Text("Aufnehmen")
        } footer: {
            Text("«Fenster»: das gewünschte Fenster anklicken. «Ausschnitt»: einen Rahmen aufziehen, die Leertaste wechselt zum Fenster. Esc bricht ab. Das Bild landet im Download-Ordner (\(ScreenCapture.folder.lastPathComponent)), in der Zwischenablage und in der Insel. Die Tasten änderst du unter Kurzbefehle; in der Kurzbefehle-App heisst die Aktion «Bildschirmfoto aufnehmen». Nach dem Erlauben Vibrant+ einmal neu starten. Ist Vibrant+ in der Liste schon eingeschaltet und es klappt trotzdem nicht, dort mit «–» entfernen und neu erlauben.")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in allowed = ScreenCapture.allowed }
        Section("Bild bearbeiten") {
            Button("Bildeditor öffnen…") { Windows.show(.imageEditor) }
            Text("Zuschneiden, Bereiche vollständig schwärzen, Wasserzeichen und Rand. Das Original bleibt erhalten; die bearbeitete Fassung wird als neue PNG-Datei exportiert.").foregroundStyle(.secondary)
        }
        Section("Scrollendes Fenster") {
            Button("Aktives Fenster scrollend aufnehmen") { Task { await ScrollingCapture.shared.capture() } }
                .disabled(ScreenCapture.shared.running || ScrollingCapture.shared.running)
            if ScrollingCapture.shared.running { ProgressView("Scrollt und fügt zusammen…") }
            if let message = ScrollingCapture.shared.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            Text("Nimmt das vordere Standardfenster mehrfach auf, blättert dazwischen per Bild-ab und setzt die Streifen überlappend zusammen. Höchstens acht Schritte. Braucht Bildschirmaufnahme und Bedienungshilfen.").font(.caption).foregroundStyle(.secondary)
        }
        TrackRecorderSettings(enabled: true)
        Section("Letzte Aufnahme") {
            if let last = ScreenRecorder.shared.lastURL {
                Text(last.lastPathComponent).foregroundStyle(.secondary)
                Button("Als GIF sichern") { Task { await ScreenRecorder.shared.exportLastGIF() } }
                    .disabled(ScreenRecorder.shared.exportingGIF)
                Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([last]) }
            } else {
                Text("Noch keine Bildschirmaufnahme in dieser Sitzung.").foregroundStyle(.secondary)
            }
            Text("Das GIF bleibt lokal, höchstens 12 Sekunden, 10 Bilder/s und 480 px auf der langen Seite. Kein Upload, kein Teilen-Link.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Aufnahme-Ausschnitt") {
            Toggle("Auf den Bereich um den Zeiger zoomen", isOn: $prefs.recordZoomCursor)
            Text("Nimmt die Hälfte der Bildschirmfläche um den Mauszeiger auf. Der Zoom gilt für die nächste Aufnahme, nicht für eine laufende.").font(.caption).foregroundStyle(.secondary)
        }
        Section {
            Text("Sobald du ein Bildschirmfoto machst (⇧⌘3, ⇧⌘4, ⇧⌘5), erscheint es 10 Sekunden in der Insel: kopieren, in der Vorschau beschriften, teilen, im Finder zeigen oder in den Papierkorb legen.")
            Text("Vibrant+ findet die Bilder über Spotlight, egal wo macOS sie ablegt. Nichts wird verändert, solange du keine Aktion wählst. «Löschen» legt nur in den Papierkorb.")
                .foregroundStyle(.secondary)
        } header: {
            Text("So funktioniert es")
        }
    }
}

struct SnippetSettings: View {
    @State private var service = SnippetService.shared
    @State private var trigger = ""
    @State private var text = ""
    @State private var error: String?

    var body: some View {
        if !Permission.accessibilityTrusted {
            Section {
                Label("Textbausteine brauchen die Bedienungshilfen-Berechtigung.", systemImage: "hand.raised")
                Button("Erlauben…") { Permission.requestAccessibility() }
            }
        }
        Section {
            ForEach(service.snippets) { s in
                HStack(alignment: .top) {
                    Text(s.trigger).monospaced().frame(width: 110, alignment: .leading)
                    Text(s.text).lineLimit(3).foregroundStyle(.secondary)
                    Spacer()
                    Button("Entfernen", systemImage: "minus.circle") { service.remove(s) }.labelStyle(.iconOnly).buttonStyle(.borderless)
                }
            }
            if service.snippets.isEmpty { Text("Noch keine Textbausteine.").foregroundStyle(.secondary) }
        } header: {
            Text("Deine Textbausteine")
        }
        Section {
            TextField("Kürzel, z. B. ;adr", text: $trigger)
            TextField("Text", text: $text, axis: .vertical).lineLimit(2...6)
            HStack {
                Button("Hinzufügen") {
                    error = service.add(trigger: trigger, text: text)
                    if error == nil { trigger = ""; text = "" }
                }
                .buttonStyle(.borderedProminent)
                .disabled(trigger.isEmpty || text.isEmpty)
                if let error { Text(error).foregroundStyle(Palette.danger).font(.caption) }
            }
        } header: {
            Text("Neu")
        } footer: {
            Text("Tippe das Kürzel in einer beliebigen App, es wird sofort durch den Text ersetzt. Platzhalter: {datum}, {zeit}, {wochentag}. Ein Kürzel darf nicht der Anfang eines anderen sein. In Passwortfeldern sieht Vibrant+ keine Tasten, und die getippten Zeichen werden nirgends gespeichert.")
        }
    }
}

private func quality(_ v: AVSpeechSynthesisVoice) -> String {
    switch v.quality {
    case .premium: "Premium"
    case .enhanced: "Erweitert"
    default: "Standard"
    }
}

struct MeetingSettings: View {
    @State private var prefs = Prefs.shared

    var body: some View {
        Section {
            Toggle("Besprechung zusätzlich als Notiz in Apple Notizen ablegen", isOn: $prefs.meetingToNotes)
        } header: {
            Text("Besprechung")
        } footer: {
            Text("Dein Mikrofon («Ich») und der Ton des Mac («Andere», braucht Bildschirmaufnahme) werden auf dem Mac in Text umgewandelt und als Datei in Dokumente › Vibrant+ Besprechungen gesichert. Sag allen Beteiligten, dass du mitschreibst.")
        }
    }
}

struct NotionSettings: View {
    @State private var notion = NotionService.shared
    @State private var secret = ""

    var body: some View {
        if !notion.connected {
            Section {
                Text("1. Öffne die Notion-Integrationen und lege eine neue «interne» Integration an, z. B. «Vibrant+». Rechte: Inhalte lesen, aktualisieren, einfügen.")
                Button("Notion-Integrationen öffnen") { NSWorkspace.shared.open(URL(string: "https://www.notion.so/profile/integrations")!) }
                Text("2. Kopiere das «Internal Integration Secret» und füge es hier ein.")
                SecureField("Secret (ntn_…)", text: $secret)
                Text("3. Teile in Notion deine Aufgaben- und Termin-Datenbank mit der Integration: ••• › Verbindungen › Vibrant+.")
                HStack {
                    Button("Verbinden") { Task { await notion.connect(secret: secret); secret = "" } }
                        .buttonStyle(.borderedProminent)
                        .disabled(secret.trimmingCharacters(in: .whitespaces).isEmpty || notion.busy)
                    if notion.busy { ProgressView().controlSize(.small) }
                }
            } header: {
                Text("Mit Notion verbinden")
            } footer: {
                Text("Der Schlüssel wird nur im macOS-Schlüsselbund gespeichert. Vibrant+ spricht direkt mit api.notion.com, ohne Zwischenserver, und nur mit Seiten, die du der Integration freigibst.")
            }
        } else {
            Section("Verbindung") {
                LabeledContent("Status", value: notion.workspaceUser.map { "Verbunden mit «\($0)»" } ?? "Verbunden")
                HStack {
                    Button("Datenbanken neu laden") { Task { await notion.loadDatabases() } }
                    Button("Trennen", role: .destructive) { notion.disconnect() }
                }
            }
            Section {
                picker("Aufgaben", kind: .tasks, current: notion.tasksTarget)
                picker("Termine", kind: .events, current: notion.eventsTarget)
            } header: {
                Text("Wohin speichern")
            } footer: {
                Text("Neue Aufgaben aus Vibrant+, vom Assistenten und von Siri landen in der Aufgaben-Datenbank; Erledigt, Erinnerung und Löschen werden übernommen. Termine gehen in die Termin-Datenbank; ohne Auswahl in den Apple-Kalender.")
            }
        }
        if notion.connected, notion.syncTasks {
            Section {
                LabeledContent("Zuletzt abgeglichen", value: notion.lastPull.map { $0.formatted(.dateTime.hour().minute().second()) } ?? "–")
                Button("Jetzt abgleichen") { Task { let n = await notion.pull(); notion.message = n == 0 ? "Alles aktuell." : "\(n) Änderungen aus Notion übernommen." } }
            } header: {
                Text("Aus Notion zurück")
            } footer: {
                Text("Alle 2 Minuten liest Vibrant+ die Aufgaben-Datenbank: abgehakte, umbenannte und neu angelegte Aufgaben aus Notion erscheinen hier. Bei Konflikten gilt Notion.")
            }
        }
        if let m = notion.message { Section { Text(m).foregroundStyle(.secondary) } }
        if let e = notion.lastError { Section { Label(e, systemImage: "exclamationmark.triangle").foregroundStyle(Palette.caution) } }
    }

    private func picker(_ title: String, kind: NotionService.Kind, current: NotionService.Target?) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Picker(title, selection: Binding(get: { current?.database.id ?? "" }, set: { id in
                Task { await notion.choose(notion.databases.first { $0.id == id }, for: kind) }
            })) {
                Text("Nicht speichern").tag("")
                if let c = current, !notion.databases.contains(c.database) { Text(c.database.title).tag(c.database.id) }
                ForEach(notion.databases) { db in Text(db.title).tag(db.id) }
            }
            if let m = current?.mapping {
                Text(describe(m)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .task { if notion.databases.isEmpty { await notion.loadDatabases() } }
    }

    private func describe(_ m: NotionKit.Mapping) -> String {
        var parts = ["Titel → «\(m.title)»"]
        if let d = m.date { parts.append("Datum → «\(d)»") }
        switch m.done {
        case .checkbox(let n): parts.append("Erledigt → «\(n)»")
        case .status(let n, let d, _): parts.append("Erledigt → «\(n)» = \(d)")
        case nil: break
        }
        return parts.joined(separator: " · ")
    }
}

struct TodaySettings: View {
    @State private var store = TodayStore.shared
    @State private var prefs = Prefs.shared

    var body: some View {
        Section("Fokus") {
            Stepper("Fokusdauer: \(store.data.focusMinutes) Minuten",
                    value: Binding(get: { store.data.focusMinutes }, set: { store.setFocusMinutes($0) }), in: 5...180, step: 5)
        }
        Section {
            Toggle("«Nicht stören» einschalten", isOn: $prefs.focusRules.doNotDisturb)
            Toggle("Dunkelmodus einschalten", isOn: $prefs.focusRules.darkMode)
            Toggle("Desktop-Symbole ausblenden", isOn: $prefs.focusRules.hideDesktopIcons)
            Toggle("Mac wach halten", isOn: $prefs.focusRules.keepAwake)
        } header: {
            Text("Während des Fokus")
        } footer: {
            Text("Beim Start des Fokus schaltet Vibrant+ das Gewählte um und stellt es danach wieder zurück. Schon erfüllte Regeln werden nicht angefasst und nicht rückgängig gemacht. «Nicht stören» braucht den Kurzbefehl «Vibrant DND» (Aktion «Fokus festlegen»), der Dunkelmodus die Automation für System Events.")
        }
        Section("Karten") {
            ForEach(TodayData.Card.allCases) { c in
                Toggle(c.title, isOn: Binding(get: { !store.data.hiddenCards.contains(c) }, set: { on in
                    var hidden = store.data.hiddenCards
                    if on { hidden.remove(c) } else { hidden.insert(c) }
                    store.setCards(store.data.cards, hidden: hidden)
                }))
            }
        }
        Section {
            if CalendarService.shared.granted {
                Label("Kalenderzugriff erlaubt", systemImage: "checkmark.circle.fill")
            } else {
                Button("Kalender erlauben") { CalendarService.shared.requestAccess() }
            }
        } header: {
            Text("Termine")
        } footer: {
            Text("Kalender und Erinnerungen liest Vibrant+ über Apples EventKit. Inhalte der Nachrichten-App sind für Apps nicht zugänglich; Vibrant+ kann sie deshalb nicht anzeigen.")
        }
    }
}

struct StowSettings: View {
    @State private var prefs = Prefs.shared

    var body: some View {
        Section("Umwandeln") {
            LabeledContent("Bilder", value: StowEngine.ImageFormat.writable.map(\.rawValue).joined(separator: ", ") + ", PDF")
            LabeledContent("Video und Audio", value: "MP4, MOV, M4A")
            Text("Ziehe Dateien auf den Notch und wähle «Umwandeln». Mit ⌥ erscheinen Werkzeuge. Die Kopie liegt neben dem Original; nichts wird überschrieben.")
                .foregroundStyle(.secondary)
        }
    }
}

struct RowlineSettings: View {
    @State private var prefs = Prefs.shared
    private var wm = WindowManager.shared
    @State private var name = ""
    @State private var newExclusion = ""

    var body: some View {
        if !Permission.accessibilityTrusted {
            Section {
                Label("Rowline braucht die Bedienungshilfen-Berechtigung.", systemImage: "hand.raised")
                Button("Erlauben…") { Permission.requestAccessibility() }
            }
        }
        Section("Reihe") {
            Slider(value: $prefs.rowGap, in: 0...24, step: 2) { Text("Abstand: \(Int(prefs.rowGap)) pt") }
            Text("⌃⌥⌘F ordnet die Fenster in eine Reihe. ⌃⌥⌘← / → springt zum Nachbarn und scrollt die Reihe, ⌃⌥⌘W wechselt die Breite (½, ⅔, ganz, ⅓).")
                .foregroundStyle(.secondary)
        }
        Section {
            ForEach(prefs.rowExcluded, id: \.self) { id in
                HStack {
                    Text(id)
                    Spacer()
                    Button("Entfernen", systemImage: "minus.circle") { prefs.rowExcluded.removeAll { $0 == id } }
                        .labelStyle(.iconOnly).buttonStyle(.borderless)
                }
            }
            HStack {
                TextField("Bundle-ID, z. B. com.apple.Music", text: $newExclusion)
                Button("Hinzufügen") {
                    let t = newExclusion.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty && !prefs.rowExcluded.contains(t) { prefs.rowExcluded.append(t) }
                    newExclusion = ""
                }
            }
        } header: {
            Text("Diese Apps kommen nie in die Reihe")
        }
        Section("Gesicherte Anordnungen") {
            HStack {
                TextField("Name, z. B. Studium", text: $name)
                Button("Aktuelle Fenster sichern") { wm.saveLayout(named: name); name = "" }
            }
            ForEach(wm.layouts) { l in
                HStack {
                    Text(l.name)
                    Text("\(l.entries.count) Fenster").foregroundStyle(.secondary)
                    Spacer()
                    Button("Wiederherstellen") { wm.restore(l) }
                    Button("Löschen", systemImage: "trash") { wm.deleteLayout(l) }.labelStyle(.iconOnly).buttonStyle(.borderless)
                }
            }
            if let m = wm.lastMessage { Text(m).foregroundStyle(.secondary) }
        }
    }
}

struct DialSettings: View {
    @State private var prefs = Prefs.shared
    @State private var audio = AudioDevices.shared

    var body: some View {
        Section {
            Picker("Bildschirmrand", selection: $prefs.dialLeftEdge) {
                Text("Links").tag(true)
                Text("Rechts").tag(false)
            }
            .pickerStyle(.segmented)
        } footer: {
            Text("Führe die Maus an den Rand, auf Höhe der Lasche. Lautstärke und Ausgang pro App brauchen die Erlaubnis «Systemaudio-Aufnahme»; es wird nichts aufgenommen. Bildschirm- und Tastaturhelligkeit sowie der Trackpad-Rand fehlen bewusst: macOS bietet dafür keine öffentliche Schnittstelle.")
        }
        Section("Favoriten und Ausgang") {
            if prefs.mixerMemory.favorites.isEmpty {
                Text("Im Rand-Regler mit dem Stern merken.").foregroundStyle(.secondary)
            }
            ForEach(prefs.mixerMemory.favorites, id: \.self) { bid in
                HStack {
                    Text(NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)?.deletingPathExtension().lastPathComponent ?? bid)
                    Picker("Ausgang", selection: Binding(
                        get: { prefs.mixerMemory.outputs[bid] ?? "" },
                        set: { uid in
                            var memory = prefs.mixerMemory
                            memory.outputs[bid] = MixerPlan.storedOutput(uid)
                            prefs.mixerMemory = memory
                        }
                    )) {
                        Text("Systemstandard").tag("")
                        ForEach(audio.devices.filter { $0.output && $0.uid != nil }) { device in
                            Text(device.name).tag(device.uid ?? "")
                        }
                    }
                    .labelsHidden()
                    Button("Entfernen") {
                        var memory = prefs.mixerMemory
                        memory.favorites.removeAll { $0 == bid }
                        prefs.mixerMemory = memory
                    }
                }
            }
        }
        .onAppear { audio.refresh() }
    }
}

struct VoiceSettings: View {
    var body: some View {
        Section {
            LabeledContent("Diktieren", value: "⌃⌥ halten")
            LabeledContent("Befehl", value: "⌃⌘ halten")
            Text("Befehle: «Öffne Safari», «Suche auf YouTube nach …», «Suche nach …», «Füge zur Liste hinzu: …», «Fokus starten», «Dunkelmodus an/aus».")
                .foregroundStyle(.secondary)
        } header: {
            Text("So geht’s")
        } footer: {
            Text("Nutzt die Spracherkennung von macOS, wenn möglich direkt auf dem Mac. Der Ton wird nie gespeichert. Füllwörter wie «ähm» werden entfernt. Diktierter Text wird über die Zwischenablage eingefügt; deren Inhalt wird danach wiederhergestellt.")
        }
        Section("Berechtigungen") {
            PermissionRow(permission: .microphone)
            PermissionRow(permission: .speech)
            PermissionRow(permission: .accessibility)
        }
    }
}

struct KeysSettings: View {
    @State private var prefs = Prefs.shared

    var body: some View {
        Section("Berechtigung") { PermissionRow(permission: .accessibility) }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in KeyMonitor.shared.update() }
        Section("Tastengeräusche") {
            Toggle("Geräusch bei jedem Tastendruck", isOn: $prefs.keySounds)
            Picker("Klang", selection: $prefs.keySoundProfile) {
                ForEach(KeySoundProfile.allCases) { Text($0.title).tag($0) }
            }
            Slider(value: $prefs.keySoundVolume, in: 0...1) { Text("Lautstärke") }
        }
        Section {
            Toggle("Gedrückte Tasten anzeigen", isOn: $prefs.showKeys)
            Toggle("Auch normale Tasten (nicht nur Kurzbefehle)", isOn: $prefs.showAllKeys)
                .disabled(!prefs.showKeys)
        } header: {
            Text("Tasten anzeigen")
        } footer: {
            Text("Für Präsentationen und Aufnahmen. Tasten werden nie gespeichert. Beides braucht die Bedienungshilfen-Berechtigung.")
        }
    }
}

struct AppearanceSettings: View {
    @State private var prefs = Prefs.shared
    @State private var theme = ThemeStore.shared

    var body: some View {
        Section {
            Picker("Thema", selection: Binding(get: { prefs.theme }, set: { t in
                prefs.theme = t
                ThemeController.shared.apply(t, switchMac: prefs.themeSwitchesMac)
            })) {
                ForEach(AppTheme.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Auch macOS umstellen (Dunkelmodus, Schreibtischbild)", isOn: $prefs.themeSwitchesMac)
            wallpaper("Bild für «Nacht»", \.nightWallpaper)
            wallpaper("Bild für «Papier»", \.paperWallpaper)
            Button("Gewähltes Bild jetzt auf alle Schreibtische legen") {
                let path = prefs.theme == .night ? prefs.nightWallpaper : prefs.theme == .paper ? prefs.paperWallpaper : nil
                ThemeController.shared.applyWallpaper(path)
            }
            .disabled(prefs.theme == .system)
        } header: {
            Text("Thema")
        } footer: {
            Text("Gilt für die Fenster von Vibrant+. Die Insel hat ihren eigenen Stil (unten); geschlossen bleibt sie schwarz wie der Notch. «Jetzt legen» setzt das Bild des aktuellen Themas über NSWorkspace auf jeden Bildschirm.")
        }
        Section {
            Picker("Insel-Stil", selection: Binding(get: { IslandTheme.shared.style }, set: { IslandTheme.shared.style = $0 })) {
                ForEach(IslandStyle.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Insel, Heute und Rand-Regler")
        } footer: {
            Text("«Notch-Schwarz» verschmilzt mit dem Notch. «Liquid Glass» zeigt die Insel im durchscheinenden Glas von macOS 26. Geschlossen bleibt die Insel immer schwarz wie der Notch. Beide letzten Stile folgen Hell/Dunkel des Mac; bei «Transparenz reduzieren» (Bedienungshilfen) wird das Glas zu einer festen Fläche.")
        }
        Section("Akzentfarbe") {
            Picker("Akzent", selection: $theme.themeID) {
                ForEach(Theme.all) { t in Text(t.name).tag(t.id) }
                Text("Eigene Farbe").tag("custom")
            }
            if theme.themeID == "custom" {
                ColorPicker("Eigene Farbe", selection: Binding(get: { Color(hex: theme.customHex) }, set: { theme.customHex = $0.hex }),
                            supportsOpacity: false)
            }
            Text("«System» folgt der Akzentfarbe des Mac. Mit «Mehrfarbig» erscheint der Vibrant+-Akzent Puls.")
                .foregroundStyle(.secondary)
        }
    }

    private func wallpaper(_ title: String, _ key: ReferenceWritableKeyPath<Prefs, String?>) -> some View {
        LabeledContent(title) {
            HStack {
                Text(prefs[keyPath: key].map { ($0 as NSString).lastPathComponent } ?? "Keins").foregroundStyle(.secondary)
                Button("Wählen…") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.image]
                    if panel.runModal() == .OK { prefs[keyPath: key] = panel.url?.path }
                }
                if prefs[keyPath: key] != nil { Button("Entfernen") { prefs[keyPath: key] = nil } }
            }
        }
    }
}

struct ShortcutSettings: View {
    private var hotkeys = HotKeys.shared
    @State private var recording: HotKeyAction?
    @State private var monitor: Any?

    var body: some View {
        Section {
            ForEach(HotKeyAction.allCases) { a in
                LabeledContent(a.title) {
                    Button(recording == a ? "Tasten drücken…" : (hotkeys.shortcuts[a]?.display ?? "–")) { record(a) }
                        .monospaced()
                        .foregroundStyle(recording == a ? Palette.accentText : .primary)
                }
                .opacity(a.isEnabled(in: Prefs.shared) ? 1 : 0.5)
            }
        } footer: {
            if hotkeys.unavailable.isEmpty {
                Text("Klicke auf einen Kurzbefehl und drücke die neuen Tasten, mindestens mit ⌃, ⌥ oder ⌘. Esc bricht ab.")
            } else {
                Text("Von einer anderen App belegt und darum ohne Wirkung: \(hotkeys.unavailable.map(\.title).sorted().joined(separator: ", ")). Wähle dort eine andere Kombination.")
            }
        }
        Section {
            Button("Standard wiederherstellen") { hotkeys.reset() }
        }
        .onDisappear { stopRecording() }
        // Clicking into another app ends the recording, otherwise every key of this window
        // stays swallowed and all global shortcuts stay paused.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in stopRecording() }
    }

    private func record(_ a: HotKeyAction) {
        stopRecording()
        recording = a
        hotkeys.paused = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            if e.keyCode == 53 { stopRecording(); return nil }
            if let s = Shortcut(event: e) { hotkeys.change(a, to: s); stopRecording() }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = nil
        hotkeys.paused = false
    }
}

struct PermissionSettings: View {
    var body: some View {
        Section {
            ForEach([Permission.accessibility, .calendar, .reminders, .microphone, .speech, .screenRecording, .automation, .audioCapture]) { p in
                PermissionRow(permission: p)
            }
        } footer: {
            Text("Vibrant+ fragt jede Berechtigung erst, wenn ein Modul sie braucht. Du kannst sie jederzeit in den Systemeinstellungen zurücknehmen.")
        }
    }
}

struct PermissionRow: View {
    var permission: Permission
    @State private var tick = 0

    var body: some View {
        LabeledContent {
            HStack {
                if let granted = status {
                    Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(granted ? Palette.accentText : .secondary)
                        .accessibilityLabel(granted ? "Erlaubt" : "Nicht erlaubt")
                }
                Button("Öffnen…") { request() }
            }
        } label: {
            Text(permission.title)
            Text(permission.reason)
        }
        .id(permission.rawValue + "-" + String(tick))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in tick += 1 }
    }

    private var status: Bool? {
        switch permission {
        case .accessibility: Permission.accessibilityTrusted
        case .calendar: EKEventStore.authorizationStatus(for: .event) == .fullAccess
        case .reminders: EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
        case .microphone: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        case .speech: SFSpeechRecognizer.authorizationStatus() == .authorized
        case .screenRecording: ScreenCapture.allowed
        default: nil
        }
    }

    private func request() {
        switch permission {
        case .accessibility: Permission.requestAccessibility(); permission.openSettings()
        case .calendar: CalendarService.shared.requestAccess()
        case .reminders: RemindersService.shared.requestAccess()
        case .microphone: AudioCallbacks.requestMicrophone { _ in }
        case .speech: AudioCallbacks.requestSpeech { _ in }
        case .screenRecording: ScreenCapture.requestAccess(); permission.openSettings()
        default: permission.openSettings()
        }
    }
}

struct AboutSettings: View {
    @State private var prefs = Prefs.shared
    private var updater = AppUpdater.shared

    var body: some View {
        Section {
            HStack(spacing: Space.lg) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Wordmark.view(height: 24)
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"))")
                        .foregroundStyle(.secondary)
                    Text("Ein Produkt von ARJO LAB").foregroundStyle(.secondary)
                }
            }
        }
        Section("Updates") {
            Toggle("Täglich nach Updates suchen", isOn: $prefs.appAutoUpdate)
            Button("Auf Update prüfen") { updater.check() }
                .disabled({
                    switch updater.status {
                    case .checking, .downloading: true
                    default: false
                    }
                }())
            switch updater.status {
            case .idle: EmptyView()
            case .checking: Text("Suche…").foregroundStyle(.secondary)
            case .upToDate: Text("Du hast die neueste Version.")
            case .available(let version):
                Text("Vibrant+ \(version) ist bereit.")
                Button("Jetzt laden und ersetzen") { updater.install() }
            case .downloading: Text("Update wird geladen…")
            case .failed(let message): Text(message).foregroundStyle(.red)
            }
            Text("Zuerst GitHub Releases (ArijanVr/VibrantPL). Optional lokaler Ordner über die Umgebungsvariable PROJEKTELAB_RELEASES. Kein Sparkle. Automatisch nur prüfen, nie still installieren.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Was Vibrant+ bewusst nicht tut") {
            Text("Keine Helligkeitsregler, kein Trackpad-Rand und kein Bluetooth-Schalter: dafür gibt es in macOS keine öffentliche Schnittstelle. Keine Konten, keine Analyse.")
                .foregroundStyle(.secondary)
        }
    }
}

/// Save and open panels for the backup.
@MainActor
@Observable
final class BackupUI {
    static var message: String?

    static func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Vibrant+ Sicherung \(Date.now.formatted(.iso8601.year().month().day())).vibrantbackup"
        panel.allowedContentTypes = [.zip]
        panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        TodayStore.shared.saveNow()
        do {
            try Backup.export(to: url, dataDirectory: Paths.dataDirectory, defaults: .standard, domain: Bundle.main.bundleIdentifier ?? "ch.arjo.vibrantplus")
            message = "Gesichert: \(url.lastPathComponent)"
        } catch { message = error.localizedDescription }
    }

    static func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let alert = NSAlert()
        alert.messageText = "Sicherung importieren?"
        alert.informativeText = "Die aktuellen Daten und Einstellungen werden ersetzt. Der alte Stand bleibt in «VibrantPlus-vor-Import» erhalten. Vibrant+ startet danach neu."
        alert.addButton(withTitle: "Importieren")
        alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            let n = try Backup.importBackup(from: url, dataDirectory: Paths.dataDirectory, defaults: .standard, domain: Bundle.main.bundleIdentifier ?? "ch.arjo.vibrantplus")
            message = "\(n) Teile wiederhergestellt. Neustart…"
            AppRelaunch.now()
        } catch { message = error.localizedDescription }
    }
}
