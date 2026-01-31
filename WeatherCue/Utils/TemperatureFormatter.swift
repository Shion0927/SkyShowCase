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

/// ロケールに応じて華氏を使用するべきかどうかを返す
/// - Parameter locale: 判定に使うロケール
/// - Returns: `true` なら華氏、`false` なら摂氏
@inline(__always)
private func shouldUseFahrenheit(_ locale: Locale) -> Bool {
    // 多くの地域ではメートル法(摂氏)を使用。US/BS/LR など一部はヤード・ポンド法(華氏)。
    // iOS 16 以降は Locale.measurementSystem を使用し、それ以前は usesMetricSystem をフォールバックとして使用。
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
        if locale.measurementSystem != .metric { return true }
    } else {
        if locale.usesMetricSystem == false { return true }
    }

    // usesMetricSystem が true でも、国コードで明示的に上書き（将来の互換性のため）
    // 米国(US)、バハマ(BS)、リベリア(LR) などは華氏を使用。
    if let region = locale.region?.identifier.uppercased() {
        switch region {
        case "US", "BS", "BZ", "KY", "LR", "PW":
            return true
        default:
            break
        }
    }

    return false
}
