// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UniformTypeIdentifiers
import VibrantPlusKit

/// The island: a black shape that grows out of the notch.
struct IslandRoot: View {
    @State private var model = IslandModel.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var agent = AgentStore.shared
    private var today = TodayStore.shared

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                if model.isOpen {
                    VStack(spacing: 0) {
                        // The band beside the notch is not wasted: the pages put their tabs there.
                        band
                        openContent
                            .padding(.top, Space.xs)
                            .padding([.horizontal, .bottom], Metrics.islandPadding)
                    }
                    // As wide as what it shows needs: the pages take the full width, one card less.
                    .frame(width: showsPages ? Metrics.islandWidth : Metrics.islandCardWidth)
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                        guard abs(size.height - model.openHeight) > 1 || abs(size.width - model.openWidth) > 1 else { return }
                        // Never resize the window inside SwiftUI's layout pass: AppKit throws.
                        DispatchQueue.main.async {
                            model.openHeight = size.height
                            model.openWidth = size.width
                        }
                    }
                    // The content grows out of the notch with the shape. Only a fade with Reduce motion.
                    .transition(.asymmetric(
                        insertion: (reduceMotion ? AnyTransition.opacity
                                                 : .opacity.combined(with: .scale(scale: Motion.contentScale, anchor: .top)))
                            .animation(Motion.contentIn),
                        removal: .opacity.animation(Motion.contentOut)))
                } else {
                    ClosedWings()
                        .transition(.opacity)
                }
            }
            // Shoulders sit outside the body: pad first, then draw the outline around it.
            .padding(.horizontal, shoulder)
            .islandBackground(IslandShape(radius: model.isOpen ? CGFloat(NotchGeometry.openRadius)
                                                               : CGFloat(NotchGeometry.closedRadius(notchHeight: model.notchSize.height)),
                                          shoulder: shoulder), open: model.isOpen)
            .shadow(color: model.isOpen ? Shadow.card : .clear, radius: Shadow.cardRadius, y: Shadow.cardY)
            .scaleEffect(model.growing ? 0.8 : 1, anchor: .top)
            .environment(\.colorScheme, IslandColor.scheme)
            // Pulsi peeks out under the notch while the mouse rests on it, and hangs on the open island.
            .overlay(alignment: .top) { peekingMascot }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Pulsi hangs partly below the island: a layer over the whole window, because SwiftUI gives no clicks
        // to views outside their parent's bounds.
        .overlay { GeometryReader { geo in hangingMascot(in: geo.size) } }
        // Esc folds the island. With a Claude request on screen, Esc belongs to «Ablehnen».
        .onExitCommand {
            guard model.isOpen, agent.pending.isEmpty else { return }
            withAnimation(Motion.respecting(Motion.islandClose)) { IslandController.shared.close() }
        }
        .animation(Motion.respecting(model.isOpen ? Motion.island : Motion.islandClose), value: model.isOpen)
        .animation(Motion.respecting(Motion.island), value: model.page)
        .animation(Motion.respecting(Motion.quick), value: agent.pending.count)
        .animation(Motion.respecting(Motion.island), value: showsPages)
    }

    private var mascotOn: Bool { Prefs.shared.mascot }

    /// Closed island, mouse on the notch: the mascot rises from behind the pill. The clipped frame
    /// hides the part still behind the notch.
    private var peekingMascot: some View {
        Color.clear
            .frame(width: PulsMascot.size.width, height: PulsMascot.size.height)
            .overlay(alignment: .top) {
                if mascotOn && !model.isOpen && model.near {
                    PulsMascot(anchor: IslandController.shared.mascotAnchor(open: false),
                               mood: PulsiVoice.shared.talking ? .happy : .normal)
                        .overlay(alignment: .bottomTrailing) {
                            if PulsiWake.shared.running {
                                Image(systemName: "ear")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(IslandColor.accentText)
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .clipped()
            .offset(y: model.notchSize.height + Space.sm - 1)
            .allowsHitTesting(false)
    }

    /// Open island: Pulsi hangs on the bottom edge. Click, drag and right click: see HangingMascot.
    @ViewBuilder private func hangingMascot(in container: CGSize) -> some View {
        if mascotOn && model.isOpen {
            HangingMascot(container: container)
                .transition(.scale(scale: 0.4, anchor: .top).combined(with: .opacity))
        }
    }

    /// Nothing is asking for attention: the island shows its pages. Otherwise it shows one card.
    /// What comes first: a dragged file, then what a person has to answer (Claude, a reminder),
    /// then a new screenshot, then what the island was doing anyway.
    private var showsPages: Bool {
        !model.dragging && agent.pending.isEmpty && today.due.isEmpty && ScreenshotShelf.shared.latest == nil
            && !(Assistant.shared.visible && Prefs.shared.isOn(.assistant)) && StowModel.shared.isEmpty
    }

    /// The top band of the open island, as high as the notch. Left of the notch the page tabs,
    /// right of it the date and the settings. A single card leaves the band empty.
    @ViewBuilder private var band: some View {
        if showsPages {
            HStack(spacing: 0) {
                Group {
                    if Prefs.shared.islandNavigation.placement == .besideNotch {
                        GeometryReader { geo in
                            let pages = IslandModel.Page.available.count
                            let tab = IslandNavLayout.tabMinWidth(count: pages, available: geo.size.width)
                            IslandPageTabs(page: $model.page, showsTitle: false, minWidth: tab)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        }
                    }
                }
                .background { pageShortcuts }
                .frame(maxWidth: .infinity, alignment: .leading)
                // The notch itself: nothing can be shown there.
                Color.clear.frame(width: model.notchSize.width)
                HStack(spacing: Space.xs) {
                    if Prefs.shared.islandNavigation.showsDate {
                        ViewThatFits(in: .horizontal) {
                            dateLabel
                            EmptyView()
                        }
                    }
                    if Prefs.shared.islandNavigation.showsSettings { IslandIconButton(symbol: "gearshape", label: "Einstellungen", size: 24) {
                        AppActions.openSettings()
                    } }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, Metrics.islandPadding)
            .frame(height: model.bandHeight)
        } else {
            Color.clear.frame(height: model.bandHeight)
        }
    }

    /// Concave shoulders where the island meets the menu bar, sized from the notch; none when idle.
    private var shoulder: CGFloat {
        let visible = model.isOpen || model.near || IslandController.shared.hasWings || IslandController.shared.hasRing
        return visible ? CGFloat(NotchGeometry.shoulder(notchHeight: model.notchSize.height, open: model.isOpen)) : 0
    }

    @ViewBuilder private var openContent: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if showsPages && Prefs.shared.islandNavigation.placement == .aboveTiles {
                IslandPageTabs(page: $model.page, showsTitle: Prefs.shared.islandNavigation.labels != .icons)
            }
            if model.dragging {
                DropZones()
            } else if let p = agent.pending.first {
                // Each request arrives on its own: it settles in from just above, the next one
                // in the queue replaces it the same way. Only a fade with Reduce motion.
                AgentRequestCard(pending: p)
                    .id(p.id)
                    .transition(.asymmetric(insertion: reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -Space.sm)), // grid: ok transition, not layout
                                            removal: .opacity))
            } else if let task = today.due.first {
                ReminderCard(task: task)
            } else if ScreenshotShelf.shared.latest != nil {
                ScreenshotCard()
            } else if Assistant.shared.visible && Prefs.shared.isOn(.assistant) {
                AssistantCard()
            } else if !StowModel.shared.isEmpty {
                StowPanel()
            } else {
                switch IslandModel.Page.reachable.contains(model.page) ? model.page : .home {
                case .home: TileStrip(category: .start)
                case .mac: TileStrip(category: .mac)
                case .ai: TileStrip(category: .ai)
                case .tools: TileStrip(category: .tools)
                case .today: TodayView(compact: true)
                case .claude: ClaudePage()
                case .files: FilesPage()
                case .downloads: DownloadPage()
                case .assistant: AssistantCard()
                }
            }
            if let toast = model.toast { ToastRow(toast: toast) }
            else if Prefs.shared.islandKeepNotices, !model.notices.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(model.notices.prefix(3)) { note in
                        Label(note.text, systemImage: note.symbol)
                            .font(TypeStyle.islandCaption).foregroundStyle(note.warm ? IslandColor.warm : IslandColor.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    /// ⌘1 … ⌘6 pick a page. Invisible buttons that only carry the shortcuts.
    private var pageShortcuts: some View {
        ForEach(Array(IslandModel.Page.available.enumerated()), id: \.element) { index, page in
            Button(page.title) { model.page = page }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }

    private var dateLabel: some View {
        HStack(spacing: 0) {
            Text(Date.now, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                .foregroundStyle(IslandColor.secondaryText)
            // Brandguide 04: a title may end with the Puls point, once per view.
            // (not when the abbreviated date already ends with a period: "Nov.")
            if !Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).hasSuffix(".") {
                Text(".").foregroundStyle(IslandColor.dot)
            }
        }
        .font(TypeStyle.islandCaption)
        .lineLimit(1)
        .fixedSize()
    }
}

/// Small content next to the notch while the island is closed.
struct ClosedWings: View {
    private var agent = AgentStore.shared
    private var music = NowPlaying.shared
    private var today = TodayStore.shared
    private var timer = QuickTimer.shared
    private var model = IslandModel.shared

    /// A countdown is on screen: tick every second. Otherwise every 30 s is enough to notice a
    /// meeting coming within five minutes; everything else arrives through observation.
    private var tick: TimeInterval {
        today.focusRunning || timer.running || MeetingWatch.isSoon ? 1 : 30
    }

    /// Both wings grow together (the notch stays centered) when a note would not fit in the
    /// normal wing, so «Bildschirmaufnahme fehlt …» is readable without opening the island.
    /// The island controller reads it to know where a click still belongs to the pill.
    static var halfWidth: CGFloat {
        guard let toast = IslandModel.shared.toast else { return Metrics.compactPillExtra }
        let width = (toast.text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium)]).width
        return width + Space.sm > Metrics.compactPillExtra ? min(Metrics.toastWingWidth, width + Space.sm) : Metrics.compactPillExtra
    }

    private var wingWidth: CGFloat { Self.halfWidth }

    var body: some View {
        TimelineView(.periodic(from: .now, by: tick)) { context in
            if IslandController.shared.hasWings {
                // Something to show: the island grows sideways around the notch.
                HStack(spacing: 0) {
                    left(context.date)
                        .frame(width: wingWidth, alignment: .leading)
                        .padding(.leading, Space.md)
                    Spacer(minLength: model.notchSize.width - Space.md * 2)
                    right(context.date)
                        .frame(width: wingWidth, alignment: .trailing)
                        .padding(.trailing, Space.md)
                }
                .font(TypeStyle.islandCaption.weight(.medium))
                .foregroundStyle(IslandPalette.notch.primaryText)
                .frame(height: model.notchSize.height)
            } else if IslandController.shared.hasRing {
                // A timer or a focus session: a thin line just below the notch, so how far it has
                // come is visible without opening anything. The shape reaches a little past the
                // band: inside the notch itself there are no pixels on a real Mac.
                Color.clear
                    .frame(width: model.notchSize.width, height: model.notchSize.height + Space.xs)
                    .overlay(alignment: .bottom) { NotchProgress().padding(.bottom, 2) }
            } else if model.near {
                // The mouse heads for the notch: the island appears, a little wider than the notch.
                // It reaches a little below the menu bar so it is visible on a black menu bar too.
                Color.clear.frame(width: model.notchSize.width + Space.xl * 2, height: model.notchSize.height + Space.sm)
            } else {
                // Idle: nothing at all.
                Color.clear.frame(width: 0, height: 0)
            }
        }
        .animation(Motion.respecting(Motion.island), value: wingKey)
    }

    private var wingKey: String {
        "\(model.near)|\(IslandController.shared.hasActivityWings)|\(IslandController.shared.hasRing)|\(agent.headline?.status.rawValue ?? "")|\(music.isPlaying)|\(today.focusRunning)|\(timer.running)|\(model.toast?.id.uuidString ?? "")|\(MeetingWatch.isSoon)"
    }

    @ViewBuilder private func left(_ now: Date) -> some View {
        if VoiceController.shared.listening != nil {
            // Listening: the level of your voice, so you see that it hears you.
            VoiceLevel()
        } else if let toast = model.toast {
            Image(systemName: toast.symbol).foregroundStyle(toast.warm ? IslandPalette.notch.warm : IslandPalette.notch.accent)
        } else if let s = agent.headline, s.status.needsAnswer {
            AgentPulse(status: s.status)
        } else if MeetingWatch.isSoon {
            Image(systemName: "video.fill").foregroundStyle(IslandPalette.notch.accent)
        } else if activeDownload != nil {
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(IslandPalette.notch.accent)
                .accessibilityLabel("Download läuft")
        } else if StowModel.shared.busy {
            Image(systemName: "wand.and.stars").foregroundStyle(IslandPalette.notch.accent)
                .accessibilityLabel("Stow wandelt um")
        } else if let s = agent.headline, s.status.isActive {
            AgentPulse(status: s.status)
        } else if music.isPlaying, let cover = music.cover {
            Image(nsImage: cover).resizable().frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 4))
        } else if music.isPlaying {
            Image(systemName: "music.note")
        } else if today.focusRunning || timer.running {
            Image(systemName: "timer").foregroundStyle(IslandPalette.notch.accent)
        }
    }

    @ViewBuilder private func right(_ now: Date) -> some View {
        if let toast = model.toast {
            Text(toast.text).lineLimit(1).foregroundStyle(IslandPalette.notch.secondaryText)
        } else if let s = agent.headline, s.status.needsAnswer {
            Text(statusWord(s.status)).foregroundStyle(IslandPalette.notch.warm)
        } else if MeetingWatch.isSoon, let next = CalendarService.shared.next {
            Text(Clock.format(next.start.timeIntervalSince(now))).monospacedDigit()
        } else if let download = activeDownload {
            // How far it is: a ring and the percentage. Without a known size (or while it is
            // being prepared or converted) only the word.
            if case .loading(let fraction?) = download.state {
                HStack(spacing: Space.xs) {
                    IslandRing(value: fraction, tint: IslandPalette.notch.accent, track: IslandPalette.notch.cardHover)
                    Text("\(Int((fraction * 100).rounded())) %").monospacedDigit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Download \(Int((fraction * 100).rounded())) Prozent")
            } else {
                Text("lädt").foregroundStyle(IslandPalette.notch.secondaryText)
            }
        } else if StowModel.shared.busy {
            Text("wandelt um").foregroundStyle(IslandPalette.notch.secondaryText)
        } else if let s = agent.headline, s.status.isActive {
            Text(statusWord(s.status)).foregroundStyle(IslandPalette.notch.secondaryText)
        } else if music.isPlaying {
            Equalizer()
        } else if today.focusRunning {
            Text(Clock.format(today.focusRemaining(at: now))).monospacedDigit()
        } else if timer.running {
            Text(Clock.format(timer.remaining(at: now))).monospacedDigit()
        }
    }

    /// The download under way, if downloads are switched on.
    private var activeDownload: DownloadItem? {
        Prefs.shared.isOn(.downloads) ? Downloads.shared.running : nil
    }

    private func statusWord(_ s: AgentSession.Status) -> String {
        switch s {
        case .working: "arbeitet"
        case .needsPermission: "fragt"
        case .asking: "Frage"
        case .waiting: "fertig"
        case .ended: ""
        }
    }
}

/// How far a running timer or a focus session has come: a quiet line just below the notch.
/// It is there without hovering, because the person started it on purpose.
struct NotchProgress: View {
    private var timer = QuickTimer.shared
    private var today = TodayStore.shared
    private var model = IslandModel.shared

    /// Slightly narrower than the notch: the shape's bottom corners would cut the ends off.
    private var width: CGFloat { max(Space.xxl, model.notchSize.width - Space.lg) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let value = progress(at: ctx.date)
            Capsule()
                .fill(IslandPalette.notch.accent.opacity(0.22))
                .frame(width: width, height: 2)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(IslandPalette.notch.accent)
                        .frame(width: max(2, width * value), height: 2)
                }
                .animation(Motion.respecting(Motion.quick), value: value)
                .accessibilityElement()
                .accessibilityLabel(timer.running ? "Timer läuft" : "Fokus läuft")
                .accessibilityValue("\(Int((value * 100).rounded())) Prozent")
        }
    }

    /// Done share of the running timer, else of the focus session.
    private func progress(at now: Date) -> Double {
        if timer.running, timer.length > 0 {
            return min(1, max(0, 1 - timer.remaining(at: now) / timer.length))
        }
        if today.focusRunning {
            return min(1, max(0, today.focusProgress(at: now)))
        }
        return 0
    }
}

