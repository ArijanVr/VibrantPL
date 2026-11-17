// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import VibrantPlusKit

/// Island tile «Besprechung»: write a call down (your voice and the sound of the Mac) into a note.
struct MeetingTile: View {
    private var meeting = MeetingService.shared

    var body: some View {
        IslandCard(width: Metrics.wideTileWidth - 64) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack {
                    CardHeader(title: "Besprechung", symbol: "text.bubble")
                    Spacer()
                    if meeting.isRunning, let start = meeting.started {
                        Text(start, style: .timer).font(TypeStyle.islandMicroNumber).foregroundStyle(IslandColor.warm)
                    }
                }
                if meeting.isRunning {
                    ForEach(meeting.lines.suffix(2), id: \.offset) { l in
                        Text("\(l.speaker): \(l.text)").font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText).lineLimit(2)
                    }
                    if !meeting.live.isEmpty {
                        Text(meeting.live).font(TypeStyle.islandCaption).foregroundStyle(IslandColor.tertiaryText).lineLimit(2)
                    }
                } else if let app = meeting.runningMeetingApp {
                    Text("\(app) läuft. Mitschreiben?").font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                } else {
                    Text("Schreibt Gespräche mit, auch Teams und Zoom. Sag allen Beteiligten Bescheid.")
                        .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.tertiaryText).lineLimit(3)
                }
                if let m = meeting.message {
                    Text(m).font(TypeStyle.islandMicro).foregroundStyle(IslandColor.warm).lineLimit(2)
                }
                Spacer(minLength: 0)
                HStack(spacing: Space.xs) {
                    IslandPillButton(title: meeting.isRunning ? "Beenden" : (meeting.starting ? "Startet…" : "Mitschreiben"),
                                     kind: meeting.isRunning ? .warm : .primary) { meeting.toggle() }
                    if let file = meeting.savedFile, !meeting.isRunning {
                        IslandPillButton(title: "Zeigen", kind: .secondary) { NSWorkspace.shared.activateFileViewerSelecting([file]) }
                    }
                }
            }
        }
    }
}
