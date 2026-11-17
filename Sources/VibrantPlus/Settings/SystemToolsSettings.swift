// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import VibrantPlusKit

struct SystemMonitorSettings: View {
    @State private var monitor = ExtendedSystemMonitor.shared
    @State private var prefs = SystemToolPreferences.shared
    @State private var notificationMessage: String?
    var body: some View {
        Section("Messwerte") {
            Toggle("CPU", isOn: $prefs.monitorCPU)
            Toggle("Arbeitsspeicher", isOn: $prefs.monitorMemory)
            Toggle("Freier Speicherplatz", isOn: $prefs.monitorDisk)
            Toggle("Netzwerkverkehr", isOn: $prefs.monitorNetwork)
            Toggle("Akku und Stromversorgung", isOn: $prefs.monitorPower)
            Toggle("Verbundene Bildschirme, USB-Geräte und Datenträger", isOn: $prefs.monitorDevices)
            if !monitor.running { Text("Schalte das Systemmonitor-Modul ein, um Messungen zu starten.").foregroundStyle(.secondary) }
        }
        if monitor.running, let latest = monitor.latest {
            Section("Aktuell · Verlauf der letzten sechs Minuten") {
                if prefs.monitorCPU, let cpu = latest.cpu {
                    LabeledContent("CPU", value: cpu.formatted(.percent.precision(.fractionLength(0))))
                    LabeledContent("Wärmezustand", value: ThermalLabel.german(latest.thermal))
                    Chart(monitor.history) { sample in
                        if let cpu = sample.cpu { LineMark(x: .value("Zeit", sample.date), y: .value("CPU", cpu * 100)).foregroundStyle(Palette.accentText) }
                    }.chartYScale(domain: 0...100).frame(height: 120)
                    Text("Der Wärmezustand kommt von macOS (normal bis kritisch). Gradzahlen von CPU- und GPU-Sensoren brauchen private Schnittstellen und werden nicht angezeigt.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if prefs.monitorMemory, let used = latest.memoryGB {
                    LabeledContent("Arbeitsspeicher", value: "\(used.formatted(.number.precision(.fractionLength(1)))) / \(monitor.totalMemoryGB.formatted(.number.precision(.fractionLength(1)))) GB")
                    if let share = monitor.compressorShare {
                        LabeledContent("Kompressor-Anteil", value: share.formatted(.percent.precision(.fractionLength(0))))
                    }
                    ForEach(monitor.processes) { process in
                        LabeledContent(process.name, value: ByteCountFormatter.string(fromByteCount: Int64(clamping: process.memoryBytes), countStyle: .memory))
                    }
                }
                if prefs.monitorDisk, let free = latest.diskFreeGB {
                    LabeledContent("Startvolume frei", value: "\(free.formatted(.number.precision(.fractionLength(1)))) GB")
                    if let read = monitor.diskReadPerSecond, let write = monitor.diskWritePerSecond {
                        LabeledContent("Lesen", value: rate(read))
                        LabeledContent("Schreiben", value: rate(write))
                    }
                }
                if prefs.monitorNetwork {
                    LabeledContent("Empfangen", value: rate(latest.receivedPerSecond))
                    LabeledContent("Senden", value: rate(latest.sentPerSecond))
                    LabeledContent("Seit Aktivierung empfangen", value: ByteCountFormatter.string(fromByteCount: Int64(clamping: monitor.sessionReceived), countStyle: .file))
                    LabeledContent("Seit Aktivierung gesendet", value: ByteCountFormatter.string(fromByteCount: Int64(clamping: monitor.sessionSent), countStyle: .file))
                    Text("Summe aktiver Schnittstellen ohne Loopback. VPN- und Brückenverkehr kann mehrfach gezählt werden.").font(.caption).foregroundStyle(.secondary)
                    ForEach(monitor.localAddresses, id: \.self) { Text($0).textSelection(.enabled).font(.caption.monospaced()) }
                }
                if prefs.monitorPower {
                    if let battery = latest.battery { LabeledContent("Akku", value: "\(battery) %") }
                    LabeledContent("Stromquelle", value: latest.onPower ? "Netzteil" : latest.battery == nil ? "Nicht gemeldet" : "Akku")
                    if let minutes = monitor.remainingMinutes { LabeledContent("Geschätzte Restlaufzeit", value: "\(minutes) Minuten") }
                    if let health = monitor.batteryHealth { LabeledContent("Kapazität gegen Auslegung", value: "\(health) %") }
                    if let cycles = monitor.batteryCycles { LabeledContent("Ladezyklen", value: "\(cycles)") }
                    if monitor.batteryHealth == nil && monitor.batteryCycles == nil {
                        Text("Dieses Gerät meldet keine öffentliche Gesundheitszahl.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        if prefs.monitorDevices && monitor.running {
            Section("Verbundene Geräte") {
                ForEach(Array(monitor.connectedDevices.enumerated()), id: \.offset) { _, device in Text(device) }
                Button("Geräte aktualisieren") { monitor.refreshDevices() }
                Text("Öffentlich verfügbare USB-Namen, Bildschirme und entfernbare Datenträger. Keine privaten Bluetooth-Gerätedaten.").font(.caption).foregroundStyle(.secondary)
            }
        }
        Section("Hinweise") {
            Toggle("CPU länger als 20 Sekunden über 90 %", isOn: $prefs.alertCPU)
            Toggle("Arbeitsspeicher über 90 %", isOn: $prefs.alertMemory)
            Toggle("Weniger als 10 GB frei", isOn: $prefs.alertDisk)
            Toggle("Akku höchstens 15 %", isOn: $prefs.alertBattery)
            Toggle("Zusätzlich als macOS-Mitteilung", isOn: $prefs.notify)
                .disabled(!monitor.running)
                .onChange(of: prefs.notify) {
                    guard prefs.notify else { return }
                    Task {
                        do {
                            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                            if !granted { prefs.notify = false; notificationMessage = "Mitteilungen sind nicht erlaubt. Du kannst sie in den Systemeinstellungen freigeben." }
                        } catch { prefs.notify = false; notificationMessage = "Mitteilungen konnten nicht aktiviert werden." }
                    }
                }
            if let notificationMessage { Text(notificationMessage).font(.caption).foregroundStyle(.secondary) }
            if let error = monitor.notificationError { Text(error).font(.caption).foregroundStyle(.secondary) }
            ForEach(monitor.notices, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").foregroundStyle(Palette.accentText) }
            Text("Hinweise erscheinen in Vibrant+, pro Warnung höchstens alle fünf Minuten. GPU-Auslastung, Sensor-Temperaturen in Grad und Lüfterwerte werden ohne öffentliche Schnittstelle nicht erfunden.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func rate(_ bytes: Double?) -> String {
        guard let bytes else { return "Erste Messung…" }
        return ByteCountFormatter.string(fromByteCount: Int64(min(Double(Int64.max / 2), max(0, bytes.isFinite ? bytes : 0))), countStyle: .file) + "/s"
    }
}

struct KeepAwakeRulesSettings: View {
    @State private var service = KeepAwakeRulesService.shared
    @State private var prefs = SystemToolPreferences.shared
    @State private var minutes = 60
    var body: some View {
        Section("Timer") {
            LabeledContent("Status", value: service.active ? service.reason : "Nicht aktiv")
            Stepper("\(minutes) Minuten", value: $minutes, in: 1...1440, step: 5)
            HStack {
                Button("Wachhalten starten") { service.keepAwake(minutes: minutes) }.disabled(!service.running)
                Button("Timer stoppen") { service.cancelTimer() }.disabled(service.manualUntil == nil)
            }
            if let until = service.manualUntil { LabeledContent("Bis", value: until.formatted(date: .omitted, time: .shortened)) }
            if let error = service.error { Text(error).foregroundStyle(Palette.danger) }
        }
        Section("Automatische Regeln") {
            Toggle("Solange der Mac am Netzteil hängt", isOn: $prefs.awakeOnPower)
            Toggle("Solange ein externer Bildschirm verbunden ist", isOn: $prefs.awakeOnDisplay)
            Toggle("Auch den Bildschirm wach halten", isOn: $prefs.preventDisplaySleep)
            ForEach(prefs.awakeApps.sorted(), id: \.self) { id in
                HStack { Text(id); Spacer(); Button("Entfernen") { prefs.awakeApps.remove(id) } }
            }
            Button("App-Regel hinzufügen…") {
                let panel = NSOpenPanel(); panel.allowedContentTypes = [.applicationBundle]
                guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier else { return }
                prefs.awakeApps.insert(id)
            }
            Text("Eine passende Regel genügt. Beim Ausschalten wird nur die eigene Wachhalte-Assertion freigegeben. Geschlossener Deckel, manueller Ruhezustand und kritischer Akkustand werden nicht umgangen.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct QuickToolsSettings: View {
    @State private var store = QuickToolsStore.shared
    @State private var shortcutName = ""
    var body: some View {
        Section("Öffnen") {
            HStack {
                Button("Befehlsleiste") { QuickToolsController.shared.open(.command) }
                Button("Schnellpalette") { QuickToolsController.shared.open(.palette) }
                Button("Radialmenü") { QuickToolsController.shared.open(.radial) }
            }.disabled(!QuickToolsController.shared.enabled)
            Text("Die Befehlsleiste sucht Apps, Dateien, Fenster, Menüs, Zwischenablage und Textbausteine, rechnet lokal und wandelt Einheiten wie «5 km in mi» um. Schnellpalette und Radialmenü öffnen am Zeiger. Das Radialmenü zeigt die ersten acht Favoriten.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Favoriten") {
            ForEach(store.favorites) { action in
                HStack {
                    Text(action.title).lineLimit(1); Spacer()
                    Button { store.move(action, by: -1) } label: { Image(systemName: "chevron.up") }
                        .disabled(action.id == store.favorites.first?.id).help("Nach vorne")
                    Button { store.move(action, by: 1) } label: { Image(systemName: "chevron.down") }
                        .disabled(action.id == store.favorites.last?.id).help("Nach hinten")
                    Button("Entfernen") { store.remove(action) }
                }
            }
            HStack {
                Button("App hinzufügen…") { store.add(kind: .application) }
                Button("Datei oder Ordner…") { store.add(kind: .file) }
            }
            HStack {
                TextField("Name eines macOS-Kurzbefehls", text: $shortcutName)
                Button("Hinzufügen") { store.addShortcut(shortcutName); shortcutName = "" }.disabled(shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let message = store.message { Text(message).foregroundStyle(.secondary) }
            Text("Bis zu 16 Favoriten. Nur ausgewählte Dateien/Apps und benannte macOS-Kurzbefehle; keine Shell-Kommandos.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
