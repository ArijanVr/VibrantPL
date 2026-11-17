// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// One entry of the clipboard history: text, or a small image kept in memory only.
public struct ClipItem: Codable, Sendable, Identifiable, Equatable {
    public enum Kind: String, Codable, Sendable { case text, image, file }

    public var id: UUID
    public var kind: Kind
    /// The text, or a short description for images ("Bild 640 × 480").
    public var text: String
    public var date: Date
    public var pinned: Bool

    public init(kind: Kind = .text, text: String, date: Date = .now, pinned: Bool = false) {
        id = UUID()
        self.kind = kind
        self.text = text
        self.date = date
        self.pinned = pinned
    }

    /// First line, for lists.
    public var preview: String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        return line.count > 120 ? String(line.prefix(119)) + "…" : line
    }
}

/// The history: newest first, pinned entries stay, search, limits. Pure logic.
public struct ClipList: Sendable, Equatable {
    public static let maxUnpinned = 50
    public static let maxTextLength = 20_000

    public private(set) var items: [ClipItem] = []

    public init(items: [ClipItem] = []) { self.items = items }

    /// Adds a copied text. The same text moves to the top (keeping its pin).
    @discardableResult
    public mutating func add(text raw: String, now: Date = .now) -> ClipItem? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let clipped = String(text.prefix(Self.maxTextLength))
        var pinned = false
        if let i = items.firstIndex(where: { $0.kind == .text && $0.text == clipped }) {
            pinned = items[i].pinned
            items.remove(at: i)
        }
        let item = ClipItem(text: clipped, date: now, pinned: pinned)
        items.insert(item, at: 0)
        prune()
        return item
    }

    @discardableResult
    public mutating func add(image description: String, now: Date = .now) -> ClipItem {
        let item = ClipItem(kind: .image, text: description, date: now)
        items.insert(item, at: 0)
        prune()
        return item
    }

    @discardableResult
    public mutating func add(files paths: [String], now: Date = .now) -> ClipItem? {
        let paths = paths.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !paths.isEmpty else { return nil }
        let text = paths.joined(separator: "\n")
        if let i = items.firstIndex(where: { $0.kind == .file && $0.text == text }) { items.remove(at: i) }
        let item = ClipItem(kind: .file, text: text, date: now)
        items.insert(item, at: 0)
        prune()
        return item
    }

    public mutating func togglePin(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].pinned.toggle()
    }

    public mutating func remove(_ id: UUID) { items.removeAll { $0.id == id } }

    /// Removes everything that is not pinned.
    public mutating func clearUnpinned() { items.removeAll { !$0.pinned } }

    public mutating func prune() {
        var unpinned = 0
        items = items.filter { item in
            if item.pinned { return true }
            unpinned += 1
            return unpinned <= Self.maxUnpinned
        }
    }

    /// Pinned first (newest first), then the rest; filtered by a case- and diacritic-insensitive search.
    public func visible(matching query: String) -> [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let hits = q.isEmpty ? items : items.filter { $0.text.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        return hits.filter(\.pinned) + hits.filter { !$0.pinned }
    }

    public var pinned: [ClipItem] { items.filter { $0.pinned && $0.kind == .text } }
}
