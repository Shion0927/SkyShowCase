import Foundation

struct ClothingAdvisor {
    static func advice(current: Forecast.Current, locale: Locale) -> String {
        let t = current.temperature_2m
        let apparent = current.apparent_temperature
        let wind = current.wind_speed_10m
        let rainy = rainLikeCodes.contains(current.weather_code)

        // 風が強い場合は体感をより冷たく感じる想定
        let feels = wind >= 8 ? min(t, apparent) : apparent
        let jp = isJapanese(locale)

        var parts: [String] = []
        if rainy { parts.append(jp ? "傘を忘れずに" : "Bring an umbrella") }

        // 温度帯によるメッセージ
        let msg: String
        switch feels {
        case ..<0:
            msg = jp ? "極寒：ダウン＋手袋・マフラー必須" : "Frigid: heavy down jacket, gloves & scarf"
        case 0..<5:
            msg = jp ? "とても寒い：厚手コート＋防寒小物" : "Very cold: heavy coat + winter accessories"
        case 5..<10:
            msg = jp ? "寒い：コートや厚手の上着" : "Cold: coat or thick outer layer"
        case 10..<16:
            msg = jp ? "肌寒い：ライトアウター" : "Chilly: light jacket"
        case 16..<22:
            msg = jp ? "快適：長袖が無難" : "Mild: long sleeves recommended"
        case 22..<28:
            msg = jp ? (wind >= 8 ? "暑め：薄手＋羽織り（風強め）" : "やや暑い：薄手で快適")
                      : (wind >= 8 ? "Warm: lightwear + outer (windy)" : "Warm: lightwear")
        default:
            msg = jp ? "猛暑：半袖＋こまめに水分補給" : "Hot: T-shirt, stay hydrated"
        }
        parts.append(msg)

        // 強風注意
        if wind >= 12 {
            parts.append(jp ? "風が強いので帽子や固定できる服装を" : "Windy: secure hats or layers")
        }

        let head = jp ? "アドバイス：" : "Advice: "
        return head + parts.joined(separator: jp ? "／" : " / ")
    }

    private static let rainLikeCodes: Set<Int> = [51,52,53,55,56,57,61,63,65,80,81,82,95,96,99]
}
