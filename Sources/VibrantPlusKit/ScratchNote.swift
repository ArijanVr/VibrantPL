// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
public struct ScratchNote: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var text: String
    public var modified: Date
    public init(id: UUID = UUID(), title: String = "Notiz", text: String = "", modified: Date = .now) {
        self.id = id; self.title = title; self.text = text; self.modified = modified
    }
}
