// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Selection is a persistent draft. Services start only after the final step.
struct WelcomeView: View {
    @State private var prefs = Prefs.shared
    @State private var launchAtLogin = Coordinator.launchesAtLogin
    @State private var loginError: String?
    var previewStep: Int?

    private var step: Int { previewStep ?? prefs.setupStep }
    private let titles = ["Was Vibrant+ kann", "Werkzeuge wählen", "Berechtigungen", "Bereit"]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.sm) {
                Wordmark.view(height: 36)
                Text(titles[step]).font(TypeStyle.title)
                Text("Schritt \(step + 1) von 4").font(TypeStyle.footnote).foregroundStyle(Surface.secondary)
            }
            .padding(.horizontal, Space.xl)
            if step == 1 {
                selectionForm
            } else if step == 2 {
                permissionForm
            } else {
                ScrollView {
                    content.padding(.horizontal, Space.xl)
                }
            }
            Divider()
            HStack {
                Button("Zurück") { prefs.setupStep = max(0, step - 1) }
                    .disabled(step == 0)
                Spacer()
                Button(step == 3 ? "Vibrant+ starten" : "Weiter") { advance() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, Space.xl)
        }
        .padding(.vertical, Space.xl)
        .padding(.top, Space.lg)
        .frame(width: 560, height: 600)
        .background(Surface.window)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0:
            VStack(alignment: .leading, spacing: Space.md) {
                PulsiImage(pose: .willkommen, height: 120)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                Text("Dein Mac. Deine Werkzeuge.").font(TypeStyle.headline)
                Text("Alles bleibt aus, bis du es einschaltest. Keine Konten, keine Analyse. Im nächsten Schritt wählst du, was wirklich läuft.")
                Label("Pulslinie in der Menüleiste, Insel am Notch oder ⌃⌥⌘I.", systemImage: "menubar.rectangle")
                ForEach(Module.Group.allCases, id: \.self) { group in
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(group.rawValue).font(.subheadline).fontWeight(.semibold)
                        ForEach(Module.allCases.filter { $0.group == group }) { module in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(module.title)
                                    Text(module.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: module.symbol).foregroundStyle(Palette.accentText).frame(width: 20)
                            }
                        }
                    }
                }
            }.fixedSize(horizontal: false, vertical: true)
        case 1: EmptyView() // The selection form owns its scrolling.
        case 2: EmptyView() // The permission form owns its scrolling.
        default:
            VStack(alignment: .leading, spacing: Space.lg) {
                PulsiImage(pose: .erfolg, height: 120)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                Label("\(prefs.setupSelection.count) Werkzeuge ausgewählt", systemImage: "checkmark.circle")
                    .font(TypeStyle.headline)
                Text("Du findest deine Werkzeuge in der Menüleiste. Einstellungen › Funktionen bietet Suche, Profile und alle Schalter. Ausgeschaltete Module behalten ihre Einstellungen.")
                Toggle("Beim Anmelden öffnen", isOn: $launchAtLogin)
                if let loginError { Text(loginError).foregroundStyle(Palette.danger) }
                Text("Berechtigungen und Einstellungen kannst du jederzeit ändern.").foregroundStyle(.secondary)
            }.fixedSize(horizontal: false, vertical: true)
        }
    }

    private var permissionForm: some View {
        Form {
            Section {
                let permissions = SetupPermissions.required(for: prefs.setupSelection, tiles: prefs.tilesOn)
                if permissions.isEmpty {
                    Label("Deine Auswahl braucht hier keine Freigabe.", systemImage: "checkmark.circle")
                } else {
                    ForEach(permissions) { PermissionRow(permission: $0) }
                }
            } header: {
                Text("Nur für deine Auswahl")
            } footer: {
                Text("Du kannst jede Freigabe überspringen und später erteilen. Nach einer Bildschirmfreigabe kann macOS einen Neustart verlangen. Deine Auswahl und dieser Schritt bleiben gespeichert.")
            }
        }
        .formStyle(.grouped)
    }

    private var selectionForm: some View {
        Form {
            Section {
                ForEach(ModuleProfile.allCases) { profile in
                    Button {
                        prefs.setupSelection = profile.modules
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text(profile.title).fontWeight(.medium).foregroundStyle(Color.primary)
                                Text(profile.detail).font(.caption).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            if prefs.setupSelection == profile.modules {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.accentText)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.borderless)
                }
            } header: { Text("Profile") }
              footer: { Text("Wähle ein Profil als Ausgangspunkt oder stelle deine Auswahl unten selbst zusammen.") }
            ModuleSelection(selection: $prefs.setupSelection)
        }
        .formStyle(.grouped)
    }

    private func advance() {
        guard step == 3 else { prefs.setupStep = step + 1; return }
        if launchAtLogin != Coordinator.launchesAtLogin {
            loginError = Coordinator.setLaunchAtLogin(launchAtLogin)
            guard loginError == nil else { return }
        }
        prefs.modules = prefs.setupSelection
        prefs.onboarded = true
        prefs.setupStep = 0
        Coordinator.shared.apply()
        Windows.close(.welcome)
        if prefs.isOn(.island) {
            withAnimation(Motion.respecting(Motion.island)) { IslandController.shared.open() }
        }
    }
}
