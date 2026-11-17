// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI
import VibrantPlusKit

/// Island page «Laden»: paste a link, pick Video, Audio or Bild, load. The latest downloads beside it.
struct DownloadPage: View {
    private var downloads = Downloads.shared
    @State private var prefs = Prefs.shared
    @State private var text = ""
    @State private var format: DownloadFormat = .video
    @FocusState private var focused: Bool

    private let inputWidth: CGFloat = Metrics.wideTileWidth + 48

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            input
            list
        }
        .onAppear {
            downloads.findTools()
            if text.isEmpty, let link = Downloads.clipboardLink { text = link.absoluteString }
        }
    }

    private var link: URL? { DownloadPlan.link(from: text) }

    private var input: some View {
        IslandCard(width: inputWidth, height: Metrics.tileHeight + 44) {
            VStack(alignment: .leading, spacing: Space.sm) {
                CardHeader(title: "Aus Link laden", symbol: "arrow.down.circle")
                HStack(spacing: Space.xs) {
                    TextField("Link einfügen", text: $text)
                        .textFieldStyle(.plain).font(TypeStyle.islandBody)
                        .focused($focused)
                        .onSubmit(load)
                        .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
                        .background(IslandColor.field, in: RoundedRectangle(cornerRadius: Radius.chip))
                        .accessibilityLabel("Link")
                    IslandIconButton(symbol: "doc.on.clipboard", label: "Link aus der Zwischenablage einfügen", size: 24) {
                        if let l = Downloads.clipboardLink { text = l.absoluteString }
                    }
                }
                HStack(spacing: Space.xs) {
                    ForEach(DownloadFormat.allCases, id: \.self) { f in
                        FormatChip(title: f.title, symbol: f.symbol, selected: format == f) { format = f }
                    }
                    if format == .audio {
                        Divider().frame(height: 16)
                        ForEach(AudioFormat.allCases, id: \.self) { a in
                            FormatChip(title: a.rawValue.uppercased(), symbol: nil, selected: prefs.downloadAudio == a) {
                                prefs.downloadAudio = a
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    IslandPillButton(title: "Laden", kind: .primary, action: load)
                        .disabled(link == nil)
                        .help(link == nil ? "Zuerst einen Link einfügen" : "Nach «\(downloads.folder.lastPathComponent)» laden")
                }
                Text(hint)
                    .font(TypeStyle.islandMicro).foregroundStyle(hintWarm ? IslandColor.warm : IslandColor.tertiaryText)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text("Nur eigene oder freigegebene Inhalte laden. Kopiergeschütztes (DRM) lädt Vibrant+ nicht.")
                    .font(TypeStyle.islandMicro).foregroundStyle(IslandColor.tertiaryText).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// What will happen with this link, before loading.
    private var hint: String {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "Direkte Links auf Bilder, Videos und Musik. YouTube, Instagram, Vimeo & Co. mit yt-dlp."
        }
        guard let link else { return "Das ist kein Web-Link (https://…)." }
        switch DownloadPlan.classify(link) {
        case .protected: return "Dieser Dienst schützt seine Inhalte (DRM). Hier lädt Vibrant+ nichts."
        case .platform:
            if downloads.ytDlp == nil { return "Für diese Seite braucht es yt-dlp: im Terminal «brew install yt-dlp ffmpeg»." }
            let login = DownloadPlan.isInstagram(link) && InstagramLogin.shared.signedIn ? " Mit deinem Login." : ""
            if format == .image { return "Lädt die Bilder des Beitrags (Karussell: alle)." + login }
            if downloads.ffmpeg == nil { return "Ohne ffmpeg nur eine Datei in mittlerer Qualität («brew install ffmpeg» für mehr)." + login }
            return "Lädt mit yt-dlp nach «\(downloads.folder.lastPathComponent)»." + login
        case .direct(let f):
            return f == format ? "Datei-Link, wird direkt geladen." : "Datei-Link (\(f.title)), wird so geladen, wie er ist."
        case .other: return "Ist es keine Datei, versucht Vibrant+ es mit yt-dlp."
        }
    }

    private var hintWarm: Bool {
        guard let link else { return !text.trimmingCharacters(in: .whitespaces).isEmpty }
        switch DownloadPlan.classify(link) {
        case .protected: return true
        case .platform: return downloads.ytDlp == nil
        default: return false
        }
    }

    private func load() {
        guard let link else { return }
        if downloads.start(link, format: format) != nil { text = "" }
    }

    private var list: some View {
        IslandCard(width: Metrics.islandContentWidth - inputWidth - Space.sm, height: Metrics.tileHeight + 44) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack {
                    CardHeader(title: "Zuletzt", symbol: "clock.arrow.circlepath")
                    Spacer()
                    Button("Ordner") { NSWorkspace.shared.open(downloads.folder) }
                        .buttonStyle(.plain).font(TypeStyle.islandLabel).foregroundStyle(IslandColor.accentText)
                        .help("«\(downloads.folder.path)» im Finder öffnen")
                    if downloads.items.contains(where: { !$0.isRunning }) {
                        Button("Leeren") { downloads.clearFinished() }
                            .buttonStyle(.plain).font(TypeStyle.islandLabel).foregroundStyle(IslandColor.accentText)
                    }
                }
                if downloads.items.isEmpty {
                    Spacer()
                    Text("Noch nichts geladen.").font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                    Spacer()
                } else {
                    ForEach(downloads.items.prefix(3)) { DownloadRow(item: $0) }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

/// One line in the list: name, progress or result, and what can be done with it.
struct DownloadRow: View {
    var item: DownloadItem

    var body: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: item.format.symbol).foregroundStyle(IslandColor.secondaryText).frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(TypeStyle.islandCaption.weight(.medium)).lineLimit(1).truncationMode(.middle)
                status
            }
            Spacer(minLength: 0)
            actions
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var status: some View {
        switch item.state {
        case .preparing:
            Text("Wird vorbereitet …").font(TypeStyle.islandMicro).foregroundStyle(IslandColor.tertiaryText)
        case .loading(let fraction):
            if let fraction {
                ProgressView(value: fraction).progressViewStyle(.linear).tint(IslandColor.accent).controlSize(.mini)
                    .accessibilityLabel("Lädt, \(Int(fraction * 100)) Prozent")
            } else {
                Text("Lädt … \(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file))")
                    .font(TypeStyle.islandMicroNumber).foregroundStyle(IslandColor.tertiaryText)
            }
        case .done:
            Text("Fertig").font(TypeStyle.islandMicro).foregroundStyle(IslandColor.secondaryText)
        case .failed(let reason):
            Text(reason).font(TypeStyle.islandMicro).foregroundStyle(IslandColor.warm).lineLimit(2)
                .help(reason)
        case .cancelled:
            Text("Abgebrochen").font(TypeStyle.islandMicro).foregroundStyle(IslandColor.tertiaryText)
        }
    }

    @ViewBuilder private var actions: some View {
        switch item.state {
        case .preparing, .loading:
            IslandIconButton(symbol: "xmark", label: "Abbrechen", size: 20) { Downloads.shared.cancel(item) }
        case .done(let url):
            IslandIconButton(symbol: "magnifyingglass", label: "Im Finder zeigen", size: 20) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            IslandIconButton(symbol: "tray.and.arrow.down", label: "In die Ablage", size: 20) { Shelf.shared.add([url]) }
        case .failed, .cancelled:
            IslandIconButton(symbol: "arrow.clockwise", label: "Nochmals versuchen", size: 20) {
                Downloads.shared.remove(item)
                Downloads.shared.start(item.link, format: item.format)
            }
        }
    }
}

/// A small selectable chip on the island (Video, Audio, Bild; M4A, MP3).
struct FormatChip: View {
    var title: String
    var symbol: String?
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(TypeStyle.islandCaption.weight(.semibold))
            .foregroundStyle(selected ? IslandColor.primaryText : IslandColor.secondaryText)
            .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
            .background(selected ? IslandColor.cardHover : IslandColor.field, in: Capsule(style: .circular))
            .overlay(Capsule(style: .circular).strokeBorder(selected ? IslandColor.accent : .clear, lineWidth: 1))
        }
        .buttonStyle(IslandPressStyle())
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

// MARK: - Settings

struct DownloadSettings: View {
    @State private var prefs = Prefs.shared
    private var downloads = Downloads.shared
    private var login = InstagramLogin.shared
    @State private var version: String?

    var body: some View {
        Section {
            LabeledContent("Ordner") {
                HStack {
                    Text(downloads.folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    Button("Ändern…", action: chooseFolder)
                    if !prefs.downloadFolder.isEmpty {
                        Button("Downloads") { prefs.downloadFolder = "" }
                    }
                }
            }
            Picker("Video-Qualität", selection: $prefs.downloadQuality) {
                Text("Beste in H.264 (meist bis 1080p)").tag(VideoQuality.standard)
                Text("4K, wenn vorhanden (wird umgewandelt, dauert)").tag(VideoQuality.uhd)
                Text("720p").tag(VideoQuality.hd720)
                Text("Klein (480p)").tag(VideoQuality.small)
            }
            Picker("Nur Ton als", selection: $prefs.downloadAudio) {
                Text("M4A (beste Qualität, Apple)").tag(AudioFormat.m4a)
                Text("MP3 (überall abspielbar, braucht ffmpeg)").tag(AudioFormat.mp3)
            }
        } header: {
            Text("Ablage")
        } footer: {
            Text("Beim ersten Laden in «Downloads» fragt macOS einmal, ob Vibrant+ dort speichern darf.")
        }
        Section {
            tool("yt-dlp", path: downloads.ytDlp, detail: version.map { "Version \($0)" })
            tool("ffmpeg", path: downloads.ffmpeg, detail: nil)
            if downloads.ytDlp == nil || downloads.ffmpeg == nil {
                LabeledContent {
                    HStack {
                        Text("brew install yt-dlp ffmpeg").monospaced().textSelection(.enabled)
                        Button("Kopieren") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("brew install yt-dlp ffmpeg", forType: .string)
                        }
                    }
                } label: {
                    Text("Installieren")
                    Text("Im Terminal ausführen (Homebrew nötig, brew.sh). Danach «Neu suchen».")
                }
            }
            Button("Neu suchen") { downloads.findTools(); Task { await readVersion() } }
        } header: {
            Text("Links von Plattformen")
        } footer: {
            Text("Für YouTube, Instagram, TikTok, Vimeo, SoundCloud und viele mehr nutzt Vibrant+ das freie Werkzeug yt-dlp, wenn es auf deinem Mac installiert ist. Vibrant+ liefert es nicht mit. Ändert eine Plattform etwas, hilft oft «brew upgrade yt-dlp». Direkte Links auf Bild-, Video- und Musikdateien gehen ohne yt-dlp.")
        }
        Section {
            LabeledContent("Instagram") {
                HStack {
                    Image(systemName: login.signedIn ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(login.signedIn ? Palette.accentText : .secondary)
                        .accessibilityHidden(true)
                    Text(login.signedIn ? "Angemeldet" : "Nicht angemeldet").foregroundStyle(.secondary)
                }
            }
            HStack {
                Button(login.signedIn ? "Neu anmelden…" : "Bei Instagram anmelden…") { login.open() }
                if login.signedIn {
                    Button("Abmelden", role: .destructive) { Task { await login.signOut() } }
                }
            }
        } header: {
            Text("Mit meinem Login laden")
        } footer: {
            Text("Die Anmeldung läuft auf der echten Instagram-Seite, dein Passwort bleibt bei Instagram. Beim Laden eines Instagram-Links gibt Vibrant+ die Anmeldung an yt-dlp weiter und löscht die Kopie gleich danach. Du siehst nur, was dein Konto sieht. Storys zeigen dich als Betrachter. Viele Downloads in kurzer Zeit können zu einer Sperre deines Kontos führen.")
        }
        .task { await login.refresh() }
        Section {
            Text("Lade nur, was dir gehört, was frei lizenziert ist oder wofür du die Erlaubnis hast. Viele Plattformen verbieten das Herunterladen in ihren Nutzungsbedingungen.")
            Text("Vibrant+ umgeht keinen Kopierschutz (DRM): Spotify, Netflix, Apple Music und ähnliche Dienste werden abgelehnt. Inhalte hinter einer Anmeldung lädt Vibrant+ nur mit deinem eigenen Instagram-Login. Geladen wird direkt von der Quelle auf deinen Mac, ohne Umweg über einen Server.")
                .foregroundStyle(.secondary)
        } header: {
            Text("Fair laden")
        }
        .task { await readVersion() }
    }

    private func tool(_ name: String, path: String?, detail: String?) -> some View {
        LabeledContent {
            HStack {
                Image(systemName: path != nil ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(path != nil ? Palette.accentText : .secondary)
                    .accessibilityLabel(path != nil ? "Gefunden" : "Nicht gefunden")
                Text(path ?? "nicht gefunden").foregroundStyle(.secondary)
            }
        } label: {
            Text(name)
            if let detail { Text(detail) }
        }
    }

    private func readVersion() async {
        guard let path = downloads.ytDlp else { version = nil; return }
        let r = await Run.async(path, ["--version"], timeout: 15)
        let v = r.output.trimmingCharacters(in: .whitespacesAndNewlines)
        version = r.status == 0 && !v.isEmpty ? v : nil
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = downloads.folder
        panel.prompt = "Wählen"
        if panel.runModal() == .OK, let url = panel.url { prefs.downloadFolder = url.path }
    }
}
