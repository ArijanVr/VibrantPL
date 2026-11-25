// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UniformTypeIdentifiers
import VibrantPlusKit

/// The tiles a person chose, in their order. Scrolls sideways when there are many.
struct TileStrip: View {
    var category: TileCategory = .start
    private var prefs = Prefs.shared
    /// Pages the strip for the arrows; the trackpad moves it freely.
    @State private var position = ScrollPosition(edge: .leading)
    @State private var offset: CGFloat = 0
    @State private var contentWidth: CGFloat = 1
    @State private var frameWidth: CGFloat = 1

    private struct ScrollFacts: Equatable {
        var offset: CGFloat
        var content: CGFloat
        var frame: CGFloat
    }

    /// More tiles than fit: the strip shows a line and two arrows instead of a scrollbar.
    private var more: Bool { contentWidth > frameWidth + 1 }

    var body: some View {
        let tiles = prefs.visibleTiles(in: category)
        VStack(alignment: .leading, spacing: Space.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Space.sm) {
                    ForEach(tiles) { tile in
                        view(for: tile).id(tile)
                            .environment(\.tileWide, prefs.wideTiles.contains(tile))
                            .arrangeable(tile, among: tiles)
                    }
                    if tiles.isEmpty {
                        IslandCard(width: Metrics.wideTileWidth) {
                            Text("Keine Kacheln eingeschaltet. Wähle sie in den Einstellungen unter Kacheln.")
                                .font(TypeStyle.islandBody).foregroundStyle(IslandColor.secondaryText)
                        }
                    }
                }
                // Measured while it lays out, so the arrows and the line are there on the first
                // frame instead of appearing a moment later.
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
                // Few tiles gather under the notch, on its axis, instead of leaving one half empty.
                .frame(minWidth: frameWidth, alignment: .center)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { frameWidth = $0 }
            .scrollPosition($position)
            .onScrollGeometryChange(for: ScrollFacts.self) { geo in
                ScrollFacts(offset: geo.contentOffset.x, content: geo.contentSize.width, frame: geo.containerSize.width)
            } action: { _, facts in
                offset = facts.offset
                let model = IslandModel.shared
                let leading = facts.offset <= 1
                let trailing = facts.offset + facts.frame >= facts.content - 1
                if model.atLeadingEdge != leading { model.atLeadingEdge = leading }
                if model.atTrailingEdge != trailing { model.atTrailingEdge = trailing }
                // The content size is authoritative once the strip scrolls.
                if facts.content > 1 { contentWidth = facts.content }
                if facts.frame > 1 { frameWidth = facts.frame }
            }
            // A soft edge says «there is more», a line says how much, two arrows get there with a mouse.
            // The edge is a mask, not a painted gradient: it works on glass too.
            .mask { edgeFade }
            .overlay(alignment: .leading) { arrow(-1) }
            .overlay(alignment: .trailing) { arrow(1) }
            if more {
                scrollLine
            }
        }
    }

    /// One step of the arrows: what is in view, less a piece that stays for orientation.
    private func page(_ direction: Int) {
        let step = max(Metrics.tileWidth, frameWidth - Metrics.tileWidth / 2)
        let target = min(max(0, contentWidth - frameWidth), max(0, offset + CGFloat(direction) * step))
        withAnimation(Motion.respecting(Motion.page)) { position.scrollTo(x: target) }
    }

    @ViewBuilder private func arrow(_ direction: Int) -> some View {
        if more && canScroll(direction) {
            IslandIconButton(symbol: direction < 0 ? "chevron.left" : "chevron.right",
                             label: direction < 0 ? "Weitere Kacheln links zeigen" : "Weitere Kacheln rechts zeigen",
                             size: 24) { page(direction) }
                // Solid: it floats over cut-off tiles.
                .background(Color(hex: Brand.black), in: Circle())
                .transition(.opacity)
        }
    }

    private func canScroll(_ direction: Int) -> Bool {
        direction < 0 ? offset > 1 : offset + frameWidth < contentWidth - 1
    }

    private var edgeFade: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [more && canScroll(-1) ? .clear : .black, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: Space.section)
            Color.black
            LinearGradient(colors: [.black, more && canScroll(1) ? .clear : .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: Space.section)
        }
    }

    /// How far the strip has scrolled, as a thin line: a scrollbar would be too loud in the island.
    private var scrollLine: some View {
        let visible = min(1, frameWidth / max(contentWidth, 1))
        let thumb = max(Space.xxl, frameWidth * visible)
        let travel = max(0, frameWidth - thumb)
        let progress = min(1, max(0, offset / max(1, contentWidth - frameWidth)))
        return Capsule()
            .fill(IslandColor.cardHover)
            .frame(height: 2)
            .overlay(alignment: .leading) {
                Capsule().fill(IslandColor.tertiaryText)
                    .frame(width: thumb, height: 2)
                    .padding(.leading, travel * progress)
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder private func view(for tile: TileKind) -> some View {
        switch tile {
        case .nowPlaying: NowPlayingTile()
        case .agent: AgentTile()
        case .nextEvent: NextEventTile()
        case .weather: WeatherTile()
        case .clock: ClockTile()
        case .system: SystemTile()
        case .todo: TodoTile()
        case .timer: TimerTile()
        case .shelf: ShelfTile()
        case .clipboard: ClipboardTile()
        case .recentApps: RecentAppsTile()
        case .controls: ControlsTile()
        case .shortcuts: ShortcutsTile()
        case .quickNote: QuickNoteTile()
        case .teleprompter: TeleprompterTile()
        case .commands: CommandsTile()
        case .browserTab: BrowserTabTile()
        case .message: MessageTile()
        case .converter: ConverterTile()
        case .colorPicker: ColorPickerTile()
        case .mirror: MirrorTile()
        case .usage: UsageTile()
        case .reminders: RemindersTile()
        case .quitApps: QuitAppsTile()
        case .meeting: MeetingTile()
        }
    }
}

// MARK: Music

struct NowPlayingTile: View {
    private var music = NowPlaying.shared

    var body: some View {
        // The tile takes the cover's color while it plays.
        IslandCard(width: Metrics.wideTileWidth, glow: music.hasTrack ? music.coverColor : nil) {
            if music.hasTrack {
                HStack(alignment: .top, spacing: Space.md) {
                    cover
                    VStack(alignment: .leading, spacing: 2) {
                        // The cover says «music»: no header, the room goes to title, artist and lyric.
                        Text(music.title).font(TypeStyle.islandTitle).lineLimit(1)
                        Text(music.artist.isEmpty ? (music.album.isEmpty ? (music.player?.title ?? "Musik") : music.album) : music.artist)
                            .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText).lineLimit(1)
                        if music.lyrics != nil {
                            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                                Text(music.currentLyric(at: ctx.date) ?? " ")
                                    .font(TypeStyle.islandCaption.weight(.medium)).foregroundStyle(IslandColor.accentText).lineLimit(1)
                                    .accessibilityLabel("Liedtext")
                            }
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: Space.sm) {
                            IslandIconButton(symbol: "backward.fill", label: "Zurück") { music.previous() }
                            IslandIconButton(symbol: music.isPlaying ? "pause.fill" : "play.fill",
                                             label: music.isPlaying ? "Pause" : "Wiedergabe", size: 32, prominent: true) { music.playPause() }
                            IslandIconButton(symbol: "forward.fill", label: "Weiter") { music.next() }
                        }
                        Spacer(minLength: 0)
                        progress
                        if !music.upcoming.isEmpty {
                            Text(music.upcoming.prefix(3).joined(separator: " · "))
                                .font(TypeStyle.islandMicro).foregroundStyle(IslandColor.tertiaryText).lineLimit(1)
                                .help(music.upcoming.joined(separator: "\n"))
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: Space.xs) {
                    CardHeader(title: "Musik", symbol: "music.note")
                    IslandEmpty(symbol: "music.note",
                                text: music.automationDenied ? "Erlaube Vibrant+ die Automation für Musik oder Spotify."
                                                             : "Nichts läuft gerade. Starte Musik oder Spotify.")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Musik")
    }

    private var cover: some View {
        Group {
            if let image = music.cover {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note").font(.system(size: 30)).foregroundStyle(IslandColor.tertiaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(IslandColor.cardHover)
            }
        }
        .frame(width: Metrics.tileHeight - Space.md * 2, height: Metrics.tileHeight - Space.md * 2)
        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .onTapGesture { music.openPlayer() }
        .accessibilityLabel("Cover, öffnet den Player")
    }

    private var progress: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let pos = music.currentPosition(at: ctx.date)
            // One line: elapsed, bar, remaining.
            HStack(spacing: Space.sm) {
                Text(Clock.format(pos))
                ProgressView(value: music.duration > 0 ? pos / music.duration : 0)
                    .progressViewStyle(.linear).tint(music.coverColor ?? IslandColor.accent)
                Text("-" + Clock.format(max(0, music.duration - pos)))
            }
            .font(TypeStyle.islandMicroNumber).foregroundStyle(IslandColor.tertiaryText)
        }
    }
}

// MARK: Agent

struct AgentTile: View {
    private var agent = AgentStore.shared

    var body: some View {
        IslandCard(width: Metrics.wideTileWidth) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack {
                    CardHeader(title: "Claude Code", symbol: "sparkles")
                    Spacer()
                    Button("Panel") { AppActions.openAgentPanel() }
                        .buttonStyle(.plain).font(TypeStyle.islandLabel).foregroundStyle(IslandColor.accentText)
                }
                if !agent.hooksInstalled {
                    Spacer()
                    Text("Noch nicht mit Claude Code verbunden.").font(TypeStyle.islandBody).foregroundStyle(IslandColor.secondaryText)
                    IslandPillButton(title: "Verbinden", kind: .primary) { agent.installHooks() }
                } else if let s = agent.headline {
                    Text(s.projectName).font(TypeStyle.islandTitle).lineLimit(1)
                    Text(s.current).font(TypeStyle.islandBody).foregroundStyle(IslandColor.secondaryText).lineLimit(2)
                    Spacer(minLength: 0)
                    ForEach(s.steps.suffix(agent.filesForClaude.isEmpty ? 2 : 1).reversed()) { step in
                        Label(step.label, systemImage: step.symbol)
                            .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.tertiaryText).lineLimit(1)
                    }
                    if !agent.filesForClaude.isEmpty {
                        Label("\(agent.filesForClaude.count) Datei(en) für die nächste Nachricht", systemImage: "paperclip")
                            .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                    }
                } else {
                    IslandEmpty(symbol: "sparkles", text: "Starte Claude Code in einem Terminal. Hier erscheint, was es tut.")
                }
            }
        }
    }
}

