//
//  TimelineView.swift
//  SkyShowCase
//
//  Created by 植村詩苑 on 2025/12/22.
//

import SwiftUI

struct TimelineView: View {

    // MARK: - Mock data (UI only)
    private let hourly: [HourlyItem] = HourlyItem.mock24h
    private let daily: [DailyItem] = DailyItem.mock7d

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                header

                hourlySection

                dailySection

            }
            .padding(16)
        }
        .navigationTitle("タイムライン")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("今後の変化")
                .font(.title2).bold()

            Text("重要な変化だけを時系列で")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Hourly (24h)
    private var hourlySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("24時間")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(hourly) { item in
                        HourlyCard(item: item)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .cardContainerStyle()
    }

    // MARK: - Daily (7d)
    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("7日間")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(daily) { item in
                    DailyRow(item: item)
                }
            }
        }
        .cardContainerStyle()
    }
}

// MARK: - Models (UI-only)

private struct HourlyItem: Identifiable {
    let id = UUID()
    let hour: String
    let symbol: String
    let temp: String
    let highlight: Bool

    static let mock24h: [HourlyItem] = [
        .init(hour: "18", symbol: "cloud.rain", temp: "12°", highlight: true),
        .init(hour: "19", symbol: "cloud.rain", temp: "11°", highlight: true),
        .init(hour: "20", symbol: "cloud", temp: "11°", highlight: false),
        .init(hour: "21", symbol: "cloud", temp: "10°", highlight: false),
        .init(hour: "22", symbol: "moon", temp: "9°", highlight: false)
    ]
}

private struct DailyItem: Identifiable {
    let id = UUID()
    let day: String
    let summary: String
    let highLow: String
    let symbol: String

    static let mock7d: [DailyItem] = [
        .init(day: "今日", summary: "夕方から雨", highLow: "12° / 6°", symbol: "cloud.rain"),
        .init(day: "明日", summary: "くもり", highLow: "13° / 7°", symbol: "cloud"),
        .init(day: "水", summary: "晴れ", highLow: "15° / 8°", symbol: "sun.max")
    ]
}

// MARK: - Components

private struct HourlyCard: View {
    let item: HourlyItem

    var body: some View {
        VStack(spacing: 6) {
            Text(item.hour)
                .font(.caption).foregroundStyle(.secondary)

            Image(systemName: item.symbol)
                .font(.title3)
                .foregroundStyle(item.highlight ? .blue : .secondary)

            Text(item.temp)
                .font(.subheadline).fontWeight(.semibold)
        }
        .padding(12)
        .frame(width: 72)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(item.highlight ? Color.blue.opacity(0.12) : Color(.secondarySystemBackground))
        )
    }
}

private struct DailyRow: View {
    let item: DailyItem

    var body: some View {
        HStack(spacing: 12) {
            Text(item.day)
                .font(.subheadline).fontWeight(.semibold)
                .frame(width: 40, alignment: .leading)

            Image(systemName: item.symbol)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.summary)
                    .font(.subheadline)
                Text(item.highLow)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Styling

private extension View {
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
        TimelineView()
    }
}
