// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Observation
import SwiftUI

/// New screenshots appear in the island for a moment: copy, share, mark up, move to the Trash.
/// Found through Spotlight's screen-capture flag, so it works wherever macOS saves them.
@Observable
final class ScreenshotShelf {
    static let shared = ScreenshotShelf()

    private(set) var latest: URL?
    private(set) var thumbnail: NSImage?
    /// True when Vibrant+ took the picture itself and already put it in the clipboard.
    private(set) var copied = false
    /// Set when the picture is a file that arrived by AirDrop instead of a screenshot.
    private(set) var arrivedByAirDrop = false
    @ObservationIgnored private var query: NSMetadataQuery?
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var started = Date.now
    @ObservationIgnored private var hideTask: Task<Void, Never>?
    @ObservationIgnored private var seen: Set<String> = []

    func start() {
        guard query == nil else { return }
        started = .now
        let q = NSMetadataQuery()
        q.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
        q.searchScopes = [NSMetadataQueryUserHomeScope]
        observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: q, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        q.start()
        query = q
        AirDropArrival.shared.start()
    }

    func stop() {
        AirDropArrival.shared.stop()
        query?.stop()
        query = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        dismiss()
    }

    private func check() {
        guard let q = query else { return }
        q.disableUpdates()
        defer { q.enableUpdates() }
        var newest: (URL, Date)?
        for case let item as NSMetadataItem in q.results {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  let created = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date,
                  created > started.addingTimeInterval(-1), !seen.contains(path) else { continue }
            if newest == nil || created > newest!.1 { newest = (URL(fileURLWithPath: path), created) }
            seen.insert(path)
        }
        if let (url, _) = newest { show(url) }
    }

    /// Also used by the self-test.
    func show(_ url: URL, copied: Bool = false, airDrop: Bool = false) {
        arrivedByAirDrop = airDrop
        seen.insert(url.path)   // Spotlight reports pictures Vibrant+ took, too: show them once
        self.copied = copied
        latest = url
        thumbnail = NSImage(contentsOf: url)
        // An open island shows the card at once (a request or a reminder stays in front of it),
        // and the island waits for it to be dealt with.
        withAnimation(Motion.respecting(Motion.island)) { IslandController.shared.open(sticky: true) }
        armAutoHide()
    }

    /// The card folds away by itself after a while, unless the mouse rests on the island.
    private func armAutoHide() {
        hideTask?.cancel()
        // «Screenshots bleiben hängen»: the card stays until the person closes it.
        guard !Prefs.shared.screenshotsStay else { return }
        hideTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                guard !IslandController.shared.pointerIsInside else { continue }
                dismiss()
                return
            }
        }
    }

    func dismiss() {
        hideTask?.cancel()
        hideTask = nil
        latest = nil
        thumbnail = nil
        copied = false
        arrivedByAirDrop = false
        // Fold the island away only when this card was the last reason for it: a request that is
        // still waiting keeps it open.
        IslandController.shared.releaseStickyIfIdle()
    }

    // MARK: Actions

    func copy() {
        guard let latest, let image = NSImage(contentsOf: latest) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
        IslandModel.shared.show(Toast(symbol: "doc.on.doc", text: "Bildschirmfoto kopiert"))
        dismiss()
    }

    /// Opens the picture in Preview, whose Markup tools draw on it.
    func markUp() {
        guard let latest else { return }
        if let preview = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") {
            NSWorkspace.shared.open([latest], withApplicationAt: preview, configuration: NSWorkspace.OpenConfiguration())
        }
        dismiss()
    }

    func reveal() {
        guard let latest else { return }
        NSWorkspace.shared.activateFileViewerSelecting([latest])
        dismiss()
    }

    /// To the Trash, not deleted for good.
    func trash() {
        guard let latest else { return }
        do {
            try FileManager.default.trashItem(at: latest, resultingItemURL: nil)
            IslandModel.shared.show(Toast(symbol: "trash", text: "In den Papierkorb gelegt"))
        } catch {
            IslandModel.shared.show(Toast(symbol: "exclamationmark.triangle", text: "Konnte nicht löschen", warm: true))
        }
        dismiss()
    }
}

struct ScreenshotCard: View {
    var shelf = ScreenshotShelf.shared
    /// A received photo settles in like a Polaroid: slightly tilted, dropped from above, then straight.
    @State private var landed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Space.md) {
            Group {
                if let image = shelf.thumbnail {
                    Image(nsImage: image).resizable().scaledToFit()
                } else {
                    Image(systemName: "photo").font(.system(size: 28)).foregroundStyle(IslandColor.tertiaryText)
                }
            }
            .frame(width: 160, height: 100)
            .background(IslandColor.field, in: RoundedRectangle(cornerRadius: Radius.control))
            .clipShape(RoundedRectangle(cornerRadius: Radius.control))
            .rotationEffect(.degrees(shelf.arrivedByAirDrop && !landed && !reduceMotion ? -7 : 0))
            .offset(y: shelf.arrivedByAirDrop && !landed && !reduceMotion ? -28 : 0)
            .opacity(shelf.arrivedByAirDrop && !landed && !reduceMotion ? 0 : 1)
            .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { landed = true } }
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(shelf.arrivedByAirDrop ? "Per AirDrop erhalten" : shelf.copied ? "Bildschirmfoto gesichert und kopiert" : "Neues Bildschirmfoto").font(TypeStyle.islandTitle)
                Text(shelf.latest?.lastPathComponent ?? "").font(TypeStyle.islandCaption)
                    .foregroundStyle(IslandColor.secondaryText).lineLimit(1)
                HStack(spacing: Space.xs) {
                    IslandPillButton(title: "Kopieren", kind: .primary) { shelf.copy() }
                    IslandPillButton(title: "Beschriften") { shelf.markUp() }
                    if let url = shelf.latest {
                        ShareLink(item: url) {
                            Text("Teilen").font(TypeStyle.islandCaption.weight(.semibold))
                                .padding(.horizontal, Space.md).padding(.vertical, Space.xs + 2)
                                .foregroundStyle(IslandColor.primaryText)
                                .background(IslandColor.cardHover, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack(spacing: Space.xs) {
                    IslandPillButton(title: "Im Finder") { shelf.reveal() }
                    IslandPillButton(title: "Löschen", kind: .danger) { shelf.trash() }
                    IslandPillButton(title: "Schliessen") { shelf.dismiss() }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Space.md)
        .islandSurface()
    }
}