// MARK: Calendar

struct NextEventTile: View {
    private var calendar = CalendarService.shared

    var body: some View {
        IslandCard {
            VStack(alignment: .leading, spacing: Space.xs) {
                CardHeader(title: "Nächster Termin", symbol: "calendar")
                if !calendar.granted {
                    Spacer()
                    Text("Kalender erlauben, um Termine zu sehen.").font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                    IslandPillButton(title: "Erlauben", kind: .primary) { calendar.requestAccess() }
                } else if let e = calendar.next {
                    Text(e.title).font(TypeStyle.islandTitle).lineLimit(2)
                    TimelineView(.periodic(from: .now, by: 30)) { ctx in
                        Text(relative(e, ctx.date)).font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                    }
                    Spacer(minLength: 0)
                    if let m = e.meeting {
                        // The service name would not fit the tile: it is the tooltip.
                        IslandPillButton(title: "Beitreten", kind: .primary) { NSWorkspace.shared.open(m.url) }
                            .help("Beitreten · \(m.service.rawValue)")
                            .accessibilityLabel("Beitreten, \(m.service.rawValue)")
                    } else {
                        Text(e.start, format: .dateTime.hour().minute()).font(TypeStyle.islandCaption).foregroundStyle(IslandColor.tertiaryText)
                    }
                } else {
                    IslandEmpty(symbol: "calendar", text: "Heute nichts mehr geplant")
                }
            }
        }
    }

