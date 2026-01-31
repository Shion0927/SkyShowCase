// Utils/DateFormatting.swift
import Foundation

/// ISO(yyyy-MM-dd) 形式の文字列を Date に変換
@inline(__always)
func parseISO_YMD(_ iso: String) -> Date? {
    return DateFormatters.isoYMD.date(from: iso)
}

/// ISO8601 (日時) 形式の文字列を Date に変換
@inline(__always)
func parseISO8601DateTime(_ iso: String) -> Date? {
    // まずサブ秒ありを試し、だめならサブ秒なしで再試行
    if let d = DateFormatters.iso8601DateTime.date(from: iso) { return d }
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: iso)
}

/// ロケールに応じて「短い日付 + 曜日」を返す
/// - 例: ja_JP → "9月4日(木)" / en_US → "Sep 4, Thu"
@inline(__always)
func formatShortDay(_ date: Date, locale: Locale) -> String {
    let out = DateFormatter()
    out.locale = locale
    out.setLocalizedDateFormatFromTemplate("MMMdEEE")
    return out.string(from: date)
}

/// ISO(yyyy-MM-dd) 文字列をロケールに応じた短い日付テキストに変換
@inline(__always)
func shortDateText(_ iso: String, locale: Locale) -> String {
    if let d1 = parseISO8601DateTime(iso) {
        return formatMonthDayWithShortWeekday(d1, locale: locale)
    }
    if let d2 = parseISO_YMD(iso) {
        return formatMonthDayWithShortWeekday(d2, locale: locale)
    }
    return iso
}

/// Date をロケールに応じた短い日付テキストに変換
@inline(__always)
func shortDateText(_ date: Date, locale: Locale) -> String {
    return formatMonthDayWithShortWeekday(date, locale: locale)
}

/// ロケールに応じて "月/日(曜日略)" を返す
/// - 例: ja_JP → "12/19(金)" / en_US → "12/19(Fri)"
@inline(__always)
func formatMonthDayWithShortWeekday(_ date: Date, locale: Locale) -> String {
    // Month/Day part
    let df = DateFormatter()
    df.locale = locale
    df.calendar = Calendar(identifier: .gregorian)
    df.timeZone = TimeZone.current
    df.setLocalizedDateFormatFromTemplate("Md")
    let dayPart = df.string(from: date)

    // Weekday short symbol (locale-aware)
    let weekdayIndex = df.calendar?.component(.weekday, from: date) ?? Calendar.current.component(.weekday, from: date)
    let weekdayFormatter = DateFormatter()
    weekdayFormatter.locale = locale
    let shortSymbols = weekdayFormatter.shortWeekdaySymbols ?? ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    let symbol = shortSymbols[(weekdayIndex - 1 + shortSymbols.count) % shortSymbols.count]

    return "\(dayPart)(\(symbol))"
}

// MARK: - Private cached formatters

private enum DateFormatters {
    /// 入力想定: "yyyy-MM-dd"
    static let isoYMD: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale   = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// 入力想定: ISO8601 日時 (例: "2025-12-18T00:00:00+09:00")
    static let iso8601DateTime: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        // サブ秒なし・タイムゾーン付きなど一般的なバリアントを許容
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
