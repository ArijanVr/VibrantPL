// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import VibrantPlusKit

/// Island page «Claude»: every running session at a glance, its latest steps and what it changed.
struct ClaudePage: View {
    private var agent = AgentStore.shared

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            if !agent.hooksInstalled {
                IslandCard(width: Metrics.islandContentWidth, height: 108) {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        CardHeader(title: "Claude Code", symbol: "sparkles")
                        Text("Noch nicht mit Claude Code verbunden.").font(TypeStyle.islandBody).foregroundStyle(IslandColor.secondaryText)
                        IslandPillButton(title: "Verbinden", kind: .primary) { agent.installHooks() }
                    }
                }
            } else if agent.sortedSessions.isEmpty {
                IslandCard(width: Metrics.islandContentWidth, height: 108) {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        CardHeader(title: "Claude Code", symbol: "sparkles")
                        Text("Keine Sitzung offen. Starte Claude Code in einem Terminal, es erscheint hier.")
                            .font(TypeStyle.islandBody).foregroundStyle(IslandColor.secondaryText)
                        summary
                    }
                }
            } else {
                let shown = Array(agent.sortedSessions.prefix(3))
                let hidden = agent.sortedSessions.count - shown.count
                ForEach(shown) { s in session(s, more: s.id == shown.last?.id ? hidden : 0) }
            }
        }
    }

    /// `more`: sessions that did not fit; the last card says so and links to the panel.
    private func session(_ s: AgentSession, more: Int = 0) -> some View {
        let count = min(3, max(1, agent.sortedSessions.count))
        let width = (Metrics.islandContentWidth - Space.sm * CGFloat(count - 1)) / CGFloat(count)
        return IslandCard(width: width, height: 172) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack {
                    AgentPulse(status: s.status)
                    Text(s.projectName).font(TypeStyle.islandTitle).lineLimit(1)
                    Spacer()
                    Text(statusText(s.status)).font(TypeStyle.islandLabel)
                        .foregroundStyle(s.status == .needsPermission || s.status == .asking ? IslandColor.warm : IslandColor.tertiaryText)
                }
                if !s.prompt.isEmpty {
                    Text(s.prompt).font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText).lineLimit(2)
                }
                Text(s.current).font(TypeStyle.islandBody.weight(.medium)).lineLimit(1)
                ForEach(s.steps.suffix(3).reversed()) { step in
                    Label(step.label, systemImage: step.symbol)
                        .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.tertiaryText).lineLimit(1)
                }
                Spacer(minLength: 0)
                HStack {
                    if !s.files.isEmpty { Label("\(s.files.count)", systemImage: "doc.text").help("Geänderte Dateien") }
                    if s.usage.total > 0 { Label(TokenUsage.format(s.usage.total), systemImage: "number").help("Token") }
                    Spacer()
                    Button(more > 0 ? "+\(more) weitere · Panel" : "Panel") { AppActions.openAgentPanel() }
                        .buttonStyle(.plain).foregroundStyle(IslandColor.accentText)
                        .help(more > 0 ? "\(more) weitere Sitzungen im Claude-Code-Panel" : "Claude-Code-Panel öffnen")
                }
                .font(TypeStyle.islandLabel).foregroundStyle(IslandColor.secondaryText)
            }
        }
    }

    private var summary: some View {
        let today = agent.history.filter { Calendar.current.isDateInToday($0.date) }
        return Text(today.isEmpty ? "Heute noch keine Antworten." :
                        "Heute: \(today.count) Antworten, \(TokenUsage.format(today.reduce(0) { $0 + $1.tokens })) Token")
            .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.tertiaryText)
    }

    private func statusText(_ s: AgentSession.Status) -> String {
        switch s {
        case .working: "arbeitet"
        case .needsPermission: "wartet auf dich"
        case .asking: "fragt"
        case .waiting: "fertig"
        case .ended: "beendet"
        }
    }
}

/// Island page «Ablage»: the shelf and the clipboard side by side, with search.
struct FilesPage: View {
    private var shelf = Shelf.shared
    private var clip = ClipboardHistory.shared
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if Prefs.shared.isOn(.screenshots) { CaptureStrip() }
            files
        }
    }

    private var files: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            ShelfTile()
            IslandCard(width: Metrics.islandContentWidth - (Metrics.wideTileWidth - 64) - Space.sm, height: Metrics.tileHeight) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack {
                        CardHeader(title: "Zwischenablage", symbol: "doc.on.clipboard")
                        Spacer()
                        Button("Alle") { Windows.show(.clipboard) }.buttonStyle(.plain)
                            .font(TypeStyle.islandLabel).foregroundStyle(IslandColor.accentText)
                    }
                    TextField("Suchen", text: $query)
                        .textFieldStyle(.plain).font(TypeStyle.islandCaption)
                        .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
                        .background(IslandColor.field, in: RoundedRectangle(cornerRadius: Radius.chip))
                    let rows = clip.list.visible(matching: query)
                    if rows.isEmpty {
                        Text(query.isEmpty ? "Noch nichts kopiert." : "Nichts gefunden.")
                            .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                    }
                    ForEach(rows.prefix(3)) { item in
                        HStack(spacing: Space.xs) {
                            Button { clip.copy(item); IslandModel.shared.show(Toast(symbol: "doc.on.doc", text: "Kopiert")) } label: {
                                Label(item.preview, systemImage: item.kind == .image ? "photo" : item.kind == .file ? "doc" : "text.alignleft")
                                    .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            if item.kind == .text {
                                Button { clip.togglePin(item) } label: { Image(systemName: item.pinned ? "pin.fill" : "pin") }
                                    .buttonStyle(.plain).foregroundStyle(item.pinned ? IslandColor.accentText : IslandColor.tertiaryText)
                                    .help(item.pinned ? "Lösen" : "Anheften")
                            }
                        }
                        .font(TypeStyle.islandBody)
                    }
                }
            }
        }
    }
}

/// Island row on the «Ablage» page: take a screenshot of the screen, a window or an area.
struct CaptureStrip: View {
    private var recorder = ScreenRecorder.shared

    var body: some View {
        HStack(spacing: Space.xs) {
            Label("Bildschirmfoto", systemImage: "camera.viewfinder")
                .font(TypeStyle.islandCaption.weight(.semibold)).foregroundStyle(IslandColor.secondaryText)
            Spacer(minLength: 0)
            ForEach(CaptureMode.allCases, id: \.self) { mode in
                IslandPillButton(title: mode.title, kind: mode == .area ? .primary : .secondary) {
                    Task { await ScreenCapture.shared.capture(mode) }
                }
                .help(HotKeys.shared.shortcuts[mode.hotKey].map { "\(mode.title) (\($0.display))" } ?? mode.title)
            }
            IslandPillButton(title: recorder.isRecording ? "Aufnahme beenden" : "Aufnehmen", kind: recorder.isRecording ? .warm : .secondary) { recorder.toggle() }
        }
        .padding(.horizontal, Space.xs)
    }
}