    private func relative(_ e: CalendarService.Event, _ now: Date) -> String {
        if e.start <= now { return "Läuft seit \(Int(now.timeIntervalSince(e.start) / 60)) Min." }
        let m = Int(e.start.timeIntervalSince(now) / 60)
        if m < 60 { return "In \(max(1, m)) Min." }
        return "Um " + e.start.formatted(.dateTime.hour().minute())
    }
}

// MARK: Weather

struct WeatherTile: View {
    private var weather = WeatherService.shared

    var body: some View {
        IslandCard {
            VStack(alignment: .leading, spacing: 2) {
                CardHeader(title: weather.current?.place ?? "Wetter", symbol: "location")
                if let w = weather.current {
                    let d = WeatherCode.describe(w.code, isDay: w.isDay)
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(Int(w.temperature.rounded()))°").font(TypeStyle.islandNumber)
                        Image(systemName: d.symbol).symbolRenderingMode(.multicolor).font(.system(size: 20))
                    }
                    Text(d.text)
                        .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText).lineLimit(1)
                    Spacer(minLength: 0)
                    if w.hours.count >= 3 {
                        // The next hours as a curve; high, low and the sun move to the line below it.
                        TemperatureCurve(hours: w.hours)
                        Text("H \(Int(w.high.rounded()))°  T \(Int(w.low.rounded()))°  ·  \(ageText(w.fetched))")
                            .font(TypeStyle.islandMicroNumber).foregroundStyle(IslandColor.tertiaryText).lineLimit(1)
                            .help("Gefühlt \(Int(w.feelsLike.rounded()))° · Sonne \(w.sunrise)–\(w.sunset) · \(w.fetched.formatted(date: .omitted, time: .shortened))")
                    } else {
                        // Two short lines instead of one that would be cut off.
                        Group {
                            Text("H \(Int(w.high.rounded()))°  T \(Int(w.low.rounded()))°  ·  \(ageText(w.fetched))")
                            Text("☀︎ \(w.sunrise)–\(w.sunset)")
                        }
                        .font(TypeStyle.islandMicroNumber).foregroundStyle(IslandColor.tertiaryText).lineLimit(1)
                    }
                } else {
                    Spacer()
                    Text(weather.error ?? "Stadt in den Einstellungen festlegen").font(TypeStyle.islandCaption)
                        .foregroundStyle(IslandColor.secondaryText)
                }
            }
        }
    }

    private func ageText(_ date: Date) -> String {
        let m = Int(max(0, Date.now.timeIntervalSince(date) / 60))
        if m < 1 { return "gerade" }
        if m == 1 { return "vor 1 Min." }
        return "vor \(m) Min."
    }
}

