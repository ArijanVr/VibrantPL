// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import VibrantPlusKit

/// Island tile «Erinnerungen»: what Apple Reminders says is due. A tap checks one off.
struct RemindersTile: View {
    private var reminders = RemindersService.shared

    var body: some View {
        IslandCard(width: Metrics.wideTileWidth - 64) {
            VStack(alignment: .leading, spacing: Space.xs) {
                CardHeader(title: "Erinnerungen", symbol: "checklist")
                if !reminders.granted {
                    Spacer()
                    Text("Erinnerungen erlauben, um Fälliges zu sehen.").font(TypeStyle.islandCaption).foregroundStyle(IslandColor.secondaryText)
                    IslandPillButton(title: "Erlauben", kind: .primary) { reminders.requestAccess() }
                } else if reminders.items.isEmpty {
                    Spacer()
                    Text("Nichts fällig").font(TypeStyle.islandBody).foregroundStyle(IslandColor.secondaryText)
                    Text("Erledigtes verschwindet hier.").font(TypeStyle.islandCaption).foregroundStyle(IslandColor.tertiaryText)
                } else {
                    ForEach(reminders.items.prefix(3)) { item in
                        Button { reminders.complete(item) } label: {
                            HStack(spacing: Space.sm) {
                                Image(systemName: "circle").foregroundStyle(IslandColor.secondaryText)
                                Text(item.title).font(TypeStyle.islandBody).lineLimit(1)
                                Spacer(minLength: 0)
                                Text(RemindersService.dueText(item.due))
                                    .font(TypeStyle.islandMicroNumber)
                                    .foregroundStyle(RemindersService.dueText(item.due) == "überfällig" ? IslandColor.warm : IslandColor.tertiaryText)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.title) erledigen")
                    }
                    Spacer(minLength: 0)
                    if reminders.items.count > 3 {
                        Text("+\(reminders.items.count - 3) weitere in Erinnerungen")
                            .font(TypeStyle.islandMicroNumber).foregroundStyle(IslandColor.tertiaryText)
                    } else if reminders.failed {
                        Text("Konnte nicht sichern").font(TypeStyle.islandMicroNumber).foregroundStyle(IslandColor.warm)
                    }
                }
            }
        }
    }
}
