// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Observation
import SwiftUI

@Observable
final class CleaningMode {
    static let shared = CleaningMode()
    private(set) var active = false
    private(set) var deadline: Date?
    private(set) var message: String?
    @ObservationIgnored private var panels: [NSPanel] = []
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var escapes: [Date] = []

    func start() {
        guard !active, Prefs.shared.isOn(.cleaning), Permission.accessibilityTrusted else {
            message = "Zum Sperren der Tastatur zuerst Bedienungshilfen erlauben."; return
        }
        active = true
        InputTools.shared.update()
        guard InputTools.shared.isRunning else { active = false; message = "Eingabesicherung konnte nicht gestartet werden."; return }
        deadline = .now.addingTimeInterval(60); escapes = []
        for screen in NSScreen.screens {
            let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .black
            let host = NSHostingView(rootView: CleaningOverlay())
            host.sizingOptions = []
            panel.contentView = host
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        timer = Timer.repeating(every: 1) { _ in MainActor.assumeIsolated {
            if CleaningMode.shared.deadline.map({ $0 <= .now }) == true { CleaningMode.shared.stop() }
        } }
        message = nil
    }
    func stop() {
        active = false; deadline = nil; timer?.invalidate(); timer = nil; escapes = []
        for panel in panels { panel.close() }; panels = []
        InputTools.shared.update()
    }
    func consumes(_ type: CGEventType, _ event: CGEvent) -> Bool {
        guard active else { return false }
        if type == .keyDown, event.getIntegerValueField(.keyboardEventKeycode) == 53,
           event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            escapes = escapes.filter { Date.now.timeIntervalSince($0) < 2 }
            escapes.append(.now)
            if escapes.count >= 3 { stop() }
        }
        return type == .keyDown || type == .keyUp || type == .flagsChanged
    }
}

private struct CleaningOverlay: View {
    var body: some View {
        VStack(spacing: Space.lg) {
            Image(systemName: "sparkles").font(.largeTitle)
            Text("Tastatur reinigen").font(.title2)
            Text("Dreimal Esc drücken oder unten beenden. Nach 60 Sekunden wird die Tastatur automatisch freigegeben.")
                .multilineTextAlignment(.center)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text("\(max(0, Int(CleaningMode.shared.deadline?.timeIntervalSince(context.date) ?? 0))) Sekunden")
                    .monospacedDigit()
            }
            Button("Reinigungsmodus beenden") { CleaningMode.shared.stop() }.buttonStyle(.borderedProminent)
        }.padding(Space.xxl).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(IslandPalette.notch.background).foregroundStyle(IslandPalette.notch.primaryText)
    }
}

struct CleaningModeSettings: View {
    @State private var prefs = Prefs.shared
    var body: some View {
        Section { PermissionRow(permission: .accessibility) }
        Section("Tastatur reinigen") {
            Button("Für 60 Sekunden starten") { CleaningMode.shared.start() }.disabled(!prefs.isOn(.cleaning))
            Text("Die Tastatur wird vorübergehend blockiert, alle Bildschirme zeigen eine schwarze Fläche. Dreimal Esc oder der sichtbare Beenden-Knopf gibt sie sofort wieder frei. Die Maus bleibt bedienbar.").foregroundStyle(.secondary)
            if let message = CleaningMode.shared.message { Text(message).foregroundStyle(.secondary) }
        }
    }
}