// MARK: Clock and month

struct ClockTile: View {
    var body: some View {
        IslandCard {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                HStack(alignment: .top, spacing: Space.sm) {
                    if Prefs.shared.clockAnalog { AnalogWatch(date: ctx.date).frame(width: 52, height: 52) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ctx.date, format: .dateTime.hour().minute()).font(TypeStyle.islandTimer)
                        MonthGrid(date: ctx.date)
                    }
                }
            }
        }
    }
}

struct AnalogWatch: View {
    var date: Date
    var body: some View {
        let cal = Calendar.current
        let s = Double(cal.component(.second, from: date))
        let m = Double(cal.component(.minute, from: date)) + s / 60
        let h = Double(cal.component(.hour, from: date) % 12) + m / 60
        let ink = IslandColor.primaryText
        let rim = IslandColor.separator
        Canvas { context, size in
            let r = min(size.width, size.height) / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            context.stroke(Path(ellipseIn: CGRect(x: c.x - r + 1, y: c.y - r + 1, width: (r - 1) * 2, height: (r - 1) * 2)), with: .color(rim), lineWidth: 1)
            func hand(_ length: CGFloat, _ angle: Double, _ width: CGFloat) {
                var path = Path()
                path.move(to: c)
                path.addLine(to: CGPoint(x: c.x + sin(angle) * length, y: c.y - cos(angle) * length))
                context.stroke(path, with: .color(ink), lineWidth: width)
            }
            hand(r * 0.5, h / 12 * 2 * .pi, 2)
            hand(r * 0.72, m / 60 * 2 * .pi, 1.5)
            hand(r * 0.82, s / 60 * 2 * .pi, 0.6)
        }
        .accessibilityHidden(true)
    }
}

