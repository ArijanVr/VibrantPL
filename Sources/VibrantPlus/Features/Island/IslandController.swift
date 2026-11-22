// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Observation
import SwiftUI
import VibrantPlusKit

/// State of the island the views read.
@Observable
final class IslandModel {
    static let shared = IslandModel()

    /// The tile strip is in arrange mode: tiles can be moved and widened.
    var arranging = false
    /// The island has just opened and still grows to full size (see IslandController.open).
    var growing = false

    /// The island's pages. Only those whose module is on are offered.
    enum Page: String, CaseIterable {
        case home, mac, ai, tools, today, claude, files, downloads, assistant
        var title: String {
            switch self {
            case .home: "Start"
            case .mac: "Mac"
            case .ai: "KI"
            case .tools: "Werkzeuge"
            case .today: "Heute"
            case .claude: "Claude"
            case .files: "Ablage"
            case .downloads: "Downloads"
            case .assistant: "Assistent"
            }
        }
        var symbol: String {
            switch self {
            case .home: "house.fill"
            case .mac: "macbook"
            case .ai: "chart.pie.fill"
            case .tools: "wrench.and.screwdriver.fill"
            case .today: "sun.max.fill"
            case .claude: "sparkles"
            case .files: "tray.fill"
            case .downloads: "arrow.down.circle.fill"
            case .assistant: "bubble.left.fill"
            }
        }
        var module: Module? {
            switch self {
            case .home, .files, .mac, .ai, .tools: nil
            case .today: .today
            case .claude: .agent
            case .downloads: .downloads
            case .assistant: .assistant
            }
        }
        /// The tile group a page shows, if it is one of the tile pages.
        var category: TileCategory? {
            switch self {
            case .home: .start
            case .mac: .mac
            case .ai: .ai
            case .tools: .tools
            default: nil
            }
        }
        /// Start is always there; the other tile pages only when one of their tiles is on.
        static var reachable: [Page] {
            allCases.filter { page in
                if page == .home { return true }
                if let c = page.category { return !Prefs.shared.visibleTiles(in: c).isEmpty }
                return page.module.map(Prefs.shared.isOn) ?? true
            }
        }

        static var available: [Page] {
            Prefs.shared.islandNavigation.visible(reachable.map(\.rawValue)).compactMap(Page.init(rawValue:))
        }

        var navigationTitle: String { Prefs.shared.islandNavigation.title(for: rawValue, fallback: title) }
    }

    var isOpen = false
    var page: Page = .home {
        willSet {
            guard newValue != page else { return }
            let pages = Page.available
            if let from = pages.firstIndex(of: page), let to = pages.firstIndex(of: newValue) { pageForward = to > from }
        }
        // Pages that are not tile strips have no end to swipe past: the neighbour is always reachable.
        didSet { if page.category == nil { atLeadingEdge = true; atTrailingEdge = true } }
    }
    /// The last page change went to the right in the tabs: the new page comes in from there.
    var pageForward = true
    /// The tab under the pointer: the band names it.
    var hoveredPage: Page?
    /// Whether the page's strip sits at its left / right end (or does not scroll at all):
    /// a swipe past that end goes to the neighbouring page.
    var atLeadingEdge = true
    var atTrailingEdge = true
    /// Files are being dragged near the notch: show the drop zones.
    var dragging = false
    var toast: Toast?
    var notices: [Toast] = []
    /// Notch size in points. Without a notch: a slim pill in the menu bar.
    var notchSize = CGSize(width: 192, height: 32)
    var hasNotch = false
    /// Size of the open island's content, measured by the view. It is as wide and as tall as
    /// what it shows needs, never more.
    var openHeight: CGFloat = Metrics.islandHeight
    var openWidth: CGFloat = Metrics.islandWidth
    /// Opened by an event (permission, reminder): stays until clicked away.
    var sticky = false
    /// The mouse is on the notch: the island shows itself (closed).
    var near = false
    /// The band at the top of the open island, beside the notch: the page tabs live there.
    var bandHeight: CGFloat { max(notchSize.height, Metrics.islandBandMinHeight) }

    @ObservationIgnored private var toastTask: Task<Void, Never>?

    func show(_ toast: Toast, seconds: Double = 4) {
        self.toast = toast
        if Prefs.shared.islandKeepNotices {
            notices.insert(toast, at: 0)
            if notices.count > 8 { notices = Array(notices.prefix(8)) }
        }
        Announce.say(toast.text, urgent: toast.warm)
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.respecting(Motion.fade)) { self.toast = nil }
        }
    }
}

