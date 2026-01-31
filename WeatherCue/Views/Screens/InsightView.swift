//
//  InsightView.swift
//  WeatherCue
//
//  Created by 植村詩苑 on 2025/12/22.
//

import SwiftUI

struct InsightView: View {

    // MARK: - Mock (UI-only)
    private let understanding: [InsightItem] = [
        .init(
            icon: "sparkles",
            title: "このアプリは“結論”を通知します",
            detail: "雨そのものではなく、あなたの行動に影響する変化（帰宅前の雨など）を優先します。"
        ),
        .init(
            icon: "bell.badge",
            title: "通知レベルは3段階",
            detail: "Hard / Soft / In‑App の範囲で、あなたの反応から最適化します。"
        )
    ]

    private let trends: [InsightItem] = [
        .init(icon: "hand.thumbsup", title: "役立った通知", detail: "帰宅前の雨（夕方）"),
        .init(icon: "hand.thumbsdown", title: "抑制が増えた通知", detail: "弱い雨（短時間）")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                intro

                insightSection(title: "通知の考え方", items: understanding)

                insightSection(title: "最近の傾向", items: trends)

                actions

            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .navigationTitle(String(localized: .init("insight.nav.title")))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("なぜ通知した？が分かる")
                .font(.title2).bold()
            Text("通知の判断基準と、あなたに合わせた変化をまとめます")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func insightSection(title: String, items: [InsightItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { idx in
                    InsightRow(item: items[idx])
                        .padding(.vertical, 10)

                    if idx != items.count - 1 {
                        Divider().opacity(0.6)
                    }
                }
            }
            .padding(.top, 2)
        }
        .cardContainerStyle()
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("調整")
                .font(.headline)

            NavigationLink {
                InsightTuningView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("通知の考え方を調整")
                            .font(.subheadline).fontWeight(.semibold)
                        Text("しきい値・抑制の方針など")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)
        }
        .cardContainerStyle()
    }
}

// MARK: - Models (UI-only)

private struct InsightItem {
    let icon: String
    let title: String
    let detail: String
}

// MARK: - Components

private struct InsightRow: View {
    let item: InsightItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                Image(systemName: item.icon)
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline).fontWeight(.semibold)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Styling

extension View {
    func cardContainerStyle() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
            )
    }
}

#Preview {
    NavigationStack {
        InsightView()
    }
}