struct MonthGrid: View {
    var date: Date

    var body: some View {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: date))!
        let days = cal.range(of: .day, in: .month, for: date)!.count
        let lead = (cal.component(.weekday, from: start) - cal.firstWeekday + 7) % 7
        let today = cal.component(.day, from: date)
        let cells = Array(repeating: 0, count: lead) + Array(1...days)
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(16), spacing: 2), count: 7), spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, d in
                Text(d == 0 ? "" : "\(d)")
                    .font(TypeStyle.islandMicroNumber.weight(d == today ? .bold : .regular))
                    .foregroundStyle(d == today ? IslandColor.onAccent : IslandColor.secondaryText)
                    .frame(width: 16, height: 12)
                    .background(d == today ? IslandColor.accentFill : .clear, in: Capsule())
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: System

struct SystemTile: View {
    private var stats = SystemStats.shared

    var body: some View {
        IslandCard {
            VStack(alignment: .leading, spacing: Space.sm) {
                CardHeader(title: "Mac", symbol: "gauge.with.dots.needle.50percent")
                meter("CPU", stats.cpu, "\(Int(stats.cpu * 100)) %")
                meter("RAM", stats.memoryTotal > 0 ? stats.memoryUsed / stats.memoryTotal : 0,
                      String(format: "%.1f/%.0f GB", stats.memoryUsed, stats.memoryTotal))
                HStack {
                    Label(String(format: "%.0f GB frei", stats.diskFree), systemImage: "internaldrive")
                    Spacer()
                    if let b = stats.battery {
                        Label("\(b) %", systemImage: stats.charging ? "battery.100percent.bolt" : "battery.75percent")
                    }
                }
                .font(TypeStyle.islandMicro).foregroundStyle(IslandColor.secondaryText)
            }
        }
    }

    private func meter(_ title: String, _ value: Double, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Text(title).font(TypeStyle.islandLabel)
                Spacer()
                Text(text).font(TypeStyle.islandMicroNumber)
            }
            .foregroundStyle(IslandColor.secondaryText)
            IslandBar(value: value)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: To-do

struct TodoTile: View {
    private var today = TodayStore.shared
    @State private var newTask = ""

    var body: some View {
        IslandCard(width: Metrics.wideTileWidth - 64) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack {
                    CardHeader(title: "Aufgaben", symbol: "checklist")
                    Spacer()
                    Text("\(today.openTasks.count)").font(TypeStyle.islandLabel).foregroundStyle(IslandColor.tertiaryText)
                }
                ForEach(today.openTasks.prefix(3)) { t in
                    Button { today.toggle(t) } label: {
                        Label(t.title, systemImage: "circle").lineLimit(1)
                    }
                    .buttonStyle(.plain).font(TypeStyle.islandBody)
                }
                Spacer(minLength: 0)
                TextField("Neue Aufgabe", text: $newTask)
                    .textFieldStyle(.plain).font(TypeStyle.islandBody)
                    .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
                    .background(IslandColor.field, in: RoundedRectangle(cornerRadius: Radius.chip))
                    .onSubmit { today.addTask(newTask); newTask = "" }
            }
        }
    }
}

