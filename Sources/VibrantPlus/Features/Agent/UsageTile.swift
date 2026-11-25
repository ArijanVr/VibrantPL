// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import VibrantPlusKit

/// The ring: one segment per model, in Puls steps (Porzellan trägt, Puls zeigt.
/// Models differ by how strong the Puls is, not by extra colors).
/// In the middle, the share of the leading model.
struct UsageRing: View {
    var report: UsageReport
    /// At most this many own segments; the rest becomes «Andere».
    static let maxSegments = 5

    /// Segments in ring order with their trim range (0…1), largest first.
    var segments: [(model: ModelUsage?, from: Double, to: Double)] {
        let shown = Array(report.models.prefix(Self.maxSegments - 1))
        let rest = report.models.dropFirst(Self.maxSegments - 1).reduce(0) { $0 + $1.tokens }
        var shares = shown.map { (Optional($0), report.share($0)) }
        if rest > 0 { shares.append((nil, report.total > 0 ? Double(rest) / Double(report.total) : 0)) }
        var start = 0.0
        return shares.map { model, share in
            let segment = (model, start, start + share)
            start += share
            return segment
        }
    }

    /// Segment color by rank: full Puls for the leader, then calmer. «Andere» is graphite.
    static func color(rank: Int, other: Bool) -> Color {
        if other { return IslandColor.cardHover }
        let steps: [Double] = [1.0, 0.7, 0.5, 0.35]
        return IslandColor.accent.opacity(steps[min(rank, steps.count - 1)])
    }

    var body: some View {
        ZStack {
            Circle().stroke(IslandColor.cardHover, lineWidth: 8)
            if report.total > 0 {
                ForEach(Array(segments.enumerated()), id: \.offset) { rank, segment in
                    Circle()
                        .trim(from: segment.from, to: max(segment.from, segment.to - (segment.to - segment.from > 0.02 ? 0.008 : 0)))
                        .stroke(Self.color(rank: rank, other: segment.model == nil),
                                style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
                if let leader = report.models.first {
                    VStack(spacing: 0) {
                        Text("\(Int((report.share(leader) * 100).rounded())) %")
                            .font(TypeStyle.islandTitle.monospacedDigit())
                        Text(Self.shortLabel(leader.model)).font(TypeStyle.islandMicroNumber)
                            .foregroundStyle(IslandColor.tertiaryText).lineLimit(1)
                            .frame(maxWidth: 48)
                    }
                }
            } else {
                Image(systemName: "chart.pie").foregroundStyle(IslandColor.tertiaryText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Verbrauch der KI-Modelle, 7 Tage")
        .accessibilityValue(report.models.first.map { "\(Self.shortLabel($0.model)) mit \(Int((report.share($0) * 100).rounded())) Prozent" } ?? "keine Daten")
    }

    /// A model name short enough for ring and legend.
    static func shortLabel(_ model: String) -> String {
        model.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "gpt-", with: "gpt-")
    }
}

/// Island tile «KI-Verbrauch»: the ring, the three leading models and what the tools did last.
struct UsageTile: View {
    private var store = UsageStore.shared

    var body: some View {
        IslandCard(width: Metrics.wideTileWidth) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack {
                    CardHeader(title: "KI-Verbrauch", symbol: "chart.pie")
                    Spacer()
                    Text("7 Tage").font(TypeStyle.islandMicroNumber).foregroundStyle(IslandColor.tertiaryText)
                }
                if store.report.total > 0 {
                    HStack(spacing: Space.md) {
                        UsageRing(report: store.report).frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: Space.xs) {
                            ForEach(Array(store.report.models.prefix(3).enumerated()), id: \.element.id) { rank, m in
                                HStack(spacing: Space.xs) {
                                    Circle().fill(UsageRing.color(rank: rank, other: false)).frame(width: 8, height: 8)
                                    Text(m.provider == .claude ? UsageRing.shortLabel(m.model) : "\(m.provider.title) · \(UsageRing.shortLabel(m.model))")
                                        .font(TypeStyle.islandCaption).lineLimit(1)
                                    Spacer(minLength: 0)
                                    Text(TokenUsage.format(m.tokens)).font(TypeStyle.islandMicroNumber).foregroundStyle(IslandColor.tertiaryText)
                                }
                            }
                            Spacer(minLength: 0)
                            footer
                        }
                    }
                } else {
                    Spacer()
                    Text(store.scanning ? "Zähle Token…" : "Noch keine Daten. Claude Code, Codex oder OpenCode starten.")
                        .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                }
            }
        }
        .onAppear { UsageStore.shared.refreshIfStale() }
    }

    /// Codex reports its own quotas; the others get their last activity.
    @ViewBuilder private var footer: some View {
        if let quota = store.report.quotas.first {
            Text("Codex \(Int(quota.usedPercent.rounded())) % · \(quota.window)")
                .font(TypeStyle.islandMicroNumber).foregroundStyle(IslandColor.tertiaryText).lineLimit(1)
                .help("Codex-Kontingent \(quota.resets.map { "· zurückgesetzt \($0.formatted(date: .omitted, time: .shortened))" } ?? "")")
        } else if let live = store.report.activity.first(where: \.live) {
            Label("\(live.provider.title) arbeitet gerade", systemImage: "circle.fill")
                .font(TypeStyle.islandMicroNumber).foregroundStyle(IslandColor.accentText).lineLimit(1)
        } else if let last = store.report.activity.first {
            Text("\(last.provider.title): zuletzt \(last.when.formatted(date: .omitted, time: .shortened))")
                .font(TypeStyle.islandMicroNumber).foregroundStyle(IslandColor.tertiaryText).lineLimit(1)
        }
    }
}
