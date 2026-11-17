// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import VibrantPlusKit
import AppKit
import Observation
import ServiceManagement
import SwiftUI

/// Starts and stops each module as its switch changes. A module that is off runs nothing.
final class Coordinator {
    static let shared = Coordinator()
    private let prefs = Prefs.shared
    private(set) var running: Set<Module> = []
    private var activationObserver: NSObjectProtocol?

    func start() {
        Paths.ensureDataDirectory()
        wireCallbacks()
        wireHotKeys()
        apply()
        observe()
        activationObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                guard Prefs.shared.onboarded else { return }
                if Prefs.shared.isOn(.snippets) { SnippetService.shared.start() }
                if Prefs.shared.isOn(.voice) { VoiceController.shared.start() }
                if Prefs.shared.isOn(.keys) { KeyMonitor.shared.update() }
                WindowTools.shared.refreshPermissions()
                InputTools.shared.update()
            }
        }
        ThemeController.shared.apply(prefs.theme, switchMac: false)
        if !prefs.onboarded { Windows.show(.welcome) }
        else if prefs.appAutoUpdate {
            Task {
                try? await Task.sleep(for: .seconds(12))
                AppUpdater.shared.check(automatic: true)
            }
        }
    }

    /// Re-applies whenever a module switch changes.
    private func observe() {
        withObservationTracking {
            _ = prefs.onboarded
            _ = WindowToolPreferences.shared.greenButtonMaximizes
            _ = WindowToolPreferences.shared.modifierDragEnabled
            _ = prefs.autoCleanLinks
            _ = prefs.inputRules
            _ = prefs.modules
            _ = prefs.tilesOn
            _ = prefs.keySounds
            _ = prefs.showKeys
            _ = prefs.dialLeftEdge
        } onChange: {
            Task { @MainActor in
                Coordinator.shared.apply()
                Coordinator.shared.observe()
            }
        }
    }

    func apply() {
        guard prefs.onboarded else { return }
        for m in Module.allCases {
            let want = prefs.isOn(m)
            if want && !running.contains(m) { start(m); running.insert(m) }
            else if !want && running.contains(m) { stop(m); running.remove(m) }
        }
        // Island services follow the tiles that are on.
        if prefs.isOn(.island) { updateTileServices() }
        InputTools.shared.update()
        LinkCleanerService.shared.update()
        syncClipboard()
        syncCalendar()
        if prefs.isOn(.keys) { KeyMonitor.shared.update() }
        if prefs.isOn(.dial) { DialController.shared.relayout() }
        HotKeys.shared.refresh()
    }

    private func start(_ m: Module) {
        switch m {
        case .island:
            IslandController.shared.start()
            SystemStats.shared.startSlow()
            PulsiSounds.shared.prepare()
            PulsiWake.shared.update()
            updateTileServices()
        case .agent: AgentStore.shared.start()
        case .today:
            TodayStore.shared.start()
        case .stow: break
        case .rowline: WindowManager.shared.start()
        case .dial: DialController.shared.start()
        case .voice: VoiceController.shared.start()
        case .keys: KeyMonitor.shared.update()
        case .appGrid: break // only the hot key
        case .assistant: break // runs on demand
        case .screenshots: ScreenshotShelf.shared.start()
        case .downloads: break // runs on demand
        case .snippets: SnippetService.shared.start()
        case .devBar: DevStatus.shared.start()
        case .windowTools: WindowTools.shared.start()
        case .systemMonitor: ExtendedSystemMonitor.shared.start()
        case .keepAwakeRules: KeepAwakeRulesService.shared.start()
        case .quickTools: QuickToolsController.shared.start()
        case .cleaner, .uninstaller, .homebrew, .appUpdates, .diskInstaller, .cleaning: break
        case .autoQuit: AutoQuit.shared.start()
        case .mouse, .finder, .quitProtection, .audioDevices, .ocr, .scratchpad, .processes: break
        case .clipboard, .links: break
        }
    }

    private func stop(_ m: Module) {
        switch m {
        case .island:
            IslandController.shared.stop()
            ShelfPalette.shared.close()
            PulsiWake.shared.stop()
            PulsiSounds.shared.shutdown()
            SystemStats.shared.stopSlow()
            NowPlaying.shared.stop()
            WeatherService.shared.stop()
            RecentApps.shared.stop()
            UsageStore.shared.stop()
            RemindersService.shared.stop()
        case .agent: AgentStore.shared.stop()
        case .today:
            TodayStore.shared.stop()
        case .stow: break
        case .rowline: WindowManager.shared.stop()
        case .dial: DialController.shared.stop()
        case .voice: VoiceController.shared.stop()
        case .keys: KeyMonitor.shared.stop()
        case .appGrid: AppGridController.shared.close()
        case .assistant: Assistant.shared.newConversation(); Assistant.shared.visible = false
        case .screenshots: ScreenshotShelf.shared.stop()
        case .downloads: Downloads.shared.cancelAll()
        case .snippets: SnippetService.shared.stop()
        case .devBar: DevStatus.shared.stop()
        case .windowTools: WindowTools.shared.stop()
        case .systemMonitor: ExtendedSystemMonitor.shared.stop()
        case .keepAwakeRules: KeepAwakeRulesService.shared.stop()
        case .quickTools: QuickToolsController.shared.stop()
        case .cleaning: CleaningMode.shared.stop()
        case .cleaner, .uninstaller, .homebrew, .appUpdates, .diskInstaller: break
        case .autoQuit: AutoQuit.shared.stop()
        case .scratchpad: Scratchpad.shared.save(); Windows.close(.scratchpad)
        case .mouse, .finder, .quitProtection, .audioDevices, .ocr, .processes: break
        case .clipboard: break
        case .links: break
        }
    }

    /// Each tile's service runs only while the tile is on.
    private func updateTileServices() {
        let on = prefs.tilesOn
        on.contains(.nowPlaying) ? NowPlaying.shared.start() : NowPlaying.shared.stop()
        on.contains(.weather) ? WeatherService.shared.start() : WeatherService.shared.stop()
        on.contains(.recentApps) ? RecentApps.shared.start() : RecentApps.shared.stop()
        on.contains(.usage) ? UsageStore.shared.start() : UsageStore.shared.stop()
        on.contains(.reminders) ? RemindersService.shared.start() : RemindersService.shared.stop()
    }

    /// The calendar feeds three places: the next-event tile, the Today page and the meeting wing
    /// beside the notch. It runs while at least one of them is on, and stops as soon as none is.
    private func syncCalendar() {
        if prefs.isOn(.today) || (prefs.isOn(.island) && prefs.tilesOn.contains(.nextEvent)) {
            CalendarService.shared.start()
        } else {
            CalendarService.shared.stop()
        }
    }

    private func syncClipboard() {
        let wanted = prefs.isOn(.clipboard) || (prefs.isOn(.island) && prefs.tilesOn.contains(.clipboard))
        wanted ? ClipboardHistory.shared.start() : ClipboardHistory.shared.stop()
        if !wanted { Windows.close(.clipboard) }
    }

    func stopAll() {
        for m in running { stop(m) }
        running = []
        CalendarService.shared.stop()
        ClipboardHistory.shared.stop()
        InputTools.shared.stop()
        LinkCleanerService.shared.stop()
        SystemControls.shared.setKeepAwake(false)
        TodayStore.shared.saveNow()
    }

    private func wireCallbacks() {
        let island = IslandController.shared
        AgentStore.shared.onAttention = {
            // Takes key status so ⌘↩ and Esc work right away, as the announcement says.
            withAnimation(Motion.respecting(Motion.island)) { island.open(sticky: true, keyboard: true) }
        }
        AgentStore.shared.onPendingEmpty = {
            // The last request is answered or expired: what it opened folds away, unless something
            // else still wants the person or the mouse rests on the island.
            island.releaseStickyIfIdle()
        }
        TodayStore.shared.onReminder = { _ in
            withAnimation(Motion.respecting(Motion.island)) { island.open(sticky: true) }
        }
        TodayStore.shared.onFocusStarted = { FocusMode.shared.began() }
        TodayStore.shared.onFocusEnded = { FocusMode.shared.ended() }
        TodayStore.shared.onFocusDone = {
            IslandModel.shared.show(Toast(symbol: "checkmark.circle", text: "Fokus geschafft"), seconds: 6)
            PulsiVoice.shared.say("Fokus ist geschafft.")
        }
        QuickTimer.shared.onDone = {
            IslandModel.shared.show(Toast(symbol: "timer", text: "Timer abgelaufen", warm: true), seconds: 8)
            PulsiVoice.shared.say("Der Timer ist abgelaufen.")
        }
        SystemStats.shared.onNewAlert = { alert in
            IslandModel.shared.show(Toast(symbol: alert.symbol, text: alert.text, warm: true), seconds: 6)
        }
    }

    private func wireHotKeys() {
        let h = HotKeys.shared
        let wm = WindowManager.shared
        h.setHandler(.toggleIsland) {
            withAnimation(Motion.respecting(Motion.island)) { IslandController.shared.toggle(keyboard: true) }
        }
        h.setHandler(.rowArrange) { wm.arrangeRow() }
        h.setHandler(.rowNext) { wm.focusNeighbour(1) }
        h.setHandler(.rowPrevious) { wm.focusNeighbour(-1) }
        h.setHandler(.rowWidth) { wm.cycleWidth() }
        h.setHandler(.snapLeft) { wm.snapFocused(.left) }
        h.setHandler(.snapRight) { wm.snapFocused(.right) }
        h.setHandler(.snapLeftTwoThirds) { wm.snapFocused(.leftTwoThirds) }
        h.setHandler(.snapRightTwoThirds) { wm.snapFocused(.rightTwoThirds) }
        h.setHandler(.snapFull) { wm.snapFocused(.full) }
        h.setHandler(.snapCenter) { wm.snapFocused(.center) }
        h.setHandler(.grid) { wm.arrangeGrid() }
        h.setHandler(.stack) { wm.arrangeStack() }
        h.setHandler(.otherDisplay) { wm.moveFocusedToOtherDisplay() }
        h.setHandler(.appGrid) { AppGridController.shared.toggle() }
        h.setHandler(.clipboard) { ClipboardHistory.shared.start(); Windows.show(.clipboard) }
        h.setHandler(.windowSwitcher) { WindowTools.shared.openSwitcher() }
        h.setHandler(.commandBar) { QuickToolsController.shared.open(.command) }
        h.setHandler(.toolPalette) { QuickToolsController.shared.open(.palette) }
        h.setHandler(.shelfPalette) { ShelfPalette.shared.toggle() }
        for mode in CaptureMode.allCases {
            h.setHandler(mode.hotKey) { Task { await ScreenCapture.shared.capture(mode) } }
        }
    }

    // MARK: Launch at login

    static var launchesAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    static func setLaunchAtLogin(_ on: Bool) -> String? {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return "Anmeldeobjekt konnte nicht geändert werden: \(error.localizedDescription)"
        }
    }
}
