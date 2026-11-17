// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Stow in the island: the dropped files, what they are for, and (with ⌥) tools.
struct StowPanel: View {
    @State private var stow = StowModel.shared
    @State private var trimStart = ""
    @State private var trimEnd = ""
    @State private var shrinkMB = "2"
    @State private var flagsMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Image(systemName: "wand.and.stars").foregroundStyle(IslandColor.accentText)
                Text("Stow").font(TypeStyle.islandTitle)
                Text(fileSummary).font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText).lineLimit(1)
                Spacer()
                Text(stow.showTools ? "Werkzeuge" : "⌥ für Werkzeuge").font(TypeStyle.islandLabel).foregroundStyle(IslandColor.tertiaryText)
                IslandIconButton(symbol: "xmark", label: "Schliessen", size: 22) { stow.clear() }
            }
            if stow.busy {
                HStack { ProgressView().controlSize(.small); Text("Wird umgewandelt…").font(TypeStyle.islandBody) }
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if !stow.results.isEmpty || stow.error != nil {
                result
            } else if stow.showTools {
                tools
            } else {
                targets
            }
        }
        .onAppear {
            flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { e in
                stow.showTools = e.modifierFlags.contains(.option)
                return e
            }
        }
        .onDisappear { if let m = flagsMonitor { NSEvent.removeMonitor(m) } }
    }

    private var fileSummary: String {
        stow.files.count == 1 ? stow.files[0].lastPathComponent : "\(stow.files.count) Dateien"
    }

    @ViewBuilder private var targets: some View {
        if stow.canJoinVideos { joinRow }
        HStack(spacing: Space.sm) {
            thumbnail
            if stow.imagesOrPDF {
                if stow.allImages {
                    target(.web) { stow.preset(.web) }
                    target(.send) { stow.preset(.send) }
                }
                target(.print) { stow.preset(.print) }
            }
            if stow.allMedia {
                card("Für das Web", "MP4, 1080p", "globe") { stow.export(.web) }
                card("Zum Senden", "MP4, 720p", "paperplane") { stow.export(.send) }
            }
        }
        .frame(height: 96)
        formats
    }

    /// The clips in film order, with arrows to reorder, and the join button.
    private var joinRow: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Text("Reihenfolge im Film").font(TypeStyle.islandLabel).foregroundStyle(IslandColor.tertiaryText)
                Spacer()
                Button("Nach Namen sortieren") { stow.sortByName() }
                    .buttonStyle(.plain).font(TypeStyle.islandLabel).foregroundStyle(IslandColor.accentText)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.xs) {
                    ForEach(Array(stow.files.enumerated()), id: \.element) { i, url in
                        HStack(spacing: Space.xs) {
                            Text("\(i + 1)").font(TypeStyle.islandLabel.monospacedDigit()).foregroundStyle(IslandColor.accentText)
                            Text(url.lastPathComponent).font(TypeStyle.islandCaption).lineLimit(1).frame(maxWidth: 140)
                            if i > 0 {
                                Button { stow.move(from: i, to: i - 1) } label: { Image(systemName: "chevron.left") }
                                    .buttonStyle(.plain).help("Früher")
                            }
                            if i < stow.files.count - 1 {
                                Button { stow.move(from: i, to: i + 1) } label: { Image(systemName: "chevron.right") }
                                    .buttonStyle(.plain).help("Später")
                            }
                        }
                        .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
                        .background(IslandColor.cardHover, in: Capsule())
                    }
                }
            }
            IslandPillButton(title: "Zu einem Film verbinden (\(stow.files.count) Clips)", kind: .primary) { stow.joinVideos() }
        }
    }

    private var thumbnail: some View {
        VStack(spacing: 2) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: stow.files.first?.path ?? ""))
                .resizable().frame(width: 56, height: 56)
            if stow.files.count > 1 { Text("+\(stow.files.count - 1)").font(TypeStyle.islandLabel).foregroundStyle(IslandColor.secondaryText) }
        }
        .frame(width: 84, height: 96)
        .islandSurface()
    }

    private func target(_ p: StowEngine.Preset, action: @escaping () -> Void) -> some View {
        card(p.title, p.subtitle, p.symbol, action: action)
    }

    private func card(_ title: String, _ subtitle: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Space.xs) {
                Image(systemName: symbol).font(.system(size: 18))
                Text(title).font(TypeStyle.islandBody.weight(.semibold))
                Text(subtitle).font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .islandSurface()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var formats: some View {
        HStack(spacing: Space.xs) {
            Text("Format").font(TypeStyle.islandLabel).foregroundStyle(IslandColor.tertiaryText)
            if stow.allImages {
                ForEach(StowEngine.ImageFormat.writable) { f in IslandPillButton(title: f.rawValue) { stow.convert(to: f) } }
                IslandPillButton(title: "Hochskalieren 2×") { stow.upscaleImages(2) }
                IslandPillButton(title: "4×") { stow.upscaleImages(4) }
            }
            if stow.kinds == [.video] {
                IslandPillButton(title: "Hochskalieren (bis 4K)") { stow.upscaleVideos() }
            }
            if stow.imagesOrPDF {
                IslandPillButton(title: stow.files.count > 1 ? "Ein PDF" : "PDF") { stow.makePDF() }
            }
            if stow.allMedia {
                if stow.hasVideo {
                    IslandPillButton(title: "MP4") { stow.export(.mp4) }
                    IslandPillButton(title: "MOV") { stow.export(.mov) }
                }
                IslandPillButton(title: "M4A") { stow.export(.m4a) }
            }
        }
    }

    @ViewBuilder private var tools: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if stow.allImages {
                HStack(spacing: Space.xs) {
                    Text("Zuschneiden").font(TypeStyle.islandLabel).foregroundStyle(IslandColor.tertiaryText)
                    ForEach(StowEngine.Ratio.allCases) { r in IslandPillButton(title: r.rawValue) { stow.crop(r) } }
                    Spacer()
                    IslandPillButton(title: "Metadaten entfernen") { stow.stripMetadata() }
                }
                HStack(spacing: Space.xs) {
                    Text("Verkleinern unter").font(TypeStyle.islandLabel).foregroundStyle(IslandColor.tertiaryText)
                    TextField("MB", text: $shrinkMB).textFieldStyle(.roundedBorder).frame(width: 52)
                    Text("MB").font(TypeStyle.islandCaption)
                    IslandPillButton(title: "Los", kind: .primary) {
                        if let mb = Double(shrinkMB.replacingOccurrences(of: ",", with: ".")), mb > 0 { stow.shrink(underMB: mb) }
                    }
                }
            }
            if stow.hasVideo {
                HStack(spacing: Space.xs) {
                    Text("Video kürzen von").font(TypeStyle.islandLabel).foregroundStyle(IslandColor.tertiaryText)
                    TextField("0", text: $trimStart).textFieldStyle(.roundedBorder).frame(width: 52)
                    Text("bis").font(TypeStyle.islandCaption)
                    TextField("Ende", text: $trimEnd).textFieldStyle(.roundedBorder).frame(width: 52)
                    Text("Sekunden").font(TypeStyle.islandCaption)
                    IslandPillButton(title: "Kürzen", kind: .primary) {
                        stow.export(.mp4, start: Double(trimStart) ?? 0, end: Double(trimEnd))
                    }
                }
            }
            if stow.singlePDF {
                IslandPillButton(title: "PDF in Seiten teilen") { stow.splitPDF() }
            }
            if !stow.allImages && !stow.hasVideo && !stow.singlePDF {
                Text("Für diese Dateien gibt es keine Werkzeuge.").font(TypeStyle.islandBody).foregroundStyle(IslandColor.secondaryText)
            }
        }
        .frame(minHeight: 96, alignment: .top)
    }

    private var result: some View {
        HStack(spacing: Space.md) {
            Image(systemName: stow.error == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 26))
                .foregroundStyle(stow.error == nil ? IslandColor.accentText : IslandColor.warm)
            VStack(alignment: .leading, spacing: 2) {
                if let e = stow.error {
                    Text(e).font(TypeStyle.islandBody)
                } else {
                    Text(stow.results.count == 1 ? "Fertig: \(stow.results[0].lastPathComponent)" : "Fertig: \(stow.results.count) Dateien")
                        .font(TypeStyle.islandTitle).lineLimit(1)
                    Text("Neben dem Original abgelegt. Nichts wurde überschrieben.")
                        .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                }
            }
            Spacer()
            if !stow.results.isEmpty {
                IslandPillButton(title: "AirDrop") { Shelf.airDrop(stow.results) }
                IslandPillButton(title: "Im Finder zeigen", kind: .primary) { stow.revealResults() }
            }
            IslandPillButton(title: "Fertig") { stow.clear() }
        }
        .frame(minHeight: 80)
    }
}