// MARK: Timer

struct TimerTile: View {
    private var timer = QuickTimer.shared

    var body: some View {
        IslandCard {
            VStack(alignment: .leading, spacing: Space.sm) {
                CardHeader(title: "Timer", symbol: "timer")
                if timer.running {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text(Clock.format(timer.remaining(at: ctx.date))).font(TypeStyle.islandNumber)
                    }
                    Spacer(minLength: 0)
                    IslandPillButton(title: "Stoppen", kind: .danger) { timer.cancel() }
                } else {
                    Spacer(minLength: 0)
                    // Two by two: four pills in one row are wider than the tile.
                    Grid(horizontalSpacing: Space.xs, verticalSpacing: Space.xs) {
                        ForEach([[1, 5], [10, 25]], id: \.self) { row in
                            GridRow {
                                ForEach(row, id: \.self) { m in
                                    IslandPillButton(title: "\(m) Min.", expands: true) { timer.start(minutes: Double(m)) }
                                        .accessibilityLabel("Timer für \(m) Minuten starten")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: Shelf

struct ShelfTile: View {
    private var shelf = Shelf.shared
    @State private var targeted = false
    @State private var filter = ShelfFilter.all

    private var shown: [URL] { shelf.files.filter(filter.matches) }

    var body: some View {
        IslandCard(width: Metrics.wideTileWidth - 64) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack {
                    CardHeader(title: "Ablage", symbol: "tray")
                    Spacer()
                    Button("Am Zeiger") { ShelfPalette.shared.toggle() }
                        .buttonStyle(.plain).font(TypeStyle.islandLabel).foregroundStyle(IslandColor.accentText)
                    if !shelf.files.isEmpty {
                        Button("AirDrop") {
                            if !Shelf.airDrop(shelf.files) { IslandModel.shared.show(Toast(symbol: "exclamationmark.triangle", text: "AirDrop nicht verfügbar", warm: true)) }
                        }
                        .buttonStyle(.plain).font(TypeStyle.islandLabel).foregroundStyle(IslandColor.accentText)
                        Button("Leeren") { shelf.clear() }.buttonStyle(.plain)
                            .font(TypeStyle.islandLabel).foregroundStyle(IslandColor.accentText)
                    }
                }
                if shelf.files.count > 1 {
                    HStack(spacing: Space.xs) {
                        ForEach(ShelfFilter.allCases) { f in
                            IslandPillButton(title: f.title, kind: filter == f ? .primary : .secondary) { filter = f }
                        }
                    }
                }
                if shelf.files.isEmpty {
                    IslandEmpty(symbol: "tray.and.arrow.down", text: "Dateien hierher ziehen, später wieder herausziehen.")
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Space.sm) {
                            ForEach(shown, id: \.self) { url in
                                VStack(spacing: 2) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                        .resizable().frame(width: 40, height: 40)
                                    Text(url.lastPathComponent).font(TypeStyle.islandMicro).lineLimit(1).frame(width: 60)
                                }
                                .draggable(url)
                                .contextMenu {
                                    Button("Per AirDrop senden") { Shelf.airDrop([url]) }
                                    Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                                    Button("Öffnen") { NSWorkspace.shared.open(url) }
                                    Button("Aus der Ablage nehmen") { shelf.remove(url) }
                                }
                                .accessibilityLabel(url.lastPathComponent)
                            }
                        }
                    }
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(targeted ? IslandColor.accent : .clear, lineWidth: 2))
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            Task {
                var urls: [URL] = []
                for p in providers {
                    if let d = try? await p.loadItem(forTypeIdentifier: UTType.fileURL.identifier) as? Data,
                       let u = URL(dataRepresentation: d, relativeTo: nil) { urls.append(u) }
                }
                await MainActor.run { shelf.add(urls) }
            }
            return true
        }
    }
}

/// Which dropped files the shelf shows.
enum ShelfFilter: String, CaseIterable, Identifiable {
    case all, images, documents
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "Alle"
        case .images: "Bilder"
        case .documents: "Dokumente"
        }
    }
    func matches(_ url: URL) -> Bool {
        let type = UTType(filenameExtension: url.pathExtension)
        let isImage = type?.conforms(to: .image) ?? false
        switch self {
        case .all: return true
        case .images: return isImage
        case .documents: return !isImage
        }
    }
}

// MARK: Clipboard

struct ClipboardTile: View {
    private var clip = ClipboardHistory.shared

    var body: some View {
        IslandCard(width: Metrics.wideTileWidth - 64) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack {
                    CardHeader(title: "Zwischenablage", symbol: "doc.on.clipboard")
                    Spacer()
                    Button("Alle") { Windows.show(.clipboard) }
                        .buttonStyle(.plain).font(TypeStyle.islandLabel).foregroundStyle(IslandColor.accentText)
                }
                if clip.items.isEmpty {
                    IslandEmpty(symbol: "doc.on.clipboard", text: "Kopiertes erscheint hier. Nur Angeheftetes wird gespeichert.")
                } else {
                    ForEach(clip.items.prefix(4)) { item in
                        Button { clip.copy(item); IslandModel.shared.show(Toast(symbol: "doc.on.doc", text: "Kopiert")) } label: {
                            Label(item.kind == .image ? item.text : item.preview, systemImage: item.pinned ? "pin.fill" : (item.kind == .image ? "photo" : item.kind == .file ? "doc" : "text.alignleft"))
                                .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain).font(TypeStyle.islandBody)
                        .help("Erneut kopieren")
                    }
                }
            }
        }
    }
}

