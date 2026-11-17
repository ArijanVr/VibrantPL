// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import CoreGraphics
import VibrantPlusKit

extension CaptureMode {
    var title: String {
        switch self {
        case .screen: "Ganzer Bildschirm"
        case .window: "Fenster"
        case .area: "Ausschnitt"
        }
    }

    var symbol: String {
        switch self {
        case .screen: "display"
        case .window: "macwindow"
        case .area: "rectangle.dashed"
        }
    }

    var hotKey: HotKeyAction {
        switch self {
        case .screen: .captureScreen
        case .window: .captureWindow
        case .area: .captureArea
        }
    }
}

/// Takes screenshots with macOS's own `screencapture` tool: the person picks the window or drags the area
/// with the system's crosshair, Esc cancels. The picture lands where macOS saves screenshots, in the
/// clipboard, and in the island's screenshot card.
@Observable
final class ScreenCapture {
    static let shared = ScreenCapture()

    enum Outcome: Equatable {
        case saved(URL)
        case cancelled
        case notAllowed
        case failed
    }

    private(set) var running = false
    @ObservationIgnored private var askedThisRun = false

    /// True when Vibrant+ may record the screen. Without it, macOS hands over only the wallpaper.
    static var allowed: Bool { CGPreflightScreenCaptureAccess() }

    /// Asks once (macOS shows its prompt the first time and adds Vibrant+ to the list in System Settings).
    @discardableResult
    static func requestAccess() -> Bool { CGRequestScreenCaptureAccess() }

    /// Clears Vibrant+'s own Screen Recording entry and asks again. Needed when the entry was saved for a
    /// differently signed copy: System Settings then shows the switch on, but macOS still refuses this copy,
    /// and switching it off and on keeps the old signature.
    static func resetAccess() async -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let r = await Run.async("/usr/bin/tccutil", ["reset", "ScreenCapture", id])
        requestAccess()
        Permission.screenRecording.openSettings()
        return r.status == 0
    }

    /// macOS reads the permission when the app starts: quit, then open again.
    static func relaunch() { AppRelaunch.now() }

    /// Screenshots always go to Downloads, whatever macOS has set for ⇧⌘5.
    static var folder: URL { Downloads.shared.folder }

    /// Takes a screenshot. Shows the result or a clear hint in the island.
    @discardableResult
    func capture(_ mode: CaptureMode) async -> Outcome {
        guard !running else { return .cancelled }
        guard Self.allowed else {
            // The system prompt only once per run; after that a hint, not a new prompt each time.
            if !askedThisRun {
                askedThisRun = true
                Self.requestAccess()
            }
            showMissingPermission()
            return .notAllowed
        }
        running = true
        defer { running = false }

        // The island must not be in the picture.
        if IslandController.shared.model.isOpen {
            IslandController.shared.close()
            try? await Task.sleep(for: .milliseconds(350))
        }

        let url = CapturePlan.freeURL(in: Self.folder, name: CapturePlan.fileName(at: .now))
        let args = CapturePlan.arguments(mode, display: mode == .screen ? Self.displayUnderPointer() : nil, output: url.path)
        // Interactive modes wait for the person; ten minutes is plenty.
        let result = await Run.async(CapturePlan.tool, args, timeout: 600)

        guard result.status == 0, FileManager.default.fileExists(atPath: url.path) else {
            // Esc ends screencapture without a file: nothing to say.
            return result.status == 0 || result.status == 1 ? .cancelled : fail()
        }
        copyToClipboard(url)
        if Prefs.shared.isOn(.island) {
            ScreenshotShelf.shared.show(url, copied: true)
        }
        return .saved(url)
    }

    private func fail() -> Outcome {
        IslandModel.shared.show(Toast(symbol: "exclamationmark.triangle", text: "Bildschirmfoto fehlgeschlagen", warm: true))
        return .failed
    }

    private func copyToClipboard(_ url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
    }

    private func showMissingPermission() {
        IslandModel.shared.show(Toast(symbol: "lock.shield",
                                      text: "Bildschirmaufnahme fehlt. Einstellungen › Bildschirmfotos › «Erlaubnis neu einrichten»",
                                      warm: true), seconds: 8)
        if Prefs.shared.isOn(.island) { IslandController.shared.open(sticky: false) }
        Permission.screenRecording.openSettings()
    }

    /// 1-based index of the display under the pointer, in screencapture's order (the active display list).
    static func displayUnderPointer() -> Int? {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }),
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return nil }
        return ids.firstIndex(of: CGDirectDisplayID(number.uint32Value)).map { $0 + 1 }
    }
}