/// A calm pulse for Claude's status. Still when Reduce Motion is on.
struct AgentPulse: View {
    var status: AgentSession.Status
    @State private var on = false
    /// Read live: switching Reduce motion on stops a pulse that is already running.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "sparkle")
            .foregroundStyle(status == .needsPermission || status == .asking ? IslandPalette.notch.warm : IslandPalette.notch.accent)
            .opacity(status == .working && on ? 0.45 : 1)
            .onAppear(perform: updatePulse)
            .onChange(of: reduceMotion) { updatePulse() }
            .accessibilityLabel("Claude Code")
    }

    private func updatePulse() {
        if reduceMotion {
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { on = false }
        } else {
            withAnimation(Motion.pulse) { on = true }
        }
    }
}

/// Five bars that follow the microphone while Vibrant+ listens. With Reduce Motion: the still symbol.
struct VoiceLevel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The middle bar is the tallest, like a voice.
    private let shape: [Double] = [0.45, 0.75, 1, 0.75, 0.45]

    var body: some View {
        if reduceMotion {
            Image(systemName: "waveform").foregroundStyle(IslandPalette.notch.accent)
        } else {
            TimelineView(.animation(minimumInterval: Motion.voiceLevelInterval)) { ctx in
                // Speech peaks are small numbers: the root lifts quiet voices into view.
                let level = min(1, Double(audioLevel.latest).squareRoot() * 1.6)
                let t = ctx.date.timeIntervalSinceReferenceDate
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Capsule().fill(IslandPalette.notch.accent)
                            .frame(width: 2, height: 3 + 11 * level * shape[i] * (0.7 + 0.3 * abs(sin(t * 9 + Double(i) * 1.7)))) // grid: ok level bars, not layout
                    }
                }
                .frame(width: 20, height: 16)
                .animation(Motion.quick, value: level)
            }
            .accessibilityLabel("Vibrant+ hört zu")
        }
    }
}

