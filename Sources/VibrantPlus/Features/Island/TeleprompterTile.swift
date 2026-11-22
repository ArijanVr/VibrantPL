// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Teleprompter: the script scrolls upward at the chosen speed, right under the notch.
struct TeleprompterTile: View {
    private var prefs = Prefs.shared
    @State private var started: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var text: Binding<String> { Binding(get: { prefs.teleprompterText }, set: { prefs.teleprompterText = $0 }) }
    private var speed: Binding<Double> { Binding(get: { prefs.teleprompterSpeed }, set: { prefs.teleprompterSpeed = $0 }) }

    var body: some View {
        IslandCard(width: Metrics.wideTileWidth - 64) {
            VStack(alignment: .leading, spacing: Space.xs) {
                CardHeader(title: "Teleprompter", symbol: "text.alignleft")
                if let start = started {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                        // Reduce motion: no smooth scroll, the text advances in whole lines.
                        let raw = ctx.date.timeIntervalSince(start) * prefs.teleprompterSpeed
                        let y = reduceMotion ? (raw / 16).rounded(.down) * 16 : raw
                        // The whole script at its own height, behind a window: without fixedSize it was cut to three lines.
                        Color.clear
                            .overlay(alignment: .top) {
                                Text(prefs.teleprompterText)
                                    .font(TypeStyle.islandBody)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .offset(y: -y) // grid: ok motion
                            }
                            .clipped()
                    }
                } else {
                    TextField("Skript einfügen", text: text, axis: .vertical)
                        .textFieldStyle(.plain).font(TypeStyle.islandBody).lineLimit(1...3)
                        .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
                        .background(IslandColor.field, in: RoundedRectangle(cornerRadius: Radius.chip))
                        .accessibilityLabel("Skript")
                    Spacer(minLength: 0)
                }
                HStack(spacing: Space.xs) {
                    Text("Tempo").font(TypeStyle.islandLabel).foregroundStyle(IslandColor.tertiaryText)
                    Slider(value: speed, in: 8...80).controlSize(.mini)
                        .accessibilityLabel("Tempo")
                    IslandPillButton(title: started == nil ? "Start" : "Stopp", kind: .primary) {
                        started = started == nil ? Date() : nil
                    }
                    .disabled(prefs.teleprompterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
