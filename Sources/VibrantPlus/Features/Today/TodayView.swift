// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Charts
import SwiftUI
import VibrantPlusKit

/// Today: tasks, focus, note, events, and the last seven days.
/// `compact` is the version inside the island (always dark); the window version follows the Mac.
struct TodayView: View {
    var compact = false
    @State private var store = TodayStore.shared
    @State private var showInsights = false
    @State private var customizing = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .top, spacing: Space.sm) {
                ForEach(store.data.cards.filter { !store.data.hiddenCards.contains($0) }) { card in
                    switch card {
                    case .tasks: TasksCard(compact: compact)
                    case .focus: FocusCard()
                    case .note: NoteCard()
                    case .events: EventsCard()
                    }
                }
            }
            HStack {
                Button(showInsights ? "Insights ausblenden" : "Insights: letzte 7 Tage") {
                    withAnimation(Motion.respecting(Motion.quick)) { showInsights.toggle() }
                }
                Spacer()
                Button("Anpassen…") { customizing = true }
            }
            .buttonStyle(.plain)
            .font(TypeStyle.islandLabel)
            .foregroundStyle(compact ? IslandColor.accentText : Palette.accentText)
            if showInsights { InsightsChart().frame(height: 112) }
        }
        .popover(isPresented: $customizing) { CustomizeToday() }
    }
}

private struct TodayCard<Content: View>: View {
    var title: String
    var symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            CardHeader(title: title, symbol: symbol)
            content
        }
        .padding(Space.md)
        .frame(width: Metrics.tileWidth, height: Metrics.todayCardHeight, alignment: .topLeading)
        .islandSurface()
    }
}

struct TasksCard: View {
    var compact: Bool
    @State private var store = TodayStore.shared
    @State private var newTask = ""