// MARK: Recent apps

struct RecentAppsTile: View {
    private var recent = RecentApps.shared

    var body: some View {
        IslandCard {
            VStack(alignment: .leading, spacing: Space.sm) {
                CardHeader(title: "Letzte Apps", symbol: "square.stack")
                if recent.apps.isEmpty {
                    IslandEmpty(symbol: "square.stack", text: "Apps, die du benutzt, erscheinen hier.")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: Space.xs), count: 4), spacing: Space.xs) {
                    ForEach(recent.apps.prefix(8), id: \.processIdentifier) { app in
                        Button { app.activate() } label: {
                            Image(nsImage: app.icon ?? NSImage()).resizable().frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .help(app.localizedName ?? "")
                        .accessibilityLabel(app.localizedName ?? "App")
                    }
                }
            }
        }
    }
}

// MARK: Controls

struct ControlsTile: View {
    private var controls = SystemControls.shared
    private var recorder = ScreenRecorder.shared

    var body: some View {
        IslandCard(width: Metrics.wideTileWidth) {
            VStack(alignment: .leading, spacing: Space.xs) {
                CardHeader(title: "Steuerungen", symbol: "switch.2")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.xs), count: 5), spacing: Space.xs) {
                    toggle("circle.lefthalf.filled", "Dunkel", controls.darkMode, full: "Dunkelmodus") { controls.setDarkMode(!controls.darkMode) }
                    toggle("menubar.dock.rectangle", "Desktop", controls.desktopIconsHidden, full: "Symbole auf dem Schreibtisch ausblenden") { controls.setDesktopIconsHidden(!controls.desktopIconsHidden) }
                    toggle("eye", "Versteckt", controls.hiddenFilesShown, full: "Versteckte Dateien im Finder zeigen") { controls.setHiddenFilesShown(!controls.hiddenFilesShown) }
                    toggle("cup.and.saucer.fill", "Wach", controls.keepAwake, full: "Mac wach halten") { controls.setKeepAwake(!controls.keepAwake) }
                    toggle("record.circle", "Aufnahme", recorder.isRecording, full: recorder.isRecording ? "Bildschirmaufnahme beenden" : "Bildschirm aufnehmen") { recorder.toggle() }
                    toggle("moon.fill", "Fokus", false, full: "Nicht stören umschalten") { controls.toggleFocus() }
                    toggle("trash", "Leeren", false, full: "Papierkorb leeren") { controls.emptyTrash() }
                    toggle("lock.fill", "Sperren", false, full: "Bildschirm sperren") { controls.lockScreen() }
                    toggle("display", "Display", false, full: "Display ausschalten") { controls.displaySleep() }
                    toggle("zzz", "Ruhe", false, full: "Ruhezustand") { controls.sleepNow() }
                }
                if let m = controls.message {
                    Text(m).font(TypeStyle.islandMicro).foregroundStyle(IslandColor.warm).lineLimit(2)
                }
            }
        }
        .onAppear { controls.refresh() }
    }

    /// `title` is the short label under the icon; `full` names the action for the tooltip and VoiceOver.
    private func toggle(_ symbol: String, _ title: String, _ on: Bool, full: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                    .frame(width: 32, height: 24)
                    .background(on ? IslandColor.accentFill : IslandColor.cardHover, in: RoundedRectangle(cornerRadius: Radius.chip))
                    .foregroundStyle(on ? IslandColor.onAccent : IslandColor.primaryText)
                Text(title).font(TypeStyle.islandMicro).foregroundStyle(IslandColor.secondaryText).lineLimit(1)
            }
        }
        .buttonStyle(IslandPressStyle())
        .help(full)
        .accessibilityLabel(full)
        .accessibilityValue(on ? "Ein" : "Aus")
    }
}