/// Three bars for "music is playing". Still when Reduce Motion is on.
struct Equalizer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: Motion.equalizerInterval, paused: reduceMotion || !Prefs.shared.equalizerMoves)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(NowPlaying.shared.coverColor ?? IslandPalette.notch.accent)
                        .frame(width: 3, height: 5 + 7 * abs(sin(t * 3 + Double(i) * 1.3)))
                }
            }
            .frame(height: 12)
        }
        .accessibilityLabel("Musik läuft")
    }
}

struct ToastRow: View {
    var toast: Toast
    var body: some View {
        Label(toast.text, systemImage: toast.symbol)
            .font(TypeStyle.islandCaption)
            .foregroundStyle(toast.warm ? IslandColor.warm : IslandColor.secondaryText)
            .padding(.horizontal, Space.xs)
    }
}

// MARK: - Drop zones

/// While files are dragged to the notch: Stow, the Shelf, or Claude.
struct DropZones: View {
    var body: some View {
        HStack(spacing: Space.sm) {
            if Prefs.shared.isOn(.stow) {
                DropZone(title: "Umwandeln", subtitle: "Stow: Format wählen", symbol: "wand.and.stars") { urls in
                    StowModel.shared.load(urls)
                }
            }
            DropZone(title: "Ablegen", subtitle: "In die Ablage", symbol: "tray.and.arrow.down") { urls in
                Shelf.shared.add(urls)
                IslandModel.shared.show(Toast(symbol: "tray.fill", text: "\(urls.count) in der Ablage"))
            }
            if Prefs.shared.isOn(.agent) {
                DropZone(title: "An Claude", subtitle: "Mit der nächsten Nachricht", symbol: "sparkles") { urls in
                    AgentStore.shared.addFilesForClaude(urls)
                    IslandModel.shared.show(Toast(symbol: "sparkles", text: "Für die nächste Nachricht an Claude"))
                    PulsiVoice.shared.say("Die Dateien liegen für Claude bereit.")
                }
            }
        }
        .frame(height: Metrics.tileHeight)
    }
}

