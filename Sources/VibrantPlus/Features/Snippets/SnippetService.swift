// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Observation
import VibrantPlusKit

/// Text snippets: type ";adr" in any app and it becomes your address.
/// Needs Accessibility (to see keys and to type). Secure text fields (passwords) never
/// deliver keys to other apps, so nothing is seen there. The key buffer is short, lives in
/// memory, and is cleared on every non-text key.
@Observable
final class SnippetService {
    static let shared = SnippetService()

    private(set) var snippets: [Snippet] = []
    @ObservationIgnored private var matcher = SnippetMatcher()
    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private var busyUntil = Date.distantPast
    @ObservationIgnored private let file = JSONFile<[Snippet]>(url: Paths.snippets)
    var message: String?

    func start() {
        if snippets.isEmpty { snippets = file.load() ?? [] }
        matcher.snippets = snippets
        guard monitor == nil else { return }
        guard Permission.accessibilityTrusted else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] e in
            let type = e.type, flags = e.modifierFlags
            let isKey = type == .keyDown
            let code = isKey ? e.keyCode : 0, chars = isKey ? (e.characters ?? "") : ""
            MainActor.assumeIsolated { self?.handle(type, code, flags, chars) }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        matcher.reset()
    }

    private func handle(_ type: NSEvent.EventType, _ code: UInt16, _ flags: NSEvent.ModifierFlags, _ chars: String) {
        // Our own synthetic backspaces and paste.
        guard Date.now > busyUntil else { return }
        if type != .keyDown { matcher.reset(); return }
        if !flags.intersection([.command, .control, .option]).isEmpty { matcher.reset(); return }
        if code == 51 { matcher.backspace(); return }
        // Return, Tab, Escape, arrows, function keys: the cursor may have moved.
        let nonText: Set<UInt16> = [36, 48, 53, 76, 117, 115, 119, 116, 121, 123, 124, 125, 126]
        if nonText.contains(code) || chars.isEmpty || chars.unicodeScalars.contains(where: { $0.value < 32 || ($0.value >= 0xF700 && $0.value <= 0xF8FF) }) {
            matcher.reset()
            return
        }
        if let hit = matcher.feed(chars) { expand(hit) }
    }

    private func expand(_ snippet: Snippet) {
        guard Permission.accessibilityTrusted else { return }
        busyUntil = Date.now.addingTimeInterval(0.8)
        let src = CGEventSource(stateID: .combinedSessionState)
        for _ in 0..<snippet.trigger.count {
            CGEvent(keyboardEventSource: src, virtualKey: 51, keyDown: true)?.post(tap: .cgAnnotatedSessionEventTap)
            CGEvent(keyboardEventSource: src, virtualKey: 51, keyDown: false)?.post(tap: .cgAnnotatedSessionEventTap)
        }
        VoiceController.type(SnippetRules.expand(snippet.text))
    }

    // MARK: Editing

    @discardableResult
    func add(trigger raw: String, text: String) -> String? {
        let trigger = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard SnippetRules.isValid(trigger: trigger) else { return "Das Kürzel beginnt mit «;» und hat mindestens einen Buchstaben, ohne Leerzeichen." }
        if let clash = SnippetRules.conflict(trigger, with: snippets) { return "Kollidiert mit «\(clash)»: ein Kürzel darf nicht der Anfang eines anderen sein." }
        guard !text.isEmpty else { return "Der Text ist leer." }
        snippets.append(Snippet(trigger: trigger, text: text))
        save()
        return nil
    }

    func remove(_ s: Snippet) {
        snippets.removeAll { $0.id == s.id }
        save()
    }

    private func save() {
        matcher.snippets = snippets
        SaveReport.attempt("Textbausteine") { try file.save(snippets) }
    }
}
