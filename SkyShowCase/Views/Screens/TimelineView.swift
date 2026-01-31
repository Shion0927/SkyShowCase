//
//  TimelineView.swift
//  SkyShowCase
//
//  Created by 植村詩苑 on 2025/12/22.
//

import SwiftUI

struct TimelineView: View {

    @Environment(AppState.self) private var appState

    private var wxData: WeatherData? {
        appState.forecast?.wxdata?.first
    }

    private var hourly: [HourlyItem] {
        guard let srf = wxData?.srf, !srf.isEmpty else { return [] }
        let count = min(24, srf.count)
        return (0..<count).map { i in
            let it = srf[i]
            let temp = Double(it.temp ?? -9999)
            let t = temp == -9999 ? "--" : "\(Int(round(temp)))°"
            let prec = Double(it.prec ?? -9999)
            let highlight = WXWeatherCode.isPrecipitation(it.wx) || (prec != -9999 && prec > 0)
            return .init(hour: hourLabel(from: it.date), symbol: WXWeatherSymbols.symbolName(for: it.wx), temp: t, highlight: highlight)
        }
    }

    private var daily: [DailyItem] {
        guard let mrf = wxData?.mrf, !mrf.isEmpty else { return [] }
        let count = min(7, mrf.count)
        return (0..<count).map { i in
            let it = mrf[i]
            let day = dayLabel(from: it.date, offset: i)
            let high = Double(it.maxtemp ?? -9999)
            let low = Double(it.mintemp ?? -9999)
            let highLow: String = {
                let h = high == -9999 ? "--" : "\(Int(round(high)))°"
                let l = low == -9999 ? "--" : "\(Int(round(low)))°"
                return "\(h) / \(l)"
            }()

            let pop = it.pop ?? -99
            let popText = pop >= 0 ? "（\(pop)%）" : ""
            let summary = WXWeatherText.shortLabel(for: it.wx) + popText

            return .init(day: day, summary: summary, highLow: highLow, symbol: WXWeatherSymbols.symbolName(for: it.wx))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                header

                if wxData == nil {
                    Text("天気データがありません。ホームで都市を選ぶと表示されます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

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
}

private struct DailyItem: Identifiable {
    let id = UUID()
    let day: String
    let summary: String
    let highLow: String
    let symbol: String
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

// MARK: - Helpers (WXTech)

private func hourLabel(from iso: String) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let d: Date? = f.date(from: iso) ?? {
        let g = ISO8601DateFormatter()
        g.formatOptions = [.withInternetDateTime]
        return g.date(from: iso)
    }()

    guard let date = d else {
        if let t = iso.split(separator: "T").dropFirst().first {
            let hh = t.prefix(2)
            return String(hh)
        }
        return "--"
    }

    let out = DateFormatter()
    out.locale = Locale(identifier: "ja_JP")
    out.timeZone = TimeZone.current
    out.dateFormat = "H"
    return out.string(from: date)
}

private func dayLabel(from isoOrDate: String, offset: Int) -> String {
    if offset == 0 { return "今日" }
    if offset == 1 { return "明日" }

    let base = isoOrDate.split(separator: "T").first.map(String.init) ?? isoOrDate

    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(secondsFromGMT: 0)
    df.dateFormat = "yyyy-MM-dd"

    let out = DateFormatter()
    out.locale = Locale(identifier: "ja_JP")
    out.timeZone = TimeZone.current
    out.dateFormat = "E"

    if let d = df.date(from: base) {
        return out.string(from: d)
    }
    return "\(offset + 1)日後"
}


#Preview {
    NavigationStack {
        TimelineView()
            .environment(AppState())
    }
}
