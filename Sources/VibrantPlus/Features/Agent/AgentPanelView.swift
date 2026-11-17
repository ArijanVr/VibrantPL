// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import VibrantPlusKit

/// The Claude Code panel: sessions, every step, changed files and their diffs.
struct AgentPanelView: View {
    @State private var agent = AgentStore.shared
    @State private var selection: String?
    @State private var showHistory = false
    @State private var file: String?

    var body: some View {
        Group {
            if showHistory { historyView } else { sessionsView }
        }
        .toolbar {
            ToolbarItem {
                Picker("Ansicht", selection: $showHistory) {
                    Text("Sitzungen").tag(false)
                    Text("Verlauf").tag(true)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var historyView: some View {
        Group {
            if agent.history.isEmpty {
                ContentUnavailableView("Noch kein Verlauf", systemImage: "clock.arrow.circlepath",
                                       description: Text("Jede abgeschlossene Antwort von Claude Code erscheint hier, mit Dauer, Dateien und Verbrauch."))
            } else {
                List(agent.history) { e in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(e.project).font(.headline)
                            Spacer()
                            Text(e.date, format: .dateTime.day().month().hour().minute()).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(e.prompt).lineLimit(2)
                        HStack(spacing: Space.md) {
                            Label(AgentHistory.durationText(e.duration), systemImage: "clock")
                            if !e.files.isEmpty { Label("\(e.files.count) Dateien", systemImage: "doc.text") }
                            if e.tokens > 0 { Label(TokenUsage.format(e.tokens) + " Token", systemImage: "number") }
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Claude Code")
        .toolbar {
            ToolbarItem {
                Button("Verlauf löschen", systemImage: "trash", role: .destructive) { agent.clearHistory() }
                    .disabled(agent.history.isEmpty)
            }
        }
    }

    private var sessionsView: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(agent.sortedSessions) { s in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.projectName).font(.headline)
                        Text(s.current).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .tag(s.id)
                    .badge(badge(s))
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230)
            .overlay {
                if agent.sortedSessions.isEmpty {
                    ContentUnavailableView("Keine Claude-Code-Sitzung", systemImage: "sparkles",
                                           description: Text(agent.hooksInstalled
                                                             ? "Starte Claude Code in einem Terminal. Jede Sitzung erscheint hier."
                                                             : "Verbinde Vibrant+ in den Einstellungen mit Claude Code."))
                }
            }
        } detail: {
            if let s = agent.sessions[selection ?? ""] ?? agent.sortedSessions.first {
                detail(s)
            } else {
                ContentUnavailableView("Wähle eine Sitzung", systemImage: "sidebar.left")
            }
        }
        .navigationTitle("Claude Code")
        .toolbar {
            ToolbarItem {
                Button("Beendete entfernen", systemImage: "xmark.bin") { agent.clearEnded() }
            }
        }
        .noInitialFocus()
    }

    private func badge(_ s: AgentSession) -> Text? {
        switch s.status {
        case .needsPermission, .asking: Text("wartet")
        default: nil
        }
    }

    private func detail(_ s: AgentSession) -> some View {
        HSplitView {
            List {
                if !s.prompt.isEmpty {
                    Section("Auftrag") { Text(s.prompt).textSelection(.enabled) }
                }
                Section("Sitzung") {
                    LabeledContent("Antworten", value: "\(s.turns)")
                    if let d = s.lastTurn { LabeledContent("Letzte Antwort dauerte", value: AgentHistory.durationText(d)) }
                    if s.usage.total > 0 {
                        LabeledContent("Verbrauch", value: TokenUsage.format(s.usage.total) + " Token")
                        LabeledContent("davon neu geschrieben", value: TokenUsage.format(s.usage.input + s.usage.output))
                    }
                }
                Section("Terminal") {
                    let commands = s.steps.filter { !$0.detail.isEmpty }
                    if commands.isEmpty { Text("Noch kein Befehl ausgeführt").foregroundStyle(.secondary) }
                    ForEach(commands.reversed()) { step in
                        Text(step.detail)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(step.kind == .failed ? Palette.danger : Color.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
                Section("Schritte") {
                    ForEach(s.steps.reversed()) { step in
                        HStack {
                            Label(step.label, systemImage: step.symbol)
                                .foregroundStyle(step.kind == .failed ? Palette.danger : Color.primary)
                            Spacer()
                            Text(step.time, format: .dateTime.hour().minute().second())
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Geänderte Dateien") {
                    if s.files.isEmpty { Text("Noch keine Datei geändert").foregroundStyle(.secondary) }
                    ForEach(s.files) { f in
                        Button {
                            file = f.path
                        } label: {
                            HStack {
                                Label(f.fileName, systemImage: "doc.text")
                                Spacer()
                                Text("\(f.edits)×").foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: f.path)]) }
                        }
                    }
                }
            }
            .frame(minWidth: 300)
            DiffView(change: s.files.first { $0.path == file } ?? s.files.last)
                .frame(minWidth: 320)
        }
        .navigationSubtitle(s.cwd)
    }
}

struct DiffView: View {
    var change: FileChange?

    var body: some View {
        if let change {
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(change.path).font(.caption).foregroundStyle(.secondary).padding(.bottom, Space.sm)
                    ForEach(Array(LineDiff.lines(old: change.oldText, new: change.newText).enumerated()), id: \.offset) { _, line in
                        row(line)
                    }
                }
                .padding(Space.md)
                .textSelection(.enabled)
            }
            .defaultScrollAnchor(.topLeading)
            .background(.background)
        } else {
            ContentUnavailableView("Kein Diff", systemImage: "doc.text.magnifyingglass",
                                   description: Text("Wähle eine geänderte Datei."))
        }
    }

    @ViewBuilder private func row(_ line: LineDiff.Line) -> some View {
        switch line {
        case .same(let t): text(" ", t).foregroundStyle(.secondary)
        case .removed(let t): text("−", t).background(Palette.diffRemoved)
        case .added(let t): text("+", t).background(Palette.diffAdded)
        }
    }

    private func text(_ sign: String, _ t: String) -> some View {
        Text("\(sign) \(t)").font(.system(size: 11, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
    }
}
