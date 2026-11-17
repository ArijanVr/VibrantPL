// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import CoreAudio
import SwiftUI
import UniformTypeIdentifiers
import VibrantPlusKit

struct InputToolsSettings: View {
    let kind: Module
    @State private var prefs = Prefs.shared
    @State private var exclusions = Prefs.shared.inputRules.excludedApps.sorted().joined(separator: "\n")
    var body: some View {
        Section("Bedienungshilfen") { PermissionRow(permission: .accessibility) }
        Section("Verhalten") {
            switch kind {
            case .mouse:
                Toggle("Mausrad weich auslaufen lassen", isOn: $prefs.inputRules.smoothScroll)
                Toggle("Gleiche Schrittweite pro Mausrad-Ereignis", isOn: $prefs.inputRules.linearScroll)
                Toggle("Mit ⌘ und Mausrad zoomen (+/−)", isOn: $prefs.inputRules.commandScrollZoom)
                Toggle("Rechte Ctrl-Taste als ⌃⌥⌘ nutzen, Antippen als Esc", isOn: $prefs.inputRules.rightControlSuperKey)
                Toggle("Vertikale Mausrichtung umkehren", isOn: $prefs.inputRules.invertVertical)
                Toggle("Horizontale Mausrichtung umkehren", isOn: $prefs.inputRules.invertHorizontal)
                Toggle("Mit ⇧ seitwärts scrollen", isOn: $prefs.inputRules.shiftScrollsSideways)
                Slider(value: $prefs.inputRules.scrollMultiplier, in: 0.1...5) { Text("Scrollgeschwindigkeit") }
                Text("\(prefs.inputRules.scrollMultiplier, specifier: "%.1f")×").font(.caption).foregroundStyle(.secondary)
                Toggle("Seitentasten für Zurück und Vorwärts", isOn: $prefs.inputRules.sideButtonsNavigate)
                Toggle("Mausbeschleunigung aus, bisheriger Wert beim Ausschalten zurück", isOn: $prefs.inputRules.disableMouseAcceleration)
                Picker("Zusatztaste 5", selection: $prefs.inputRules.extraButton5) {
                    ForEach(ExtraMouseAction.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("Zusatztaste 6", selection: $prefs.inputRules.extraButton6) {
                    ForEach(ExtraMouseAction.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("Maus-Seitenrad nach links", selection: $prefs.inputRules.tiltLeft) {
                    ForEach(ExtraMouseAction.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("Maus-Seitenrad nach rechts", selection: $prefs.inputRules.tiltRight) {
                    ForEach(ExtraMouseAction.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Toggle("Music-Start durch Medientasten verhindern", isOn: $prefs.inputRules.blockMusicLaunch)
                Toggle("Sehr schnelle doppelte Tasteneingaben filtern", isOn: $prefs.inputRules.debounceKeys)
                Toggle("Unbeabsichtigte schnelle Mausklicks filtern", isOn: $prefs.inputRules.debounceClicks)
                Text("Scrollanpassungen gelten für Mausräder, nicht für kontinuierliche Trackpad-Gesten. Das Seitenrad (Achse 2) löst nur bei diskreten Mausereignissen aus. Automatische Tastenwiederholungen bleiben erhalten. Sichere Eingabefelder werden nicht verändert. Drei-Finger-Mitteltaste braucht private Multitouch-Schnittstellen und bleibt aus. Die Mausbeschleunigung nutzt IOHIDSetCFTypeParameter; der vorherige Wert wird gesichert.").font(.caption).foregroundStyle(.secondary)
            case .finder:
                Toggle("⌘X und ⌘V zum Verschieben im Finder", isOn: $prefs.inputRules.finderCutPaste)
                Toggle("F2 zum Umbenennen im Finder", isOn: $prefs.inputRules.finderRename)
                Toggle("⌥⇧⌘V fügt reinen Text ein", isOn: $prefs.inputRules.plainPaste)
                Text("Reinen Text einfügen stellt die ursprünglichen Zwischenablageformate danach wieder her, sofern du nicht inzwischen etwas anderes kopiert hast.").font(.caption).foregroundStyle(.secondary)
            case .quitProtection:
                Toggle("⌘Q mit zweitem Tastendruck bestätigen", isOn: $prefs.inputRules.protectQuit)
                Toggle("⌘W mit zweitem Tastendruck bestätigen", isOn: $prefs.inputRules.protectClose)
                Text("Denselben Kurzbefehl innerhalb von 1,5 Sekunden nochmals drücken. Gedrückthalten bestätigt nicht.").font(.caption).foregroundStyle(.secondary)
            default: EmptyView()
            }
            if let message = InputTools.shared.message { Text(message).foregroundStyle(.secondary) }
        }
        .disabled(!prefs.isOn(kind))
        Section {
            TextField("Bundle-IDs, eine pro Zeile", text: $exclusions, axis: .vertical).lineLimit(2...5)
                .onChange(of: exclusions) { prefs.inputRules.excludedApps = Set(exclusions.split(whereSeparator: \.isWhitespace).map(String.init)) }
        } header: { Text("Apps ohne Eingabeanpassungen") }
          footer: { Text("Die Ausnahmen gelten gemeinsam für Maus, Finder-Kurzbefehle und Beenden-Schutz. Beispiel: com.apple.Terminal") }
    }
}

struct AutoQuitSettings: View {
    @State private var prefs = Prefs.shared
    var body: some View {
        Section { PermissionRow(permission: .accessibility) }
        Section {
            ForEach(prefs.autoQuitApps.sorted(), id: \.self) { id in
                HStack {
                    Text(NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)?.deletingPathExtension().lastPathComponent ?? id)
                    Spacer()
                    Button("Entfernen") { prefs.autoQuitApps.remove(id) }
                }
            }
            Button("App hinzufügen…") {
                let panel = NSOpenPanel(); panel.allowedContentTypes = [.applicationBundle]
                guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier,
                      id != Bundle.main.bundleIdentifier, id != "com.apple.finder" else { return }
                prefs.autoQuitApps.insert(id)
            }
        } header: { Text("Ausgewählte Apps") }
          footer: { Text("Erst nachdem Vibrant+ ein Fenster der App gesehen hat, wird sie nach dem Schliessen des letzten Fensters normal beendet. Speicherrückfragen der App bleiben wirksam; kein erzwungenes Beenden.") }
    }
}

struct AudioDeviceSettings: View {
    @State private var audio = AudioDevices.shared
    @State private var prefs = Prefs.shared
    var body: some View {
        Section("Ausgang") {
            Picker("Ton wiedergeben über", selection: Binding(get: { audio.selectedOutput }, set: { audio.selectOutput($0) })) {
                Text("Kein Gerät").tag(AudioObjectID(0))
                ForEach(audio.devices.filter(\.output)) { Text($0.name).tag($0.id) }
            }
        }.disabled(!prefs.isOn(.audioDevices))
        Section("Mikrofon") {
            Picker("Eingang", selection: Binding(get: { audio.selectedInput }, set: { audio.selectInput($0) })) {
                Text("Kein Gerät").tag(AudioObjectID(0))
                ForEach(audio.devices.filter(\.input)) { Text($0.name).tag($0.id) }
            }
            Slider(value: Binding(get: { audio.inputLevel }, set: { audio.setLevel($0) }), in: 0...1) { Text("Eingangspegel") }
                .disabled(!audio.canSetInputLevel)
            Toggle("Mikrofon am Gerät stummschalten", isOn: Binding(get: { audio.inputMuted }, set: { audio.setMuted($0) }))
                .disabled(!audio.canMuteInput)
            Text("Nicht jedes Gerät bietet diese Regler. Hardware-Stummschaltung ist keine Datenschutzsperre für alle Apps oder andere Mikrofone.").font(.caption).foregroundStyle(.secondary)
        }.disabled(!prefs.isOn(.audioDevices))
        Section { Button("Geräte aktualisieren") { audio.refresh() }.disabled(!prefs.isOn(.audioDevices)); if let message = audio.message { Text(message).foregroundStyle(.secondary) } }
            .onAppear { if prefs.isOn(.audioDevices) { audio.refresh() } }
    }
}

struct OCRSettings: View {
    @State private var recognition = TextRecognition.shared
    @State private var prefs = Prefs.shared
    var body: some View {
        Section("Lokal erkennen") {
            HStack {
                Button("Bildschirmbereich…") { recognition.captureArea() }
                Button("Bilddatei…") { recognition.chooseImage() }
            }.disabled(recognition.working || !prefs.isOn(.ocr))
            if recognition.working { ProgressView("Text und QR-Codes erkennen…") }
            if let message = recognition.message { Text(message).foregroundStyle(.secondary) }
            Text("Vision liest Text und QR-Codes auf dem Mac. QR-Links werden nur angezeigt und nie automatisch geöffnet.").font(.caption).foregroundStyle(.secondary)
        }
        if !recognition.text.isEmpty {
            Section("Erkannter Text") {
                Text(recognition.text).textSelection(.enabled)
                Button("Text kopieren") { LinkActions.copy(recognition.text) }
            }
        }
        if !recognition.codes.isEmpty {
            Section("QR-Inhalte") { ForEach(Array(recognition.codes.enumerated()), id: \.offset) { _, code in Text(code).textSelection(.enabled) } }
        }
    }
}

struct ScratchpadSettings: View {
    @State private var prefs = Prefs.shared
    var body: some View {
        Section("Notizen") {
            Button("Notizblock öffnen…") { Windows.show(.scratchpad) }.disabled(!prefs.isOn(.scratchpad))
            Text("Mehrere automatisch gespeicherte Notizen, Markdown-Vorschau und Export als Text. Gelöschte Notizen landen als Markdown im Papierkorb.").foregroundStyle(.secondary)
        }
    }
}

struct ProcessSettings: View {
    @State private var processes = ProcessTools.shared
    @State private var prefs = Prefs.shared
    var body: some View {
        Section {
            Button("Aktualisieren") { processes.refresh() }.disabled(!prefs.isOn(.processes))
            if let message = processes.message { Text(message).foregroundStyle(.secondary) }
        }
        Section("Apps") {
            ForEach(processes.apps, id: \.processIdentifier) { app in
                HStack {
                    Text(app.localizedName ?? "App"); Spacer()
                    Button("Beenden…") { processes.quit(app) }
                    Button("Sofort…") { processes.quit(app, force: true) }
                }
            }
        }.disabled(!prefs.isOn(.processes))
        Section("Lauschende Netzwerkports") {
            ForEach(processes.ports, id: \.self) { server in
                HStack {
                    Text("\(server.port) · \(server.command) (\(server.pid))"); Spacer()
                    Button("Beenden…") { processes.terminatePort(server) }
                }
            }
        }.disabled(!prefs.isOn(.processes))
        .onAppear { if prefs.isOn(.processes) { processes.refresh() } }
    }
}
