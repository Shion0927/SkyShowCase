import Foundation

// MARK: - Weathernews WXTech API Response (ss1wx)

// Root response
struct WeatherResponse: Decodable {
    let requestId: String?
    let wxdata: [WeatherData]?
    let errors: [WXError]?

    enum CodingKeys: String, CodingKey {
        case requestId
        case wxdata
        case errors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.requestId = try container.decodeIfPresent(String.self, forKey: .requestId)
        self.wxdata = try container.decodeIfPresent([WeatherData].self, forKey: .wxdata)
        self.errors = try container.decodeIfPresent([WXError].self, forKey: .errors)
    }
}

// Error object
struct WXError: Decodable {
    let code: String
    let message: String
}

// Weather data per requested coordinate
struct WeatherData: Decodable {
    let lat: Double
    let lon: Double
    let srf: [ShortRangeForecast]?
    let mrf: [MediumRangeForecast]?
}

// MARK: - Short Range Forecast (72h / hourly)
struct ShortRangeForecast: Decodable {
    let date: String
    let wx: Int
    let temp: Float?
    let prec: Float?
    let arpress: Float?
    let wndspd: Float?
    let wnddir: Int?
    let rhum: Int?
}

// MARK: - Medium Range Forecast (10 days / daily)
struct MediumRangeForecast: Decodable {
    let date: String
    let wx: Int
    let maxtemp: Float?
    let mintemp: Float?
    let pop: Int?
}

func countryName(from code: String?) -> String? {
    guard let code, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    let upper = code.uppercased()
    return Locale.current.localizedString(forRegionCode: upper) ?? upper
}
