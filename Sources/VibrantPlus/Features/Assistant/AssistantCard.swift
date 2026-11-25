// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The conversation in the island: questions, streamed answers, a field for follow-ups.
struct AssistantCard: View {
    @State private var assistant = Assistant.shared
    @State private var input = ""
    private var voice = VoiceController.shared
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill").foregroundStyle(IslandColor.secondaryText)
                Text("Assistent").font(TypeStyle.islandTitle)
                Text("Apple Intelligence · auf diesem Mac").font(TypeStyle.islandCaption).foregroundStyle(IslandColor.tertiaryText)
                Spacer()
                IslandIconButton(symbol: "speaker.slash", label: "Vorlesen stoppen", size: 24) { assistant.stopSpeaking() }
                IslandIconButton(symbol: "doc.on.doc", label: "Antwort kopieren", size: 24) { assistant.copyLastAnswer() }
                IslandIconButton(symbol: "plus.bubble", label: "Neues Gespräch", size: 24) { assistant.newConversation() }
                IslandIconButton(symbol: "xmark", label: "Schliessen", size: 24) {
                    assistant.stopSpeaking()
                    assistant.visible = false
                }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.md) {
                        if assistant.turns.isEmpty {
                            Text(hint).font(TypeStyle.islandBody).foregroundStyle(IslandColor.secondaryText)
                        }
                        ForEach(assistant.turns) { turn in
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text(turn.question).font(TypeStyle.islandBody.weight(.semibold))
                                    .foregroundStyle(IslandColor.accentText)
                                if turn.answer.isEmpty && !turn.done {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text(turn.answer).font(TypeStyle.islandBody)
                                        .foregroundStyle(turn.failed ? IslandColor.warm : IslandColor.primaryText)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .id(turn.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
                .onChange(of: assistant.turns.last?.answer) {
                    if let id = assistant.turns.last?.id { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
            if voice.listening != nil || assistant.conversationActive {
                HStack(spacing: Space.sm) {
                    Image(systemName: voice.listening != nil ? "waveform" : "bubble.left.and.bubble.right")
                        .foregroundStyle(IslandColor.accentText)
                        .symbolEffect(.variableColor.iterative, isActive: voice.listening != nil && !reduceMotion)
                    Text(voice.listening != nil ? (voice.partial.isEmpty ? "Ich höre zu…" : voice.partial)
                                                : "Gespräch läuft. Sag «Danke», um es zu beenden.")
                        .font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText).lineLimit(2)
                    Spacer()
                    if assistant.conversationActive {
                        Button("Beenden") { assistant.endConversation(); assistant.stopSpeaking() }
                            .buttonStyle(.plain).font(TypeStyle.islandLabel).foregroundStyle(IslandColor.accentText)
                    }
                }
            }
            HStack(spacing: Space.sm) {
                TextField("Frag etwas oder sag, was ich tun soll", text: $input)
                    .textFieldStyle(.plain).font(TypeStyle.islandBody)
                    .padding(.horizontal, Space.md).padding(.vertical, Space.sm)
                    .background(IslandColor.field, in: RoundedRectangle(cornerRadius: Radius.control))
                    .focused($focused)
                    .onSubmit(send)
                IslandIconButton(symbol: voice.listening != nil ? "stop.fill" : "mic.fill",
                                 label: voice.listening != nil ? "Zuhören beenden" : "Sprechen", size: 28,
                                 prominent: voice.listening != nil) { voice.toggleTalk() }
                IslandIconButton(symbol: "arrow.up", label: "Senden", size: 28, prominent: true, action: send)
                    .disabled(assistant.busy)
            }
        }
        .padding(Space.md)
        .islandSurface()
        .onAppear { focused = assistant.turns.isEmpty }
    }

    private var hint: String {
        if case .unavailable(let why) = Assistant.state { return why }
        return "Tipp auf das Mikrofon und sprich, oder schreib. Zum Beispiel: «Erinnere mich in 20 Minuten an den Anruf», «Was steht heute an?», «Starte einen Timer für 10 Minuten»."
    }

    private func send() {
        let text = input
        input = ""
        assistant.ask(text, speak: false)
    }
}
