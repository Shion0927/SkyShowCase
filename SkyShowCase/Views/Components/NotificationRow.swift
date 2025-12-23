//
//  NotificationRow.swift
//  SkyShowCase
//
//  Created by 植村詩苑 on 2025/12/23.
//

import SwiftUI

/// A lightweight press feedback style for row-like tap targets.
struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(configuration.isPressed ? Color(.systemGray5) : Color.clear)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// UI-only DTO for notification list rows
struct NotificationRowModel: Identifiable {
    enum State {
        case sent
        case suppressed

        var badgeText: String? {
            switch self {
            case .sent: return nil
            case .suppressed: return "抑制"
            }
        }

        var badgeColor: Color {
            switch self {
            case .sent: return .secondary
            case .suppressed: return .gray
            }
        }
    }

    let id = UUID()
    let title: String
    let timeText: String
    let summary: String
    let state: State
}

struct NotificationRow: View {
    let model: NotificationRowModel

    var body: some View {
        Button {} label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(model.title)
                        .font(.subheadline).fontWeight(.semibold)

                    if let badge = model.state.badgeText {
                        Text(badge)
                            .font(.caption2).fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(model.state.badgeColor.opacity(0.15))
                            )
                            .foregroundStyle(model.state.badgeColor)
                    }

                    Spacer()

                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }

                Text(model.timeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(model.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(PressableRowStyle())
    }
}

#Preview {
    List {
        NotificationRow(model: .init(
            title: "帰宅前の雨",
            timeText: "今日 18:00",
            summary: "帰宅時間帯 × 雨開始60分前",
            state: .sent
        ))
        NotificationRow(model: .init(
            title: "弱い雨",
            timeText: "通知せず",
            summary: "過去の反応から通知を抑制",
            state: .suppressed
        ))
    }
}
