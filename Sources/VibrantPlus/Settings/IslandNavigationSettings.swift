// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import VibrantPlusKit

struct IslandNavigationSettings: View {
    @State private var prefs = Prefs.shared
    @State private var beforeReset: IslandNavigation?

    private var pages: [IslandModel.Page] {
        prefs.islandNavigation.ordered(IslandModel.Page.allCases.map(\.rawValue)).compactMap(IslandModel.Page.init(rawValue:))
    }

    var body: some View {
        Section {
            Picker("Position", selection: $prefs.islandNavigation.placement) {
                Text("Neben dem Notch").tag(IslandNavigation.Placement.besideNotch)
                Text("Über den Kacheln").tag(IslandNavigation.Placement.aboveTiles)
            }
            Picker("Beschriftung", selection: $prefs.islandNavigation.labels) {
                Text("Ausgewählte Seite").tag(IslandNavigation.Labels.selected)
                Text("Nur Symbole").tag(IslandNavigation.Labels.icons)
                Text("Alle Seitennamen").tag(IslandNavigation.Labels.all)
            }
            .disabled(prefs.islandNavigation.placement == .besideNotch)
            .help("Wirkt bei «Über den Kacheln». Neben dem Notch steht der Seitenname rechts vom Notch.")
            Toggle("Datum in der Leiste", isOn: $prefs.islandNavigation.showsDate)
            Toggle("Einstellungen in der Leiste", isOn: $prefs.islandNavigation.showsSettings)
            ForEach(pages, id: \.self) { page in
                HStack(spacing: Space.sm) {
                    Toggle(isOn: Binding(get: { !prefs.islandNavigation.hidden.contains(page.rawValue) }, set: { visible in
                        if visible { prefs.islandNavigation.hidden.remove(page.rawValue) }
                        else { prefs.islandNavigation.hidden.insert(page.rawValue) }
                    })) {
                        Image(systemName: page.symbol).frame(width: 24)
                    }.labelsHidden().help(page.title + " in der Navigation zeigen")
                    TextField(page.title, text: Binding(get: { prefs.islandNavigation.titles[page.rawValue] ?? "" }, set: {
                        prefs.islandNavigation.titles[page.rawValue] = String($0.prefix(40))
                    }))
                    .accessibilityLabel("Name für " + page.title)
                    Button { move(page, by: -1) } label: { Image(systemName: "chevron.up") }
                        .disabled(page == pages.first).help(page.title + " nach vorne")
                    Button { move(page, by: 1) } label: { Image(systemName: "chevron.down") }
                        .disabled(page == pages.last).help(page.title + " nach hinten")
                }
            }
            Button("Navigation zurücksetzen") {
                beforeReset = prefs.islandNavigation
                prefs.islandNavigation = IslandNavigation()
            }
            if let beforeReset {
                Button("Zurücksetzen rückgängig machen") { prefs.islandNavigation = beforeReset; self.beforeReset = nil }
            }
        } header: {
            Text("Navigation")
        } footer: {
            Text("Neben dem Notch bleiben die Seiten einzelne Symbole, auch wenn alle eingeschaltet sind; die Namen stehen in der Hilfe. Über den Kacheln kannst du Namen dazu zeigen. Das Ausblenden einer Seite stoppt kein Modul. Mindestens eine verfügbare Seite bleibt erreichbar.")
        }
    }

    private func move(_ page: IslandModel.Page, by delta: Int) {
        var order = pages.map(\.rawValue)
        guard let index = order.firstIndex(of: page.rawValue), order.indices.contains(index + delta) else { return }
        order.swapAt(index, index + delta)
        prefs.islandNavigation.order = order
    }
}
