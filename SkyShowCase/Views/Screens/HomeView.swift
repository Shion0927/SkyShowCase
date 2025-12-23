//
//  HomeView.swift
//  SkyShowCase
//
//  Created by 植村詩苑 on 2025/12/22.
//

import SwiftUI

struct HomeView: View {
    @State private var selectedCity: City = City.mockTokyo
    @State private var showCityPicker = false

    // MARK: - Mock data (replace with real data later)
    private let conclusionCards: [ConclusionCard] = [
        .init(icon: "cloud.rain", title: "18–20時に雨", message: "傘があると安心", meta: "18:40〜", severity: .soft),
        .init(icon: "thermometer.low", title: "朝は体感が低い", message: "薄手の上着が安心", meta: "7:00頃", severity: .soft)
    ]

    private let timeline: [TimelineItem] = [
        .init(hour: "18", icon: "cloud", temp: "12°", marker: nil),
        .init(hour: "20", icon: "cloud.rain", temp: "11°", marker: .start),
        .init(hour: "22", icon: "cloud.rain", temp: "10°", marker: nil),
        .init(hour: "0", icon: "cloud", temp: "10°", marker: nil)
    ]

    private let logItems: [NotificationRowModel] = [
        .init(
            title: "帰宅前の雨",
            timeText: "18:00",
            summary: "帰宅時間帯 × 雨開始60分前",
            state: .sent
        ),
        .init(
            title: "弱い雨",
            timeText: "通知せず",
            summary: "以前スキップが多かったため",
            state: .suppressed
        )
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                header

                conclusionSection

                timelineSection

                notificationLogSection

                learningCardSection

                shortcutSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showCityPicker) {
            CityPickerSheet(selected: $selectedCity)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 12) {
            Button {
                showCityPicker = true
            } label: {
                HStack(spacing: 6) {
                    Text(selectedCity.displayName)
                        .font(.title2).bold()
                    Image(systemName: "chevron.down")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                // TODO: route to notification preferences
            } label: {
                Image(systemName: "bell")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("通知設定")
        }
        .padding(.vertical, 6)
    }

    // MARK: - Sections
    private var conclusionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(conclusionCards.prefix(2)) { card in
                ConclusionCardView(card: card)
            }
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今後24時間")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    ForecastDetailPlaceholderView(city: selectedCity)
                } label: {
                    Text("詳細")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(timeline) { item in
                        TimelinePill(item: item)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .cardContainerStyle()
    }

    private var notificationLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("通知ログ")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    NotificationsView()
                } label: {
                    Text("すべて")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(logItems.indices, id: \.self) { idx in
                    let it = logItems[idx]

                    NavigationLink {
                        NotificationDetailView(
                            title: it.title,
                            time: it.timeText,
                            wasSent: it.state == .sent,
                            reason: it.summary,
                            level: .soft // TODO: derive from real rule
                        )
                    } label: {
                        NotificationRow(model: it)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if idx != logItems.count - 1 {
                        Divider().opacity(0.6)
                    }
                }
            }
            .padding(.top, 2)
        }
        .cardContainerStyle()
    }

    private var learningCardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("学習カード")
                .font(.headline)

            LearningCardView(
                title: "この雨、通知した方が良かった？",
                subtitle: "通知では聞かない質問（学習用）",
                actions: [
                    .init(label: "👍", value: .yes),
                    .init(label: "😐", value: .neutral),
                    .init(label: "👎", value: .no)
                ],
                onTap: { _ in
                    // TODO: send feedback
                }
            )
        }
        .cardContainerStyle()
    }

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                YouPlaceholderView(city: selectedCity)
            } label: {
                ShortcutCardView(title: "通知の考え方を調整", subtitle: "あなたの設定へ")
            }
            .buttonStyle(.plain)
        }
    }
}


