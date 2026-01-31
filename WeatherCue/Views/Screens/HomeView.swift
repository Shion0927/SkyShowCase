//
//  HomeView.swift
//  WeatherCue
//
//  Created by 植村詩苑 on 2025/12/22.
//

import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState

    @State private var showCityPicker = false

    @State private var lastFetchedAt: Date? = nil

    private var selectedCity: City {
        get { appState.selectedCity ?? City.mockTokyo }
        nonmutating set { appState.selectedCity = newValue }
    }

    private var wxData: WeatherData? {
        appState.forecast?.wxdata?.first
    }

    private var conclusionCards: [ConclusionCard] {
        guard let data = wxData else { return [] }

        // Card 1: 今日の天気（雨なら強調）
        let todayCode = data.mrf?.first?.wx ?? -9999
        let todaySymbol = WXWeatherSymbols.symbolName(for: todayCode)
        let todayTitle: String = {
            switch WXWeatherCode.kind(for: todayCode) {
            case .storm:
                return "今日は大雨・嵐の可能性"
            case .thunder:
                return "今日は雷の可能性"
            case .rain:
                return "今日は雨の可能性"
            case .sleet:
                return "今日はみぞれの可能性"
            case .snow, .heavySnow:
                return "今日は雪の可能性"
            case .heat:
                return "今日は猛暑の可能性"
            case .fog:
                return "今日は霧の可能性"
            case .clear:
                return "今日は晴れ"
            case .cloudy:
                return "今日はくもり"
            case .unknown:
                return "予報を取得できませんでした"
            }
        }()
        let todayMsg = "外出前にタイムラインで変化点を確認"

        // Card 2: いまの気温（ShortRangeForecast 先頭を current 相当として扱う）
        let current = data.srf?.first
        let tempValue = Double(current?.temp ?? -9999)
        let windValue = Double(current?.wndspd ?? -9999)
        let temp = Int(round(tempValue))

        let title2: String = {
            if tempValue == -9999 { return "いま --" }
            return "いま \(temp)°"
        }()

        let msg2: String = {
            if windValue != -9999 {
                return "風速 \(String(format: "%.1f", windValue))m/s"
            }
            return "現在の状況を確認"
        }()

        return [
            .init(icon: todaySymbol, title: todayTitle, message: todayMsg, meta: "今日", severity: WXWeatherCode.isPrecipitation(todayCode) ? .soft : .inApp),
            .init(icon: "thermometer", title: title2, message: msg2, meta: "現在", severity: .inApp)
        ]
    }

    private var timeline: [TimelineItem] {
        guard let srf = wxData?.srf, !srf.isEmpty else { return [] }

        let count = min(12, srf.count)
        return (0..<count).map { i in
            let it = srf[i]
            let label = hourLabel(from: it.date)
            let icon = WXWeatherSymbols.symbolName(for: it.wx)
            let t: String = {
                let v = Double(it.temp ?? -9999)
                if v == -9999 { return "--" }
                return "\(Int(round(v)))°"
            }()
            return .init(hour: label, icon: icon, temp: t, marker: i == 0 ? .start : nil)
        }
    }

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
            CityPickerSheet(selected: Binding(get: { selectedCity }, set: { selectedCity = $0 }))
                .presentationDetents([.medium, .large])
        }
        .task {
            appState.requestLocationIfNeeded()
        }
        .onChange(of: (appState.selectedCity?.id ?? City.mockTokyo.id)) { _, _ in
            Task { await appState.refreshForecastForSelectedCity() }
        }
        .task {
            // 初回表示時に一度だけ取得
            await appState.refreshForecastForSelectedCity()
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 12) {
            Button {
                showCityPicker = true
            } label: {
                HStack(spacing: 6) {
                    if let city = appState.selectedCity {
                        Text(city.displayName)
                            .font(.title2).bold()
                    } else {
                        Text("都市を選択")
                            .font(.title2).bold()
                            .foregroundStyle(.secondary)
                    }
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
            .accessibilityLabel("通知")
        }
        .padding(.vertical, 6)
    }

    // MARK: - Sections
    private var conclusionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if appState.isFetchingForecast {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("読み込み中")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }

            if let err = appState.forecastErrorText {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            }

            let cards = conclusionCards
            if cards.isEmpty && !appState.isFetchingForecast && appState.forecastErrorText == nil {
                Text("都市を選ぶと天気が表示されます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ForEach(cards.prefix(2)) { card in
                    ConclusionCardView(card: card)
                }
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
                InsightTuningView()
            } label: {
                ShortcutCardView(title: "通知の考え方を調整", subtitle: "学習の調整へ")
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Data loading


    // MARK: - Helpers (UI-only)
    private func hourLabel(from iso: String) -> String {
        // Expect ISO 8601 extended with timezone: 2020-01-02T09:00:00+09:00
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let d: Date? = f.date(from: iso) ?? {
            let g = ISO8601DateFormatter()
            g.formatOptions = [.withInternetDateTime]
            return g.date(from: iso)
        }()

        guard let date = d else {
            // fallback: try to extract "HH" from string
            if let t = iso.split(separator: "T").dropFirst().first {
                let hh = t.prefix(2)
                return "\(hh)時"
            }
            return "--"
        }

        let out = DateFormatter()
        out.locale = Locale(identifier: "ja_JP")
        out.timeZone = TimeZone.current
        out.dateFormat = "H"
        return "\(out.string(from: date))時"
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
    @Environment(AppState.self) private var appState
    @Binding var selected: City

    @State private var query: String = ""
    @State private var isSearching: Bool = false
    @State private var results: [City] = []
    @State private var searchError: String? = nil

    var body: some View {
        NavigationStack {
            List {
                // 現在地
                Section("現在地") {
                    if let cur = appState.currentLocationCity {
                        Button {
                            selected = cur
                            Task { await appState.selectCityAndFetch(cur) }
                            // 現在地はお気に入りに入れない（必要ならここで addFavorite）
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cur.displayName)
                                    Text("GPS")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if cur.id == selected.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            appState.refreshCurrentLocation()
                        } label: {
                            Label("現在地を更新", systemImage: "location")
                        }
                    } else {
                        Text("現在地が取得できていません")
                            .foregroundStyle(.secondary)
                        Button {
                            appState.refreshCurrentLocation()
                        } label: {
                            Label("取得する", systemImage: "location")
                        }
                    }
                }

                // お気に入り
                Section("登録した土地") {
                    if appState.favoriteCities.isEmpty {
                        Text("まだ登録がありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.favoriteCities) { city in
                            Button {
                                selected = city
                                Task { await appState.selectCityAndFetch(city) }
                                dismiss()
                            } label: {
                                HStack {
                                    Text(city.displayName)
                                    Spacer()
                                    if city.id == selected.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) {
                                    appState.removeFavorite(id: city.id)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                // 検索
                Section("検索して追加") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("都市名（例: Tokyo / 札幌）", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        if isSearching {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("検索中")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let e = searchError {
                            Text(e)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            Task { await search() }
                        } label: {
                            Label("検索", systemImage: "magnifyingglass")
                        }
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if !results.isEmpty {
                        ForEach(results) { city in
                            Button {
                                appState.addFavorite(city)
                                selected = city
                                Task { await appState.selectCityAndFetch(city) }
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(city.displayName)
                                    Text(city.country)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("場所")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .task {
            // 初回に現在地取得を促す
            appState.requestLocationIfNeeded()
        }
    }

    @MainActor
    private func search() async {
        if isSearching { return }
        isSearching = true
        searchError = nil
        results = []
        defer { isSearching = false }

        do {
            let items = try await WeatherClient.shared.searchCities(query: query.trimmingCharacters(in: .whitespacesAndNewlines))
            results = items
        } catch {
            searchError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
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
