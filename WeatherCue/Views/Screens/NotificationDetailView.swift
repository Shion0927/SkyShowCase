//
//  NotificationDetailView.swift
//  WeatherCue
//
//  Created by 植村詩苑 on 2025/12/23.
//

import SwiftUI

struct NotificationDetailView: View {

    // MARK: - Input (later replace with domain model)
    let title: String
    let time: String
    let wasSent: Bool
    let reason: String
    let level: NotificationLevel

    @State private var feedback: Feedback? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                header

                reasonSection

                levelSection

                feedbackSection

            }
            .padding(16)
        }
        .navigationTitle("通知の詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2).bold()

            Text(time)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(wasSent ? "この通知は送信されました" : "この通知は送信されませんでした")
                .font(.subheadline)
                .foregroundStyle(wasSent ? .primary : .secondary)
        }
        .cardContainerStyle(emphasized: true)
    }

    // MARK: - Reason
    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("なぜこう判断した？")
                .font(.headline)

            Text(reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .cardContainerStyle()
    }

    // MARK: - Level
    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("通知レベル")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(NotificationLevel.allCases, id: \.self) { lv in
                    LevelPill(level: lv, isActive: lv == level)
                }
            }
        }
        .cardContainerStyle()
    }

    // MARK: - Feedback
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("この判断はどうだった？")
                .font(.headline)

            HStack(spacing: 12) {
                FeedbackButton(label: "👍", value: .good, selection: $feedback)
                FeedbackButton(label: "😐", value: .neutral, selection: $feedback)
                FeedbackButton(label: "👎", value: .bad, selection: $feedback)
            }
        }
        .cardContainerStyle()
    }
}

// MARK: - Supporting Types

enum NotificationLevel: String, CaseIterable {
    case hard = "Hard"
    case soft = "Soft"
    case inApp = "In-App"

    var description: String {
        switch self {
        case .hard: return "必ず知らせる"
        case .soft: return "必要そうなら通知"
        case .inApp: return "アプリ内のみ"
        }
    }

    var tint: Color {
        switch self {
        case .hard: return .orange
        case .soft: return .blue
        case .inApp: return .gray
        }
    }
}

enum Feedback {
    case good
    case neutral
    case bad
}

// MARK: - Components

private struct LevelPill: View {
    let level: NotificationLevel
    let isActive: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(level.rawValue)
                .font(.subheadline).fontWeight(.semibold)

            Text(level.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isActive ? level.tint.opacity(0.15) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isActive ? level.tint.opacity(0.4) : Color.primary.opacity(0.05))
        )
    }
}

private struct FeedbackButton: View {
    let label: String
    let value: Feedback
    @Binding var selection: Feedback?

    var body: some View {
        Button {
            selection = value
        } label: {
            Text(label)
                .font(.title2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selection == value ? Color(.systemGray4) : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Styling

private extension View {
    func cardContainerStyle(emphasized: Bool = false) -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(emphasized ? Color.primary.opacity(0.06) : Color.primary.opacity(0.04), lineWidth: 1)
            )
    }
}

#Preview {
    NavigationStack {
        NotificationDetailView(
            title: "帰宅前の雨",
            time: "今日 18:00",
            wasSent: true,
            reason: "帰宅時間帯と雨の開始時刻が重なり、以前は同様の通知で役立ったと評価されたため",
            level: .soft
        )
    }
}
