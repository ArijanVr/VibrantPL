// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct WindowToolsSettings: View {
    @State private var prefs = WindowToolPreferences.shared
    var body: some View {
        Section("Berechtigungen") {
            PermissionRow(permission: .accessibility)
            PermissionRow(permission: .screenRecording)
            Text("Die reine App-Liste funktioniert ohne Freigabe. Einzelne Fenster und deren Steuerung brauchen Bedienungshilfen. Bilder von Fenstern brauchen zusätzlich Bildschirmaufnahme.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Apps und Fenster") {
            Toggle("App- und Fensterwechsler", isOn: $prefs.switcherEnabled)
            Toggle("Fensterbilder anzeigen", isOn: $prefs.previewImagesEnabled)
            Button("Fensterwechsler öffnen…") { WindowTools.shared.openSwitcher() }.disabled(!WindowTools.shared.active || !prefs.switcherEnabled)
            Text("Apps und einzelne Fenster suchen, nach Bildschirm filtern und per Doppelklick oder Öffnen aktivieren. Rechtsklick bietet Minimieren, normales Schliessen und Anordnen. Minimierte Fenster haben unter Umständen kein verfügbares Bild.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Dock") {
            Toggle("Fenster bei Dock-Hover zeigen", isOn: $prefs.dockPreviewEnabled)
            Picker("Klick auf aktive App", selection: $prefs.dockClickAction) {
                ForEach(WindowToolPreferences.DockClickAction.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Text("Nur ein Klick auf eine bereits aktive App erhält die gewählte Zusatzaktion. Das normale Starten anderer Apps bleibt erhalten. Die Vorschau arbeitet mit öffentlichen AX- und ScreenCaptureKit-Daten; privates Festhalten des automatisch ausgeblendeten Docks und Steuerung anderer Spaces sind nicht enthalten.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Fenstersteuerung") {
            Toggle("Grüner Fensterknopf füllt den Bildschirm", isOn: $prefs.greenButtonMaximizes)
            Toggle("Fenster folgt dem Mausfokus", isOn: $prefs.focusFollowsMouse)
            Toggle("An Bildschirmrändern einrasten", isOn: $prefs.edgeSnapEnabled)
            Toggle("Mit ⌥ und Ziehen Fenster verschieben", isOn: $prefs.modifierDragEnabled)
            Slider(value: $prefs.hoverDelay, in: 0.2...2, step: 0.1) { Text("Hover-Verzögerung") }
            Text("\(prefs.hoverDelay, specifier: "%.1f") Sekunden").font(.caption).foregroundStyle(.secondary)
            Text("Erneuter Klick auf den grünen Knopf stellt die vorherige Grösse wieder her. Im Wechsler gibt es dieselbe Wiederherstellung, Drittel-Anordnungen und den Sprung auf den nächsten Bildschirm. Modifizierte Klicks bleiben nativ. Randziele: links/rechts halbe Breite, oben nutzbare Bildschirmfläche. ⌥-Ziehen verwendet die öffentliche Fensterposition; der ursprüngliche ⌥-Drag wird dabei nicht an App-Inhalte weitergegeben.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Spaces") {
            Toggle("Spaces in fester Reihenfolge halten", isOn: $prefs.fixedSpaces)
            Button("Dock neu starten…") { SpacesOrderController.restartDock() }
            Text("Sichert die vorherige Mission-Control-Einstellung «Spaces nach letzter Verwendung automatisch ausrichten» und stellt sie beim Ausschalten wieder her. Dock kann einen Neustart benötigen. Es werden keine Spaces verschoben oder über private APIs verwaltet.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Ausnahmen") {
            TextField("Bundle-IDs, eine pro Zeile", text: $prefs.excludedApps, axis: .vertical).lineLimit(2...5)
            if let message = WindowTools.shared.message { Text(message).foregroundStyle(.secondary) }
        }
    }
}
