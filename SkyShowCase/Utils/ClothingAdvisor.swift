import Foundation

struct ClothingAdvisor {
    static func advice(current: Forecast.Current, locale: Locale) -> String {
        let t = current.temperature_2m
        let apparent = current.apparent_temperature
        let wind = current.wind_speed_10m
        let rainy = rainLikeCodes.contains(current.weather_code)

        // 風が強い場合は体感をより冷たく感じる想定
        let feels = wind >= 8 ? min(t, apparent) : apparent
        var parts: [String] = []
        if rainy {
            parts.append(String(localized: "ADVICE_RAIN"))
        }

        let msgKey: String
        switch feels {
        case ..<0:
            msgKey = "ADVICE_FRIGID"
        case 0..<5:
            msgKey = "ADVICE_VERY_COLD"
        case 5..<10:
            msgKey = "ADVICE_COLD"
        case 10..<16:
            msgKey = "ADVICE_CHILLY"
        case 16..<22:
            msgKey = "ADVICE_MILD"
        case 22..<28:
            msgKey = (wind >= 8) ? "ADVICE_WARM_WINDY" : "ADVICE_WARM"
        default:
            msgKey = "ADVICE_HOT"
        }
        parts.append(NSLocalizedString(msgKey, comment: "Temperature-based advice"))

        if wind >= 12 {
            parts.append(String(localized: "ADVICE_WINDY"))
        }

        let head = String(localized: "ADVICE_HEADER")
        let separator = String(localized: "ADVICE_SEPARATOR")
        return head + parts.joined(separator: separator)
    }

    private static let rainLikeCodes: Set<Int> = [51,52,53,55,56,57,61,63,65,80,81,82,95,96,99]
}