// Use the app-wide `City` model defined in Cache.swift.
// Add small UI helpers / mock presets here to avoid touching the shared model.
private extension City {
    var displayName: String {
        // Example: "Tokyo" or "Tokyo, JP" or "Tokyo, Tokyo".
        if let admin1, !admin1.isEmpty {
            return "\(name), \(admin1)"
        }
        if !country_code.isEmpty {
            return "\(name), \(country_code.uppercased())"
        }
        return name
    }

    static var mockTokyo: City {
        City(id: 130010, name: "Tokyo", latitude: 35.6762, longitude: 139.6503, country: "Japan", country_code: "JP", admin1: "Tokyo")
    }

    static var mockOsaka: City {
        City(id: 270000, name: "Osaka", latitude: 34.6937, longitude: 135.5023, country: "Japan", country_code: "JP", admin1: "Osaka")
    }

    static var mockNagoya: City {
        City(id: 230010, name: "Nagoya", latitude: 35.1815, longitude: 136.9066, country: "Japan", country_code: "JP", admin1: "Aichi")
    }
}

private enum Severity {
    case hard
    case soft
    case inApp

    var tint: Color {
        switch self {
        case .hard: return .orange
        case .soft: return .blue
        case .inApp: return .gray
        }
    }
}

private struct ConclusionCard: Identifiable {
    var id = UUID()
    var icon: String
    var title: String
    var message: String
    var meta: String
    var severity: Severity
}

private struct TimelineItem: Identifiable {
    enum Marker {
        case start
        case peak
    }

    var id = UUID()
    var hour: String
    var icon: String
    var temp: String
    var marker: Marker?
}


private struct LearningAction: Identifiable {
    enum Value { case yes, neutral, no }

    var id = UUID()
    var label: String
    var value: Value
}

// MARK: - Components

private struct ConclusionCardView: View {
    let card: ConclusionCard

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(card.severity.tint.opacity(0.12))
                Image(systemName: card.icon)
                    .font(.title3)
                    .foregroundStyle(card.severity.tint)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.headline)
                Text(card.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(card.meta)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardContainerStyle(emphasized: true)
    }
}

private struct TimelinePill: View {
    let item: TimelineItem

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(item.hour)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                if let marker = item.marker {
                    Circle()
                        .frame(width: 6, height: 6)
                        .foregroundStyle(marker == .start ? .blue : .orange)
                        .accessibilityLabel(marker == .start ? "開始" : "ピーク")
                }
            }

            Image(systemName: item.icon)
                .font(.headline)

            Text(item.temp)
                .font(.subheadline).fontWeight(.semibold)
        }
        .frame(width: 66)
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}


private struct LearningCardView: View {
    let title: String
    let subtitle: String
    let actions: [LearningAction]
    var onTap: (LearningAction.Value) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline).fontWeight(.semibold)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(actions) { act in
                    Button {
                        onTap(act.value)
                    } label: {
                        Text(act.label)
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ShortcutCardView: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .cardContainerStyle()
    }
}

private struct CityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: City

    private let cities: [City] = [.mockTokyo, .mockOsaka, .mockNagoya]

    var body: some View {
        NavigationStack {
            List {
                ForEach(cities) { city in
                    Button {
                        selected = city
                        dismiss()
                    } label: {
                        HStack {
                            Text(city.displayName)
                            Spacer()
                            if city == selected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("場所")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
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

// MARK: - Placeholders (replace with real screens)

private struct ForecastDetailPlaceholderView: View {
    let city: City
    var body: some View {
        VStack(spacing: 12) {
            Text("Forecast Detail")
                .font(.title2).bold()
            Text(city.displayName)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

private struct NotificationsPlaceholderView: View {
    let city: City
    var body: some View {
        VStack(spacing: 12) {
            Text("Notifications")
                .font(.title2).bold()
            Text(city.displayName)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

private struct YouPlaceholderView: View {
    let city: City
    var body: some View {
        VStack(spacing: 12) {
            Text("You")
                .font(.title2).bold()
            Text(city.displayName)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .navigationTitle("Home") // Preview-only title
    }
}