    var body: some View {
        TodayCard(title: "Aufgaben", symbol: "checklist") {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xs) {
                    ForEach(store.openTasks + store.doneToday) { t in row(t) }
                    if store.openTasks.isEmpty && store.doneToday.isEmpty {
                        Text("Noch nichts. Schreib unten die erste.").font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                    }
                }
            }
            TextField("Aufgabe hinzufügen", text: $newTask)
                .textFieldStyle(.plain).font(TypeStyle.islandBody)
                .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
                .background(IslandColor.field, in: RoundedRectangle(cornerRadius: Radius.chip))
                .onSubmit { store.addTask(newTask); newTask = "" }
        }
    }

    private func row(_ t: TaskItem) -> some View {
        HStack(spacing: Space.xs) {
            Button { store.toggle(t) } label: {
                Image(systemName: t.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(t.isDone ? IslandColor.accentText : IslandColor.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(t.isDone ? "Als offen markieren" : "Erledigt")
            Text(t.title).font(TypeStyle.islandCaption).strikethrough(t.isDone)
                .foregroundStyle(t.isDone ? IslandColor.tertiaryText : IslandColor.primaryText).lineLimit(1)
            Spacer(minLength: 0)
            if !t.isDone {
                Menu {
                    ForEach(ReminderPreset.allCases) { p in Button(p.title) { store.remind(t, p) } }
                    if t.remindAt != nil { Button("Erinnerung entfernen") { store.remind(t, nil) } }
                    Divider()
                    Button("Löschen", role: .destructive) { store.delete(t) }
                } label: {
                    Image(systemName: t.remindAt == nil ? "bell" : "bell.fill")
                        .foregroundStyle(t.remindAt == nil ? IslandColor.tertiaryText : IslandColor.warm)
                }
                .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                .help(t.remindAt.map { "Erinnerung " + $0.formatted(.dateTime.weekday().hour().minute()) } ?? "Erinnern")
            }
        }
    }
}

struct FocusCard: View {
    @State private var store = TodayStore.shared

    var body: some View {
        TodayCard(title: "Fokus", symbol: "scope") {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(Clock.format(store.focusRemaining(at: ctx.date))).font(TypeStyle.islandTimer)
                    ProgressView(value: store.focusProgress(at: ctx.date)).tint(IslandColor.accent)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: Space.xs) {
                IslandIconButton(symbol: "minus", label: "5 Minuten weniger", size: 24) { store.adjustFocus(minutes: -5) }
                IslandIconButton(symbol: store.focusRunning ? "pause.fill" : "play.fill",
                                 label: store.focusRunning ? "Pause" : "Fokus starten", size: 30, prominent: true) {
                    store.focusRunning ? store.pauseFocus() : store.startFocus()
                }
                IslandIconButton(symbol: "plus", label: "5 Minuten mehr", size: 24) { store.adjustFocus(minutes: 5) }
                if store.focusActive {
                    IslandIconButton(symbol: "stop.fill", label: "Fokus beenden", size: 24) { store.stopFocus() }
                }
            }
        }
    }
}

struct NoteCard: View {
    @State private var store = TodayStore.shared
    @State private var text = TodayStore.shared.data.note

    var body: some View {
        TodayCard(title: "Notiz", symbol: "note.text") {
            TextEditor(text: $text)
                .font(TypeStyle.islandBody)
                .scrollContentBackground(.hidden)
                .background(IslandColor.field, in: RoundedRectangle(cornerRadius: Radius.chip))
                .onChange(of: text) { store.setNote(text) }
                .accessibilityLabel("Notiz")
        }
    }
}

struct EventsCard: View {
    private var calendar = CalendarService.shared

    var body: some View {
        TodayCard(title: "Termine", symbol: "calendar") {
            if !calendar.granted {
                Text("Kalender erlauben, um Termine zu sehen.").font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                IslandPillButton(title: "Erlauben", kind: .primary) { calendar.requestAccess() }
            } else if calendar.today.isEmpty {
                Text("Heute nichts geplant").font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        ForEach(calendar.today) { e in
                            HStack(alignment: .top, spacing: Space.xs) {
                                RoundedRectangle(cornerRadius: 1).fill(Color(nsColor: e.color ?? .systemBlue)).frame(width: 4, height: 28)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(e.title).font(TypeStyle.islandCaption.weight(.medium)).lineLimit(1)
                                    Text(e.allDay ? "Ganztägig" : e.start.formatted(.dateTime.hour().minute()))
                                        .font(TypeStyle.islandMicro).foregroundStyle(IslandColor.secondaryText)
                                }
                                Spacer(minLength: 0)
                                if let m = e.meeting {
                                    Button { NSWorkspace.shared.open(m.url) } label: { Image(systemName: "video.fill") }
                                        .buttonStyle(.plain).foregroundStyle(IslandColor.accentText).help("Beitreten")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct InsightsChart: View {
    private var store = TodayStore.shared

    var body: some View {
        let days = store.insights
        Chart {
            ForEach(days) { d in
                BarMark(x: .value("Tag", d.day, unit: .day), y: .value("Fokus", d.focusMinutes))
                    .foregroundStyle(by: .value("Art", "Fokusminuten"))
                LineMark(x: .value("Tag", d.day, unit: .day), y: .value("Erledigt", d.done * 25))
                    .foregroundStyle(by: .value("Art", "Erledigte Aufgaben (×25)"))
                    .symbol(.circle)
            }
        }
        .chartForegroundStyleScale(["Fokusminuten": IslandColor.primaryText, "Erledigte Aufgaben (×25)": IslandColor.warm])
        .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
        .chartLegend(position: .bottom, alignment: .leading)
        .font(TypeStyle.islandMicro)
        .accessibilityLabel("Fokusminuten und erledigte Aufgaben der letzten 7 Tage")
        .padding(Space.sm)
        .islandSurface()
    }
}

/// Show, hide and reorder the Today cards, and set the focus length.
struct CustomizeToday: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cards = TodayStore.shared.data.cards
    @State private var hidden = TodayStore.shared.data.hiddenCards
    @State private var minutes = TodayStore.shared.data.focusMinutes

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Heute anpassen").font(.headline)
            List {
                ForEach(cards) { c in
                    Toggle(c.title, isOn: Binding(get: { !hidden.contains(c) }, set: { on in
                        if on { hidden.remove(c) } else { hidden.insert(c) }
                    }))
                }
                .onMove { cards.move(fromOffsets: $0, toOffset: $1) }
            }
            .frame(height: 152)
            Stepper("Fokusdauer: \(minutes) Minuten", value: $minutes, in: 5...180, step: 5)
            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Sichern") {
                    TodayStore.shared.setCards(cards, hidden: hidden)
                    TodayStore.shared.setFocusMinutes(minutes)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Space.margin)
        .frame(width: 340)
    }
}
