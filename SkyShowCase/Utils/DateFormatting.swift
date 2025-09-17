// Utils/DateFormatting.swift
import Foundation

/// ISO(yyyy-MM-dd) 形式の文字列を Date に変換
@inline(__always)
func parseISO_YMD(_ iso: String) -> Date? {
    return DateFormatters.isoYMD.date(from: iso)
}

/// ロケールに応じて「短い日付 + 曜日」を返す
/// - 例: ja_JP → "9月4日(木)" / en_US → "Sep 4, Thu"
@inline(__always)
func formatShortDay(_ date: Date, locale: Locale) -> String {
    let out = DateFormatter()
    // 日本語優先判定の場合は ja_JP を強制（en_JP のような混在ロケールでも日本語表記に寄せる）
    out.locale = isJapanese(locale) ? Locale(identifier: "ja_JP") : locale
    out.setLocalizedDateFormatFromTemplate("MMMdEEE")
    return out.string(from: date)
}

/// ISO(yyyy-MM-dd) 文字列をロケールに応じた短い日付テキストに変換
@inline(__always)
func shortDateText(_ iso: String, locale: Locale) -> String {
    guard let d = parseISO_YMD(iso) else { return iso }
    return formatShortDay(d, locale: locale)
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
}