// MARK: Shortcuts

/// Your own buttons: each runs a shortcut from the Shortcuts app.
struct ShortcutsTile: View {
    private var prefs = Prefs.shared

    var body: some View {
        IslandCard(width: Metrics.wideTileWidth - 64) {
            VStack(alignment: .leading, spacing: Space.sm) {
                CardHeader(title: "Kurzbefehle", symbol: "bolt.fill")
                if prefs.shortcutButtons.isEmpty {
                    IslandEmpty(symbol: "bolt", text: "Wähle in den Einstellungen unter Kacheln, welche Kurzbefehle hier erscheinen.")
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.xs), GridItem(.flexible(), spacing: Space.xs)], spacing: Space.xs) {
                        ForEach(prefs.shortcutButtons) { b in
                            Button { ShortcutRunner.run(b) } label: {
                                Label(b.name, systemImage: b.symbol).lineLimit(1)
                                    .font(TypeStyle.islandCaption.weight(.medium))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, Space.sm).padding(.vertical, Space.xs + 2)
                                    .background(IslandColor.cardHover, in: RoundedRectangle(cornerRadius: Radius.chip))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Kurzbefehl \(b.name) ausführen")
                        }
                    }
                }
            }
        }
    }
}

enum ShortcutRunner {
    /// Runs the shortcut by name (argument array, never a shell) and reports the outcome in the notch.
    static func run(_ b: ShortcutButton) {
        IslandModel.shared.show(Toast(symbol: "bolt.fill", text: "\(b.name) läuft…"), seconds: 30)
        Task {
            let r = await Run.async("/usr/bin/shortcuts", ["run", b.name], timeout: 120)
            IslandModel.shared.show(r.status == 0 ? Toast(symbol: "checkmark.circle", text: "\(b.name) erledigt")
                                                  : Toast(symbol: "exclamationmark.triangle", text: "\(b.name) ist fehlgeschlagen", warm: true))
        }
    }

    static func available() async -> [String] {
        ShortcutsCLI.parseList((await Run.async("/usr/bin/shortcuts", ["list"], timeout: 15)).output)
    }
}
