// Utils/TemperatureFormatter.swift

import Foundation

// MARK: - Cached number formatters
private final class _TempFormatters {
    static let shared = _TempFormatters()
    private init() {}

    private var map: [String: NumberFormatter] = [:]

    func nf(locale: Locale, fractionDigits: Int) -> NumberFormatter {
        let key = locale.identifier + "#" + String(fractionDigits)
        if let f = map[key] { return f }
        let f = NumberFormatter()
        f.locale = locale
        f.minimumFractionDigits = fractionDigits
        f.maximumFractionDigits = fractionDigits
        map[key] = f
        return f
    }
}

/// 摂氏の実数値をロケール/設定に応じた文字列（℃ / ℉）で返す
/// - Parameters:
///   - celsius: 摂氏の値
///   - locale: 表示用ロケール
///   - forceFahrenheit: `true` なら必ず℉、`false` なら必ず℃、`nil` ならロケールから自動判定
///   - fractionDigits: 小数点以下桁数（デフォルト 1）
/// - Returns: 例 `"23.4℃"` / `"74.1℉"`
@inline(__always)
func formatTemperature(_ celsius: Double,
                       locale: Locale,
                       forceFahrenheit: Bool? = nil,
                       fractionDigits: Int = 1) -> String
{
    let useF = forceFahrenheit ?? shouldUseFahrenheit(locale)

    let value: Double
    let unitSymbol: String
    if useF {
        value = Measurement(value: celsius, unit: UnitTemperature.celsius)
            .converted(to: .fahrenheit).value
        unitSymbol = "℉"
    } else {
        value = celsius
        unitSymbol = "℃"
    }

    let fmt = _TempFormatters.shared.nf(locale: locale, fractionDigits: fractionDigits)
    let num = fmt.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
    return "\(num)\(unitSymbol)"
}

/// 摂氏→華氏への単純変換（表示以外のロジックで使う場合）
@inline(__always)
func celsiusToFahrenheit(_ c: Double) -> Double {
    Measurement(value: c, unit: UnitTemperature.celsius).converted(to: .fahrenheit).value
}