/// A panel that can take keyboard input without activating Vibrant+.
final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Places the island under the notch, opens it on hover, closes it on a click elsewhere.
final class IslandController {
    static let shared = IslandController()

    let model = IslandModel.shared
    private var panel: IslandPanel?
    private var monitors: [Any] = []
    private var hoverTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var screenObserver: NSObjectProtocol?
    /// Extra room around the island for its shadow.
    private let shadowMargin: CGFloat = 48

    var isRunning: Bool { panel != nil }

    func start() {
        guard panel == nil else { return }
        let p = IslandPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        // One above the menu bar icons (also on .statusBar), so no icon is drawn over the open island.
        p.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        p.isMovable = false
        p.hidesOnDeactivate = false
        p.ignoresMouseEvents = true
        p.setAccessibilityLabel("Vibrant+ Insel")
        let host = NSHostingView(rootView: IslandRoot().themed())
        host.sizingOptions = []
        p.contentView = host
        panel = p
        layout(animated: false)
        p.orderFrontRegardless()
        installMonitors()
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.layout(animated: false) }
        }
    }

    /// Everything the island started goes with it: scrim, live stats, camera, conversation.
    /// A module that is switched off leaves nothing running (and nothing on screen).
    func stop() {
        hoverTask?.cancel()
        hoverTask = nil
        closeTask?.cancel()
        closeTask = nil
        ScrimController.shared.hide()
        Assistant.shared.endConversation()
        MirrorCamera.shared.stop()
        SystemStats.shared.setLive(false)
        for m in monitors { NSEvent.removeMonitor(m) }
        monitors = []
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        panel?.resignKey()
        panel?.orderOut(nil)
        panel = nil
        model.isOpen = false
        model.near = false
        model.dragging = false
        model.sticky = false
    }

    /// The display the island sits on: the one the mouse last headed for (top center),
    /// by default the one with the notch, else the main display.
    private var activeScreen: NSScreen?

    var screen: NSScreen? {
        if let a = activeScreen, NSScreen.screens.contains(a) { return a }
        return NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    /// Moves the island to another display when the mouse heads for that display's top center.
    /// Only while the island is closed; the panel keeps its size, it just moves.
    private func followMouse(_ p: CGPoint) {
        guard !model.isOpen, NSScreen.screens.count > 1,
              let i = ScreenPick.topCenterScreen(mouse: p, frames: NSScreen.screens.map(\.frame)) else { return }
        let target = NSScreen.screens[i]
        guard target != screen else { return }
        activeScreen = target
        layout(animated: false)
    }

    // MARK: Geometry

    private func measureNotch(_ screen: NSScreen) {
        if screen.safeAreaInsets.top > 0, let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea {
            model.hasNotch = true
            model.notchSize = CGSize(width: r.minX - l.maxX, height: screen.safeAreaInsets.top)
        } else {
            model.hasNotch = false
            let bar = max(24, screen.frame.maxY - screen.visibleFrame.maxY)
            model.notchSize = CGSize(width: NotchGeometry.pillWidth(menuBarHeight: bar), height: bar)
        }
    }

    /// Something to show next to the notch while closed.
    /// Idle, the island is invisible. It shows itself only for things that need you,
    /// or for everything else once the mouse heads for the notch.
    var hasWings: Bool { hasUrgentWings || hasActivityWings || (model.near && hasQuietWings) }

    /// A timer or a focus session runs: a thin line along the notch's bottom edge shows how far
    /// it has come, without opening anything. Only on a notched Mac: elsewhere the island has no
    /// body to put a line on, so it stays idle until the mouse comes.
    var hasRing: Bool {
        !model.isOpen && model.hasNotch && (QuickTimer.shared.running || TodayStore.shared.focusRunning)
    }

    /// Work that is under way and ends by itself: a download, a conversion. Its progress stays
    /// beside the notch until it is done, so nobody has to open the island to look.
    var hasActivityWings: Bool {
        (Prefs.shared.isOn(.downloads) && Downloads.shared.running != nil) || StowModel.shared.busy
    }

    /// Needs attention now: a note, Claude waiting for an answer, a meeting about to start.
    var hasUrgentWings: Bool {
        model.toast != nil || MeetingWatch.isSoon
            || [.needsPermission, .asking].contains(AgentStore.shared.headline?.status)
    }

    /// Worth a glance when you look: music, Claude working, focus, a timer.
    var hasQuietWings: Bool {
        AgentStore.shared.headline?.status == .working || NowPlaying.shared.isPlaying
            || TodayStore.shared.focusRunning || QuickTimer.shared.running
    }

    /// Where the closed island shows itself: the notch itself, nothing around or below it.
    /// Heading for the menu bar, a toolbar or a tab at the top of a window never wakes it.
    private var nearRect: CGRect { notchRect }

    /// The panel never moves or resizes while SwiftUI draws (AppKit throws when a hosting
    /// window changes during its constraints pass). It is placed once, as big as the island
    /// can get; mouse events pass through except over the open island.
    func layout(animated: Bool) {
        guard let panel, let screen else { return }
        measureNotch(screen)
        let size = CGSize(width: Metrics.islandWidth + shadowMargin * 2, height: Metrics.islandMaxHeight)
        let frame = CGRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height,
                           width: size.width, height: size.height)
        if panel.frame != frame { panel.setFrame(frame, display: false) }
        updateMouseThrough()
    }

    /// Clicks reach the island only where it is drawn.
    private func updateMouseThrough() {
        guard let panel else { return }
        let inside = model.isOpen && openRect.contains(NSEvent.mouseLocation)
        let take = inside || model.dragging
        if panel.ignoresMouseEvents == take { panel.ignoresMouseEvents = !take }
    }

    /// The notch (a hair wider) inside the menu bar band, in screen coordinates.
    private var notchRect: CGRect {
        guard let screen else { return .zero }
        let w = model.notchSize.width + 8, h = model.notchSize.height
        // The top edge counts: `NSEvent.mouseLocation` reaches `maxY`, which `contains` would reject.
        return CGRect(x: screen.frame.midX - w / 2, y: screen.frame.maxY - h, width: w, height: h + 1)
    }

    /// The mouse opens the island only when it is pushed all the way up into the notch.
    private func isOnTrigger(_ p: CGPoint) -> Bool {
        guard let screen else { return false }
        return NotchGeometry.isOnTopEdge(mouse: p, screen: screen.frame, notchWidth: model.notchSize.width)
    }

    /// True while a menu (menu bar menu, context menu, pop-up) is on screen. Then the island
    /// stays out of the way: it never opens or shows itself over a menu.
    /// Asking the window server is not free, so the answer is reused for 150 ms; it is only
    /// asked at all while the mouse is in one of the notch zones.
    private var menuIsOpen: Bool {
        let now = ProcessInfo.processInfo.systemUptime
        if now - menuCheckedAt < 0.15 { return menuOpenCached }
        let list = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
        menuOpenCached = list.contains { ($0[kCGWindowLayer as String] as? Int) == Int(CGWindowLevelForKey(.popUpMenuWindow)) }
        menuCheckedAt = now
        return menuOpenCached
    }
    private var menuOpenCached = false
    private var mouseDownPasteboardCount = 0
    private var menuCheckedAt: TimeInterval = 0

    private var openRect: CGRect {
        guard let screen else { return .zero }
        let w = model.openWidth + 24, h = model.openHeight + 24
        // Open to the top: `NSEvent.mouseLocation` reaches `maxY` at the display's top edge, which
        // `contains` would reject. Pushing the mouse further up must never fold the island away.
        return CGRect(x: screen.frame.midX - w / 2, y: screen.frame.maxY - h, width: w, height: h + 48)
    }

    /// The mouse rests on the open island. Cards that hide by themselves wait for it to leave.
    var pointerIsInside: Bool { model.isOpen && openRect.contains(NSEvent.mouseLocation) }

    /// The closed island as the mouse sees it: the notch (dead space on a notched Mac), the wings
    /// it shows, or the pill the mouse just brought out. A click there opens the island. The panel
    /// stays transparent to the mouse, so nothing under it loses a click that was meant for it.
    private var closedRect: CGRect {
        guard let screen else { return .zero }
        // Without a notch the pill sits in the menu bar: only a shown pill may take the click.
        guard model.hasNotch || hasWings || hasRing || model.near else { return .zero }
        let w: CGFloat
        var h = model.notchSize.height
        if hasWings {
            w = model.notchSize.width + ClosedWings.halfWidth * 2
        } else if hasRing {
            // The line hangs a little below the band, where a real Mac has pixels.
            w = model.notchSize.width + Space.xs * 2
            h += Space.xs
        } else if model.near {
            w = model.notchSize.width + Space.xl * 2
            h += Space.sm
        } else {
            w = model.notchSize.width + Space.sm * 2
        }
        return CGRect(x: screen.frame.midX - w / 2, y: screen.frame.maxY - h, width: w, height: h + 1)
    }

    /// What a click on the pill opens: the page that belongs to whatever the wings show.
    private func wingPage() -> IslandModel.Page? {
        let page: IslandModel.Page?
        if AgentStore.shared.headline?.status.needsAnswer == true { page = .claude }
        else if MeetingWatch.isSoon { page = .today }
        else if Prefs.shared.isOn(.downloads) && Downloads.shared.running != nil { page = .downloads }
        else if StowModel.shared.busy { page = .files }
        else if TodayStore.shared.focusRunning { page = .today }
        else if NowPlaying.shared.isPlaying || QuickTimer.shared.running { page = .home }
        else { page = nil }
        guard let page, IslandModel.Page.available.contains(page) else { return nil }
        return page
    }

    // MARK: Open and close

    /// `keyboard`: opened by a hot key. The panel then takes key status (without activating
    /// Vibrant+), so ⌘1–5, Esc, Tab and the card shortcuts work right away.
    func open(page: IslandModel.Page? = nil, sticky: Bool = false, keyboard: Bool = false) {
        // Without a panel there is nothing to show. An event (a request, a reminder) must never
        // leave the island "open" in a state the next start would inherit.
        guard panel != nil else { return }
        closeTask?.cancel()
        if let page { model.page = page }
        model.sticky = model.sticky || sticky
        if keyboard { panel?.makeKey() }
        hoverTask?.cancel()
        hoverTask = nil
        guard !model.isOpen else { return }
        if let screen { measureNotch(screen) }   // display mode may have changed
        // Fluid opening: the whole island starts a little smaller and grows to size with the spring.
        withTransaction(Transaction(animation: nil)) { model.growing = true }
        model.isOpen = true
        model.near = false
        DispatchQueue.main.async { withAnimation(Motion.respecting(Motion.island)) { self.model.growing = false } }
        updateMouseThrough()
        if let screen, let panel { ScrimController.shared.show(on: screen, below: panel) }
        SystemStats.shared.setLive(true)
        Shelf.shared.prune()
        // Live data greets you fresh: weather and AI usage reload when they are older than a minute.
        WeatherService.shared.refreshIfStale()
        UsageStore.shared.refreshIfStale()
    }

    func close() {
        guard model.isOpen else { return }
        ScrimController.shared.hide()
        Assistant.shared.endConversation()
        withAnimation(Motion.respecting(Motion.islandClose)) {
            model.isOpen = false
            model.dragging = false
            model.arranging = false
            model.hoveredPage = nil
        }
        MirrorCamera.shared.stopIfUnused()
        model.sticky = false
        SystemStats.shared.setLive(false)
        panel?.ignoresMouseEvents = true
        panel?.resignKey()
        closeTask?.cancel()
    }

    func toggle(keyboard: Bool = false) { model.isOpen ? close() : open(keyboard: keyboard) }

    /// The reason the island opened is gone (a request was answered or expired, a card was put
    /// away). It folds away, but only if nothing else still wants the person. Someone still
    /// reading it keeps it open; it then folds away as soon as the mouse leaves.
    func releaseStickyIfIdle() {
        guard model.isOpen, model.sticky else { return }
        guard AgentStore.shared.pending.isEmpty, TodayStore.shared.due.isEmpty, !AppUpdater.shared.offer,
              ScreenshotShelf.shared.latest == nil, StowModel.shared.isEmpty,
              !(Assistant.shared.visible && Prefs.shared.isOn(.assistant)) else { return }
        if pointerIsInside {
            model.sticky = false
            return
        }
        close()
    }

    // MARK: Mouse

    private func installMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        if let g = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] e in
            let type = e.type
            MainActor.assumeIsolated { self?.handle(type, global: true) }
        }) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] e in
            let type = e.type
            MainActor.assumeIsolated { self?.handle(type, global: false) }
            return e
        }) { monitors.append(l) }
        if let w = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] e in
            MainActor.assumeIsolated { self?.handleScroll(e) }
            return e
        }) { monitors.append(w) }
        // ← and → walk through the pages. A local monitor sees the keys once the island has the keyboard
        // (click, shortcut); a global one reacts while the pointer rests on the open island (it needs
        // the Accessibility permission, and cannot swallow the key).
        if let k = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
            let code = e.keyCode, flags = e.modifierFlags
            let used = MainActor.assumeIsolated { self?.handleArrow(code, flags, global: false) == true }
            return used ? nil : e
        }) { monitors.append(k) }
        if let g = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
            let code = e.keyCode, flags = e.modifierFlags
            MainActor.assumeIsolated { _ = self?.handleArrow(code, flags, global: true) }
        }) { monitors.append(g) }
    }

    /// Switches the page for ← (123) and → (124). Returns true when the key was used.
    private func handleArrow(_ code: UInt16, _ flags: NSEvent.ModifierFlags, global: Bool) -> Bool {
        guard model.isOpen, !model.arranging, code == 123 || code == 124,
              flags.intersection([.command, .option, .control, .shift]).isEmpty else { return false }
        if global {
            guard pointerIsInside else { return false }
        } else {
            guard panel?.isKeyWindow == true, !(panel?.firstResponder is NSText) else { return false }
        }
        let pages = IslandModel.Page.available
        guard let index = pages.firstIndex(of: model.page) else { return false }
        let target = index + (code == 124 ? 1 : -1)
        guard pages.indices.contains(target) else { return false }
        withAnimation(Motion.respecting(Motion.page)) { model.page = pages[target] }
        return true
    }

    /// Where the mascot sits in screen coordinates, so its eyes can look at the mouse.
    func mascotAnchor(open: Bool, dx: Double = -24, dy: Double = 30) -> CGPoint {
        guard let screen else { return .zero }
        if open {
            return CGPoint(x: screen.frame.midX + model.openWidth / 2 + dx - PulsMascot.size.width / 2,
                           y: screen.frame.maxY - model.openHeight - dy + PulsMascot.size.height / 2)
        }
        return CGPoint(x: screen.frame.midX, y: screen.frame.maxY - model.notchSize.height - PulsMascot.size.height / 2)
    }

    /// A two-finger swipe sideways past the end of a page's strip goes to the neighbouring page.
    /// One page per gesture; mouse wheels (no gesture phase) never switch. The axes are counted apart:
    /// a swipe is one or the other, never a little of both added up.
    private var swipeX: CGFloat = 0
    private var swipeY: CGFloat = 0
    private var swipeDone = false
    /// The gesture began over content that scrolls up and down: then it scrolls, and never closes the island.
    private var swipeScrollsContent = false
    /// Whether the gesture started at an end of the strip, per direction (right, left).
    private var swipeFromLeading = false
    private var swipeFromTrailing = false

    private func handleScroll(_ e: NSEvent) {
        guard model.isOpen, !model.dragging, let panel, e.window === panel else { return }
        if e.phase.contains(.began) || e.phase.contains(.mayBegin) {
            swipeX = 0
            swipeY = 0
            swipeDone = false
            swipeFromLeading = model.atLeadingEdge
            swipeFromTrailing = model.atTrailingEdge
            swipeScrollsContent = panel.contentView.map { Self.scrollsVertically(at: e.locationInWindow, in: $0) } ?? false
        }
        guard !e.phase.isEmpty, !swipeDone else { return }
        if abs(e.scrollingDeltaY) > abs(e.scrollingDeltaX) {
            swipeY += e.scrollingDeltaY
            // A waiting request is answered, not swiped away.
            if swipeY < -80, abs(swipeY) > abs(swipeX), !swipeScrollsContent, AgentStore.shared.pending.isEmpty {
                swipeDone = true
                close()
            }
            return
        }
        guard abs(e.scrollingDeltaX) > abs(e.scrollingDeltaY) else { return }
        swipeX += e.scrollingDeltaX
        guard abs(swipeX) > abs(swipeY) else { return }
        let pages = IslandModel.Page.available
        guard let index = pages.firstIndex(of: model.page) else { return }
        // Fingers moving right pull the previous page in, moving left the next one.
        let target: Int
        if swipeX > 60, swipeFromLeading { target = index - 1 }
        else if swipeX < -60, swipeFromTrailing { target = index + 1 }
        else { return }
        guard pages.indices.contains(target) else { return }
        swipeDone = true
        model.atLeadingEdge = true
        model.atTrailingEdge = true
        withAnimation(Motion.respecting(Motion.page)) { model.page = pages[target] }
    }

    /// True when a list or text under the point (window coordinates) has more above or below.
    static func scrollsVertically(at point: CGPoint, in view: NSView) -> Bool {
        if let scroll = view as? NSScrollView, let document = scroll.documentView,
           scroll.convert(scroll.bounds, to: nil).contains(point),
           document.frame.height > scroll.contentView.bounds.height + 1 {
            return true
        }
        return view.subviews.contains { !$0.isHidden && scrollsVertically(at: point, in: $0) }
    }

    private func handle(_ type: NSEvent.EventType, global: Bool) {
        let p = NSEvent.mouseLocation
        defer { updateMouseThrough() }
        switch type {
        case .mouseMoved:
            if !model.isOpen {
                followMouse(p)
                let near = nearRect.contains(p) && NSEvent.pressedMouseButtons == 0 && !menuIsOpen
                if near != model.near {
                    withAnimation(Motion.respecting(Motion.quick)) { model.near = near }
                }
                guard Prefs.shared.openOnHover, NSEvent.pressedMouseButtons == 0, isOnTrigger(p), !menuIsOpen else {
                    hoverTask?.cancel()
                    hoverTask = nil
                    return
                }
                // At the very top, on the notch: open after a moment of rest, so a mouse that only
                // slides along the top edge past the notch opens nothing.
                guard hoverTask == nil else { return }
                hoverTask = Task {
                    try? await Task.sleep(for: .milliseconds(NotchGeometry.triggerDwellMilliseconds))
                    guard !Task.isCancelled else { return }
                    self.hoverTask = nil
                    guard !self.model.isOpen, self.isOnTrigger(NSEvent.mouseLocation), !self.menuIsOpen else { return }
                    withAnimation(Motion.respecting(Motion.island)) { self.open() }
                    if Prefs.shared.glowOnHover { GlowCenter.shared.fire() }
                }
            } else if !model.sticky && !model.dragging {
                if openRect.contains(p) { closeTask?.cancel(); return }
                closeTask?.cancel()
                closeTask = Task {
                    // A short grace so a quick overshoot past the edge does not fold it away.
                    // Not while a button is held: something is being dragged out of the island.
                    try? await Task.sleep(for: .milliseconds(NotchGeometry.closeGraceMilliseconds))
                    guard !Task.isCancelled, !self.openRect.contains(NSEvent.mouseLocation), !self.model.dragging,
                          NSEvent.pressedMouseButtons == 0,
                          !self.model.sticky, self.panel?.isKeyWindow != true else { return }
                    self.close()
                }
            }
        case .leftMouseDragged:
            guard global, !model.dragging, !menuIsOpen, notchRect.insetBy(dx: -40, dy: -30).contains(p) else { return }
            let pb = NSPasteboard(name: .drag)
            // The drag pasteboard keeps old contents: only a drag that filled it after the mouse
            // went down counts, and a browser tab (web URL) is not a file.
            guard pb.changeCount != mouseDownPasteboardCount,
                  pb.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]),
                  !((pb.readObjects(forClasses: [NSURL.self]) as? [URL]) ?? []).contains(where: { !$0.isFileURL })
            else { return }
            withAnimation(Motion.respecting(Motion.island)) {
                model.dragging = true
                open()
            }
        case .leftMouseUp:
            if model.dragging {
                Task {
                    // Give the drop a moment to land before folding the zones away.
                    try? await Task.sleep(for: .milliseconds(300))
                    withAnimation(Motion.respecting(Motion.fade)) { self.model.dragging = false }
                }
            }
        case .leftMouseDown:
            if global { mouseDownPasteboardCount = NSPasteboard(name: .drag).changeCount }
            if model.isOpen {
                // A click anywhere else folds the island back.
                if global, !openRect.contains(p) { close() }
            } else if closedRect.contains(p), !menuIsOpen {
                // A click on the notch, on a wing or on the pill opens the island, on the page the
                // wing showed. A menu that is open is dismissed first and stays a menu click.
                withAnimation(Motion.respecting(Motion.island)) { open(page: wingPage(), keyboard: true) }
            }
        default: break
        }
    }
}

/// Watches for a meeting that starts within five minutes.
enum MeetingWatch {
    @MainActor static var isSoon: Bool {
        guard Prefs.shared.showMeetingCountdown, let next = CalendarService.shared.next else { return false }
        let t = next.start.timeIntervalSinceNow
        return t <= 5 * 60 && t > -60
    }
}