struct DropZone: View {
    var title: String
    var subtitle: String
    var symbol: String
    var onDrop: ([URL]) -> Void
    @State private var targeted = false

    var body: some View {
        VStack(spacing: Space.sm) {
            Image(systemName: symbol).font(.system(size: 22, weight: .medium))
            Text(title).font(TypeStyle.islandTitle)
            Text(subtitle).font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
        }
        .foregroundStyle(targeted ? IslandColor.onAccent : IslandColor.primaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(targeted ? IslandColor.accent : IslandColor.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            .strokeBorder(IslandColor.separator, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            Task {
                var urls: [URL] = []
                for p in providers {
                    if let url = try? await p.loadItem(forTypeIdentifier: UTType.fileURL.identifier) as? Data,
                       let u = URL(dataRepresentation: url, relativeTo: nil) { urls.append(u) }
                }
                guard !urls.isEmpty else { return }
                await MainActor.run {
                    IslandModel.shared.dragging = false
                    onDrop(urls)
                }
            }
            return true
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Agent request

/// A permission request or a question from Claude Code.
struct AgentRequestCard: View {
    var pending: AgentStore.Pending
    /// Question text -> chosen option labels (one, or several for multi-select).
    @State private var choices: [String: Set<String>] = [:]
    private var agent = AgentStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Image(systemName: pending.event.isQuestion ? "questionmark.bubble.fill" : "hand.raised.fill")
                    .foregroundStyle(IslandColor.warm)
                Text(pending.event.isQuestion ? "Claude fragt" : "Claude möchte")
                    .font(TypeStyle.islandTitle)
                Text(projectName).font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                Spacer()
                // More requests wait behind this one (other sessions): say how many.
                if agent.pending.count > 1 {
                    Text("1 von \(agent.pending.count)")
                        .font(TypeStyle.islandLabel.monospacedDigit())
                        .padding(.horizontal, Space.sm).padding(.vertical, 2)
                        .background(IslandColor.field, in: Capsule())
                        .foregroundStyle(IslandColor.secondaryText)
                        .accessibilityLabel("\(agent.pending.count - 1) weitere Anfragen warten")
                }
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(Clock.format(pending.expires.timeIntervalSince(ctx.date)))
                        .font(TypeStyle.islandCaption.monospacedDigit())
                        .foregroundStyle(IslandColor.tertiaryText)
                        .help("Danach fragt Claude Code im Terminal")
                }
            }
            if pending.event.isQuestion {
                questions
            } else {
                permission
            }
        }
        .padding(Space.md)
        .islandSurface(tone: .warm)
    }

    private var projectName: String {
        agent.sessions[pending.event.sessionID]?.projectName ?? ""
    }

    private var permission: some View {
        let detail = pending.permission
        return VStack(alignment: .leading, spacing: Space.sm) {
            Text(detail.title).font(TypeStyle.islandBody.weight(.medium))
            // The whole text, never cut: long commands scroll. What you allow is what you see.
            ScrollView(.vertical) {
                Text(detail.body.isEmpty ? "–" : detail.body)
                    .font(TypeStyle.islandCode)
                    .foregroundStyle(IslandColor.primaryText)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.sm)
            }
            .frame(maxHeight: Metrics.permissionBodyMaxHeight)
            .fixedSize(horizontal: false, vertical: true)
            .background(IslandColor.field, in: RoundedRectangle(cornerRadius: Radius.chip))
            .accessibilityLabel("Inhalt der Anfrage")
            .accessibilityValue(detail.body)
            if let note = detail.note {
                Text("Laut Claude: \(note)")
                    .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                    .lineLimit(3)
            }
            if !detail.warnings.isEmpty {
                Label("Achtung: " + detail.warnings.joined(separator: ", "), systemImage: "exclamationmark.triangle.fill")
                    .font(TypeStyle.islandCaption.weight(.semibold))
                    .foregroundStyle(IslandColor.warm)
            }
            // A standing rule is a bigger yes than one command: say exactly what it adds.
            if pending.event.offersAlways {
                let rules = PermissionDetail.alwaysRules(pending.event.permissionSuggestions)
                Text("«Immer erlauben» trägt ein: " + rules.joined(separator: "; "))
                    .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
            HStack(spacing: Space.sm) {
                IslandPillButton(title: "Ablehnen", kind: .danger) { agent.answer(pending, .deny) }
                    .keyboardShortcut(.cancelAction)
                IslandPillButton(title: "Im Terminal") { agent.answerInTerminal(pending) }
                Spacer()
                if pending.event.offersAlways {
                    IslandPillButton(title: "Immer erlauben", kind: .warm) { agent.answer(pending, .always) }
                }
                // ⌘↩, never plain ↩: a Return typed into another island field must not allow a command.
                IslandPillButton(title: "Erlauben", kind: .primary) { agent.answer(pending, .allow) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Erlauben (⌘↩)")
            }
        }
    }

    private var questions: some View {
        let list = pending.questions
        let complete = list.allSatisfy { !(choices[$0.question] ?? []).isEmpty }
        return VStack(alignment: .leading, spacing: Space.md) {
            ForEach(list) { q in
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(q.question).font(TypeStyle.islandBody.weight(.medium))
                    if q.multiSelect {
                        Text("Mehrere möglich").font(TypeStyle.islandCaption).foregroundStyle(IslandColor.tertiaryText)
                    }
                    FlowChips(question: q, selected: choices[q.question] ?? []) { option in
                        var set = choices[q.question] ?? []
                        if q.multiSelect {
                            if set.contains(option) { set.remove(option) } else { set.insert(option) }
                        } else {
                            set = [option]
                        }
                        choices[q.question] = set
                    }
                }
            }
            HStack {
                IslandPillButton(title: "Im Terminal antworten") { agent.answerInTerminal(pending) }
                Spacer()
                // Until every question has an answer the button is secondary and inactive, but stays
                // readable (no extra dimming on top of the disabled state).
                IslandPillButton(title: "Antworten", kind: complete ? .primary : .secondary) {
                    let answers = Dictionary(uniqueKeysWithValues: list.map { ($0.question, $0.answer(choices[$0.question] ?? [])) })
                    agent.answer(pending, .answer, answers: answers)
                }
                .disabled(!complete)
                .help(complete ? "Antworten" : "Zuerst jede Frage beantworten")
            }
        }
    }
}

/// The options of one question. Multi-select questions toggle; Claude's explanation of an
/// option shows as its tooltip and is read by VoiceOver.
struct FlowChips: View {
    var question: AgentQuestion
    var selected: Set<String>
    var pick: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.xs) {
                ForEach(question.options, id: \.self) { o in
                    IslandPillButton(title: o, kind: selected.contains(o) ? .primary : .secondary) { pick(o) }
                        .help(question.descriptions[o] ?? o)
                        .accessibilityHint(question.descriptions[o] ?? "")
                        .accessibilityAddTraits(selected.contains(o) ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - Reminder

struct ReminderCard: View {
    var task: TaskItem

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: "bell.fill").font(.system(size: 18)).foregroundStyle(IslandColor.warm)
            VStack(alignment: .leading, spacing: 2) {
                Text("Erinnerung").font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                Text(task.title).font(TypeStyle.islandTitle).lineLimit(2)
            }
            Spacer()
            IslandPillButton(title: "+10 Min.") { TodayStore.shared.snooze(task) }
            IslandPillButton(title: "Erledigt", kind: .primary) { TodayStore.shared.toggle(task) }
        }
        .padding(Space.md)
        .islandSurface(tone: .warm)
    }
}

extension AgentSession.Status {
    /// Claude works or waits for the person: worth a wing next to the notch.
    var isActive: Bool { self == .working || self == .needsPermission || self == .asking }
    /// Claude waits for the person: this goes before everything else beside the notch.
    var needsAnswer: Bool { self == .needsPermission || self == .asking }
}

/// The island's page switcher, in the band beside the notch: one symbol per page, the chosen
/// page as a pill that also carries its name and slides to the next one. `showsTitle: false`
/// is the version for a narrow band (a wide notch): symbols only, the name as tooltip.
struct IslandPageTabs: View {
    @Binding var page: IslandModel.Page
    var showsTitle = true
    var minWidth: CGFloat = 28
    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Light grounds: a tinted pill. Dark grounds and glass: a lighter pill.
    private var pillColor: Color {
        IslandColor.isGlass || IslandColor.scheme == .dark ? IslandColor.cardHover : IslandColor.card
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(IslandModel.Page.available, id: \.self) { p in
                tab(p)
            }
        }
        .fixedSize(horizontal: showsTitle, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Seite")
        .contextMenu {
            Button("Navigation anpassen…") { AppActions.openSettings(.island) }
        }
    }

    private func tab(_ p: IslandModel.Page) -> some View {
        let selected = p == page
        let named = showsTitle && Prefs.shared.islandNavigation.labels != .icons && (selected || Prefs.shared.islandNavigation.labels == .all)
        return Button {
            withAnimation(reduceMotion ? nil : Motion.island) { page = p }
        } label: {
            HStack(spacing: Space.xs) {
                Image(systemName: p.symbol)
                    .font(.system(size: minWidth >= 24 ? 11 : 10, weight: .semibold))
                if named {
                    Text(p.navigationTitle).font(TypeStyle.islandCaption.weight(.semibold)).lineLimit(1).fixedSize()
                }
            }
            .foregroundStyle(selected ? IslandColor.primaryText : IslandColor.secondaryText)
            .padding(.horizontal, selected && named ? Space.sm : 0)
            .frame(minWidth: minWidth, minHeight: 24)
            .frame(maxWidth: named ? .infinity : minWidth)
            .background {
                if selected {
                    Capsule().fill(pillColor).matchedGeometryEffect(id: "pill", in: pill)
                }
            }
        }
        .buttonStyle(IslandPressStyle())
        .help(p.navigationTitle)
        .accessibilityLabel(p.navigationTitle)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
